import Testing
import AppKit
@testable import UtterKit

/// The pointer route into hands-free dictation, in the parts that are decisions rather
/// than drawing.
///
/// The pill is a `.nonactivatingPanel` and a hover cannot be simulated here, so the view
/// itself has to be watched on a real screen. What can be pinned is the pair of rules the
/// view is built out of - and they are the pair that fails silently:
///
///   * **which states offer the control**, because one offered where pressing it is
///     swallowed is a button that does nothing, and
///   * **who owns a press**, because the pill already had a 2-second press that opens the
///     Utter window and a window drag underneath it, and a new click target that quietly
///     ate either would be a regression nothing points at.
@Suite("Pill hover control")
struct PillHoverControlTests {

    /// Every state the pill can be in, so a new one cannot be added without a decision
    /// about the pointer route being made for it here.
    private static let allStates: [PillState] = [
        .preparing, .idle, .recording, .handsFree, .capturingNote, .capturingMemory,
        .processing(.transcribing), .processing(.rewriting), .processing(.typing),
        .notice("New note - keep talking"), .error("No speech detected"),
    ]

    // MARK: Where the control is offered

    @Test("The resting pill starts hands-free, a latched pill stops it")
    func offeredToStartAndToStop() {
        // Both directions, or the pointer route is one-way - which is how the missing
        // stop was reported. Every other exclusion is still a real one: `.preparing`
        // would promise dictation while the model loads, `.recording` would mean
        // "upgrade" (a third meaning a record button does not carry), `.capturingNote`
        // already says `⌃⌥N to finish`, and `.processing` is refused by
        // `toggleHandsFree` outright while a transcription is in flight.
        #expect(PillHoverControl.isOffered(in: .idle))
        #expect(PillHoverControl.isOffered(in: .handsFree))
        #expect(!PillHoverControl.stops(in: .idle))
        #expect(PillHoverControl.stops(in: .handsFree))
        for state in Self.allStates where state != .idle && state != .handsFree {
            #expect(!PillHoverControl.isOffered(in: state),
                    "\(state) should not offer the hands-free control")
        }
    }

    @Test("The control needs both a resting pill and a pointer inside it")
    func revealNeedsHoverAndIdle() {
        #expect(PillHoverControl.isRevealed(in: .idle, pointerInsidePill: true))
        // Not revealed on a resting pill nobody is pointing at: that is the pill's whole
        // job at rest - say "ready" and stay out of the way.
        #expect(!PillHoverControl.isRevealed(in: .idle, pointerInsidePill: false))
        #expect(PillHoverControl.isRevealed(in: .handsFree, pointerInsidePill: true))
        for state in Self.allStates where state != .idle && state != .handsFree {
            #expect(!PillHoverControl.isRevealed(in: state, pointerInsidePill: true),
                    "\(state) revealed the control on hover")
        }
    }

    // MARK: Who owns a press

    @Test("A press away from the control still opens Utter")
    func longPressStillOpensUtter() {
        // The existing gesture, unchanged. Everywhere on the pill except the lock itself, a
        // 2-second press does what it always did - and the window drag underneath it is
        // untouched, because nothing new consumes a mouse-down outside the control's own
        // 20pt circle.
        #expect(PillHoverControl.longPressOpensUtter(in: .idle, pointerOnControl: false))
    }

    @Test("A press on the control belongs to the control")
    func controlWinsThePress() {
        // The precedence rule, written down rather than left to SwiftUI's arbitration
        // between a `Button` and an ancestor's `onLongPressGesture`: holding the lock for
        // two seconds must not also open the Utter window.
        #expect(!PillHoverControl.longPressOpensUtter(in: .idle, pointerOnControl: true))
    }

    @Test("A hover flag left set cannot disable the long press")
    func staleHoverFlagIsHarmless() {
        // The bug this guard exists for, and the reason the rule reads the state at all.
        // A press changes the pill's state *under the pointer*, and SwiftUI is not obliged
        // to deliver an `onHover(false)` for a view it has just removed from the hierarchy.
        // A stale `true` would then suppress the long press for the rest of the session:
        // the pill would quietly stop opening Utter, with nothing on screen to suggest why.
        // Reading the state makes the stale flag inert.
        //
        // The two states that *do* offer the control are excluded, and not as a
        // convenience: there the flag is not stale, the control is on screen under the
        // pointer, and it is supposed to own the press. `suppressionImpliesTheControlIsVisible`
        // is the invariant that keeps those two facts from drifting apart.
        for state in Self.allStates where !PillHoverControl.isOffered(in: state) {
            #expect(PillHoverControl.longPressOpensUtter(in: state, pointerOnControl: true),
                    "a stale hover flag disabled the long press in \(state)")
        }
    }

    @Test("The press is only ever taken by a control that is on screen")
    func suppressionImpliesTheControlIsVisible() {
        // The invariant that ties the two rules together. The long press may only be
        // suppressed in a state where the control can actually be revealed - otherwise the
        // 2-second press would be surrendered to something the user cannot see or click,
        // and the gesture would simply be dead.
        for state in Self.allStates {
            for pointerOnControl in [true, false] {
                let suppressed = !PillHoverControl.longPressOpensUtter(
                    in: state, pointerOnControl: pointerOnControl
                )
                if suppressed {
                    #expect(PillHoverControl.isRevealed(in: state, pointerInsidePill: true),
                            "\(state) surrendered the press to a control it never shows")
                }
            }
        }
    }
}

