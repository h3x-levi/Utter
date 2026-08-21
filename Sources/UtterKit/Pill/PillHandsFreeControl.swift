import SwiftUI

/// The pointer route into hands-free dictation: hover the resting pill, click the record
/// button that appears.
///
/// Until now both hands-free and note capture were chords and nothing else — discoverable
/// only from Settings, the status-item menu and onboarding. The pill was a read-only
/// indicator you could drag. This makes it a control, without taking anything away: the
/// chord still works from every state, and this offers the same thing to a pointer.
///
/// The rules live here, apart from the view, because they are the part that can be wrong
/// in a way nobody notices — a control offered in a state where pressing it does nothing,
/// or a long press that stops working because a hover flag was left set. A view cannot be
/// tested on this machine; arithmetic and predicates can.
enum PillHoverControl {

    /// Whether the pointer route is offered in `state` at all.
    ///
    /// Idle only, and every other state is a deliberate exclusion rather than an oversight:
    ///
    ///   * `.preparing` — the speech model is still loading. That state exists to say that
    ///     holding the hotkey now would queue behind the load rather than record, so a
    ///     button promising to start dictation would be the same lie in a different shape.
    ///   * `.recording` — `toggleHandsFree` *upgrades* a push-to-talk session here, which is
    ///     a third meaning ("keep this one going after I let go") and not one a record button
    ///     conveys. The hold is already in the user's hand; the chord or the hold-then-tap is
    ///     the honest route to upgrading it.
    ///   * `.capturingNote` — the card already carries its own `⌃⌥N to finish`, and the
    ///     capture is entered from the keyboard in the first place.
    ///   * `.processing` — `toggleHandsFree` refuses outright while a transcription is in
    ///     flight, so the press would be swallowed with no explanation.
    ///   * `.error`, `.notice` — transient, and the capsule is full of their text.
    /// `.handsFree` offers it too, as a **stop**. Leaving it out made the pointer route
    /// one-way: a user who started a latched recording by clicking had no way to end it by
    /// clicking, which is how this was reported. The earlier objection — that one glyph
    /// cannot mean start, latch and stop — was right, and the answer is two glyphs: a record
    /// ring to start, a stop square to end. That is how every recorder in existence reads,
    /// and `toggleHandsFree` is already the single entry point for both directions.
    static func isOffered(in state: PillState) -> Bool {
        state == .idle || state == .handsFree
    }

    /// What a press would do, which is the only thing that varies between the two states
    /// the control appears in.
    static func stops(in state: PillState) -> Bool {
        state == .handsFree
    }

    /// What the control is called, in the state it is being offered in.
    ///
    /// Beside the predicate it depends on, because the two text affordances had already
    /// drifted from it: the glyph switched to `stop.circle` in `.handsFree` while both the
    /// tooltip and the VoiceOver action still said "Start hands-free dictation" — on the one
    /// control whose entire purpose in that state is to end the recording. Threading the
    /// literal into two independent call sites is how that happened, so it lives here.
    static func actionName(in state: PillState) -> String {
        stops(in: state) ? "Stop hands-free dictation" : "Start hands-free dictation"
    }

    /// Whether the control is *always* shown in this state, rather than waiting for hover.
    ///
    /// True only while a hands-free session is latched. Starting hands-free is a discovery
    /// affordance — fine to reveal on hover, and the resting pill's job is to stay out of the
    /// way. Stopping one is a session control: the recording is running, the user needs to see
    /// how to end it, and hiding that behind hover meant the stop button "will not show up"
    /// until the pointer found the right part of the pill. Deliberately scoped to `.handsFree`
    /// alone so the idle pill is unchanged.
    static func isPersistent(in state: PillState) -> Bool {
        stops(in: state)
    }

    /// Whether the control is on screen right now.
    static func isRevealed(in state: PillState, pointerInsidePill: Bool) -> Bool {
        isOffered(in: state) && (isPersistent(in: state) || pointerInsidePill)
    }

    /// Whether a completed 2-second press should open the Utter window.
    ///
    /// This is the whole of the gesture-precedence rule, and it is written down rather than
    /// left to SwiftUI's arbitration between a `Button` and an ancestor's
    /// `onLongPressGesture`: **while the pointer is over the control, the control owns the
    /// press.** Everywhere else on the pill, the long press and the window drag behave
    /// exactly as they did.
    ///
    /// The `isOffered` guard is not redundant, and it is the reason this is a function of
    /// the state at all. `pointerOnControl` is view state that can outlive the control:
    /// pressing the control changes the pill's state to `.handsFree` *under the pointer*, and
    /// SwiftUI is not obliged to deliver an `onHover(false)` for a view that has just been
    /// removed from the hierarchy. A stale `true` would then suppress the long press
    /// forever — the pill would quietly stop opening Utter, with nothing on screen to
    /// suggest why. Reading the state as well makes a stale flag harmless.
    static func longPressOpensUtter(in state: PillState, pointerOnControl: Bool) -> Bool {
        guard isOffered(in: state) else { return true }
        return !pointerOnControl
    }
}

