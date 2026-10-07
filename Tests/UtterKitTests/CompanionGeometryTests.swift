import Testing
import AppKit
@testable import UtterKit

/// Where the companion's panel is allowed to sit.
///
/// The clamps are the part worth pinning, and they are the part that cannot be tested
/// through the window: the window resolves an `NSScreen`, and a menu bar, a Dock and a
/// short display are not things a test can construct. So `CompanionGeometry` takes a
/// `visibleFrame` directly and these drive that.
///
/// Every assertion is made against `characterTop`/`characterBottom`/`characterLeft`/
/// `characterRight` rather than against a recomputed formula. Re-deriving the geometry
/// here would just be a second copy of the same arithmetic, free to agree with a bug in
/// the first.
///
/// And every one of them runs at every size the settings offer. The size is a preference
/// now, so "the geometry" is four geometries; a suite that checked the shipped default
/// would leave three sizes unverified, and the menu-bar overshoot this file exists to
/// prevent is the one that *grows with the character* (measured 4.5pt at 28pt, 7.0pt at
/// 44pt, before the fix).
@Suite("Companion geometry")
@MainActor
struct CompanionGeometryTests {

    /// A 16:10 display with a menu bar, in the coordinates AppKit reports: `visibleFrame`
    /// excludes the 25pt menu bar at the top and a 70pt Dock at the bottom.
    private static let visible = NSRect(x: 0, y: 70, width: 1512, height: 887)

    private static let sizes = CompanionSize.allCases

    // MARK: The top edge - the menu bar

    @Test("A companion at the top of the screen keeps the character under the menu bar",
          arguments: sizes)
    func clampsBelowMenuBar(size: CompanionSize) {
        // The regression. The top bound counted the hop but not the pose scales
        // stacked on it, and measured the character's frame rather than what a pose
        // draws - so at 44pt the character's head cleared `visibleFrame.maxY` by 7.0pt
        // and this window sits above the menu bar's own level, so it draws over the menu
        // bar rather than being clipped by it.
        let geometry = CompanionGeometry(size)
        let desired = Self.visible.maxY - 20   // dragged right to the top
        let y = geometry.clampedY(desired: desired, visible: Self.visible)
        #expect(geometry.characterTop(panelOriginY: y) <= Self.visible.maxY + 0.001)
    }

