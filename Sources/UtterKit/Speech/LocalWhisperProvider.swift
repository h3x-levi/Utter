import Foundation
import os
import whisper

/// On-device transcription via whisper.cpp.
///
/// The model ships inside the app bundle (`Contents/Resources/Models`), so the
/// first transcription works offline with no download step. Metal and Core ML
/// are compiled into the prebuilt framework, so inference runs on the GPU.
///
/// The whisper context is expensive to build (~0.4s) but cheap to reuse, so it
/// is created once on first use and held for the process lifetime. All calls to
/// the underlying C API are serialized on a dedicated queue: a `whisper_context`
/// is not thread-safe, and the recorder can finish a new utterance while a
/// previous one is still decoding.
///
/// `@unchecked Sendable` is sound here precisely because of that queue - the
/// mutable `context`/`loadFailure` state is only ever touched inside `queue`.
final class LocalWhisperProvider: TranscriptionProvider, @unchecked Sendable, ObservableObject {

    private static let performanceLog = Logger(
        subsystem: "utter.dictation.app",
        category: "speech-performance"
    )

    /// Filename of the bundled model. Quantized small.en - the accuracy/size
    /// balance chosen for shipping inside the DMG.
    static let modelFilename = "ggml-small.en-q5_1.bin"

    /// Where the engine is in its lifecycle.
    ///
    /// Published so the UI can be honest during the first cold load, which takes
    /// several seconds while macOS pages 181 MB off disk. Without this the pill
    /// showed "Hold Fn to dictate" - an invitation the engine couldn't yet honour.
    enum LoadState: Equatable {
        case idle           // not started
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .idle

    /// The tier to load, set from the main actor before a load begins. Held here
    /// so the whisper queue never reaches into main-actor state.
    private var requestedTier: SpeechModel.Tier = SpeechModel.fallback

    private let queue = DispatchQueue(label: "utter.dictation.whisper")
    private var context: OpaquePointer?
    private var loadFailure: Error?

    /// Monotonic token identifying the newest preview request.
    ///
    /// Previews are speculative: each one transcribes a snapshot of audio that is
    /// already stale by the time it finishes. When a newer snapshot arrives, or the
    /// user stops talking, the in-flight pass is wasted work standing between the
    /// user and their final text - so it is aborted rather than awaited. Guarded by
    /// `previewLock` because the abort callback reads it from whisper's own compute
    /// threads while the main actor writes it.
    private var previewGeneration: Int = 0
    private let previewLock = NSLock()

    private func bumpPreviewGeneration() -> Int {
        previewLock.lock()
        defer { previewLock.unlock() }
        previewGeneration += 1
        return previewGeneration
    }

    private func currentPreviewGeneration() -> Int {
        previewLock.lock()
        defer { previewLock.unlock() }
        return previewGeneration
    }

    /// Abandon any in-flight preview. Called when a real transcription starts, so
    /// the final pass isn't queued behind speculative work.
    func cancelPreviews() {
        _ = bumpPreviewGeneration()
    }

    init() {}

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    /// Build the whisper context ahead of the user's first utterance.
    ///
    /// Loading the model costs several seconds on a cold filesystem cache. Doing
    /// that lazily would stall the very first dictation - the one where the user
    /// is deciding whether the app works - so `AppDelegate` calls this at launch.
    /// Failures are deliberately swallowed: this is an optimization, and the real
    /// error is surfaced with proper UI on the first transcription attempt.
    @MainActor
    func preload() {
        let tier = ModelStore.shared.active
        let language = UserData.shared.selectedLanguage
        publish(.loading)
        queue.async { [self] in
            requestedTier = tier
            _ = try? context(forLanguage: language)
        }
    }

