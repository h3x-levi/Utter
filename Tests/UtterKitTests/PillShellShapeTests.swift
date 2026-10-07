import Testing
import SwiftUI
import CoreGraphics
@testable import UtterKit

/// `PillShellShape` - the pill's silhouette with the hands-free bead extruded out of it.
///
/// A shape cannot be looked at on this machine, but almost everything that can be *wrong* with
/// this one is arithmetic on a `CGPath`, and the two defects that matter most are both invisible
/// to the kind of check that only reads a bounding box:
///
///   * **How many outlines it has.** `strokeBorder` is `inset(by:).stroke(...)`, and `stroke`
///     strokes every subpath - so a shape assembled as rounded-rect + circle + neck-patch inks
///     the capsule's buried trailing arc, the lobe's buried arc and both neck chords as well.
///     Five or six outlines where the fill shows one, which is worse than the two-outlined-objects
///     problem the whole design exists to delete. A bounding box is identical either way, which is
///     exactly why it has to be probed by stroking and sampling.
///   * **Whether the two strokes stay concentric through the neck.** They cross if `inset(by:)`
///     gets the sign of the concave radius wrong, and a crossed pair on a 12pt bridge is the most
///     visible possible defect.
///
/// So the probes here render: they stroke the path and ask CoreGraphics what it inked.
@Suite("Pill shell shape")
struct PillShellShapeTests {

    /// The rect the shell is drawn in - `shellWidthWithBead` wide, so the lobe has room.
    private func rect(capsuleWidth: CGFloat,
                      height: CGFloat = PillMetrics.capsuleHeight) -> CGRect {
        CGRect(x: 0, y: 0,
               width: PillMetrics.shellWidthWithBead(capsuleWidth: capsuleWidth),
               height: height)
    }

    private func path(extrusion: CGFloat, capsuleWidth: CGFloat,
                      height: CGFloat = PillMetrics.capsuleHeight,
                      inset: CGFloat = 0) -> Path {
        PillShellShape(extrusion: extrusion, capsuleWidth: capsuleWidth)
            .inset(by: inset)
            .path(in: rect(capsuleWidth: capsuleWidth, height: height))
    }

