import Testing
import AppKit
@testable import UtterKit

/// The companion's behaviour engine.
///
/// Driven by stepping its clock directly rather than by waiting on the real 30 Hz
/// ticker: a test that sleeps for 90 seconds to watch the character fall asleep is a
/// test nobody runs. `step(_:)` advances simulated time in tick-sized increments, so
/// these exercise exactly the code path the timer does, at whatever speed the machine
/// can manage.
@Suite("Companion behaviour")
@MainActor
struct CompanionBehaviourTests {

    /// An engine with the window's real geometry limits applied, as the app does.
    private func makeEngine(
        _ geometry: CompanionGeometry = CompanionGeometry(UserData.defaultCompanionSize),
        seed: UInt64 = 0x5EED
    ) -> CompanionBehaviour {
        let engine = CompanionBehaviour()
        engine.roamRange = geometry.roamRange
        engine.hopHeight = geometry.hopHeight
        // Seeded, so a suite about randomly chosen behaviour is reproducible. See
        // `CompanionBehaviour.rng`.
        engine.rng = SeededGenerator(seed: seed)
        return engine
    }

    // MARK: Mood mapping

    @Test("Recording makes the character alert")
    func recordingIsAlert() {
        let engine = makeEngine()
        engine.apply(pillState: .recording)
        engine.step(0.2)
        #expect(engine.mood == .alert)
    }

    @Test("Processing makes the character think")
    func processingThinks() {
        let engine = makeEngine()
        engine.apply(pillState: .processing(.transcribing))
        engine.step(0.2)
        #expect(engine.mood == .thinking)
    }

    @Test("An error startles the character and speaks the reason")
    func errorIsStartled() {
        let engine = makeEngine()
        engine.apply(pillState: .error("No speech detected"))
        engine.step(0.2)
        #expect(engine.mood == .startled)
        #expect(engine.quip == "No speech detected")
    }

    @Test("Transient moods expire back to rest")
    func transientMoodsExpire() {
        let engine = makeEngine()
        engine.apply(pillState: .error("Boom"))
        engine.step(0.2)
        #expect(engine.mood == .startled)
        engine.step(3.0)
        #expect(engine.mood == .resting)
    }

    @Test("Finishing work earns a celebration, then rest")
    func celebratesAfterWork() {
        let engine = makeEngine()
        engine.apply(pillState: .processing(.typing))
        engine.step(0.2)
        engine.apply(pillState: .idle)
        engine.step(0.2)
        #expect(engine.mood == .delighted)
        engine.step(2.0)
        #expect(engine.mood == .resting)
    }

    @Test("Going idle from a cold start does not celebrate")
    func doesNotCelebrateForNothing() {
        // Merely showing the companion must not make it cheer — only finishing real
        // work does.
        let engine = makeEngine()
        engine.apply(pillState: .idle)
        engine.step(0.5)
        #expect(engine.mood == .resting)
    }

    // MARK: Live signal

    @Test("The listening bounce follows the real microphone level")
    func bounceFollowsLevel() {
        let engine = makeEngine()
        var level: Float = 0
        engine.levelSource = { level }
        engine.apply(pillState: .recording)

        level = 0.9
        engine.step(0.3)
        let loud = engine.pose.squash

        level = 0
        engine.step(0.3)
        let quiet = engine.pose.squash

        // Real signal in, real deformation out — not a timer.
        #expect(loud > quiet)
    }

    // MARK: Position

    /// Run at every size the settings offer: the limits are a fraction of the character,
    /// so the engine is handed a different pair of numbers for each, and the panel that
    /// has to contain the result grows with them.
    @Test("Roaming stays within the panel's safe range", arguments: CompanionSize.allCases)
    func roamingIsBounded(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        let engine = makeEngine(geometry)
        var worstX: CGFloat = 0
        var worstY: CGFloat = 0
        // Long enough for many ambient acts to be chosen and completed.
        for _ in 0..<3_000 {
            engine.step(1.0 / 30.0)
            worstX = max(worstX, abs(engine.offsetX))
            worstY = max(worstY, abs(engine.offsetY))
        }
        #expect(worstX <= geometry.roamRange + 0.001)
        #expect(worstY <= geometry.hopHeight + 0.001)
    }

    @Test("The character returns to its post when work starts")
    func returnsHomeOnDuty() {
        let engine = makeEngine()
        // Wander until it is genuinely away from home.
        var wandered = false
        for _ in 0..<3_000 {
            engine.step(1.0 / 30.0)
            if abs(engine.offsetX) > 5 { wandered = true; break }
        }
        #expect(wandered, "the character never left its home spot")

        // Something happens: it must walk back rather than stay where it stopped.
        engine.apply(pillState: .recording)
        engine.step(1.0)
        #expect(abs(engine.offsetX) < 0.01)
        #expect(abs(engine.offsetY) < 0.01)
    }

