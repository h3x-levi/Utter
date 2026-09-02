import SwiftUI
import Combine

/// Everything the engine recomputes on every one of its 30 ticks a second, in one value.
///
/// **This exists to make the tick publish once instead of two-to-four times.** `pose`,
/// `offsetX`, `offsetY` and `moodElapsed` were four separate `@Published` properties, and
/// `@Published` sends `objectWillChange` on every assignment — so a single tick entered
/// SwiftUI's dependency graph up to four times to describe one frame. SwiftUI coalesces the
/// *view update* to one per runloop turn, but each send still costs a Combine dispatch and an
/// AttributeGraph invalidation. Measured over 24 000 release-build ticks per scenario:
///
///   awake, resting, static cursor      2.115 sends/tick  ->  1.000
///   awake, cursor moving + typing      2.001            ->  1.000
///   recording, live input level        2.000            ->  1.000
///   Reduce Motion + pet signals off    4.000            ->  1.000
///
/// Reduce Motion was the worst case because its branch assigns `offsetX = 0; offsetY = 0`
/// every tick — values that were *already* zero, publishing twice to say nothing changed.
///
/// Grouped by *rate*, not by subject: these four are the ones that move at the tick rate.
/// `mood`, `quip`, `pomodoroCountdown` and `pinnedMessage` stay separate because they change
/// on events, seconds apart at best, and folding them in would mean an event that changes
/// only the caption re-publishes the whole frame.
struct CompanionFrame: Equatable {
    /// The current frame. Renderers read this and nothing else.
    var pose: CompanionPose = .neutral

    /// Horizontal offset from the character's home spot, in points. The companion's
    /// *window* never moves during ambient behaviour — only this offset does, which keeps
    /// the character inside the panel it already owns and avoids a window-move on every one
    /// of 30 frames per second.
    var offsetX: CGFloat = 0

    /// Vertical offset from home, in points. Negative is up (SwiftUI convention).
    var offsetY: CGFloat = 0

    /// Seconds the current mood has been showing.
    ///
    /// This is what a sprite pack animates against. Deliberately a *time* rather than a
    /// frame counter: APNG frames each carry their own duration, so the pack decides which
    /// frame a given moment lands on (`CompanionAnimation.frameIndex(at:)`) and this only
    /// has to say what moment it is. One clock still drives everything — a pack starting a
    /// timer of its own is the drift this design exists to avoid.
    ///
    /// Reset when the mood changes, so each animation starts at its first frame rather than
    /// halfway through whatever the previous state was doing.
    var moodElapsed: Double = 0
}

/// The character's brain: turns dictation state plus time into a pose and a
/// position.
///
/// One driver for everything on purpose. The alternative — each body part running
/// its own `repeatForever` animation — is what makes desktop pets read as looping
/// GIFs: every part restarts on the same beat forever, and nothing can react.
/// Here a single 30 Hz tick advances one behaviour at a time, so a fidget can
/// interrupt a stroll and a recording can interrupt both.
///
/// Ambient behaviour costs nothing when there is nothing to do: the ticker only
/// runs while the companion is visible, and it stops entirely once the character
/// falls asleep (see `sleepAfter`).
@MainActor
final class CompanionBehaviour: ObservableObject {

    // MARK: Published state

    /// Everything that moves at the tick rate, published as one value.
    ///
    /// Deliberately **not** `@Published`: the tick mutates this several times as it composes
    /// a frame — zeroing an offset, easing another, writing the pose — and `@Published` would
    /// send `objectWillChange` on each of those writes. `tick()` sends once, up front, for the
    /// whole frame instead. See `CompanionFrame` for the measured before/after.
    ///
    /// A single send per tick is never a *spurious* send: `moodElapsed` advances on every
    /// tick without exception, so there is no tick that changes nothing. Pinned by
    /// `everyTickPublishesSomething`.
    private(set) var frame = CompanionFrame()

    /// The current frame. Renderers read this and nothing else.
    ///
    /// The four accessors below forward to `frame` so the read surface is unchanged by the
    /// collapse — `CompanionWindow` and `NoteCaptureBox` still read `pose`, `offsetX`,
    /// `offsetY` and `moodElapsed` exactly as before.
    var pose: CompanionPose { frame.pose }

    var offsetX: CGFloat { frame.offsetX }

    var offsetY: CGFloat { frame.offsetY }

    var moodElapsed: Double { frame.moodElapsed }

    @Published private(set) var mood: CompanionMood = .resting

    /// A brief speech bubble, or empty. Only ever set from real events.
    @Published private(set) var quip: String = ""
    @Published private(set) var currentReminder: CompanionReminder?

    // MARK: Configuration

    /// How far the character may stray from home, in points, in each direction.
    ///
    /// Deliberately small. The companion sits beside the pill at pill scale, and
    /// its whole charm is orbiting that anchor — a pet that wanders 200pt away is
    /// just a second floating window.
    ///
    /// Set by the window from its own geometry rather than chosen here, because the
    /// two are the same constraint: a borderless panel clips its content, so
    /// anything past `padding - characterSize/2` is a character sliced in half at
    /// the window edge. It also changes with the character's size, which is a user
    /// preference — see `CompanionGeometry.roamRange`.
    var roamRange: CGFloat = 16

    /// Vertical clearance for a hop, in points. Bounded by the same padding as
    /// `roamRange` — a hop that clears the top of the panel is decapitated.
    var hopHeight: CGFloat = 14

    /// Seconds of unbroken rest before the character curls up and the ticker
    /// stops. Long enough not to fall asleep during a pause in dictation.
    private let sleepAfter: TimeInterval = 90

    // MARK: Internals

    private var ticker: Timer?
    /// Seconds since the behaviour engine started. Drives every ambient
    /// oscillation, so they all share one clock and stay in phase.
    private var clock: TimeInterval = 0

    /// The awake rate. **30 Hz is load-bearing twice over, and both were measured before
    /// anyone tries to lower it as an idle-CPU saving.**
    ///
    /// 1. `GooglyEyes.settle` integrates a deliberately underdamped spring (damping ratio
    ///    ~0.51) with semi-implicit Euler, so the tick length *is* the integration step and
    ///    the visible bounce changes with it. Peak overshoot toward a target at 0.5 of full
    ///    deflection, measured: 30 Hz +11.7%, 24 Hz +10.6%, 20 Hz +9.3%, 15 Hz +6.5%.
    ///    Halving the rate halves the bounce — which is exactly the "smoothed the googly
    ///    eyes" regression the spring's own comment exists to prevent. (At 10 Hz it reads
    ///    +40% and has not settled after 2 s, which is the independent reason the sleeping
    ///    branch does no cursor read at all rather than tracking slowly.)
    /// 2. It is also the best sampler for the frame rates packs actually declare. Mean
    ///    deviation from an even frame hold across an 8-frame strip, using the real
    ///    `CompanionAnimation.frameIndex(at:)`:
    ///
    ///        tick   5 fps   8 fps  10 fps  12 fps
    ///        30 Hz   0.25    0.31    0.25    0.50
    ///        24 Hz   0.28    0.38    0.50    0.38
    ///        20 Hz   0.25    0.50    0.25    0.42
    ///        15 Hz   0.25    0.12    0.50    0.38
    ///
    ///    30 Hz is best or joint-best on three of the four rates the shipped packs use.
    ///
    /// The idle cost this would be trying to buy back is already bought a different way: a
    /// still character reaches `sleepAfter` and `retick`s to `sleepTickInterval` — measured
    /// onset at tick 2701, i.e. 90.0 s exactly. So the 30 Hz floor is bounded, not permanent.
    private let tickInterval: TimeInterval = 1.0 / 30.0

