import AppKit
import Testing
@testable import UtterKit

@Suite("Robot companion")
struct RobotTests {
    // MARK: Palette

    @Test("The default palette is the upstream ink body and white eyes")
    func paletteDefaults() throws {
        let p = RobotPalette.upstream
        let body = try #require(p.body.usingColorSpace(.sRGB))
        #expect(abs(body.redComponent - 8 / 255) < 0.001)
        #expect(abs(body.greenComponent - 9 / 255) < 0.001)
        #expect(abs(body.blueComponent - 11 / 255) < 0.001)
        #expect(p.face == p.body && p.accent == p.body)
        let eye = try #require(p.eye.usingColorSpace(.sRGB))
        #expect(min(eye.redComponent, eye.greenComponent, eye.blueComponent) > 0.999)
    }

    // MARK: State rules

    @Test("Only waiting, input and sleep persist; the rest play once")
    func persistence() {
        let persistent = RobotState.allCases.filter(\.persists)
        #expect(Set(persistent) == [.waiting, .waitingWrap, .input, .sleep])
    }

    @Test("Wake, sleep and input are ignored when they would change nothing")
    func noOps() {
        #expect(RobotState.wake.isNoOp(whenShowing: .idle))
        #expect(!RobotState.wake.isNoOp(whenShowing: .sleep))
        #expect(RobotState.sleep.isNoOp(whenShowing: .sleep))
        #expect(RobotState.input.isNoOp(whenShowing: .input))
        #expect(!RobotState.success.isNoOp(whenShowing: .success))
    }

    @Test("Antenna flash periods follow upstream, blocked flashing like angry")
    func flashPeriods() {
        #expect(RobotState.input.flashPeriod == 1.2)
        #expect(RobotState.blocked.flashPeriod == RobotState.angry.flashPeriod)
        #expect(RobotState.idle.flashPeriod == nil && RobotState.waiting.flashPeriod == nil)
    }

    @Test("Every state builds finite frames", arguments: RobotState.allCases)
    func plansAreFinite(state: RobotState) {
        let plan = RobotPlan.make(state, from: RobotFace(), reduced: false, seed: 3)
        let values = (plan.frames + plan.loop).flatMap { f in
            RobotFace.scalars.map { f[keyPath: $0] } + RobotEyeFace.scalars.flatMap { [f.left[keyPath: $0], f.right[keyPath: $0]] }
        }
        let finite = values.allSatisfy { $0.isFinite }
        #expect(!plan.frames.isEmpty)
        #expect(finite)
    }

    @Test("One-shot states settle back to the idle face")
    func oneShotsReturnToRest() {
        for state in RobotState.allCases where !state.persists {
            let plan = RobotPlan.make(state, from: RobotFace(), reduced: false, seed: 5)
            let done = plan.frames[Int((plan.introDuration * RobotPlan.frameRate).rounded())]
            #expect(abs(done.left.x - 86) < 0.5 && abs(done.right.x - 154) < 0.5 && abs(done.headY) < 0.3, "\(state)")
            #expect(plan.frames[plan.frames.count - 1].distance(to: plan.face(at: plan.introSpan)) < 0.2, "\(state) jumps into the idle loop")
        }
    }

    @Test("Sleep holds closed eyes with the head lowered; wake opens them again")
    func sleepAndWake() {
        let sleep = RobotPlan.make(.sleep, from: RobotFace(), reduced: false, seed: 1)
        let asleep = sleep.frames[sleep.frames.count - 1]
        #expect(sleep.loop.isEmpty)
        #expect(abs(asleep.left.height - 10) < 0.5 && abs(asleep.headY - 4) < 0.05)
        let wake = RobotPlan.make(.wake, from: asleep, reduced: false, seed: 1)
        #expect(abs(wake.frames[wake.frames.count - 1].left.height - 58) < 0.5)
    }

    @Test("Waiting loops seamlessly")
    func waitingLoops() {
        for state in [RobotState.waiting, .waitingWrap] {
            let plan = RobotPlan.make(state, from: RobotFace(), reduced: false, seed: 2)
            #expect(plan.loop.count > 2)
            #expect(plan.loop[0].distance(to: plan.loop[plan.loop.count - 1]) < 1e-6)
            #expect(plan.loop[0].distance(to: plan.loop[1]) < 2, "\(state) jumps at the loop seam")
        }
    }

