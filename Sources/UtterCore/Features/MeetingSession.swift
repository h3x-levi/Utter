import Foundation

/// Records a meeting and turns it into a note as it goes.
///
/// Two audio sources are captured at once - the microphone (the user) and system
/// output (everyone else) - and transcribed in rolling windows rather than in one
/// pass at the end. Windowing matters for three reasons:
///
///   * A one-hour meeting transcribed in a single call would hold an hour of
///     samples in memory and produce nothing until it finished.
///   * Whisper's accuracy degrades on very long inputs, and its 30-second decode
///     window means long audio is chunked internally anyway.
///   * The note fills in as the meeting runs, so a crash or a forced quit loses
///     one window rather than the whole meeting.
///
/// Each source is transcribed separately and labelled, which gives "You" vs
/// "Others" for free - they are literally different audio streams. That is a
/// *source* distinction, not speaker diarisation: this cannot tell two remote
/// participants apart, and does not pretend to.
///
/// Two consequences of that follow the transcript all the way to the note, and both
/// are deliberate restraint rather than unfinished work:
///
///   * **Turns are split on silence, never labelled by voice.** Each window is cut
///     into turns at gaps whisper actually measured (`TurnSegmenter`), so several
///     contributions inside one 30-second window stop being glued into a single
///     paragraph. Every turn from a source still carries the *same* label. A pause is
///     not evidence that the voice changed - people breathe, and two people can swap
///     without one - so numbering turns "Speaker 1/2/3" off pause timings would be
///     inventing an attribution. There is no on-device Apple API that could do it
///     properly either: the macOS 26.5 `SpeechAnalyzer` exposes exactly
///     `DictationTranscriber`, `SpeechTranscriber` and `SpeechDetector`, and nothing
///     resembling speaker identity.
///   * **The two streams are not merged into one chronological conversation.**
///     Tempting, and wrong with what is measurable here. The only clock available is
///     each stream's own sample count, the two captures start at different moments by
///     an unmeasured margin (`SystemAudioCapture.start` awaits a permission-gated
///     content enumeration before the mic tap even opens), a dropped
///     `ScreenCaptureKit` packet shifts one clock against the other permanently, and
///     each stream advances its own retry cursor so one can be a whole window ahead of
///     the other. Interleaving on that would fabricate a turn order - asserting who
///     replied to whom. Source-major ordering is visibly coarse, which is the honest
///     failure.
///
/// Labels are the user's to change. `MeetingSpeakers` is stored on the note and read
/// fresh on every window, so renaming "Others" to a name mid-meeting applies from the
/// next window on, and `NoteStore.renameSpeaker` rewrites the headings already
/// written.
///
/// **Audio never touches the disk.** Samples are converted, transcribed, and
/// dropped; only text is persisted. This is the same invariant the dictation path
/// holds, and it is the reason meeting capture is defensible at all.
@MainActor
package final class MeetingSession: ObservableObject {
    package init() {}

    /// Length of each transcription window. Long enough that sentences aren't cut
    /// mid-clause, short enough that the note visibly grows during a meeting.
    private let windowSeconds = 30

    /// 16 kHz, Int16 mono → bytes per second.
    private let bytesPerSecond = 16_000 * 2

    package enum State: Equatable {
        case idle
        case recording
        /// Transcribing the tail after the user stopped.
        case finishing
        case failed(String)
    }

    @Published package private(set) var state: State = .idle
    @Published package private(set) var elapsed: Int = 0
    /// True once any audio has actually been heard on the system tap. A silent tap
    /// is the most likely failure and looks identical to a working one otherwise.
    @Published package private(set) var heardOthers = false

    private let systemAudio = SystemAudioCapture()
    private var recorder: AudioRecorder?
    private var transcriber: TranscriptionService?
    package private(set) var noteID: UUID?

    private var timer: Timer?
    /// True while a `transcribeWindows` pass is running.
    ///
    /// `tick()` fires every second but a 30s window takes several seconds of
    /// inference, so without this the next tick snapshots the same audio and
    /// transcribes it again - appending the segment to the note twice, then calling
    /// `consume()` a second time and discarding 30s that was never transcribed.
    private var isDraining = false

    /// The in-flight drain, so `stop()` can await it instead of polling `isDraining`.
    ///
    /// `while isDraining { await Task.yield() }` was correct but spun the main actor
    /// flat out for the whole of the last window's inference - several seconds of one
    /// core burnt at the exact moment the user has just pressed Stop and is watching
    /// "Finishing the transcript…". Awaiting the task suspends instead.
    private var drainTask: Task<Void, Never>?

    /// Consecutive failed windows, counted **per stream**.
    ///
    /// A failed window is left in the buffer to be retried, which is right for a
    /// transient fault - but if the transcriber stays broken the same window would
    /// be retried forever while audio piles up behind it, and the bounded-memory
    /// guarantee would be gone. After `maxWindowRetries` the window is given up on
    /// and consumed, so the meeting keeps moving.
    ///
    /// One counter per stream, not one shared: the mic and system drains run back to
    /// back over the same budget, so a single counter had them eating each other's
    /// retries - with a broken transcriber the mic gave up after two attempts and
    /// system audio after four, neither of them the three the constant promises.
    private var micFailures = 0
    private var systemFailures = 0
    private let maxWindowRetries = 3
    private var startedAt: Date?

    /// Whether meeting capture can run at all, and why not if it can't.
    ///
    /// This is the *Screen Recording* answer specifically, which is what the Permissions card and the
    /// onboarding checklist report. It is no longer the whole story - see `prepare`, which is what a
    /// caller about to start a capture should ask.
    static var permission: SystemAudioCapture.PermissionState {
        SystemAudioCapture.permissionState()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        SystemAudioCapture.requestPermission()
    }

    /// Clear the way for a capture, asking for whatever is still needed. Returns nil to go ahead, or
    /// the sentence to put in front of the user.
    ///
    /// One function rather than a `switch` at each call site, because there were two of them - the
    /// offer card and the Notes screen - and they had already drifted: the offer card bailed when the
    /// Screen Recording request came back false and the Notes screen carried on regardless, so the
    /// same denial produced an explanation in one place and a half-recorded meeting in the other.
    package static func prepare() -> String? {
        // The per-process tap route needs no Screen Recording grant at all - a different and much
        // narrower permission, asked for by starting - so when it is available there is nothing to
        // preflight and nothing to explain. See `SystemAudioCapture.processTapAvailable`.
        if SystemAudioCapture.processTapAvailable { return nil }

        switch permission {
        case .granted:
            return nil
        case .notDetermined:
            // Ask, and *read the answer*. `permissionState()` is `CGPreflightScreenCaptureAccess`,
            // which returns a Bool, so it can only ever say granted or not-yet-asked - a user who
            // denied Screen Recording arrives here, not in `.denied`. `requestPermission` returns
            // false both when the user says no and when macOS has already asked once and will not
            // ask again, and in both cases the route left is System Settings *and a relaunch*. So
            // "Allow Screen Recording, then try again" was wrong twice over: trying again in this
            // launch cannot work, and there was nothing left to try it on. The app's own denied copy
            // already says the true thing, including the restart, so it is reused rather than
            // paraphrased.
            return requestPermission() ? nil : SystemAudioCapture.PermissionState.denied.message
        case .denied, .unsupported:
            return permission.message
        }
    }

    // MARK: - Lifecycle

    /// Begin recording into a new note.
    ///
    /// Returns the note's id so the caller can select it - the note is created up
    /// front rather than at the end, so partial transcripts have somewhere to land
    /// from the first window.
    /// `store` is optional rather than defaulted to `.shared`: a default argument is
    /// evaluated in the *caller's* isolation, so naming a main-actor-isolated
    /// singleton there is a warning today and an error in the Swift 6 language mode.
    /// Resolving it inside the body says the same thing where it is actually true.
    /// `source` is the app the call was detected in, when there was one and it could be named. It
    /// does two things and neither of them is required: it titles the note ("Zoom meeting - …"), and
    /// it is what lets the capture tap *only that process* instead of the whole system mix. A capture
    /// started from the Notes screen passes nil and gets the old behaviour of both.
    package func start(
        recorder: AudioRecorder,
        transcriber: TranscriptionService,
        store: NoteStore? = nil,
        source: CallSource? = nil
    ) async -> UUID? {
        let store = store ?? NoteStore.shared
        // Retry from a failure, not just from rest.
        //
        // `.failed` was terminal: nothing assigned `.idle` again, and the UI only
        // draws the Record button in the `.idle` branch - so one failed start
        // (Screen Recording not yet granted, which is the *normal* first-run path)
        // killed meeting capture until the app was relaunched.
        switch state {
        case .idle, .failed:
            state = .idle
        case .recording, .finishing:
            return nil
        }

        self.recorder = recorder
        self.transcriber = transcriber
        micFailures = 0
        systemFailures = 0
        heardOthers = false

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        let heading = CallSource.noteHeading(appName: source?.appName,
                                             when: fmt.string(from: Date()))
        let note = store.create(body: heading, source: .meeting)
        noteID = note.id

        do {
            // The process holding the call, when one was identified. Empty means "everything but
            // Utter", which is what the ScreenCaptureKit path has always done.
            try await systemAudio.start(tapping: source.map { [$0.processObject] } ?? [])
        } catch {
            // Roll back the empty note: leaving a titled but contentless meeting
            // note behind after a failed start is worse than nothing.
            store.delete(id: note.id)
            noteID = nil
            state = .failed(error.localizedDescription)
            return nil
        }

        // The mic path is the existing recorder, with VAD disabled: a meeting has
        // long silences on the user's side and auto-stopping on them would end the
        // recording every time the user listened instead of talked.
        //
        // The result is checked, not discarded. `startRecording` returns false when
        // the tap could not be opened *or* when it is already open, and both were
        // silently ignored here:
        //
        //   * Microphone denied → the meeting ran with only "Others" transcribed,
        //     while the UI said "Recording this meeting" for an hour.
        //   * A hands-free dictation already holding the tap → the meeting adopted
        //     that session's buffer, `tick()` transcribed the user's dictation into
        //     the meeting note and then `consume()`d it out of the buffer, so the
        //     dictation returned a truncated transcript to the app it was aimed at.
        //     `stop()` would then have torn the engine down under it.
        guard recorder.startRecording() else {
            await systemAudio.stop()
            store.delete(id: note.id)
            noteID = nil
            state = .failed(
                "Couldn\u{2019}t open the microphone. Stop any dictation in progress, "
                + "check Microphone access, then try again."
            )
            return nil
        }

        startedAt = Date()
        state = .recording

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        return note.id
    }

    /// Stop recording, transcribe whatever is left, and finish the note.
    package func stop(store: NoteStore? = nil) async {
        let store = store ?? NoteStore.shared
        guard state == .recording else { return }
        state = .finishing
        timer?.invalidate()
        timer = nil

        // Let an in-flight drain finish before taking the tail, or both would work
        // from overlapping snapshots and double-append. `state` is already
        // `.finishing`, so `tick` cannot start another.
        await drainTask?.value
        drainTask = nil

        let systemTail = await systemAudio.stop()

        // Close the mic. The completion hands back trimmed WAV, but the rolling
        // windows work in raw PCM, so the tail is taken from the snapshot instead.
        let micTail = recorder?.audioSnapshot() ?? Data()
        recorder?.stopRecording { _ in }

        await transcribeWindows(mic: micTail, system: systemTail, flushAll: true, store: store)

        state = .idle
        elapsed = 0
        startedAt = nil
        noteID = nil
        recorder = nil
        transcriber = nil
    }

    // MARK: - Rolling transcription

    private func tick() {
        guard state == .recording else { return }
        if let startedAt { elapsed = Int(Date().timeIntervalSince(startedAt)) }

        if systemAudio.peakLevel > 0.01 { heardOthers = true }

        // Only wake the transcriber once a full window has accumulated on either
        // side; otherwise this would fire every second. Checked before copying: a
        // snapshot shares the live buffer, so the next append has to copy all of it.
        //
        // Compared against the whole buffer, not against a read cursor: both buffers
        // are trimmed from the front by `consume`, so anything still in them is by
        // definition not yet transcribed.
        let window = windowSeconds * bytesPerSecond
        guard !isDraining else { return }
        guard (recorder?.audioByteCount ?? 0) >= window || systemAudio.sampleByteCount >= window else { return }

        let mic = recorder?.audioSnapshot() ?? Data()
        let system = systemAudio.samples
        isDraining = true
        drainTask = Task { @MainActor in
            await transcribeWindows(mic: mic, system: system, flushAll: false)
            isDraining = false
        }
    }

    /// Transcribe any complete windows (or everything, when finishing) and append
    /// the text to the meeting note.
    private func transcribeWindows(
        mic: Data,
        system: Data,
        flushAll: Bool,
        store: NoteStore? = nil
    ) async {
        let store = store ?? NoteStore.shared
        guard let noteID, let transcriber else { return }
        let window = windowSeconds * bytesPerSecond

        // Read the labels once per pass rather than once per meeting: a rename made
        // while the meeting is still running has to take effect, and re-reading here is
        // a dictionary-free array lookup against a handful of notes.
        let speakers = store.notes.first { $0.id == noteID }?.speakerLabels ?? .default

        // Below roughly a second there is nothing recognisable, and Whisper on a
        // sliver of audio tends to hallucinate a plausible sentence.
        let minimumBytes = bytesPerSecond

        var additions: [String] = []

        // Takes the stream's retry count and returns it alongside the byte count,
        // rather than mutating actor state through `inout` - passing isolated state as
        // `inout` across an `await` is exactly the race Swift's actor checking
        // rejects, since another hop could observe the half-updated value.
        //
        // Reading starts at 0 every pass: `consume` trims each buffer from the front,
        // so a window that was transcribed is gone and one that failed is still at
        // the head waiting to be retried.
        func drain(
            _ data: Data,
            role: SpeakerRole,
            failures: Int
        ) async -> (consumed: Int, failures: Int) {
            let label = speakers[role]
            var cursor = 0          // also the number of bytes consumed, since the
                                    // caller trims the buffer front afterwards
            var failures = failures
            while true {
                let available = data.count - cursor
                let take: Int
                if available >= window {
                    take = window
                } else if flushAll, available >= minimumBytes {
                    take = available
                } else {
                    return (cursor, failures)
                }

                let chunk = data.subdata(in: cursor..<(cursor + take))

                switch await transcribe(chunk, using: transcriber) {
                case .turns(let turns):
                    failures = 0
                    cursor += take
                    // One paragraph per turn, each carrying the same label. The blank
                    // line between them is the *only* thing separating two people who
                    // spoke in the same window - it says "there was a real pause here"
                    // and stops short of saying who filled it.
                    additions.append(contentsOf: turns.map { MeetingTranscript.line(label, $0.text) })
                case .silence:
                    // Nothing was said. Consume it - there is nothing to keep, and
                    // holding silent audio would stall the buffer forever.
                    cursor += take
                case .failed:
                    failures += 1
                    guard failures <= maxWindowRetries else {
                        // Give up on this window rather than stalling the meeting
                        // and growing the buffer without bound.
                        print("⚠️ Dropping a \(label) window after \(maxWindowRetries) failed attempts")
                        failures = 0
                        cursor += take
                        continue
                    }
                    // Stop without advancing, so the window survives in the buffer
                    // and the next pass retries it. Returning rather than continuing
                    // also avoids hammering a transcriber that is currently broken.
                    return (cursor, failures)
                }
            }
        }

        let micDrain = await drain(mic, role: .you, failures: micFailures)
        let systemDrain = await drain(system, role: .others, failures: systemFailures)
        micFailures = micDrain.failures
        systemFailures = systemDrain.failures
        let micConsumed = micDrain.consumed
        let systemConsumed = systemDrain.consumed

        // Release the audio we just transcribed instead of carrying it for the rest
        // of the meeting. At 32 kB/s per stream an untrimmed three-hour call would
        // sit on ~690 MB of samples that had already been read. Trimming from the
        // front is what lets the next pass start reading at zero again.
        if micConsumed > 0 { recorder?.consume(micConsumed) }
        if systemConsumed > 0 { systemAudio.consume(systemConsumed) }

        guard !additions.isEmpty else { return }
        store.append(additions.joined(separator: "\n\n"), to: noteID)
        // Persist each window as it lands: the point of windowing is that an
        // interrupted meeting keeps everything up to that moment.
        store.writeToDisk()
    }

    /// The outcome of transcribing one window.
    ///
    /// "Nothing was said" and "the transcriber broke" used to collapse into `nil`,
    /// and the caller advanced its cursor for both - so a transient whisper failure
    /// (the Metal context is invalidated whenever the user switches speech model)
    /// silently destroyed 30 seconds of real speech that then no longer existed in
    /// the buffer. Silence is discardable; a failure is not.
    private enum WindowOutcome {
        /// One or more turns of speech. Never empty - an empty result is `.silence`.
        case turns([SpeechTurn])
        case silence
        case failed
    }

    private func transcribe(_ pcm: Data, using service: TranscriptionService) async -> WindowOutcome {
        guard let wav = AudioRecorder.wav(fromPCM: pcm) else { return .silence }
        do {
            let turns = try await service.transcribeTurns(audioData: wav)
            return turns.isEmpty ? .silence : .turns(turns)
        } catch {
            // One bad window must not end the meeting; the next one may be fine.
            // The audio is left in the buffer so the retry has something to read.
            print("⚠️ Meeting window failed to transcribe: \(error.localizedDescription)")
            return .failed
        }
    }

}