    /// The ambient act currently playing, and its span on the clock.
    ///
    /// Both ends are stored. Deriving the start from the end minus a per-case
    /// duration looks tidier but is a trap: the travelling acts' durations depend
    /// on a distance that changes when the next act is chosen, so the derived
    /// start time would drift mid-act.
    private var act: Act = .idle
    private var actStartedAt: TimeInterval = 0
    private var actEndsAt: TimeInterval = 0
    /// Where the current act is travelling to, for the acts that move.
    private var travelFrom: CGPoint = .zero
    private var travelTo: CGPoint = .zero

    private var restingSince: TimeInterval = 0
    /// The source of the character's randomness.
    ///
    /// Injectable so the ambient behaviour can be tested at all. Every act, its duration and
    /// every roam target is drawn at random, so with the global generator a test of what the
    /// character does over 20 seconds is flaky by construction — `everyTickPublishesSomething`
    /// failed roughly one run in a hundred because two consecutive ticks occasionally landed
    /// on identical values, which is a fact about the RNG rather than about the engine.
    /// Production keeps `SystemRandomNumberGenerator`.
    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()

    /// When the current mood began, so `moodElapsed` restarts each sprite animation.
    private var moodStartedAt: TimeInterval = 0

    /// Where to read the live microphone level from, 0...1. Real signal — the
    /// character's reaction while listening is never a timer.
    ///
    /// A pull, not a push. The engine already ticks at 30 Hz, so subscribing to the
    /// level would deliver ~30 updates a second that do nothing but overwrite a
    /// stored value before it is next read. Pulling reads the freshest level at the
    /// moment the pose is composed, and costs one call instead of a publisher chain.
    var levelSource: () -> Float = { 0 }

    /// The level as of this tick.
    private var inputLevel: Float = 0

    // MARK: Pet signals
    //
    // Three more pulls of exactly the same shape as `levelSource`, for the same reason:
    // the engine already ticks 30 times a second, so asking is cheaper than being told.
    // All three are **local hardware only** — a cursor position, a keystroke count and a
    // hit test. Nothing here reaches the network, the filesystem or another process.

    /// Where the pointer is, in screen coordinates.
    ///
    /// Fed from a plain read of `NSEvent.mouseLocation`, which is a free poll of the
    /// global cursor and needs no event monitor and no permission of any kind — that is
    /// why eye-follow, hunting and petting all cost one function call per frame between
    /// them rather than a tap the user has to approve.
    var cursorSource: () -> CGPoint = { .zero }

    /// Where the character is on screen, and how big, so petting can hit-test the pointer
    /// against it and the eyes know which way to look.
    ///
    /// Answered live by the window rather than stored, because the window moves: the same
    /// reasoning as `pillIsToTheRight`.
    var characterRectSource: () -> CGRect = { .zero }

    /// Scroll deltas since the last tick, drained by the engine.
    ///
    /// A push in one direction only, because scrolling is the one signal that genuinely
    /// cannot be polled: a flick delivers its distance as a burst of events and the total
    /// is the signal, so sampling at 30 Hz would read whatever fraction happened to land
    /// on the tick boundary. The window accumulates, the engine drains.
    private var pendingScroll: CGFloat = 0

    /// The pupils' own physics, so they roll rather than point. See `GooglyEyes`.
    private var googly = GooglyEyes()

    private var typing = TypingActivity()
    private var cursorTracking = CursorTracking()
    private var petting = PettingDetector()
    private var scrolling = ScrollActivity()

    /// The keystroke count at the last tick, so the delta is what gets recorded.
    private var lastKeystrokeCount: UInt64?

    /// Whether the pet layer is allowed to drive the character at all.
    ///
    /// Off makes every pet signal inert, which is what Reduce Motion and the settings
    /// toggle both need — and it is checked before the signals are even sampled, so
    /// turning it off also stops the work rather than just hiding the result.
    var petBehavioursEnabled = true

    /// Live heat, 0...1, for the tint. Published so a settings preview can show it.
    private(set) var heat: CGFloat = 0

    /// True while the character is parked at a screen edge because something is filling
    /// the screen.
    ///
    /// Suppresses the cursor-driven reactions rather than the whole pet layer: a character
    /// that has deliberately got out of the way should not then chase the pointer back
    /// across the film you are watching. Typing still counts, because kneading happens in
    /// place and costs the viewer nothing, and petting still works — reaching over to
    /// stroke it is a request for its attention.
    var isPeeking = false

    /// True while the user is physically dragging the character.
    ///
    /// Set by the window from the gesture it already runs, rather than inferred from
    /// position changes: the character also moves during a stroll, and inferring would
    /// make it dangle from an invisible hand every time it walked.
    var isBeingDragged = false

    /// Move the *window* horizontally by `dx` points (screen space, + is right) and report
    /// how far it actually went.
    ///
    /// This is the one thing the walk needs that a published offset cannot give: a stroll
    /// shifts the character inside its own panel (the window never moves — see `offsetX`),
    /// but a walk crosses the desktop, so the window itself has to travel. The engine asks,
    /// the window clamps to the screen edge and answers with the real distance, and a short
    /// answer is how the engine learns it has hit an edge and should turn around. The
    /// default is inert (`0`), so a headless engine — every test that does not wire a window
    /// — simply never walks anywhere, exactly as before.
    var walkStep: (CGFloat) -> CGFloat = { _ in 0 }
    var objectSource: () -> CompanionObject = { .none }
    var unlockSource: (CompanionUnlock) -> Bool = { _ in false }
    private var nextObjectPlayAt: TimeInterval = 12
    private var playingObject: CompanionObject?
    private var objectPlayStartedAt: TimeInterval = 0
    private var objectPlayEndsAt: TimeInterval = 0
    private var quietMode = false

    /// Hand the window the character's current ambient offset and zero it, at the start of a
    /// drag.
    ///
    /// The window folds this into its own origin, so suppressing the offset — which the drag
    /// does, see `advanceAmbientAct` — cannot make the character jump. Without it, grabbing a
    /// character mid-stroll snapped it to its panel centre before the drag had even moved.
    func takeAmbientOffsetForDrag() -> CGSize {
        let carried = CGSize(width: frame.offsetX, height: frame.offsetY)
        // The one frame mutation outside `tick()`, so it publishes for itself. Sent before
        // the write, which is `objectWillChange`'s contract — and it matters here rather
        // than at 30 Hz: the window folds `carried` into its own origin in the same runloop
        // turn, so the view has to stop applying the offset in that same turn or the
        // character visibly doubles the distance for one frame.
        guard frame.offsetX != 0 || frame.offsetY != 0 else {
            act = .idle
            return carried
        }
        objectWillChange.send()
        frame.offsetX = 0
        frame.offsetY = 0
        act = .idle
        return carried
    }

    /// How far the paper is unrolled, 0...1. Read by the renderer for the scroll overlay.
    var paperExtension: CGFloat { scrolling.extension_ }

    /// Cleared when the mood stops being transient, so `delighted`/`startled`
    /// can't stick.
    private var moodExpiresAt: TimeInterval?

    /// When the current caption should clear. Same mechanism as `moodExpiresAt`.
    private var quipExpiresAt: TimeInterval?

    /// Forces Reduce Motion on or off, instead of reading the system setting.
    ///
    /// Exists for tests: the accessibility behaviour is a real requirement, and the
    /// alternative is either changing a system-wide setting from a test or leaving the
    /// behaviour unverified.
    var reduceMotionOverride: Bool?

