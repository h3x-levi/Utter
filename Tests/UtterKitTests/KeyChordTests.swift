import Testing
import AppKit
import Carbon.HIToolbox
@testable import UtterKit

/// The two global chords, and the text Settings prints for them.
///
/// Worth pinning because the failure is silent in both directions: a card that names
/// a chord the monitor no longer matches is wrong with nothing to catch it, and the
/// glyphs are non-ASCII characters that are easy to get subtly wrong (⌥ Option vs ⌃
/// Control, or the modifiers in the wrong order).
@Suite("Key chords")
struct KeyChordTests {

    @Test("The note chord reads as ⌃⌥N")
    func noteCaptureText() {
        #expect(KeyChord.noteCapture.symbols == "\u{2303}\u{2325}N")
        #expect(KeyChord.noteCapture.spelled == "Control-Option-N")
    }

    @Test("The hands-free chord reads as ⌃⌥Space")
    func handsFreeText() {
        #expect(KeyChord.handsFree.symbols == "\u{2303}\u{2325}Space")
        #expect(KeyChord.handsFree.spelled == "Control-Option-Space")
    }

    @Test("The memory chord reads as ⌃⌥R")
    func memoryCaptureText() {
        #expect(KeyChord.memoryCapture.symbols == "\u{2303}\u{2325}R")
        #expect(KeyChord.memoryCapture.spelled == "Control-Option-R")
        #expect(KeyChord.memoryCapture.keycaps == ["\u{2303}", "\u{2325}", "R"])
    }

    @Test("Keycaps are one string per key")
    func keycapsSplitPerKey() {
        // `ShortcutHint` draws a chip per element, so a joined string would render as
        // one wide keycap reading "⌃⌥N" instead of the three keys to press.
        #expect(KeyChord.noteCapture.keycaps == ["\u{2303}", "\u{2325}", "N"])
    }

    @Test("Modifiers print in the order macOS uses, not the order they are declared")
    func canonicalModifierOrder() {
        let all = KeyChord(keyCode: UInt16(kVK_ANSI_K),
                           flags: [.command, .shift, .option, .control],
                           keyLabel: "K",
                           action: .handsFree)
        #expect(all.symbols == "\u{2303}\u{2325}\u{21E7}\u{2318}K")
        #expect(all.spelled == "Control-Option-Shift-Command-K")
    }

    @Test("Each chord's label describes the key code it is matched on")
    func labelsMatchTheirKeyCodes() {
        // The drift this type exists to prevent: changing `keyLabel` without the key
        // code (or the reverse) leaves Settings advertising a chord that does
        // something else, and nothing else in the app compares the two.
        #expect(KeyChord.handsFree.keyCode == UInt16(kVK_Space))
        #expect(KeyChord.handsFree.keyLabel == "Space")
        #expect(KeyChord.noteCapture.keyCode == UInt16(kVK_ANSI_N))
        #expect(KeyChord.noteCapture.keyLabel == "N")
        #expect(KeyChord.memoryCapture.keyCode == UInt16(kVK_ANSI_R))
        #expect(KeyChord.memoryCapture.keyLabel == "R")
    }

    @Test("Both chords require Control and Option and nothing else")
    func sharedModifiers() {
        // `KeyMonitor.handleKeyDown` rejects an event carrying Command or Shift, so a
        // chord that declared either could never fire.
        for chord in [KeyChord.handsFree, KeyChord.noteCapture, KeyChord.memoryCapture] {
            #expect(chord.flags == [.control, .option])
        }
    }

    @Test("The two chords are distinguishable by key code")
    func chordsAreDistinct() {
        // They share their modifiers, so the key code is the only thing separating
        // "start hands-free" from "dictate into a note".
        #expect(KeyChord.handsFree.keyCode != KeyChord.noteCapture.keyCode)
        #expect(KeyChord.memoryCapture.keyCode != KeyChord.handsFree.keyCode)
        #expect(KeyChord.memoryCapture.keyCode != KeyChord.noteCapture.keyCode)
    }
}

/// Hold the dictation hotkey, tap a key: the second spelling of a shortcut.
///
/// The rule is worth pinning because two of its cases are silent, user-visible bugs if
/// they regress - the tap consumes the key it acts on, so a wrong `pass`/`swallow`
/// either types a stray character into whatever has focus or eats a keystroke the user
/// meant for their app.
@Suite("Hold-then-tap")
struct HoldTapTests {

