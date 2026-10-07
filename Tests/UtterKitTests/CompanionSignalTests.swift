import CoreGraphics
import Testing

@testable import UtterKit

/// The input rules behind the pet behaviours.
///
/// These are the parts most likely to be wrong in a way nobody notices: a threshold that
/// never fires, a latch that never clears, a decay that leaves the character stuck. Every
/// test drives a simulated clock, so a 1.2-second sustain is verified in microseconds and
/// nothing here needs a keyboard, a mouse, a screen or a permission grant.
@Suite("Companion input signals")
struct CompanionSignalTests {

    // MARK: Typing

    @Test("One keystroke is not typing; two inside the window are")
    func typingNeedsTwoKeys() {
        var typing = TypingActivity()
        typing.record(at: 0)
        #expect(typing.isTyping(at: 0) == false)

        typing.record(at: 0.2)
        #expect(typing.isTyping(at: 0.2))
    }

    @Test("Typing stops being true once the window passes")
    func typingDecays() {
        var typing = TypingActivity()
        typing.record(at: 0)
        typing.record(at: 0.1)
        #expect(typing.isTyping(at: 0.5))
        // Both strokes are now older than the 0.6s window.
        #expect(typing.isTyping(at: 0.8) == false)
    }

    @Test("Overheat needs the rate sustained, not just touched")
    func overheatNeedsSustain() {
        var typing = TypingActivity()
        // 10 keys/s - comfortably over the 6.0 threshold - but only for 0.5s, which is
        // under the 1.2s sustain. A fast burst mid-sentence must not turn the cat red.
        var time = 0.0
        while time < 0.5 {
            typing.record(at: time)
            typing.update(at: time)
            time += 0.1
        }
        #expect(typing.isOverheating == false)

        // Keep going past the sustain window and it should latch.
        while time < 2.0 {
            typing.record(at: time)
            typing.update(at: time)
            time += 0.1
        }
        #expect(typing.isOverheating)
    }

    @Test("Overheat clears when typing stops, without any further keystrokes")
    func overheatClearsOnItsOwn() {
        var typing = TypingActivity()
        var time = 0.0
        while time < 2.0 {
            typing.record(at: time)
            typing.update(at: time)
            time += 0.1
        }
        #expect(typing.isOverheating)

        // Hands off the keyboard. Only `update` runs from here - this is the case that
        // needs `update` to exist at all, because a state that can only be changed by an
        // event can never end when the events stop.
        while time < 4.0 {
            typing.update(at: time)
            time += 1.0 / 30.0
        }
        #expect(typing.isOverheating == false)
    }

    @Test("The cool threshold is below the trigger, so a typist at the edge does not flicker")
    func overheatHasHysteresis() {
        #expect(TypingActivity.coolRate < TypingActivity.overheatRate)

        var typing = TypingActivity()
        var time = 0.0
        // Get hot.
        while time < 2.0 {
            typing.record(at: time)
            typing.update(at: time)
            time += 0.1
        }
        #expect(typing.isOverheating)

        // Now type at 5 keys/s: under the 6.0 trigger, over the 3.5 cool. Someone
        // hovering right at the boundary should STAY hot rather than strobing.
        while time < 3.5 {
            typing.record(at: time)
            typing.update(at: time)
            time += 0.2
        }
        #expect(typing.isOverheating)
    }

    @Test("Heat is 0 while typing gently and rises with the rate")
    func heatScales() {
        var typing = TypingActivity()
        // 2 keys in the last second: under coolRate, so no heat at all.
        typing.record(at: 0.4)
        typing.record(at: 0.8)
        #expect(typing.heat(at: 1.0) == 0)

        var fast = TypingActivity()
        for i in 0..<9 { fast.record(at: Double(i) * 0.1) }
        let heat = fast.heat(at: 0.9)
        #expect(heat > 0)
        #expect(heat <= 1)
    }

