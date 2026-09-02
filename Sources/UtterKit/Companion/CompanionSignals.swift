import CoreGraphics
import Foundation

// MARK: - Companion signals
//
// The rules that turn raw input into something the character can react to: is the user
// typing, how fast, is the cursor being flicked about, is the pointer stroking the
// character's head.
//
// Every type here is a **pure value type over timestamps and points**. No AppKit, no
// event monitors, no clocks of their own — a caller feeds in what it observed and the
// time it observed it, and reads the answer back. That is deliberate and it is the same
// choice `HoldTap.outcome(keyCode:isHotkeyHeld:isRepeat:)` makes in `KeyMonitor`: the
// interesting part is the rule, the rule is where the bugs are, and a rule expressed as
// a function of its inputs can be tested at 200x speed with no window, no screen, no
// permission grant and no real keyboard.
//
// **Nothing here records what was typed.** `TypingActivity` stores timestamps and
// nothing else — no key codes, no characters, no modifiers. That is not an accident of
// the design, it is the point: the companion needs to know *that* you are typing to
// knead its paws, and knowing *what* you typed would make this a keylogger. `KeyMonitor`
// already holds itself to that rule where it taps events, and it holds here too.

// MARK: Typing

/// How hard the user is typing, from keystroke timestamps alone.
///
/// Drives two behaviours: kneading (the character works its paws while you type) and
/// overheating (type fast enough for long enough and it goes red and steams).
///
/// Thresholds are set from real typing rates rather than picked to feel nice. A
/// comfortable prose typist runs 40-70 WPM, which at ~5 characters a word is 3.3-5.8
/// keys/second; a fast typist sustains 90-100 WPM, or 7.5-8.3 keys/second. So:
///
///   * **Typing at all** is >= 2 keys inside `typingWindow` (0.6 s). One key is a
///     keystroke, not typing — a single Cmd-Tab should not make the cat knead. Two
///     inside 600 ms is the slowest real digraph.
///   * **Overheating** is `overheatRate` (6.0 keys/s) sustained for `overheatSustain`
///     (1.2 s). Six sits above every comfortable rate and below a fast typist's peak,
///     so it fires when someone is genuinely hammering, not when they are working.
///
/// The exit threshold is deliberately lower than the entry threshold (`coolRate`, 3.5
/// keys/s). Without that gap, a typist hovering either side of 6 keys/s makes the cat
/// flicker red-normal-red several times a second, which is both ugly and — since it is
/// driven by a real signal — impossible to smooth out downstream.
struct TypingActivity: Equatable {

    /// Keystroke times, newest last. Times only — never what was pressed.
    private var strokes: [TimeInterval] = []

    /// Longest window any rule looks back over, so anything older can be discarded.
    ///
    /// Bounds memory without a magic capacity: at a physically implausible 30 keys/s
    /// this holds 60 entries, and a `Double` array of 60 is nothing. A ring buffer
    /// sized by hand would be the same thing with an off-by-one in it.
    private static let historyWindow: TimeInterval = 2.0

    static let typingWindow: TimeInterval = 0.6
    static let overheatRate: Double = 6.0
    static let overheatSustain: TimeInterval = 1.2
    static let coolRate: Double = 3.5

    /// When the current sustained burst crossed `overheatRate`, or nil if it has not.
    private var hotSince: TimeInterval?

    /// Whether the character is currently overheating. Latches, and clears via
    /// `coolRate`, which is what stops the flicker described above.
    private(set) var isOverheating = false

    /// Record one keystroke. `now` is the caller's clock, in seconds.
    ///
    /// Out-of-order times are dropped rather than sorted. Two `NSEvent` monitors can
    /// deliver the same physical keypress microseconds apart, and a timestamp that
    /// goes backwards would make `rate(at:)` divide by a negative window.
    mutating func record(at now: TimeInterval) {
        guard strokes.last.map({ now >= $0 }) ?? true else { return }
        strokes.append(now)
        prune(before: now - Self.historyWindow)
    }

    /// Advance the latched state to `now` without recording a keystroke.
    ///
    /// Has to exist separately from `record`: overheating must *end* when the user stops
    /// typing, and when they stop there are by definition no more events to carry the
    /// clock forward. The behaviour engine already ticks 30 times a second, so it calls
    /// this on every tick and the state decays on its own.
    mutating func update(at now: TimeInterval) {
        prune(before: now - Self.historyWindow)
        let current = rate(at: now)

        if current >= Self.overheatRate {
            let began = hotSince ?? now
            hotSince = began
            if now - began >= Self.overheatSustain { isOverheating = true }
        } else {
            hotSince = nil
            if isOverheating, current < Self.coolRate { isOverheating = false }
        }
    }

