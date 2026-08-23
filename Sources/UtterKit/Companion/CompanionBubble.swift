import SwiftUI
import AppKit

// MARK: - What the bubble is showing
//
// The bubble used to be one `Text` fed by a `String`, so the three things it carries — a
// dictation failure, a live pomodoro countdown, a note the user pinned — arrived
// indistinguishable from each other. A countdown is a number, a failure is a failure and a
// reminder is a nudge; a reader should not have to parse the words to work out which.
//
// The kind is derived from state that already exists on `CompanionBehaviour` (see
// `CompanionContainerView.notice`), never from sniffing the string. That matters because the
// text can be the *user's own* pinned words, and a classifier that reads them would change
// what the icon says depending on what someone typed.

/// Which of the companion's four kinds of message the bubble is carrying.
enum CompanionNoticeKind: Equatable {
    /// Dictation failed. The line is the reason.
    case failure
    /// The pomodoro countdown, `mm:ss`, updated once a second.
    case timer
    /// A reminder that just fired — stretch, water, a block boundary, a timed message.
    case reminder
    /// The note the user pinned above the character's head.
    case pinned

    /// SF Symbols only, and one per kind.
    ///
    /// The symbol is what actually distinguishes the kinds: hue is a *second* cue, not the
    /// only one, because two of the four share a tint and because colour alone fails WCAG
    /// 1.4.1. All four ship in SF Symbols 1 (macOS 11), which is below this app's 13.3 floor,
    /// so none of them needs an availability branch.
    var symbol: String {
        switch self {
        case .failure: return "exclamationmark.triangle.fill"
        case .timer: return "timer"
        case .reminder: return "bell.fill"
        case .pinned: return "pin.fill"
        }
    }

    /// The glyph's colour.
    ///
    /// **Only one kind is coloured, and that is a measurement rather than restraint.** A glyph
    /// is a non-text graphical object, so its floor is WCAG 1.4.11's 3:1 rather than 4.5:1.
    /// Measured against `CompanionBubble.surfaceAlpha` composited over the two extreme
    /// wallpapers, worst case over all six themes. The first two rows are
    /// `CompanionBubbleTests.glyphTintsAreLegible`; the third is a one-off measurement of a
    /// theme's own accent, untransformed:
    ///
    ///     Ink.primary        7.04:1   (Graphite over a white desktop)   ✓
    ///     Tint.dangerText    3.26:1   (Graphite over a white desktop)   ✓
    ///     theme accent raw   2.13:1   (Paper over a black desktop)      ✗ under 3:1
    ///
    /// `Tint.accentText` was the first choice for the three non-failure kinds, and it was
    /// rejected as a design decision rather than on contrast: it clears 3:1 in every
    /// configuration the app can actually draw (worst 5.90:1, Violet over a white desktop).
    /// It is also derived from the **active** theme rather than from the surface it sits on, so
    /// it cannot be measured per theme without mutating the shared `ThemeManager` — which is
    /// its own reason not to spend it on a glyph that floats over the desktop.
    ///
    /// So colour is spent on the one kind where it carries weight, and never as the only cue —
    /// the symbol differs for all four (WCAG 1.4.1), and `spokenKind` says it in words.
    var glyphTint: Color {
        switch self {
        case .failure: return Tint.dangerText
        case .timer, .reminder, .pinned: return Ink.primary
        }
    }

    /// Whether the headline is a **live value** rather than a sentence.
    ///
    /// Only the countdown is, and it needs monospaced digits for a reason that is about motion
    /// rather than typography: it is rewritten once a second by
    /// `CompanionBehaviour.setPomodoroCountdown`, and the bubble sizes to its content and is
    /// centred over the character. With proportional digits every tick changes the string's
    /// width, so the whole bubble would shimmy left and right at 1 Hz, in a floating window, for
    /// the length of a focus block. `Typo.timestamp` exists for exactly this and is not used
    /// here only because its ink is `Ink.secondary` (see `CompanionBubbleView.text`).
    ///
    /// The minute rollover (9:59 → 10:00) does still add a character, because the format is
    /// `%d:%02d`. That is once a block rather than once a second.
    var isLiveValue: Bool { self == .timer }

    /// How VoiceOver names the kind, since the glyph itself is not read out.
    var spokenKind: String {
        switch self {
        case .failure: return "Dictation failed"
        case .timer: return "Focus timer"
        case .reminder: return "Reminder"
        case .pinned: return "Pinned note"
        }
    }
}

/// One message above the character's head.
struct CompanionNotice: Equatable {
    let kind: CompanionNoticeKind
    /// The headline. Wraps; never a fragment of a truncated line if there is room.
    let line: String
    /// A second, quieter line, or nil. Only populated when there is genuinely a second
    /// thing to say — today that is a pinned note surviving underneath a countdown or a
    /// reminder, which the single-line bubble dropped for the whole of a focus block.
    let detail: String?

