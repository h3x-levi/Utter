import Cocoa
import Carbon.HIToolbox

/// Supported hotkey options with descriptions
struct HotkeyOption: Identifiable {
    let id: String
    let name: String
    let description: String
    let impact: String
    let flagCheck: (NSEvent) -> Bool

    static let options: [HotkeyOption] = [
        HotkeyOption(
            id: "fn",
            name: "Fn",
            description: "The Function key in the bottom-left corner of your keyboard.",
            impact: "Recommended \u{2014} rarely conflicts with other shortcuts.",
            flagCheck: { $0.modifierFlags.contains(.function) }
        ),
        HotkeyOption(
            id: "rightOption",
            name: "Right ⌥ Option",
            description: "The Option key on the right side of the spacebar.",
            impact: "Good if you don\u{2019}t use right Option for special characters.",
            flagCheck: { $0.modifierFlags.contains(.option) && $0.keyCode == 61 }
        ),
        HotkeyOption(
            id: "rightCommand",
            name: "Right ⌘ Command",
            description: "The Command key on the right side of the spacebar.",
            impact: "Use with caution \u{2014} right Command appears in some shortcuts.",
            flagCheck: { $0.modifierFlags.contains(.command) && $0.keyCode == 54 }
        ),
        HotkeyOption(
            id: "rightControl",
            name: "Right ⌃ Control",
            description: "The Control key on the right side (if your keyboard has one).",
            impact: "Safe, but not every keyboard has a right Control key.",
            // Must check the keyCode, like the other right-hand options: matching
            // the bare `.control` flag fired dictation on ⌃C, ⌃A, ⌃E and every
            // other Control shortcut - each also injecting a ⌘C into the user's app.
            flagCheck: { $0.modifierFlags.contains(.control) && $0.keyCode == 62 }
        ),
    ]

    static func find(id: String) -> HotkeyOption {
        options.first { $0.id == id } ?? options[0]
    }

    /// Resolves a persisted value that is either an id or a legacy display label.
    static func find(stored: String) -> HotkeyOption {
        options.first { $0.id == stored || $0.name == stored } ?? options[0]
    }
}

/// What a shortcut does, independent of how it is spelled.
///
/// Each action has two spellings - a standalone `KeyChord`, and for some a `HoldTap` on
/// the end of the held dictation hotkey. The monitor resolves an event to an action and
/// dispatches once, so the two spellings of one shortcut cannot drift into doing
/// different things.
enum ShortcutAction: Equatable {
    case handsFree
    case noteCapture
    case memoryCapture

    /// What the shortcut is called on screen and in the log. Lives here so both
    /// spellings are captioned from one string.
    var label: String {
        switch self {
        case .handsFree: return "Hands-free"
        case .noteCapture: return "Take a note"
        case .memoryCapture: return "Remember"
        }
    }
}

/// A global chord Utter listens for, plus the text that names it.
///
/// One value per chord so the monitor and the UI cannot drift: the key code an event
/// is matched against and the "⌃⌥N" the Hotkey card prints come from the same place.
/// They were previously string literals in Settings, the status-item menu and the
/// release notes, none of which could see the key code they were describing.
struct KeyChord {
    let keyCode: UInt16
    let flags: NSEvent.ModifierFlags
    /// How the key is printed on a keyboard - "Space", "N".
    let keyLabel: String
    let action: ShortcutAction

    /// Hands-free dictation: press to start, press again to finish. Independent of
    /// the push-to-talk hotkey so the gesture works from idle.
    static let handsFree = KeyChord(keyCode: UInt16(kVK_Space),
                                    flags: [.control, .option],
                                    keyLabel: "Space",
                                    action: .handsFree)

    /// Dictate into a Utter note instead of the frontmost app. Shares the ⌃⌥ prefix
    /// with hands-free so the two dictation gestures stay next to each other; N for
    /// note.
    static let noteCapture = KeyChord(keyCode: UInt16(kVK_ANSI_N),
                                      flags: [.control, .option],
                                      keyLabel: "N",
                                      action: .noteCapture)

    /// Speak a private memory or reminder. R for remember.
    static let memoryCapture = KeyChord(keyCode: UInt16(kVK_ANSI_R),
                                        flags: [.control, .option],
                                        keyLabel: "R",
                                        action: .memoryCapture)

    /// Each modifier's flag, glyph and spelled name, in the order macOS prints them
    /// in a menu - Control, Option, Shift, Command - rather than the order the flags
    /// happen to be written in at the definition above.
    private static let modifiers: [(flag: NSEvent.ModifierFlags, glyph: String, name: String)] = [
        (.control, "\u{2303}", "Control"),
        (.option, "\u{2325}", "Option"),
        (.shift, "\u{21E7}", "Shift"),
        (.command, "\u{2318}", "Command"),
    ]

