import Testing
import AppKit
@testable import UtterKit

/// Frame selection under variable per-frame timing.
///
/// This is the behaviour that justifies APNG over a sprite strip, so it is the part
/// most worth pinning: an animator holds a pose and then snaps through the next few
/// frames, and any implementation that divides elapsed time by an average frame rate
/// shows the wrong frame everywhere except by coincidence.
@Suite("Companion animation timing")
struct CompanionAnimationTests {

    /// A 4-frame animation that holds frame 0 for 0.5s, then runs 3 frames at 0.08s.
    private func holdThenSnap() -> CompanionAnimation {
        CompanionAnimation(
            frames: (0..<4).map { _ in NSImage(size: NSSize(width: 8, height: 8)) },
            delays: [0.5, 0.08, 0.08, 0.08]
        )
    }

    @Test("The long hold occupies its full duration")
    func longHold() {
        let animation = holdThenSnap()
        #expect(animation.frameIndex(at: 0) == 0)
        #expect(animation.frameIndex(at: 0.25) == 0)
        // Still inside the 0.5s hold. An averaged frame rate (0.185s/frame) would
        // already be showing frame 2 here.
        #expect(animation.frameIndex(at: 0.49) == 0)
    }

    @Test("Each snapped frame gets its own slot")
    func snappedFrames() {
        let animation = holdThenSnap()
        #expect(animation.frameIndex(at: 0.51) == 1)
        #expect(animation.frameIndex(at: 0.59) == 2)
        #expect(animation.frameIndex(at: 0.67) == 3)
    }

    @Test("Cycle length is the sum of the delays")
    func duration() {
        #expect(abs(holdThenSnap().duration - 0.74) < 0.0001)
    }

    @Test("Playback loops")
    func loops() {
        let animation = holdThenSnap()
        #expect(animation.frameIndex(at: animation.duration + 0.01) == 0)
        // Several cycles in, it still lines up.
        #expect(animation.frameIndex(at: animation.duration * 3 + 0.51) == 1)
    }

    @Test("A time past the last frame clamps rather than crashing")
    func clampsAtEnd() {
        let animation = holdThenSnap()
        // Exactly on the boundary: the accumulated-delay walk must not fall off the
        // end of the array.
        #expect(animation.frameIndex(at: animation.duration) == 0)
        #expect(animation.frameIndex(at: 1_000_000) < animation.frames.count)
    }

    @Test("A single still never drifts and never divides by zero")
    func stillImage() {
        let still = CompanionAnimation.still(NSImage(size: NSSize(width: 8, height: 8)))
        #expect(still.frames.count == 1)
        #expect(still.duration > 0)
        #expect(still.frameIndex(at: 0) == 0)
        #expect(still.frameIndex(at: 99) == 0)
    }

    @Test("More delays than frames cannot index past the end")
    func moreDelaysThanFrames() {
        // `frameIndex` walks `delays` and returns that walk's index, which the renderer
        // then uses to subscript `frames` - so a mismatched pair is a crash, not a
        // glitch. The loader keeps them in step on every path, but the type does not
        // enforce it, and the clamp costs one comparison.
        let animation = CompanionAnimation(
            frames: (0..<2).map { _ in NSImage(size: NSSize(width: 4, height: 4)) },
            delays: [0.1, 0.1, 0.1, 0.1, 0.1]
        )
        // Sweep the whole cycle and past it: every answer must be a real index.
        for step in 0...120 {
            let index = animation.frameIndex(at: Double(step) * 0.01)
            #expect(animation.frames.indices.contains(index))
        }
    }

    @Test("Equal delays hold for equal time when sampled on the engine's tick")
    func evenDelaysStayEven() {
        // The companion samples at 30 Hz, so a frame's hold is a whole number of ticks
        // and rates that do not divide 30 cannot be perfectly even. What must not
        // happen is a *second* grid on top of that: flooring the clock to 1/24 s before
        // asking for a frame doubled the error at 5 and 10 fps, which are rates the
        // shipped packs use.
        for fps in [5.0, 8.0, 10.0, 12.0] {
            let frameCount = 8
            let animation = CompanionAnimation(
                frames: (0..<frameCount).map { _ in NSImage(size: NSSize(width: 4, height: 4)) },
                delays: Array(repeating: 1.0 / fps, count: frameCount)
            )
            let ticks = Int((animation.duration * 30).rounded())
            var holds = [Int](repeating: 0, count: frameCount)
            for tick in 0..<ticks {
                holds[animation.frameIndex(at: Double(tick) / 30.0)] += 1
            }
            let ideal = Double(ticks) / Double(frameCount)
            // Every frame gets its share to within one tick - no frame is dropped, and
            // none is held for twice its neighbour.
            for (index, hold) in holds.enumerated() {
                #expect(abs(Double(hold) - ideal) <= 1,
                        "fps \(fps) frame \(index) held \(hold) ticks, ideal \(ideal)")
            }
            #expect(holds.reduce(0, +) == ticks)
        }
    }

    @Test("The drawn frame index holds across in-between ticks and advances by one on a boundary")
    func frameIndexHoldsBetweenBoundaries() {
        // The invariant the memoised `SpriteBodyLayer` relies on: at 30 Hz sampling an 8 fps
        // state the frame index is identical for several consecutive ticks and only changes
        // on a boundary. If it stopped holding, memoisation would merely be pointless (nothing
        // to skip) rather than wrong - so this is the property worth pinning next to the view.
        let fps = 8.0
        let frameCount = 8
        let animation = CompanionAnimation(
            frames: (0..<frameCount).map { _ in NSImage(size: NSSize(width: 4, height: 4)) },
            delays: Array(repeating: 1.0 / fps, count: frameCount)
        )
        let ticks = Int((animation.duration * 30).rounded())
        let indices = (0..<ticks).map { animation.frameIndex(at: Double($0) / 30.0) }

        // At least one run of identical consecutive indices - an in-between tick a memoised
        // view skips. (8 fps against 30 Hz holds each frame ~3.75 ticks.)
        #expect(zip(indices, indices.dropFirst()).contains { $0 == $1 })

        // Every change steps forward by exactly one frame, or wraps to 0 - never a skip, so
        // the memoised layer never misses a frame the engine intended to show.
        for (previous, next) in zip(indices, indices.dropFirst()) where previous != next {
            #expect(next == previous + 1 || next == 0)
        }
    }

    @Test("A zero-delay animation cannot divide by zero")
    func zeroDelays() {
        // Defensive: a malformed pack could report every delay as 0. `duration` floors
        // at a positive value, so the modulo in `frameIndex` stays defined.
        let broken = CompanionAnimation(
            frames: (0..<3).map { _ in NSImage(size: NSSize(width: 4, height: 4)) },
            delays: [0, 0, 0]
        )
        #expect(broken.duration > 0)
        #expect(broken.frameIndex(at: 1.5) < 3)
    }
}