/// The hover-grace that stops the bead fleeing the cursor across the pill->bead gap.
///
/// These model the exact interaction the user reported: hover the pill, the bead appears, then
/// move toward it - and the pointer spends a moment in the gap over neither surface. Without
/// grace the bead retracted there; these assert it does not. (`update` is mutating, so each call
/// is pulled into a `let` - the `#expect` macro cannot wrap a mutating call.)
@Suite("Hover reveal latch")
struct HoverRevealLatchTests {

    @Test("Crossing the gap toward the bead never drops the reveal")
    func transitKeepsItRevealed() {
        var latch = HoverRevealLatch()
        let onPill = latch.update(present: true, at: 0);        #expect(onPill)
        let enterGap = latch.update(present: false, at: 0);     #expect(enterGap)
        let midGap = latch.update(present: false, at: 0.05);    #expect(midGap)
        let reachBead = latch.update(present: true, at: 0.06);  #expect(reachBead)
    }

    @Test("Actually leaving retracts once the grace elapses")
    func leavingRetracts() {
        var latch = HoverRevealLatch()
        _ = latch.update(present: true, at: 0)
        let justLeft = latch.update(present: false, at: 0);                              #expect(justLeft)
        let nearlyUp = latch.update(present: false, at: HoverRevealLatch.grace - 0.01);  #expect(nearlyUp)
        let elapsed = latch.update(present: false, at: HoverRevealLatch.grace + 0.01);   #expect(!elapsed)
    }

    @Test("Grace is a reasonable window - not zero, not a lingering delay")
    func graceIsAReasonableWindow() {
        #expect(HoverRevealLatch.grace > 0.05)
        #expect(HoverRevealLatch.grace < 0.4)
    }

    @Test("A returning pointer re-arms the grace from scratch")
    func graceReArmsOnReturn() {
        var latch = HoverRevealLatch()
        _ = latch.update(present: true, at: 0)
        _ = latch.update(present: false, at: 0)      // hide scheduled for +grace
        _ = latch.update(present: true, at: 0.05)    // returned - cancels the schedule
        let reLeft = latch.update(present: false, at: 0.05);                             #expect(reLeft)
        let reNearly = latch.update(present: false, at: 0.05 + HoverRevealLatch.grace - 0.01); #expect(reNearly)
        let reElapsed = latch.update(present: false, at: 0.05 + HoverRevealLatch.grace + 0.01); #expect(!reElapsed)
    }
}