    @Test("A keystroke timestamped in the past is ignored rather than corrupting the rate")
    func outOfOrderKeysDropped() {
        var typing = TypingActivity()
        typing.record(at: 1.0)
        typing.record(at: 0.5)          // two monitors delivering the same press
        #expect(typing.isTyping(at: 1.0) == false)
    }

    // MARK: Cursor

    @Test("A slow drag does not trigger a hunt; a flick does")
    func huntNeedsSpeed() {
        var cursor = CursorTracking()
        cursor.sample(CGPoint(x: 0, y: 0), at: 0)
        // 100pt in 0.5s = 200 pt/s. An ordinary reach.
        cursor.sample(CGPoint(x: 100, y: 0), at: 0.5)
        #expect(cursor.isHunting(at: 0.5) == false)

        var flick = CursorTracking()
        flick.sample(CGPoint(x: 0, y: 0), at: 0)
        // 900pt in 0.05s = 18000 pt/s. A throw across the display.
        flick.sample(CGPoint(x: 900, y: 0), at: 0.05)
        #expect(flick.isHunting(at: 0.05))
    }

    @Test("A hunt ends on its own")
    func huntExpires() {
        var cursor = CursorTracking()
        cursor.sample(CGPoint(x: 0, y: 0), at: 0)
        cursor.sample(CGPoint(x: 900, y: 0), at: 0.05)
        #expect(cursor.isHunting(at: 0.05))
        #expect(cursor.isHunting(at: 0.05 + CursorTracking.huntDuration + 0.01) == false)
    }

    @Test("Two samples in the same instant cannot divide by zero")
    func zeroIntervalIsSafe() {
        var cursor = CursorTracking()
        cursor.sample(CGPoint(x: 0, y: 0), at: 1.0)
        cursor.sample(CGPoint(x: 50, y: 0), at: 1.0)
        #expect(cursor.speed.isFinite)
    }

    @Test("Eye aim points toward the cursor and clamps at the edges")
    func eyeAimDirection() {
        let centre = CGPoint(x: 500, y: 500)

        let right = CursorTracking.aim(from: centre, to: CGPoint(x: 600, y: 500))
        #expect(right.dx > 0)
        #expect(abs(right.dy) < 0.001)

        let left = CursorTracking.aim(from: centre, to: CGPoint(x: 400, y: 500))
        #expect(left.dx < 0)

        // Far away in both axes: a unit vector, so the eyes cannot leave their sockets however
        // far the cursor goes.
        //
        // This asserted `dx == 1 && dy == 1`, which is per-axis clamping - and that is the one
        // shape of answer that breaks the promise in the line above. `SpritePack` draws the pupil
        // at `eyeAim.dx * eyeTravelPoints`, so the vector's *magnitude* is the distance from the
        // eye's centre: normalised, the pupil traces a circle of exactly `eyeTravelPoints` in
        // every direction, while (1, 1) is √2 ≈ 1.41 times that and would put it outside the
        // socket on the diagonals. The implementation normalises; the expectation was wrong.
        let far = CursorTracking.aim(from: centre, to: CGPoint(x: 5000, y: 5000))
        #expect(abs(hypot(far.dx, far.dy) - 1) < 0.001, "the pupil must stay on its socket circle")
        // 45 degrees away, so the two components are equal and both positive.
        #expect(abs(far.dx - far.dy) < 0.001)
        #expect(far.dx > 0)
        // Never beyond the socket on any axis either.
        #expect(far.dx <= 1 && far.dy <= 1)

        // The same holds however far away the cursor is, and on an off-diagonal.
        let veryFar = CursorTracking.aim(from: centre, to: CGPoint(x: 90_000, y: 500 + 30_000))
        #expect(abs(hypot(veryFar.dx, veryFar.dy) - 1) < 0.001)
    }

