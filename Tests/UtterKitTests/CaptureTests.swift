import Foundation
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Dictation pipeline")
struct DictationPipelineTests {

    private func marking(_ log: Log) -> DictationPipeline {
        DictationPipeline(
            polish: { $0 + ">polish" },
            voiceCommand: { $0 == "select all" ? .selectAll : $0 == "new note" ? .startNewNote : nil },
            correct: { log.note("correct"); return $0 + ">correct" },
            expandSnippets: { log.note("snippets"); return $0 + ">snippets" },
            formatForApp: { log.note("format"); return $0 + ">format" },
            detectLanguage: { _ in "Fixture" }
        )
    }

    final class Log { var stages: [String] = []; func note(_ s: String) { stages.append(s) } }

    @Test("Typed text runs dictionary, snippets, then app formatting, in that order")
    func appStageOrder() {
        let log = Log()
        #expect(marking(log).prepare("x", for: .app) == "x>correct>snippets>format")
        #expect(log.stages == ["correct", "snippets", "format"])
    }

    @Test("Notes and memories get dictionary and snippets but no app formatting")
    func nonAppStages() {
        #expect(marking(Log()).prepare("x", for: .note) == "x>correct>snippets")
        #expect(marking(Log()).prepare("x", for: .memory) == "x>correct>snippets")
    }

    @Test("Inside a note only routing commands run; a memory runs none")
    func commandsByDestination() {
        let pipeline = marking(Log())
        #expect(pipeline.command(in: "select all", for: .app) == .selectAll)
        #expect(pipeline.command(in: "select all", for: .note) == nil)
        #expect(pipeline.command(in: "new note", for: .note) == .startNewNote)
        #expect(pipeline.command(in: "new note", for: .memory) == nil)
        #expect(pipeline.command(in: "hello", for: .app) == nil)
    }

    /// The live wiring is the only caller of these four features; dropping a stage fails here.
    @Test("The live pipeline wires dictionary, snippets, app formatting and language detection")
    func liveWiring() {
        let data = UserData(storageDir: nil)
        data.dictionaryWords = ["macOS"]
        data.snippets = [(trigger: "my sig", expansion: "Kind regards")]
        let pipeline = DictationPipeline.live(data, context: { .email })

        #expect(pipeline.prepare("I use macos my sig", for: .app) == "I use macOS Kind regards.")
        #expect(pipeline.prepare("I use macos my sig", for: .note) == "I use macOS Kind regards")
        #expect(pipeline.detectLanguage("Bonjour tout le monde, comment allez-vous aujourd'hui ?") == "Français")
        #expect(pipeline.command(in: "select all", for: .app) == .selectAll)
    }
}

/// One row per state bug the old capture flags' comments documented.
@Suite("Capture machine")
struct CaptureMachineTests {

    private func state(_ phase: CaptureState.Phase, _ destination: CaptureDestination = .app) -> CaptureState {
        CaptureState(phase: phase, destination: destination, modelLoading: false)
    }

    private func next(_ state: CaptureState, _ event: CaptureEvent) -> (CaptureState, [CaptureEffect]) {
        CaptureMachine.next(state, event)
    }

    private let mic = CaptureMachine.micMessage

    @Test("Brushing the hotkey during a latched session leaves the live tap alone")
    func holdDuringLatchedSession() {
        for latched in [state(.recording(handsFree: true)), state(.recording(handsFree: true), .note)] {
            let (after, effects) = next(latched, .holdBegan(meetingActive: false))
            #expect(after == latched)
            #expect(effects.isEmpty)
        }
    }

    @Test("Dictation is refused while a meeting owns the mic, and an armed note stays armed")
    func meetingRefusal() {
        let (after, effects) = next(state(.idle, .note), .holdBegan(meetingActive: true))
        #expect(after.phase == .error(CaptureMachine.meetingMessage))
        #expect(after.destination == .note)
        #expect(!effects.contains(.openMic(vad: false)))
    }

    @Test("A failed mic start rolls back hands-free and the release suppression")
    func micFailureRollsBack() {
        let (after, effects) = next(state(.recording(handsFree: true)), .micFailed)
        #expect(after.phase == .error(mic))
        #expect(effects.contains(.suppressRelease(false)))
        #expect(effects.contains(.resumeMedia))
        #expect(effects.contains(.stopTelemetry))
    }

    @Test("A failed mic start in a note capture shows the error, not a note card recording nothing")
    func micFailureDuringNote() {
        let (after, _) = next(state(.recording(handsFree: true), .note), .micFailed)
        #expect(after.pill == .error(mic))
        #expect(after.destination == .app)
    }

    @Test("A release before the failed start reports the mic, not missing speech")
    func micFailureAfterRelease() {
        let (failed, _) = next(state(.processing(.transcribing)), .micFailed)
        #expect(failed.phase == .error(mic))
        let (after, effects) = next(failed, .audioReady(nil))
        #expect(after.phase == .error(mic))
        #expect(effects.isEmpty)
    }

