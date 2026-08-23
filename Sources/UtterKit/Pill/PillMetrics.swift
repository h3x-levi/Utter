import SwiftUI
import AppKit

/// The pill's geometry, in one place, because the window and the content have to agree.
///
/// Every state has two sizes: the **shell** — the glass object the user sees — and the
/// **window** hosting it, which is larger and transparent. That was harmless while the
/// shell was always 28pt tall inside a fixed 60pt panel, and it stopped being harmless
/// the moment note capture grew a 124pt box: SwiftUI lays the box out *inside* the
/// panel, so a panel left at the resting size clips it. Both sizes are derived from the
/// same numbers here rather than kept in step by hand.
enum PillMetrics {
    /// The capsule's height — every state except note capture.
    static let capsuleHeight: CGFloat = 28

    /// The hands-free control's diameter, and the gap between it and the capsule.
    ///
    /// It is drawn *outside* the pill — a separate circular button that appears beside the
    /// capsule on hover rather than inside it. That is what keeps the resting pill a plain
    /// centred microphone: putting the button in the row shifted the mic off centre and
    /// changed the capsule's width, which read as the pill moving under the pointer.
    static let handsFreeButtonSide: CGFloat = 26
    static let handsFreeButtonGap: CGFloat = 6

    /// How far the hit region has to extend past the capsule to cover that button.
    static var handsFreeButtonReach: CGFloat { handsFreeButtonGap + handsFreeButtonSide }

    /// The resting capsule's floor width. Its content is only ~33pt intrinsically; 56 holds
    /// a 2:1 capsule at rest and gives the hands-free control room to appear without the
    /// pill visibly growing. Named because the hit-test region needs the same number.
    static let minimumCapsuleWidth: CGFloat = 56

    /// Transparent padding above and below the shell, inside the window.
    ///
    /// The pill's content is anchored to the *bottom* of its window (see
    /// `PillContainerView`), so this is the gap `PillWindow` has to subtract when it
    /// positions the pill by window origin. 16pt, which is exactly what `(60 - 28) / 2`
    /// came to while the window was a fixed 60pt with the capsule centred in it — so
    /// the resting pill sits where it always has, to the point.
    static let verticalInset: CGFloat = 16

    /// Padding between the shell's edge and its content, horizontally.
    static let horizontalPadding: CGFloat = Space.x2 + 2

    /// How wide a `.notice` or `.error` message may draw before it truncates.
    ///
    /// These are the only two states whose text comes from arbitrary failures, and they had no cap at
    /// all: a long reason drew the shell wider than the panel that holds it, so it lost its rounded
    /// ends to the clip and left a full-width strip across the bottom of the screen taking clicks.
    /// The glyph, both paddings and the panel's own margin come out of the 320pt, leaving this.
    static let messageWidth: CGFloat = 240

    /// The window's width. Fixed, and the note box has to fit inside it — see
    /// `noteContentWidth`, and the test that holds the two together.
    static let windowWidth: CGFloat = 320

    /// The note box's height.
    ///
    /// Enough for a destination line, three lines of live transcript, and a footer
    /// carrying the level meter — measured against the 12pt caption face those use, with
    /// a few points of slack because system font metrics are not ours to promise. It is
    /// a fixed height rather than one that follows the transcript: text arrives every
    /// second or so while dictating, and a box that regrew on each pass would be a
    /// twitching window rather than a card being filled in.
    static let noteBoxHeight: CGFloat = 124

    /// The width of the note box's *content*, inside `horizontalPadding`.
    static let noteContentWidth: CGFloat = 272

    /// The shell's corner radius.
    ///
    /// One constant covers both shapes because `PillShape` clamps it to half the shorter
    /// side: at the capsule's 28pt height that is 14, which draws a true capsule, and at
    /// the note box's 124pt the full 16 comes through as a card. So the silhouette
    /// follows the height animation instead of being animated separately on a curve of
    /// its own — one moving quantity, not two that can disagree mid-morph.
    static let cornerRadius: CGFloat = Radius.panel

    /// The shell's height for a state. The only state that is not a capsule is note
    /// capture, which is the whole point of the box.
    static func shellHeight(for state: PillState) -> CGFloat {
        state == .capturingNote ? noteBoxHeight : capsuleHeight
    }