    @Test("A finished stroll still returns home when work starts")
    func returnsHomeFromIdleAct() {
        // The regression this pins: the return trip was only scheduled when the current
        // act was not `.idle`, but `.idle` is the most common act — so a character that
        // finished strolling and settled was already `.idle` when recording began, no
        // return was scheduled, and it stayed ~10pt off post for the whole turn.
        let engine = makeEngine()
        for _ in 0..<3_000 {
            engine.step(1.0 / 30.0)
            if abs(engine.offsetX) > 5 { break }
        }
        // Let the current act finish so the engine settles into `.idle` while away.
        for _ in 0..<200 { engine.step(1.0 / 30.0) }

        engine.apply(pillState: .processing(.transcribing))
        engine.step(1.0)
        #expect(abs(engine.offsetX) < 0.01)
    }

    // MARK: Dragging holds the character still

    @Test("Dragging freezes ambient motion, so the character tracks the cursor 1:1")
    func draggingFreezesAmbientMotion() {
        // The reported jitter: a stroll, a walk or the return-home animation kept mutating
        // the offset during a drag, and because the offset is applied to the character view
        // under a live DragGesture, that shifted the gesture's own coordinate space and the
        // character oscillated against the pointer. While dragging, the offset must hold at
        // zero so the window (which the drag moves) is the only thing that changes.
        let engine = makeEngine()
        // Wander until there is an offset to suppress.
        for _ in 0..<3_000 {
            engine.step(1.0 / 30.0)
            if abs(engine.offsetX) > 3 { break }
        }

        engine.isBeingDragged = true
        // The window folds the carried offset into its own origin, so nothing jumps.
        _ = engine.takeAmbientOffsetForDrag()
        for _ in 0..<300 {
            engine.step(1.0 / 30.0)
            #expect(engine.offsetX == 0, "offset moved during a drag")
            #expect(engine.offsetY == 0, "offset moved during a drag")
        }
        #expect(engine.mood == .held)
    }

    // MARK: Walking across the screen

    @Test("The character walks across a simulated screen and turns at the edges")
    func walksAndTurnsAtEdges() {
        let engine = makeEngine()
        // A track the window can travel along, clamped as the real screen clamp would.
        var x = 0.0
        let minX = -120.0, maxX = 120.0
        engine.walkStep = { dx in
            let want = min(max(x + Double(dx), minX), maxX)
            let actual = want - x
            x = want
            return CGFloat(actual)
        }

        var moved = false
        var farthestRight = 0.0
        var farthestLeft = 0.0
        for _ in 0..<9_000 {          // ~5 minutes of simulated time — many ambient acts
            engine.step(1.0 / 30.0)
            if x != 0 { moved = true }
            farthestRight = max(farthestRight, x)
            farthestLeft = min(farthestLeft, x)
        }
        #expect(moved, "the character never walked anywhere")
        // Stayed on the track: the window clamp plus the turn-at-edge logic keep it on screen.
        #expect(farthestRight <= maxX + 0.001)
        #expect(farthestLeft >= minX - 0.001)
    }

    @Test("Reduce Motion stops the walk")
    func reduceMotionStopsWalking() {
        let engine = makeEngine()
        engine.reduceMotionOverride = true
        var x = 0.0
        engine.walkStep = { dx in x += Double(dx); return dx }
        for _ in 0..<6_000 { engine.step(1.0 / 30.0) }
        #expect(x == 0, "the character walked under Reduce Motion")
    }

    @Test("A character being dragged does not also walk")
    func draggingStopsWalking() {
        let engine = makeEngine()
        var x = 0.0
        engine.walkStep = { dx in x += Double(dx); return dx }
        engine.isBeingDragged = true
        for _ in 0..<6_000 { engine.step(1.0 / 30.0) }
        #expect(x == 0, "a dragged character walked as well")
    }

    // MARK: Sleep

    @Test("The character sleeps after a long rest")
    func sleepsWhenIdle() {
        let engine = makeEngine()
        engine.step(95)
        #expect(engine.mood == .sleepy)
        // Parked at home, not asleep mid-stride.
        #expect(engine.offsetX == 0)
    }

    @Test("Real work wakes a sleeping character")
    func wakesOnWork() {
        let engine = makeEngine()
        engine.step(95)
        #expect(engine.mood == .sleepy)

        engine.apply(pillState: .recording)
        engine.step(0.2)
        #expect(engine.mood == .alert)
    }

    // MARK: Sprite timing

    @Test("Mood elapsed time restarts with each mood")
    func moodElapsedResets() {
        // A sprite pack animates against this, so it must restart when the mood does —
        // otherwise `delighted` would begin part-way through its strip.
        let engine = makeEngine()
        engine.apply(pillState: .processing(.transcribing))
        engine.step(2.0)
        #expect(engine.moodElapsed > 1.5)

        engine.apply(pillState: .idle)
        engine.step(1.0 / 30.0)
        #expect(engine.moodElapsed < 0.5)
    }