    /// How many separate contours the path has - one `moveTo` each.
    private func contourCount(_ path: Path) -> Int {
        var count = 0
        path.cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint { count += 1 }
        }
        return count
    }

    /// The spans of `x` where a 1pt stroke of `path` inks the horizontal line `y`.
    ///
    /// This is the constraint the design is judged on, measured the only way it can be: one
    /// silhouette inks two spans on a line that crosses it - the leading edge and the trailing
    /// edge - however complicated the shape between them is.
    private func inkedSpans(_ path: Path, y: CGFloat,
                            from x0: CGFloat, to x1: CGFloat,
                            step: CGFloat = 0.02) -> [ClosedRange<CGFloat>] {
        let stroked = path.cgPath.copy(strokingWithWidth: 1, lineCap: .butt,
                                       lineJoin: .miter, miterLimit: 10)
        var spans: [ClosedRange<CGFloat>] = []
        var open: CGFloat?
        var x = x0
        while x <= x1 {
            let inked = stroked.contains(CGPoint(x: x, y: y), using: .winding)
            if inked, open == nil { open = x }
            if !inked, let start = open { spans.append(start...(x - step)); open = nil }
            x += step
        }
        if let start = open { spans.append(start...x1) }
        return spans
    }

    // MARK: The one-outline constraint

    @Test("The extruded shell has exactly one outline while the bead is joined")
    func oneSilhouetteWhileJoined() {
        // The failure this pins, verbatim: a compound path made of a rounded rect, an ellipse and
        // a neck quad has the same bounding box and the same fill as this single contour, and
        // stroking it draws six outlines - the capsule's trailing semicircle straight across the
        // neck, the lobe's full circle including the arc buried in the capsule, and the neck's own
        // two chords. Measured on the centre line at extrusion 0.25: six spans against two.
        let width = PillMetrics.minimumCapsuleWidth
        let bounds = rect(capsuleWidth: width)
        var closedOver = 0
        for step in 0...92 {
            let extrusion = CGFloat(step) / 100
            // As `strokeBorder(lineWidth: 1)` draws it: inset by half the line width.
            let shell = path(extrusion: extrusion, capsuleWidth: width, inset: 0.5)
            let spans = inkedSpans(shell, y: bounds.midY, from: -2, to: bounds.width + 2)
            let inked = spans.map { "\($0.lowerBound)...\($0.upperBound)" }
            #expect(contourCount(shell) == 1,
                    "extrusion \(extrusion) is \(contourCount(shell)) contours, not one")
            // Two, except for the one frame where the neck is thinner than the pen drawing it and
            // the ink closes across it - a third band, not a third outline. Measured: that happens
            // at exactly extrusion 0.92, where the inset neck is 0.86pt against a 1pt line, and
            // nowhere else. It reads as the neck about to snap, which is what it is.
            #expect(spans.count == 2 || spans.count == 3,
                    "extrusion \(extrusion) inks \(spans.count) outlines on the centre line: \(inked)")
            if spans.count == 3 { closedOver += 1 }
        }
        #expect(closedOver <= 2, "\(closedOver) frames have a neck narrower than the line")
    }

    @Test("No outline is drawn inside the silhouette")
    func buriedArcsAreNotStroked() {
        // The sharpest form of the constraint, and the exact defect a compound path produces: with
        // the shape assembled as rounded-rect + circle + neck-patch, `strokeBorder` inks the
        // capsule's own trailing edge as a hard vertical line straight across the neck at *every*
        // extrusion, and the lobe's full circle including the arc buried inside the capsule. Both
        // are interior to the union, so the fill and the bounding box are identical and cannot see
        // them. These two probes can.
        let width = PillMetrics.minimumCapsuleWidth
        let bounds = rect(capsuleWidth: width)
        let endCentre = width - PillMetrics.capsuleHeight / 2
        let endRadius = PillMetrics.capsuleHeight / 2 - 0.5
        let beadRadius = PillMetrics.handsFreeButtonSide / 2 - 0.5

        for step in stride(from: 5, through: 90, by: 5) {
            let extrusion = CGFloat(step) / 100
            let shell = path(extrusion: extrusion, capsuleWidth: width, inset: 0.5)
            guard let stroked = shell.cgPath.copy(strokingWithWidth: 1, lineCap: .butt,
                                                 lineJoin: .miter, miterLimit: 10) as CGPath? else {
                Issue.record("stroking failed at extrusion \(extrusion)"); continue
            }
            func inked(_ x: CGFloat) -> Bool {
                stroked.contains(CGPoint(x: x, y: bounds.midY), using: .winding)
            }

            // 1. The capsule's own trailing edge, while the lobe still covers it.
            let lobeCentre = width + PillMetrics.lobeCentreOffset(extrusion: extrusion,
                                                                 capsuleWidth: width)
            if lobeCentre - beadRadius < width - 0.5 {
                #expect(!inked(width - 0.5),
                        "extrusion \(extrusion): the capsule's trailing edge is stroked at x = \(width - 0.5), inside the lobe")
            }
            // 2. The lobe's leftmost point, while it is buried in the capsule's end.
            let lobeLeft = lobeCentre - beadRadius
            if abs(lobeLeft - endCentre) < endRadius {
                #expect(!inked(lobeLeft),
                        "extrusion \(extrusion): the lobe's buried arc is stroked at x = \(lobeLeft)")
            }
        }
    }

    @Test("The path is a single non-self-intersecting loop, so its fill is unambiguous")
    func contourDoesNotCrossItself() {
        // A closed loop that never crosses itself fills identically under both rules. If the neck
        // arcs were traced in the wrong rotational sense they would cross, and the even-odd fill
        // would punch a hole where the winding fill does not - which is also the state in which a
        // stroke doubles back over itself.
        let width = PillMetrics.minimumCapsuleWidth
        let bounds = rect(capsuleWidth: width)
        for extrusion in [0.05, 0.2, 0.5, 0.8, 0.9, 0.92] {
            let shell = path(extrusion: CGFloat(extrusion), capsuleWidth: width).cgPath
            var disagreements = 0
            var x = bounds.minX - 1
            while x <= bounds.maxX + 1 {
                var y = bounds.minY - 1
                while y <= bounds.maxY + 1 {
                    let point = CGPoint(x: x, y: y)
                    if shell.contains(point, using: .winding)
                        != shell.contains(point, using: .evenOdd) { disagreements += 1 }
                    y += 0.5
                }
                x += 0.5
            }
            #expect(disagreements == 0,
                    "extrusion \(extrusion): \(disagreements) points fill differently under winding and even-odd - the contour crosses itself")
        }
    }

    @Test("Detached, the bead is a second object with its own outline")
    func pinchedBeadIsItsOwnObject() {
        // Two outlines *after* the pinch is the ask, not the failure: "I don't want the button to
        // be attached to the main pill, it disconnect and then merge back to the pill." The
        // failure was two outlines *during* the merge, which `oneSilhouetteWhileJoined` covers.
        let width = PillMetrics.minimumCapsuleWidth
        let bounds = rect(capsuleWidth: width)
        let shell = path(extrusion: 1, capsuleWidth: width, inset: 0.5)
        #expect(contourCount(shell) == 2)
        let spans = inkedSpans(shell, y: bounds.midY, from: -2, to: bounds.width + 2)
        #expect(spans.count == 4, "two separate objects should ink 4 spans, not \(spans.count)")
    }

    // MARK: The silhouette never leaves the shell's band

    @Test("The silhouette is exactly the shell's height, bottom-anchored, at every extrusion")
    func heightAndAnchorHold() {
        // The invariant that caught a real bug while this shape was being written: three of the
        // four `clockwise:` combinations put a fillet centre outside the shell and blew the height
        // from 28pt to as much as 29.88pt, spilling the outline above the capsule's top edge. It
        // matters beyond looks - `PillMetrics.capsuleCentreAboveBottom` is what
        // `CompanionWindow.placeBesidePill` puts the character on, and it is only true while the
        // shell stays in its band.
        var worstHeight: CGFloat = 0
        var worstAnchor: CGFloat = 0
        var samples = 0
        for width in stride(from: PillMetrics.minimumCapsuleWidth, through: 300, by: 4) {
            for extrusion in stride(from: 0.0, through: 1.0, by: 0.01) {
                let bounds = path(extrusion: CGFloat(extrusion),
                                  capsuleWidth: width).boundingRect
                worstHeight = max(worstHeight, abs(bounds.height - PillMetrics.capsuleHeight))
                worstAnchor = max(worstAnchor, abs(bounds.minY))
                samples += 1
            }
        }
        #expect(samples > 6_000)
        #expect(worstHeight < 0.001, "height drifted by \(worstHeight)pt")
        #expect(worstAnchor < 0.001, "the silhouette left y = 0 by \(worstAnchor)pt")
    }

    @Test("The trailing edge is exactly the lobe's edge, and the lobe is where the glyph is")
    func trailingEdgeTracksTheLobe() {
        // The glyph is positioned from the same `lobeCentreOffset` the shape draws the lobe from,
        // so this is what stops a record ring sitting a point off its own bead.
        for width in stride(from: PillMetrics.minimumCapsuleWidth, through: 300, by: 7) {
            for extrusion in stride(from: 0.0, through: 1.0, by: 0.05) {
                let lobeCentre = width + PillMetrics.lobeCentreOffset(extrusion: CGFloat(extrusion),
                                                                     capsuleWidth: width)
                let expected = max(width, lobeCentre + PillMetrics.handsFreeButtonSide / 2)
                let measured = path(extrusion: CGFloat(extrusion),
                                    capsuleWidth: width).boundingRect.maxX
                // 0.01pt of slack for CoreGraphics' arc flattening.
                #expect(abs(measured - expected) < 0.01,
                        "width \(width) extrusion \(extrusion): edge \(measured), lobe \(expected)")
            }
        }
    }

    // MARK: Nothing changes at rest, or on a shell that is not a capsule

    @Test("At extrusion 0 the path is PillShape's own, to the point")
    func restingSilhouetteIsUnchanged() {
        // The pill spends most of its life here, so the change cannot be allowed to regress it.
        // Byte-identical rather than merely close: at extrusion 0 the bead is internally tangent
        // to the capsule's end - 1 + 13 == 14 - so it contributes nothing and the shape
        // short-circuits.
        for (width, height) in [(PillMetrics.minimumCapsuleWidth, PillMetrics.capsuleHeight),
                                (200 as CGFloat, PillMetrics.capsuleHeight),
                                (292 as CGFloat, PillMetrics.noteBoxHeight)] {
            let shell = path(extrusion: 0, capsuleWidth: width, height: height)
            let capsule = PillShape().path(in: CGRect(x: 0, y: 0, width: width, height: height))
            #expect(shell.description == capsule.description,
                    "extrusion 0 at \(width)x\(height) is not PillShape's path")
        }
    }

    @Test("An expanded shell never grows a lobe, whatever the extrusion says")
    func expandedShellSuppressesTheLobe() {
        // Hover the pill, then hit the note chord: a ~300ms extrusion collapse overlaps a 0.46s
        // height growth, so the shape is asked for a lobe on a 124pt-tall shell. The neck is
        // derived against a trailing end modelled as a semicircle of radius height/2, which
        // `Path(roundedRect:)` only draws while the corner radius reaches that far - so at 124pt
        // the arithmetic would be meaningless and it drew a tab at the card's mid-height right
        // edge. The guard is the derived condition, not a state comparison, so a future expanded
        // state inherits it.
        let width: CGFloat = 292
        // 2 * cornerRadius is where the end stops being a semicircle: 32pt.
        #expect(PillMetrics.cornerRadius * 2 == 32)
        for height in [PillMetrics.capsuleHeight, 32, 33, PillMetrics.noteBoxHeight] {
            let extruded = path(extrusion: 1, capsuleWidth: width, height: height)
            let plain = path(extrusion: 0, capsuleWidth: width, height: height)
            let lobed = height <= PillMetrics.cornerRadius * 2
            #expect((extruded.description != plain.description) == lobed,
                    "height \(height) should \(lobed ? "" : "not ")draw a lobe")
        }
        // And specifically: the note card's silhouette is the card, with nothing past its edge.
        #expect(path(extrusion: 1, capsuleWidth: width,
                     height: PillMetrics.noteBoxHeight).boundingRect.maxX == width)
    }

    // MARK: The two strokes stay concentric

    @Test("inset(by:) is concentric and strictly interior, neck included")
    func insetStaysInside() {
        // `strokeBorder` insets by half the line width, and the inner highlight insets again - so
        // the outer 1pt ring and the 0.8pt highlight are two insets of the same shape. If an
        // inward offset failed to *grow* the concave fillet radius, they would cross inside the
        // neck. Sampled along the inner contour rather than compared as boxes, because a box
        // cannot see a crossing.
        let width = PillMetrics.minimumCapsuleWidth
        for extrusion in [0.0, 0.3, 0.5, 0.8, 0.9, 0.92, 1.0] {
            let outer = path(extrusion: CGFloat(extrusion), capsuleWidth: width).cgPath
            let inner = path(extrusion: CGFloat(extrusion), capsuleWidth: width, inset: 0.5)
            var outside = 0
            for t in stride(from: 0.0, through: 1.0, by: 0.002) {
                guard let point = inner
                    .trimmedPath(from: CGFloat(t), to: min(CGFloat(t) + 0.001, 1))
                    .currentPoint else { continue }
                if !outer.contains(point, using: .winding) { outside += 1 }
            }
            #expect(outside == 0,
                    "extrusion \(extrusion): \(outside) points of the inset contour fall outside the uninset fill - the strokes cross")
            // Concentric on all four sides, not merely smaller.
            let box = inner.boundingRect, hull = outer.boundingBoxOfPath
            #expect(abs((box.minX - hull.minX) - 0.5) < 0.001)
            #expect(abs((hull.maxX - box.maxX) - 0.5) < 0.001)
            #expect(abs((box.minY - hull.minY) - 0.5) < 0.001)
            #expect(abs((hull.maxY - box.maxY) - 0.5) < 0.001)
        }
    }

    // MARK: animatableData

    @Test("animatableData carries both quantities, and the silhouette holds through the blend")
    func animatableDataInterpolates() {
        // SwiftUI interpolates `animatableData`, not the properties, so a shape whose pair does not
        // round-trip animates to the wrong geometry. And the pair is a *pair* on purpose: in
        // `.handsFree` the capsule widens with every word of the live transcript, so a lobe
        // animated independently of the edge it is leaving would drift off it mid-sentence.
        var shape = PillShellShape(extrusion: 0, capsuleWidth: PillMetrics.minimumCapsuleWidth)
        shape.animatableData = AnimatablePair(0.5, 100)
        #expect(shape.extrusion == 0.5)
        #expect(shape.capsuleWidth == 100)
        #expect(shape.animatableData.first == 0.5)
        #expect(shape.animatableData.second == 100)

        // Extruding while the capsule grows 56 -> 292: the worst case, and the height must hold
        // through every frame of it.
        var worst: CGFloat = 0
        for t in stride(from: 0.0, through: 1.0, by: 0.005) {
            var frame = PillShellShape(extrusion: 0, capsuleWidth: PillMetrics.minimumCapsuleWidth)
            frame.animatableData = AnimatablePair(
                CGFloat(t),
                PillMetrics.minimumCapsuleWidth + (292 - PillMetrics.minimumCapsuleWidth) * CGFloat(t))
            let bounds = frame.path(in: rect(capsuleWidth: frame.capsuleWidth)).boundingRect
            worst = max(worst, abs(bounds.height - PillMetrics.capsuleHeight) + abs(bounds.minY))
        }
        #expect(worst < 0.001, "the silhouette moved by \(worst)pt during the blend")
    }

    // MARK: The neck

    @Test("The neck thins, and it thins late")
    func neckIsBackLoaded() {
        // The cue that says surface tension rather than rigid extrusion. A real liquid bridge holds
        // its girth while the droplet pulls away and then necks down sharply, and here that comes
        // free from the geometry of two separating circles - no second animation, no phase offset.
        //
        // Measured full widths at capsule width 56 (`2 * (h - fillet)`, the closed form):
        // 25.83pt at 0.2, 23.69 at 0.4, 19.49 at 0.6, 11.91 at 0.8, 4.52 at 0.9, 1.86 at 0.92.
        let width = PillMetrics.minimumCapsuleWidth
        func neck(_ extrusion: CGFloat) -> CGFloat {
            let separation = PillMetrics.capsuleHeight / 2
                + PillMetrics.lobeCentreOffset(extrusion: extrusion, capsuleWidth: width)
            guard let offset = PillMetrics.neckArcOffset(
                distance: separation,
                rA: PillMetrics.capsuleHeight / 2,
                rB: PillMetrics.handsFreeButtonSide / 2,
                fillet: PillMetrics.neckFillet) else { return 0 }
            return 2 * (offset.y - PillMetrics.neckFillet)
        }
        // Monotone from the point the circles start separating in earnest.
        var previous = neck(0.2)
        #expect(previous > 25, "the neck starts fat: \(previous)pt")
        for extrusion in stride(from: 0.25, through: 0.92, by: 0.01) {
            let current = neck(CGFloat(extrusion))
            #expect(current < previous,
                    "the neck widened at extrusion \(extrusion): \(previous) -> \(current)")
            previous = current
        }
        #expect(previous < 2, "the neck should be nearly gone by 0.92, not \(previous)pt")
        // Back-loaded: under a fifth of the thinning happens in the first 40% of the travel.
        let total = neck(0.2) - neck(0.92)
        #expect((neck(0.2) - neck(0.4)) / total < 0.2)
    }

    @Test("The bead detaches before it settles, and the pinch is where the closed form says")
    func beadDetachesBeforeRest() {
        // Replaces the old `glassBlendSpacing < handsFreeButtonGap` check, which asserted the same
        // look about `GlassEffectContainer(spacing:)`. The requirement is unchanged and on the
        // record: "I don't want the button to be attached to the main pill, it disconnect and then
        // merge back to the pill."
        let rA = PillMetrics.capsuleHeight / 2
        let rB = PillMetrics.handsFreeButtonSide / 2
        let pinch = PillMetrics.neckPinchDistance(rA: rA, rB: rB, fillet: PillMetrics.neckFillet)

        // sqrt(14 * 18) + sqrt(13 * 17) = 15.874 + 14.866.
        #expect(abs(pinch - 30.7406) < 0.001, "pinch distance is \(pinch)")
        // The resting separation: tucked centres are 1pt apart and travel is 32pt.
        let restingSeparation = (rA - rB) + PillMetrics.handsFreeButtonReach
        #expect(restingSeparation == 33)
        #expect(pinch < restingSeparation,
                "the neck survives to rest - the bead would stay a permanent lobe")

        // The closed form has to agree with the predicate the shape actually branches on, or the
        // documented pinch and the drawn one are two different numbers.
        #expect(PillMetrics.neckArcOffset(distance: pinch - 0.01, rA: rA, rB: rB,
                                          fillet: PillMetrics.neckFillet) != nil)
        #expect(PillMetrics.neckArcOffset(distance: pinch + 0.01, rA: rA, rB: rB,
                                          fillet: PillMetrics.neckFillet) == nil)

        // And it necks for nearly all of the journey, or the bead just slides out.
        let necked = pinch - (rA - rB)
        #expect(necked / PillMetrics.handsFreeButtonReach > 0.9,
                "the neck covers only \(necked)pt of \(PillMetrics.handsFreeButtonReach)pt")

        // The resting pill detaches; a pill wide enough for the clamp to bite does not. Pinned
        // because it is a real behaviour change on wide states and a surprise if it is not written
        // down: the clamp shortens the travel, so past `capsuleWidth` ~260.5 the bead settles while
        // still joined. `PillMetrics.lobeCentreOffset` has the arithmetic.
        func separationAtRest(capsuleWidth: CGFloat) -> CGFloat {
            (rA - rB) + PillMetrics.handsFreeButtonSide / 2
                + PillMetrics.lobeCentreOffset(extrusion: 1, capsuleWidth: capsuleWidth)
        }
        #expect(separationAtRest(capsuleWidth: PillMetrics.minimumCapsuleWidth) > pinch,
                "the resting pill's bead has to come off")
        #expect(separationAtRest(capsuleWidth: 240) > pinch)
        #expect(separationAtRest(capsuleWidth: 292) < pinch,
                "a note-card-width capsule is expected to keep its lobe - see lobeCentreOffset")
    }

    // MARK: The shell fits the panel it is drawn in

    @Test("The drawn shell never runs past the panel's edge")
    func shellFitsThePanel() {
        // `shellWidthWithBead` is what the glass, both strokes, the shadow and the hit region are
        // sized to, and it is derived from `handsFreeButtonCentreX` rather than `+ handsFreeButtonReach` for
        // exactly this reason: past a ~256pt capsule the bead's resting position is clamped to the
        // panel edge, and the naive sum would claim up to 10.5pt of shell that nothing draws in.
        //
        // The domain ends at the panel's own width, and that is not a convenience. The widest shell
        // the pill ever draws is the note card at `noteContentWidth + horizontalPadding * 2` = 292pt
        // (and the widest `.handsFree` row is ~277pt), and a capsule wider than 320pt cannot be
        // drawn inside a 320pt panel at all - `PillWindow.drawnShellRect` clamps to
        // `content.bounds.width` for that reason, which `PillMorphTests` covers separately. At
        // exactly 320 the bead has nowhere left to go and the shell is the capsule.
        #expect(PillMetrics.noteContentWidth + PillMetrics.horizontalPadding * 2 == 292)
        #expect(PillMetrics.shellWidthWithBead(capsuleWidth: PillMetrics.windowWidth)
                == PillMetrics.windowWidth)
        for width in stride(from: PillMetrics.minimumCapsuleWidth,
                            through: PillMetrics.windowWidth, by: 1) {
            let leading = max(0, PillMetrics.windowWidth / 2 - width / 2)
            let shell = PillMetrics.shellWidthWithBead(capsuleWidth: width)
            #expect(leading + shell <= PillMetrics.windowWidth + 0.001,
                    "capsule \(width): shell reaches \(leading + shell) in a \(PillMetrics.windowWidth)pt panel")
            #expect(shell >= width, "the shell is narrower than the capsule at \(width)")
            #expect(shell <= width + PillMetrics.handsFreeButtonReach)
        }
        // The resting pill, spelled out: 56/2 + 47 + 13 = 88 = 56 + 32.
        #expect(PillMetrics.shellWidthWithBead(capsuleWidth: PillMetrics.minimumCapsuleWidth)
                == PillMetrics.minimumCapsuleWidth + PillMetrics.handsFreeButtonReach)
    }

    @Test("The lobe's two endpoints are the tuck and the resting button position")
    func lobeEndpointsAreTheOnesTheGlyphUses() {
        // One function places the lobe and positions the glyph, so this pins that its ends are the
        // positions the glyph had before the shape existed - `tuckedX` and `restX`.
        for width in stride(from: PillMetrics.minimumCapsuleWidth, through: 300, by: 3) {
            let tucked = PillMetrics.lobeCentreOffset(extrusion: 0, capsuleWidth: width)
            let rest = PillMetrics.lobeCentreOffset(extrusion: 1, capsuleWidth: width)
            #expect(tucked == -PillMetrics.handsFreeButtonSide / 2)
            #expect(abs((width / 2 + rest)
                        - PillMetrics.handsFreeButtonCentreX(capsuleWidth: width)) < 0.001)
            // Linear, which is what lets SwiftUI interpolate the shape's `extrusion` and the
            // glyph's `offset(x:)` separately and still agree on every frame.
            let middle = PillMetrics.lobeCentreOffset(extrusion: 0.5, capsuleWidth: width)
            #expect(abs(middle - (tucked + rest) / 2) < 0.001)
            // Clamped, so an out-of-range extrusion cannot fling the lobe off the panel.
            #expect(PillMetrics.lobeCentreOffset(extrusion: -1, capsuleWidth: width) == tucked)
            #expect(PillMetrics.lobeCentreOffset(extrusion: 2, capsuleWidth: width) == rest)
        }
    }
}
