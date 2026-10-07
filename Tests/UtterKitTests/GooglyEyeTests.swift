import CoreGraphics
import Foundation
import Testing

@testable import UtterKit

/// The pupil's physics.
///
/// The whole point of `GooglyEyes` is that it does NOT arrive smoothly - it overshoots and
/// wobbles, which is what separates a googly eye from a security camera. So the tests assert
/// the overshoot exists, rather than only that it settles: a well-meaning change to the
/// damping that made the motion "smoother" would silently remove the effect and break nothing
/// else.
@Suite("Googly eyes")
struct GooglyEyeTests {

    private let tick: TimeInterval = 1.0 / 30.0

    /// Run the spring toward a target for `seconds`, returning every position it passed through.
    private func run(toward target: CGVector, seconds: Double,
                     from start: GooglyEyes = GooglyEyes()) -> [CGVector] {
        var eyes = start
        var path: [CGVector] = []
        var elapsed = 0.0
        while elapsed < seconds {
            eyes.settle(toward: target, tick: tick)
            path.append(eyes.offset)
            elapsed += tick
        }
        return path
    }

    @Test("The pupil starts centred")
    func startsCentred() {
        let eyes = GooglyEyes()
        #expect(eyes.offset.dx == 0)
        #expect(eyes.offset.dy == 0)
    }

    @Test("It lags behind the target rather than snapping to it")
    func lagsBehind() {
        // One tick after the cursor jumps to the far right, the pupil must NOT be there yet.
        // If it is, the spring has been replaced by an assignment and the effect is gone.
        var eyes = GooglyEyes()
        eyes.settle(toward: CGVector(dx: 1, dy: 0), tick: tick)
        #expect(eyes.offset.dx > 0, "it should have started moving")
        #expect(eyes.offset.dx < 0.5, "it should not have arrived in one tick")
    }

    @Test("It overshoots the target - this is the googly part")
    func overshoots() {
        let path = run(toward: CGVector(dx: 1, dy: 0), seconds: 1.0)
        let peak = path.map(\.dx).max() ?? 0
        // Underdamped, so it goes past 1 before settling back. Clamped at 1 on magnitude, so
        // the observable overshoot is that it REACHES the rim and stays pinned for a moment
        // rather than easing in.
        #expect(peak >= 0.999, "the pupil never reached the rim: \(peak)")
        // And it is still there - or near it - at the end, rather than having drifted off.
        #expect((path.last?.dx ?? 0) > 0.9)
    }

    @Test("It settles rather than oscillating forever")
    func settles() {
        let path = run(toward: CGVector(dx: 0.5, dy: 0), seconds: 2.0)
        // The last quarter second should be essentially still.
        let tail = path.suffix(8).map(\.dx)
        let spread = (tail.max() ?? 0) - (tail.min() ?? 0)
        #expect(spread < 0.02, "still wobbling after two seconds: spread \(spread)")
        #expect(abs((path.last?.dx ?? 0) - 0.5) < 0.02, "settled on the wrong value")
    }

    @Test("It comes back to centre when the target does")
    func returnsToCentre() {
        var eyes = GooglyEyes()
        for _ in 0..<60 { eyes.settle(toward: CGVector(dx: 1, dy: 0), tick: tick) }
        #expect(eyes.offset.dx > 0.9)

        for _ in 0..<90 { eyes.settle(toward: CGVector(dx: 0, dy: 0), tick: tick) }
        #expect(abs(eyes.offset.dx) < 0.05, "the pupil did not roll back to centre")
    }

    @Test("The pupil never leaves its socket, including on the diagonals")
    func clampedToTheSocketCircle() {
        // A diagonal target is the case per-axis clamping gets wrong: (1, 1) has magnitude
        // 1.41, which would put the bead outside a round white.
        let path = run(toward: CGVector(dx: 1, dy: 1), seconds: 2.0)
        for offset in path {
            let magnitude = hypot(offset.dx, offset.dy)
            #expect(magnitude <= 1.0001, "pupil left the socket: magnitude \(magnitude)")
        }
    }

    @Test("A driven pupil does not stick to the rim")
    func reboundsOffTheRim() {
        // Held hard against the right edge, then the cursor jumps to the far left. The
        // outward velocity is cancelled at the clamp, so it must leave immediately rather
        // than sitting there while accumulated speed bleeds off.
        //
        // Asserted as "how far, how fast", not as "kept decreasing on every tick" - the
        // first version of this test counted ticks where `dx` fell and demanded 15 of 20.
        // That failed at 6, and the 6 was correct: this spring crosses to the opposite rim
        // in about a fifth of a second and is then clamped there, so it stops decreasing
        // because it has *arrived*. The test was describing a slower spring than the one
        // the effect needs.
        var eyes = GooglyEyes()
        for _ in 0..<60 { eyes.settle(toward: CGVector(dx: 1, dy: 0), tick: tick) }
        #expect(eyes.offset.dx > 0.9, "setup: should be pinned at the right rim")

        for _ in 0..<3 { eyes.settle(toward: CGVector(dx: -1, dy: 0), tick: tick) }
        #expect(eyes.offset.dx < 0.5, "the pupil stuck at the rim instead of releasing")

        for _ in 0..<20 { eyes.settle(toward: CGVector(dx: -1, dy: 0), tick: tick) }
        #expect(eyes.offset.dx < -0.9, "the pupil never crossed to the other side")
    }

    @Test("A stalled run loop cannot fling the pupil across the face")
    func hugeTickIsClamped() {
        var eyes = GooglyEyes()
        // Two seconds in one tick - what a wedged run loop delivers. An unclamped spring
        // integrates that into an enormous velocity.
        eyes.settle(toward: CGVector(dx: 1, dy: 0), tick: 2.0)
        #expect(hypot(eyes.offset.dx, eyes.offset.dy) <= 1.0001)
        #expect(eyes.offset.dx.isFinite)
    }

    @Test("Reset stops the motion dead")
    func resetClearsVelocity() {
        var eyes = GooglyEyes()
        for _ in 0..<10 { eyes.settle(toward: CGVector(dx: 1, dy: 0), tick: tick) }
        eyes.reset()
        #expect(eyes.offset.dx == 0)
        // With velocity cleared, one tick toward centre must leave it at centre - if the
        // velocity had survived, it would keep coasting.
        eyes.settle(toward: CGVector(dx: 0, dy: 0), tick: tick)
        #expect(abs(eyes.offset.dx) < 0.0001)
    }
}