/// The record button the pointer route puts in the resting pill.
///
/// This was `lock.fill` — the same glyph the `.handsFree` state shows while a session is
/// latched — on the reasoning that the affordance becoming the indicator is self-explanatory
/// in retrospect. It did not land, and the reason is worth writing down: a padlock is a
/// *status*, and a padlock specifically reads as "locked" — closed, unavailable, not a thing
/// to press. It described the state the control produces instead of the action the control
/// performs, and the two are not interchangeable when one of them is a button.
///
/// `record.circle` instead. The concentric ring-and-dot is the most conventional "press this
/// to start recording" affordance there is, it reads as a control rather than a state
/// because that is the only thing it is ever used for, and it distinguishes cleanly from the
/// resting pill's own `mic` glyph — which *is* a status ("ready"), sitting right next to it.
///
/// The colour is `Tint.handsFree`, not the record metaphor's red: the amber says *which*
/// mode this starts, matching the tint the pill takes on once it is running, where red is
/// the app's push-to-talk recording colour and would promise the wrong gesture.
///
/// So the pair is now a control and a status rather than one glyph doing both jobs — press
/// `record.circle`, and `lock.fill` appears to tell you it latched. The `.handsFree`
/// indicator is deliberately unchanged: a lock is the right read for "latched", it just was
/// never the right read for "press me".
///
/// No text, by request. Nothing would fit anyway: a 28pt capsule holding a word plus a glyph
/// is the keycap chip the resting pill was deliberately stripped back from.
struct HandsFreeRevealButton: View {
    /// Whether this press ends a latched session rather than starting one.
    let stops: Bool
    /// How far out of the pill the bead has travelled, 0 (inscribed in the capsule's end) to
    /// 1 (at rest beside it).
    ///
    /// Drives the glyph, which is now the only thing this view draws. The bead's *body* belongs
    /// to `PillShellShape` — it is a lobe of the pill's own silhouette, so at 0 it is inscribed in
    /// the capsule's rounded end and contributes nothing, and on the way out the shell's single
    /// outline necks and stretches. This view never fades a glass body in, because there is no
    /// second glass body to fade: that was what read as a bead materialising beside the pill.
    ///
    /// The glyph still has to be hidden while the lobe is inside the capsule, or a record ring
    /// would sit on the capsule's face at rest.
    let emergence: Double
    let action: () -> Void
    /// Reported upward so `PillContainerView` can hand the press to this control rather than to
    /// the long press it sits inside. See `PillHoverControl.longPressOpensUtter`.
    let onHoverChanged: (Bool) -> Void

    @ObservedObject private var motion = MotionPreference.shared
    @State private var isHovering = false

    /// The full button, matching `PillMetrics.handsFreeButtonSide`.
    ///
    /// It was 20pt when it sat *inside* the capsule and had to leave the shell room. It is
    /// now a bead of the pill's own body, so it is sized as one — and 26 against the capsule's
    /// 28 is what lets it sit exactly inscribed in the rounded end when tucked.
    private static let side: CGFloat = PillMetrics.handsFreeButtonSide

