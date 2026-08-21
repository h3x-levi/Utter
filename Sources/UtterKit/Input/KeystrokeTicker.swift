import Foundation

/// A count of keystrokes, for anything that needs to know the user is typing.
///
/// **It stores a number and a time. Nothing else.** Not the key code, not the character,
/// not the modifiers, not the frontmost app. That constraint is the whole design: the
/// companion needs to know *that* you are typing so it can knead its paws, and a type
/// that physically cannot hold what you typed can never be made to leak it by a later
/// change. `KeyMonitor` already holds itself to this rule where it taps events — its own
/// comment notes that a tap printing key codes would be a keylogger — and this is that
/// rule expressed as a type.
///
/// **Pulled, not pushed.** The obvious shape is a callback that the companion registers,
/// but the companion is created by the window and `KeyMonitor` by the app delegate, so a
/// callback means threading a reference between two objects that have no reason to know
/// about each other. A counter both sides can reach needs no wiring at all, and it
/// matches how the behaviour engine already reads the microphone level: it ticks 30 times
/// a second regardless, so it may as well ask.
///
/// The resolution that costs is 1/30 s, since that is how often anyone looks. At a fast
/// typist's 8 keys/second that is at most one keystroke per sample, so nothing is ever
/// collapsed; at a physically impossible 60 keys/second two would land in one tick and
/// both are still counted, just with the same timestamp.
enum KeystrokeTicker {

    /// Guards the two fields. An `NSLock` rather than an actor or a queue because the
    /// critical section is two stores, the writer is a key-event handler that must not
    /// wait on anything, and `await` is not available on the paths that read this.
    private static let lock = NSLock()
    private static var total: UInt64 = 0
    private static var lastAt: TimeInterval = 0

    /// One keystroke happened. Called from `KeyMonitor`'s existing key handler — this
    /// adds no event monitor and no permission requirement of its own.
    static func note(at when: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lock.lock()
        total &+= 1
        lastAt = when
        lock.unlock()
    }

    /// The running count and when the last one landed.
    ///
    /// The count wraps with `&+`, which is correct rather than lazy: a consumer reads
    /// *differences* between samples, and unsigned wrapping subtraction gives the right
    /// difference across the boundary. At 8 keys/second `UInt64` would take 73 billion
    /// years to get there anyway.
    static var snapshot: (count: UInt64, lastAt: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        return (total, lastAt)
    }

    /// Reset, for tests. Not called in the app: a monotonic counter has nothing to reset.
    static func resetForTesting() {
        lock.lock()
        total = 0
        lastAt = 0
        lock.unlock()
    }
}