    /// The shell's width for a state, or `nil` when the state's *content* decides it.
    ///
    /// The counterpart of `shellHeight(for:)`, and the reason the morph is now one event
    /// rather than two. Both are read by `ShellSize`, which interpolates them as a single
    /// `AnimatablePair` — so a state whose width is a number here grows on exactly the
    /// mechanism its height grows on. A state whose width is `nil` falls back to the last
    /// measured content width, which lands a layout pass later and therefore *cannot*
    /// interpolate inside the transaction that changed the state.
    ///
    /// **That is why the split is by content and not by taste.** A width can be a constant
    /// only when the state's content is a fixed set of glyphs:
    ///
    ///   * `.capturingNote` — `NoteCaptureBox` pins itself to `noteContentWidth`, so the
    ///     shell is that plus the padding every state gets. This is the one that matters:
    ///     it is the far endpoint of the morph, and it was the value stepping 56 -> 292 in
    ///     one layout pass that made the pill snap wide before it grew tall.
    ///   * `.idle` — a `mic` glyph, intrinsically ~33pt, so `minimumCapsuleWidth` decides it
    ///     outright and no font metric can move it.
    ///   * `.processing` — `WritingPen` is an explicit square frame (23pt: a 10pt glyph box plus
    ///     its scribble envelope), so `minimumCapsuleWidth` decides that one too. It was 28x14
    ///     while the pen was paired with a drawn line; the line is gone and the frame shrank.
    ///
    /// and `nil` for the four that carry text of a length nothing here can know:
    /// `.recording`/`.handsFree` grow with the level meter and a live transcript,
    /// `.notice`/`.error` with their message, and `.preparing` with a localised string whose
    /// rendered width is the font's business, not ours.
    ///
    /// **The states that are actually morph endpoints are all in the first group**, which is
    /// what makes the fallback's one-pass lag harmless in practice rather than in theory:
    /// `.capturingNote` is entered from `.idle`, `.recording` and `.handsFree`, and left only
    /// for `.processing(.transcribing)` (`AppDelegate.stopRecording`) or `.idle`. Entering is
    /// safe from a measured state — the pill already *has* that width, settled, from the
    /// previous pass. Leaving is the direction that needs the destination's width up front,
    /// and both destinations have one. `PillMorphTests` pins that list, because a future
    /// `setState` from the card into a text-carrying state would hold the card's 292pt through
    /// the whole shrink and then snap, and nothing else would catch it.
    static func shellWidth(for state: PillState) -> CGFloat? {
        switch state {
        case .capturingNote: return noteContentWidth + horizontalPadding * 2
        case .idle, .processing: return minimumCapsuleWidth
        case .preparing, .recording, .handsFree, .notice, .error: return nil
        }
    }

    /// The shell's width for a state, resolved against the last measured content width.
    ///
    /// The one expression, so the drawn shell (`PillContent`), the bead's glyph
    /// (`PillContainerView`) and the hit region (`PillWindow.drawnShellRect`) cannot come to
    /// three different answers about where the pill ends. Two answers to one question is what
    /// made the stop button visible and inert; see `drawnShellRect`.
    /// The narrowest a state may draw, before its content has been measured.
    ///
    /// **This is what stops the pill widening in two steps when you start dictating.** The four
    /// content-driven states resolve their width from `capsuleWidth`, which `idealWidthProbe`
    /// publishes one layout pass *after* the state changes — so on the frame the hotkey is pressed the
    /// shell is still the 56pt resting width while the content inside it is already a dot, a meter and
    /// a timer. It drew narrow, then jumped to the real width a pass later, which reads as the pill
    /// stretching open rather than simply being the right size.
    ///
    /// A floor fixes it without freezing the width: frame one is at least this wide, so nothing is
    /// clipped and nothing jumps, and the live transcript can still grow the pill past it as words
    /// arrive. Sized from the row rather than guessed — `horizontalPadding` at both ends, the 8pt dot,
    /// `Space.x2` either side of the meter, the meter's seven 3pt bars with 2.5pt between them, and
    /// room for the m:ss timer; `.handsFree` adds the lock glyph and its gap.
    static func widthFloor(for state: PillState) -> CGFloat {
        let meter = CGFloat(LevelMeter.barCount) * 3 + CGFloat(LevelMeter.barCount - 1) * 2.5
        let row = horizontalPadding * 2 + 8 + Space.x2 + meter + Space.x2 + 30
        switch state {
        case .recording: return row
        case .handsFree: return row + 10 + Space.x2
        default: return minimumCapsuleWidth
        }
    }