    /// "⌃⌥N", for a label or a menu item.
    var symbols: String { keycaps.joined() }

    /// One string per key, for `ShortcutHint`, which draws each as its own keycap  - 
    /// two chips read as two keys, which is what the user has to press.
    var keycaps: [String] {
        Self.modifiers.filter { flags.contains($0.flag) }.map(\.glyph) + [keyLabel]
    }

    /// "Control-Option-N": the chord spelled out, for prose and for VoiceOver, which
    /// reads the glyphs as nothing useful.
    var spelled: String {
        (Self.modifiers.filter { flags.contains($0.flag) }.map(\.name) + [keyLabel])
            .joined(separator: "-")
    }
}

/// The second spelling of a shortcut: keep the dictation hotkey held, then tap one key.
///
/// Why hold-*then*-tap rather than a plain "Fn+N" chord: the hotkey starts recording on
/// key-**down**, so by the time a letter could be seen the recording has already begun,
/// and waiting to find out whether a letter follows would put latency on the app's
/// primary action. Tapping during the recording needs no disambiguation at all - and
/// both actions already know how to adopt an in-flight push-to-talk recording
/// (`toggleHandsFree` and `toggleNoteCapture` check `audioRecorder.isRecording`), so
/// this is an extension of the hold rather than a second chord system.
///
/// Generalised over the hotkey: the rule is "while the dictation hotkey is held",
/// whichever key that is, and the hold state comes from the same `isKeyHeld` that
/// decides when to record.
struct HoldTap {
    let keyCode: UInt16
    /// How the key is printed on a keyboard - "Space".
    let keyLabel: String
    let action: ShortcutAction

    /// Tap Space while still holding: the push-to-talk recording carries on hands-free,
    /// and releasing the hotkey no longer stops it (`suppressReleaseStop`).
    static let handsFree = HoldTap(keyCode: UInt16(kVK_Space),
                                   keyLabel: "Space",
                                   action: .handsFree)

    /// Every hold-then-tap binding, in the order Settings prints them.
    ///
    /// Note capture is deliberately **not** here: macOS owns Fn+N. Read back from the
    /// live WindowServer table on this machine (macOS 26.6.1) via
    /// `CGSGetSymbolicHotKeyValue`, symbolic hotkey 212 is key code 45 (N) + fn and
    /// enabled - Show Notification Center - as are fn+A/C/F/H/M/Q/S. Space appears in
    /// that table only with ⌘/⌃/⌥ and never with fn, which is what makes it safe to
    /// bind. `⌃⌥N` stays the only route to a note: a second gesture that opened
    /// Notification Center instead would be worse than none.
    static let all: [HoldTap] = [.handsFree]

    static func binding(forKeyCode keyCode: UInt16) -> HoldTap? {
        all.first { $0.keyCode == keyCode }
    }

    /// The hold-then-tap spelling of an action, if it has one. Settings asks this way
    /// round: it prints the chord for every action and adds this row when one exists.
    static func binding(for action: ShortcutAction) -> HoldTap? {
        all.first { $0.action == action }
    }

    /// What the tap should do with a key seen while it is installed.
    enum Outcome: Equatable {
        /// Not ours - hand it to the frontmost app untouched.
        case pass
        /// Ours, but there is nothing to do. Swallow it anyway so it never types.
        case swallow
        /// Ours: swallow it and run the action.
        case fire(ShortcutAction)
    }

    /// The whole hold-then-tap rule, as a pure function of the key and the hold state.
    ///
    /// Pure because the alternative is testing it through a live `CGEventTap`, which
    /// needs Accessibility and real key presses. The two cases worth pinning are the
    /// ones that would be user-visible bugs: an unbound key must `pass` (holding the
    /// hotkey must not swallow the rest of the keyboard), and an auto-repeat must
    /// `swallow` without firing - a held Space would otherwise toggle hands-free about
    /// fifteen times a second *and* leak a stream of spaces into the frontmost app.
    static func outcome(keyCode: UInt16, isHotkeyHeld: Bool, isRepeat: Bool) -> Outcome {
        guard isHotkeyHeld, let binding = binding(forKeyCode: keyCode) else { return .pass }
        return isRepeat ? .swallow : .fire(binding.action)
    }