    private var reduceMotion: Bool {
        reduceMotionOverride ?? MotionPreference.shared.reduceMotion
    }

    /// One ambient behaviour. Each is a short act with a duration, chosen at
    /// random when the previous one ends.
    private enum Act {
        case idle
        /// Walk to a new spot nearby.
        case stroll
        /// Cross the desktop under its own steam. Unlike `stroll`, which only shifts the
        /// character inside its panel, this translates the *window* — so the character
        /// genuinely walks across the screen, turning around when it reaches an edge.
        case walk
        /// A hop, with real squash on take-off and landing.
        case hop
        /// Sit up, arch, and settle. The cat stretch.
        case stretch
        /// Turn to face the other way.
        case turn
        /// Look up at the pill it lives beside.
        case glanceAtPill
        /// Walk back to the home spot because something happened. Its own act, not
        /// a reused `.idle`: the return needs its own travel endpoints and its own
        /// duration, and `.idle` legitimately holds a *stale* `travelTo` from the
        /// stroll before it — which is what made the character stand where it was
        /// and never come back.
        case returnHome
    }

    // MARK: Lifecycle

    /// Start ticking. Safe to call repeatedly.
    func start() {
        start(interval: tickInterval)
    }

    /// How often the engine ticks while the character is asleep.
    ///
    /// Sleeping used to stop the ticker outright, which is why `sleepy` had to be a single
    /// frame: with the clock frozen, `moodElapsed` never advances and a multi-frame sleep
    /// holds one arbitrary drawing forever. But a sleeping cat that does not breathe reads as
    /// a dead cat, and the pack authors a 4-frame breath.
    ///
    /// 10 Hz is twice the 5 fps the sleep animation is drawn at, so every frame boundary
    /// lands cleanly, and it is a third of the work the awake engine does. Nothing else runs
    /// on these ticks — no ambient acts, no pet signals, no cursor read — so the cost is one
    /// timer wake and two published properties. The process is already awake at 1 Hz for the
    /// wake-watcher regardless.
    private let sleepTickInterval: TimeInterval = 1.0 / 10.0

    /// True while the ticker is running at the slow sleeping rate.
    ///
    /// Readable rather than fully private so the rate drop can be tested. It is the whole
    /// point of the sleep state — a 30 Hz ticker for a character nobody is watching is the
    /// idle cost — and `step(_:)` cannot show it, because stepping always advances by
    /// `tickInterval` regardless of what the real timer is set to. Without this the tests
    /// could only prove the character *looks* asleep, not that it stopped costing 30 Hz.
    private(set) var tickingSlowly = false

    private func start(interval: TimeInterval) {
        guard ticker == nil else { return }
        // `.common` mode, so behaviour keeps running while a menu is open or the
        // user is dragging — a pet that freezes mid-stride when you open the
        // menu bar looks broken.
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tickingSlowly = interval > tickInterval
    }

    /// Swap the ticker's rate. Used when falling asleep and when waking.
    private func retick(interval: TimeInterval) {
        ticker?.invalidate()
        ticker = nil
        start(interval: interval)
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        playingObject = nil
        frame.pose.objectPlay = nil
        // Clear any speech bubble on the way out.
        //
        // A quip expires in `tick()`, and stopping the ticker freezes the clock it is
        // measured against — so one in flight when the companion is hidden would still be
        // there the next time the character appeared, quoting a dictation turn from earlier.
        quip = ""
        quipExpiresAt = nil
    }

    // MARK: Inputs

    /// Map dictation state onto a mood. The single place the companion learns
    /// what the app is doing.
    func apply(pillState: PillState) {
        switch pillState {
        case .idle, .notice:
            break
        case .preparing, .recording, .handsFree, .capturingNote, .capturingMemory,
             .processing, .error:
            playingObject = nil
        }
        switch pillState {
        case .preparing:
            set(mood: .thinking)
        case .idle:
            // A finished turn earns a short celebration, then back to rest. Only
            // from a state that was actually doing something, so merely showing
            // the companion doesn't make it cheer.
            if mood == .thinking {
                set(mood: .delighted, for: 1.6)
            } else if mood != .sleepy {
                set(mood: .resting)
            }
        case .recording, .handsFree, .capturingNote, .capturingMemory:
            set(mood: .alert)
        case .notice:
            // A transient confirmation is not a mood: the character keeps whatever
            // it was doing rather than reacting to a message about note routing.
            break
        case .processing:
            set(mood: .thinking)
        case .error(let reason):
            set(mood: .startled, for: 2.4)
            say(reason, for: 2.4)
        }
    }

    /// Record scroll movement. Called by the window's scroll monitor.
    ///
    /// Takes a magnitude, not a direction: the character unspools paper because the page
    /// is moving, and it does not care which way. Guarding on `petBehavioursEnabled` here
    /// rather than at the call site means a disabled pet layer cannot accumulate a scroll
    /// that would then unroll the instant it is re-enabled.
    func recordScroll(delta: CGFloat) {
        guard petBehavioursEnabled else { return }
        pendingScroll += abs(delta)
        // Scrolling is user activity, so it wakes a sleeping cat. Without this the paper
        // would silently accumulate against a frozen clock, because the ticker stops
        // after 90 seconds of rest and nothing would be draining it.
        if mood == .sleepy { wake() }
    }

    /// Say something the user asked to be told, and react to it.
    ///
    /// The one public way into the speech bubble. `say` stays private so every line the
    /// character speaks comes from a real event through a named entry point — the bubble was
    /// built for dictation errors, and "only ever set from real events" is a property worth
    /// keeping as the number of callers grows.
    ///
    /// Wakes the character first, because every reminder exists for a user who has been
    /// sitting still, which is exactly when it is asleep with its ticker stopped.
    func announce(_ reminder: CompanionReminder, name: String) {
        wake()
        currentReminder = reminder
        // A stretch reminder is the character stretching *with* you — the point is to model
        // the behaviour, not to nag. The rest just get its attention.
        switch reminder {
        case .stretch:
            begin(.stretch)
        case .water, .pomodoro, .message:
            set(mood: .delighted, for: 1.4)
        }
        say(reminder.line(name: name), for: 4.0)
        SoundPlayer.playTrill()
    }

    /// The pomodoro countdown to show beside the character, or nil when it is not running.
    ///
    /// A text countdown in the existing bubble rather than the floating pixel timer this was
    /// modelled on. That is a deliberate reduction, not an oversight: the companion's panel
    /// is sized to exactly the character's reach envelope, so a second floating element
    /// needs either a larger panel — which re-introduces a transparent-margin bug the
    /// geometry comments record — or a whole second window to manage, position, clamp across
    /// displays and tear down. `mm:ss` in the bubble delivers the actual information for one
    /// line of code. The pixel timer is a real upgrade, and it is a window problem, not a
    /// timer problem.
    @Published private(set) var pomodoroCountdown: String?

    /// Set from the window's one-second heartbeat, which is also where the reminder clocks
    /// live. Seconds resolution, so a per-second string is the finest that is honest.
    func setPomodoroCountdown(_ remaining: TimeInterval?) {
        guard let remaining, remaining > 0 else {
            if pomodoroCountdown != nil { pomodoroCountdown = nil }
            return
        }
        let whole = Int(remaining.rounded())
        let text = String(format: "%d:%02d", whole / 60, whole % 60)
        if pomodoroCountdown != text { pomodoroCountdown = text }
    }

