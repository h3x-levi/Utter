import CoreGraphics

/// How large the companion's character is drawn.
///
/// A ladder of four rather than a free slider, and the frames are the reason. Every
/// pixel a pack is decoded at is held for as long as the pack is loaded
/// (`SpritePackStore.maxFrameSide`), and the cap is derived from the drawn size — so
/// changing the size means re-decoding every frame. A continuous control would ask for
/// that on every drag of the knob. Four steps also make the memory cost of the feature
/// a short list of known numbers instead of a curve nobody has measured.
enum CompanionSize: String, CaseIterable {
    case small, medium, large, huge

    /// The rendered size of the character, in points.
    ///
    /// `medium` is 52 because that is what the app drew before the size was a choice,
    /// so an install that never touches this setting looks exactly as it did.
    ///
    /// The floor is 36. The size went 28 → 44 → 52 for one reason: sprite art at 28pt
    /// is shorter than a line of text and the face — the entire point of having moods —
    /// is a handful of pixels. 36 is the smallest step that still reads as a character
    /// at a glance rather than on inspection.
    ///
    /// The ceiling is 84 — three times the pill's 28pt capsule height, and 1.5x the
    /// capsule's 56pt resting width. Past that the companion stops being something beside
    /// the pill and becomes the thing on screen you look at, and the panel it needs
    /// (`panelSide`, 2.1x the character, so 178pt at 84) starts covering a serious
    /// fraction of a laptop display.
    var points: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 52
        case .large: return 68
        case .huge: return 84
        }
    }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .huge: return "Huge"
        }
    }
}

/// The companion's geometry at one character size.
///
/// Every number here is a fraction of `characterSize`, so changing the size moves the
/// whole rig — roam, hop, padding, the panel, the clearance from the pill and the
/// screen-edge clamps — together. Independently-picked numbers are exactly the bug this
/// avoids: 30pt of padding against a 26pt roam range put the character 10pt over its own
/// window, which clips a walking character's leading edge at the extremes of every
/// stroll.
///
/// A value rather than a wall of statics on `CompanionWindow`, because the size is a
/// user preference: "the geometry" is a function of it, and a test can hold one of these
/// per offered size instead of trusting a single global to be the only size that ships.
struct CompanionGeometry: Equatable {

    /// The rendered size of the character.
    let characterSize: CGFloat

    init(characterSize: CGFloat) { self.characterSize = characterSize }

    init(_ size: CompanionSize) { self.init(characterSize: size.points) }

    // MARK: The motion budget

    /// Extra room for the poses that scale the character up.
    ///
    /// Two scales multiply and both have to be budgeted: the pose's own `squash`
    /// (peaking at 1.16 on `stretch`) and the view's hover lift (`scaleEffect` 1.10).
    ///
    /// Not private: `SpritePackStore` sizes its decoded frames from these, because the
    /// largest a frame is ever drawn is `characterSize * maxPoseScale * hoverScale` and
    /// every pixel past that is decoded, held and then discarded by the renderer.
    static let maxPoseScale: CGFloat = 1.16
    /// Read by the container view, which applies it.
    static let hoverScale: CGFloat = 1.10

    /// How far the character may stray from its home spot, in each direction.
    ///
    /// The companion's whole charm is orbiting its spot, so this is small on purpose: a
    /// pet that wanders 200pt off is just a second floating window.
    ///
    /// A fraction of the character rather than a fixed 18pt, so the motion keeps its
    /// proportions at every size — a fixed roam reads as a progressively smaller shuffle
    /// as the character grows.
    var roamRange: CGFloat { characterSize * 0.41 }

    /// Vertical clearance for a hop. Scaled with the character, same reasoning as
    /// `roamRange`.
    var hopHeight: CGFloat { characterSize * 0.32 }

    /// Hovering mid-stretch gives 1.16 x 1.10 = 1.276, which needs
    /// `characterSize * 0.276 / 2` of slack — at 52pt that is 8.2pt against the 4.2pt a
    /// `0.16`-only figure allowed, so the character's top was clipped in exactly the case
    /// this constant exists to prevent.
    private var stretchSlack: CGFloat {
        characterSize * (Self.maxPoseScale * Self.hoverScale - 1) / 2 + 1
    }

    /// How far the panel's edge sits from the character's *centre* — half of `panelSide`,
    /// and not a margin added around the character. Reading the name as a margin is
    /// exactly what put a spare `characterSize` in the panel.
    ///
    /// Derived, not chosen: a borderless panel clips its content, so every point the
    /// character can reach has to be inside the window or it is sliced at the edge
    /// mid-stride. The budget is how far the character's *edge* can get from centre —
    /// half its width, plus the roam distance, plus the slack a stretch adds.
    private var padding: CGFloat {
        characterSize / 2 + max(roamRange, hopHeight) + stretchSlack
    }