    /// Keycaps for `ShortcutHint`: the key being held, then the key to tap. Takes the
    /// hold key rather than reading `UserData` so the gesture prints correctly for
    /// whichever hotkey is configured, and so this stays testable.
    func keycaps(holdKey: String) -> [String] { [holdKey, keyLabel] }

    /// "hold Fn, then Space" - for prose, the log, and VoiceOver, which reads a row of
    /// keycaps as nothing useful.
    func spelled(holdKey: String) -> String { "hold \(holdKey), then \(keyLabel)" }

    /// Whether hold-then-tap can actually fire right now.
    ///
    /// False until `KeyMonitor` has an event tap: without one the tapped key cannot be
    /// swallowed, and a gesture that types a space into the field the transcript is
    /// about to land in is worse than no gesture. Settings reads this so the Hotkey card
    /// cannot advertise a route nothing would fire - the same property that keeps the
    /// chords honest. Main thread only.
    fileprivate(set) static var isAvailable = false
}

/// The event tap behind hold-then-tap.
///
/// A `CGEventTap` and not `NSEvent.addGlobalMonitorForEvents` because only a tap can
/// **consume** a key: a global monitor is observe-only - its handler returns nothing  - 
/// so a tapped Space would reach the frontmost app as well, landing a stray space in the
/// very field the transcript is about to be typed into, or hitting play/pause in
/// whatever is playing. The chords get away with a monitor because ⌃⌥ produces no
/// character; Fn does not suppress text input, so hold-then-tap cannot.
///
/// Needs Accessibility, which Utter already requires in order to type text at all
/// (`TextInjector`), so this asks for nothing new. Without it the tap is never created
/// and hold-then-tap stays off rather than typing letters.
///
/// Must outlive its tap: the callback reaches this object through an **unretained**
/// pointer, because a C callback cannot hold a Swift reference. `deinit` tears the tap
/// down, and `KeyMonitor` - which owns the only instance - lives as long as the app, so
/// there is no window in which a keystroke can find a freed object. Do not make this a
/// short-lived object without retaining it for the tap's lifetime instead.
private final class HoldTapMonitor {
    private let onAction: (ShortcutAction) -> Void
    /// Guards the state the tap thread and the main thread share. Uncontended in the
    /// steady state: the only per-keystroke read is `hotkeyIsHeld`.
    private let lock = NSLock()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var hotkeyIsHeld = false

    init(onAction: @escaping (ShortcutAction) -> Void) {
        self.onAction = onAction
    }

    /// Create the tap and start pumping it. `false` means hold-then-tap is unavailable  - 
    /// the caller says why in the log.
    ///
    /// Checks `AXIsProcessTrusted` first so an untrusted process never reaches
    /// `tapCreate`, which would put a second permission prompt (Input Monitoring) in
    /// front of a user who has not granted the first one.
    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            return Unmanaged<HoldTapMonitor>.fromOpaque(refcon)
                .takeUnretainedValue()
                .handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        lock.withLock { self.tap = tap }

        // Created here, pumped there. Creating on the calling thread keeps "did it work"
        // synchronous - the startup log and the Settings card both need the answer now  - 
        // while the callbacks arrive on a thread of our own, because macOS disables a tap
        // whose callback is slow to return and stalls every keystroke in the system while
        // it waits. Utter loads and runs a Whisper model in-process, so the main thread is
        // not a safe place to sit in the path of system-wide key delivery.
        let thread = Thread { [weak self] in
            guard let self else { return }
            self.lock.withLock { self.runLoop = CFRunLoopGetCurrent() }
            // `stop()` can land between `thread.start()` and here - two `.hotkeyChanged`
            // notifications in quick succession are enough - and an invalidated port
            // yields no source. Bail rather than handing the run loop a null one.
            guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            // Returns once the source is gone - see `stop()`.
            CFRunLoopRun()
        }
        thread.name = "utter.dictation.holdtap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    func stop() {
        // Clear `tap` *before* disabling it, and outside the lock. Disabling a tap can
        // call back with `.tapDisabledByUserInput`, and that branch re-enables whatever
        // `self.tap` holds - so a stop that niled it afterwards would be undone by its
        // own callback, and one that disabled the tap while holding the lock would
        // deadlock against it.
        let (tap, loop) = lock.withLock { () -> (CFMachPort?, CFRunLoop?) in
            let pair = (self.tap, self.runLoop)
            self.tap = nil
            self.runLoop = nil
            self.hotkeyIsHeld = false
            return pair
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            // Drops the run loop source, which is what lets `CFRunLoopRun` return and the
            // thread exit. The stop is belt-and-braces for a loop still waiting on it.
            CFMachPortInvalidate(tap)
        }
        if let loop { CFRunLoopStop(loop) }
    }

    /// Called from `handleFlagsChanged` as the dictation hotkey goes down and up.
    func setHotkeyIsHeld(_ isHeld: Bool) {
        lock.withLock { hotkeyIsHeld = isHeld }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap that ever takes too long, and again after some
        // security-relevant input. A disabled tap is silent, so re-enable it rather than
        // letting hold-then-tap quietly stop working for the rest of the session.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let tap = lock.withLock { self.tap }
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            print("⌨️ Hold-then-tap: the system disabled the event tap "
                  + "(\(type == .tapDisabledByTimeout ? "timeout" : "user input")) - re-enabled")
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let isHeld = lock.withLock { hotkeyIsHeld }

        // Every keystroke on this machine passes through here, so nothing about a key
        // that is not one of ours is examined further, and nothing is ever logged for
        // one - a tap that printed key codes would be a keylogger.
        switch HoldTap.outcome(keyCode: keyCode, isHotkeyHeld: isHeld, isRepeat: isRepeat) {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .swallow:
            return nil
        case .fire(let action):
            print("⌨️ Hold-then-tap: \(action.label)")
            onAction(action)
            return nil
        }
    }

    deinit { stop() }
}