    /// A pinned note that stays above the character's head until the user clears it.
    ///
    /// Separate from `announce` because it is not an event: it has no expiry, and it must
    /// survive the character falling asleep and waking again. Empty clears it.
    var pinnedMessage: String = "" {
        didSet {
            guard pinnedMessage != oldValue else { return }
            objectWillChange.send()
        }
    }

    /// Wake the character if outside activity happened while it was asleep.
    ///
    /// Needed because sleeping *stops the ticker*, and a stopped ticker polls nothing —
    /// so the pet signals cannot notice the user has come back. The window watches at a
    /// low rate while asleep and calls this; everything else the engine can see for
    /// itself.
    func wakeIfSleeping() {
        guard mood == .sleepy, !quietMode else { return }
        wake()
    }

    /// Nudge the character awake — called when the user interacts with it.
    func poke() {
        wake()
        set(mood: .delighted, for: 1.2)
        // A poke interrupts whatever it was doing with a hop, which is the
        // clearest acknowledgement at this size.
        begin(.hop)
        // And it answers. Rate-limited inside `SoundPlayer`, so tapping repeatedly does not
        // stack overlapping meows.
        SoundPlayer.playMeow()
    }

    /// Both a click and autonomous idle play route through here so the prop and cat stay in sync.
    func play(with object: CompanionObject) {
        guard petBehavioursEnabled, object != .none, !quietMode else { return }
        wake()
        playingObject = object
        objectPlayStartedAt = clock
        objectPlayEndsAt = clock + object.playDuration
        nextObjectPlayAt = clock + .random(in: 45...75, using: &rng)
        act = .idle
        frame.offsetX = 0
        frame.offsetY = 0
        switch object {
        case .none:
            break
        case .ball:
            set(mood: .delighted, for: object.playDuration)
        case .box:
            set(mood: .hunting, for: object.playDuration)
        case .yarn:
            set(mood: .hunting, for: object.playDuration)
        case .cushion:
            set(mood: unlockSource(.loaf) ? .loaf : .purring, for: object.playDuration)
        }
    }

    func feed() {
        guard !quietMode else { return }
        wake()
        set(mood: .delighted, for: 1.8)
        SoundPlayer.playMeow()
    }

    func brush() {
        guard !quietMode else { return }
        wake()
        set(mood: unlockSource(.grooming) ? .grooming : .purring, for: 2.6)
        SoundPlayer.playPurr()
    }

    func doubleClick() {
        guard !quietMode else { return }
        wake()
        set(mood: unlockSource(.rolling) ? .rolling : .delighted, for: 2.2)
    }

    func celebrateGoal(_ line: String) {
        wake()
        set(mood: .delighted, for: 2.2)
        say(line, for: 4)
        SoundPlayer.playTrill()
    }

    func respondToCurrentReminder(completed: Bool) -> CompanionReminder? {
        guard let reminder = currentReminder else { return nil }
        currentReminder = nil
        quip = ""
        quipExpiresAt = nil
        set(mood: completed ? .delighted : .resting, for: completed ? 1.5 : nil)
        return reminder
    }

    func setQuietMode(_ enabled: Bool) {
        guard quietMode != enabled || (enabled && mood != .sleepy) else { return }
        quietMode = enabled
        if enabled {
            playingObject = nil
            currentReminder = nil
            quip = ""
            quipExpiresAt = nil
            mood = .sleepy
            moodExpiresAt = nil
            moodStartedAt = clock
            frame.offsetX = 0
            frame.offsetY = 0
            frame.pose = sleepingPose()
            frame.moodElapsed = 0
            if !tickingSlowly { retick(interval: sleepTickInterval) }
        } else if mood == .sleepy {
            wake()
        }
    }

    private func set(mood newMood: CompanionMood, for duration: TimeInterval? = nil) {
        // Any real event wakes the character, so it can't sleep through a
        // recording.
        if newMood != .resting, newMood != .sleepy { wake() }

        if mood != newMood {
            mood = newMood
            // Restart the sprite animation with the mood, so a pack's `delighted`
            // plays from its first frame rather than from wherever `thinking` had got
            // to.
            moodStartedAt = clock
            frame.moodElapsed = 0
            if newMood == .resting { restingSince = clock }
        }
        moodExpiresAt = duration.map { clock + $0 }
    }

    private func say(_ text: String, for duration: TimeInterval) {
        quip = text
        // Retried every tick, exactly like `moodExpiresAt` — not checked once after a
        // `Task.sleep`.
        //
        // The sleep measured *wall* time while the deadline was in `clock`, which only
        // advances 1/30s per `tick()`. Any main-thread hitch that coalesced a single timer
        // fire — a sprite pack decoding, a transcription landing — left `clock` short of the
        // deadline at the one moment it was tested, and the check never came round again. The
        // caption then stuck for the rest of the session: a resting or strolling character
        // with "Couldn't start the microphone" above it. `stop()` while asleep has the same
        // effect by design, so the clock cannot be trusted to reach any particular value.
        quipExpiresAt = clock + duration
    }

    /// Bring the character back to the responsive rate, and clear the sleepy pose.
    private func wake() {
        if mood == .sleepy {
            mood = .resting
            // Waking is a mood change like any other, so the resting loop has to start at its
            // first frame. `set(mood:)` does this for every other transition; assigning here
            // and leaving `moodStartedAt` behind would resume the animation at whatever point
            // in the cycle the character happened to fall asleep at.
            moodStartedAt = clock
            frame.moodElapsed = 0
            googly.reset()
            // Back to 30 Hz. Sleeping drops the ticker to 10 Hz so the sleep animation can
            // breathe; without this the character would walk, blink and track the cursor at
            // 10 Hz for the rest of the session, which reads as the app lagging.
            if tickingSlowly { retick(interval: tickInterval) }
        }
        restingSince = clock
        start()
    }

    // MARK: The tick

    /// Advance simulated time by `seconds`, in tick-sized steps.
    ///
    /// The same code path the timer drives, decoupled from wall-clock time. Behaviour
    /// here plays out over tens of seconds — a 90-second sleep timer, ambient acts
    /// lasting several seconds each — and a test that actually waited for those is a
    /// test nobody runs. Stepping also removes the flakiness of asserting on a
    /// real-time timer under load.
    ///
    /// Ticks are *not* coalesced into one large step: the behaviour depends on being
    /// sampled at ~30 Hz (blink windows are 90 ms), so a single jump would skip states
    /// the real engine passes through.
    func step(_ seconds: TimeInterval) {
        var remaining = seconds
        while remaining > 0 {
            tick()
            remaining -= tickInterval
        }
    }

