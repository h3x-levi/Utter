import AppKit
import Testing

@testable import UtterKit

/// How the pet moods — the ones driven by the user's hands rather than by Utter's work —
/// take hold, take precedence over each other, and let go.
///
/// This is the part of the companion most likely to break in a way that is annoying rather
/// than obvious: a mood that never ends leaves the character stuck kneading at an empty
/// keyboard, and a mood that outranks a recording makes the app look broken during
/// dictation. Both are cheap to assert and impossible to notice by hand.
///
/// Everything is driven by injected sources and a stepped clock, so nothing here touches a
/// mouse, a keyboard, a screen or a permission grant.
@Suite("Companion pet moods")
@MainActor
struct CompanionPetMoodTests {

    /// The character's own rect, and a pointer far outside it.
    private let catRect = NSRect(x: 500, y: 500, width: 52, height: 52)
    private let farAway = CGPoint(x: 2000, y: 2000)

    private func makeEngine() -> CompanionBehaviour {
        let engine = CompanionBehaviour()
        engine.rng = SeededGenerator(seed: 0x5EED)
        engine.characterRectSource = { self.catRect }
        engine.cursorSource = { self.farAway }
        // The keystroke count is process-global, so a previous test's typing would leak in
        // as a delta on this engine's first tick.
        KeystrokeTicker.resetForTesting()
        return engine
    }

    /// Type `count` keys, then let the engine observe them.
    private func type(_ count: Int, on engine: CompanionBehaviour, over seconds: Double) {
        let perKey = seconds / Double(max(count, 1))
        for _ in 0..<count {
            KeystrokeTicker.note()
            engine.step(perKey)
        }
    }

    // MARK: Taking hold

    @Test("Typing makes the character knead")
    func typingKneads() {
        let engine = makeEngine()
        type(6, on: engine, over: 0.5)
        #expect(engine.mood == .kneading)
    }

    @Test("Kneading stops once the typing stops")
    func kneadingEnds() {
        let engine = makeEngine()
        type(6, on: engine, over: 0.5)
        #expect(engine.mood == .kneading)

        // Hands off. No further keystrokes are recorded — the mood has to end on its own,
        // which is the case a purely event-driven design gets wrong.
        engine.step(2.0)
        #expect(engine.mood == .resting)
    }

    @Test("Typing hard enough overheats, and it cools down again")
    func typingOverheats() {
        let engine = makeEngine()
        // 24 keys in 2s = 12/s, over the 6/s trigger for longer than the 1.2s sustain.
        type(24, on: engine, over: 2.0)
        #expect(engine.mood == .overheating)
        #expect(engine.heat > 0)

        engine.step(3.0)
        #expect(engine.mood == .resting)
        #expect(engine.heat == 0)
    }

    @Test("Flicking the cursor makes the character hunt, and the hunt ends")
    func cursorFlickHunts() {
        let engine = makeEngine()
        var pointer = CGPoint(x: 100, y: 100)
        engine.cursorSource = { pointer }

        engine.step(1.0 / 30.0)
        // ~1500pt in one tick is a throw across the display, far past the 1400 pt/s trigger.
        pointer = CGPoint(x: 1600, y: 100)
        engine.step(1.0 / 30.0)
        #expect(engine.mood == .hunting)

        engine.step(CursorTracking.huntDuration + 0.2)
        #expect(engine.mood == .resting)
    }

    @Test("Dragging the character makes it hang, and releasing lets it go")
    func draggingHolds() {
        let engine = makeEngine()
        engine.isBeingDragged = true
        engine.step(0.2)
        #expect(engine.mood == .held)

        engine.isBeingDragged = false
        engine.step(0.2)
        #expect(engine.mood == .resting)
    }

    // MARK: Precedence

    @Test("Being held outranks everything else")
    func heldWins() {
        let engine = makeEngine()
        engine.isBeingDragged = true
        // Type hard at the same time: overheating would otherwise win.
        type(24, on: engine, over: 2.0)
        #expect(engine.mood == .held)
    }

    @Test("Overheating outranks kneading, because a flustered typist is still typing")
    func overheatOutranksKnead() {
        let engine = makeEngine()
        type(24, on: engine, over: 2.0)
        #expect(engine.mood == .overheating)
        // Not `.kneading`, even though `isTyping` is also true — otherwise the two
        // alternate every tick.
    }

    @Test("Utter's own work always outranks the pet moods")
    func dictationWins() {
        let engine = makeEngine()
        // Recording, and typing at the same time.
        engine.apply(pillState: .recording)
        type(10, on: engine, over: 0.8)
        #expect(engine.mood == .alert)

        // And a transcription in progress is not interrupted either.
        engine.apply(pillState: .processing(.transcribing))
        type(10, on: engine, over: 0.8)
        #expect(engine.mood == .thinking)
    }