    /// The panel is square, and this is its side: the reach budget on each side of the
    /// character's centre, and nothing else.
    ///
    /// It read `characterSize + padding * 2`, which counted the character twice —
    /// `padding` is measured from *centre* and already contains half of it. That made the
    /// panel 3.1x the character rather than 2.1x (163pt around a 52pt character), and the
    /// surplus 26pt on each side is transparent margin that sat over the pill's capsule.
    /// This window is a level above the pill's, so wherever it overlaps it takes the
    /// mouse: hovering the pill's left half, or its microphone glyph, never reached the
    /// pill at all and its hands-free control stayed hidden.
    ///
    /// Not private: it is the bound the character's reach has to stay inside, and the
    /// test that checks that relationship has to be able to name it rather than
    /// re-deriving it and agreeing with a bug.
    var panelSide: CGFloat { padding * 2 }

    /// Horizontal clearance between the *panel's* inner edge and the pill's capsule.
    ///
    /// From the panel, not from the character, and that is the other half of the
    /// `panelSide` fix: the panel is exactly the character's reach envelope now, so a
    /// placement that clears the capsule by this much clears it for the window (the
    /// defect — an overlapping window swallows the pill's hover) *and* for the art (which
    /// cannot leave the panel to reach the capsule).
    ///
    /// It was `roamRange + 4` measured from the character's resting edge, which still left
    /// the corrected panel 2.0pt (at 36) to 8.6pt (at 84) over the capsule. Fixed rather
    /// than a fraction of the character because it budgets no motion any more — the roam
    /// is inside the panel. 2pt, so that the backing-store rounding of a window origin and
    /// a `capsuleWidth` measured to a fraction of a point cannot round the two windows
    /// back into contact.
    static let clearanceFromCapsule: CGFloat = 2

    // MARK: What the art can reach

    /// How far above the panel's centre the character's art can actually reach.
    ///
    /// The vertical budget `clampedY` needs, and deliberately *not* `padding`: that
    /// budgets `max(roamRange, hopHeight)` because it has to cover horizontal roaming
    /// too, and it measures from the character's *frame* rather than from what a pose
    /// draws.
    ///
    /// Two things stack, and only one of them was being counted:
    ///
    ///   * `hopHeight` — the offset a hop lifts the character by, and
    ///   * the pose scales — `squash` grows the frame from its `.bottom` anchor and the
    ///     hover lift then scales the result about its centre.
    ///
    /// The `- 0.5` is the part worth being careful about, and the reason `stretchSlack`
    /// is not reusable here: `squash` is anchored at `.bottom`, so the frame's top rises
    /// by the *whole* `characterSize * (squash - 1)` rather than half of it. At
    /// 1.16 x 1.10 the frame's top reaches 0.726 of the character above centre, not the
    /// 0.638 a centre-anchored reading gives.
    ///
    /// Combining the full hop offset with the full stretch scale is deliberately
    /// pessimistic — a hop squashes to 1.10 and holds `lean` at 0, a stretch reaches 1.16
    /// but never leaves the ground.
    private var maxReachAboveCentre: CGFloat {
        hopHeight + characterSize * (Self.maxPoseScale - 0.5) * Self.hoverScale
    }

    /// How far to either side of the panel's centre the character's art can reach.
    ///
    /// The horizontal counterpart, and it needs the pose scales for the same reason the
    /// vertical one does: `squash` conserves volume, so it scales x by `1/squash` — the
    /// extremes it reaches (1.16 stretching, 0.86 landing -> 1.163 wide) are the same
    /// magnitude, so `maxPoseScale` bounds the width as well as the height. Budgeting
    /// `roamRange` alone (which the old clamp did) let a hovering character at the roam
    /// extreme hang several points off the screen edge.
    ///
    /// `pose.lean` is the one thing this does not model: `stretch` rotates by up to 8
    /// degrees about its `.bottom` anchor while it scales, which swings the squashed box's
    /// top corner out to 0.647 of the character rather than 0.638. The `+1` in
    /// `stretchSlack` is what absorbs it — measured against `panelSide`, the worst pose at
    /// the roam extreme leaves 0.67pt of panel at 36pt and 0.24pt at 84pt, and that is
    /// with the art assumed to fill the very corner of its frame, which sprite art does
    /// not. Adding the rotation to the model would move the panel by under a point at
    /// every size on the ladder.
    private var maxReachAsideCentre: CGFloat {
        roamRange + characterSize / 2 * Self.maxPoseScale * Self.hoverScale
    }