    /// Whether the user is typing as of `now`.
    func isTyping(at now: TimeInterval) -> Bool {
        strokes.count(where: { now - $0 <= Self.typingWindow }) >= 2
    }

    /// Keys per second over the last second.
    ///
    /// One second rather than the full 2 s history: a 2 s average lags visibly behind a
    /// burst, and the character reacting a second late reads as broken rather than as
    /// smoothed.
    func rate(at now: TimeInterval) -> Double {
        Double(strokes.count(where: { now - $0 <= 1.0 }))
    }

    /// 0...1 for how hot things are, for driving a colour tint continuously rather than
    /// as a switch. 0 at `coolRate`, 1 at twice `overheatRate`.
    func heat(at now: TimeInterval) -> CGFloat {
        let current = rate(at: now)
        guard current > Self.coolRate else { return 0 }
        let span = Self.overheatRate * 2 - Self.coolRate
        return CGFloat(min(1, (current - Self.coolRate) / span))
    }

    private mutating func prune(before cutoff: TimeInterval) {
        guard let first = strokes.first, first < cutoff else { return }
        strokes.removeAll { $0 < cutoff }
    }
}

// MARK: Cursor

/// Where the character should look, and whether the cursor is worth chasing.
///
/// A value type over two samples, because that is all either question needs: aim is a
/// function of where the cursor is relative to the character, and speed is a function of
/// how far it moved since last time.
struct CursorTracking: Equatable {

    /// Cursor speed, in points per second, above which the character starts hunting.
    ///
    /// A deliberate flick across a 1512pt-wide built-in display takes 200-400 ms, so
    /// 1400 pt/s is a decisive throw. Set from the measured extreme rather than a small
    /// number: at 600 pt/s an ordinary reach for the menu bar sets the cat off, and a
    /// pet that pounces every time you move the mouse is exhausting rather than playful.
    static let huntSpeed: CGFloat = 1400

    /// How long a hunt lasts once triggered. Long enough to read as a decision, short
    /// enough that it cannot stack into permanent chasing.
    static let huntDuration: TimeInterval = 1.6

    private var previous: CGPoint?
    private var previousAt: TimeInterval?

    /// Speed of the last movement, points per second.
    private(set) var speed: CGFloat = 0

    /// When the current hunt began, or nil.
    private(set) var huntingSince: TimeInterval?

    /// Feed the current cursor position. Called once per tick, from a plain read of
    /// `NSEvent.mouseLocation` — no event monitor, and so no permission of any kind.
    mutating func sample(_ point: CGPoint, at now: TimeInterval) {
        defer { previous = point; previousAt = now }

        guard let last = previous, let lastAt = previousAt else { return }
        let elapsed = now - lastAt
        // A zero or negative interval would divide to infinity. Two samples inside the
        // same tick carry no new information anyway.
        guard elapsed > 0.0001 else { return }

        let travelled = hypot(point.x - last.x, point.y - last.y)
        speed = travelled / CGFloat(elapsed)

        if speed >= Self.huntSpeed {
            huntingSince = now
        } else if let began = huntingSince, now - began >= Self.huntDuration {
            huntingSince = nil
        }
    }

    func isHunting(at now: TimeInterval) -> Bool {
        guard let began = huntingSince else { return false }
        return now - began < Self.huntDuration
    }

