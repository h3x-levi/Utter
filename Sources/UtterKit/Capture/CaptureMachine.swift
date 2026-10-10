import Foundation

/// Everything a dictation turn is doing, in one value. The pill is derived from it.
struct CaptureState: Equatable {
    enum Phase: Equatable {
        case idle
        case recording(handsFree: Bool)
        case processing(PillState.Phase)
        case error(String)
        case notice(String)
        /// A finished dictation with nowhere to type it, held for the user to copy.
        case holding(String)
    }

    var phase: Phase = .idle
    /// This turn's destination. While idle it is where the next turn goes, which is how a spoken
    /// "start a new note" arms the turn after it.
    var destination: CaptureDestination = .app
    var modelLoading = true

    var pill: PillState {
        switch phase {
        case .idle: return modelLoading ? .preparing : .idle
        case .recording(let handsFree):
            switch destination {
            case .note: return .capturingNote
            case .memory: return .capturingMemory
            case .app: return handsFree ? .handsFree : .recording
            }
        case .processing(let step): return .processing(step)
        case .error(let message): return .error(message)
        case .notice(let message): return .notice(message)
        case .holding(let transcript): return .island(transcript)
        }
    }
}

/// The chords and gestures that latch a recording: ⌃⌥Space or a double tap, ⌃⌥N, ⌃⌥R.
enum CaptureToggle: Equatable { case handsFree, note, memory }

enum CaptureOutcome: Equatable {
    case delivered
    case failed(String)
    case notice(String)
    /// A spoken note-routing command: the next turn goes into a note.
    case armedNote(String)
    /// Not pasted, because the user moved to an app with nothing to type into.
    case held(String)
}

enum CaptureEvent: Equatable {
    case holdBegan(meetingActive: Bool)
    case holdEnded
    case toggle(CaptureToggle, meetingActive: Bool)
    case voiceStopped
    case micFailed
    case audioReady(Data?)
    case transcribed(String)
    case transcriptionFailed(String)
    case step(PillState.Phase)
    case finished(CaptureOutcome)
    /// A message from outside the turn, such as the meeting offer.
    case show(CaptureState.Phase)
    case messageExpired
    /// The held transcript was copied, closed, or dismissed with Escape.
    case islandClosed
    case model(LocalWhisperProvider.LoadState)
}

enum CaptureEffect: Equatable {
    /// Pause media, warm the speech context, prewarm surrounding context.
    case startTurn
    case playStart
    case openMic(vad: Bool)
    case installVAD
    case suppressRelease(Bool)
    case startTelemetry
    case stopTelemetry
    case startPreview
    /// Media resumes and the stop chime plays once the mic is closed.
    case closeMic
    case resumeMedia
    case transcribe(Data)
    /// Polish, commands and delivery for the turn's destination.
    case finish(String)
    case playDone
    case playError
    case endTurn
    case expireMessage
}

/// The turn's rules as a pure function. `CaptureSession` runs the effects.
enum CaptureMachine {
    static let meetingMessage = "Recording a meeting - stop it first"
    static let micMessage = "Couldn\u{2019}t start the microphone"
    static let noSpeechMessage = "No speech detected"

