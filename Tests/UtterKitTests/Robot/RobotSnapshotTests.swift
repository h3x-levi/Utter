import AppKit
import Testing
@testable import UtterKit

@Suite("Robot snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_ROBOT_SNAPSHOTS"] == "1"))
@MainActor
struct RobotSnapshotTests {
    /// Seconds into each state's plan where its expression is fully formed.
    private static let moments: [(RobotState, Double)] = [
        (.idle, 0), (.bored, 1.5), (.waiting, 0.32), (.waitingWrap, 1.0), (.input, 1.0), (.send, 0.65),
        (.success, 0.85), (.failure, 1.66), (.warning, 1.78), (.inspect, 1.88), (.angry, 1.3), (.blocked, 1.3),
        (.error, 0.67), (.surprise, 0.96), (.love, 1.02), (.random, 0.88), (.sleep, 4.0), (.wake, 0.3),
    ]

    @Test("Render each state's resting pose to .build/robot-snapshots")
    func renderStates() throws {
        let directory = try SnapshotCanvas.directory("robot-snapshots")

        let view = RobotView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        view.appearance = NSAppearance(named: .aqua)
        view.layout()
        let sleeping = RobotPlan.make(.sleep, from: RobotFace(), reduced: false, seed: 1, resting: true, withLoop: false)
        for (state, moment) in Self.moments {
            let start = state == .wake ? sleeping.frames[sleeping.frames.count - 1] : RobotFace()
            view.showStill(RobotPlan.make(state, from: start, reduced: false, seed: 7).face(at: moment))
            try png(of: view).write(to: directory.appendingPathComponent("\(state).png"))
        }
        for roundness in [CGFloat(0), 100] {
            view.roundness = roundness
            view.showStill(RobotFace())
            try png(of: view).write(to: directory.appendingPathComponent("roundness-\(Int(roundness)).png"))
        }
    }

    /// Each moment is caught just after its last accessory arrives, or halfway through when it wears none.
    @Test("Render every library moment to .build/robot-snapshots/moments")
    func renderMoments() throws {
        let library = try #require(RobotLibrary.shared)
        let time = try #require(library.times[library.defaults["time"] ?? "day"])
        let directory = try SnapshotCanvas.directory("robot-snapshots/moments")
        let view = RobotView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        view.appearance = NSAppearance(named: .aqua)
        view.layout()
        for (id, moment) in library.moments {
            let (plan, cues) = RobotPlan.make(moment: moment, from: RobotFace(), antennaVelocity: .zero, reduced: false,
                                              time: time, seed: 7, loop: false, hold: false)
            let length = moment.steps.compactMap(\.wait).reduce(0, +) / time.speed
            var at = length / 2
            if let lastOn = cues.filter({ $0.on != nil }).map(\.at).max() {
                let nextOff = cues.filter { $0.off != nil && $0.at > lastOn }.map(\.at).min() ?? length
                at = lastOn + min(600, (nextOff - lastOn) / 2)
            }
            var worn: [String] = []
            for cue in cues where cue.at <= at {
                if let on = cue.on, !worn.contains(on) { worn.append(on) }
                if let off = cue.off { worn.removeAll { $0 == off } }
            }
            view.showStill(plan.face(at: at / 1000), accessories: worn)
            try png(of: view).write(to: directory.appendingPathComponent("\(id).png"))
        }
    }

    /// Top row bare, bottom row wearing two accessories, so palette swaps show.
    @Test("Render every finish in light and dark to .build/robot-snapshots")
    func renderFinishes() throws {
        let library = try #require(RobotLibrary.shared)
        let directory = try SnapshotCanvas.directory("robot-snapshots")
        let view = RobotView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        view.appearance = NSAppearance(named: .aqua)
        view.layout()
        let worn = ["headphones", "bow"].filter { library.accessories[$0] != nil }
        let sheets: [(String, NSAppearance.Name, NSColor)] = [
            ("light", .aqua, NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1)),
            ("dark", .darkAqua, NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)),
        ]
        for (name, appearance, background) in sheets {
            view.appearance = NSAppearance(named: appearance)
            let data = try png(of: view, columns: library.finishOrder.count, rows: 2, background: background) { column, row in
                view.look.finish = library.finishOrder[column]
                view.showStill(RobotFace(), accessories: row == 0 ? [] : worn)
            }
            try data.write(to: directory.appendingPathComponent("finishes-\(name).png"))
        }
    }

    private func png(of view: RobotView, columns: Int = 1, rows: Int = 1,
                     background: NSColor = NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1),
                     tile: (Int, Int) -> Void = { _, _ in }) throws -> Data {
        let scale: CGFloat = 2
        let size = view.bounds.size
        guard let layer = view.layer,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale) * columns,
                                         pixelsHigh: Int(size.height * scale) * rows, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { throw RenderError.noContext }
        context.setFillColor(background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
        context.scaleBy(x: scale, y: scale)
        for row in 0..<rows {
            for column in 0..<columns {
                tile(column, row)
                context.saveGState()
                context.translateBy(x: CGFloat(column) * size.width, y: CGFloat(rows - 1 - row) * size.height)
                layer.render(in: context)
                context.restoreGState()
            }
        }
        guard let data = rep.representation(using: .png, properties: [:]) else { throw RenderError.noContext }
        return data
    }

    private enum RenderError: Error { case noContext }
}