    @Test("The idle loop starts and ends at rest, so it can repeat forever")
    func idleLoopIsPeriodic() {
        let plan = RobotPlan.make(.idle, from: RobotFace(), reduced: false, seed: 9)
        let first = plan.loop[0], almostLast = plan.loop[plan.loop.count - 2]
        #expect(first.distance(to: almostLast) < 0.05)
        #expect(first.distance(to: RobotFace()) < 0.1)
        #expect(plan.loop.contains { abs($0.left.x - 86) > 5 }, "the eyes never wander")
    }

    @Test("Reduce Motion: no idle loop, no blinks, and pose changes dissolve instead of morphing")
    func reducedMotion() {
        let plan = RobotPlan.make(.success, from: RobotFace(), reduced: true, seed: 4)
        #expect(plan.loop.isEmpty && plan.blinkLoop.isEmpty)
        #expect(plan.frames.allSatisfy { $0.blink == 1 && $0.headY == 0 })
        #expect(plan.frames.contains { $0.eyesOpacity < 0.2 })
        #expect(!RobotPlan.make(.input, from: RobotFace(), reduced: true, seed: 4).caretBlinks)
    }

    // MARK: Blink scheduling

    @Test("Blinks keep upstream's spacing, including across the loop seam", arguments: [1, 2, 3, 99, 12345] as [UInt64])
    func blinkSchedule(seed: UInt64) {
        var random = RobotRandom(seed: seed)
        let blinks = RobotBlinks(random: &random)
        let events = blinks.events
        #expect((1800...3600).contains(events[0].at))
        for e in events { #expect((150...220).contains(e.duration)) }
        for (a, b) in zip(events, events.dropFirst()) {
            #expect((1900...4500 + 1e-6).contains(b.at - (a.at + a.duration)))
        }
        let last = events[events.count - 1]
        #expect(blinks.period + events[0].at - (last.at + last.duration) >= 1900)
        let mid = events[0].at + events[0].duration / 2
        #expect(abs(blinks.value(at: mid) - 0.08) < 0.02)
        #expect(blinks.value(at: events[0].at - 1) == 1)
    }

    @Test("A different seed gives a different rhythm")
    func blinkReseeding() {
        var a = RobotRandom(seed: 1), b = RobotRandom(seed: 2)
        #expect(RobotBlinks(random: &a).events.map(\.at) != RobotBlinks(random: &b).events.map(\.at))
    }

    // MARK: Springs and rubber banding

    @Test("A spring settles on its target")
    func springSettles() {
        var s = RobotSpring(value: 10)
        s.step(toward: 0, stiffness: 180, damping: 5.6, seconds: 3)
        #expect(abs(s.value) < 0.05 && abs(s.velocity) < 0.5)
    }

    @Test("Reduce Motion snaps the antenna to its target")
    func antennaSnaps() {
        var a = RobotAntenna()
        a.follow(CGPoint(x: 140, y: 20), seconds: 1.0 / 60, reduced: true)
        #expect(a.x.value == 140 && a.y.value == 20 && a.x.velocity == 0)
    }

    @Test("The jelly pull is capped however far the pointer goes")
    func jellyClamps() {
        var j = RobotJelly(hot: CGPoint(x: 200, y: 120), viewSize: 112)
        j.track(dx: 900, dy: -900, viewSize: 112)
        for _ in 0..<60 { _ = j.step(ms: 16.7, reduced: false) }
        #expect(abs(j.pull.dx) <= 25.0001 && abs(j.pull.dy) <= 25.0001)
        #expect(j.pull.dx > 24)
    }

    @Test("Pulling outward then letting go ends angry; pushing inward ends happy")
    func jellyReactions() {
        func release(dx: CGFloat) -> RobotReaction? {
            var j = RobotJelly(hot: CGPoint(x: 210, y: 120), viewSize: 112)
            j.track(dx: dx, dy: 0, viewSize: 112)
            for _ in 0..<20 { _ = j.step(ms: 16.7, reduced: false) }
            j.release()
            for _ in 0..<600 {
                if let done = j.step(ms: 16.7, reduced: false) { return done }
            }
            Issue.record("the jelly never settled")
            return nil
        }
        #expect(release(dx: 60) == .angry)
        #expect(release(dx: -60) == .success)
        #expect(release(dx: 5) == nil)
    }

    @Test("Release velocity carries into the spring and overshoots before settling")
    func jellyCarriesVelocity() {
        var j = RobotJelly(hot: CGPoint(x: 120, y: 30), viewSize: 112)
        j.track(dx: 0, dy: 10, viewSize: 112)
        _ = j.step(ms: 16.7, reduced: false)
        #expect(j.y.velocity > 0)
        j.release()
        var crossed = false
        for _ in 0..<600 where j.step(ms: 16.7, reduced: false) == nil {
            if j.y.value < -0.05 { crossed = true }
        }
        #expect(crossed)
        #expect(abs(j.y.value) < 0.35)
    }

    @Test("Squeeze squashes while held and wobbles back after release")
    func squeeze() {
        var s = RobotSqueeze()
        for _ in 0..<90 { _ = s.step(seconds: 1.0 / 60, reduced: false) }
        #expect(s.q > 0.9)
        #expect(abs(s.face(reduced: false).headScaleY - (1 - 0.29 * s.q)) < 0.05)
        s.release()
        var done = false, undershoot = false
        for _ in 0..<240 where !done {
            done = s.step(seconds: 1.0 / 60, reduced: false)
            if s.q < -0.01 { undershoot = true }
        }
        #expect(done && undershoot)
    }

    @Test("Antenna drag stretches toward the pointer, capped, and twangs home")
    func antennaDrag() {
        var d = RobotAntennaDrag(home: CGPoint(x: 120, y: 12), viewSize: 112)
        d.track(dx: 500, dy: 0, viewSize: 112)
        for _ in 0..<30 { _ = d.step(seconds: 1.0 / 60, reduced: false) }
        #expect(d.dot.x > 24 && d.dot.x <= 25.0001)
        #expect(d.tug.x > 5)
        d.release()
        var done = false
        for _ in 0..<300 where !done { done = d.step(seconds: 1.0 / 60, reduced: false) }
        #expect(done && d.reacts)
    }

    // MARK: Geometry

    @Test("The head outline is the upstream 160-point path, flattened to 90% height")
    func headOutline() {
        #expect(RobotGeometry.upstreamHead.count == 160)
        let ys = RobotGeometry.defaultHead.map(\.y)
        #expect(abs((ys.max()! - ys.min()!) - 180) < 0.01)
        #expect(RobotGeometry.head(roundness: 50) == RobotGeometry.defaultHead)
    }

    @Test("Roundness moves the corners out toward a square or in toward an oval")
    func roundness() {
        func corner(_ points: [CGPoint]) -> CGFloat {
            points.map { hypot($0.x - 120, $0.y - 120) }.max()!
        }
        let base = corner(RobotGeometry.defaultHead)
        #expect(corner(RobotGeometry.head(roundness: 0)) > base + 5)
        #expect(corner(RobotGeometry.head(roundness: 100)) < base - 5)
    }

    @Test("The jelly deformation moves the grab point by the full pull and leaves far points alone")
    func deformation() {
        let points = [CGPoint(x: 220, y: 120), CGPoint(x: 20, y: 120)]
        let out = RobotGeometry.deformed(points, hot: CGPoint(x: 220, y: 120), pull: CGVector(dx: 10, dy: 0))
        #expect(abs(out[0].x - 230) < 1e-9)
        #expect(abs(out[1].x - 20) < 0.02)
    }

    @Test("Wrap waiting starts and ends on the resting eyes")
    func wrapEndpoints() {
        for t in [0.0, RobotWrap.cycle] {
            let pose = RobotWrap.pose(at: t)
            #expect(abs(pose[0].x - 86) < 0.01 && abs(pose[1].x - 154) < 0.01)
            #expect(abs(pose[0].width - 54) < 0.01 && abs(pose[0].height - 58) < 0.01)
        }
    }

    @Test("Slot reels overshoot, bounce and land exactly on a whole turn")
    func reels() {
        for reel in RobotReel.pair {
            #expect(abs(reel.position(at: reel.landTime) - (reel.target + 8)) < 1e-6)
            #expect(reel.position(at: reel.endTime) == reel.target)
            #expect(abs((reel.target / RobotReel.period).rounded() * RobotReel.period - reel.target) < 1e-6)
        }
        #expect(RobotReel.pair[1].endTime > RobotReel.pair[0].endTime)
    }

    @Test("The upstream head easing curve is monotonic with fixed ends")
    func easing() {
        let e = RobotEase.head
        #expect(e(0) == 0 && e(1) == 1)
        let samples = stride(from: 0.0, through: 1.0, by: 0.05).map { e(CGFloat($0)) }
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
    }
}