    /// The bubble is the companion's only textual output and the character itself is
    /// `.accessibilityHidden(true)`, so this label is the *only* way a VoiceOver user learns
    /// a reminder fired at all.
    var accessibilityLabel: String {
        var text = "\(kind.spokenKind): \(line)"
        if let detail, !detail.isEmpty { text += ". \(detail)" }
        return text
    }
}

// MARK: - Metrics
//
// Every number the bubble needs, in one place, because they are all fractions of a panel
// this file does not own. See `CompanionGeometry+bubble` below for the one that matters.

enum CompanionBubble {

    /// How far the bubble's top edge stays inside the panel's own top edge.
    ///
    /// The panel is borderless and *clips*, and the bubble's rim is drawn by `strokeBorder`
    /// — i.e. inside the shape's own bounds — so in principle 0 would not clip anything.
    /// 1pt (two device pixels on a retina display) is here for the same reason
    /// `CompanionGeometry.clearanceFromCapsule` is 2: `clampedY` permits the panel's top
    /// edge to sit up to `panelSide / 2 - maxReachAboveCentre` — measured 1.07pt at 36 and
    /// 1.17pt at 84 — *above* the screen's visible top, so the outermost row of the panel is
    /// not reliably on screen when the companion is dragged to the top of the display.
    static let panelInset: CGFloat = 1

    /// Padding inside the bubble.
    ///
    /// Vertical is 2.5 and it is *solved for*, not chosen: it is the largest value at which
    /// a `large` (68pt) companion still fits two 12pt lines above its own head. At 3pt it
    /// fits 1 — the margin is 0.24pt. That single number is the clearest statement of how
    /// full this panel is, and it is why the vertical padding is not a `Space` token.
    static let horizontalPadding = Space.x2
    static let verticalPadding: CGFloat = 2.5
    /// Between the glyph and the text.
    static let glyphGap = Space.x1

    /// Corner radius. Clamped by SwiftUI to half the height, so the one-line bubble (18-20pt
    /// tall) renders as a capsule and the two-line one as a rounded card — which is the right
    /// read for each without a second shape.
    static let cornerRadius = Radius.field

    static var shape: RoundedRectangle { Radius.rect(cornerRadius) }

    // MARK: The surface's opacity

    /// How opaque the bubble's themed wash is, over whatever the desktop happens to be.
    ///
    /// **`Veil.nestedSurface`'s *light* value, deliberately used in both appearances.** Every
    /// other surface in the app sits inside a window, which is why the dark ramp is allowed to
    /// be thinner — `Veil`'s own note: "there is far less luminance behind the window to show
    /// through". This bubble has no window behind it. It floats in a transparent panel over an
    /// *arbitrary wallpaper*, so the dark assumption does not hold, and at 0.62 it fails.
    /// Modelling the material as fully transparent (the conservative bound — see the test),
    /// `Ink.primary` over a white desktop measured
    ///
    ///     at 0.62   Graphite 3.47   Pine 3.97   Violet 4.12   Ember 4.28    all under 4.5
    ///     at 0.86   Graphite 7.04   Pine 8.67   Violet 9.20   Ember 9.67    all clear
    ///
    /// in the app's only surface whose backdrop is unknown. 14% of the desktop still shows
    /// through at 0.86, so it still reads as a material rather than a plate.
    ///
    /// Not a new constant: it is `Veil`'s existing number, applied under a different rule.
    static var surfaceAlpha: Double { Veil.nestedSurface(isDark: false) }

    /// The extra wash to lay over `glassSurface(.content)`'s own veil to reach
    /// `surfaceAlpha`.
    ///
    /// Two washes of the same colour compose as `1 - (1 - a)(1 - b)`, so the lift that takes
    /// `base` to `surfaceAlpha` is `(surfaceAlpha - base) / (1 - base)`. In light appearance
    /// the base already *is* `surfaceAlpha`, so this is 0 and the layer is a no-op; in dark it
    /// is 0.632. Under Reduce Transparency `ContentGlass` fills opaquely underneath, so the
    /// lift lands on an opaque surface and changes nothing — which is why this needs no branch
    /// of its own.
    static func veilLift(isDark: Bool) -> Double {
        let base = Veil.nestedSurface(isDark: isDark)
        guard base < surfaceAlpha else { return 0 }
        return (surfaceAlpha - base) / (1 - base)
    }

    // MARK: Type