    /// Where to point the eyes: a **unit vector** from the character's centre toward the
    /// cursor.
    ///
    /// Returned as a direction rather than as pixels because the art decides how far an
    /// eye may travel — a 32px sprite can move an iris about 2px before it leaves the
    /// socket, and only the pack knows that. Scaling a direction by the art's own limit
    /// keeps that knowledge with the art.
    ///
    /// **This divides by the distance, not by a fixed falloff, and that is the whole
    /// point.** The first version scaled each axis by a 220pt reference distance and
    /// clamped: `dx = (cursor.x - centre.x) / 220`. Every cursor further away than that —
    /// which on a 1512pt-wide display is nearly the entire screen — clamped *both* axes to
    /// ±1, so the eyes locked to one of four 45° diagonals and stopped responding to the
    /// mouse at all. Measured against the true bearing, that was wrong by up to 33°, and it
    /// is why the character appeared to stare off into a corner instead of following the
    /// pointer.
    ///
    /// Dividing by the true distance makes the direction exact at every range: the
    /// magnitude is always 1, so the eyes are always fully deflected *the correct way*.
    /// Partial deflection by distance was considered and rejected — with only two pixels of
    /// travel available, a proportional aim spends most of its range on sub-pixel offsets
    /// that quantise to no movement, which looks exactly like the bug being fixed.
    ///
    /// `deadZone` is the one exception: with the pointer sitting on the character, the
    /// direction is dominated by jitter, so the eyes look straight ahead instead of
    /// twitching.
    static func aim(from centre: CGPoint, to cursor: CGPoint,
                    deadZone: CGFloat = 6) -> CGVector {
        let dx = cursor.x - centre.x
        let dy = cursor.y - centre.y
        let distance = hypot(dx, dy)
        guard distance > deadZone else { return CGVector(dx: 0, dy: 0) }
        return CGVector(dx: dx / distance, dy: dy / distance)
    }
}

// MARK: Googly eyes

/// A pupil that rolls loosely in its socket instead of pointing rigidly at the cursor.
///
/// The difference between "the eyes track the mouse" and "the eyes are googly" is entirely
/// physical: a craft-shop googly eye is a bead in a shallow dome, so it *lags* when the head
/// turns, *overshoots* when it arrives, and *settles* with a wobble. Snapping the pupil
/// straight to the cursor direction reads as a security camera; this reads as an eye.
///
/// Modelled as a damped spring per axis, which is the standard way to get that shape and is
/// two multiplies per axis per frame. Deliberately **underdamped**: the damping ratio is
/// about 0.5, which overshoots the target by roughly 16% and settles in a third of a second.
/// Critically damped would arrive smoothly with no wobble — correct for a UI transition, and
/// exactly the wrong feel here.
struct GooglyEyes: Equatable {

    /// Spring constant. Higher is snappier and overshoots sooner.
    ///
    /// 140 with `damping` 12 gives a damping ratio of 12 / (2·√140) ≈ 0.51 and a settle time
    /// near 0.3s — fast enough to feel attached to the cursor, slow enough that the lag is
    /// visible on a quick flick, which is where the whole effect lives.
    static let stiffness: CGFloat = 140
    static let damping: CGFloat = 12

    /// Where the pupil is, as a fraction of its travel. Magnitude is clamped to 1 so it can
    /// never leave the socket, however hard the spring is driven.
    private(set) var offset: CGVector = CGVector(dx: 0, dy: 0)
    private var velocity: CGVector = CGVector(dx: 0, dy: 0)

    /// Advance toward `target` by one tick.
    mutating func settle(toward target: CGVector, tick: TimeInterval) {
        // A tick long enough to make the spring explode is a tick that came from a stalled
        // run loop, not from the engine. Clamped rather than skipped, so a hitch makes the
        // eyes lag slightly instead of flinging the pupil across the face.
        let step = CGFloat(min(max(tick, 0.001), 0.1))

        for axis in 0..<2 {
            let position = axis == 0 ? offset.dx : offset.dy
            let goal = axis == 0 ? target.dx : target.dy
            var speed = axis == 0 ? velocity.dx : velocity.dy

            let acceleration = (goal - position) * Self.stiffness - speed * Self.damping
            speed += acceleration * step
            let moved = position + speed * step

            if axis == 0 {
                velocity.dx = speed
                offset.dx = moved
            } else {
                velocity.dy = speed
                offset.dy = moved
            }
        }

        // Clamp on magnitude, not per axis: the socket is round, so per-axis clamping would
        // let the pupil sit at (1, 1) — √2 times its travel — and land outside the white on
        // the diagonals. This is the same reasoning as `CursorTracking.aim`.
        let magnitude = hypot(offset.dx, offset.dy)
        if magnitude > 1 {
            offset.dx /= magnitude
            offset.dy /= magnitude
            // Kill the outward component of the velocity too, or the spring keeps pushing
            // into the clamp and the pupil sticks to the rim instead of rebounding.
            let outward = (velocity.dx * offset.dx + velocity.dy * offset.dy)
            if outward > 0 {
                velocity.dx -= outward * offset.dx
                velocity.dy -= outward * offset.dy
            }
        }
    }