    /// Capped at the panel, because two of the measured states carry text of unbounded length.
    ///
    /// `.error` and `.notice` draw a single line with no `maxWidth` (unlike the live transcript,
    /// which caps at 190), and their messages come from arbitrary failures. Past roughly 300pt the
    /// shell was drawn wider than the 320pt panel: clipped at both ends so it lost its rounded caps,
    /// and `PillWindow.drawnShellRect` clamped to the full panel width, leaving a 320x28 strip across
    /// the bottom of the screen eating desktop clicks for as long as the message showed.
    ///
    /// Capped here rather than at each `Text`, because this is the one expression the drawn shell,
    /// the bead's glyph and the hit region all read — a cap at one call site would be a cap the other
    /// two disagree with.
    static func shellWidth(for state: PillState, measured: CGFloat) -> CGFloat {
        let floor = max(measured, widthFloor(for: state))
        return shellWidth(for: state) ?? min(floor, windowWidth - verticalInset * 2)
    }

    /// The window's height. One number, for every state.
    ///
    /// Tall enough for the note card at all times, and deliberately NOT resized per state.
    /// The panel used to grow 60 -> 156 on the way into note capture and shrink back 0.45s
    /// after leaving it, and that resize was the cause of the morph looking "jittery, just
    /// very fast" on the way in while looking correct on the way out:
    ///
    ///   * The grow had to happen *before* the content or a 60pt panel simply clipped the
    ///     124pt card, so it sat on the open direction's critical path. The shrink could
    ///     happen *after*, so it sat entirely outside the close direction's. One-sided by
    ///     construction, which is why only one direction looked wrong.
    ///   * `setFrame(display: true)` forces a synchronous layout and display of the whole
    ///     hosting view. Deferring the animation by a `DispatchQueue.main.async` did not buy
    ///     the resize its own presented frame — measured with a CFRunLoopObserver, the
    ///     deferred block ran ~0.5ms later with *no* CA commit in between — so the spring's
    ///     first frames were still being computed across a relayout and were dropped. A
    ///     time-based spring that loses its first frames then presents already part-way
    ///     through, which is exactly "very fast".
    ///   * The same `setFrame` inside a display cycle is what threw
    ///     `-[NSWindow _postWindowNeedsUpdateConstraints]` and killed 2.0.84.
    ///
    /// A fixed height deletes all three at once: there is no resize to sequence against, to
    /// drop frames for, or to crash inside. It costs 96pt of extra transparent panel above
    /// the capsule, which is free — nothing is drawn there, and `ShapedHostingView.hitTest`
    /// already nils every point outside `PillWindow.drawnShellRect`, so it takes no clicks.
    ///
    /// The capsule does not move as a result. The content is bottom-anchored, so at both the
    /// old 60pt and this 156pt the capsule's centre is `verticalInset + capsuleHeight / 2`
    /// = 30pt above the window's bottom edge.
    static let windowHeight: CGFloat = noteBoxHeight + verticalInset * 2

    /// The shell's bottom edge, as a `UnitPoint.y` within the panel — the anchor the settle scales
    /// about.
    ///
    /// Not `1.0`. The panel carries `verticalInset` of transparent padding below the shell, so
    /// scaling about the panel's own bottom would scale that padding too and drop the pill by
    /// `verticalInset * (1 - scale)` — 1.6pt at a 0.90 settle, which reads as the pill dipping into
    /// the Dock and climbing back out. This puts the fixed point on the shell's own bottom edge,
    /// which is the one edge that must not move.
    static var shellBottomAnchorY: CGFloat { (windowHeight - verticalInset) / windowHeight }

    /// How far the capsule's centre sits above the window's bottom edge.
    ///
    /// Published as a constant because a second window has to find the pill's eye line, and
    /// `frame.midY` is not it: the content is bottom-anchored, so the window's midline
    /// coincided with the capsule's centre only at the old 60pt resting height. At 156pt
    /// they are 48pt apart. `CompanionWindow.placeBesidePill` reads this.
    static let capsuleCentreAboveBottom: CGFloat = verticalInset + capsuleHeight / 2

