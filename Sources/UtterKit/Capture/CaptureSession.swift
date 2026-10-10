import Cocoa
import Combine

/// Runs `CaptureMachine`'s effects and owns the turn's live parts: mic, telemetry, preview,
/// pipeline and delivery. The only writer of the pill's state.
@MainActor
final class CaptureSession {
    private(set) var state = CaptureState()

    private let recorder: AudioRecorder
    private let transcriber: TranscriptionService
    private let pill: PillWindow
    private let meetingIsActive: () -> Bool
    private let suppressRelease: (Bool) -> Void
    private let celebrate: (String) -> Void

    private var expiry: DispatchWorkItem?
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
    }

    func holdBegan() { handle(.holdBegan(meetingActive: meetingIsActive())) }
    func holdEnded() { handle(.holdEnded) }
    func toggle(_ toggle: CaptureToggle) { handle(.toggle(toggle, meetingActive: meetingIsActive())) }
    func showError(_ message: String) { handle(.show(.error(message))) }
    func showNotice(_ message: String) { handle(.show(.notice(message))) }

    func handle(_ event: CaptureEvent) {
        let (next, effects) = CaptureMachine.next(state, event)
        if effects.contains(.startTurn) { Signposts.beginKeyDownToPill() }
        let shown = state.pill
        state = next
        if next.pill != shown {
            if next.pill.isRecordingLike, !pill.isVisible { pill.orderFront(nil) }
            pill.setState(next.pill)
        }
        effects.forEach(run)
    }

    /// Mirror the engine's load state, so the first launch reads "Getting ready" instead of
    /// inviting a dictation that would just queue.
    func observeModelLoad() {
        guard let local = transcriber.localProvider else { return }
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
            SurroundingContext.prewarm()
            // Pause other audio so music doesn't bleed into the microphone.
            MediaControl.pauseIfPlaying()
            // Rebuilds an evicted whisper context (78-93 ms warm, ~7.7 s cold) while the user speaks.
            transcriber.warmUp()
            Task.detached(priority: .utility) { SentencePolish.prewarm() }
            if state.modelLoading { print("⏳ Recording while the speech model finishes loading") }
        case .playStart:
            SoundPlayer.playStart()
        case .openMic(let vad):
            let onVoiceStopped: (() -> Void)? = vad ? { [weak self] in self?.handle(.voiceStopped) } : nil
            recorder.open(onVoiceStopped: onVoiceStopped) { [weak self] started in
                if !started { self?.handle(.micFailed) }
            }
        case .installVAD:
            recorder.installVoiceStoppedCallback { [weak self] in self?.handle(.voiceStopped) }
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
            recorder.stopRecording(onClosed: {
                // Before transcription: waiting seconds for it would feel like the app forgot.
                MediaControl.resumeIfPaused()
                SoundPlayer.playStop()
            }) { [weak self] audio in
                self?.handle(.audioReady(audio))
            }
        case .resumeMedia:
            MediaControl.resumeIfPaused()
        case .transcribe(let audio):
            Task {
                do {
                    handle(.transcribed(try await transcriber.transcribe(audioData: audio)))
                } catch {
                    print("Transcription error: \(error)")
                    handle(.transcriptionFailed(Self.message(for: error)))
                }
            }
        case .finish(let text):
            let destination = state.destination
            Task { handle(.finished(await finish(text, to: destination))) }
        case .playDone:
            SoundPlayer.playDone()
        case .playError:
            SoundPlayer.playError()
        case .endTurn:
            SurroundingContext.clearPrewarmed()
        case .expireMessage:
            expiry?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.handle(.messageExpired) }
            expiry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
        }
    }

    // MARK: - Finishing a turn

    private func finish(_ raw: String, to destination: CaptureDestination) async -> CaptureOutcome {
        let pipeline = DictationPipeline.live()
        let text = await pipeline.polish(raw)
        if destination == .memory {
            return await saveMemory(pipeline.prepare(text, for: .memory))
        }
        if let action = pipeline.command(in: text, for: destination) {
            // Log the matched action, not the spoken text it came from.
            print("🗣️ Voice command: \(action)")
            switch action {
            case .startNewNote, .continueNote:
                return .armedNote(routeNextDictation(action))
            default:
                TextInjector.executeAction(action)
                return .delivered
            }
        }
        // A note skips AI commands: they match suffixes, and every outcome acts on the frontmost
        // app, which is not where a note's text is going.
        if destination == .note {
            return deliver(pipeline.prepare(text, for: .note), to: .note, pipeline)
        }
        handle(.step(.rewriting))
        var selection: String?
        guard let result = await AICommands.process(text, selectedText: {
            if selection == nil { selection = await readSelection() }
            return selection ?? ""
        }) else {
            return deliver(pipeline.prepare(text, for: .app), to: .app, pipeline)
        }
        guard let rewritten = result.text else {
            if let error = result.error { print("⚠️ AI command: \(error)") }
            return .failed(result.error ?? "Command failed")
        }
        // A live selection is still highlighted, so a plain paste replaces it; ⌘Z would undo the
        // user's own last edit. Undo-then-paste only when the source was our dictation.
        if result.replacesSelection, (selection ?? "").isEmpty {
            TextInjector.undoLastTranscription()
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        handle(.step(.typing))
        TextInjector.typeText(rewritten)
        if UserData.shared.keepHistory { TranscriptionHistory.shared.add(text: rewritten) }
        print("🤖 AI result: \(rewritten.count) chars")
        return .delivered
    }

    private func deliver(_ text: String, to destination: CaptureDestination,
                         _ pipeline: DictationPipeline) -> CaptureOutcome {
        let delivery = Signposts.poster.beginInterval("Delivery")
        defer { Signposts.poster.endInterval("Delivery", delivery) }
        if destination == .note { deliverToNote(text) } else { TextInjector.typeText(text) }
        UserData.shared.lastTranscription = text
        if let celebration = UserData.shared.recordCompanionDictation(
            words: text.split(whereSeparator: \.isWhitespace).count
        ) {
            celebrate(celebration)
        }
        // History is opt-out; language detection only feeds it.
        if UserData.shared.keepHistory {
            TranscriptionHistory.shared.add(text: text, language: pipeline.detectLanguage(text) ?? "")
        }
        print("⚡ Total latency: \(String(format: "%.1f", Date().timeIntervalSince(stoppedAt)))s")
        return .delivered
    }

    private func saveMemory(_ text: String) async -> CaptureOutcome {
        handle(.step(.rewriting))
        do {
            let proposal = try await CompanionMemoryParser.parse(text)
            _ = try CompanionMemoryStore.shared.add(proposal: proposal, source: .spoken)
            _ = UserData.shared.recordCompanionDictation(
                words: proposal.text.split(whereSeparator: \.isWhitespace).count
            )
            print("🧠 Saved spoken memory in \(String(format: "%.1f", Date().timeIntervalSince(stoppedAt)))s")
            return .notice(proposal.remindAt == nil ? "Remembered" : "Reminder saved")
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// File a finished transcript into the notes store: the open note when asked and one is
    /// open, otherwise a new one. `NoteCaptureDestination.resolve` makes the choice, because the
    /// pill's note box names it while the user is still speaking.
    private func deliverToNote(_ text: String) {
        let store = NoteStore.shared
        switch store.captureDestination(
            appendsToOpenNote: UserData.shared.captureAppendsToOpenNote
        ) {
        case .appending(let id, _):
            store.append(text, to: id)
            print("📝 Appended \(text.split(separator: " ").count) words to the open note")
        case .newNote:
            store.create(body: text, source: .dictated)
            print("📝 Created a note from dictation (\(text.split(separator: " ").count) words)")
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
        UserData.shared.captureAppendsToOpenNote = true
        UserData.shared.save()
        return message
    }

    /// The frontmost app's selection, for an AI command that has matched. Accessibility first, off
    /// main; ⌘C only where that attribute is not exposed.
    private func readSelection() async -> String {
        let selected = await AXReader.read {
            AXReader.focusedElement().flatMap { AXReader.string($0, kAXSelectedTextAttribute as CFString) }
        }
        if let selected { return selected }
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
        transcriber.localProvider?.cancelPreviews()
        pill.stateModel.previewText = ""
    }

    /// A rough transcript while the user talks, one pass at a time so passes cannot pile up.
    /// Notes and memories always preview: the card exists to show it. Ordinary dictation honours
    /// the preference.
    private func startPreview() {
        guard UserData.shared.livePreviewEnabled || state.destination != .app else { return }
        guard let local = transcriber.localProvider else { return }

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