/// Monitors a configurable key for hold-to-record behavior.
///
/// Three independent gestures are supported:
///   - Hold the configured hotkey (Fn / Right Option / Right Cmd / Right Ctrl) → push-to-talk
///   - `KeyChord.handsFree` anywhere → toggle hands-free dictation
///   - `KeyChord.noteCapture` anywhere → dictate into a Utter note instead of
///     typing into the frontmost app
///
/// Plus a second spelling of the first two: `HoldTap`, a key tapped while the hotkey is
/// still held, which upgrades the recording that hold already started. The chords remain
/// the only route from idle, where there is no hold to add a key to.
class KeyMonitor {
    private let onRecordStart: () -> Void
    private let onRecordStop: () -> Void
    private let onHandsFreeToggle: () -> Void
    private let onNoteCaptureToggle: () -> Void
    private let onMemoryCaptureToggle: () -> Void
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var isKeyHeld = false
    private var lastHotkeyPressTime: TimeInterval = 0
    private var lastHotkeyReleaseTime: TimeInterval = 0
    private var firstTapWasQuick: Bool = false
    private let doubleTapIntervalThreshold: TimeInterval = 0.38
    private let quickTapDurationThreshold: TimeInterval = 0.35
    /// Lazy so it can close over `dispatch`, which needs the callbacks `init` stores.
    private lazy var holdTapMonitor = HoldTapMonitor { [weak self] action in
        self?.dispatch(action)
    }

    /// External signal: when true, releasing the hotkey will NOT call onRecordStop.
    /// AppDelegate sets this while in hands-free mode so push-to-talk → hands-free
    /// upgrades survive the hotkey release.
    var suppressReleaseStop = false

    init(
        onRecordStart: @escaping () -> Void,
        onRecordStop: @escaping () -> Void,
        onHandsFreeToggle: @escaping () -> Void = {},
        onNoteCaptureToggle: @escaping () -> Void = {},
        onMemoryCaptureToggle: @escaping () -> Void = {}
    ) {
        self.onRecordStart = onRecordStart
        self.onRecordStop = onRecordStop
        self.onHandsFreeToggle = onHandsFreeToggle
        self.onNoteCaptureToggle = onNoteCaptureToggle
        self.onMemoryCaptureToggle = onMemoryCaptureToggle
    }