    @Test("Both spellings of a shortcut resolve to the same action")
    func spellingsAgree() {
        // The point of the whole change: ⌃⌥Space and hold-hotkey-then-Space are two
        // ways to say one thing, and `KeyMonitor.dispatch` switches on the action, so
        // if these two ever disagreed the gestures would do different things.
        #expect(HoldTap.handsFree.action == KeyChord.handsFree.action)
        #expect(HoldTap.binding(for: .handsFree)?.keyCode == KeyChord.handsFree.keyCode)
    }

    @Test("Each binding's label describes the key code it is matched on")
    func labelsMatchTheirKeyCodes() {
        #expect(HoldTap.handsFree.keyCode == UInt16(kVK_Space))
        #expect(HoldTap.handsFree.keyLabel == "Space")
    }

    @Test("Note capture has no hold-then-tap spelling")
    func noteCaptureIsChordOnly() {
        // Not an oversight: macOS owns Fn+N (symbolic hotkey 212, key code 45 + fn,
        // Show Notification Center - read from the live WindowServer table). A binding
        // here would fight the system, so ⌃⌥N stays the only route to a note.
        #expect(HoldTap.binding(for: .noteCapture) == nil)
        #expect(HoldTap.binding(forKeyCode: UInt16(kVK_ANSI_N)) == nil)
    }

    @Test("Memory capture has no hold-then-tap spelling")
    func memoryCaptureIsChordOnly() {
        #expect(HoldTap.binding(for: .memoryCapture) == nil)
        #expect(HoldTap.binding(forKeyCode: UInt16(kVK_ANSI_R)) == nil)
    }

    @Test("A bound key does nothing unless the hotkey is held")
    func passesWhenNotHeld() {
        // The most important case: Space has to keep typing spaces the rest of the time.
        #expect(HoldTap.outcome(keyCode: UInt16(kVK_Space),
                                isHotkeyHeld: false, isRepeat: false) == .pass)
    }

    @Test("Tapping the bound key while holding fires the action")
    func firesWhileHeld() {
        #expect(HoldTap.outcome(keyCode: UInt16(kVK_Space),
                                isHotkeyHeld: true, isRepeat: false) == .fire(.handsFree))
    }

    @Test("Auto-repeat is swallowed without firing again")
    func repeatSwallowedNotFired() {
        // Holding the key down would otherwise toggle hands-free on every repeat - the
        // same burst-of-chimes bug the chords guard against with `event.isARepeat` - and
        // returning `.pass` instead would leak the repeats into the frontmost app.
        #expect(HoldTap.outcome(keyCode: UInt16(kVK_Space),
                                isHotkeyHeld: true, isRepeat: true) == .swallow)
    }

    @Test("Unbound keys are never swallowed, even while the hotkey is held")
    func unboundKeysPassThrough() {
        for keyCode in [UInt16(kVK_ANSI_K), UInt16(kVK_ANSI_N), UInt16(kVK_Return)] {
            #expect(HoldTap.outcome(keyCode: keyCode,
                                    isHotkeyHeld: true, isRepeat: false) == .pass)
        }
    }

    @Test("The gesture prints with whichever hotkey is configured")
    func printsForTheConfiguredHotkey() {
        // Generalised over the hotkey rather than hardcoding Fn: the same binding has to
        // read correctly for a user who dictates on right Option.
        let fn = HotkeyOption.find(id: "fn").name
        #expect(HoldTap.handsFree.keycaps(holdKey: fn) == ["Fn", "Space"])
        #expect(HoldTap.handsFree.spelled(holdKey: fn) == "hold Fn, then Space")

        let rightOption = HotkeyOption.find(id: "rightOption").name
        #expect(HoldTap.handsFree.keycaps(holdKey: rightOption) == [rightOption, "Space"])
    }

    @Test("Hold-then-tap is unavailable until an event tap exists")
    func unavailableWithoutATap() {
        // Nothing in a test process installs one, so this documents the default the UI
        // depends on: no tap means the tapped key cannot be swallowed, so the Hotkey
        // card must not advertise the gesture at all.
        #expect(HoldTap.isAvailable == false)
    }
}