    @Test("⌃⌥N from idle starts one note capture: one state, chime before the mic")
    func noteFromIdle() {
        let (after, effects) = next(state(.idle), .toggle(.note, meetingActive: false))
        #expect(after.pill == .capturingNote)
        #expect(effects == [.suppressRelease(true), .startTurn, .playStart, .startTelemetry, .openMic(vad: true)])
    }

    @Test("⌃⌥N during push-to-talk upgrades the live tap instead of opening another")
    func noteUpgradesPushToTalk() {
        let (after, effects) = next(state(.recording(handsFree: false)), .toggle(.note, meetingActive: false))
        #expect(after == state(.recording(handsFree: true), .note))
        #expect(effects == [.suppressRelease(true), .startPreview, .installVAD])
    }

    @Test("⌃⌥N during hands-free redirects it and starts the preview the card needs")
    func noteRedirectsHandsFree() {
        let (after, effects) = next(state(.recording(handsFree: true)), .toggle(.note, meetingActive: false))
        #expect(after == state(.recording(handsFree: true), .note))
        #expect(effects == [.startPreview])
    }

    @Test("The same chord again finishes the capture")
    func chordFinishes() {
        for (toggle, destination) in [(CaptureToggle.note, CaptureDestination.note), (.memory, .memory)] {
            let (after, effects) = next(state(.recording(handsFree: true), destination),
                                        .toggle(toggle, meetingActive: false))
            #expect(after.phase == .processing(.transcribing))
            #expect(effects == [.suppressRelease(false), .stopTelemetry, .closeMic])
        }
    }

    @Test("⌃⌥Space over an armed push-to-talk note upgrades it rather than starting on a live tap")
    func handsFreeOverArmedNote() {
        let (after, effects) = next(state(.recording(handsFree: false), .note),
                                    .toggle(.handsFree, meetingActive: false))
        #expect(after == state(.recording(handsFree: true), .note))
        #expect(!effects.contains(.openMic(vad: true)))
        #expect(effects.contains(.installVAD))
    }

    @Test("⌃⌥Space while latched stops, whatever the destination")
    func handsFreeStopsAnyDestination() {
        let (after, _) = next(state(.recording(handsFree: true), .memory), .toggle(.handsFree, meetingActive: false))
        #expect(after.phase == .processing(.transcribing))
    }

    @Test("A spoken note command arms the next turn, and the arming outlives this turn's end")
    func armingSurvivesTurnEnd() {
        let (noticed, effects) = next(state(.processing(.transcribing)), .finished(.armedNote("New note - keep talking")))
        #expect(noticed.phase == .notice("New note - keep talking"))
        #expect(effects.contains(.endTurn))
        let (rested, _) = next(noticed, .messageExpired)
        let (recording, _) = next(rested, .holdBegan(meetingActive: false))
        #expect(recording.pill == .capturingNote)
        #expect(recording.appendsToOpenNote)
    }

    @Test("Every way a note turn ends clears the destination")
    func exitsClearDestination() {
        var processing = state(.processing(.transcribing), .note)
        processing.appendsToOpenNote = true
        let endings: [CaptureEvent] = [.finished(.delivered), .finished(.failed("x")), .finished(.notice("x")),
                                       .audioReady(nil), .transcribed(""), .transcriptionFailed("x"), .micFailed,
                                       .cancel]
        for ending in endings {
            let after = next(processing, ending).0
            #expect(after.destination == .app && !after.appendsToOpenNote, "\(ending)")
        }
    }

    @Test("An expiring message never cancels a recording started inside its window")
    func expiryLeavesRecording() {
        let recording = state(.recording(handsFree: false))
        #expect(next(recording, .messageExpired).0 == recording)
        #expect(next(state(.error("x")), .messageExpired).0.phase == .idle)
    }

    @Test("VAD silence only ends a latched recording")
    func vadOnlyWhenLatched() {
        #expect(next(state(.processing(.transcribing)), .voiceStopped).1.isEmpty)
        #expect(next(state(.recording(handsFree: false)), .voiceStopped).1.isEmpty)
        #expect(next(state(.recording(handsFree: true)), .voiceStopped).0.phase == .processing(.transcribing))
    }

    @Test("Stopping with no usable audio says so instead of returning silently to idle")
    func noAudioIsAnError() {
        let (after, effects) = next(state(.processing(.transcribing)), .audioReady(nil))
        #expect(after.phase == .error(CaptureMachine.noSpeechMessage))
        #expect(effects.contains(.playError))
    }