    /// The highest point the character's art can reach, for a panel placed at
    /// `panelOriginY`. This is the quantity the vertical clamp exists to keep on screen,
    /// named so a test can assert on it instead of re-deriving the geometry and agreeing
    /// with a bug.
    func characterTop(panelOriginY: CGFloat) -> CGFloat {
        panelOriginY + panelSide / 2 + maxReachAboveCentre
    }

    /// The character's resting baseline. `squash` is anchored here, so no pose moves it
    /// down; only the hover lift does, and that is bounded by `padding`.
    func characterBottom(panelOriginY: CGFloat) -> CGFloat {
        panelOriginY + panelSide / 2 - characterSize / 2
    }

    /// The leftmost point the character's art can reach, at the far end of a stroll.
    func characterLeft(panelOriginX: CGFloat) -> CGFloat {
        panelOriginX + panelSide / 2 - maxReachAsideCentre
    }

    /// The rightmost point the character's art can reach, at the far end of a stroll.
    func characterRight(panelOriginX: CGFloat) -> CGFloat {
        panelOriginX + panelSide / 2 + maxReachAsideCentre
    }

    // MARK: Inside the note card

    /// The size the character is drawn at when the note card is drawing it instead of the
    /// desktop panel.
    ///
    /// A fixed number and deliberately *not* the user's `CompanionSize`: that preference
    /// governs the desktop companion, a window with a whole display to roam in, where
    /// inside a 292x124pt card the character is a passenger. At `huge` it would be 84pt —
    /// two thirds of the card's height.
    ///
    /// 36pt, and the bracket is tight enough that it is the only number in it:
    ///
    ///   * **At least 36**, which is `CompanionSize.small.points` — the documented floor
    ///     for art that reads as a character at a glance rather than on inspection. Below
    ///     it the face, which is the entire point of having moods, is a handful of pixels.
    ///   * **At most 39.6**, because frames are decoded once, capped at
    ///     `SpritePackStore.maxFrameSide(for:)` of the size the *user* chose — 92px for
    ///     someone on `small` (36 x 1.16 x 1.10 x 2). Drawing at `S` needs
    ///     `S x maxPoseScale x 2` px on a retina display, so anything past 39.6 upscales a
    ///     bitmap that was decoded smaller and the character goes soft. That would land on
    ///     exactly the users who asked for the smallest character.
    ///
    /// `hoverScale` is absent from that second bound on purpose: the card's character
    /// carries no hover, no poke and no drag. It is a passenger, not a control.
    static let inCardCharacterSize: CGFloat = 36

    // MARK: Keeping it on screen

    /// Vertical placement, kept inside the screen.
    ///
    /// The x axis was clamped and y was not: the panel extends well above and below the
    /// character, and the window sits above the menu bar's own level — so it draws *over*
    /// the menu bar rather than being clipped by it. A companion at the top of the screen
    /// put the character on top of the menu bar.
    ///
    /// Subtracting `hopHeight` from the lower bound (an earlier attempt) was backwards: a
    /// hop lifts the character *up*, away from the bottom edge, so it needs no bottom
    /// allowance at all. It needs it at the top instead.
    ///
    /// The top bound used `padding - hopHeight`, which counted the hop but not the pose
    /// scales stacked on top of it, and `padding` measures the character's *frame* rather
    /// than what a pose draws. So the character's head still cleared `visible.maxY`: at
    /// 44pt, hovering at the apex of a hop put it 7.0pt over, and the overshoot grew with
    /// the character (4.5pt at 28pt) — which is exactly why it has to be a function of
    /// the size rather than a number that was right once.
    ///
    /// Takes the `visibleFrame` rather than an `NSScreen` so it can be tested: the cases
    /// that matter — a menu bar, a Dock, a short display — cannot be constructed in a
    /// test, and the visible frame is the only thing about the screen this ever used.
    func clampedY(desired: CGFloat, visible: CGRect) -> CGFloat {
        // Bound the CHARACTER's box, not the panel's. The panel is mostly transparent
        // padding, so clamping its edges to the screen drags the character off its own
        // centre line — which is what left it sitting high and half out of frame.
        //
        // Written as the inverse of `characterBottom`, so this bound and the thing it
        // bounds cannot drift apart. It used to read `visible.minY - padding`, which was
        // the same number only because `panelSide` double-counted the character: with the
        // panel corrected that expression puts the character's *centre* on `minY` and cuts
        // its feet off by half its height.
        let lowest = visible.minY - (panelSide / 2 - characterSize / 2)
        let highest = visible.maxY - panelSide / 2 - maxReachAboveCentre
        guard lowest <= highest else { return desired }
        return min(max(desired, lowest), highest)
    }