    @Test("The cursor sitting on the character means the eyes look straight ahead")
    func eyeAimCentred() {
        let aim = CursorTracking.aim(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 10))
        #expect(aim.dx == 0)
        #expect(aim.dy == 0)
    }

    // MARK: Petting

    @Test("Hovering without stroking does not purr")
    func hoverIsNotPetting() {
        var petting = PettingDetector()
        // Pointer resting on the character, drifting one way only.
        for i in 0..<30 {
            petting.sample(CGPoint(x: CGFloat(i) * 3, y: 0), inside: true,
                           at: Double(i) / 30.0)
        }
        #expect(petting.isPurring(at: 1.0) == false)
    }

    @Test("Stroking back and forth purrs")
    func strokingPurrs() {
        var petting = PettingDetector()
        var time = 0.0
        // Three full reversals: right, left, right, left.
        for pass in 0..<4 {
            let forward = pass % 2 == 0
            for step in 0..<10 {
                let x = forward ? CGFloat(step) * 4 : CGFloat(40 - step * 4)
                petting.sample(CGPoint(x: x, y: 0), inside: true, at: time)
                time += 1.0 / 30.0
            }
        }
        #expect(petting.isPurring(at: time))
    }

    @Test("Trackpad jitter under the deadband is not a stroke")
    func jitterIsNotPetting() {
        var petting = PettingDetector()
        var time = 0.0
        // Sub-pixel wobble around one spot, alternating direction every sample.
        for i in 0..<60 {
            let x: CGFloat = i % 2 == 0 ? 100.0 : 100.8
            petting.sample(CGPoint(x: x, y: 0), inside: true, at: time)
            time += 1.0 / 30.0
        }
        #expect(petting.isPurring(at: time) == false)
    }

    @Test("The purr lingers after the pointer leaves, then stops")
    func purrLingers() {
        var petting = PettingDetector()
        var time = 0.0
        for pass in 0..<4 {
            let forward = pass % 2 == 0
            for step in 0..<10 {
                let x = forward ? CGFloat(step) * 4 : CGFloat(40 - step * 4)
                petting.sample(CGPoint(x: x, y: 0), inside: true, at: time)
                time += 1.0 / 30.0
            }
        }
        #expect(petting.isPurring(at: time))

        petting.sample(CGPoint(x: 900, y: 900), inside: false, at: time)
        // Still purring immediately after the hand lifts...
        #expect(petting.isPurring(at: time + 0.2))
        // ...but not indefinitely.
        #expect(petting.isPurring(at: time + PettingDetector.purrLinger + 0.1) == false)
    }

    // MARK: Scrolling

    @Test("Scrolling unrolls the paper and stopping rolls it back")
    func scrollExtendsAndRetracts() {
        var scroll = ScrollActivity()
        #expect(scroll.isUnrolled == false)

        scroll.record(delta: 120, at: 0)
        #expect(scroll.extension_ > 0)
        #expect(scroll.isUnrolled)

        // Nothing happens until the retract delay passes - a pause between two flicks of
        // the same scroll should not snap the paper shut.
        scroll.update(at: 0.2, tick: 1.0 / 30.0)
        #expect(scroll.isUnrolled)

        var time = 0.5
        while time < 2.0 {
            scroll.update(at: time, tick: 1.0 / 30.0)
            time += 1.0 / 30.0
        }
        #expect(scroll.extension_ == 0)
        #expect(scroll.isUnrolled == false)
    }

    @Test("Extension saturates at fully unrolled")
    func scrollSaturates() {
        var scroll = ScrollActivity()
        scroll.record(delta: ScrollActivity.fullExtension * 10, at: 0)
        #expect(scroll.extension_ == 1)
    }

    @Test("Scrolling the other way still unrolls - direction is not the signal")
    func scrollDirectionAgnostic() {
        var up = ScrollActivity()
        up.record(delta: 100, at: 0)
        var down = ScrollActivity()
        down.record(delta: -100, at: 0)
        #expect(up.extension_ == down.extension_)
    }
}