    /// The radius of the concave arc that necks the capsule into the hands-free bead.
    ///
    /// **The calibration knob.** It is the one number in this file whose right value can only
    /// be judged by looking at it, so everything else about the neck is derived from it rather
    /// than tuned beside it.
    ///
    /// This replaced `glassBlendSpacing`, which was `GlassEffectContainer(spacing:)` — the
    /// proximity blend between two sibling glass bodies. That approach produced the liquid
    /// read on exactly one of the four render configurations (macOS 26 with transparency on)
    /// and two separate outlined objects on the other three, and its merged silhouette has no
    /// `Path`, so nothing could stroke it: the pill's outer contrast ring is load-bearing (see
    /// `PillContent`), and two rings sliding through each other is the failure it was meant to
    /// avoid. `PillShellShape` puts the bead in the pill's *own* silhouette instead, so one
    /// shape feeds `glassEffect(in:)`, both strokes and the shadow on all four configurations.
    ///
    /// The geometry it is chosen against, all of it fixed regardless of capsule width:
    ///
    ///   * tucked, the bead is *inscribed* in the capsule's rounded end. Its centre sits
    ///     `handsFreeButtonSide / 2` = 13pt in from the capsule's trailing edge, and the
    ///     capsule's end is a semicircle of radius `capsuleHeight / 2` = 14 whose centre is
    ///     14pt in — so the centres are 1pt apart and 1 + 13 == 14 exactly. The bead is
    ///     inside the capsule's silhouette, touching it, contributing nothing to it.
    ///   * travel is `handsFreeButtonGap + handsFreeButtonSide` = 32pt, and at rest the two
    ///     edges are `handsFreeButtonGap` = 6pt apart.
    ///
    /// 2pt puts the pinch at `neckPinchDistance` = 30.74pt of the 33pt centre separation, i.e.
    /// the neck survives 29.74 of the 32pt of travel (92.9%, measured) and then lets go,
    /// leaving the bead a separate object at rest with 6pt of clear air. That is what was
    /// asked for: "I don't want the button to be attached to the main pill, it disconnect and
    /// then merge back to the pill." It also lands within 0.6pt of where the old 4pt
    /// `glassBlendSpacing` pinched, so the look this was already calibrated to is preserved.
    ///
    /// **Raising it to 3 was tried and reverted, and the arithmetic is worth keeping.** The case for
    /// 3 was that 2 breaks the bridge with only 3.74pt of the final 6pt gap open (62.3%), so the
    /// thread appears to vanish with a third of the journey still to run. True — but it optimises the
    /// wrong quantity, because it ignores how *thick* the bridge is at the moment it goes:
    ///
    ///     fillet 2 -> breaks at extrusion 0.929 with a **1.86pt** thread, gone in ~3ms of a 300ms reveal
    ///     fillet 3 -> breaks at extrusion 0.983 with a **6.74pt** thread, gone in ~19ms
    ///
    /// A 6.74pt bridge disappearing is a far more visible pop than a 1.86pt one, so 3 trades a small
    /// early release for a large late one. The invariant that actually matters is the one
    /// `PillShellShapeTests` already pins — the neck must be *nearly gone* before it lets go — and 2
    /// satisfies it. Raise this only with eyes on the result.
    static let neckFillet: CGFloat = 2

    /// Where the hands-free bead's centre sits along the extrusion, measured from the
    /// capsule's trailing edge. Negative is inside the capsule.
    ///
    /// The single source of truth for where the lobe is, read by `PillShellShape` (which draws
    /// it) and by `PillContainerView` (which puts the glyph on it). Two answers is what put a
    /// record ring a point off its own bead in an earlier pass.
    ///
    /// Linear in `extrusion`, deliberately: SwiftUI animates the shape's `extrusion` and the
    /// glyph's `offset(x:)` as separate quantities, and a linear map is the only one for which
    /// interpolating either gives the same position at every frame.
    ///
    /// **The travel shortens on a wide pill, and past a point the bead stops detaching.**
    /// `handsFreeButtonCentreX` clamps the resting position to the panel's edge, so the bead's
    /// journey is 32pt only while it is unclamped. Working it out: the centres are 1pt apart when
    /// tucked, so the resting separation is `1 + travel` = `161 - capsuleWidth / 2` once clamped,
    /// and the neck lets go at `neckPinchDistance` = 30.74pt — which needs
    /// `capsuleWidth <= 260.5`. Above that the bead settles while still joined and reads as a
    /// permanent lobe rather than a separate object. That is the same trade the clamp already
    /// makes today (an overlapping button that stays whole and clickable beats a clipped one), it
    /// only shows up as a neck now instead of an overlap, and it only happens in `.handsFree` with
    /// a long live transcript.
    static func lobeCentreOffset(extrusion: CGFloat, capsuleWidth: CGFloat) -> CGFloat {
        // Inscribed in the capsule's rounded end: the bead's centre is its own radius in from
        // the trailing edge, which is exactly internal tangency (see `neckFillet`).
        let tucked = -handsFreeButtonSide / 2
        // At rest, wherever the panel allows the button to sit — the same clamp the glyph uses.
        let rest = handsFreeButtonCentreX(capsuleWidth: capsuleWidth) - capsuleWidth / 2
        return tucked + (rest - tucked) * min(max(extrusion, 0), 1)
    }