    @Test("Mood elapsed time is the clock, not a coarser grid")
    func moodElapsedIsNotQuantised() {
        // This was floored to a 1/24 s grid, to stop a value that changes every tick
        // from invalidating the SwiftUI body 30x/second. It could not: it shares
        // `CompanionFrame` with `pose`, `offsetX` and `offsetY`, the pose alone changes on
        // every tick (see `everyTickPublishesSomething`), and a view observing the object
        // cannot be updated less often than that.
        //
        // The grid was not free, though. 24 does not divide by 5 or 10, and packs
        // declare those rates, so frame boundaries landed unevenly: an 8-frame state
        // at 10 fps held its frames for [4,3,3,3,2,4,3,2] ticks instead of an even 3.
        // Sampling the raw clock gives [3,3,4,2,3,3,3,3] — half the deviation.
        let engine = makeEngine()
        let tick = 1.0 / 30.0
        for step in 1...12 {
            engine.step(tick)
            // Exactly `step` ticks of the engine's own clock, to floating-point noise.
            #expect(abs(engine.moodElapsed - Double(step) * tick) < 1e-9)
        }
    }

    @Test("Something published changes on every single tick")
    func everyTickPublishesSomething() {
        // The measurement the line above rests on. `pose` alone plateaus — a hop holds
        // one squash value for several ticks — but `offsetY` is moving through exactly
        // those ticks, so the observing view is invalidated either way.
        let engine = makeEngine()
        var unchanged = 0
        var previous: (CompanionPose, CGFloat, CGFloat)?
        for _ in 0..<600 {
            engine.step(1.0 / 30.0)
            let current = (engine.pose, engine.offsetX, engine.offsetY)
            if let previous,
               previous.0 == current.0, previous.1 == current.1, previous.2 == current.2 {
                unchanged += 1
            }
            previous = current
        }
        #expect(unchanged == 0, "\(unchanged) ticks published nothing")
    }

    // MARK: Accessibility

    @Test("Reduce Motion holds the character still but keeps its expression")
    func reduceMotionStopsMovement() {
        let engine = makeEngine()
        engine.reduceMotionOverride = true
        engine.apply(pillState: .processing(.transcribing))
        for _ in 0..<600 { engine.step(1.0 / 30.0) }

        // No travel, no rocking, no deformation.
        #expect(engine.offsetX == 0)
        #expect(engine.offsetY == 0)
        #expect(engine.pose.lean == 0)
        #expect(engine.pose.squash == 1)
        // But the state is still legible: Reduce Motion asks for less movement, not
        // less information.
        #expect(engine.mood == .thinking)
    }

    // MARK: Publish rate
    //
    // The companion's ticker is the app's idle-CPU floor, and it is not the engine's
    // arithmetic that costs — a release-build `tick()` measures ~2.7 us, which at 30 Hz is
    // 0.008% of one core. What costs is what each `objectWillChange` send does downstream in
    // SwiftUI's dependency graph, so the number of sends per tick is the thing worth pinning.