    private func tick() {
        // One send for the whole frame, before any of it is written.
        //
        // `frame` is a plain stored property rather than `@Published` precisely so that the
        // dozen writes below — an offset zeroed here, eased there, a pose composed at the end
        // — cost nothing individually. This is the single point at which a tick enters
        // SwiftUI's dependency graph, and it is up front because that is `objectWillChange`'s
        // contract: observers are told before the value moves, and they read the new value on
        // the next update pass.
        //
        // Unconditional, and that is not laziness: `frame.moodElapsed` advances on every tick
        // without exception, so there is no tick whose frame is unchanged. Measured 0 of 24 000
        // ticks unchanged in every scenario (see `everyTickPublishesSomething`), so an equality
        // guard here would be a comparison that never once returned true.
        objectWillChange.send()

        clock += tickInterval
        // Reset the per-tick window-travel accumulator before the act runs, so `measureTravel()`
        // below sees only what this tick moved.
        windowTravelThisTick = 0
        // Read the live level once per frame, so the `alert` bounce is driven by the
        // same signal the pill's meter draws.
        inputLevel = levelSource()

        if let expiry = quipExpiresAt, clock >= expiry {
            quipExpiresAt = nil
            quip = ""
            currentReminder = nil
        }

        if let expiry = moodExpiresAt, clock >= expiry {
            moodExpiresAt = nil
            mood = .resting
            // `moodElapsed`'s contract is that each animation starts at its first frame, and
            // only `set(mood:)` upholds it — assigning `mood` directly leaves `moodStartedAt`
            // at whenever the *previous* mood began, so the resting loop resumes mid-cycle.
            moodStartedAt = clock
            frame.moodElapsed = 0
            restingSince = clock
        }

        if playingObject != nil, clock >= objectPlayEndsAt {
            playingObject = nil
        }

        // Fall asleep after a long rest, and drop to a fraction of the CPU for a character
        // nobody is watching. A real event calls `wake()`, which restores the full rate.
        if mood == .resting, clock - restingSince > sleepAfter {
            mood = .sleepy
            // Reset the animation clock as the mood changes, so the sleep animation starts on
            // its first frame. This mattered even more when falling asleep *stopped* the
            // ticker: measured, `step(95)` left `moodElapsed == 95.033` against a 4-frame
            // 5fps cycle, so `frameIndex(at:)` picked a mid-breath drawing and the frozen
            // clock held it there forever. The ticker only slows now, so the animation runs —
            // but it still has to begin at the frame drawn as "settling".
            moodStartedAt = clock
            frame.moodElapsed = 0
            frame.offsetX = 0
            frame.offsetY = 0
            frame.pose = sleepingPose()
            // Slowed, not stopped. Stopping froze `moodElapsed`, which is what forced the
            // sleep state to be a single drawing; at 10 Hz the pack's breath animates and the
            // engine still does a third of its awake work.
            retick(interval: sleepTickInterval)
            return
        }

        // While asleep, advance only the animation clock. No ambient acts, no cursor read,
        // no keystroke poll — a sleeping cat reacts to nothing until something wakes it, and
        // this is what keeps the slow ticker nearly free.
        if mood == .sleepy {
            frame.pose = sleepingPose()
            frame.moodElapsed = clock - moodStartedAt
            return
        }

        if quietMode {
            frame.pose = sleepingPose()
            frame.moodElapsed = clock - moodStartedAt
            return
        }

        if petBehavioursEnabled, mood == .resting, !isBeingDragged, !isPeeking,
           clock >= nextObjectPlayAt {
            let object = objectSource()
            if object == .none {
                nextObjectPlayAt = clock + 15
            } else {
                play(with: object)
            }
        }

        samplePetSignals()
        advanceAmbientAct()
        frame.pose = composePose()
        // Kept raw, at the tick rate.
        //
        // This was floored to a 1/24 s grid to stop a value that changes every tick
        // from invalidating the SwiftUI body 30x/second. That saved nothing: it shares
        // `CompanionFrame` with `pose`, `offsetX` and `offsetY`, and the pose alone
        // changes on *every* tick (the resting breath is a continuous sine), so the
        // frame publishes 30x/second regardless and the container view could never
        // observe fewer updates than that. Measured over 6 runs of 300 ticks: one of
        // the four changed on 299/299 of them, with and without the grid; re-measured
        // after the collapse at 24 000 ticks per scenario, 0 were unchanged.
        //
        // What the grid did do was move frame boundaries. It is 24 Hz, so it divides
        // evenly only for frame rates that divide 24 — and packs declare 5 and 10 fps
        // as well as 8 and 12. Measured frame holds for an 8-frame state, in ticks:
        //
        //   10 fps  grid [4,3,3,3,2,4,3,2]   raw [3,3,4,2,3,3,3,3]   ideal 3
        //    5 fps  grid [7,6,6,6,5,7,6,5]   raw [6,6,7,5,6,6,6,6]   ideal 6
        //    8 fps  grid [4,4,4,3,4,4,4,3]   raw identical
        //   12 fps  grid [3,2,3,2,3,2,3,2]   raw identical
        //
        // So the grid doubled the mean deviation from even timing at 5 and 10 fps
        // (0.5 vs 0.25 ticks) and changed nothing at 8 and 12. Sampling at 30 Hz is
        // the floor on accuracy either way; adding a second, coarser grid on top of
        // it only ever costs.
        frame.moodElapsed = clock - moodStartedAt
    }

    // MARK: Ambient acts
    //
    // The character picks a new act whenever the last one ends. Weighted so
    // stillness dominates: constant motion beside a text field is a distraction,
    // and the occasional hop only reads as playful because it is rare.

    private func advanceAmbientAct() {
        // A drag owns the character's position outright: the window tracks the cursor 1:1,
        // so any ambient offset or travel here fights the gesture. It fights it twice, in
        // fact — the offset is applied to the character view, and animating it under a live
        // `DragGesture` shifts the gesture's own coordinate space, which is the jitter the
        // user reported. Hold everything still until the drag ends.
        guard !isBeingDragged else {
            frame.offsetX = 0
            frame.offsetY = 0
            act = .idle
            return
        }

        // Reduce Motion: no travel, no hops. The character still
        // blinks and still reacts to state, because those carry information —
        // it simply stops moving around the screen.
        guard !reduceMotion else {
            act = .idle
            frame.offsetX = 0
            frame.offsetY = 0
            return
        }

        guard mood.allowsWandering else {
            // Something is happening, so whatever the character was doing is
            // abandoned and it walks back to its post beside the pill.
            //
            // The trip is started whenever one is needed and not already running —
            // testing `act != .idle` was the bug: `.idle` is by far the most common
            // act, so a character that finished a stroll and settled was already
            // `.idle` when recording began, no return was ever scheduled, and it
            // stayed where it stopped. Measured ~10pt off post.
            if act != .returnHome, frame.offsetX != 0 || frame.offsetY != 0 {
                act = .returnHome
                actStartedAt = clock
                actEndsAt = clock + 0.35
                travelFrom = CGPoint(x: frame.offsetX, y: frame.offsetY)
                travelTo = .zero
                // Walk back facing the way it is going.
                if travelFrom.x != 0 { lastFacing = travelFrom.x > 0 ? -1 : 1 }
            }

            if act == .returnHome {
                let t = actProgress()
                frame.offsetX = lerp(travelFrom.x, travelTo.x, easeInOut(t))
                frame.offsetY = lerp(travelFrom.y, travelTo.y, easeInOut(t))
                if t >= 1 {
                    frame.offsetX = 0
                    frame.offsetY = 0
                    act = .idle
                    actStartedAt = clock
                    // No ambient act may start while off duty, so the window is
                    // irrelevant — but leave it consistent rather than stale.
                    actEndsAt = clock
                    travelFrom = .zero
                    travelTo = .zero
                }
            }
            return
        }

        if clock >= actEndsAt {
            begin(chooseAct())
        }

        // Drive whatever is playing.
        let progress = actProgress()
        switch act {
        // `.returnHome` is driven by the off-duty branch above and can never be
        // running here, since this point is only reached while wandering is allowed.
        case .idle, .stretch, .glanceAtPill, .returnHome:
            break
        case .turn:
            // Flip once, at the midpoint, where the body is edge-on and the
            // change of direction is invisible.
            if !turnFlipped, progress >= 0.5 {
                lastFacing = -lastFacing
                turnFlipped = true
            }
        case .stroll:
            frame.offsetX = lerp(travelFrom.x, travelTo.x, easeInOut(progress))
        case .walk:
            // Ask the window to move the whole panel this tick, and see how far it could.
            let requested = Self.walkSpeed * CGFloat(tickInterval) * walkDirection
            let actual = walkStep(requested)
            windowTravelThisTick += actual
            // Hit a screen edge: turn around and carry on the other way. If it still cannot
            // move after turning — boxed into a corner, or the window is ordered out during
            // the note-card handover — end the walk rather than flip its facing every tick
            // against the wall.
            if abs(actual) + 0.01 < abs(requested) {
                walkDirection = -walkDirection
                lastFacing = walkDirection
                walkStuckTicks += 1
                if walkStuckTicks >= 2 { actEndsAt = clock }
            } else {
                walkStuckTicks = 0
            }
        case .hop:
            frame.offsetX = lerp(travelFrom.x, travelTo.x, progress)
            // A real arc, not a sine: fast up, slower down reads as gravity.
            //
            // Measured from the ground (0), not from `travelFrom.y`. Arcing from
            // wherever the character happened to be *stacked* hops: a hop beginning
            // while still airborne added its full height to the previous offset, and
            // measured 26.2pt of travel against a 14pt hop — nearly double, which is
            // enough to clip the character against the top of its panel. There is only
            // one floor, so a hop always starts from it.
            frame.offsetY = -hopArc(progress) * hopHeight
        }
    }