    /// The full width of the shell including the bead at rest.
    ///
    /// What the glass, the strokes and the shadow have to be sized to, and 32pt more than the
    /// capsule only while the bead is unclamped. Derived from `handsFreeButtonCentreX` rather
    /// than `+ handsFreeButtonReach` so the two cannot disagree at the wide end, where the
    /// clamp pulls the bead back inward: at the widest `.handsFree` row (~277pt) the naive sum
    /// would claim 309pt of shell against 298.5pt actually drawn, and the extra 10.5pt would
    /// be shadow and hit region hanging off the panel's edge.
    ///
    /// Named for the bead rather than left as `shellWidth(capsuleWidth:)` now that
    /// `shellWidth(for:measured:)` exists: the two answer different questions — this one adds
    /// the bead, that one *produces* the capsule width this consumes — and one label away from
    /// each other in the same enum is a mistake waiting to be made. The composition reads
    /// `shellWidthWithBead(capsuleWidth: shellWidth(for: state, measured:))`.
    static func shellWidthWithBead(capsuleWidth: CGFloat) -> CGFloat {
        capsuleWidth / 2 + handsFreeButtonCentreX(capsuleWidth: capsuleWidth)
            + handsFreeButtonSide / 2
    }

    /// The offset of the neck's fillet centre from the capsule's end-arc centre — `x` along
    /// the line joining the two circles, `y` perpendicular to it — or `nil` once the neck has
    /// pinched off.
    ///
    /// A circle of radius `rF` tangent to both circles from outside has its centre at distance
    /// `rA + rF` from one and `rB + rF` from the other, which is one circle-circle
    /// intersection. `nil` when the two solutions have collapsed to within `rF` of the axis:
    /// the neck's full width is `2 * (h - rF)` because each concave arc eats `rF` of the
    /// offset, so at `h <= rF` the two arcs have crossed and there is no bridge left to draw.
    static func neckArcOffset(distance d: CGFloat, rA: CGFloat, rB: CGFloat,
                              fillet rF: CGFloat) -> CGPoint? {
        let r1 = rA + rF, r2 = rB + rF
        guard d > 0, d <= r1 + r2, d >= abs(r1 - r2) else { return nil }
        let x = (d * d - r2 * r2 + r1 * r1) / (2 * d)
        let h2 = r1 * r1 - x * x
        guard h2 > rF * rF else { return nil }
        return CGPoint(x: x, y: h2.squareRoot())
    }

    /// The centre separation at which the neck pinches off, in closed form.
    ///
    /// Substituting the pinch condition `h == fillet` into the intersection above gives
    /// `x = sqrt(rA * (rA + 2 * fillet))` and `d - x = sqrt(rB * (rB + 2 * fillet))`, so the
    /// distance is their sum. With the pill's numbers — `rA` 14, `rB` 13, `fillet` 2 —
    /// sqrt(14 * 18) + sqrt(13 * 17) = 15.874 + 14.866 = **30.740pt**, against a 33pt resting
    /// separation: an edge gap of 3.74pt, so the bead detaches 3.74pt before it settles.
    ///
    /// Published so the pinch can be asserted rather than eyeballed — the value that decides
    /// whether the bead detaches at all is worth a test, and `neckArcOffset` returning `nil`
    /// is otherwise only observable by rendering.
    static func neckPinchDistance(rA: CGFloat, rB: CGFloat, fillet: CGFloat) -> CGFloat {
        (rA * (rA + 2 * fillet)).squareRoot() + (rB * (rB + 2 * fillet)).squareRoot()
    }