    /// Rebuild the context now, if idle eviction released it, so an imminent transcription does
    /// not pay for it.
    ///
    /// Called when *recording starts*, which is the whole point: the user then speaks for a couple
    /// of seconds, the rebuild runs on `queue` during that time, and the inference work item  - 
    /// queued behind it on the same serial queue - finds a warm context. The cost does not
    /// disappear, it moves off the part of the turn the user is waiting through.
    ///
    /// Measured on this machine (M4, `ggml-small.en-q5_1`, 190 MB), timing
    /// `whisper_init_from_file_with_params` directly:
    ///
    ///   * **78-93 ms** to rebuild in-process after a `whisper_free` with the file still in the
    ///     page cache - the ordinary post-eviction case, and small.
    ///   * **7,686 ms** for the first load in a fresh process with a cold page cache.
    ///
    /// The second number is why this exists. Eviction is deliberately aggressive (5 minutes) and a
    /// menu-bar app can sit idle for hours, by which point the OS has every reason to have dropped
    /// the file from the page cache too - so the rebuild is somewhere on that range, not reliably
    /// at the low end, and the user cannot tell which turn will be the slow one. Warming from
    /// record-start removes the variance rather than the average.
    ///
    /// Deliberately does **not** `publish`. Nothing about capability changed, and this runs while
    /// the pill is `.recording`; see `context(forLanguage:)`. Failures are swallowed for the same
    /// reason `preload` swallows them - this is an optimisation, and the real error is surfaced
    /// with proper UI when the transcription itself asks for a context.
    @MainActor
    func warmUp() {
        let tier = ModelStore.shared.active
        let language = UserData.shared.selectedLanguage
        queue.async { [self] in
            requestedTier = tier
            _ = try? context(forLanguage: language)
        }
    }

    private func publish(_ state: LoadState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.loadState != state else { return }
            self.loadState = state
        }
    }

    // MARK: - TranscriptionProvider

    func transcribe(audioData: Data) async throws -> String {
        Self.joined(try await transcribeTimed(audioData: audioData))
    }

    /// Transcribe, keeping whisper's own per-segment timings.
    ///
    /// The same inference as `transcribe` - which is now a join over this - with the
    /// timestamps kept instead of discarded. Meeting capture needs them to find where
    /// the speaker actually paused (`TurnSegmenter`); dictation does not, because it
    /// produces one continuous utterance that goes into one place.
    ///
    /// Times are relative to `audioData`, not to any longer recording it came from.
    func transcribeTimed(audioData: Data) async throws -> [TimedSegment] {
        let preparationStarted = DispatchTime.now().uptimeNanoseconds
        let samples = try Self.pcmSamples(fromWAV: audioData)
        guard !samples.isEmpty else { throw TranscriptionError.invalidResponse }
        let preparationMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - preparationStarted) / 1_000_000