    private func chooseAct() -> Act {
        // Weighted draw. Idle carries most of the weight so the character is
        // mostly still, which is what makes the motion land when it happens.
        var pool: [(Act, Int)] = [
            (.idle, 32),
            (.stroll, 12),
            (.hop, 8),
            (.stretch, 7),
            (.turn, 6),
            (.glanceAtPill, 8),
        ]
        // The occasional longer journey across the desktop — but not while parked at a
        // screen edge to stay out of something full-screen (`isPeeking`), where a walk
        // would march the character straight back over what it just got out of the way of.
        if !isPeeking { pool.append((.walk, 11)) }

        let total = pool.reduce(0) { $0 + $1.1 }
        var draw = Int.random(in: 0..<total, using: &rng)
        for (candidate, weight) in pool {
            draw -= weight
            if draw < 0 { return candidate }
        }
        return .idle
    }

    private func begin(_ next: Act) {
        act = next
        actStartedAt = clock
        travelFrom = CGPoint(x: frame.offsetX, y: frame.offsetY)

        switch next {
        case .idle:
            travelTo = travelFrom
            actEndsAt = clock + .random(in: 1.4...4.2, using: &rng)
        case .stroll:
            travelTo = CGPoint(x: newRoamTarget(minStep: 6), y: 0)
            // Pace, not teleport: distance sets duration so the walk speed is
            // constant regardless of how far it decided to go.
            let distance = abs(travelTo.x - travelFrom.x)
            actEndsAt = clock + max(0.5, TimeInterval(distance / 22))
            // Remember the heading, so the character keeps facing the way it
            // walked instead of snapping back on arrival.
            if travelTo.x != travelFrom.x { lastFacing = travelTo.x > travelFrom.x ? 1 : -1 }
        case .walk:
            // The walk moves the *window*, not the offset, so bring the in-panel offset
            // home first — otherwise the character would travel while also hanging a few
            // points off its own window for the length of the walk. A stroll biases back
            // toward home, so this is usually already ~0.
            frame.offsetX = 0
            frame.offsetY = 0
            travelFrom = .zero
            travelTo = .zero
            walkDirection = Bool.random(using: &rng) ? 1 : -1
            lastFacing = walkDirection
            walkStuckTicks = 0
            actEndsAt = clock + .random(in: 2.2...4.6, using: &rng)
        case .hop:
            travelTo = CGPoint(x: clampRoam(travelFrom.x + .random(in: -10...10, using: &rng)), y: 0)
            actEndsAt = clock + 0.52
        case .stretch:
            travelTo = travelFrom
            actEndsAt = clock + 1.15
        case .turn:
            travelTo = travelFrom
            actEndsAt = clock + 0.4
            turnFlipped = false
        case .glanceAtPill:
            travelTo = travelFrom
            actEndsAt = clock + .random(in: 0.9...1.8, using: &rng)
        case .returnHome:
            // Only ever begun by the off-duty path above, which sets its own
            // endpoints and duration.
            travelTo = .zero
            actEndsAt = clock + 0.35
        }
    }

    /// A new spot at least `minStep` away, inside the roam range, biased back
    /// toward home so the character doesn't loiter at one edge.
    private func newRoamTarget(minStep: CGFloat) -> CGFloat {
        let towardHome: CGFloat = frame.offsetX > 0 ? -1 : 1
        // Two thirds of the time, head back toward the anchor.
        let direction: CGFloat = Bool.random(using: &rng) || abs(frame.offsetX) > roamRange * 0.6
            ? towardHome
            : -towardHome
        let step = CGFloat.random(in: minStep...(minStep + 16), using: &rng)
        return clampRoam(frame.offsetX + direction * step)
    }

    private func clampRoam(_ x: CGFloat) -> CGFloat {
        min(max(x, -roamRange), roamRange)
    }

    /// 0...1 through the current act.
    private func actProgress() -> CGFloat {
        let total = max(0.0001, actEndsAt - actStartedAt)
        return CGFloat(min(1, max(0, (clock - actStartedAt) / total)))
    }

    // MARK: Pet signals

    /// Sample the local input signals and let them pick a mood, once per tick.
    ///
    /// Order matters: sample first, resolve second, so every rule sees the same instant.
    private func samplePetSignals() {
        guard petBehavioursEnabled else {
            heat = 0
            // Drop anything that accumulated before the toggle flipped, so re-enabling
            // does not replay a burst of stale scrolling.
            pendingScroll = 0
            if mood.isPetMood { set(mood: .resting) }
            return
        }

        // Typing, as a count delta. `KeystrokeTicker` holds a number and a time and has
        // nowhere to put a key code, so this cannot become a keylogger by accident.
        let strokes = KeystrokeTicker.snapshot
        if let previous = lastKeystrokeCount {
            // Unsigned wrapping subtraction is correct across the counter's rollover.
            let delta = strokes.count &- previous
            // Capped at 8 per tick — 240 keys/second, well past physically possible. The
            // cap exists so a counter that somehow jumped cannot spin this loop.
            for _ in 0..<min(delta, 8) { typing.record(at: clock) }
        }
        lastKeystrokeCount = strokes.count
        typing.update(at: clock)
        heat = typing.heat(at: clock)

        // Cursor: one free read, no monitor, no permission.
        let pointer = cursorSource()
        cursorTracking.sample(pointer, at: clock)
        petting.sample(pointer, inside: characterRectSource().contains(pointer), at: clock)

        // Scroll: drain what the window pushed since the last tick.
        if pendingScroll > 0 {
            scrolling.record(delta: pendingScroll, at: clock)
            pendingScroll = 0
        }
        scrolling.update(at: clock, tick: tickInterval)

        resolvePetMood()
    }

