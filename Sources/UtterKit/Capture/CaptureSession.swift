import Cocoa
import Combine
import os
import UtterCore

/// Runs `CaptureMachine`'s effects and owns the turn's live parts: mic, telemetry, preview,
/// pipeline and delivery. The only writer of the pill's state.
@MainActor
final class CaptureSession {
    private(set) var state = CaptureState()
    /// Bumped as each turn starts, so late work from an earlier one is dropped.
    private var turn = 0
    private static let log = Logger(subsystem: "utter.dictation.app", category: "capture")

    private let recorder: AudioRecorder
    private let transcriber: TranscriptionService
    private let pill: PillWindow
    private let meetingIsActive: () -> Bool
    private let suppressRelease: (Bool) -> Void
    private let celebrate: (String) -> Void

    private var expiry: DispatchWorkItem?
    /// The frontmost app when the turn started, to notice the user moving away before delivery.
    private var turnApp: pid_t?
    private var stoppedAt = Date()
    private var elapsedTimer: Timer?
    /// The live-preview polling loop, cancelled when recording stops.
    private var previewTask: Task<Void, Never>?
    private var levelObserver: AnyCancellable?
    private var loadObserver: AnyCancellable?
    private var recordingStart = Date()

    init(recorder: AudioRecorder, transcriber: TranscriptionService, pill: PillWindow,
         meetingIsActive: @escaping () -> Bool,
         suppressRelease: @escaping (Bool) -> Void,
         celebrate: @escaping (String) -> Void) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.pill = pill
        self.meetingIsActive = meetingIsActive
        self.suppressRelease = suppressRelease
        self.celebrate = celebrate
        pill.onCloseIsland = { [weak self] in self?.handle(.islandClosed) }
    }

    func holdBegan() { handle(.holdBegan(meetingActive: meetingIsActive())) }
    func holdEnded() { handle(.holdEnded) }
    func toggle(_ toggle: CaptureToggle) { handle(.toggle(toggle, meetingActive: meetingIsActive())) }
    // The pill may be ordered out ("show at all times" off), and a message doesn't bring it back by itself.
    func showError(_ message: String) { wakePill(); handle(.show(.error(message))) }
    func showNotice(_ message: String) { wakePill(); handle(.show(.notice(message))) }
    private func wakePill() { if !pill.isVisible { pill.orderFront(nil) } }

    private func expireMessage(after seconds: TimeInterval) {
        expiry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.handle(.messageExpired) }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
    func cancel() { handle(.cancel) }

    func handle(_ event: CaptureEvent) {
        let (next, effects) = CaptureMachine.next(state, event)
        if effects.contains(.startTurn) { Signposts.beginKeyDownToPill() }
        let shown = state.pill
        state = next
        if next.pill != shown { pill.setState(next.pill) }
        effects.forEach(run)
    }

    private func handle(_ event: CaptureEvent, from turn: Int) {
        if turn == self.turn { handle(event) }
    }

    /// False once Escape cancelled this turn or a newer one started: its work must not reach the user.
    private func isLive(_ turn: Int) -> Bool {
        guard turn == self.turn, case .processing = state.phase else { return false }
        return true
    }

    /// Mirror the engine's load state, so the first launch reads "Getting ready" instead of
    /// inviting a dictation that would just queue.
    func observeModelLoad() {
        let local = transcriber.localProvider
        loadObserver = local.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] load in
                ReadinessMonitor.shared.modelLoad = load
                self?.handle(.model(load))
            }
    }

    private func run(_ effect: CaptureEffect) {
        switch effect {
        case .startTurn:
            turn += 1
            turnApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
            SurroundingContext.prewarm()
            // Pause other audio so music doesn't bleed into the microphone.
            MediaControl.pauseIfPlaying()
            // Rebuilds an evicted whisper context (78-93 ms warm, ~7.7 s cold) while the user speaks.
            transcriber.warmUp()
            Task.detached(priority: .utility) { SentencePolish.prewarm() }
            if state.modelLoading { Self.log.info("Recording while the speech model finishes loading") }
        case .playStart:
            SoundPlayer.playStart()
        case .openMic(let vad):
            let turn = self.turn
            let onVoiceStopped: (() -> Void)? = vad ? { [weak self] in self?.handle(.voiceStopped, from: turn) } : nil
            recorder.open(onVoiceStopped: onVoiceStopped) { [weak self] started in
                if !started { self?.handle(.micFailed, from: turn) }
            }
        case .installVAD:
            let turn = self.turn
            recorder.installVoiceStoppedCallback { [weak self] in self?.handle(.voiceStopped, from: turn) }
        case .suppressRelease(let on):
            suppressRelease(on)
        case .startTelemetry:
            startTelemetry()
        case .stopTelemetry:
            stopTelemetry()
        case .startPreview:
            if previewTask == nil { startPreview() }
        case .closeMic:
            if state.destination == .app { TextInjector.prepareSnapshot() }
            stoppedAt = Date()
            let turn = self.turn
            closeMic { [weak self] audio in self?.handle(.audioReady(audio), from: turn) }
        case .discardMic:
            closeMic { _ in }
        case .resumeMedia:
            MediaControl.resumeIfPaused()
        case .transcribe(let audio):
            let turn = self.turn
            Task {
                do {
                    handle(.transcribed(try await transcriber.transcribe(audioData: audio)), from: turn)
                } catch {
                    Self.log.error("Transcription error: \(String(describing: error), privacy: .public)")
                    handle(.transcriptionFailed(Self.message(for: error)), from: turn)
                }
            }
        case .finish(let text):
            let turn = self.turn, destination = state.destination, appending = state.appendsToOpenNote
            Task {
                guard let outcome = await finish(text, to: destination, appending: appending, turn: turn) else { return }
                handle(.finished(outcome), from: turn)
            }
        case .playDone:
            SoundPlayer.playDone()
        case .playError:
            SoundPlayer.playError()
        case .endTurn:
            SurroundingContext.clearPrewarmed()
            TextInjector.discardSnapshot()
        case .expireMessage:
            expireMessage(after: 4)
        case .expireMessageSoon:
            expireMessage(after: 1.2)
        }
    }

    /// The stop chime and the media resume are skipped once a newer turn has taken the mic over.
    private func closeMic(then audioReady: @escaping (Data?) -> Void) {
        let turn = self.turn
        recorder.stopRecording(onClosed: { [weak self] in
            guard self?.turn == turn else { return }
            // Before transcription: waiting seconds for it would feel like the app forgot.
            MediaControl.resumeIfPaused()
            SoundPlayer.playStop()
        }, completion: audioReady)
    }

    // MARK: - Finishing a turn

    /// `nil` when the turn stopped being live before anything reached the user.
    private func finish(_ raw: String, to destination: CaptureDestination, appending: Bool,
                        turn: Int) async -> CaptureOutcome? {
        let pipeline = DictationPipeline.live()
        let text = await pipeline.polish(raw)
        guard isLive(turn) else { return nil }
        if destination == .memory {
            return await saveMemory(pipeline.prepare(text, for: .memory), turn: turn)
        }
        if let action = pipeline.command(in: text, for: destination) {
            // Log the matched action, not the spoken text it came from.
            Self.log.info("Voice command: \(String(describing: action), privacy: .public)")
            switch action {
            case .startNewNote, .continueNote:
                return .armedNote(routeNextDictation(action))
            default:
                guard let held = await holds(turn) else { return nil }
                if held { return .notice(CaptureMachine.commandSkippedMessage) }
                TextInjector.executeAction(action)
                return .delivered
            }
        }
        // A note skips AI commands: they match suffixes, and every outcome acts on the frontmost
        // app, which is not where a note's text is going.
        if destination == .note {
            return await deliver(pipeline.prepare(text, for: .note), to: .note, appending: appending, pipeline, turn: turn)
        }
        handle(.step(.rewriting), from: turn)
        var selection: String?
        guard let result = await AICommands.process(text, selectedText: {
            if selection == nil { selection = await self.readSelection(turn) }
            return selection ?? ""
        }) else {
            return await deliver(pipeline.prepare(text, for: .app), to: .app, appending: false, pipeline, turn: turn)
        }
        guard let rewritten = result.text else {
            if let error = result.error { Self.log.error("AI command: \(error, privacy: .public)") }
            return .failed(result.error ?? "Command failed")
        }
        guard let held = await holds(turn) else { return nil }
        if !held {
            // A live selection is still highlighted, so a plain paste replaces it; ⌘Z would undo the
            // user's own last edit. Undo-then-paste only when the source was our dictation.
            if result.replacesSelection, (selection ?? "").isEmpty {
                TextInjector.undoLastTranscription()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            handle(.step(.typing), from: turn)
            TextInjector.typeText(rewritten)
        }
        if UserData.shared.keepHistory {
            TranscriptionHistory.shared.add(text: rewritten,
                                            app: held ? "" : NSWorkspace.shared.frontmostApplication?.localizedName ?? "",
                                            duration: stoppedAt.timeIntervalSince(recordingStart))
        }
        Self.log.info("AI result: \(rewritten.count) chars")
        return held ? .held(rewritten) : .delivered
    }

    private func deliver(_ text: String, to destination: CaptureDestination, appending: Bool,
                         _ pipeline: DictationPipeline, turn: Int) async -> CaptureOutcome? {
        let delivery = Signposts.poster.beginInterval("Delivery")
        defer { Signposts.poster.endInterval("Delivery", delivery) }
        guard let held = destination == .app ? await holds(turn) : false else { return nil }
        if destination == .note {
            deliverToNote(text, appending: appending)
        } else if !held {
            TextInjector.typeText(text)
        }
        UserData.shared.lastTranscription = text
        if let celebration = UserData.shared.recordCompanionDictation(
            words: text.split(whereSeparator: \.isWhitespace).count
        ) {
            celebrate(celebration)
        }
        // History is opt-out; language detection only feeds it.
        if UserData.shared.keepHistory {
            let app = destination == .app && !held ? NSWorkspace.shared.frontmostApplication?.localizedName ?? "" : ""
            TranscriptionHistory.shared.add(text: text, language: pipeline.detectLanguage(text) ?? "",
                                            app: app, duration: stoppedAt.timeIntervalSince(recordingStart))
        }
        Self.log.info("Total latency: \(Date().timeIntervalSince(self.stoppedAt), format: .fixed(precision: 1))s")
        return held ? .held(text) : .delivered
    }

    /// Whether the island takes this turn's result instead of a keystroke; `nil` once it is not live.
    private func holds(_ turn: Int) async -> Bool? {
        let held = await holdsTranscript()
        return isLive(turn) ? held : nil
    }

    /// The focus is read only when the user has actually moved to another app.
    private func holdsTranscript() async -> Bool {
        let trusted = AXIsProcessTrusted()
        let frontApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let accepts = trusted && frontApp != turnApp ? await AXReader.focusAcceptsText() : true
        return CaptureMachine.holdsTranscript(trusted: trusted, turnApp: turnApp, frontApp: frontApp,
                                              focusAcceptsText: accepts)
    }

    private func saveMemory(_ text: String, turn: Int) async -> CaptureOutcome? {
        handle(.step(.rewriting), from: turn)
        do {
            let proposal = try await CompanionMemoryParser.parse(text)
            guard isLive(turn) else { return nil }
            _ = try CompanionMemoryStore.shared.add(proposal: proposal, source: .spoken)
            _ = UserData.shared.recordCompanionDictation(
                words: proposal.text.split(whereSeparator: \.isWhitespace).count
            )
            Self.log.info("Saved spoken memory in \(Date().timeIntervalSince(self.stoppedAt), format: .fixed(precision: 1))s")
            return .notice(proposal.remindAt == nil ? "Remembered" : "Reminder saved")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// File a finished transcript into the notes store: the open note when asked and one is
    /// open, otherwise a new one. `NoteCaptureDestination.resolve` makes the choice, because the
    /// pill's note box names it while the user is still speaking.
    private func deliverToNote(_ text: String, appending: Bool) {
        let store = NoteStore.shared
        switch store.captureDestination(
            appendsToOpenNote: appending || UserData.shared.captureAppendsToOpenNote
        ) {
        case .appending(let id, _):
            store.append(text, to: id)
            Self.log.info("Appended \(text.split(separator: " ").count) words to the open note")
        case .newNote:
            store.create(body: text, source: .dictated)
            Self.log.info("Created a note from dictation (\(text.split(separator: " ").count) words)")
        }
        // Write through rather than waiting on the debounce: this text exists
        // nowhere else, and the user may quit straight after speaking.
        store.writeToDisk()
    }

    /// Prepare the note a spoken "start a new note" or "continue the note" points the next
    /// turn at, and return the confirmation to show.
    private func routeNextDictation(_ action: VoiceAction) -> String {
        let store = NoteStore.shared
        let message: String
        if action == .startNewNote {
            // An empty note becomes the destination, so the next capture appends to it.
            store.create(body: "", source: .dictated)
            message = "New note - keep talking"
        } else {
            message = store.selectedNote == nil ? "No note open - starting one" : "Adding to the open note"
            if store.selectedNote == nil { store.create(body: "", source: .dictated) }
        }
        return message
    }

    /// The frontmost app's selection, for an AI command that has matched. Accessibility first, off
    /// main; ⌘C only where that attribute is not exposed and the island would not hold the result.
    private func readSelection(_ turn: Int) async -> String {
        let selected = await AXReader.read {
            AXReader.focusedElement().flatMap { AXReader.string($0, kAXSelectedTextAttribute as CFString) }
        }
        if let selected { return selected }
        guard await holds(turn) == false else { return "" }
        return await copySelection()
    }

    /// Copy the selection with ⌘C and put the pasteboard back, awaiting rather than sleeping.
    ///
    /// Waits for the count to move *and* a readable string: an app bumps `changeCount` in
    /// `declareTypes` before it writes the data. 80 ms ceiling, for an app with nothing selected.
    private func copySelection() async -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let changeCountBefore = pasteboard.changeCount

        TextInjector.simulateCopy()

        var selected = ""
        let deadline = ContinuousClock.now + .milliseconds(80)
        while ContinuousClock.now < deadline {
            if pasteboard.changeCount != changeCountBefore,
               let string = pasteboard.string(forType: .string) {
                selected = string
                break
            }
            try? await Task.sleep(for: .milliseconds(2))
        }

        // Cmd+C with no selection leaves the pasteboard untouched.
        guard pasteboard.changeCount != changeCountBefore else { return "" }

        snapshot.restore(to: pasteboard)
        return selected
    }

    /// Map an internal error to something a user can act on.
    private static func message(for error: Error) -> String {
        if let transcription = error as? TranscriptionError {
            switch transcription {
            case .modelMissing: return "Speech model missing"
            case .modelLoadFailed: return "Could not load model"
            case .invalidAudio: return "Could not read audio"
            default: return "Transcription failed"
            }
        }
        return "Transcription failed"
    }

    // MARK: - Telemetry

    /// Forward the recorder's real level and an elapsed-seconds counter to the pill.
    private func startTelemetry() {
        recordingStart = Date()
        pill.stateModel.elapsed = 0

        levelObserver = recorder.$inputLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in self?.pill.stateModel.level = level }

        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pill.stateModel.elapsed = Int(Date().timeIntervalSince(self.recordingStart))
            }
        }

        startPreview()
    }

    private func stopTelemetry() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        levelObserver?.cancel()
        levelObserver = nil
        pill.stateModel.level = 0
        previewTask?.cancel()
        previewTask = nil
        // Abandon in-flight inference too, or a started pass would delay the real one.
        transcriber.localProvider.cancelPreviews()
        pill.stateModel.previewText = ""
    }

    /// A rough transcript while the user talks, one pass at a time so passes cannot pile up. Only
    /// with "Show words as you speak" on: the pill shows no words by default.
    private func startPreview() {
        guard UserData.shared.livePreviewEnabled else { return }
        let local = transcriber.localProvider

        pill.stateModel.previewText = ""
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            // A preview of the first fraction of a second is noise, and would flash a wrong word.
            try? await Task.sleep(nanoseconds: 900_000_000)
            while !Task.isCancelled {
                guard let self else { return }
                // The tail only: re-reading the whole utterance made each pass grow with it.
                let snapshot = self.recorder.audioSnapshot(lastBytes: AudioRecorder.previewWindowBytes)
                // Below ~0.6s of audio (16 kHz mono 16-bit) there is not enough to transcribe.
                if snapshot.count >= 19_200,
                   let text = await local.previewTranscribe(pcm: snapshot), !Task.isCancelled {
                    self.pill.stateModel.previewText = text
                }
                // Yield so previews never monopolise the queue the final transcription needs.
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }
}