    @Test("A timed reaction is allowed to finish before a pet mood takes over")
    func transientMoodNotInterrupted() {
        let engine = makeEngine()
        // A failure holds `startled` for 2.4s. Typing through it must not cut it short —
        // the character reporting an error then immediately kneading reads as the error
        // never having happened.
        engine.apply(pillState: .error("nope"))
        #expect(engine.mood == .startled)
        type(8, on: engine, over: 0.6)
        #expect(engine.mood == .startled)
    }

    // MARK: Petting

    @Test("Stroking the character over its own rect makes it purr")
    func strokingPurrs() {
        let engine = makeEngine()
        var pointer = CGPoint(x: catRect.midX, y: catRect.midY)
        engine.cursorSource = { pointer }

        // Four passes back and forth inside the cat's rect.
        for pass in 0..<4 {
            for step in 0..<8 {
                let offset = pass % 2 == 0 ? CGFloat(step) * 5 : CGFloat(40 - step * 5)
                pointer = CGPoint(x: catRect.minX + offset, y: catRect.midY)
                engine.step(1.0 / 30.0)
            }
        }
        #expect(engine.mood == .purring)
    }

    @Test("A pointer moving the same way over the character is not petting")
    func hoverDoesNotPurr() {
        let engine = makeEngine()
        var pointer = CGPoint(x: catRect.minX, y: catRect.midY)
        engine.cursorSource = { pointer }
        for step in 0..<30 {
            pointer = CGPoint(x: catRect.minX + CGFloat(step), y: catRect.midY)
            engine.step(1.0 / 30.0)
        }
        #expect(engine.mood != .purring)
    }

    // MARK: Eyes

    /// The pupils ROLL to the cursor rather than pointing at it.
    ///
    /// This test used to assert `eyeAim.dx == 1` after 0.1s, i.e. that the eyes arrive
    /// instantly. They no longer do, deliberately: the pupil is a bead on a damped spring
    /// (`GooglyEyes`), so 0.1s in it has travelled 0.42 of the way and it reaches the rim a
    /// few tenths later. Instant arrival is precisely the behaviour that read as a security
    /// camera rather than an eye, so the assertion is the thing that changed, not a
    /// regression. What must still hold is direction, arrival, and never leaving the socket.
    @Test("The eyes roll toward the cursor and stay inside the socket")
    func eyesTrackCursor() {
        let engine = makeEngine()
        engine.cursorSource = { CGPoint(x: self.catRect.midX + 120, y: self.catRect.midY) }
        engine.step(0.1)
        let earlyRight = engine.pose.eyeAim.dx
        #expect(earlyRight > 0, "should have started rolling right")
        #expect(earlyRight < 1, "should not have arrived instantly — that is the lag")

        // Given time, it does arrive.
        engine.step(0.5)
        #expect(engine.pose.eyeAim.dx > 0.9)

        engine.cursorSource = { CGPoint(x: self.catRect.midX - 120, y: self.catRect.midY) }
        engine.step(0.6)
        #expect(engine.pose.eyeAim.dx < 0)

        // However far the cursor goes, the bead stays on its circle.
        engine.cursorSource = { CGPoint(x: self.catRect.midX + 100_000, y: self.catRect.midY) }
        engine.step(0.6)
        #expect(engine.pose.eyeAim.dx > 0.9)
        #expect(hypot(engine.pose.eyeAim.dx, engine.pose.eyeAim.dy) <= 1.0001)
    }

    @Test("A sleeping character does not track the cursor")
    func sleepingEyesAreStill() {
        let engine = makeEngine()
        engine.cursorSource = { CGPoint(x: self.catRect.midX + 200, y: self.catRect.midY) }
        // Past the 90s sleep threshold. Nothing else may happen in that time, so the
        // cursor is held still by returning a constant.
        engine.step(95)
        #expect(engine.mood == .sleepy)
        #expect(engine.pose.eyeAim.dx == 0)
        #expect(engine.pose.eyeAim.dy == 0)
    }

    // MARK: The off switch

    @Test("Disabling pet behaviours makes every local signal inert")
    func disabledIsInert() {
        let engine = makeEngine()
        engine.petBehavioursEnabled = false

        type(24, on: engine, over: 2.0)
        #expect(engine.mood == .resting)
        #expect(engine.heat == 0)

        engine.isBeingDragged = true
        engine.step(0.3)
        #expect(engine.mood == .resting)

        engine.recordScroll(delta: 500)
        engine.step(0.3)
        #expect(engine.paperExtension == 0)
    }

    @Test("Scrolling unrolls the paper and it rolls back up")
    func scrollingUnrollsPaper() {
        let engine = makeEngine()
        engine.recordScroll(delta: 200)
        engine.step(1.0 / 30.0)
        #expect(engine.paperExtension > 0)

        engine.step(3.0)
        #expect(engine.paperExtension == 0)
    }

    @Test("Scrolling wakes a sleeping character")
    func scrollingWakes() {
        let engine = makeEngine()
        engine.step(95)
        #expect(engine.mood == .sleepy)

        engine.recordScroll(delta: 120)
        #expect(engine.mood != .sleepy)
    }
}
