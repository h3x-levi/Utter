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

    @Test("A note turn still smiles after its notice")
    func noteTurn() {
        let b = CompanionBehaviour()
        b.apply(pillState: .capturingNote)
        b.apply(pillState: .processing(.transcribing))
        b.apply(pillState: .notice("Saved to note"))
        #expect(b.robotState == .waiting)
        b.apply(pillState: .idle)
        #expect(b.robotState == .success)
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
        b.apply(pillState: .recording)
        b.announce(.water, name: "")
        b.celebrateGoal("Goal reached")
        #expect(b.robotState == .sleep && b.quip == nil)
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
        b.celebrateGoal("Water goal reached")
        #expect(b.notice == CompanionNotice(kind: .reminder, line: "Water goal reached", detail: "Ship it"))
        b.setPomodoroCountdown(nil)
        #expect(b.pomodoroCountdown == nil)
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