    static func next(_ state: CaptureState, _ event: CaptureEvent) -> (CaptureState, [CaptureEffect]) {
        var s = state
        switch (state.phase, event) {

        // Brushing the hotkey during a latched session must not touch the live tap.
        case (.recording, .holdBegan), (.processing, .holdBegan):
            return (s, [])
        case (_, .holdBegan(let meetingActive)):
            if meetingActive { return refuse(s) }
            return start(s, handsFree: false, to: s.destination)

        case (.recording(handsFree: false), .holdEnded):
            return stop(s)
        case (_, .holdEnded):
            return (s, [])

        case (.recording(let handsFree), .toggle(let toggle, _)):
            let target = destination(for: toggle, current: s.destination)
            if handsFree {
                if toggle == .handsFree || target == s.destination { return stop(s, latched: true) }
                s.destination = target
                return (s, [.startPreview])
            }
            s.phase = .recording(handsFree: true)
            s.destination = target
            return (s, [.suppressRelease(true)] + (target == .app ? [] : [.startPreview]) + [.installVAD])
        case (.processing, .toggle):
            // A double tap sets the release suppression itself; a refused toggle must clear it.
            return (s, [.suppressRelease(false)])
        case (_, .toggle(let toggle, let meetingActive)):
            if meetingActive {
                let (refused, effects) = refuse(s)
                return (refused, [.suppressRelease(false)] + effects)
            }
            return start(s, handsFree: true, to: destination(for: toggle, current: s.destination))

        case (.recording(handsFree: true), .voiceStopped):
            return stop(s, latched: true)
        case (_, .voiceStopped):
            return (s, [])

        // A start that failed leaves nothing able to end the turn, so it is rolled back whole.
        case (.recording, .micFailed), (.processing, .micFailed):
            return fail(s, micMessage, sound: false, extra: [.suppressRelease(false), .resumeMedia])
        case (_, .micFailed):
            return (s, [])

        case (.processing, .audioReady(let audio)):
            guard let audio else { return fail(s, noSpeechMessage) }
            return (s, [.transcribe(audio)])
        case (.processing, .transcribed(let text)):
            return text.isEmpty ? fail(s, noSpeechMessage) : (s, [.finish(text)])
        case (.processing, .transcriptionFailed(let message)):
            return fail(s, message)
        case (.processing, .step(let step)):
            s.phase = .processing(step)
            return (s, [])
        case (.processing, .finished(let outcome)):
            return finish(s, outcome)
        case (_, .audioReady), (_, .transcribed), (_, .transcriptionFailed), (_, .step), (_, .finished):
            return (s, [])

        case (.recording, .show), (.processing, .show), (.holding, .show):
            return (s, [])
        case (_, .show(let message)):
            s.phase = message
            return (s, [.expireMessage])

        // Only a message still on screen expires; a turn started meanwhile is left alone.
        case (.error, .messageExpired), (.notice, .messageExpired):
            s.phase = .idle
            return (s, [])
        case (_, .messageExpired):
            return (s, [])

        case (.holding, .islandClosed):
            s.phase = .idle
            return (s, [])
        case (_, .islandClosed):
            return (s, [])

        case (_, .model(let load)):
            s.modelLoading = load == .loading || load == .idle
            guard case .failed(let reason) = load, state.phase == .idle else { return (s, []) }
            s.phase = .error(reason)
            return (s, [.expireMessage])
        }
    }

    private static func destination(for toggle: CaptureToggle,
                                    current: CaptureDestination) -> CaptureDestination {
        switch toggle {
        case .handsFree: return current
        case .note: return .note
        case .memory: return .memory
        }
    }

    private static func start(_ state: CaptureState, handsFree: Bool,
                              to destination: CaptureDestination) -> (CaptureState, [CaptureEffect]) {
        var s = state
        s.phase = .recording(handsFree: handsFree)
        s.destination = destination
        // The chime is queued before the mic opens, so it stays out of the recording.
        return (s, (handsFree ? [.suppressRelease(true)] : [])
                   + [.startTurn, .playStart, .startTelemetry, .openMic(vad: handsFree)])
    }

    private static func stop(_ state: CaptureState, latched: Bool = false) -> (CaptureState, [CaptureEffect]) {
        var s = state
        s.phase = .processing(.transcribing)
        return (s, (latched ? [.suppressRelease(false)] : []) + [.stopTelemetry, .closeMic])
    }

    /// A refusal before anything started keeps an armed note armed.
    private static func refuse(_ state: CaptureState) -> (CaptureState, [CaptureEffect]) {
        var s = state
        s.phase = .error(meetingMessage)
        return (s, [.expireMessage])
    }

    /// Every way a turn ends goes through here or `finish`, so none can leave a note armed.
    private static func fail(_ state: CaptureState, _ message: String, sound: Bool = true,
                             extra: [CaptureEffect] = []) -> (CaptureState, [CaptureEffect]) {
        var s = state
        s.phase = .error(message)
        s.destination = .app
        return (s, extra + [.stopTelemetry] + (sound ? [.playError] : []) + [.endTurn, .expireMessage])
    }

    private static func finish(_ state: CaptureState, _ outcome: CaptureOutcome) -> (CaptureState, [CaptureEffect]) {
        var s = state
        s.destination = .app
        switch outcome {
        case .delivered:
            s.phase = .idle
            return (s, [.playDone, .endTurn])
        case .failed(let message):
            return fail(s, message)
        case .notice(let message):
            s.phase = .notice(message)
            return (s, [.playDone, .endTurn, .expireMessage])
        case .armedNote(let message):
            s.phase = .notice(message)
            s.destination = .note
            return (s, [.playDone, .endTurn, .expireMessage])
        case .held(let transcript):
            s.phase = .holding(transcript)
            return (s, [.playDone, .endTurn])
        }
    }

    /// Whether a finished dictation is held on the pill instead of pasted: only when the user is
    /// now in a different app whose focus takes no text. Without Accessibility nothing is known
    /// about the focus, so it pastes as it always has.
    static func holdsTranscript(trusted: Bool, turnApp: pid_t?, frontApp: pid_t?,
                                focusAcceptsText: Bool) -> Bool {
        trusted && turnApp != frontApp && !focusAcceptsText
    }
}