    @Test("A toggle refused while processing clears the release suppression a double tap set")
    func refusedToggleClearsSuppression() {
        let processing = state(.processing(.transcribing))
        let (after, effects) = next(processing, .toggle(.handsFree, meetingActive: false))
        #expect(after == processing)
        #expect(effects == [.suppressRelease(false)])
        #expect(next(state(.idle), .toggle(.handsFree, meetingActive: true)).1.contains(.suppressRelease(false)))
    }

    @Test("Escape cancels recording, hands-free and processing; nothing is delivered and the pill rests")
    func escapeCancels() {
        let closesMic: [CaptureEffect] = [.suppressRelease(false), .stopTelemetry, .discardMic, .endTurn, .expireMessageSoon]
        let rows: [(CaptureState, [CaptureEffect])] = [
            (state(.recording(handsFree: false)), closesMic),
            (state(.recording(handsFree: true)), closesMic),
            (state(.recording(handsFree: true), .note), closesMic),
            (state(.processing(.transcribing)), [.endTurn, .expireMessageSoon]),
            (state(.processing(.rewriting)), [.endTurn, .expireMessageSoon]),
        ]
        for (before, expected) in rows {
            let (cancelled, effects) = next(before, .cancel)
            #expect(cancelled.pill == .notice(CaptureMachine.cancelledMessage), "\(before)")
            #expect(effects == expected, "\(before)")
            for late in [CaptureEvent.audioReady(Data([1])), .transcribed("hello"), .finished(.delivered)] {
                #expect(next(cancelled, late).1.isEmpty, "\(before) \(late)")
            }
            #expect(next(cancelled, .messageExpired).0.phase == .idle)
        }
        for resting in [state(.idle), state(.holding("hello")), state(.error("x"))] {
            #expect(next(resting, .cancel).1.isEmpty, "\(resting)")
        }
    }

    @Test("A double tap starts hands-free only while a slow mic still owes the first tap's audio")
    func doubleTapOnSlowMicStart() {
        let (released, _) = next(state(.recording(handsFree: false)), .holdEnded)
        let (transcribing, _) = next(released, .audioReady(Data([1])))
        let (latchedStop, _) = next(state(.recording(handsFree: true)), .voiceStopped)
        let rows: [(CaptureState, PillState)] = [
            (released, .handsFree),
            (transcribing, .processing(.transcribing)),
            (latchedStop, .processing(.transcribing)),
        ]
        for (before, pill) in rows {
            #expect(next(before, .toggle(.handsFree, meetingActive: false)).0.pill == pill, "\(before)")
        }
        let (handsFree, effects) = next(released, .toggle(.handsFree, meetingActive: false))
        #expect(effects == [.suppressRelease(true), .startTurn, .playStart, .startTelemetry, .openMic(vad: true)])
        #expect(next(handsFree, .audioReady(nil)).0 == handsFree)
    }

    @Test("Key-down and release while processing are ignored")
    func processingIgnoresHotkey() {
        let processing = state(.processing(.rewriting))
        #expect(next(processing, .holdBegan(meetingActive: false)).1.isEmpty)
        #expect(next(processing, .holdEnded).1.isEmpty)
    }

    @Test("Push-to-talk: key-down shows recording at once and the chime is queued before the mic")
    func pushToTalk() {
        let (recording, effects) = next(state(.idle), .holdBegan(meetingActive: false))
        #expect(recording.pill == .recording)
        let chime = effects.firstIndex(of: .playStart), open = effects.firstIndex(of: .openMic(vad: false))
        #expect(chime != nil && open != nil && chime! < open!)
        let (stopped, stopEffects) = next(recording, .holdEnded)
        #expect(stopped.pill == .processing(.transcribing))
        #expect(stopEffects == [.stopTelemetry, .closeMic])
    }

    @Test("Model load drives preparing, and a failure only interrupts an idle pill")
    func modelLoad() {
        var loading = state(.idle)
        loading.modelLoading = true
        #expect(loading.pill == .preparing)
        #expect(next(loading, .model(.ready)).0.pill == .idle)
        #expect(next(state(.idle), .model(.failed("bad"))).0.phase == .error("bad"))
        #expect(next(state(.recording(handsFree: false)), .model(.failed("bad"))).0.phase == .recording(handsFree: false))
    }

    @Test("A message from outside the turn never interrupts one")
    func outsideMessage() {
        let recording = state(.recording(handsFree: true))
        #expect(next(recording, .show(.notice("Recording the meeting"))).0 == recording)
        #expect(next(state(.idle), .show(.notice("Recording the meeting"))).0.pill == .notice("Recording the meeting"))
    }
}

@Suite("Destination policy")
struct DestinationPolicyTests {