    /// Where the hands-free button's centre sits, measured from the panel's centre.
    ///
    /// Clamped, because the ideal position runs off the panel. The button wants to sit clear
    /// of the capsule's trailing edge by `handsFreeButtonGap`, but the capsule's width is
    /// content-driven and the panel's is fixed: in `.handsFree` with a live preview the row
    /// reaches roughly 277pt (padding 10 + dot 8 + 8 + meter 25 + 8 + preview up to 190 + 8 +
    /// glyph 10 + padding 10), which puts the button's right edge at 277/2 + 6 + 26 = 170.5
    /// from centre — 10.5pt past the 160pt half-panel. The one control that ends a latched
    /// recording was being clipped in half exactly when the pill was busiest.
    ///
    /// So it slides inward instead of off the edge. Overlapping the capsule slightly is the
    /// right failure: the button stays whole and clickable, which is what it is for.
    static func handsFreeButtonCentreX(capsuleWidth: CGFloat) -> CGFloat {
        let clear = capsuleWidth / 2 + handsFreeButtonGap + handsFreeButtonSide / 2
        let edge = windowWidth / 2 - handsFreeButtonSide / 2
        return min(clear, edge)
    }

    /// Whether a state draws something other than a capsule — today, only note capture.
    ///
    /// The predicate rather than `state == .capturingNote` at the call sites, so a future
    /// state that grows the shell inherits everything keyed off this (the window resize
    /// derives from `shellHeight`; `CompanionWindow.noteCardDrawsCharacter` decides the
    /// companion handover from this) instead of needing to be added to a list somebody has
    /// to remember.
    static func isExpanded(_ state: PillState) -> Bool {
        shellHeight(for: state) > capsuleHeight
    }

}

/// The pill's silhouette: a rounded rectangle that *is* a capsule whenever it is no
/// taller than it is round.
///
/// One shape for both states is what makes this a morph rather than a cross-fade
/// between a capsule and a card — the glass, the border and the frame stay a single
/// view whose size animates. `Path(roundedRect:cornerRadius:)` draws circular corner
/// arcs, so at a radius of half the height the two ends meet as semicircles and the
/// result is the same silhouette `Capsule` drew here before.
struct PillShape: InsettableShape {
    var cornerRadius: CGFloat = PillMetrics.cornerRadius
    /// Accumulated by `inset(by:)`, which is how `strokeBorder` asks a shape to sit
    /// inside its own edge.
    private var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: inset, dy: inset)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        // Concentric with the uninset shape, and never more than half the shorter side:
        // a larger radius draws a self-intersecting path, and the height passes through
        // every value between the capsule's and the box's on the way.
        let radius = min(cornerRadius - inset, min(bounds.width, bounds.height) / 2)
        return Path(roundedRect: bounds, cornerRadius: max(radius, 0))
    }

    func inset(by amount: CGFloat) -> PillShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

