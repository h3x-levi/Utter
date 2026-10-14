import CoreAudio
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
/// participants apart, and does not pretend to. On speakers the mic hears the call
/// too, so mic turns that repeat "Others" are dropped (`MeetingTranscript.isEcho`).
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
///   * **The two streams are merged on the host clock.** Every captured buffer is
///     stamped with the host time of its first sample (`SampleClock`), so each turn has
///     a real start time whichever stream it came from. A turn is written only once both
///     streams have been transcribed past it, so a reply never lands above what it
///     answered. Error is tens of milliseconds, far below a turn.
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
    /// The call is playing on speakers, so the mic hears it as well.
    @Published package private(set) var onSpeakers = false
    /// Off the record: both captures are closed and nothing is transcribed until resume.
    @Published package private(set) var isPaused = false
    /// Why the last resume could not reopen the captures.
    @Published package private(set) var resumeProblem: String?
    /// The meeting that just ended, for the Library's summary offer. Cleared by `dismissFinished`.
    @Published package private(set) var finishedNoteID: UUID?

    /// A meeting is being recorded or finished; `.failed` is not, though it is not `.idle` either.
    package var isCapturing: Bool { state == .recording || state == .finishing }

    /// Whether sound goes out of speakers the mic can hear.
    package static var playsThroughSpeakers: Bool { ProcessTapCapture.playsThroughSpeakers }

    /// The call ended and the recording stopped itself.
    package var onCallEnded: (() -> Void)?

    /// You (mic) and Others (call) levels, 0...1, for the banner's meters. Reading resets the call peak.
    package var levels: (you: Float, others: Float) {
        (isPaused ? 0 : recorder?.inputLevel ?? 0, isPaused ? 0 : systemAudio.meterLevel)
    }

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
    /// Recent "Others" turns, to tell the call heard through the speakers from the user's own words.
    private var recentOthers: [(start: TimeInterval, end: TimeInterval, text: String)] = []
    /// Turns waiting until both streams are transcribed past them, at host-clock seconds.
    private var pending: [(at: TimeInterval, turn: (role: SpeakerRole, text: String))] = []
    /// Recorded seconds before the current run; `startedAt` is the current run's start.
    private var recordedBefore: TimeInterval = 0
    /// What to tap and which mic to open, kept for resume.
    private var tapping: [AudioObjectID] = []
    private var micDevice: AudioDeviceID?
    /// The call, watched so the recording stops when the call does.
    private var watchedCall: CallSource?
    private var callQuietSince: TimeInterval?
    private var transition: Task<Void, Never>?
    /// Where the meeting's note lives, set at start; every later write goes here.
    private var store = NoteStore.shared
    /// Whether the mic and the call tap are open right now, so closing never runs twice or not at all.
    private var capturesOpen = false

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
        await serially { [self] in
            await begin(recorder: recorder, transcriber: transcriber, store: store, source: source)
        }
    }

    private func begin(
        recorder: AudioRecorder,
        transcriber: TranscriptionService,
        store: NoteStore?,
        source: CallSource?
    ) async -> UUID? {
        let store = store ?? NoteStore.shared
        self.store = store
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
            return noteID
        }

        self.recorder = recorder
        self.transcriber = transcriber
        micFailures = 0
        systemFailures = 0
        heardOthers = false
        recentOthers = []
        pending = []
        recordedBefore = 0
        isPaused = false
        resumeProblem = nil
        finishedNoteID = nil
        callQuietSince = nil
        let call = source ?? (CallDetector.audioInUseByOtherProcesses() ?? nil)
        watchedCall = call
        tapping = source.map { [$0.processObject] } ?? []
        micDevice = call.flatMap(CallDetector.microphone(of:))

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        let heading = CallSource.noteHeading(appName: source?.appName,
                                             when: fmt.string(from: Date()))
        let note = store.create(body: heading, source: .meeting)
        noteID = note.id

        if let problem = await openCaptures(recorder: recorder) {
            // Roll back the empty note: leaving a titled but contentless meeting
            // note behind after a failed start is worse than nothing.
            store.delete(id: note.id)
            noteID = nil
            state = .failed(problem)
            return nil
        }

        startedAt = Date()
        state = .recording

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        return note.id
    }

    package enum StartOutcome: Equatable {
        case started(UUID)
        case refused(String)
    }

    /// The one way in for every surface: ask for what is needed, start, and say why not in a sentence.
    package func record(recorder: AudioRecorder, transcriber: TranscriptionService,
                        source: CallSource? = nil) async -> StartOutcome {
        if let why = Self.prepare() { return .refused(why) }
        if let id = await start(recorder: recorder, transcriber: transcriber, source: source) { return .started(id) }
        if case .failed(let why) = state { return .refused(why) }
        return .refused("Couldn\u{2019}t start the meeting recording.")
    }

    /// Stop recording, transcribe whatever is left, and finish the note. False when nothing was recording.
    @discardableResult
    package func stop() async -> Bool {
        await serially { [self] in
            guard state == .recording else { return false }
            state = .finishing
            timer?.invalidate()
            timer = nil

            // Let an in-flight drain finish before taking the tail, or both would work
            // from overlapping snapshots and double-append. `state` is already
            // `.finishing`, so `tick` cannot start another.
            await drainTask?.value
            drainTask = nil
            await closeCaptures()
            if let noteID {
                store.setRecordedSeconds(recordedBefore + (startedAt.map { Date().timeIntervalSince($0) } ?? 0), of: noteID)
                store.writeToDisk()
            }

            state = .idle
            elapsed = 0
            startedAt = nil
            isPaused = false
            resumeProblem = nil
            watchedCall = nil
            finishedNoteID = noteID
            noteID = nil
            self.recorder = nil
            transcriber = nil
            return true
        }
    }

    /// Go off the record: transcribe what was said so far, then close the mic and the call tap.
    package func pause() async {
        await serially { [self] in
            guard state == .recording, !isPaused else { return }
            isPaused = true
            recordedBefore += startedAt.map { Date().timeIntervalSince($0) } ?? 0
            startedAt = nil
            await drainTask?.value
            drainTask = nil
            await closeCaptures()
        }
    }

    package func resume() async {
        await serially { [self] in
            guard state == .recording, isPaused, let recorder else { return }
            if let problem = await openCaptures(recorder: recorder) {
                resumeProblem = problem
                return
            }
            resumeProblem = nil
            isPaused = false
            startedAt = Date()
            callQuietSince = nil
        }
    }

    /// Start, pause, resume and stop run one at a time in the order pressed, so none of them
    /// opens or closes captures while another is halfway through doing the same.
    private func serially<T: Sendable>(_ work: @escaping @MainActor () async -> T) async -> T {
        let previous = transition
        let task = Task { @MainActor in
            await previous?.value
            return await work()
        }
        transition = Task { _ = await task.value }
        return await task.value
    }

    package func dismissFinished() { finishedNoteID = nil }

    /// Write turns still waiting for the other stream, for a quit mid-meeting.
    package func flushPending() {
        guard let noteID, !pending.isEmpty else { return }
        let speakers = store.notes.first { $0.id == noteID }?.speakerLabels ?? .default
        let ready = MeetingTranscript.release(&pending, before: .infinity)
        store.append(ready.map { MeetingTranscript.line(speakers[$0.turn.role], $0.turn.text) }.joined(separator: "\n\n"),
                     to: noteID)
    }

    /// Open the call tap, then the mic. Returns the sentence to show when either fails.
    private func openCaptures(recorder: AudioRecorder) async -> String? {
        do {
            // Empty means "everything but Utter", which is what the ScreenCaptureKit path has always done.
            try await systemAudio.start(tapping: tapping)
        } catch {
            return error.localizedDescription
        }

        // The mic path is the existing recorder, with VAD disabled: a meeting has
        // long silences on the user's side and auto-stopping on them would end the
        // recording every time the user listened instead of talked.
        //
        // The result is checked, not discarded. `open` reports false when
        // the tap could not be opened *or* when it is already open: microphone denied
        // would run a meeting with only "Others", and a hands-free dictation holding
        // the tap would have its audio transcribed into the meeting and consumed.
        // Opened off the main thread: a Bluetooth or USB mic can take seconds to start.
        let opened = await withCheckedContinuation { done in
            recorder.open(device: micDevice) { done.resume(returning: $0) }
        }
        guard opened else {
            await systemAudio.stop()
            return "Couldn\u{2019}t open the microphone. Stop any dictation in progress, "
                + "check Microphone access, then try again."
        }
        capturesOpen = true
        return nil
    }

    /// Close both captures and transcribe everything they still hold.
    private func closeCaptures() async {
        guard capturesOpen else { return }
        capturesOpen = false
        await systemAudio.stop()
        // Taken before the stop: `stopRecording` clears the buffer and its clock.
        let micTail = recorder?.bufferSnapshot() ?? CaptureBuffer()
        recorder?.stopRecording { _ in }
        await transcribeWindows(mic: micTail, system: systemAudio.bufferSnapshot, flushAll: true)
    }

    // MARK: - Rolling transcription

    private func tick() {
        guard state == .recording else { return }
        elapsed = Int(recordedBefore + (startedAt.map { Date().timeIntervalSince($0) } ?? 0))
        if watchCallEnded() { return }
        guard !isPaused else { return }

        if systemAudio.heardSound { heardOthers = true }
        onSpeakers = ProcessTapCapture.playsThroughSpeakers

        // Only wake the transcriber once a full window has accumulated on either
        // side; otherwise this would fire every second. Checked before copying: a
        // snapshot shares the live buffer, so the next append has to copy all of it.
        //
        // Compared against the whole buffer, not against a read cursor: both buffers
        // are trimmed from the front by `consume`, so anything still in them is by
        // definition not yet transcribed.
        let window = windowSeconds * bytesPerSecond
        guard !isDraining else { return }
        guard (recorder?.capturedByteCount ?? 0) >= window || systemAudio.sampleByteCount >= window else { return }

        let mic = recorder?.bufferSnapshot() ?? CaptureBuffer()
        let system = systemAudio.bufferSnapshot
        isDraining = true
        drainTask = Task { @MainActor in
            await transcribeWindows(mic: mic, system: system, flushAll: false)
            isDraining = false
        }
    }

    /// Stops the recording once the call app has done no audio for `CallPresence.releaseAfter`,
    /// the same wait that ends a call for the detector, so a mute never trips it.
    private func watchCallEnded() -> Bool {
        guard let watchedCall else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        if CallDetector.callIsAlive(watchedCall) {
            callQuietSince = nil
            return false
        }
        guard let since = callQuietSince else {
            callQuietSince = now
            return false
        }
        guard now - since >= CallPresence.releaseAfter else { return false }
        self.watchedCall = nil
        Task { @MainActor in
            if await stop() { onCallEnded?() }
        }
        return true
    }

    /// Transcribe any complete windows (or everything, when finishing) and append
    /// the text to the meeting note.
    private func transcribeWindows(
        mic: CaptureBuffer,
        system: CaptureBuffer,
        flushAll: Bool
    ) async {
        guard let noteID, let transcriber else { return }
        let window = windowSeconds * bytesPerSecond

        // Below roughly a second there is nothing recognisable, and Whisper on a
        // sliver of audio tends to hallucinate a plausible sentence.
        let minimumBytes = bytesPerSecond

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
            failures: Int,
            seconds: (Int) -> TimeInterval?
        ) async -> (consumed: Int, failures: Int, turns: [(at: TimeInterval, end: TimeInterval, text: String)]) {
            let label = role.rawValue
            var turnTexts: [(at: TimeInterval, end: TimeInterval, text: String)] = []
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
                    return (cursor, failures, turnTexts)
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
                    let base = seconds(cursor - take) ?? SampleClock.now
                    turnTexts.append(contentsOf: turns.map { (base + $0.start, base + max($0.end, $0.start), $0.text) })
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
                    // A flush has no next pass (the buffer is cleared after it), so retry now.
                    if flushAll { continue }
                    // Stop without advancing, so the window survives in the buffer
                    // and the next pass retries it. Returning rather than continuing
                    // also avoids hammering a transcriber that is currently broken.
                    return (cursor, failures, turnTexts)
                }
            }
        }

        let systemDrain = await drain(system.data, role: .others, failures: systemFailures) { system.seconds(at: $0) }
        let micDrain = await drain(mic.data, role: .you, failures: micFailures) { mic.seconds(at: $0) }
        // Read the labels after the drains, which take seconds: a rename made meanwhile has to apply.
        let speakers = store.notes.first { $0.id == noteID }?.speakerLabels ?? .default
        recentOthers += systemDrain.turns.map { ($0.at, $0.end, $0.text) }
        if let latest = recentOthers.last?.end { recentOthers.removeAll { $0.end < latest - 120 } }
        // Echo is the call said at the same moment, give or take the speaker-to-mic and clock slack.
        let mine = micDrain.turns.filter { turn in
            let heard = recentOthers.filter { $0.end + 2 >= turn.at && $0.start - 2 <= turn.end }
            return !MeetingTranscript.isEcho(turn.text, of: heard.map(\.text).joined(separator: " "))
        }
        pending += mine.map { ($0.at, (SpeakerRole.you, $0.text)) }
            + systemDrain.turns.map { ($0.at, (SpeakerRole.others, $0.text)) }

        // Each stream is transcribed up to its first untranscribed byte; one with nothing
        // buffered (a mic before the first word) holds nothing back.
        let micUpTo = mic.data.isEmpty ? SampleClock.now : mic.seconds(at: micDrain.consumed) ?? SampleClock.now
        let systemUpTo = system.data.isEmpty ? SampleClock.now : system.seconds(at: systemDrain.consumed) ?? SampleClock.now
        // Held for the slower stream, but never more than two windows, so one that stalls can't freeze the note.
        let releaseBefore = max(min(micUpTo, systemUpTo), max(micUpTo, systemUpTo) - 2 * Double(windowSeconds))
        let ready = MeetingTranscript.release(&pending, before: flushAll ? .infinity : releaseBefore)
        let additions = ready.map { MeetingTranscript.line(speakers[$0.turn.role], $0.turn.text) }
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

    /// Peak below which a whole window is treated as silence (about -41 dBFS, under the dictation VAD's floor).
    static let speechFloor: UInt16 = 300

    private func transcribe(_ pcm: Data, using service: TranscriptionService) async -> WindowOutcome {
        // Most of a meeting is one side listening: skipping whisper there saves the inference and
        // the "[BLANK_AUDIO]" or "Thank you." it invents for silence.
        let peak = pcm.withUnsafeBytes { raw in
            raw.bindMemory(to: Int16.self).baseAddress.map { AudioRecorder.peakAmplitude($0, count: pcm.count / 2) } ?? 0
        }
        guard peak >= Self.speechFloor, let wav = AudioRecorder.wav(fromPCM: pcm) else { return .silence }
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
