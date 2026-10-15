import AppKit
import Testing
@testable import UtterKit

@Suite("Robot moments")
struct RobotMomentTests {
    private static let library: RobotLibrary? = try? RobotLibrary.load(from: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Windows and Linux/src/companion-moments.json"))

    private static let day = RobotTime(name: "Day", from: 11, to: 17, speed: 1, lid: 0, blink: 1)
    private static let night = RobotTime(name: "Late night", from: 22, to: 5, speed: 0.8, lid: 9, blink: 1.4)

    private static func moment(_ steps: String, reduced: String = #"[{"wait": 1000}]"#, loopFrom: Int? = nil) throws -> RobotMoment {
        let loop = loopFrom.map { #", "loopFrom": \#($0)"# } ?? ""
        let json = #"{"group": "mood", "name": "Test", "trigger": "Test", "steps": \#(steps), "reduced": \#(reduced)\#(loop)}"#
        return try JSONDecoder().decode(RobotMoment.self, from: Data(json.utf8))
    }

    private static func make(_ m: RobotMoment, reduced: Bool = false, time: RobotTime = day, loop: Bool = false,
                             hold: Bool = false) -> (plan: RobotPlan, cues: [RobotMomentCue]) {
        RobotPlan.make(moment: m, from: RobotFace(), antennaVelocity: .zero, reduced: reduced, time: time, seed: 7, loop: loop, hold: hold)
    }

    private static func at(_ plan: RobotPlan, ms: Double) -> RobotFace { plan.face(at: ms / 1000) }

    @Test("A head rotate about the chin decomposes to the head's translate, rotate and scale")
    func headDecomposition() throws {
        let lists = ["rotate(0deg)", "rotate(90deg)"].map(RobotTransformFunction.parse)
        let motion = try #require(RobotHeadMotion(css: lists, origin: RobotGeometry.point("120px 204px"), start: 0, duration: 100,
                                                  ease: .linear, held: RobotHeadKey(offset: 0)))
        let k = motion.value(at: 100)
        #expect(abs(k.x - 84) < 1e-6 && abs(k.y - 84) < 1e-6 && abs(k.rotation - 90) < 1e-6)
        #expect(abs(k.scale - 1) < 1e-6 && abs((k.scaleY ?? 0) - 1) < 1e-6)
        let squash = RobotTransformFunction.parse("translateY(-5px) rotate(-7deg) scale(0.96, 1.07)")
        let d = RobotGeometry.decompose(RobotGeometry.matrix(squash, origin: RobotGeometry.headCenter))
        #expect(abs(d.y + 5) < 1e-6 && abs(d.rotation + 7) < 1e-6 && abs(d.scale - 0.96) < 1e-6 && abs((d.scaleY ?? 0) - 1.07) < 1e-6)
    }