/// The pill's silhouette *including* the hands-free bead, as one shape.
///
/// **Why a shape and not `GlassEffectContainer`.** The container is the platform's proximity
/// blend and it genuinely does the metaball merge, but its blended silhouette is not something
/// you can obtain a `Path` for — so it cannot be stroked. The pill's outer contrast ring is
/// load-bearing (`PillContent` records that without it the pill "dissolves against busy or
/// mid-toned backdrops and reads as a translucent smudge"), which leaves only two options with
/// the container: one stroke per body, which is two fully outlined objects sliding through each
/// other, or no stroke at all. `Path.union` is no escape either — it is macOS 14.0 and the
/// package floor is 13.3. And the container is a plain passthrough before macOS 26 *and* under
/// Reduce Transparency, so it produced the liquid read on one of four render configurations and
/// two separate objects on the other three.
///
/// Putting the bead in the pill's own silhouette answers all of that at once: one `Path` feeds
/// `glassEffect(in:)`, both `strokeBorder`s, the clip and the shadow, on every configuration.
/// What is given up is the outward *bulge* Apple's field produces mid-merge — this necks by
/// geometry, not surface tension. `PillMetrics.neckFillet` is the knob for that.
///
/// **The path is one closed contour while the bead is joined, and two while it is detached.**
/// That distinction is the whole point and it is not cosmetic: `strokeBorder` is
/// `inset(by:).stroke(...)`, and `stroke` strokes *every* subpath — so a shape assembled as
/// rounded-rect + circle + neck-patch would ink the capsule's buried trailing arc, the lobe's
/// buried arc and both neck chords as well, five or six outlines where the fill shows one.
/// Verified rather than assumed: stroking this shape and probing its centre line inks exactly
/// two spans at every extrusion up to the pinch, and four after it (two objects, one outline
/// each, which is what "it disconnect and then merge back" asks for). See `PillShellShapeTests`.
///
/// The lobe is only drawn when the shell's trailing end is a true semicircle — the whole neck
/// derivation models it as a circle of radius `height / 2`, which `Path(roundedRect:)` only
/// draws while the corner radius reaches that far. So the 124pt note card gets the plain shell
/// automatically, rather than a bulge at its mid-height right edge for the ~300ms an extrusion
/// takes to collapse.
struct PillShellShape: InsettableShape {
    /// How far the bead has come out of the pill: 0 is inscribed in the capsule's end and
    /// contributing nothing to the silhouette, 1 is at rest beside it.
    var extrusion: CGFloat = 0
    /// The capsule's own width.
    ///
    /// Passed rather than read from `rect`, because the rect this is drawn in is deliberately
    /// wider — `PillMetrics.shellWidthWithBead(capsuleWidth:)` — so the lobe has room to grow into the
    /// transparent panel without moving the capsule. That regression is on the record: giving
    /// the button a slot inside the capsule shifted the microphone off centre.
    var capsuleWidth: CGFloat
    var cornerRadius: CGFloat = PillMetrics.cornerRadius
    /// See `PillMetrics.neckFillet`. A look, so a parameter rather than an invariant.
    var fillet: CGFloat = PillMetrics.neckFillet
    /// Accumulated by `inset(by:)`, which is how `strokeBorder` asks a shape to sit inside its
    /// own edge.
    private var insetAmount: CGFloat = 0

    init(extrusion: CGFloat = 0,
         capsuleWidth: CGFloat,
         cornerRadius: CGFloat = PillMetrics.cornerRadius,
         fillet: CGFloat = PillMetrics.neckFillet) {
        self.extrusion = extrusion
        self.capsuleWidth = capsuleWidth
        self.cornerRadius = cornerRadius
        self.fillet = fillet
    }