    var body: some View {
        Button(action: action) {
            // 13pt against the 11 the lock used. `record.circle`'s meaning is carried by the
            // gap between its ring and its dot, and at 11pt that gap is under a point — it
            // closes up into a blob that could be any filled circle.
            //
            // A bare glyph, and that is the whole of it now.
            //
            // This view used to carry its own `glassSurface(in: Circle())` and its own
            // `Circle().strokeBorder`, and both are deleted rather than suppressed. Two glass
            // bodies cannot be stroked as one object: during the merge the viewer saw two fully
            // outlined objects overlapping — the fields blending underneath while two hard rings
            // slid through each other, which reads as two stickers, not one liquid. And the
            // fallbacks were worse, not better: with no `GlassEffectContainer` before macOS 26 or
            // under Reduce Transparency the ring came *back*, so the three configurations with no
            // merge to hide it got the rejected "a button travels out of the pill" read
            // permanently.
            //
            // `PillShellShape` draws the bead as a lobe of the pill's own silhouette instead, so
            // there is one glass body and one outline on every configuration, and this is a glyph
            // riding on a bead the shell has already drawn. Hover no longer tints a surface of its
            // own — it brightens the glyph, which is the only thing here to brighten.
            Image(systemName: stops ? "stop.circle" : "record.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Tint.handsFree.opacity(isHovering ? 1 : 0.82))
                // Only the glyph fades. See `emergence`.
                .opacity(emergence)
                .frame(width: Self.side, height: Self.side)
                // Exactly the artwork, and no more.
                //
                // `GlassIconButton` extends its hit region to the HIG's 44pt; that would be
                // wrong here. The bead sits `handsFreeButtonGap` from a capsule that is itself
                // long-pressable, so a hit region larger than the artwork would reach back over
                // the pill and start eating presses meant for it.
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            onHoverChanged(hovering)
        }
        .help(stops ? "Stop hands-free dictation" : "Start hands-free dictation")
        // The pill as a whole is one accessibility element (`children: .ignore`), so this
        // label is not what VoiceOver reads — `PillContent` exposes the same action on the
        // element itself, which is also the only way a hover-revealed control can be
        // reached without a pointer.
        .accessibilityHidden(true)
        .animation(motion.reduceMotion ? nil : (isHovering ? Motion.hoverIn : Motion.hoverOut),
                   value: isHovering)
    }
}

/// Attaches the hands-free action to the pill's accessibility element, or doesn't.
///
/// A modifier rather than a conditional in the chain because the choice has to be *absent*,
/// not inert: an action VoiceOver announces and then swallows is worse than no action, and
/// `accessibilityAction` has no "disabled" form.
struct HandsFreeAccessibilityAction: ViewModifier {
    let start: (() -> Void)?
    /// From `PillHoverControl.actionName(in:)` — the same wording the tooltip uses.
    let name: String

    func body(content: Content) -> some View {
        if let start {
            content.accessibilityAction(named: Text(name), start)
        } else {
            content
        }
    }
}

/// Keeps the hands-free bead revealed while the pointer crosses the gap between the pill and the
/// bead.
///
/// The reveal is `pointer over the pill OR over the bead`. Between them sits
/// `PillMetrics.handsFreeButtonGap`, which is over *neither* — so a pointer travelling from the
/// pill toward the bead spends a frame or two in that gap with both flags false. Driven directly,
/// the bead retracted the instant that happened and `allowsHitTesting` turned off with it, so the
/// bead pulled back and stopped accepting the very hover that would bring it out: it appeared to
/// flee the cursor. This is the standard hover-gap / "safe transit" problem, and the standard fix
/// is hysteresis — once revealed, survive a brief absence, long enough to cross a few points of
/// gap and no longer.
///
/// Pure and clock-injected so the transit case is a test rather than something only the eye can
/// judge: feed present→absent→present within the grace and assert it never dropped.
struct HoverRevealLatch {
    /// How long the reveal outlives the pointer leaving both surfaces.
    ///
    /// **Was 120ms, and that was too short in practice.** The old reasoning measured the wrong
    /// thing: it reasoned about the *distance* ("the gap is 6pt; a pointer crosses it in well under
    /// this") when what has to fit inside the window is the *event round trip* — leaving the
    /// capsule's `contentShape`, crossing, entering the button's frame, and SwiftUI delivering
    /// `onHover(true)` for it. 120ms is about seven frames, and any deliberate, unhurried movement
    /// of the pointer overruns it. When it overran, the bead retracted and `allowsHitTesting` went
    /// with it — so it stopped accepting the hover that would bring it back, and sitting on it did
    /// nothing. Reported as: "if I move over to the hands-free button to click it goes back inside."
    ///
    /// 350ms covers an unhurried transit with room to spare, and is still short enough that a bead
    /// left behind by a pointer that has genuinely gone reads as settling rather than as sticking.
    /// It is the timeout half of the fix; the reason a timeout is needed at all is that the gap
    /// belongs to neither surface, which is the standard hover-gap problem.
    static let grace: TimeInterval = 0.35

    private var revealed = false
    private var hideAt: TimeInterval?

    /// Fold in the current pointer presence at time `now`; returns whether the bead should show.
    mutating func update(present: Bool, at now: TimeInterval) -> Bool {
        if present {
            revealed = true
            hideAt = nil
        } else if revealed {
            if let deadline = hideAt {
                if now >= deadline {
                    revealed = false
                    hideAt = nil
                }
            } else {
                hideAt = now + Self.grace
            }
        }
        return revealed
    }
}