    /// One rung of the type ladder: a `Typo` token and the line height it actually occupies.
    struct TypeStep: Equatable {
        let typo: Typo
        let size: CGFloat
        /// `NSLayoutManager.defaultLineHeight(for:)` of the token's font, which is what a
        /// `Text` line occupies. Hardcoded rather than measured at each call because it is a
        /// constant of the system font, and pinned by `lineHeightsAreStillWhatWasMeasured`
        /// so an OS metric change fails the build instead of silently clipping a line.
        let lineHeight: CGFloat
        /// `Typo`'s own spacing between wrapped lines.
        var lineGap: CGFloat { typo.lineSpacing }
    }

    /// The smallest rung, and the fallback when even it does not fit — named separately so
    /// `room(in:)` needs no force-unwrap of the ladder's last element.
    ///
    /// It exists for one measured case: at `small` (36pt) the room above the character's head is
    /// 19.73pt, and a 12pt line needs 15 + 2 x 2.5 = 20. It misses by 0.27pt. 11pt
    /// (`Typo.keycap`) needs 18 and fits. Without this rung the smallest companion would show a
    /// clipped line or none at all.
    static let smallestStep = TypeStep(typo: .keycap, size: 11, lineHeight: 13)

    /// Largest first. Two rungs, and both are existing `Typo` tokens.
    static let typeLadder: [TypeStep] = [
        TypeStep(typo: .captionEmphasis, size: 12, lineHeight: 15),
        smallestStep,
    ]

    /// What fits above the character, at one companion size.
    struct Room: Equatable {
        let step: TypeStep
        /// Total lines the bubble may use, headline plus detail.
        let lines: Int
        /// The widest the bubble may be — the panel, less its inset on each side.
        let maxWidth: CGFloat
        /// The tallest it may be without reaching the character's resting art.
        let maxHeight: CGFloat

        /// How the line budget is split between the headline and the detail line.
        ///
        /// The detail is **dropped** rather than allowed to take the headline's only line: a
        /// pinned note underneath a countdown is a bonus, and a headline truncated to nothing
        /// is a failure. So at `small` and `medium` — 1 line — the detail never appears.
        ///
        /// Here rather than in the view so the rule has one copy and a test can hold it.
        func split(hasDetail: Bool) -> (headline: Int, showsDetail: Bool) {
            guard hasDetail, lines >= 2 else { return (lines, false) }
            return (lines - 1, true)
        }
    }

    /// Solve the type size and line budget for a companion size.
    ///
    /// Pure, and takes the geometry rather than reading the preference, so every rung of the
    /// size ladder is checkable in a test instead of only the one the developer happens to be
    /// running.
    static func room(in geometry: CompanionGeometry) -> Room {
        let maxHeight = geometry.bubbleMaxHeight
        let textBox = maxHeight - verticalPadding * 2
        // The largest rung whose single line fits; the smallest rung if none does, so the
        // bubble degrades to slightly-clipped rather than to nothing.
        let step = typeLadder.first { $0.lineHeight <= textBox } ?? smallestStep
        // n lines occupy n * lineHeight + (n - 1) * lineGap.
        let lines = Int(((textBox + step.lineGap) / (step.lineHeight + step.lineGap)).rounded(.down))
        return Room(step: step,
                    lines: max(1, lines),
                    maxWidth: geometry.bubbleMaxWidth,
                    maxHeight: maxHeight)
    }
}

// MARK: - Where the bubble can live

/// The panel geometry the bubble is bounded by.
///
/// An extension rather than lines in `CompanionGeometry` for the same reason that type is a
/// value: the panel's size is a user preference, so "where the bubble fits" is a function of
/// it, and a test can hold one of these per offered size.
///
/// **The finding these four properties encode.** `panelSide` is *exactly* the character's
/// reach envelope by construction, so the only region of the panel the character cannot enter
/// is a ~1pt margin (`panelSide / 2 - maxReachAboveCentre`: 1.07pt at 36, 1.17pt at 84). A
/// bubble that never overlaps the *moving* character therefore cannot exist inside this panel
/// at any size. What can exist is a bubble that never overlaps the character at *rest*, and
/// that is what these bound. The top strip is chosen over the side strips because the vertical
/// motion budget is the smaller one — `hopHeight` (0.32 x size) against `roamRange` (0.41 x
/// size) — so the top is where the character intrudes least.
extension CompanionGeometry {

    /// Free height between the panel's top edge and the top of the character's resting frame.
    ///
    /// Equal to `max(roamRange, hopHeight) + stretchSlack` — i.e. the panel's entire vertical
    /// motion budget. Measured: **20.73pt at 36, 29.50 at 52, 38.26 at 68, 47.03 at 84.**
    var bubbleHeadroom: CGFloat { panelSide / 2 - characterSize / 2 }