    /// Snap to a position with no motion. For waking, where a settle from the last place the
    /// cursor was would look like the character had been dreaming about it.
    mutating func reset(to position: CGVector = CGVector(dx: 0, dy: 0)) {
        offset = position
        velocity = CGVector(dx: 0, dy: 0)
    }
}

// MARK: Petting

/// Detects the pointer being stroked back and forth over the character.
///
/// A stroke is not "the pointer is inside the character" — that is hovering, and it
/// already lifts the character slightly. Petting is *repeated reversal of direction*
/// while inside, which is what a hand does when it strokes a cat and what nothing else
/// does by accident.
///
/// `reversalsToPurr` (3) inside `window` (1.4 s) is the rule. Two reversals happen when
/// someone moves the pointer past the character and comes back for a menu; three inside
/// a second and a half is a deliberate rub.
struct PettingDetector: Equatable {

    static let reversalsToPurr = 3
    static let window: TimeInterval = 1.4
    /// How long purring continues after the last stroke, so a brief pause mid-rub does
    /// not cut the purr off.
    static let purrLinger: TimeInterval = 1.1

    private var lastX: CGFloat?
    private var lastDirection: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var lastStrokeAt: TimeInterval?

    /// Feed the pointer position and whether it is currently over the character.
    mutating func sample(_ point: CGPoint, inside: Bool, at now: TimeInterval) {
        guard inside else {
            // Leaving resets the gesture but not the linger, so the purr fades out
            // rather than stopping the instant the pointer slips off.
            lastX = nil
            lastDirection = 0
            reversals.removeAll()
            return
        }

        defer { lastX = point.x }
        guard let previous = lastX else { return }

        let delta = point.x - previous
        // A 1.5pt deadband. Without it, sub-pixel jitter from a trackpad registers as
        // dozens of direction changes a second and the cat purrs at a resting hand.
        guard abs(delta) > 1.5 else { return }

        let direction: CGFloat = delta > 0 ? 1 : -1
        if lastDirection != 0, direction != lastDirection {
            reversals.append(now)
            reversals.removeAll { now - $0 > Self.window }
            if reversals.count >= Self.reversalsToPurr { lastStrokeAt = now }
        }
        lastDirection = direction
    }

    func isPurring(at now: TimeInterval) -> Bool {
        guard let last = lastStrokeAt else { return false }
        return now - last < Self.purrLinger
    }
}

// MARK: Reminders

/// What the character is reminding you about.
enum CompanionReminder: Equatable {
    case stretch
    case water
    /// A pomodoro interval ended. `focus` is true when it was a work block, so the message
    /// can say which way round it is.
    case pomodoro(focus: Bool)
    /// A time the user set, with their own words.
    case message(String)

    /// What the character says. Written in the second person and kept short, because it is
    /// rendered in a single-line capsule beside a 52pt cat.
    func line(name: String) -> String {
        let you = name.isEmpty ? "" : ", \(name)"
        switch self {
        case .stretch: return "Stretch time\(you)"
        case .water: return "Water break\(you)"
        case .pomodoro(let focus): return focus ? "Focus done — break\(you)" : "Break over\(you)"
        case .message(let text): return text
        }
    }

    var memoryKey: String {
        switch self {
        case .stretch: return "stretch"
        case .water: return "water"
        case .pomodoro(let focus): return focus ? "focus" : "break"
        case .message: return "message"
        }
    }
}

/// Decides when the character should speak up, against the **wall clock**.
///
/// Wall clock rather than the behaviour engine's own `clock`, and this is not a detail: the
/// engine's ticker stops after 90 seconds of rest, and its clock freezes with it. Every
/// reminder here exists for a user who is *sitting still* — stretch, water, the end of a
/// focus block — so scheduling them on a clock that stops precisely when the user goes
/// quiet would mean the stretch reminder never fires for anyone who needs it.
///
/// It is also why this is driven by its own low-rate timer rather than by the 30 Hz tick.
/// Once a second is 1800x more resolution than a 45-minute interval needs.
struct ReminderScheduler: Equatable {

    /// Minutes between stretch reminders, or nil for off.
    var stretchEvery: TimeInterval?
    /// Minutes between water reminders, or nil for off.
    var waterEvery: TimeInterval?

    /// Pomodoro block lengths. Nil for off.
    var pomodoroFocus: TimeInterval?
    var pomodoroBreak: TimeInterval?

    /// A one-off message and when to say it.
    var messageAt: Date?
    var messageText: String = ""

