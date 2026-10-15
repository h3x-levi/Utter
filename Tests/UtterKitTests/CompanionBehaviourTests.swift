import AppKit
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Robot companion behaviour")
@MainActor
struct CompanionBehaviourTests {
    // MARK: Capture state to robot state

    @Test("A typed turn listens, waits, then smiles")
    func typedTurn() {
        let b = CompanionBehaviour()
        b.apply(pillState: .recording)
        #expect(b.robotState == .input)
        b.apply(pillState: .processing(.transcribing))
        #expect(b.robotState == .waiting)
        b.apply(pillState: .processing(.typing))
        b.apply(pillState: .idle)
        #expect(b.robotState == .success)
    }

    @Test("A note turn ends at its notice with a smile, and the idle after it changes nothing")
    func noteTurn() {
        let b = CompanionBehaviour()
        b.apply(pillState: .capturingNote)
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .notice("Saved to note"))
        #expect(b.robotState == .success)
        #expect(b.cue?.event == "notice")
        let cue = b.cue
        b.apply(pillState: .idle)
        #expect(b.robotState == .success && b.cue == cue)
    }

    @Test("A cancelled turn and a finished load go back to idle without a smile")
    func cancelAndLoad() {
        let b = CompanionBehaviour()
        b.apply(pillState: .preparing)
        #expect(b.robotState == .waiting)
        b.apply(pillState: .idle)
        #expect(b.robotState == .idle)
        b.apply(pillState: .handsFree)
        b.apply(pillState: .idle)
        #expect(b.robotState == .idle)
    }

    @Test("A failure plays the failure and says why")
    func failure() {
        let b = CompanionBehaviour()
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .error("Speech model missing"))
        #expect(b.robotState == .failure)
        #expect(b.notice == CompanionNotice(kind: .failure, line: "Speech model missing"))
        b.apply(pillState: .idle)
        #expect(b.robotState == .failure)
    }

    @Test("Text that could not be typed stops the waiting without a smile")
    func island() {
        let b = CompanionBehaviour()
        b.apply(pillState: .recording)
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .island("hello"))
        #expect(b.robotState == .idle)
        b.apply(pillState: .idle)
        #expect(b.robotState == .idle)
    }

    // MARK: Reminders, goals, quiet

    @Test("A reminder nods, speaks, and is answered from the menu")
    func reminder() {
        let b = CompanionBehaviour()
        b.announce(.water, name: "Sam")
        #expect(b.robotState == .send)
        #expect(b.currentReminder == .water)
        #expect(b.notice?.line == "Water break, Sam")
        #expect(b.respondToCurrentReminder(completed: true) == .water)
        #expect(b.robotState == .success)
        #expect(b.currentReminder == nil && b.quip == nil)
        #expect(b.respondToCurrentReminder(completed: false) == nil)
    }

    @Test("Quiet mode sleeps, drops what is pending and ignores capture until it ends")
    func quiet() {
        let b = CompanionBehaviour()
        b.announce(.stretch, name: "")
        b.setQuietMode(true)
        #expect(b.robotState == .sleep && b.isQuiet)
        #expect(b.currentReminder == nil && b.quip == nil)
        let cue = b.cue
        b.apply(pillState: .recording)
        b.announce(.water, name: "")
        b.celebrateGoal("Goal reached", kind: "hydration")
        #expect(b.robotState == .sleep && b.quip == nil && b.cue == cue)
        b.setQuietMode(false)
        #expect(b.robotState == .wake)
        b.apply(pillState: .recording)
        #expect(b.robotState == .input)
    }

    @Test("The bubble shows a message first, then the focus timer, then the pinned note")
    func noticePriority() {
        let b = CompanionBehaviour()
        #expect(b.notice == nil)
        b.pinnedMessage = "  Ship it  "
        #expect(b.notice == CompanionNotice(kind: .pinned, line: "Ship it"))
        b.setPomodoroCountdown(125)
        #expect(b.notice == CompanionNotice(kind: .timer, line: "2:05", detail: "Ship it"))
        b.celebrateGoal("Water goal reached", kind: "hydration")
        #expect(b.notice == CompanionNotice(kind: .reminder, line: "Water goal reached", detail: "Ship it"))
        b.setPomodoroCountdown(nil)
        #expect(b.pomodoroCountdown == nil)
    }

    // MARK: Cues for moments

    @Test("Listening names its mode and destination, and every cue gets a fresh id")
    func listeningCue() {
        let b = CompanionBehaviour()
        let expected: [(PillState, [String: RobotValue])] = [
            (.recording, ["mode": .string("recording"), "destination": .string("app")]),
            (.handsFree, ["mode": .string("handsFree"), "destination": .string("app")]),
            (.capturingNote, ["destination": .string("note")]),
            (.capturingMemory, ["destination": .string("memory")]),
        ]
        var ids: [Int] = []
        for (state, detail) in expected {
            b.apply(pillState: .idle)
            b.apply(pillState: state)
            #expect(b.cue?.event == "listening" && b.cue?.detail == detail)
            ids.append(b.cue?.id ?? 0)
        }
        #expect(ids == ids.sorted() && Set(ids).count == ids.count)
    }

    @Test("Turn notes ride on the closing cue, then clear; listening starts a clean turn")
    func turnNotes() {
        let b = CompanionBehaviour()
        b.apply(pillState: .recording)
        b.apply(pillState: .processing(.transcribing))
        #expect(b.cue?.event == "thinking")
        b.note(["words": .number(12), "total": .number(1004), "destination": .string("app")])
        b.celebrateGoal("Dictation goal complete", kind: "dictation")
        #expect(b.cue?.event == "thinking" && b.robotState == .love)
        b.apply(pillState: .idle)
        #expect(b.cue?.event == "done")
        #expect(b.cue?.detail == ["words": .number(12), "total": .number(1004), "destination": .string("app"), "goal": .string("dictation")])

        b.note(["words": .number(3)])
        b.apply(pillState: .recording)
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .error("Nothing heard"))
        #expect(b.cue?.event == "error" && b.cue?.detail == [:])

        b.apply(pillState: .capturingMemory)
        b.apply(pillState: .processing(.rewriting))
        b.note(["remembered": .bool(true), "timed": .bool(false)])
        b.apply(pillState: .notice("Remembered"))
        #expect(b.cue?.event == "notice" && b.cue?.detail == ["remembered": .bool(true), "timed": .bool(false)])

        b.apply(pillState: .recording)
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .island("hello"))
        #expect(b.cue?.event == "island")
    }

    @Test("Reminders and reminder goals cue with their kind")
    func reminderCues() {
        let b = CompanionBehaviour()
        b.announce(.stretch, name: "")
        #expect(b.cue?.event == "reminder" && b.cue?.detail == ["kind": .string("stretch")])
        b.announce(.pomodoro(focus: true), name: "")
        #expect(b.cue?.detail == ["kind": .string("pomodoro"), "focus": .bool(true)])
        b.celebrateGoal("Stretch goal complete", kind: "stretch")
        #expect(b.cue?.event == "goal" && b.cue?.detail == ["kind": .string("stretch")])
        #expect(b.robotState == .love)
    }

    @Test("Idle-only cues wait for a free robot; listening and thinking count only when their state begins")
    func gating() {
        func cue(_ event: String) -> CompanionCue { CompanionCue(id: 1, event: event, detail: [:]) }
        for event in CompanionCue.idleOnly {
            #expect(cue(event).mayRoute(state: .idle, stateChanged: false, momentPlaying: false))
            #expect(!cue(event).mayRoute(state: .idle, stateChanged: false, momentPlaying: true))
            for state in [RobotState.input, .waiting, .sleep] {
                #expect(!cue(event).mayRoute(state: state, stateChanged: true, momentPlaying: false))
            }
        }
        for event in CompanionCue.noReplay {
            #expect(cue(event).mayRoute(state: .input, stateChanged: true, momentPlaying: true))
            #expect(!cue(event).mayRoute(state: .input, stateChanged: false, momentPlaying: false))
        }
        #expect(cue("talking").mayRoute(state: .input, stateChanged: false, momentPlaying: true))
        #expect(cue("done").mayRoute(state: .success, stateChanged: false, momentPlaying: true))
    }

    @Test("The shared hear table cues talking and quiet as on Windows and Linux")
    func hearTable() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Windows and Linux/src/companion-routes.test.json")
        let table = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cases = try #require(table["hear"] as? [[String: Any]])
        #expect(!cases.isEmpty)
        for item in cases {
            let name = item["name"] as? String ?? "?"
            let b = CompanionBehaviour()
            b.apply(pillState: .recording)
            var heard: [String] = []
            var last = b.cue?.id
            for sample in item["levels"] as? [[Double]] ?? [] {
                b.hear(Float(sample[1]), at: 1_000_000 + sample[0])
                if let cue = b.cue, cue.id != last {
                    heard.append(cue.event)
                    last = cue.id
                }
            }
            #expect(heard == item["expect"] as? [String], "\(name)")
        }
    }

    @Test("Hearing stops once the robot is no longer listening")
    func hearOnlyWhileListening() {
        let b = CompanionBehaviour()
        b.apply(pillState: .recording)
        b.apply(pillState: .processing(.transcribing))
        let cue = b.cue
        for ms in stride(from: 0.0, through: 6000, by: 100) { b.hear(0.3, at: ms) }
        #expect(b.cue == cue)
    }

    @Test("The saved look falls back to the library's default finish and wears only accessories marked to wear")
    func lookValidation() throws {
        let library = try #require(RobotLibrary.shared)
        let night = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30)))
        let unknown = RobotLook(finish: "plaid", accessory: "cape", at: night, library: library)
        #expect(unknown.finish == library.defaults["finish"] && unknown.worn == nil)
        #expect(unknown.time == library.timeOfDay(night))
        for id in library.finishOrder {
            #expect(RobotLook(finish: id, accessory: "", library: library).finish == id)
        }
        for id in library.accessoryOrder {
            let wears = library.accessories[id]?.wear == true
            #expect(RobotLook(finish: "ink", accessory: id, library: library).worn == (wears ? id : nil))
        }
        #expect(RobotLook(finish: "gold", accessory: "bow", library: nil) == RobotLook())
    }

    // MARK: Geometry

    @Test("The default robot stays near the resting pill's weight")
    func defaultSize() {
        #expect((38...44).contains(UserData.defaultCompanionSize.points))
        let sizes = CompanionSize.allCases.map(\.points)
        #expect(sizes == sizes.sorted())
        #expect(CompanionSize(rawValue: "huge") == .huge)
    }

    @Test("The clamp keeps the robot on screen while the empty panel may hang off")
    func clamp() {
        let g = CompanionGeometry(.medium)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 860)
        for wanted in [CGPoint(x: -500, y: -500), CGPoint(x: 5000, y: 5000), CGPoint(x: 700, y: 400)] {
            let origin = g.clamped(wanted, in: visible)
            let robot = g.robotFrameInPanel.offsetBy(dx: origin.x, dy: origin.y)
            #expect(visible.insetBy(dx: -0.001, dy: -0.001).contains(robot))
        }
        let corner = g.clamped(CGPoint(x: -500, y: 0), in: visible)
        #expect(corner.x < visible.minX)
        #expect(g.clamped(CGPoint(x: 700, y: 400), in: visible) == CGPoint(x: 700, y: 400))
    }

    @Test("A saved centre round-trips, and the bubble moves below and inward at the screen's edges")
    func positionAndBubble() {
        let g = CompanionGeometry(.large)
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 860)
        let origin = g.panelOrigin(robotCentre: CGPoint(x: 300, y: 300))
        let f = CompanionGeometry.fraction(ofCentre: CGPoint(x: 300, y: 300), in: visible)
        #expect(g.panelOrigin(forCentreFraction: f, in: visible) == origin)
        #expect(!g.bubbleBelow(panelOrigin: origin, visible: visible))
        let top = g.clamped(g.panelOrigin(robotCentre: CGPoint(x: 300, y: 2000)), in: visible)
        #expect(g.bubbleBelow(panelOrigin: top, visible: visible))
        let edge = g.clamped(g.panelOrigin(robotCentre: CGPoint(x: 1440, y: 300)), in: visible)
        let insets = g.bubbleInsets(panelOrigin: edge, visible: visible)
        #expect(insets.leading == 0 && insets.trailing > 0)
    }

    // MARK: The robot's own idle cost

    @Test("The robot naps after its delay, and quiet holds it asleep")
    func nap() {
        let robot = RobotView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        #expect(robot.state == .idle)
        robot.napDelay = 0.05
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        #expect(robot.state == .sleep)
        robot.play(.input)
        robot.napDelay = 0.05
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        #expect(robot.state == .input)
        robot.play(.idle)
        robot.isQuiet = true
        #expect(robot.state == .sleep)
        robot.isQuiet = false
        #expect(robot.state == .idle)
    }
}