    /// Choose which pet mood, if any, the character should be in.
    ///
    /// **Precedence, highest first:** being held, overheating, kneading, purring, hunting.
    /// It is ordered by how directly the user caused it — a cat you are physically holding
    /// should not decide to chase the cursor, and someone typing hard enough to overheat is
    /// still typing, so overheat has to outrank kneading or the two would alternate.
    ///
    /// Utter's own work always wins over all of it. A pet mood may only take hold from
    /// `resting` or from another pet mood, so a recording, a transcription or a failure is
    /// never interrupted by the cat noticing the mouse — and `moodExpiresAt` being set
    /// means a timed reaction (the celebration, the startle) is still playing out.
    private func resolvePetMood() {
        guard moodExpiresAt == nil else { return }
        guard mood == .resting || mood.isPetMood else { return }

        let desired: CompanionMood? =
            if isBeingDragged { .held }
            else if typing.isOverheating { .overheating }
            else if typing.isTyping(at: clock) { .kneading }
            else if petting.isPurring(at: clock) { .purring }
            else if cursorTracking.isHunting(at: clock) && !isPeeking { .hunting }
            else { nil }

        if let desired {
            if mood != desired {
                set(mood: desired)
                if desired == .purring { SoundPlayer.playPurr() }
            }
        } else if mood.isPetMood {
            // Nothing is happening any more. Back to resting, and `restingSince` restarts
            // so the sleep timer measures idleness from the end of the interaction rather
            // than from before it.
            set(mood: .resting)
        }
    }

    /// The eye direction for this frame.
    ///
    /// Nil-safe by construction: with no window wired up, `characterRectSource` returns
    /// `.zero` and the cursor lands outside it, so the aim is computed from a centre of
    /// (0,0) and clamps — the eyes point somewhere consistent rather than jittering. A
    /// sleeping or held cat does not track: its eyes are shut, and a held one is looking
    /// at you regardless.
    private func eyeAimNow() -> CGVector {
        // Where the pupil *should* be heading.
        var target = CGVector(dx: 0, dy: 0)
        if petBehavioursEnabled, mood != .sleepy, mood != .held {
            let rect = characterRectSource()
            if rect.width > 0 {
                target = CursorTracking.aim(from: CGPoint(x: rect.midX, y: rect.midY),
                                            to: cursorSource())
            }
        }
        // And where it actually is, having rolled there. The spring runs even when the target
        // is centre, so closing the eyes or picking the character up lets the pupils drift
        // back rather than snapping — which is the same motion, and the reason this is one
        // code path instead of two.
        googly.settle(toward: target, tick: tickInterval)
        return googly.offset
    }

    // MARK: Pose composition

    private func composePose() -> CompanionPose {
        if mood == .sleepy { return sleepingPose() }

        var pose = CompanionPose()
        pose.facing = facingForCurrentAct()

        switch mood {
        case .resting, .sleepy:
            // A slow breath, so a still character is never a frozen one.
            pose.squash = 1 + 0.022 * CGFloat(sin(clock * 1.7))

        case .alert:
            // Bounce on the real microphone level. `inputLevel` is already
            // smoothed by the recorder, so it is used directly rather than
            // filtered again.
            let level = CGFloat(max(0, min(1, inputLevel)))
            pose.squash = 1 + 0.14 * level
            pose.lean = -3 * level

        case .thinking:
            // A slight rock, faster than the resting breath: visibly working.
            pose.lean = 5 * CGFloat(sin(clock * 3.1))
            pose.squash = 1 + 0.015 * CGFloat(sin(clock * 3.1))

        case .delighted:
            // Bouncing on the spot.
            pose.squash = 1 + 0.10 * abs(CGFloat(sin(clock * 7.5)))

        case .startled:
            // A fast shiver, decaying — a constant-amplitude shake reads as a
            // rendering glitch rather than as a reaction.
            let remaining = moodExpiresAt.map { max(0, $0 - clock) } ?? 0
            let decay = CGFloat(min(1, remaining / 2.4))
            pose.lean = 7 * decay * CGFloat(sin(clock * 22))

        case .kneading:
            // Two paws alternating at roughly the rate of the actual typing, so the
            // kneading speeds up when you do. Clamped to 3-9 Hz: below 3 it reads as
            // stretching rather than kneading, and above 9 the frames blur into a vibration.
            let rate = min(9.0, max(3.0, typing.rate(at: clock) * 1.2))
            pose.squash = 1 + 0.05 * abs(CGFloat(sin(clock * rate)))
            pose.lean = 2 * CGFloat(sin(clock * rate * 0.5))

        case .overheating:
            // A flustered wobble, faster than thinking and shallower than startled — this
            // one can run for a whole paragraph, so it has to stay watchable.
            pose.lean = 4 * CGFloat(sin(clock * 13))
            pose.squash = 1 + 0.04 * abs(CGFloat(sin(clock * 13)))

        case .purring:
            // The purr made visible: a slow swell at the sound's own 26 Hz would be a
            // blur at 30 fps, so the body breathes at 2.6 Hz — a tenth of the rate,
            // which reads as the same rhythm without aliasing against the frame rate.
            pose.squash = 1 + 0.03 * CGFloat(sin(clock * 2.6 * .pi))

        case .hunting:
            // Crouched: squashed down and leaning toward the cursor, which is the whole
            // read of a cat about to pounce.
            pose.squash = 0.94
            pose.lean = -5 * pose.facing

        case .held:
            // Picked up: stretched a little, and held STILL. A swing here rotated the
            // sprite every frame, which reads as jitter while the user is trying to place
            // the character precisely — and dragging is exactly when precision matters. A
            // steady, slightly-stretched pose says "lifted" without fighting the cursor.
            //
            // Capped under `CompanionGeometry.maxPoseScale` (1.16) on purpose: that constant
            // is not decoration — the decoded bitmap size and the menu-bar clearance are both
            // derived from it, so a stretch past it would render a soft upscaled frame and
            // could clip over the menu bar.
            pose.squash = 1.1
            pose.lean = 0
        case .grooming:
            pose.lean = -2 * CGFloat(sin(clock * 4))
        case .rolling:
            pose.squash = 1 + 0.04 * abs(CGFloat(sin(clock * 8)))
        case .loaf:
            pose.squash = 1 + 0.012 * CGFloat(sin(clock * 1.4))
        }

        // Where the eyes look. Layered over every mood rather than set inside them,
        // because looking at the cursor is not a mood — a kneading cat and a hunting cat
        // both watch the pointer.
        pose.eyeAim = eyeAimNow()
        pose.heat = heat
        if let playingObject {
            let duration = max(playingObject.playDuration, tickInterval)
            pose.objectPlay = CompanionObjectPlay(
                object: playingObject,
                progress: CGFloat((clock - objectPlayStartedAt) / duration)
            )
        }

        // Ambient acts layer on top of the mood, never replace it.
        applyActPose(to: &pose)

        measureTravel()

        // Tell the renderer which body loop to draw, from **measured travel** rather than from
        // which act is running. See `CompanionPose.travelSpeed` for why: keying this off the act
        // name was wrong in one direction as `act == .walk` (a stroll slid a seated cat) and wrong
        // in the other as `act == .walk || act == .stroll` (a stroll ran on the spot inside its own
        // panel). A speed is right either way.
        //
        // `.hop` is excluded explicitly: it translates, but the character is airborne and a stride
        // mid-flight is worse than folded legs. Its arc carries the motion.
        pose.travelSpeed = act == .hop ? 0 : travelSpeed
        // 6 pt/s is about a seventh of a walk and well under a stroll's peak. Below it the
        // character is fidgeting, not going anywhere, and cycling the legs for that reads as a
        // treadmill.
        pose.gait = abs(pose.travelSpeed) >= 6 ? .walking : .idle

        if reduceMotion {
            // Hold still: keep expression, drop oscillation. Reduce Motion asks
            // for less movement, not less information.
            pose.squash = 1
            pose.lean = 0
        }
        return pose
    }

