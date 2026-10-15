import AppKit
import Testing
@testable import UtterKit

@Suite("Robot shapes")
@MainActor
struct RobotShapesTests {
    private func library() throws -> RobotLibrary {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try RobotLibrary.load(from: root.appendingPathComponent("Windows and Linux/src/companion-moments.json"))
    }

    private func colours(_ finish: String = "ink") throws -> RobotColours {
        let library = try library()
        return RobotColours(library: library, finish: try #require(library.finishes[finish]))
    }

    private func layers(_ root: CALayer) -> [CALayer] {
        var all: [CALayer] = []
        RobotShapes.walk(root) { all.append($0) }
        return all
    }

    private func points(_ path: CGPath) -> [CGPoint] {
        var all: [CGPoint] = []
        path.applyWithBlock { e in
            let count = switch e.pointee.type {
            case .moveToPoint, .addLineToPoint: 1
            case .addQuadCurveToPoint: 2
            case .addCurveToPoint: 3
            default: 0
            }
            all += (0..<count).map { e.pointee.points[$0] }
        }
        return all
    }

    private func rgb(_ colour: CGColor?) -> UInt32? {
        guard let colour, let c = NSColor(cgColor: colour)?.usingColorSpace(.sRGB) else { return nil }
        let byte = { (v: CGFloat) in UInt32((v * 255).rounded()) }
        return byte(c.redComponent) << 16 | byte(c.greenComponent) << 8 | byte(c.blueComponent)
    }

    private func resolved(_ colour: NSColor?, dark: Bool) -> UInt32? {
        var cg: CGColor?
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance { cg = colour?.cgColor }
        return rgb(cg)
    }

    private func close(_ a: CGPoint, _ b: CGPoint) -> Bool { abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001 }

    @Test("A path's fill box ignores control points: the notepad header is (-25, -30, 50, 11)")
    func pathBox() {
        let box = RobotSVG.path("M-25 -19 V-24 Q-25 -30 -19 -30 H19 Q25 -30 25 -24 V-19 Z").boundingBoxOfPath
        #expect(close(box.origin, CGPoint(x: -25, y: -30)) && abs(box.width - 50) < 0.001 && abs(box.height - 11) < 0.001)
    }

    @Test("Paths repeat commands implicitly and split compact numbers")
    func pathParsing() {
        let p = points(RobotSVG.path("M0 0 10 0 10-10L5.5.5Z"))
        #expect(p.count == 4 && close(p[1], CGPoint(x: 10, y: 0)) && close(p[2], CGPoint(x: 10, y: -10)) && close(p[3], CGPoint(x: 5.5, y: 0.5)))
    }

    @Test("Transform lists apply left to right, rotate about a centre, and accept CSS units")
    func transforms() {
        #expect(close(CGPoint(x: 232, y: 122).applying(RobotSVG.transform("rotate(-90 120 122)")), CGPoint(x: 120, y: 10)))
        #expect(close(CGPoint(x: 130, y: 33).applying(RobotSVG.transform("translate(120 33) scale(1.35) translate(-120 -33)")), CGPoint(x: 133.5, y: 33)))
        #expect(close(CGPoint(x: 10, y: 0).applying(RobotSVG.transform("translate(169.5px, 30.5px) scale(1.1)")), CGPoint(x: 180.5, y: 30.5)))
        #expect(close(CGPoint(x: 0, y: 10).applying(RobotSVG.transform("rotate(-16deg)")).applying(RobotSVG.transform("rotate(16deg)")), CGPoint(x: 0, y: 10)))
        #expect(close(CGPoint(x: 1, y: 1).applying(RobotSVG.transform("translateX(4px) translateY(-6px)")), CGPoint(x: 5, y: -5)))
    }

    @Test("Every accessory and finish builds, with a drawable path on every shape")
    func everythingBuilds() throws {
        let library = try library()
        for (id, spec) in library.accessories {
            let finish = try #require(library.finishes[library.defaults["finish"] ?? "ink"])
            let root = try #require(RobotShapes.accessory(id, colours: RobotColours(library: library, finish: finish)))
            #expect(root.name == id && root.sublayers?.count == spec.shapes.count && !root.bounds.isEmpty, "\(id)")
            #expect(close(root.position, CGPoint(x: root.bounds.midX, y: root.bounds.midY)), "\(id)")
            for case let shape as CAShapeLayer in layers(root) {
                let box = shape.path?.boundingBoxOfPath ?? .null
                #expect(!box.isNull && box.width + box.height > 0, "\(id)")
            }
        }
        for (id, finish) in library.finishes {
            let colours = RobotColours(library: library, finish: finish)
            #expect(RobotColours.hex(finish.body) != nil && RobotColours.hex(finish.eyes) != nil, "\(id)")
            for spec in finish.shapes ?? [] {
                #expect(layers(RobotShapes.layer(spec, colours: colours)).contains { $0 is CAShapeLayer }, "\(id)")
            }
        }
    }

    @Test("Tokens resolve light and dark, through the finish's swap; body, eyes and none are special")
    func tokens() throws {
        let ink = try colours()
        #expect(resolved(ink.colour("line"), dark: false) == 0x1C2A5E)
        #expect(resolved(ink.colour("line"), dark: true) == 0xE9EDF8)
        #expect(resolved(ink.colour("body"), dark: true) == 0x08090B && resolved(ink.colour("eyes"), dark: false) == 0xFFFFFF)
        #expect(ink.colour("none") == nil)
        let navy = try colours("navy")
        #expect(resolved(navy.colour("navy"), dark: false) == 0x2A4FC4 && resolved(navy.colour("navy"), dark: true) == 0x8FA8FF)
    }

    @Test("The focus ring is a 0.72 stroke end that starts at 12 o'clock and runs clockwise")
    func timerRing() throws {
        let root = try #require(RobotShapes.accessory("timer", colours: colours()))
        let ring = try #require(layers(root).compactMap { $0 as? CAShapeLayer }.first { $0.strokeEnd < 1 })
        #expect(abs(ring.strokeEnd - 0.72) < 0.0001)
        let p = points(try #require(ring.path)).map { $0.applying(CATransform3DGetAffineTransform(ring.transform)) }
        #expect(close(p[0], CGPoint(x: 120, y: 10)) && close(p[3], CGPoint(x: 232, y: 122)))
        let loop = try #require((ring.value(forKey: "robotLoops") as? [CAAnimation])?.first as? CAKeyframeAnimation)
        #expect(loop.keyPath == "strokeEnd" && (loop.values as? [Double]) == [0, 0.72] && loop.fillMode == .both)
    }

    @Test("An anim origin anchors the element at that point of its fill box")
    func origins() throws {
        let colours = try colours()
        let bell = try #require(RobotShapes.accessory("bell", colours: colours))
        let swing = try #require(layers(bell).first { $0.value(forKey: "robotLoops") != nil })
        #expect(close(swing.anchorPoint, CGPoint(x: 0.5, y: 0)) && close(swing.position, CGPoint(x: 0, y: -23)))
        let glass = try #require(RobotShapes.accessory("glass", colours: colours))
        let water = try #require(layers(glass).first { $0.value(forKey: "robotLoops") != nil })
        #expect(close(water.anchorPoint, CGPoint(x: 0.5, y: 1)) && close(water.position, CGPoint(x: 84, y: 230)))
        let filled = try #require(layers(glass).compactMap { $0 as? CAShapeLayer }.first { $0.fillColor?.alpha ?? 1 < 1 })
        #expect(abs((filled.fillColor?.alpha ?? 0) - 0.82) < 0.001)
    }

    @Test("Loops follow WAAPI timing: spread offsets, negative delays as phase, once holds its end")
    func loopTiming() throws {
        let colours = try colours()
        let zz = try #require(RobotShapes.accessory("zz", colours: colours))
        let tracks = layers(zz).compactMap { $0.value(forKey: "robotLoops") as? [CAAnimation] }
        #expect(tracks.count == 2 && tracks.allSatisfy { $0.map { ($0 as? CAPropertyAnimation)?.keyPath } == ["transform", "opacity"] })
        let first = try #require(tracks[0][0] as? CAKeyframeAnimation)
        #expect(first.keyTimes == [0, 0.3, 1] && first.repeatCount == .infinity && first.timeOffset == 0)
        #expect(abs(tracks[1][0].timeOffset - 1.1) < 0.0001)

        let glass = try #require(RobotShapes.accessory("glass", colours: colours))
        let water = try #require(layers(glass).first { $0.value(forKey: "robotLoops") != nil })
        RobotShapes.startLoops(glass)
        RobotShapes.startLoops(glass)
        let running = try #require(water.animation(forKey: "robotLoops0"))
        #expect(water.animationKeys() == ["robotLoops0"] && running.beginTime > 0.9 && !running.isRemovedOnCompletion)
        RobotShapes.stopLoops(glass)
        #expect(water.animationKeys() == nil)
    }

    @Test("Enter and exit use the player's styles, durations and overshoot")
    func transitions() throws {
        let root = try #require(RobotShapes.accessory("party-hat", colours: colours()))
        RobotShapes.enter(root, "drop")
        let drop = try #require(root.animation(forKey: "robotEnter.transform") as? CABasicAnimation)
        var overshoot: [Float] = [0, 0]
        drop.timingFunction?.getControlPoint(at: 1, values: &overshoot)
        #expect(abs(drop.duration - 0.36) < 0.0001 && abs(overshoot[1] - 1.56) < 0.0001)
        #expect((drop.fromValue as? NSValue)?.caTransform3DValue.m42 == -26)
        let faded = try #require(RobotShapes.accessory("zz", colours: colours()))
        RobotShapes.enter(faded, "fade")
        #expect(faded.animation(forKey: "robotEnter.transform") == nil && faded.animation(forKey: "robotEnter.opacity")?.duration == 0.26)

        RobotShapes.exit(root, "lift") {}
        let lift = try #require(root.animation(forKey: "robotExit.transform") as? CABasicAnimation)
        #expect(abs(lift.duration - 0.42) < 0.0001 && lift.fillMode == .forwards && (lift.toValue as? NSValue)?.caTransform3DValue.m42 == -34)
        RobotShapes.exit(root, "drop") {}
        let pop = try #require(root.animation(forKey: "robotExit.transform") as? CABasicAnimation)
        #expect(abs(pop.duration - 0.18) < 0.0001 && (pop.toValue as? NSValue)?.caTransform3DValue.m11 == 0.6)
    }

    @Test("Recolour repaints from the stored tokens for a new finish")
    func recolour() throws {
        let library = try library()
        let ink = RobotColours(library: library, finish: try #require(library.finishes["ink"]))
        let navy = RobotColours(library: library, finish: try #require(library.finishes["navy"]))
        let bow = try #require(RobotShapes.accessory("bow", colours: ink))
        let knot = try #require(layers(bow).compactMap { $0 as? CAShapeLayer }.last)
        #expect(rgb(knot.strokeColor) == 0x08090B)
        RobotShapes.recolour(bow, colours: navy)
        #expect(rgb(knot.strokeColor) == 0x1C2A5E && rgb(knot.fillColor) != nil)
    }
}