    /// Horizontal placement, kept inside the screen.
    ///
    /// Bounds the character's *reach*, not its rest position: `behaviour.offsetX` is
    /// applied in the view after placement, so a panel whose rest position was legal
    /// still put the character `roamRange` off the edge at the end of a stroll.
    func clampedX(desired: CGFloat, visible: CGRect) -> CGFloat {
        let inset = panelSide / 2 - maxReachAsideCentre   // panel edge → the roam extreme
        let lowest = visible.minX - inset
        let highest = visible.maxX - panelSide + inset
        guard lowest <= highest else { return desired }
        return min(max(desired, lowest), highest)
    }

    // MARK: Dragging

    /// The panel origin after a SwiftUI drag translation, clamped to the screen.
    ///
    /// SwiftUI's y grows downward and AppKit's upward, so the translation's height is
    /// subtracted. Pure, so the drag math — the sign convention, and that away from an edge
    /// the character tracks the cursor 1:1 — is pinned by a test rather than only exercised
    /// through a live gesture that a headless test cannot drive. `CompanionWindow.dragBy`
    /// calls exactly this, so the shipped path is the tested one.
    func draggedOrigin(from origin: CGPoint, translation: CGSize, visible: CGRect) -> CGPoint {
        CGPoint(x: clampedX(desired: origin.x + translation.width, visible: visible),
                y: clampedY(desired: origin.y - translation.height, visible: visible))
    }

    /// Keep the exact point the user grabbed under the global cursor.
    func draggedOrigin(cursor: CGPoint, grabOffset: CGSize, visible: CGRect) -> CGPoint {
        CGPoint(
            x: clampedX(desired: cursor.x - grabOffset.width, visible: visible),
            y: clampedY(desired: cursor.y - grabOffset.height, visible: visible)
        )
    }

    // MARK: The speech bubble
    //
    // `quipBubbleMaxLines(lineHeight:verticalPadding:cap:)` lived here. It measured the room
    // from `characterSize` above the panel's centre *down to the panel's far edge* — i.e. it
    // budgeted the whole panel below the anchor, because the bubble it sized deliberately grew
    // downward over the character. That is the overlap the bubble was rebuilt to stop, so
    // keeping the function would have left a doc comment describing behaviour the app no
    // longer has.
    //
    // Its replacement is `bubbleHeadroom` / `bubbleMaxHeight` / `bubbleMaxWidth` in
    // `CompanionBubble.swift`, which bound the strip *above* the character's resting frame
    // instead, and `CompanionBubble.room(in:)`, which solves the type size and line budget
    // from them. They live beside the view they serve because the answer now depends on the
    // font as well as on the panel.

    // MARK: The saved position

    /// The character's centre as a fraction of the visible frame.
    ///
    /// A fraction rather than the point itself, for the reason `PillWindow.savePosition`
    /// gives: an absolute origin saved on a 6K display is off screen on a laptop, so a
    /// display or resolution change would strand the companion somewhere unreachable.
    ///
    /// The *centre*, and not the panel's origin, because the panel's size is a
    /// preference: the character is what the user positioned, and it stays put across a
    /// resize (`applyPreferredSize` grows the panel about its centre), so storing the
    /// origin would have meant a size change quietly moved the saved spot by half the
    /// difference — up to 24pt between the ends of the ladder — and only revealed it on
    /// the next launch.
    static func fraction(ofCentre centre: CGPoint, in visible: CGRect) -> CGPoint {
        CGPoint(x: (centre.x - visible.minX) / max(visible.width, 1),
                y: (centre.y - visible.minY) / max(visible.height, 1))
    }

    /// The panel origin a saved centre-fraction restores to on `visible`.
    ///
    /// Clamped on the way out, so a fraction that was fine on the display it was saved on
    /// cannot put the character over the menu bar or off the edge of a smaller one. The
    /// clamps are idempotent, so restoring a position that was already legal is exact.
    func origin(forCentreFraction fraction: CGPoint, in visible: CGRect) -> CGPoint {
        let centreX = visible.minX + fraction.x * visible.width
        let centreY = visible.minY + fraction.y * visible.height
        return CGPoint(
            x: clampedX(desired: centreX - panelSide / 2, visible: visible),
            y: clampedY(desired: centreY - panelSide / 2, visible: visible)
        )
    }
}