    @Test("A tick publishes exactly once, however much of the frame it changes")
    func oneSendPerTick() {
        // `pose`, `offsetX`, `offsetY` and `moodElapsed` were four separate `@Published`
        // properties, so one tick entered the dependency graph two to four times to describe
        // one frame — measured 2.115 sends/tick at rest and a full 4.000 under Reduce Motion,
        // whose branch re-assigns `offsetX = 0; offsetY = 0` every tick to say nothing moved.
        // They now share `CompanionFrame`, published once at the top of `tick()`.
        //
        // Asserted as an exact count rather than a bound: "at most 4" would have passed
        // before the change, which is the entire defect this is guarding.
        for reduceMotion in [false, true] {
            let engine = makeEngine()
            engine.reduceMotionOverride = reduceMotion
            // Settle first, so a mood change from a cold start is not counted as a tick send.
            engine.step(1.0)

            var sends = 0
            let subscription = engine.objectWillChange.sink { _ in sends += 1 }
            defer { subscription.cancel() }
            let ticks = 300
            for _ in 0..<ticks { engine.step(1.0 / 30.0) }

            // Exactly one per tick. Ambient acts run throughout — strolls, hops and the
            // return home all write offsets — so this covers the branches that used to
            // publish two and three times as well as the plain resting one.
            #expect(sends == ticks,
                    "reduceMotion=\(reduceMotion): \(sends) sends for \(ticks) ticks")
        }
    }

    @Test("The frame keeps changing on every tick, so one send is never a wasted send")
    func theSingleSendIsNeverSpurious() {
        // The other half of the argument. Publishing unconditionally at the top of the tick is
        // only correct because there is no tick whose frame is unchanged — `moodElapsed`
        // advances every time, and the resting breath moves `pose.squash` every time. If that
        // ever stopped being true, an equality guard would start paying and this fails first.
        let engine = makeEngine()
        var unchanged = 0
        var previous: CompanionFrame?
        for _ in 0..<600 {
            engine.step(1.0 / 30.0)
            if engine.frame == previous { unchanged += 1 }
            previous = engine.frame
        }
        #expect(unchanged == 0, "\(unchanged) of 600 ticks published an identical frame")
    }

    @Test("Handing the offset to a drag publishes once, and only when there is one to hand")
    func dragHandoverPublishesOnce() {
        let engine = makeEngine()
        // Walk it off centre. A stroll is the common case and the seed makes it deterministic.
        engine.step(6.0)

        var sends = 0
        let subscription = engine.objectWillChange.sink { _ in sends += 1 }
        defer { subscription.cancel() }

        let carried = engine.takeAmbientOffsetForDrag()
        // The window folds `carried` into its own origin in the same runloop turn, so the view
        // has to stop applying the offset in that same turn — one send, not zero.
        if carried != .zero {
            #expect(sends == 1, "carrying \(carried) published \(sends) times")
        }
        #expect(engine.offsetX == 0)
        #expect(engine.offsetY == 0)

        // Already home: nothing changed, so nothing is published. This is the case that runs
        // on every drag of a character that was sitting still.
        sends = 0
        _ = engine.takeAmbientOffsetForDrag()
        #expect(sends == 0)
    }

    // MARK: The idle rate

    @Test("A long rest drops the ticker to the slow rate, and work restores it")
    func sleepSlowsTheTickerAndWakingRestoresIt() {
        // The reason the 30 Hz ticker is not the whole idle story: the common idle case — no
        // typing, no cursor movement, no pomodoro — genuinely reaches the slow path. Measured
        // onset is tick 2701, i.e. 90.0 s, exactly `sleepAfter`; asserted as a window rather
        // than the exact tick so a change to the tick rate does not fail this for the wrong
        // reason.
        let engine = makeEngine()
        engine.step(89.0)
        #expect(engine.mood != .sleepy, "asleep before the 90 s threshold")
        #expect(engine.tickingSlowly == false)

        engine.step(2.0)
        #expect(engine.mood == .sleepy)
        #expect(engine.tickingSlowly, "asleep but still ticking at the awake rate")

        // And back up on real work, or the character would blink, walk and track the cursor at
        // 10 Hz for the rest of the session — which reads as the app lagging.
        engine.apply(pillState: .recording)
        engine.step(0.2)
        #expect(engine.mood == .alert)
        #expect(engine.tickingSlowly == false)
    }

    // MARK: Interactive objects and quiet mode

    @Test("Object play drives both the prop and an unlocked cat animation")
    func objectPlayIsOneSynchronizedEvent() {
        let engine = makeEngine()
        engine.unlockSource = { $0 == .rolling }
        engine.play(with: .yarn)
        engine.step(0.2)
        #expect(engine.pose.objectPlay?.object == .yarn)
        #expect((engine.pose.objectPlay?.progress ?? 0) > 0)
        #expect(engine.mood == .hunting)
        engine.stop()
    }

    @Test("The cat plays with a selected object after settling")
    func objectPlayStartsAutomatically() {
        let engine = makeEngine()
        engine.objectSource = { .ball }
        engine.step(12.2)
        #expect(engine.pose.objectPlay?.object == .ball)
        #expect(engine.mood == .delighted)
        engine.stop()
    }

    @Test("Quiet mode sleeps through local activity and suppresses object play")
    func quietModeStaysQuiet() {
        let engine = makeEngine()
        engine.objectSource = { .ball }
        engine.setQuietMode(true)
        engine.wakeIfSleeping()
        engine.step(20)
        #expect(engine.mood == .sleepy)
        #expect(engine.pose.objectPlay == nil)
        #expect(engine.tickingSlowly)
        engine.setQuietMode(false)
        #expect(engine.mood == .resting)
        engine.stop()
    }

    @Test("A reminder response is consumed exactly once")
    func reminderResponseIsConsumed() {
        let engine = makeEngine()
        engine.announce(.water, name: "")
        #expect(engine.respondToCurrentReminder(completed: true) == .water)
        #expect(engine.respondToCurrentReminder(completed: true) == nil)
        engine.stop()
    }
}

/// A deterministic `RandomNumberGenerator`, so tests of the companion's ambient behaviour
/// are reproducible rather than passing most of the time.
///
/// SplitMix64 — the algorithm Swift's own test suites use for this. Not cryptographic and not
/// meant to be; it only has to be uniform enough and identical on every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