@Suite("Robot view moments", .serialized)
@MainActor
struct RobotViewMomentTests {
    /// Reports itself visible without ever being ordered onto a screen, so the robot runs unpaused.
    private final class UnseenWindow: NSWindow {
        override var occlusionState: NSWindow.OcclusionState { .visible }
    }

    private static let libraryJSON = """
    {"version": 1, "credit": "", "box": 240, "defaults": {"finish": "ink", "time": "day"}, "groups": {"g": "G"},
     "palette": {"red": ["#D8352A", "#E2463B"]},
     "finishes": {"ink": {"name": "Ink", "body": "#08090B", "eyes": "#FFFFFF", "outline": "dark"}},
     "times": {"day": {"name": "Day", "from": 0, "to": 24, "speed": 1, "lid": 0, "blink": 1}},
     "accessories": {
      "cap": {"name": "Cap", "slot": "top", "layer": "head", "enter": "pop", "wear": true,
              "shapes": [{"el": "rect", "x": 100, "y": 0, "width": 40, "height": 20, "fill": "red"}]},
      "hat": {"name": "Hat", "slot": "top", "layer": "head", "enter": "drop",
              "shapes": [{"el": "rect", "x": 90, "y": 0, "width": 60, "height": 24, "fill": "red"}]},
      "pad": {"name": "Pad", "slot": "hands", "layer": "front", "enter": "pop",
              "shapes": [{"el": "rect", "x": 150, "y": 170, "width": 40, "height": 50, "fill": "red"}]},
      "zz": {"name": "Zz", "slot": "air", "layer": "front", "enter": "fade",
             "shapes": [{"el": "circle", "cx": 200, "cy": 30, "r": 8, "fill": "red"}]}},
     "moments": {
      "hat-on": {"group": "g", "name": "Hat", "trigger": "t",
                 "steps": [{"on": "hat"}, {"wait": 150}], "reduced": [{"on": "hat"}, {"wait": 150}]},
      "pad-zz": {"group": "g", "name": "Two", "trigger": "t",
                 "steps": [{"on": "pad", "instant": true}, {"on": "zz"}, {"wait": 150}],
                 "reduced": [{"on": "pad"}, {"on": "zz"}, {"wait": 150}]},
      "pad": {"group": "g", "name": "Pad", "trigger": "t",
              "steps": [{"on": "pad"}, {"wait": 150}], "reduced": [{"on": "pad"}, {"wait": 150}]}},
     "routes": []}
    """

    private func library() throws -> RobotLibrary {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("robot-view-moments-\(UUID().uuidString).json")
        try Data(Self.libraryJSON.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try RobotLibrary.load(from: url)
    }

    private func spin(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }

    @Test("The worn accessory yields its slot to a moment, comes back after, and stale cues never fire")
    func wornSync() throws {
        let window = UnseenWindow(contentRect: NSRect(x: 0, y: 0, width: 240, height: 240), styleMask: .borderless,
                                  backing: .buffered, defer: true)
        let robot = RobotView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        window.contentView = robot
        robot.library = try library()
        var ended: [String] = []
        robot.onMomentEnd = { ended.append($0) }

        robot.look.worn = "hat"
        #expect(robot.shown.isEmpty)
        robot.look.worn = "cap"
        #expect(Set(robot.shown.keys) == ["cap"])

        robot.napDelay = 0.03
        robot.play(moment: "hat-on", loop: false, hold: false)
        spin(0.08)
        #expect(robot.isPlayingMoment)
        #expect(Set(robot.shown.keys) == ["hat"])
        #expect(robot.state != .sleep)
        spin(0.2)
        #expect(ended == ["hat-on"])
        #expect(!robot.isPlayingMoment)
        #expect(Set(robot.shown.keys) == ["cap"])
        robot.napDelay = nil

        robot.play(moment: "pad-zz", loop: false, hold: false)
        spin(0.05)
        #expect(Set(robot.shown.keys) == ["pad", "zz"])

        robot.play(moment: "hat-on", loop: false, hold: false)
        robot.play(moment: "pad", loop: false, hold: false)
        spin(0.05)
        #expect(Set(robot.shown.keys) == ["cap", "pad"])
        spin(0.25)
        #expect(ended == ["hat-on", "pad"])
        #expect(Set(robot.shown.keys) == ["cap"])

        robot.play(moment: "pad", loop: true, hold: false)
        spin(0.05)
        robot.stopMoment()
        #expect(!robot.isPlayingMoment)
        spin(0.25)
        #expect(ended == ["hat-on", "pad"])
    }

    @Test("A paused robot skips moments and reports them ended once")
    func pausedSkips() throws {
        let robot = RobotView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        robot.library = try library()
        var ended: [String] = []
        robot.onMomentEnd = { ended.append($0) }
        robot.play(moment: "hat-on", loop: false, hold: false)
        robot.play(moment: "pad", loop: false, hold: true)
        #expect(!robot.isPlayingMoment)
        #expect(robot.state == .input)
        spin(0.05)
        #expect(ended == ["pad"])
        #expect(robot.shown.isEmpty)
    }
}