    /// Both quantities animate, and they are paired so they cannot desynchronise.
    ///
    /// `extrusion` moves on hover; `capsuleWidth` moves whenever the content changes it, which
    /// in `.handsFree` is every time a word arrives in the live transcript. Animating them as
    /// one value means a transcript growing mid-extrusion cannot leave the lobe attached to an
    /// edge the capsule has already left.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(extrusion, capsuleWidth) }
        set {
            extrusion = newValue.first
            capsuleWidth = newValue.second
        }
    }

    /// An inward offset shrinks the *convex* radii and grows the *concave* one, with every arc
    /// centre held still.
    ///
    /// That sign rule is the whole of why the two strokes stay concentric through the neck, and
    /// getting it backwards would cross them — the most visible possible defect on a bridge
    /// 12pt wide. Verified: `inset(by: 0.5)` on the extruded shape puts every sampled point of
    /// the inner contour inside the outer fill, with a uniform 0.5pt gap on all four sides.
    func inset(by amount: CGFloat) -> PillShellShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    /// The shell without its bead — `PillShape`'s path, in the capsule's part of `rect`.
    private func shellOnly(in rect: CGRect) -> Path {
        let bounds = CGRect(x: rect.minX + insetAmount,
                            y: rect.minY + insetAmount,
                            width: capsuleWidth - insetAmount * 2,
                            height: rect.height - insetAmount * 2)
        guard bounds.width > 0, bounds.height > 0 else { return Path() }
        let radius = min(cornerRadius - insetAmount, min(bounds.width, bounds.height) / 2)
        return Path(roundedRect: bounds, cornerRadius: max(radius, 0))
    }

    func path(in rect: CGRect) -> Path {
        guard capsuleWidth - insetAmount * 2 > 0, rect.height - insetAmount * 2 > 0 else {
            return Path()
        }
        // No lobe at rest, and none on a shell whose trailing end is not a semicircle.
        guard extrusion > 0, cornerRadius >= rect.height / 2 else { return shellOnly(in: rect) }

        let midY = rect.midY
        // Convex radii shrink with the inset; the concave one grows. Centres do not move: an
        // inset rounded rect's corner centre stays put while its radius shrinks, which is what
        // `PillShape` already relies on.
        let endRadius = rect.height / 2 - insetAmount
        let beadRadius = PillMetrics.handsFreeButtonSide / 2 - insetAmount
        let filletRadius = fillet + insetAmount
        guard endRadius > 0, beadRadius > 0 else { return shellOnly(in: rect) }

        let capsuleRight = rect.minX + capsuleWidth
        let trailing = CGPoint(x: capsuleRight - rect.height / 2, y: midY)
        let leading = CGPoint(x: rect.minX + rect.height / 2, y: midY)
        let bead = CGPoint(x: capsuleRight + PillMetrics.lobeCentreOffset(
                                extrusion: extrusion, capsuleWidth: capsuleWidth),
                           y: midY)
        let separation = bead.x - trailing.x
        // Internal containment: the bead is inside the capsule's end and adds nothing. Exactly
        // true at `extrusion == 0` — 1 + 13 == 14 — and it survives the inset, since both radii
        // shrink by the same amount.
        guard separation + beadRadius > endRadius else { return shellOnly(in: rect) }

        guard let offset = PillMetrics.neckArcOffset(distance: separation,
                                                    rA: endRadius,
                                                    rB: beadRadius,
                                                    fillet: filletRadius) else {
            // Pinched off. Two objects, each with its own outline — which is the ask, not the
            // failure: the failure was two outlines *during* the merge.
            var path = shellOnly(in: rect)
            path.addEllipse(in: CGRect(x: bead.x - beadRadius, y: midY - beadRadius,
                                       width: beadRadius * 2, height: beadRadius * 2))
            return path
        }

        // Each tangent point lies on the line joining its circle's centre to the fillet's, at
        // `radius / (radius + filletRadius)` of the way along it.
        func tangent(from centre: CGPoint, radius: CGFloat, to fillet: CGPoint) -> CGPoint {
            let k = radius / (radius + filletRadius)
            return CGPoint(x: centre.x + (fillet.x - centre.x) * k,
                           y: centre.y + (fillet.y - centre.y) * k)
        }
        func angle(_ point: CGPoint, about centre: CGPoint) -> Angle {
            .radians(atan2(point.y - centre.y, point.x - centre.x))
        }

        // View space, so y grows downward and `clockwise: false` sweeps in the direction of
        // increasing angle. Convex arcs take that direction and the concave fillets take the
        // other; the three remaining combinations all put a fillet centre outside the shell and
        // blow the silhouette's height from 28pt to as much as 29.9pt (measured).
        let upper = CGPoint(x: trailing.x + offset.x, y: midY - offset.y)
        let lower = CGPoint(x: trailing.x + offset.x, y: midY + offset.y)
        let top = rect.minY + insetAmount
        let bottom = rect.maxY - insetAmount

        var path = Path()
        path.move(to: CGPoint(x: leading.x, y: top))
        path.addLine(to: CGPoint(x: trailing.x, y: top))
        path.addArc(center: trailing, radius: endRadius,
                    startAngle: .radians(-.pi / 2),
                    endAngle: angle(tangent(from: trailing, radius: endRadius, to: upper),
                                    about: trailing),
                    clockwise: false)
        path.addArc(center: upper, radius: filletRadius,
                    startAngle: angle(tangent(from: trailing, radius: endRadius, to: upper),
                                      about: upper),
                    endAngle: angle(tangent(from: bead, radius: beadRadius, to: upper),
                                    about: upper),
                    clockwise: true)
        path.addArc(center: bead, radius: beadRadius,
                    startAngle: angle(tangent(from: bead, radius: beadRadius, to: upper),
                                      about: bead),
                    endAngle: angle(tangent(from: bead, radius: beadRadius, to: lower),
                                    about: bead),
                    clockwise: false)
        path.addArc(center: lower, radius: filletRadius,
                    startAngle: angle(tangent(from: bead, radius: beadRadius, to: lower),
                                      about: lower),
                    endAngle: angle(tangent(from: trailing, radius: endRadius, to: lower),
                                    about: lower),
                    clockwise: true)
        path.addArc(center: trailing, radius: endRadius,
                    startAngle: angle(tangent(from: trailing, radius: endRadius, to: lower),
                                      about: trailing),
                    endAngle: .radians(.pi / 2),
                    clockwise: false)
        path.addLine(to: CGPoint(x: leading.x, y: bottom))
        path.addArc(center: leading, radius: endRadius,
                    startAngle: .radians(.pi / 2),
                    endAngle: .radians(3 * .pi / 2),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