        // Read main-actor state here, before hopping to the whisper queue.
        let bias = await SpeechBias.current()
        let language = await MainActor.run { UserData.shared.selectedLanguage }
        let enqueuedAt = DispatchTime.now().uptimeNanoseconds

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let queueWaitMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - enqueuedAt) / 1_000_000
                    let contextStarted = DispatchTime.now().uptimeNanoseconds
                    let ctx = try context(forLanguage: language)
                    let contextMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - contextStarted) / 1_000_000
                    let inferenceStarted = DispatchTime.now().uptimeNanoseconds
                    let segments = try Self.run(ctx, samples: samples, bias: bias)
                    let inferenceMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - inferenceStarted) / 1_000_000
                    Self.performanceLog.info(
                        "speech prep_ms=\(preparationMilliseconds, format: .fixed(precision: 1)) queue_ms=\(queueWaitMilliseconds, format: .fixed(precision: 1)) context_ms=\(contextMilliseconds, format: .fixed(precision: 1)) inference_ms=\(inferenceMilliseconds, format: .fixed(precision: 1)) samples=\(samples.count) segments=\(segments.count)"
                    )
                    continuation.resume(returning: segments)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Live preview

    /// Transcribe a snapshot of in-progress audio for on-screen preview only.
    ///
    /// Separate from `transcribe` on purpose, and not part of
    /// `TranscriptionProvider`: the result is deliberately lower quality and must
    /// never be typed into the user's document. Differences from the real path:
    ///
    ///   * **Aborts when superseded.** whisper's `abort_callback` is polled during
    ///     compute, so a stale pass stops mid-inference instead of running to
    ///     completion and delaying the final transcript.
    ///   * **No dictionary biasing, no polish.** Both cost latency, and a preview
    ///     that lags the speaker is worse than a rough one.
    ///   * **Returns nil rather than throwing.** A failed preview is not an error
    ///     the user should ever see.
    ///
    /// Runs on the same serial queue as real inference, so a preview can delay a
    /// final pass by at most one already-started chunk - bounded by `previewSeconds`
    /// in `AudioRecorder`.
    func previewTranscribe(pcm: Data) async -> String? {
        let generation = bumpPreviewGeneration()

        guard let samples = try? Self.pcmSamples(fromRawPCM: pcm), !samples.isEmpty else {
            return nil
        }
        let language = await MainActor.run { UserData.shared.selectedLanguage }

        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                // Superseded while queued: don't start at all.
                guard currentPreviewGeneration() == generation else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let ctx = try? context(forLanguage: language) else {
                    continuation.resume(returning: nil)
                    return
                }
                let segments = try? Self.run(
                    ctx,
                    samples: samples,
                    isStale: { [weak self] in
                        guard let self else { return true }
                        return self.currentPreviewGeneration() != generation
                    }
                )
                // Aborted runs return partial or empty text; treat empty as nothing.
                let trimmed = segments.map(Self.joined) ?? ""
                continuation.resume(returning: trimmed.isEmpty ? nil : trimmed)
            }
        }
    }

    // MARK: - Model loading

    /// Locate the bundled model. Checked in the same order as the app's other
    /// bundled resources (see SoundPlayer): inside the .app first, then the
    /// build-directory and project-root layouts used during development.
    static func modelURL() -> URL? {
        bundledModelURL(named: modelFilename)
    }

    /// Locate a specific bundled model by filename. Several ship in the app.
    static func bundledModelURL(named filename: String) -> URL? {
        if let bundled = Bundle.main.url(
            forResource: filename, withExtension: nil, subdirectory: "Models"
        ) {
            return bundled
        }

        let binaryURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let candidates = [
            // Inside the .app bundle: Contents/Resources/Models/
            binaryURL.deletingLastPathComponent()      // MacOS/
                .deletingLastPathComponent()           // Contents/
                .appendingPathComponent("Resources/Models/\(filename)"),
            // Dev: running from .build/release/ - Models/ is at the project root
            binaryURL.deletingLastPathComponent()      // release/
                .deletingLastPathComponent()           // .build/
                .deletingLastPathComponent()           // project root
                .appendingPathComponent("Models/\(filename)"),
            // Dev: launched from the project root directly
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Models/\(filename)"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Discard the loaded context so the next call rebuilds it. Used when the
    /// user picks a different model.
    func invalidate() {
        queue.async { [self] in
            evictionWork?.cancel()
            evictionWork = nil
            if let context { whisper_free(context) }
            context = nil
            loadFailure = nil
            publish(.idle)
        }
    }

    // MARK: - Idle eviction

    /// How long the context may sit unused before it is freed.
    ///
    /// **Holding the model for the process lifetime cost more than it saved, measured.** The
    /// context was built at launch and released only on a model switch or at quit, so an app that
    /// idles most of the day held an **845MB** footprint. Almost none of it was actually resident:
    /// `vmmap` found **667MB swapped out**, including four contiguous 128MB Metal buffers at
    /// 0K resident and 100% in swap, and RSS was seen swinging from 724MB just after an inference
    /// down to 132MB at idle. The system was already evicting the model - the difference is that it
    /// evicted it to *swap*, where it still cost address space, page-ins (0.5-1.3/s at idle) and a
    /// refault on the next dictation.
    ///
    /// Two costs went with it that are not memory at all:
    ///
    ///   * whisper's Metal residency keep-alive (`ggml_metal_rsets_init`) parks a thread for the
    ///     life of the context and does an IOKit round trip per iteration  - 
    ///     `IOGPUMetalResidencySet requestResidency` was the single largest non-wait leaf in every
    ///     idle profile (0.64-0.90% of a core, *continuously*, transcribing or not). It was asking
    ///     the kernel to keep resident the very buffers the OS had already paged out.
    ///   * `KeyMonitor` runs a `.headInsertEventTap`, so every keystroke on the machine waits on
    ///     this process. A page fault on 667MB of swapped state, taken inside that path, is a
    ///     mechanism for *system-wide* typing lag and for the tap being disabled by timeout.
    ///
    /// Five minutes keeps the model warm across a working session - repeated dictation re-arms the
    /// timer and never reloads - and releases it when the app goes back to being a menu-bar icon.
    /// The reload it costs is a real trade, taken deliberately: it lands on the *first* dictation
    /// after a long idle, where it replaces a multi-second swap-in stall that was happening anyway,
    /// and it is visible as the honest "Transcribing" the pill already shows rather than as an
    /// unexplained pause.
    static let idleEvictionDelay: TimeInterval = 300

    /// Whether a context has ever been built in this process.
    ///
    /// Distinguishes the first load - a real transition from "cannot transcribe" to "can" - from a
    /// rebuild after idle eviction, which is not a transition at all. Confined to `queue`.
    private var hasLoadedOnce = false

    /// The pending eviction, cancelled and re-armed on every use. Confined to `queue`.
    private var evictionWork: DispatchWorkItem?

    /// Re-arm the idle timer. **Called on `queue` only**, from `context(forLanguage:)`, which is
    /// the one funnel every preload and every inference passes through - so "use" is defined in a
    /// single place and cannot drift from the paths that actually use it.
    private func armIdleEviction() {
        evictionWork?.cancel()
        guard Self.idleEvictionDelay > 0 else { return }
        let work = DispatchWorkItem { [weak self] in self?.evictIdleContext() }
        evictionWork = work
        queue.asyncAfter(deadline: .now() + Self.idleEvictionDelay, execute: work)
    }

    /// Free the context because nothing has used it for `idleEvictionDelay`.
    ///
    /// Safe against freeing a context mid-inference *by construction*: `queue` is serial, so this
    /// work item cannot start while a transcription or preview is running on it, and any inference
    /// that starts afterwards calls `context(forLanguage:)` and rebuilds.
    ///
    /// Deliberately does **not** `publish`. `loadState` describes whether the engine can serve a
    /// request, not whether bytes are currently resident: it can, and the rebuild is transparent.
    /// Publishing `.idle` here would be read by `observeModelLoad` as "still loading" and would
    /// park the pill on "Getting ready" for as long as the app sat unused, while also clearing
    /// `modelReady` and refusing the hotkey - turning a memory saving into a broken app. A reload
    /// that genuinely fails still publishes `.failed` from `context(forLanguage:)`, where it is
    /// true.
    private func evictIdleContext() {
        guard let context else { return }
        whisper_free(context)
        self.context = nil
        print("🧠 Whisper model released after \(Int(Self.idleEvictionDelay))s idle "
              + "(frees the Metal buffers and stops the GPU residency loop); "
              + "it reloads on the next dictation")
    }

    /// Free the context *synchronously*, for app termination only.
    ///
    /// `invalidate()` is `queue.async`, so at quit the process can reach `exit()`
    /// before the work item runs. That left ggml's Metal device to be torn down
    /// by a C++ static destructor during `__cxa_finalize_ranges`, by which point
    /// its runtime is partly gone - it called `ggml_abort`, so every ordinary
    /// quit was recorded as a SIGABRT crash (8 in a single day of testing).
    ///
    /// `queue.sync` blocks until the free completes, which is what makes this
    /// safe: any in-flight transcription on the same serial queue finishes first,
    /// so we never free a context that whisper is still reading.
    ///
    /// Deliberately does *not* call `publish` - we are shutting down, and
    /// notifying observers whose views are being destroyed is pointless at best.
    func shutdown() {
        // Abort any in-flight preview *before* taking the queue.
        //
        // `queue.sync` waits for whatever is already running on the serial queue, and
        // a preview pass over a large model can take seconds. Called from
        // `applicationWillTerminate`, that blocks the main thread long enough for the
        // system's quit watchdog to consider the app hung. `cancelPreviews` flips the
        // abort flag whisper's `abort_callback` polls, so the running pass returns
        // almost immediately and the free below is quick.
        cancelPreviews()
        queue.sync { [self] in
            // A pending eviction would otherwise run against a torn-down context. It is a
            // `[weak self]` work item so it could not use freed memory, but cancelling is the
            // statement of intent and keeps the queue from being handed work during quit.
            evictionWork?.cancel()
            evictionWork = nil
            if let context { whisper_free(context) }
            context = nil
        }
    }

    /// Build the context on first use, then reuse it. A previous failure is
    /// cached and rethrown so a broken install doesn't retry a doomed ~190MB
    /// load on every keystroke.
    private func context(forLanguage language: String) throws -> OpaquePointer {
        if let context {
            armIdleEviction()
            return context
        }
        if let loadFailure { throw loadFailure }

        // `.loading` only for the *first* load, because only the first load is a change in what
        // this engine can do. A rebuild after `evictIdleContext` is not: the engine could serve a
        // request the whole time it was unloaded, which is the same argument `evictIdleContext`
        // makes for not publishing when it frees the context - `loadState` describes capability,
        // not residency. Announcing `.loading` on a rebuild flickered `ReadinessMonitor.modelLoad`
        // (the main window's readiness panel) and dropped `modelReady` on a path where nothing was
        // actually unavailable.
        //
        // The pill was never at risk on this path - `observeModelLoad` returns early unless the
        // pill is `.preparing`/`.idle`, and a rebuild happens while it is `.processing`. Worth
        // stating because the comment on `evictIdleContext` warns that publishing here would park
        // the pill on "Getting ready" and refuse the hotkey; that was true when written and is not
        // now, since `modelReady` gates nothing but a log line.
        if !hasLoadedOnce { publish(.loading) }
        do {
            // Honour the user's selected model; fall back to the bundled one.
            guard let url = ModelStore.url(for: requestedTier) ?? Self.modelURL() else {
                throw TranscriptionError.modelMissing(Self.modelFilename)
            }

            // whisper.cpp logs its entire init to stderr by default - dozens of
            // lines, including a "failed to load Core ML model" warning that is
            // expected here (we ship the GGML weights only, not a generated
            // .mlmodelc encoder; Metal still does the work). Keep the genuinely
            // interesting lines and drop the per-tensor init chatter.
            whisper_log_set({ _, message, _ in
                guard let message else { return }
                let text = String(cString: message).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                let isNoise = text.contains("Core ML model")
                    || text.hasPrefix("whisper_")
                    || text.hasPrefix("ggml_")
                    || text.hasPrefix("register_")
                guard !isNoise else { return }
                print("🧠 whisper: \(text)")
            }, nil)

            var params = whisper_context_default_params()
            // Metal on Apple Silicon; harmless where unavailable.
            params.use_gpu = true

            let start = Date()
            guard let ctx = whisper_init_from_file_with_params(url.path, params) else {
                throw TranscriptionError.modelLoadFailed(url.lastPathComponent)
            }
            let elapsed = Date().timeIntervalSince(start)
            print("🧠 Whisper model loaded in \(String(format: "%.2f", elapsed))s (\(url.lastPathComponent))")

            context = ctx
            hasLoadedOnce = true
            publish(.ready)
            armIdleEviction()
            return ctx
        } catch {
            loadFailure = error
            publish(.failed((error as? LocalizedError)?.errorDescription ?? "Speech model failed to load"))
            throw error
        }
    }

    // MARK: - Inference

    /// Convert one of whisper's segment timestamps to seconds.
    ///
    /// whisper.cpp reports segment times in units of 10 ms - its own `to_timestamp`
    /// helper multiplies by 10 to reach milliseconds. `whisper.h` does not say so:
    /// the header comment above `whisper_full_get_segment_t0` reads only "Get the
    /// start and end time of the specified segment", so the unit is an upstream
    /// convention rather than a documented contract. `MeetingTurnTests` pins it, and
    /// `secondsPerTick` is the single place to change if a future whisper release
    /// moves it.
    ///
    /// Being wrong here fails safe in the direction that matters. Too small a factor
    /// makes every gap look tiny, so `TurnSegmenter` returns one turn per window  - 
    /// which is precisely the single-blob behaviour turns replaced. The opposite
    /// error splits on every segment, which is immediately visible.
    static let secondsPerTick: TimeInterval = 0.01

    static func seconds(fromTicks ticks: Int64) -> TimeInterval {
        TimeInterval(ticks) * secondsPerTick
    }

    /// Flatten segments back into one string, the way whisper's own example does.
    ///
    /// A plain concatenation with no separator: each segment carries its own leading
    /// space, so joining on " " would double them and joining trimmed segments would
    /// run the words together.
    static func joined(_ segments: [TimedSegment]) -> String {
        segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Run inference. `isStale`, when supplied, is polled during compute and
    /// aborts the run as soon as it returns true (preview path only).
    private static func run(
        _ ctx: OpaquePointer,
        samples: [Float],
        bias: String = "",
        isStale: (() -> Bool)? = nil
    ) throws -> [TimedSegment] {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.single_segment = false
        // Suppress the blank-audio hallucinations whisper is prone to. The
        // recorder already trims silence, but a near-silent clip can still
        // produce invented text.
        params.suppress_blank = true
        params.no_speech_thold = 0.6
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))

        // Abort hook for previews. `abort_callback` is a C function pointer, so it
        // cannot capture context - the Swift closure is passed through
        // `user_data` and read back inside. The box is a local, and
        // `whisper_full` is synchronous, so it outlives every invocation.
        var abortBox: StaleCheck?
        if let isStale {
            abortBox = StaleCheck(isStale)
            params.abort_callback = { userData in
                guard let userData else { return false }
                return Unmanaged<StaleCheck>.fromOpaque(userData)
                    .takeUnretainedValue().check()
            }
            params.abort_callback_user_data = Unmanaged.passUnretained(abortBox!).toOpaque()
        }

        // Pin the language to English, for every tier.
        //
        // Correct even on the multilingual Large Turbo model: pinning skips the
        // language-detection pass (faster, and it cannot mis-detect accented
        // English as another language), while the model's multilingual *training*
        // still helps - that is what makes it better on non-native accents, not
        // runtime detection. Utter is English-only by design; the one time this
        // was relaxed, other languages produced confidently wrong romanised text
        // rather than an error.
        let language = "en"
        let status: Int32 = language.withCString { lang in
            params.language = lang
            // Bias toward the user's dictionary. `withCString` keeps the buffer
            // alive only for its closure body, so `whisper_full` must be called
            // *inside* it - `params.initial_prompt` is a borrowed pointer, not a
            // copy, and hoisting the call out would leave it dangling.
            //
            // The empty case skips the nesting entirely rather than passing "",
            // which whisper would still tokenize into a leading token.
            guard !bias.isEmpty else {
                return whisper_full(ctx, params, samples, Int32(samples.count))
            }
            return bias.withCString { prompt in
                params.initial_prompt = prompt
                // Pin the prompt to every decode window.
                //
                // Without this, whisper appends the prompt to `prompt_past1`, the
                // *rolling* context, and each window takes only that buffer's
                // tail. Decoded text accumulates behind the prompt and evicts it,
                // so on a long utterance the bias silently stops applying after
                // the first ~30s window - exactly where a long dictation needs it
                // most. `carry_initial_prompt` keeps it in the static buffer that
                // is prepended to every window instead.
                params.carry_initial_prompt = true
                return whisper_full(ctx, params, samples, Int32(samples.count))
            }
        }
        // A deliberately aborted preview reports failure. That is the expected
        // outcome for stale work, not an error worth surfacing - distinguish it
        // from a genuine one so `previewTranscribe` stays quiet while real
        // transcription still reports properly.
        if status != 0 {
            if abortBox?.check() == true { return [] }
            throw TranscriptionError.inferenceFailed(Int(status))
        }
        // Keep the box alive until after the call. Without this, ARC is free to
        // release it once the last *Swift* reference dies, while whisper still
        // holds the raw pointer - `passUnretained` deliberately doesn't retain.
        withExtendedLifetime(abortBox) {}

        var segments: [TimedSegment] = []
        for i in 0..<whisper_full_n_segments(ctx) {
            guard let text = whisper_full_get_segment_text(ctx, i) else { continue }
            segments.append(
                TimedSegment(
                    start: seconds(fromTicks: whisper_full_get_segment_t0(ctx, i)),
                    end: seconds(fromTicks: whisper_full_get_segment_t1(ctx, i)),
                    text: String(cString: text)
                )
            )
        }
        return segments
    }

    /// Reference box so a Swift closure can reach a C callback through `user_data`.
    ///
    /// A class, not a struct: the whole point is a stable address to hand to C.
    private final class StaleCheck {
        private let body: () -> Bool
        init(_ body: @escaping () -> Bool) { self.body = body }
        func check() -> Bool { body() }
    }

    // MARK: - WAV decoding

    /// Decode the 16 kHz mono 16-bit PCM WAV produced by AudioRecorder into the
    /// normalized float samples whisper.cpp expects.
    ///
    /// This parses the RIFF chunk table rather than assuming a fixed 44-byte
    /// header - AudioRecorder's own writer emits exactly that layout today, but
    /// silently misreading a header would surface as garbled transcripts rather
    /// than a clean error.
    /// Decode headerless 16 kHz mono 16-bit PCM - what `AudioRecorder` accumulates
    /// in its buffer before a WAV header is prepended at stop. The preview path
    /// reads that buffer directly, so it never pays for header construction.
    static func pcmSamples(fromRawPCM data: Data) throws -> [Float] {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { throw TranscriptionError.invalidAudio }

        var samples = [Float](repeating: 0, count: sampleCount)
        data.withUnsafeBytes { raw in
            for i in 0..<sampleCount {
                // Bytewise for the same reason as the WAV path: the buffer is not
                // guaranteed 2-byte aligned.
                let lo = Int16(raw[i * 2])
                let hi = Int16(bitPattern: UInt16(raw[i * 2 + 1]) << 8)
                samples[i] = max(-1.0, Float(hi | lo) / 32768.0)
            }
        }
        return samples
    }

    static func pcmSamples(fromWAV data: Data) throws -> [Float] {
        guard data.count > 44,
              data.starts(with: Array("RIFF".utf8)),
              data[8..<12].elementsEqual(Array("WAVE".utf8))
        else { throw TranscriptionError.invalidAudio }

        func u32(_ offset: Int) -> Int {
            Int(data[offset]) | Int(data[offset + 1]) << 8
                | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24
        }

        var cursor = 12
        while cursor + 8 <= data.count {
            let chunkID = data[cursor..<cursor + 4]
            let chunkSize = u32(cursor + 4)
            let body = cursor + 8

            if chunkID.elementsEqual(Array("data".utf8)) {
                let end = min(body + chunkSize, data.count)
                guard end > body else { throw TranscriptionError.invalidAudio }

                let pcm = data[body..<end]
                let sampleCount = pcm.count / 2
                guard sampleCount > 0 else { throw TranscriptionError.invalidAudio }

                var samples = [Float](repeating: 0, count: sampleCount)
                pcm.withUnsafeBytes { raw in
                    for i in 0..<sampleCount {
                        // Little-endian Int16 → [-1, 1]. Read bytewise rather
                        // than binding to Int16, which would require the buffer
                        // to be 2-byte aligned.
                        let lo = Int16(raw[i * 2])
                        let hi = Int16(bitPattern: UInt16(raw[i * 2 + 1]) << 8)
                        let value = hi | lo
                        samples[i] = max(-1.0, Float(value) / 32768.0)
                    }
                }
                return samples
            }

            // Chunks are word-aligned: odd sizes carry a trailing pad byte.
            cursor = body + chunkSize + (chunkSize % 2)
        }
        throw TranscriptionError.invalidAudio
    }
}