    @Test("No reachable position puts the character over the menu bar", arguments: sizes)
    func neverClearsTheTopEdge(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        // Sweep well past both edges: the companion can be dragged anywhere, including
        // onto a second display whose frame does not overlap this one at all.
        for offset in stride(from: -400.0, through: 1_400.0, by: 7.0) {
            let y = geometry.clampedY(desired: Self.visible.minY + offset,
                                      visible: Self.visible)
            #expect(geometry.characterTop(panelOriginY: y) <= Self.visible.maxY + 0.001,
                    "desired offset \(offset) put the head above the visible frame")
        }
    }

    // MARK: The bottom edge

    @Test("A companion at the bottom of the screen keeps the character's feet on screen",
          arguments: sizes)
    func clampsAboveTheDock(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        let desired = Self.visible.minY - 200   // dragged below the visible frame
        let y = geometry.clampedY(desired: desired, visible: Self.visible)
        #expect(geometry.characterBottom(panelOriginY: y) >= Self.visible.minY - 0.001)
    }

    // MARK: The side edges

    @Test("A companion dragged off either side keeps the whole stroll on screen",
          arguments: sizes)
    func clampsToTheSideEdges(size: CompanionSize) {
        // What has to stay visible is the envelope the character can *reach*, not where
        // it was put: `offsetX` is applied after placement, so a rest position on the
        // edge left the character `roamRange` off screen at the end of a stroll.
        let geometry = CompanionGeometry(size)
        let left = geometry.clampedX(desired: Self.visible.minX - 300, visible: Self.visible)
        #expect(geometry.characterLeft(panelOriginX: left) >= Self.visible.minX - 0.001)

        let right = geometry.clampedX(desired: Self.visible.maxX + 300, visible: Self.visible)
        #expect(geometry.characterRight(panelOriginX: right) <= Self.visible.maxX + 0.001)
    }

    @Test("No reachable position takes the character off the side of the screen",
          arguments: sizes)
    func neverClearsTheSideEdges(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        for offset in stride(from: -600.0, through: 2_200.0, by: 11.0) {
            let x = geometry.clampedX(desired: Self.visible.minX + offset,
                                      visible: Self.visible)
            #expect(geometry.characterLeft(panelOriginX: x) >= Self.visible.minX - 0.001,
                    "desired offset \(offset) put the character off the left edge")
            #expect(geometry.characterRight(panelOriginX: x) <= Self.visible.maxX + 0.001,
                    "desired offset \(offset) put the character off the right edge")
        }
    }

    // MARK: Not interfering otherwise

    @Test("A companion in the middle of the screen is not moved at all", arguments: sizes)
    func doesNotClampWhenThereIsRoom(size: CompanionSize) {
        // Clamping when it is not needed is how the character ended up sitting high and
        // off-centre.
        let geometry = CompanionGeometry(size)
        #expect(geometry.clampedY(desired: Self.visible.midY, visible: Self.visible)
                == Self.visible.midY)
        #expect(geometry.clampedX(desired: Self.visible.midX, visible: Self.visible)
                == Self.visible.midX)
    }

    @Test("The clamps are idempotent", arguments: sizes)
    func clampIsStable(size: CompanionSize) {
        // A drag clamps on every step, and a display change re-clamps a position that has
        // already been clamped, so a clamp that shifted its own output would walk the
        // companion across the screen.
        let geometry = CompanionGeometry(size)
        for offset in stride(from: -300.0, through: 1_300.0, by: 11.0) {
            let onceY = geometry.clampedY(desired: Self.visible.minY + offset,
                                          visible: Self.visible)
            #expect(onceY == geometry.clampedY(desired: onceY, visible: Self.visible))

            let onceX = geometry.clampedX(desired: Self.visible.minX + offset,
                                          visible: Self.visible)
            #expect(onceX == geometry.clampedX(desired: onceX, visible: Self.visible))
        }
    }

    // MARK: Degenerate displays

    @Test("A display too short for the panel leaves the position alone", arguments: sizes)
    func shortDisplayFallsBackToDesired(size: CompanionSize) {
        // The bounds cross over when the visible height is less than the panel plus its
        // reach. Clamping to a crossed pair would pin the character to whichever bound
        // won; the honest answer is to place it where it was asked for and let it
        // overhang.
        let tiny = NSRect(x: 0, y: 0, width: 30, height: 30)
        let geometry = CompanionGeometry(size)
        #expect(geometry.clampedY(desired: 30, visible: tiny) == 30)
        #expect(geometry.clampedX(desired: 30, visible: tiny) == 30)
    }

    @Test("An empty visible frame does not produce a NaN origin", arguments: sizes)
    func emptyFrameIsSafe(size: CompanionSize) {
        // `NSScreen.visibleFrame` has been observed empty while a display is waking.
        let geometry = CompanionGeometry(size)
        #expect(geometry.clampedY(desired: 400, visible: .zero).isFinite)
        #expect(geometry.clampedX(desired: 400, visible: .zero).isFinite)
    }

    // MARK: The character fits the panel it is drawn in

    @Test("The character's reach stays inside its own panel", arguments: sizes)
    func characterFitsInsidePanel(size: CompanionSize) {
        // A borderless panel clips its content, so anything the character can reach has
        // to be inside the window or it is sliced mid-stride. Every bound is derived from
        // `characterSize`, so this is what catches a size - or a new size on the ladder  - 
        // breaking the relationship between them.
        let geometry = CompanionGeometry(size)
        let side = geometry.panelSide
        #expect(geometry.characterTop(panelOriginY: 0) <= side + 0.001,
                "the character reaches \(geometry.characterTop(panelOriginY: 0)) in a \(side)pt panel")
        #expect(geometry.characterBottom(panelOriginY: 0) >= -0.001)
        #expect(geometry.characterLeft(panelOriginX: 0) >= -0.001)
        #expect(geometry.characterRight(panelOriginX: 0) <= side + 0.001)
    }

    @Test("The panel is the reach envelope and no larger", arguments: sizes)
    func panelIsNoLargerThanTheReach(size: CompanionSize) {
        // The other half of `characterFitsInsidePanel`, and the half that was wrong:
        // `panelSide` read `characterSize + padding * 2` while `padding` is already
        // measured from the centre, so the panel carried a whole extra character - 26pt of
        // transparent margin on each side at the default size, sitting over the pill's
        // capsule and taking the mouse there, which left the pill's own hover dead.
        //
        // Bounding the slack is what makes re-inflating it fail: putting `characterSize`
        // back adds 18pt (`small`) to 42pt (`huge`) of margin outside the reach. The 1pt
        // that is left is the `+1` in `stretchSlack`, and it is not spare - it absorbs the
        // pose lean the reach model does not carry.
        let geometry = CompanionGeometry(size)
        let slack = 2.0
        #expect(geometry.panelSide - geometry.characterTop(panelOriginY: 0) <= slack)
        #expect(geometry.characterLeft(panelOriginX: 0) <= slack)
        #expect(geometry.panelSide - geometry.characterRight(panelOriginX: 0) <= slack)
        // Not the bottom: the panel is square and centred on the character, so the room
        // under its feet is whatever the widest axis asked for and carries no meaning.
    }

    // MARK: Dragging

    @Test("A drag away from the edges moves the character 1:1 with the cursor",
          arguments: sizes)
    func dragTracksCursorOneToOne(size: CompanionSize) {
        // The heart of the jitter fix: away from any edge, the window follows the cursor
        // exactly. SwiftUI's y grows down and AppKit's up, so a negative height (drag up)
        // raises the origin.
        let geometry = CompanionGeometry(size)
        let start = CGPoint(x: Self.visible.midX - geometry.panelSide / 2,
                            y: Self.visible.midY - geometry.panelSide / 2)
        let moved = geometry.draggedOrigin(from: start,
                                           translation: CGSize(width: 37, height: -21),
                                           visible: Self.visible)
        #expect(abs(moved.x - (start.x + 37)) < 0.001)
        #expect(abs(moved.y - (start.y + 21)) < 0.001)
    }

    @Test("Incremental drag deltas accumulate exactly, so the character does not drift",
          arguments: sizes)
    func dragDeltasAccumulate(size: CompanionSize) {
        // The container view delivers a drag as a stream of per-event deltas. Summed, they
        // must land where one big translation would - a lossy step would creep the character
        // away from the cursor over a fast drag.
        let geometry = CompanionGeometry(size)
        let start = CGPoint(x: Self.visible.midX - geometry.panelSide / 2,
                            y: Self.visible.midY - geometry.panelSide / 2)
        var origin = start
        var total = CGSize.zero
        for _ in 0..<20 {
            let delta = CGSize(width: 3, height: -2)
            origin = geometry.draggedOrigin(from: origin, translation: delta, visible: Self.visible)
            total.width += delta.width
            total.height += delta.height
        }
        let once = geometry.draggedOrigin(from: start, translation: total, visible: Self.visible)
        #expect(abs(origin.x - once.x) < 0.001)
        #expect(abs(origin.y - once.y) < 0.001)
    }

    @Test("Absolute dragging preserves the point where the character was grabbed",
          arguments: sizes)
    func absoluteDragPreservesGrabPoint(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        let cursor = CGPoint(x: Self.visible.midX, y: Self.visible.midY)
        let grab = CGSize(width: 40, height: 30)
        let origin = geometry.draggedOrigin(cursor: cursor, grabOffset: grab, visible: Self.visible)

        #expect(abs((origin.x + grab.width) - cursor.x) < 0.001)
        #expect(abs((origin.y + grab.height) - cursor.y) < 0.001)
    }

    @Test("Dragging hard into an edge keeps the character on screen, not jittering past it",
          arguments: sizes)
    func dragClampsAtTheEdges(size: CompanionSize) {
        // "Freely anywhere" still means on screen: this window sits above the menu bar's
        // level, so an unclamped drag would paint the character over it. The clamp is the
        // same tested one the resting placement uses, reached through the drag path.
        let geometry = CompanionGeometry(size)
        let start = CGPoint(x: Self.visible.midX, y: Self.visible.midY)
        let up = geometry.draggedOrigin(from: start,
                                        translation: CGSize(width: 0, height: -5_000),
                                        visible: Self.visible)
        #expect(geometry.characterTop(panelOriginY: up.y) <= Self.visible.maxY + 0.001)

        let left = geometry.draggedOrigin(from: start,
                                          translation: CGSize(width: -5_000, height: 0),
                                          visible: Self.visible)
        #expect(geometry.characterLeft(panelOriginX: left.x) >= Self.visible.minX - 0.001)
    }

    // MARK: The speech bubble
    //
    // The two tests that were here pinned the *old* contract - "the bubble wraps to at least
    // two lines, bounded by the panel's far edge" and "the longest real error fits at the
    // default size" - and both were satisfied only because the bubble was allowed to grow
    // downward over the character. That was the reported defect. The bubble is now bounded by
    // the strip above the character's resting frame, so the honest contract is the one below:
    // it never reaches the resting character, and the price is a line budget the panel dictates.
    // `CompanionBubbleTests` holds the rest, including which real strings no longer fit.

    @Test("The bubble never reaches the character at rest, at any size", arguments: sizes)
    func bubbleClearsTheRestingCharacter(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        // The strip is measured from the panel's top edge down to the character's resting
        // frame, so "fits in the strip" *is* "does not touch the character".
        #expect(geometry.bubbleMaxHeight <= geometry.bubbleHeadroom)
        #expect(geometry.bubbleHeadroom + geometry.characterSize / 2
                <= geometry.panelSide / 2 + 0.001)

        let room = CompanionBubble.room(in: geometry)
        let used = CGFloat(room.lines) * room.step.lineHeight
            + CGFloat(room.lines - 1) * room.step.lineGap
            + CompanionBubble.verticalPadding * 2
        let ceiling = geometry.bubbleMaxHeight
        #expect(used <= ceiling + 0.001,
                "\(size): \(room.lines) line(s) at \(room.step.size)pt need \(used)pt, only \(ceiling)pt above the character")
    }

    @Test("The panel has ~1pt spare beyond the character's own motion, which is why the bubble cannot clear a hop",
          arguments: sizes)
    func headroomIsAlmostEntirelyTheMotionBudget(size: CompanionSize) {
        let geometry = CompanionGeometry(size)
        let spare = geometry.bubbleHeadroom - geometry.characterMotionAboveRest
        // Positive - the strip does contain the motion, which is what `clampedY` relies on.
        #expect(spare > 0)
        // …and by barely more than a point at every rung, which is the finding: there is no
        // room in this panel for a bubble that also clears a hop. If a future change to the
        // panel opens this up, this test is what says so.
        #expect(spare < 1.5,
                "\(size): \(spare)pt spare above the character's reach - if this has grown, the bubble could be placed clear of the hop as well as of the rest pose")
    }

    // MARK: The ladder itself

    @Test("The offered sizes are an ascending ladder around the size that shipped")
    func sizeLadderIsSane() {
        // 52pt is what the app drew before the size was a choice, so it has to still be
        // on the ladder and it has to be the default - otherwise the setting's arrival
        // silently resizes every existing install.
        #expect(UserData.defaultCompanionSize.points == 52)

        let points = CompanionSize.allCases.map(\.points)
        #expect(points == points.sorted())
        #expect(Set(points).count == points.count)
        // The floor: sprite art at 28pt put the character's whole face in a handful of
        // pixels, which is why the size grew to 44 and then 52 in the first place.
        #expect(points.allSatisfy { $0 >= 32 })
    }

    // MARK: The saved position

    @Test("A saved position survives the display it was saved on getting smaller",
          arguments: sizes)
    func savedPositionSurvivesADisplayChange(size: CompanionSize) {
        // The reason the position is stored as a fraction rather than a point. Park the
        // companion in the top-right corner of a large display, then restore it on a
        // small one: an absolute origin would be far off screen, and this window sits
        // above the menu bar's level, so "off the top" means drawn over the menu bar
        // rather than clipped by it.
        let geometry = CompanionGeometry(size)
        let large = NSRect(x: 0, y: 70, width: 3008, height: 1622)
        let parked = NSPoint(x: large.maxX - geometry.panelSide / 2,
                            y: large.maxY - geometry.panelSide / 2)

        let fraction = CompanionGeometry.fraction(ofCentre: parked, in: large)
        let small = NSRect(x: 0, y: 60, width: 1280, height: 740)
        let restored = geometry.origin(forCentreFraction: fraction, in: small)

        #expect(geometry.characterTop(panelOriginY: restored.y) <= small.maxY + 0.001)
        #expect(geometry.characterBottom(panelOriginY: restored.y) >= small.minY - 0.001)
        #expect(geometry.characterRight(panelOriginX: restored.x) <= small.maxX + 0.001)
        #expect(geometry.characterLeft(panelOriginX: restored.x) >= small.minX - 0.001)
    }

    @Test("A position that was already legal round-trips exactly", arguments: sizes)
    func savedPositionRoundTrips(size: CompanionSize) {
        // Saving and restoring on the same display must not drift: `restorePosition` runs
        // again on every screen-parameters change, so a lossy round trip would creep the
        // companion across the desktop over a working day of docking and undocking.
        let geometry = CompanionGeometry(size)
        let parked = NSPoint(x: Self.visible.midX, y: Self.visible.midY)
        let fraction = CompanionGeometry.fraction(ofCentre: parked, in: Self.visible)
        let restored = geometry.origin(forCentreFraction: fraction, in: Self.visible)
        #expect(abs(restored.x + geometry.panelSide / 2 - parked.x) < 0.001)
        #expect(abs(restored.y + geometry.panelSide / 2 - parked.y) < 0.001)
    }

    @Test("Resizing the character does not move the saved spot", arguments: sizes)
    func savedPositionIsSizeIndependent(size: CompanionSize) {
        // The reason the *centre* is what gets stored. `applyPreferredSize` grows the
        // panel about its centre, so the character does not move when the user resizes it
        // - and a fraction recorded from the panel's origin would have disagreed on the
        // next launch by half the difference between the two sizes.
        let parked = NSPoint(x: Self.visible.midX, y: Self.visible.midY)
        let fraction = CompanionGeometry.fraction(ofCentre: parked, in: Self.visible)
        let resized = CompanionGeometry(size)
        let origin = resized.origin(forCentreFraction: fraction, in: Self.visible)
        #expect(abs(origin.x + resized.panelSide / 2 - parked.x) < 0.001)
        #expect(abs(origin.y + resized.panelSide / 2 - parked.y) < 0.001)
    }

    @Test("A centre saved at one size restores to the same point at another",
          arguments: sizes, sizes)
    func savedCentreSurvivesASizeChange(saved: CompanionSize, restored: CompanionSize) {
        // The full round trip the previous test only half covers, and the guard that let
        // `panelSide` shrink safely: `savePosition` records the fraction from the *window's*
        // midpoint at one panel size and `restorePosition` turns it back into an origin at
        // another. Every size pair, because the panel changed by 52pt at the default size  - 
        // an origin-based scheme, or a `panelSide` that disagreed between the two halves,
        // would move the companion by half of that on the first launch after a resize.
        let before = CompanionGeometry(saved)
        let after = CompanionGeometry(restored)

        let originBefore = before.origin(forCentreFraction: CGPoint(x: 0.5, y: 0.5),
                                        in: Self.visible)
        let centreBefore = CGPoint(x: originBefore.x + before.panelSide / 2,
                                   y: originBefore.y + before.panelSide / 2)

        let fraction = CompanionGeometry.fraction(ofCentre: centreBefore, in: Self.visible)
        let originAfter = after.origin(forCentreFraction: fraction, in: Self.visible)

        #expect(abs(originAfter.x + after.panelSide / 2 - centreBefore.x) < 0.001)
        #expect(abs(originAfter.y + after.panelSide / 2 - centreBefore.y) < 0.001)
    }
}