    @Test("A transcript is held only when the user moved to an app with no text focus, with Accessibility",
          arguments: [
              // trusted, turn app, front app, focus takes text, held
              (true, 1, 1, false, false),   // same app: paste as today
              (true, 1, 2, false, true),    // moved, nothing to type into: hold
              (true, 1, 2, true, false),    // moved to a text field: paste
              (false, 1, 2, false, false),  // no Accessibility: today's behaviour
          ] as [(Bool, Int32, Int32, Bool, Bool)])
    func policy(trusted: Bool, turnApp: Int32, frontApp: Int32, accepts: Bool, held: Bool) {
        #expect(CaptureMachine.holdsTranscript(trusted: trusted, turnApp: turnApp, frontApp: frontApp,
                                               focusAcceptsText: accepts) == held)
    }

    private func state(_ phase: CaptureState.Phase) -> CaptureState {
        CaptureState(phase: phase, destination: .app, modelLoading: false)
    }

    @Test("A held transcript becomes the island and stays until closed")
    func heldBecomesIsland() {
        let (held, effects) = CaptureMachine.next(state(.processing(.typing)), .finished(.held("hello there")))
        #expect(held.pill == .island("hello there"))
        #expect(effects == [.playDone, .endTurn])
        #expect(CaptureMachine.next(held, .messageExpired).0 == held)
        #expect(CaptureMachine.next(held, .show(.notice("Recording the meeting"))).0 == held)
        #expect(CaptureMachine.next(held, .islandClosed).0.phase == .idle)
    }

    @Test("A new turn replaces the island")
    func newTurnReplacesIsland() {
        let (recording, effects) = CaptureMachine.next(state(.holding("hello")), .holdBegan(meetingActive: false))
        #expect(recording.pill == .recording)
        #expect(effects.contains(.openMic(vad: false)))
        #expect(CaptureMachine.next(state(.recording(handsFree: false)), .islandClosed).1.isEmpty)
    }

    @Test("The window grows for the island and only for it")
    func islandWindow() {
        let island = PillMetrics.panelSize(for: .island("x"), caption: false)
        let listening = PillMetrics.panelSize(for: .listening(nil), caption: false)
        #expect(island.width > listening.width && island.height > listening.height)
        #expect(island.height == ceil(PillMetrics.shellSize(for: .island("x")).height + PillMetrics.margin * 2))
    }
}

@Suite("Sentence polish policy")
struct SentencePolishPolicyTests {
    actor Probe {
        var calls = 0
        var cancelled = false
        func called() { calls += 1 }
        func markCancelled() { cancelled = true }
    }

    private let sentence = "it was closed so i came back later that evening"
    private let polished = "It was closed, so I came back later that evening."

    @Test("Dictation waits at most 900 ms for polish")
    func deadline() {
        #expect(SentencePolish.dictationDeadline == .milliseconds(900))
    }

    @Test("A slow polisher is abandoned at the deadline and cancelled; the text goes out unpolished")
    func slowPolisher() async throws {
        let probe = Probe()
        let clock = ContinuousClock()
        let started = clock.now
        let result = await SentencePolish.polish(sentence, deadline: .milliseconds(100), isAvailable: true,
                                                 rewrite: { _, _ in
            do { try await Task.sleep(for: .seconds(10)) } catch {
                await probe.markCancelled()
                throw error
            }
            return "never"
        })
        #expect(result == sentence)
        #expect(clock.now - started < .seconds(2))
        try await Task.sleep(for: .milliseconds(200))
        #expect(await probe.cancelled)
    }

    @Test("A slow context read is inside the deadline too")
    func slowContext() async {
        let result = await SentencePolish.polish(sentence, context: {
            try? await Task.sleep(for: .seconds(10))
            return ("", nil)
        }, deadline: .milliseconds(100), isAvailable: true, rewrite: { _, _ in "never" })
        #expect(result == sentence)
    }

    @Test("A failing polisher delivers the text unpolished")
    func failingPolisher() async {
        struct Refused: Error {}
        let result = await SentencePolish.polish(sentence, deadline: SentencePolish.dictationDeadline,
                                                 isAvailable: true, rewrite: { _, _ in throw Refused() })
        #expect(result == sentence)
    }

    @Test("A polish that lands in time is used")
    func timelyPolisher() async {
        let result = await SentencePolish.polish(sentence, deadline: SentencePolish.dictationDeadline,
                                                 isAvailable: true, rewrite: { [polished] _, _ in polished })
        #expect(result == polished)
    }

    @Test("Under four words, or with polish unavailable, the model is never called")
    func gates() async {
        let probe = Probe()
        let rewrite: (String, String) async throws -> String = { _, prompt in
            await probe.called()
            return prompt
        }
        _ = await SentencePolish.polish("three words here", isAvailable: true, rewrite: rewrite)
        _ = await SentencePolish.polish(sentence, isAvailable: false, rewrite: rewrite)
        #expect(await probe.calls == 0)
        _ = await SentencePolish.polish("four words right here", isAvailable: true, rewrite: rewrite)
        #expect(await probe.calls == 1)
    }
}