    @Test("Every library moment builds finite plans from its steps and its reduced steps")
    func libraryMomentsBuild() throws {
        let library = try #require(Self.library)
        for (id, m) in library.moments {
            for reduced in [false, true] {
                let (plan, cues) = Self.make(m, reduced: reduced, time: Self.night, loop: m.loopFrom != nil)
                let faces = plan.frames + plan.loop
                let finite = faces.allSatisfy { f in
                    RobotFace.scalars.allSatisfy { f[keyPath: $0].isFinite }
                        && RobotEyeFace.scalars.allSatisfy { f.left[keyPath: $0].isFinite && f.right[keyPath: $0].isFinite }
                }
                #expect(plan.isMoment && !plan.frames.isEmpty && finite, "\(id) reduced \(reduced)")
                #expect(cues.allSatisfy { library.accessories[$0.on ?? $0.off ?? ""] != nil && $0.at >= 0 }, "\(id)")
                if reduced { #expect(faces.allSatisfy { $0.headY == 0 && $0.headRotation == 0 && $0.blink == 1 }, "\(id) moves in reduce motion") }
            }
        }
    }

    @Test("One-shot moments settle back to rest, take off what they put on, and hand over to the idle loop")
    func oneShotsSettle() throws {
        let library = try #require(Self.library)
        for (id, m) in library.moments where m.loopFrom == nil {
            let (plan, cues) = Self.make(m)
            let done = plan.frames[Int((plan.introDuration * RobotPlan.frameRate).rounded())]
            #expect(plan.state == .idle && !plan.loop.isEmpty, "\(id)")
            #expect(abs(done.left.width - 54) < 0.5 && abs(done.headX) < 0.3 && abs(done.headY) < 0.3 && abs(done.headRotation) < 0.3, "\(id)")
            let last = plan.frames[plan.frames.count - 1], idle = plan.face(at: plan.introSpan)
            var still = last
            (still.antennaX, still.antennaY) = (idle.antennaX, idle.antennaY)
            #expect(still.distance(to: idle) < 0.2 && last.distance(to: idle) < 0.5, "\(id) jumps into the idle loop")
            let on = Set(cues.compactMap(\.on)), off = Set(cues.compactMap(\.off))
            #expect(on.isSubset(of: off), "\(id) leaves an accessory on")
        }
    }

    @Test("A held moment ends on the input pose and reports input; a looping one repeats seamlessly")
    func holdAndLoop() throws {
        let lean = try Self.moment(#"[{"lock": true}, {"pose": "surprise", "ms": 160}, {"head": ["translateY(0px)", "translateY(3px)"], "ms": 400}, {"wait": 500}, {"pose": "input", "ms": 220}, {"wait": 800}]"#)
        let held = Self.make(lean, hold: true).plan
        let last = held.frames[held.frames.count - 1]
        #expect(held.state == .input && held.caretBlinks && held.loop.isEmpty)
        #expect(last.left.caret > 0.99 && abs(last.headY) < 0.05)

        let tap = try Self.moment(#"[{"pose": "input", "ms": 200}, {"head": ["translateY(0px) rotate(0deg)", "translateY(2.5px) rotate(-2.5deg)", "translateY(0px) rotate(0deg)"], "ms": 600, "times": 2, "origin": "120px 204px"}, {"wait": 1200}]"#, loopFrom: 1)
        let looped = Self.make(tap, loop: true, hold: true).plan
        #expect(looped.state == .input && looped.loop.count > 2)
        #expect(looped.loop[0].distance(to: looped.loop[1]) < 1)
        let seamA = looped.frames[looped.frames.count - 1], seamB = looped.face(at: looped.introSpan + 1e-9)
        #expect(abs(seamA.headY - seamB.headY) < 1e-3 && abs(seamA.headRotation - seamB.headRotation) < 1e-3 && RobotEyeFace.scalars.allSatisfy { abs(seamA.left[keyPath: $0] - seamB.left[keyPath: $0]) < 1e-3 })
        #expect(looped.loop.contains { $0.headRotation < -1 }, "the loop pass never tilts the head")
    }

    @Test("Time of day: night lids drop 9 except while typing, and every duration slows by its speed")
    func timeOfDay() throws {
        for (state, drop) in [(RobotState.idle, CGFloat(9)), (.input, 0)] {
            let day = RobotPlan.make(state, from: RobotFace(), reduced: false, seed: 1, time: Self.day)
            let night = RobotPlan.make(state, from: RobotFace(), reduced: false, seed: 1, time: Self.night)
            let d = day.frames[day.frames.count - 1], n = night.frames[night.frames.count - 1]
            #expect(abs(n.left.topY - d.left.topY - drop) < 1e-6 && abs(n.right.topY - d.right.topY - drop) < 1e-6, "\(state)")
        }
        let notes = try Self.moment(#"[{"on": "notepad"}, {"wait": 800}, {"pose": "happy", "ms": 400}, {"wait": 800}, {"off": "notepad", "exit": "lift"}, {"wait": 400}]"#)
        let (day, dayCues) = Self.make(notes)
        let (night, nightCues) = Self.make(notes, time: Self.night)
        #expect(abs(day.introDuration - (2000 + 360) / 1000) < 1e-9 && abs(night.introDuration - (2000 / 0.8 + 360) / 1000) < 1e-9)
        #expect(dayCues.map(\.at) == [0, 1600] && nightCues.map(\.at) == [0, 2000])
        #expect(nightCues[1].off == "notepad" && nightCues[1].exit == "lift")
        var a = RobotRandom(seed: 5), b = RobotRandom(seed: 5)
        let normal = RobotBlinks(random: &a), often = RobotBlinks(random: &b, rate: 2)
        #expect(abs(normal.events[0].at - 2 * often.events[0].at) < 1e-9)
        #expect(abs((normal.events[1].at - normal.events[0].at - normal.events[0].duration)
            - 2 * (often.events[1].at - often.events[0].at - often.events[0].duration)) < 1e-9)
    }

    @Test("Gaze looks at each target for its hold then rests; wink closes only the right eye")
    func gazeAndWink() throws {
        let look = try Self.moment(#"[{"lock": true}, {"gaze": [[20, 0, 600]], "speed": 0.4}, {"wait": 700}, {"lock": true}, {"wait": 700}]"#)
        let gaze = Self.make(look).plan
        #expect(Self.at(gaze, ms: 550).left.x > 86 + 15)
        #expect(Self.at(gaze, ms: 1350).left.x < 86 + 2)
        let wink = try Self.moment(#"[{"lock": true}, {"wait": 400}, {"fx": "wink", "ms": 400}, {"wait": 1000}]"#)
        let mid = Self.at(Self.make(wink).plan, ms: 600)
        #expect(mid.right.scaleY < 0.1 && mid.left.scaleY == 1)
    }
}