    private func applyActPose(to pose: inout CompanionPose) {
        guard mood.allowsWandering, !reduceMotion else { return }
        let progress = actProgress()

        switch act {
        // `.returnHome` only runs while off duty, and this method returns early in
        // that case — the mood's own pose is what should show while it walks back.
        case .idle, .returnHome:
            break

        case .stroll:
            // Lean into the walk, and bob on each step. Two steps per second.
            pose.lean = 4 * pose.facing
            pose.squash = 1 + 0.04 * abs(CGFloat(sin(clock * 8)))

        case .walk:
            // A brisker version of the stroll's bob, leaning into the direction of travel.
            // The window is doing the travelling, so this only supplies the gait — the
            // vertical step and the forward lean that keep it from sliding like a decal.
            pose.lean = 5 * walkDirection
            pose.squash = 1 + 0.05 * abs(CGFloat(sin(clock * 9)))

        case .hop:
            // Squash on take-off and landing, stretch at the apex. This is the
            // whole reason `squash` conserves volume.
            if progress < 0.14 {
                pose.squash = 0.86
            } else if progress > 0.86 {
                pose.squash = 0.88
            } else {
                pose.squash = 1.10
            }

        case .stretch:
            // Arch up, hold, settle.
            let arch = sin(Double(progress) * .pi)
            pose.squash = 1 + 0.16 * CGFloat(arch)
            pose.lean = -8 * CGFloat(arch) * pose.facing

        case .turn:
            // Mid-turn the character is edge-on, which a horizontal squeeze
            // fakes convincingly at this size.
            let edge = sin(Double(progress) * .pi)
            pose.squash = 1 + 0.10 * CGFloat(edge)

        case .glanceAtPill:
            // The pill is the reason this thing exists, so looking at it is the
            // most characterful idle available. Faces the anchor and looks up.
            pose.facing = pillIsToTheRight() ? 1 : -1
            pose.lean = -6 * pose.facing
        }
    }

    private func sleepingPose() -> CompanionPose {
        var pose = CompanionPose()
        // A slow sleeping breath. Kept even under Reduce Motion at very low
        // amplitude, because a sleeping character with no breath reads as dead —
        // it is 1.5% over four seconds, well under any motion threshold.
        pose.squash = 1 + 0.015 * CGFloat(sin(clock * 0.8))
        pose.lean = 0
        return pose
    }

    /// Which way the character faces, given what it is doing.
    ///
    /// Pure: it reads state and returns a value. The `.turn` flip happens in
    /// `advanceAmbientAct`, not here — pose composition runs every frame and must
    /// not have side effects, or the direction would depend on how many times the
    /// pose happened to be rebuilt.
    private func facingForCurrentAct() -> CGFloat {
        switch act {
        case .stroll, .hop:
            // Face the direction of travel.
            if travelTo.x != travelFrom.x { return travelTo.x > travelFrom.x ? 1 : -1 }
            return lastFacing
        case .walk:
            // The walk carries its own heading, and flips it at each edge.
            return walkDirection
        default:
            return lastFacing
        }
    }

    /// The way the character is facing between travelling acts. Flipped by
    /// `.turn`, and by the direction of each new stroll.
    private var lastFacing: CGFloat = 1
    /// Whether the current `.turn` has already flipped, so it flips once.
    private var turnFlipped = false

    /// Which way a `.walk` is currently heading, +1 right, and how many ticks it has been
    /// unable to move (so a walk boxed into a corner ends instead of shivering there).
    private var walkDirection: CGFloat = 1
    private var walkStuckTicks = 0

    /// The character's ground position last tick, for measuring how fast it is really moving.
    ///
    /// Window movement and in-panel offset are summed, because the two acts that translate the
    /// character use one each and the renderer cannot tell them apart — nor should it.
    private var lastGroundX: CGFloat?
    /// Smoothed travel speed in points per second, signed.
    ///
    /// Smoothed because a per-tick difference at 30 Hz is noisy enough to flicker the gait on and
    /// off at the threshold, and a walk cycle that starts and stops every few frames is worse than
    /// either state. One-pole, time-constant about 0.15s: fast enough to start the legs on the
    /// first step, slow enough not to chatter.
    private var travelSpeed: CGFloat = 0
    /// Window travel applied this tick by `walkStep`, which the engine cannot otherwise see.
    private var windowTravelThisTick: CGFloat = 0

    /// Update `travelSpeed` from how far the character actually moved this tick.
    ///
    /// The character's ground position is the window's travel plus its in-panel `offsetX`, because
    /// `.walk` moves the first and `.stroll` the second. Summing them is what makes the gait
    /// correct for both without the renderer needing to know which act is running.
    private func measureTravel() {
        // `offsetX` is absolute within the panel; window travel is a delta. Integrating the delta
        // into a running total gives one comparable position.
        groundX += windowTravelThisTick
        let here = groundX + frame.offsetX
        defer { lastGroundX = here }
        guard let previous = lastGroundX else { return }
        let instant = (here - previous) / CGFloat(tickInterval)
        // One-pole smoothing, time constant ~0.15s at a 30 Hz tick. A raw per-tick difference
        // crosses the gait threshold several times a second on a stroll's easing curve, and a
        // walk cycle that starts and stops every few frames is worse than either state.
        let alpha = CGFloat(tickInterval) / (0.15 + CGFloat(tickInterval))
        travelSpeed += (instant - travelSpeed) * alpha
    }

    /// Integrated window travel, so the character has one continuous ground position.
    private var groundX: CGFloat = 0

    /// Walk pace, in points per second. A calm amble — faster than the in-place stroll's
    /// implied pace, slow enough that the character crossing the desktop reads as a decision
    /// rather than as the window being flung. Over a 2.2-4.6s walk it covers roughly 90-190pt.
    /// Points per second the window travels during a `.walk`.
    ///
    /// `static` and non-private because the window's motion note at `CompanionWindow` quotes it.
    /// It was originally exposed so the code-drawn renderer could derive a stride cadence that
    /// kept a planted paw from sliding; that renderer is gone and the sprite packs bake their
    /// own walk frames, so nothing now constrains this constant mechanically.
    ///
    /// `nonisolated` because it is an immutable constant and the renderer reads it from a
    /// nonisolated context. Without it Swift warns — and in Swift 6 mode errors — that a
    /// main-actor-isolated static cannot be referenced from a nonisolated autoclosure. A `let` of
    /// a value type has nothing to protect, so the isolation was accidental rather than meant: it
    /// came free with the enclosing `@MainActor` class the moment this stopped being `private`.
    nonisolated static let walkSpeed: CGFloat = 42

    /// Whether the pill is to the character's right, as of right now.
    ///
    /// A pull, not a stored side — the same shape as `levelSource`, and for a stronger
    /// reason: the companion and the pill are independent windows that the user can drag
    /// separately, so which side the pill is on is only true at the moment it is asked.
    /// Stored, it went stale the first time either window moved, and the character glanced
    /// at where the pill used to be.
    var pillIsToTheRight: () -> Bool = { true }

    // MARK: Easing helpers

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(max(t, 0), 1)
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return clamped < 0.5
            ? 2 * clamped * clamped
            : 1 - pow(-2 * clamped + 2, 2) / 2
    }

    /// Height of a hop at `t`, 0...1...0, weighted so the fall is slower than
    /// the rise.
    private func hopArc(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return sin(clamped * .pi) * (clamped < 0.5 ? 1 : 0.92)
    }
}