    /// The tallest the bubble may be. `bubbleHeadroom` less the panel inset.
    var bubbleMaxHeight: CGFloat { bubbleHeadroom - CompanionBubble.panelInset }

    /// The widest the bubble may be. The full panel: it is transparent either side of the
    /// character, and a bubble narrower than the panel wastes the only axis with room to spare.
    var bubbleMaxWidth: CGFloat { panelSide - CompanionBubble.panelInset * 2 }

    /// How far the character's art rises **into** the bubble's strip at the peak of a hop with
    /// a stretch on top — the overlap this panel cannot avoid.
    ///
    /// Derived from `characterTop(panelOriginY:)` rather than restating the pose arithmetic, so
    /// this figure and the clamp that keeps the character on screen cannot drift apart.
    /// Measured: **19.66pt at 36, 28.39 at 52, 37.13 at 68, 45.86 at 84** — against
    /// `bubbleHeadroom` of 20.73 / 29.50 / 38.26 / 47.03, i.e. a margin of 1.07 / 1.11 / 1.13 /
    /// 1.17pt. `CompanionGeometryTests.headroomIsAlmostEntirelyTheMotionBudget` pins it.
    var characterMotionAboveRest: CGFloat {
        characterTop(panelOriginY: 0) - panelSide / 2 - characterSize / 2
    }
}

// MARK: - The bubble

/// The companion's speech bubble: one glyph, one headline, one optional detail line, on the
/// app's own content material.
///
/// **Display only.** The panel cannot become key (`CompanionWindow.canBecomeKey` is false) and
/// the bubble is `allowsHitTesting(false)` at its call site, so there is nothing interactive
/// here and no tooltip either — a tooltip needs a hover the view cannot receive.
struct CompanionBubbleView: View {
    let notice: CompanionNotice
    let geometry: CompanionGeometry

    var body: some View {
        let room = CompanionBubble.room(in: geometry)
        let budget = room.split(hasDetail: !(notice.detail ?? "").isEmpty)

        return HStack(alignment: .firstTextBaseline, spacing: CompanionBubble.glyphGap) {
            Image(systemName: notice.kind.symbol)
                // Matched to the text's own point size, so the glyph and the headline sit on
                // one optical line at every rung of the ladder.
                .font(.system(size: room.step.size, weight: .semibold))
                .foregroundStyle(notice.kind.glyphTint)

            VStack(alignment: .leading, spacing: 0) {
                // Monospaced digits on the headline only, and only for the countdown; the detail
                // line beneath it is prose. See `CompanionNoticeKind.isLiveValue`.
                text(notice.line, room: room, limit: budget.headline,
                     monospaced: notice.kind.isLiveValue)
                if budget.showsDetail, let detail = notice.detail {
                    text(detail, room: room, limit: 1, monospaced: false)
                }
            }
        }
        .padding(.horizontal, CompanionBubble.horizontalPadding)
        .padding(.vertical, CompanionBubble.verticalPadding)
        .background(.regularMaterial, in: CompanionBubble.shape)
        .overlay {
            CompanionBubble.shape.strokeBorder(
                Color(nsColor: .separatorColor).opacity(0.65),
                lineWidth: 0.5
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notice.accessibilityLabel)
    }

    /// One line of the bubble.
    ///
    /// `ink: Ink.primary` on **both** lines, and that is a measurement rather than a
    /// preference. `Typo.captionEmphasis` and `.keycap` both default to `Ink.secondary`, which
    /// on this surface fails in 3 of the 12 theme/wallpaper pairs — worst **3.66:1** (Graphite
    /// over a white desktop), then 4.29 (Linen over black) and 4.35 (Paper over black), against
    /// a 4.5:1 floor. It passes on the other nine, which is exactly why it cannot be used: the
    /// three it fails on are wallpaper-dependent, so a user would find the detail line
    /// unreadable by changing their desktop picture.
    ///
    /// So there is no second ink level here. The two lines are separated by **order and
    /// truncation** instead — the detail sits below, gets exactly one line, and is the first
    /// thing dropped when the budget is one line.
    private func text(_ string: String, room: CompanionBubble.Room,
                      limit: Int, monospaced: Bool) -> some View {
        Text(string)
            .typo(room.step.typo, ink: Ink.primary)
            // `Font.monospacedDigit()` rather than the `View` modifier, so it composes with the
            // font `typo` just set instead of resolving against the environment's default.
            .font(monospaced ? room.step.typo.font.monospacedDigit() : room.step.typo.font)
            .multilineTextAlignment(.leading)
            .lineLimit(limit)
            .truncationMode(.tail)
            // Shrinks a single over-wide word rather than truncating it — at `small` the text
            // column is 45pt, which one long word can exceed on its own.
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }
}