    func start() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        // Both chords, from any state. Hold-then-tap does *not* arrive here - it needs to
        // swallow its key, which a monitor cannot do, so it comes from the event tap.
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }

        let hotkeyName = UserData.shared.hotkeyName

        // Hold-then-tap needs an event tap to swallow the tapped key, so unlike the
        // chords it can be unavailable. Both branches are logged: a gesture that is
        // simply missing is otherwise indistinguishable from one that is broken.
        HoldTap.isAvailable = holdTapMonitor.start()
        if !HoldTap.isAvailable {
            print("⌨️ Hold-then-tap unavailable: "
                  + (AXIsProcessTrusted() ? "the system refused an event tap"
                                          : "Accessibility not granted")
                  + " - the chords still work")
        }

        var gestures = ["hold \(hotkeyName) to record",
                        "double-tap \(hotkeyName) for hands-free",
                        "\(KeyChord.handsFree.symbols) hands-free",
                        "\(KeyChord.noteCapture.symbols) note",
                        "\(KeyChord.memoryCapture.symbols) remember"]
        if HoldTap.isAvailable {
            gestures += HoldTap.all.map { "\($0.spelled(holdKey: hotkeyName)) → \($0.action.label)" }
        }
        print("⌨️ Key monitor started (\(gestures.joined(separator: ", ")))")
    }

    func stop() {
        for monitor in [globalFlagsMonitor, localFlagsMonitor, globalKeyDownMonitor, localKeyDownMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyDownMonitor = nil
        localKeyDownMonitor = nil
        holdTapMonitor.stop()
        HoldTap.isAvailable = false
        firstTapWasQuick = false
        lastHotkeyReleaseTime = 0
        lastHotkeyPressTime = 0
    }

    /// Restart monitoring (call after hotkey change)
    func restart() {
        stop()
        isKeyHeld = false
        start()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let option = HotkeyOption.find(id: UserData.shared.hotkeyId)
        let keyPressed = option.flagCheck(event)
        let now = CACurrentMediaTime()

        if keyPressed && !isKeyHeld {
            isKeyHeld = true
            holdTapMonitor.setHotkeyIsHeld(true)

            let isDoubleTap = UserData.shared.doubleTapHotkeyForHandsFree
                && firstTapWasQuick
                && (now - lastHotkeyReleaseTime) <= doubleTapIntervalThreshold

            if isDoubleTap {
                print("✨ Hotkey double-tap (\(option.name) twice) detected - toggling hands-free")
                firstTapWasQuick = false
                lastHotkeyReleaseTime = 0
                suppressReleaseStop = true
                DispatchQueue.main.async { self.onHandsFreeToggle() }
            } else {
                lastHotkeyPressTime = now
                DispatchQueue.main.async { self.onRecordStart() }
            }
        } else if !keyPressed && isKeyHeld {
            isKeyHeld = false
            holdTapMonitor.setHotkeyIsHeld(false)

            let pressDuration = now - lastHotkeyPressTime
            firstTapWasQuick = (pressDuration < quickTapDurationThreshold)
            lastHotkeyReleaseTime = now

            // Hands-free mode keeps recording even after the hotkey is released.
            if suppressReleaseStop {
                print("🔒 Hotkey released but hands-free mode active - keeping recorder on")
                return
            }
            DispatchQueue.main.async { self.onRecordStop() }
        }
    }

    /// The two chords: hands-free and note capture.
    /// Independent of the push-to-talk hotkey so either works from idle, push-to-talk, or hands-free state.
    private func handleKeyDown(_ event: NSEvent) {
        // Auto-repeat would toggle the mode ~15x/second while the chord is held:
        // repeat 1 starts hands-free, repeat 2 immediately stops it, and the ~60ms
        // clip is then rejected as too short - a burst of chimes and a dead turn.
        guard !event.isARepeat else { return }

        // Count the keystroke for the companion, before the chord filter below returns
        // for every other key. Deliberately after the auto-repeat guard: a held-down key
        // repeats at ~15/second, which would read as inhumanly fast typing and light up
        // the overheat reaction for someone leaning on the arrow keys.
        //
        // The count is all that leaves this function - see `KeystrokeTicker`, which has
        // nowhere to put a key code even if someone later tried.
        KeystrokeTicker.note()
        // Resolve which chord this is first, so the modifier check below tests the
        // flags that chord actually declares rather than one chord's flags standing
        // in for both.
        let chord: KeyChord
        switch event.keyCode {
        case KeyChord.handsFree.keyCode: chord = .handsFree
        case KeyChord.noteCapture.keyCode: chord = .noteCapture
        case KeyChord.memoryCapture.keyCode: chord = .memoryCapture
        default: return
        }
        // Mask out unrelated flags (caps lock, numeric pad, etc.) before checking.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(chord.flags) else { return }
        // Reject if other primary modifiers are also held to avoid accidental matches.
        guard !flags.contains(.command), !flags.contains(.shift) else { return }

        dispatch(chord.action)
    }

    /// The one place an action becomes a callback.
    ///
    /// Both spellings funnel through here - the chord from the `NSEvent` monitor on the
    /// main thread, hold-then-tap from the event tap's own thread - so they cannot drift,
    /// and so the main-thread hop is stated once rather than per gesture.
    private func dispatch(_ action: ShortcutAction) {
        switch action {
        case .handsFree:
            DispatchQueue.main.async { self.onHandsFreeToggle() }
        case .noteCapture:
            DispatchQueue.main.async { self.onNoteCaptureToggle() }
        case .memoryCapture:
            DispatchQueue.main.async { self.onMemoryCaptureToggle() }
        }
    }

    deinit { stop() }
}