    private var lastStretch: Date?
    private var lastWater: Date?
    private var pomodoroStartedAt: Date?
    private var pomodoroInFocus = true
    private var messageDelivered = false

    /// Start the clocks. Called when the companion appears, so an interval is measured from
    /// when the character came on screen rather than from the epoch.
    mutating func begin(at now: Date) {
        lastStretch = now
        lastWater = now
        if pomodoroStartedAt == nil { pomodoroStartedAt = now }
    }

    /// The reminder due now, if any. At most one per call, so two coinciding reminders are
    /// spoken one after the other rather than overwriting each other in the same bubble.
    ///
    /// Order is by how time-critical each is: a pomodoro block boundary is a specific
    /// moment, a one-off message is a specific moment, and the recurring health nudges can
    /// wait a second.
    mutating func due(at now: Date) -> CompanionReminder? {
        if let focus = pomodoroFocus, let rest = pomodoroBreak, let started = pomodoroStartedAt {
            let length = pomodoroInFocus ? focus : rest
            if now.timeIntervalSince(started) >= length {
                let finished = pomodoroInFocus
                pomodoroInFocus.toggle()
                pomodoroStartedAt = now
                return .pomodoro(focus: finished)
            }
        }

        if let at = messageAt, !messageDelivered, now >= at, !messageText.isEmpty {
            messageDelivered = true
            return .message(messageText)
        }

        if let every = stretchEvery, let last = lastStretch,
           now.timeIntervalSince(last) >= every {
            lastStretch = now
            return .stretch
        }

        if let every = waterEvery, let last = lastWater, now.timeIntervalSince(last) >= every {
            lastWater = now
            return .water
        }

        return nil
    }

    /// How far through the current pomodoro block, 0...1, and whether it is a focus block.
    /// Nil when pomodoro is off — the timer should not be drawn at all rather than drawn empty.
    func pomodoroProgress(at now: Date) -> (fraction: Double, focus: Bool)? {
        guard let focus = pomodoroFocus, let rest = pomodoroBreak,
              let started = pomodoroStartedAt
        else { return nil }
        let length = pomodoroInFocus ? focus : rest
        guard length > 0 else { return nil }
        let done = now.timeIntervalSince(started) / length
        return (min(1, max(0, done)), pomodoroInFocus)
    }

    /// Seconds left in the current block, for the numeric readout.
    func pomodoroRemaining(at now: Date) -> TimeInterval? {
        guard let focus = pomodoroFocus, let rest = pomodoroBreak,
              let started = pomodoroStartedAt
        else { return nil }
        let length = pomodoroInFocus ? focus : rest
        return max(0, length - now.timeIntervalSince(started))
    }
}

// MARK: Scrolling

/// Turns scroll wheel deltas into how much paper the character has unspooled.
///
/// Kept as a value type for the same reason as the rest: the interesting behaviour is
/// the decay, and a decay is far easier to trust when it can be stepped in a test than
/// when it lives inside an animation.
struct ScrollActivity: Equatable {

    /// Scroll distance, in wheel units, that unspools the paper fully.
    ///
    /// A trackpad two-finger flick through a long document delivers on the order of
    /// hundreds of units, so 240 reaches full extension during an ordinary scroll rather
    /// than needing a deliberate effort.
    static let fullExtension: CGFloat = 240

    /// How long the paper takes to roll back up once scrolling stops.
    static let retractAfter: TimeInterval = 0.45

    private var accumulated: CGFloat = 0
    private var lastScrollAt: TimeInterval?

    /// 0...1 — how far the paper is unrolled.
    private(set) var extension_: CGFloat = 0

    mutating func record(delta: CGFloat, at now: TimeInterval) {
        accumulated += abs(delta)
        lastScrollAt = now
        extension_ = min(1, accumulated / Self.fullExtension)
    }

    /// Decay toward rolled-up. Called every tick.
    mutating func update(at now: TimeInterval, tick: TimeInterval) {
        guard let last = lastScrollAt else { return }
        guard now - last > Self.retractAfter else { return }

        // Retract over the same time it takes to extend, so the gesture feels reversible.
        let step = CGFloat(tick / Self.retractAfter)
        extension_ = max(0, extension_ - step)
        if extension_ == 0 {
            accumulated = 0
            lastScrollAt = nil
        }
    }

    var isUnrolled: Bool { extension_ > 0.02 }
}
