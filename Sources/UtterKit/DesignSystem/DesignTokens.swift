import SwiftUI
import AppKit

// MARK: - Surfaces
//
// Semantic backgrounds derived from NSColor so light/dark/increase-contrast are
// handled by the OS. Never hand-tune a hex per appearance.

enum Surface {
    /// The window canvas, behind everything. Themed when the active theme
    /// defines its own surfaces; system otherwise.
    static var canvas: Color {
        ThemeManager.shared.current.canvas ?? Color(nsColor: .windowBackgroundColor)
    }
    /// A raised card sitting on `canvas`. Always pair with `Line.hairline`.
    static var raised: Color {
        ThemeManager.shared.current.raised ?? Color(nsColor: .controlBackgroundColor)
    }
    /// Editable wells: TextEditor, TextField backgrounds.
    static var sunken: Color {
        ThemeManager.shared.current.sunken ?? Color(nsColor: .textBackgroundColor)
    }

    // Adaptive overlay fills. `Color.primary` inverts per appearance, so these
    // read as a light wash in dark mode and a dark wash in light mode.
    static let fillSubtle = Color.primary.opacity(0.04)
    static let fillMuted = Color.primary.opacity(0.07)
    /// A hover wash — safe **only** where the rest state is already a `Color.primary` wash.
    ///
    /// `Color.primary` inverts per appearance, so this darkens in a light theme and lightens in a
    /// dark one. That is correct when it deepens a wash that already runs the same direction, and
    /// it is a bug anywhere the *selected* state is a white lift: the pointer then darkens the row
    /// on hover and the click jumps it light, so one control moves in two directions. That shipped
    /// twice — the main window's sidebar and Settings' group rows — and both now use `SidebarLift`,
    /// whose lifts are white in both appearances and provably ordered. Four remaining uses are
    /// correct because rest is a `Color.primary` wash at 4% and hover is the same wash at 6%.
    static let fillHover = Color.primary.opacity(0.06)
}

// MARK: - Veil (how translucent a surface is)

/// The opacity of the themed wash that sits over a translucent backing.
///
/// Every translucent surface in the app is the same two-layer build: an
/// `NSVisualEffectView` sampling what is behind the window, and a themed colour
/// over it so a theme still reads as itself on any wallpaper. This is the opacity
/// of that second layer — which makes it the number that decides how much desktop
/// shows through, i.e. the entire perceived translucency of the app.
///
/// It was hand-written at seven call sites with seven different values, which is
/// six chances to disagree, and two of them did: Settings ran 0.50/0.38 against
/// the main window's 0.55/0.42, so the window that *opens from* the main window
/// read thinner and cooler than its parent. Nobody could have named the intended
/// difference, because there wasn't one.
///
/// Three roles, and in light mode they are a ramp — **0.42 shell → 0.72 content →
/// 0.86 nested** — so a surface is always more opaque than the surface it sits on.
/// That ordering is the whole point, and it is not decorative: the tiles were once
/// a neutral `.regularMaterial` that landed one unit from the sidebar, and the
/// nesting read backwards (see `ContentGlass`). `VeilRampTests` pins the ordering
/// so a retune cannot invert it again.
///
/// Values are per appearance because dark mode is not the light ramp inverted:
/// there is far less luminance behind the window to show through, so a dark veil
/// can be thinner at the shell and still separate.
enum Veil {
    /// A window's own background: the main window, Settings, Onboarding, a sheet.
    /// Thin, because this is the layer that has to still look like a window over
    /// the desktop.
    static func windowShell(isDark: Bool) -> Double { isDark ? 0.55 : 0.42 }

    /// The plane that carries every screen's text. Substantially more opaque than the shell — it
    /// is read, not looked through.
    ///
    /// Named for an inset content card that no longer exists: the main window is now one
    /// continuous plane with a glass sidebar floating on it, so this *is* the window's surface
    /// there rather than a card sitting on one. The value did not change when the card went,
    /// which is the point — every content pixel kept its tone and only the sidebar strip changed
    /// material.
    static func contentSurface(isDark: Bool) -> Double { isDark ? 0.45 : 0.72 }

    /// A tile or card nested *inside* the content surface. The most opaque of the
    /// three, so it lifts clear of the card behind it rather than merging with it.
    static func nestedSurface(isDark: Bool) -> Double { isDark ? 0.62 : 0.86 }

    // MARK: Pre-macOS-26 tunings
    //
    // Kept as separate values, not folded into the three above. The 13.3 floor is
    // real (set by the prebuilt whisper xcframework), so these branches run on
    // shipping hardware, and they were tuned against a different compositor: with
    // no Liquid Glass above them the same veil reads heavier, so both go thinner.
    // Deleting them to shorten this enum would change what a large share of users
    // actually see.

    /// The content card below macOS 26.
    static func contentSurfaceLegacy(isDark: Bool) -> Double { isDark ? 0.35 : 0.55 }

    /// A sheet below macOS 26. The only role whose pre-26 tuning goes *up* rather
    /// than down: a sheet is the one surface that must stay readable while the
    /// window it covers is still visible behind it.
    static func sheetLegacy(isDark: Bool) -> Double { isDark ? 0.62 : 0.48 }
}

// MARK: - Ink (content)

enum Ink {
    /// Warm near-black / warm near-white, never pure.
    ///
    /// `#26241F` in light and a warm off-white in dark — the reference palette
    /// has no pure black or pure gray anywhere, and pure `labelColor` alongside
    /// warm surfaces looks like a different design system bolted on.
    static let primary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.97, green: 0.96, blue: 0.94, alpha: 1)
            : NSColor(srgbRed: 0.149, green: 0.141, blue: 0.122, alpha: 1)
    })

    /// Supporting text: captions, descriptions, secondary values.
    ///
    /// `NSColor.secondaryLabelColor` alone measured **4.01:1** on the app's
    /// translucent tiles — under the 4.5:1 floor for body text. The system colour
    /// is calibrated against an *opaque* control background; a glass or material
    /// surface sits lighter than that, which closes the gap.
    ///
    /// So this is `labelColor` at a fixed opacity instead: 0.72 lands at ~6:1 on
    /// the tiles while still reading as clearly secondary next to full-strength
    /// primary text.
    ///
    /// Built as an `NSColor(name:dynamicProvider:)` rather than
    /// `secondaryLabelColor.blended(withFraction:of:)`, which looks equivalent
    /// but is not: `blended` *resolves* both dynamic colours immediately, against
    /// whichever appearance happened to be current when this constant
    /// initialised. That baked in one appearance's value and made the text
    /// darker than its own background in the other — measured 0.012 luminance on
    /// a 0.066 surface, i.e. invisible. A dynamic provider re-resolves per
    /// appearance, so light, dark, and Increase Contrast all stay correct.
    static let secondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.72, green: 0.70, blue: 0.67, alpha: 1)
            : NSColor(srgbRed: 0.400, green: 0.380, blue: 0.353, alpha: 1)
    })
    /// Non-essential content only — this fails 4.5:1 contrast. Decorative
    /// glyphs, dividers, and separators; never text the user must read.
    /// Quiet supporting text: micro labels, captions, metadata.
    ///
    /// The three ink levels are deliberately spaced far enough apart to read as a
    /// hierarchy. An earlier pass darkened tertiary for light-mode contrast but
    /// *raised* it in dark mode to 0.70, which put it within 0.08 of secondary at
    /// 0.78 — so primary, secondary and tertiary all converged and every label in
    /// the window looked uniformly greyed out. Dark now runs 0.97 / 0.72 / 0.56.
    ///
    /// Measured at the old value, the uppercase tracked stat labels came out at
    /// **2.68:1** — the least readable text in the window, and below even the
    /// 3:1 large-text floor. Small letter-spaced capitals need *more* contrast
    /// than body text, not less, because each glyph has very little stroke area.
    /// Darkened to clear 4.5:1 on the tile fill.
    static let tertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.56, green: 0.54, blue: 0.51, alpha: 1)
            : NSColor(srgbRed: 0.510, green: 0.490, blue: 0.459, alpha: 1)
    })
    static let quaternary = Color(nsColor: .quaternaryLabelColor)
    /// Placeholder text.
    ///
    /// `NSColor.placeholderTextColor` is a pure neutral grey, which measured
    /// (156,156,156) in the search field — perfectly neutral in an otherwise warm
    /// UI, so it read as dirty rather than quiet. Warmed to match the ramp.
    static let placeholder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.63, green: 0.61, blue: 0.58, alpha: 1)
            : NSColor(srgbRed: 0.66, green: 0.64, blue: 0.61, alpha: 1)
    })
}

// MARK: - Tint (accent + status)

enum Tint {
    /// The active accent: the selected theme's tint, or the user's System
    /// Settings accent when the theme defers to it.
    ///
    /// Computed rather than stored — a `static let` captured the system colour
    /// once at load, which is why choosing a theme appeared to do nothing.
    static var accent: Color {
        ThemeManager.shared.current.accent ?? Color(nsColor: .controlAccentColor)
    }

    /// The accent, used as *text* on a surface.
    ///
    /// A saturated accent that reads well as a fill is often too dark to be text:
    /// the "Grant" links measured **3.70:1** on the dark content card, under the
    /// 4.5:1 floor, because `systemBlue` is tuned for a light backdrop. This
    /// lightens the accent in dark mode so accent-coloured labels stay legible
    /// while keeping the same hue.
    static var accentText: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let base = NSColor(ThemeManager.shared.current.accent
                               ?? Color(nsColor: .controlAccentColor))
            guard let hsb = base.usingColorSpace(.deviceRGB) else { return base }
            if appearance.isDark {
                // Lift brightness, drop saturation: enough to clear the floor
                // without turning the hue pastel.
                return NSColor(
                    hue: hsb.hueComponent,
                    saturation: max(hsb.saturationComponent - 0.22, 0),
                    brightness: min(hsb.brightnessComponent + 0.28, 1.0),
                    alpha: 1
                )
            }
            // Light mode needs the opposite. A warm amber accent that reads well
            // as a fill measured **2.03:1** as the "Grant" link text on cream —
            // and that is an interactive control, so it is the worst place to
            // fail. Deepen it instead, keeping the hue.
            return NSColor(
                hue: hsb.hueComponent,
                saturation: min(hsb.saturationComponent + 0.12, 1.0),
                brightness: max(hsb.brightnessComponent - 0.42, 0),
                alpha: 1
            )
        })
    }
    static var accentSoft: Color { accent.opacity(0.12) }
    static var accentRim: Color { accent.opacity(0.28) }

    // NSColor.system* are appearance-aware (they lighten in dark mode).
    // Color.red and friends are not.
    static let recording = Color(nsColor: .systemRed)
    static let handsFree = Color(nsColor: .systemOrange)
    static let success = Color(nsColor: .systemGreen)
    static let warning = Color(nsColor: .systemYellow)
    static let danger = Color(nsColor: .systemRed)

    // MARK: Status colours used as text
    //
    // `NSColor.system*` are tuned as **fills**, and as 12pt text on this app's own `raised`
    // surfaces they fail badly in a light theme. Measured with the real dynamic colours resolved
    // in each `NSAppearance`, against the themes' actual `raised` values, WCAG 2.x:
    //
    //             Paper   Linen   Graphite  Ember    floor
    //   warning   1.48    1.46      8.41    11.44     4.5
    //   success   2.17    2.14      5.87     7.99     4.5
    //   danger    3.48    3.44      3.46     4.71     4.5
    //
    // Amber at **1.48:1** is invisible on cream, and every one of these is a warning or an error —
    // the strings a user most needs to read. `danger` fails on Graphite too, so it fails in a dark
    // theme as well; this is not a light-mode-only problem.
    //
    // Same fix, and same reasoning, as `accentText` above: keep the hue, move brightness. The
    // amounts are per-colour because the failures differ by an order of magnitude, and each was
    // solved for rather than picked — the minimum that cleared 4.5:1 against the *lightest* light
    // surface (Linen) was -0.45 / -0.26 / -0.10, and these carry a little headroom past that so a
    // future surface tweak does not silently drop one under the floor.
    //
    // Dark mode only touches `danger`: yellow and green already pass comfortably, so adjusting
    // them would change a shipped appearance to fix nothing. Red is desaturated rather than
    // brightened, because a brighter pure red on a dark ground reads as alarm rather than as text.
    //
    // Verified after the change — worst case across all six themes **5.07:1 light, 5.04:1 dark**.
    // `TintContrastTests` pins it.

    /// `warning` as text. rgb(128,102,0) light / unchanged dark.
    static var warningText: Color { statusText(.systemYellow, deepenBy: 0.50, desaturateInDarkBy: 0) }
    /// `success` as text. rgb(17,117,42) light / unchanged dark.
    static var successText: Color { statusText(.systemGreen, deepenBy: 0.32, desaturateInDarkBy: 0) }
    /// `danger` as text. rgb(214,21,25) light / rgb(255,132,134) dark.
    static var dangerText: Color { statusText(.systemRed, deepenBy: 0.16, desaturateInDarkBy: 0.26) }

    /// Shared body of the three above. See the block comment for why the amounts differ.
    private static func statusText(_ base: NSColor,
                                   deepenBy drop: CGFloat,
                                   desaturateInDarkBy desaturate: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            // `deviceRGB` because HSB components are only meaningful in an RGB space; a system
            // colour left in its catalog space returns garbage for `hueComponent`.
            guard let hsb = base.usingColorSpace(.deviceRGB) else { return base }
            if appearance.isDark {
                guard desaturate > 0 else { return base }
                return NSColor(hue: hsb.hueComponent,
                               saturation: max(hsb.saturationComponent - desaturate, 0),
                               brightness: hsb.brightnessComponent,
                               alpha: 1)
            }
            return NSColor(hue: hsb.hueComponent,
                           saturation: min(hsb.saturationComponent + 0.12, 1),
                           brightness: max(hsb.brightnessComponent - drop, 0),
                           alpha: 1)
        })
    }

    // `soft(_:)` (0.12) and `rim(_:)` (0.34) were here, for tinting a fill and its border from
    // one colour. Their last callers were the pill's `stateTint`/`stateRim` tables, deleted as
    // dead code — `stateRim` had no reader at all and `stateTint` existed only to be compared
    // against `.clear`. The named constants that survive (`accentSoft`, `accentRim`) carry the
    // two ratios that are actually used, so a generic helper reachable from nowhere was one more
    // thing to keep in step with no way to notice when it drifted.
}

// MARK: - Lines

enum Line {
    /// Warm hairline, not `separatorColor`.
    ///
    /// The reference design's entire neutral ramp is warm (`#E8E3DB`-class), and
    /// macOS's `separatorColor` is cool blue-gray. Mixing the two is the single
    /// fastest way to make a warm layout look wrong, so the hairline is built
    /// warm and adapts per appearance.
    static let hairline = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 1, green: 0.97, blue: 0.93, alpha: 0.13)
            : NSColor(srgbRed: 0.16, green: 0.13, blue: 0.08, alpha: 0.13)
    })
    static let strong = Color.primary.opacity(0.14)
    static let focus = Color(nsColor: .keyboardFocusIndicatorColor)
    static let width: CGFloat = 1
    static let focusWidth: CGFloat = 3
}

// MARK: - Spacing (4pt base)

enum Space {
    static let x1: CGFloat = 4
    static let x2: CGFloat = 8
    static let x3: CGFloat = 12
    static let x4: CGFloat = 16
    static let x5: CGFloat = 20
    static let x6: CGFloat = 24
    static let x8: CGFloat = 32
    static let x10: CGFloat = 40
    static let x12: CGFloat = 48

    // Semantic aliases — prefer these at call sites; they document intent.
    static let rowPaddingV = x3
    static let rowPaddingH = x4
    static let cardPadding = x5
    static let screenPadding = x8
    static let stackGap = x3
    static let groupGap = x5
    static let headerToContent = x3
}

// MARK: - Corner radius
//
// Fixed values, and they stay fixed. macOS 26 adds `ConcentricRectangle` and the
// `containerShape(_:)` overload that publishes a container's curve — the documented way
// to make a nested surface follow the surface it sits in. It is deliberately **not**
// adopted, because measured against this app's own spacing it would square every corner
// in the window. The measurements are here rather than in a report because the next
// person to read "fixed radius inside a rounded parent" will reach for that API, and the
// arithmetic is the only thing that explains why it is the wrong reach.
//
// Measured on macOS 26.5 by rendering `ConcentricRectangle` offscreen and comparing the
// corner against `RoundedRectangle` references at 1pt scale:
//
//   * `.concentric` resolves to **container radius − inset**. Verified at r24/inset 8 →
//     r16 (pixel-identical to `RoundedRectangle(16, .continuous)`), r16/inset 8 → r8,
//     r40/inset 8 → r32.
//   * The **larger of the two axis insets governs**, not each corner independently:
//     h8/v30 inside r24 rendered fully square, not r16.
//   * A **negative** inset does not extrapolate outward — a child 6pt larger than its
//     container rendered square, not r18.
//   * With no `containerShape` published at all it resolves to **0**: a sharp rectangle,
//     pixel-identical to `Rectangle()`.
//   * `ConcentricRectangle.path(in:)` on its own returns a sharp rectangle for *every*
//     style, `.fixed(12)` included — the corner is resolved in the render pass, not by
//     the shape's own path. So it cannot be wrapped behind a custom shape's `path(in:)`.
//
// Every container/child pair in this app sits at or beyond its container's corner, so
// `.concentric` resolves to 0 at all of them:
//
//   BentoTile / SettingsCard / card()   panel 16   child inset 20 (Space.cardPadding)
//   GlassSelectableRow, ModelRow        card 12    child inset 12 (Space.x3)
//   WordRow / SnippetRow / CommandRow   control 8  child inset 12 h, 4 v
//   MeetingOfferPanel card              panel 16   button row inset 16 (Space.x4)
//
// There is nothing for concentricity to act on: the container's arc has already fully
// turned before the child begins, which makes the child's radius a free choice rather
// than a derived one. `.concentric(minimum:)` would hold today's values — minimum 10
// inside panel 16 at inset 20 measured r10, identical to now — but then the minimum is
// doing all of the work, which is a fixed radius with an availability branch in front
// of it.
//
// Two further blockers if this is ever revisited. `ConcentricRectangle` conforms to
// `Shape` but **not** `InsettableShape`, so it cannot be passed to `glassSurface(_:in:)`
// and cannot take `.strokeBorder`; adopting it means dropping `strokeBorder` at every
// converted site. And `strokeBorder` is already concentric for free —
// `RoundedRectangle(12).inset(by: 4)` renders a path byte-identical to
// `RoundedRectangle(8)` on the inset rect — so every rim in this app already follows
// its own fill's curve, which is the one nested-curve relationship that repeats ~40
// times here.
//
// This becomes worth adopting the moment a surface nests at an inset *smaller* than its
// container's radius on both axes. `ConcentricityTests` pins that condition, so the
// build says so rather than leaving it to be noticed.

enum Radius {
    static let chip: CGFloat = 5
    static let control: CGFloat = 8
    static let field: CGFloat = 10
    static let card: CGFloat = 12
    static let panel: CGFloat = 16

    /// Always continuous — macOS squircles are `.continuous`; `.circular`
    /// reads as web CSS.
    static func rect(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Typography
//
// Body is 15pt. 13pt is the macOS *control* size — right for dense inspectors,
// too tight for a full-window utility, which is why the earlier scale read as
// cramped. Everything calibrates to body. Only three weights ship: regular,
// medium, semibold.
//
// `.rounded` survives in exactly one place: `Typo.wordmark`, where the app names itself as a
// brand — today that is About. The sidebar's mark is deliberately NOT it: there the name sits
// beside a 17pt app icon and takes `.subheading`, because the icon is carrying the brand and a
// rounded face next to it reads as two logos. So the rule is "rounded belongs to the wordmark
// token", not "rounded appears wherever the app's name does". Elsewhere it reads
// friendly/consumer, and Utter is a utility.

enum Typo {
    case wordmark, title, heading, sectionHeader, subheading
    case body, bodyEmphasis, lede, transcript, callout
    case caption, captionEmphasis, numeric, timestamp, mono, keycap
    /// Editorial serif, for hero headlines and large data-card titles only.
    /// Never for UI labels, buttons, or navigation — that split (serif for
    /// editorial voice, SF for interface) is the reference design's strongest
    /// brand cue. New York is macOS's system serif.
    case serifTitle, serifHeading
    /// Small uppercase tracked label: list section heads ("TODAY"), sidebar group
    /// heads, stat captions. A signature of the reference layout.
    case microLabel
    /// Large statistic, as on a metrics card.
    case statNumber

    var font: Font {
        switch self {
        case .wordmark: return .system(size: 19, weight: .semibold, design: .rounded)
        case .title: return .system(size: 24, weight: .semibold)
        case .heading: return .system(size: 17, weight: .semibold)
        case .sectionHeader: return .system(size: 13, weight: .semibold)
        case .subheading: return .system(size: 15, weight: .semibold)
        case .body, .transcript, .lede: return .system(size: 15)
        case .bodyEmphasis: return .system(size: 15, weight: .medium)
        case .callout: return .system(size: 13)
        case .caption: return .system(size: 12)
        case .captionEmphasis: return .system(size: 12, weight: .medium)
        case .numeric: return .system(size: 15).monospacedDigit()
        case .timestamp: return .system(size: 12).monospacedDigit()
        case .mono: return .system(size: 13, design: .monospaced)
        case .keycap: return .system(size: 11, weight: .medium)
        case .serifTitle: return .system(size: 21, design: .serif)
        case .serifHeading: return .system(size: 17, design: .serif)
        case .microLabel: return .system(size: 10, weight: .semibold)
        case .statNumber: return .system(size: 26, weight: .semibold)
        }
    }

    /// Letter spacing. Only the micro label needs it, and it needs it badly —
    /// uppercase at 10pt without tracking reads as a smudge.
    var tracking: CGFloat {
        switch self {
        case .microLabel: return 0.7
        case .keycap: return 0.2
        default: return 0
        }
    }

    var ink: Color {
        switch self {
        case .lede, .callout, .caption, .captionEmphasis,
             .timestamp, .sectionHeader, .keycap:
            return Ink.secondary
        case .microLabel:
            return Ink.tertiary
        default:
            return Ink.primary
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .lede, .transcript: return 4
        case .body, .bodyEmphasis, .callout, .mono: return 3
        case .caption, .captionEmphasis: return 1.5
        default: return 0
        }
    }
}

extension View {
    /// Single entry point for text styling — replaces `.font(.system(size:))`
    /// literals so the scale stays consistent.
    func typo(_ style: Typo, ink: Color? = nil) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(ink ?? style.ink)
            .lineSpacing(style.lineSpacing)
    }
}

// MARK: - Layout metrics

enum Layout {
    /// 45–90 characters at 15pt ≈ 330–660pt. Prose wider than this is a chore
    /// to read, so extra window width becomes margin rather than longer lines.
    static let proseWidth: CGFloat = 640
    /// Transcripts and the scratchpad editor.
    static let readingWidth: CGFloat = 760
    /// The detail column.
    static let contentWidth: CGFloat = 840

    /// Sidebar width.
    ///
    /// 168pt, not the reference's 140. The reference's labels are single short
    /// words; Utter's include "Dictionary" and "Transforms", and the usage card at
    /// the foot of the column wrapped to three lines in the ~100pt of text space
    /// 140pt left it. 168pt gives the card two comfortable lines and the labels
    /// room to breathe, while still keeping the content card clearly dominant.
    ///
    /// Consumed by AppKit, not SwiftUI: the column stopped setting its own `.frame(width:)` when
    /// the window became an `NSSplitViewController`, and this is now the sidebar item's
    /// `minimumThickness` *and* `maximumThickness` (`App.swift`). Equal bounds are what pin the
    /// width and keep the divider undraggable. Value unchanged.
    static let sidebarWidth: CGFloat = 168

    // MARK: Content card
    //
    // `cardInset` (8) and `cardRadius` (12) lived here, for a rounded content card inset into
    // the window with the sidebar as the background behind it. Both went with the card itself
    // when the main window became one continuous plane under a glass sidebar: Apple's macOS 26
    // shell is a single surface with glass floating on it, and a hard-clipped inset card is a
    // flat-fill idiom for separating two opaque planes. Nothing references them now.

    // `toolbarBand` (30) lived here: a band of window left clear at the top for the traffic
    // lights, used as padding standing in for chrome. Both of its callers are gone. The main
    // window dropped it when it became an `NSSplitViewController` with a real `NSToolbar`, and
    // Settings dropped it when it became the same thing — AppKit supplies a measured 66pt band
    // and a 58pt sidebar safe area to both windows now, and the four panes read those. Nothing
    // references it, and a hand-guessed 30 is not interchangeable with a laid-out 66, so it is
    // deleted rather than left for someone to reach for.

    /// Sidebar row pitch — 28pt, from the reference's 26px at 0.9x.
    static let sidebarRowHeight: CGFloat = 28
    /// Standard control height. The reference runs notably compact: 26pt buttons
    /// and toggles against 13pt labels.
    static let buttonHeight: CGFloat = 26

    static let windowMinWidth: CGFloat = 1000
    static let windowMinHeight: CGFloat = 680
    static let windowIdealWidth: CGFloat = 1180
    static let windowIdealHeight: CGFloat = 820

    /// Settings' group list — 152pt, deliberately not the main window's 168.
    ///
    /// Kept as its own number rather than converged. The main window's 168 exists for
    /// "Dictionary"/"Transforms" and for a usage card that wrapped to three lines below it; this
    /// column's longest label is "Diagnostics" and it has no card, so the extra 16pt would buy
    /// nothing — and it would come straight off a detail column that is only 460pt wide at
    /// `settingsMinWidth` (measured: 620 less a 160pt leading safe-area inset), which is the
    /// figure that number was chosen against.
    ///
    /// Consumed by AppKit, not SwiftUI: the column stopped setting its own `.frame(width:)` when
    /// the window became an `NSSplitViewController`, and this is now the sidebar item's
    /// `minimumThickness` *and* `maximumThickness` (`showSettingsWindow`). Equal bounds are what
    /// pin the width and keep the divider undraggable. Value unchanged from the old
    /// `.frame(width: 152)`.
    static let settingsSidebarWidth: CGFloat = 152

    /// Settings. Resizable, so it needs a floor as well as an opening size: the
    /// group list is a fixed `settingsSidebarWidth`, so the minimum width is what
    /// leaves the detail column enough for a card and its rows rather than what the
    /// window can technically draw.
    static let settingsMinWidth: CGFloat = 620
    static let settingsMinHeight: CGFloat = 420
    static let settingsIdealWidth: CGFloat = 720
    static let settingsIdealHeight: CGFloat = 500

    /// Onboarding. The height floor is the tallest step (welcome, with the live pill
    /// demo, ~491pt) plus the progress dots and the nav row; below it the step
    /// content scrolls rather than pushing "Continue" off the bottom edge.
    static let onboardingMinWidth: CGFloat = 520
    static let onboardingMinHeight: CGFloat = 460
    static let onboardingIdealWidth: CGFloat = 620
    static let onboardingIdealHeight: CGFloat = 600

    /// A window content size raised to the minimum it is usable at.
    ///
    /// `NSWindow.setFrameUsingName` replays an autosaved frame verbatim and does not
    /// consult `contentMinSize` — that only constrains the user's own dragging — so
    /// a frame stored while a window was collapsed reopens collapsed. This app has
    /// measured that collapse (see `showMainWindow`), so a too-small stored frame is
    /// a real state, not a hypothetical one. Pure, so the arithmetic is covered by
    /// tests instead of by opening a window.
    static func size(_ content: NSSize, atLeast minimum: NSSize) -> NSSize {
        NSSize(width: max(content.width, minimum.width),
               height: max(content.height, minimum.height))
    }

    /// Height of a standard macOS titlebar. The window uses
    /// `.fullSizeContentView`, so content extends underneath it and must inset
    /// itself to clear the traffic lights.
    static let titlebarHeight: CGFloat = 28
    /// Row height floor, so list rows have real presence.
    static let rowMinHeight: CGFloat = 44
}

// MARK: - Container modifiers

extension View {
    /// Grouped card. Content-layer glass, matching `BentoTile`, so a card and a
    /// tile are the same material rather than two similar-looking surfaces.
    /// In-window surfaces get no shadow — hierarchy comes from the rim.
    func card(radius: CGFloat = Radius.card,
              padding: CGFloat = Space.cardPadding) -> some View {
        self.padding(padding)
            .modifier(CardSurface(radius: radius))
    }

    /// Quiet grouping without a rim — for rows inside a list.
    func rowFill(radius: CGFloat = Radius.control) -> some View {
        self.background(Radius.rect(radius).fill(Surface.fillSubtle))
    }

    /// Constrain prose to a readable measure.
    func proseWidth(_ width: CGFloat = Layout.proseWidth) -> some View {
        self.frame(maxWidth: width, alignment: .leading)
    }
}

/// Reads the accessibility and appearance state a card needs.
///
/// A `ViewModifier` rather than inline code in `card()`: `@ObservedObject` and
/// `@Environment` can only be observed by a view type, and a plain function on
/// `View` has nowhere to hold them.
private struct CardSurface: ViewModifier {
    let radius: CGFloat
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.glassSurface(
            .content,
            in: Radius.rect(radius),
            reduceTransparency: motion.reduceTransparency,
            isDark: colorScheme == .dark
        )
    }
}

// MARK: - Animation curves
//
// Named curves so timing is consistent app-wide. `.smooth` and `.snappy` are
// macOS 14+; the fallbacks match their shape closely enough that the app feels
// the same on 13.3.

enum Motion {
    /// Hover and fill changes. Fast in, slightly slower out — reads less twitchy.
    static var hoverIn: Animation { .easeOut(duration: 0.11) }
    static var hoverOut: Animation { .easeOut(duration: 0.16) }

    /// Height and layout changes (row expand, panel collapse).
    static var layout: Animation {
        if #available(macOS 14, *) { return .smooth(duration: 0.28) }
        return .easeOut(duration: 0.26)
    }

    /// Insert and remove within a list.
    static var listChange: Animation {
        if #available(macOS 14, *) { return .smooth(duration: 0.24) }
        return .easeOut(duration: 0.22)
    }

    /// The pill's shape morph. A spring is right for a size change.
    static var morph: Animation {
        if #available(macOS 14, *) { return .snappy(duration: 0.32, extraBounce: 0.04) }
        return .spring(response: 0.34, dampingFraction: 0.82)
    }

    // No `morphExpand`/`cardFillDelay` family any more.
    //
    // Those four constants described an animated 96pt height and ~236pt width growth of the shell,
    // with the most detailed measurements in this file. That growth cannot happen — resizing a glass
    // body re-anchors it and the system cross-fades a ghost — so they had no production callers and
    // their doc comments were the most likely thing in here to mislead the next reader. The
    // measurements worth keeping moved to `settle` and `settleEdgeTravel`, where they explain why the
    // size change is instant instead of describing a curve for it.

    /// The pill's **settle** — the shape change itself is instant, so this is what sells it.
    ///
    /// The shell's *size* cannot be animated: `glassEffect` fills its view's bounds, so the bounds
    /// have to match the silhouette, and re-anchoring a glass body makes the system cross-fade the
    /// old against the new — which is the ghost that got the morph deleted nine times. A `scaleEffect`
    /// is a different thing entirely: it transforms an already-composited layer, so there is no new
    /// body and nothing to cross-fade. The pill therefore arrives at its new size instantly and then
    /// springs the last few percent into place.
    ///
    /// Uniform, so nothing distorts. This is why the scale is small and the earlier attempt to scale
    /// a capsule *into* a card was not: 56x28 and 292x124 are 2.00 and 2.355 aspect ratios, so
    /// covering that distance needs an anisotropic scale that turns the corner arcs into ellipses. A
    /// uniform 0.94 -> 1 keeps every proportion and moves the 16pt corner radius by less than a
    /// point.
    ///
    /// A little bounce, because a pop is the point — `.snappy` is `spring(bounce: 0.15)`.
    /// Named so the content fill can be checked against it. An `Animation` cannot be asked for its
    /// duration, so the relationship between the two is only testable if both come from a number
    /// something can read.
    static let settleDuration: TimeInterval = 0.34

    static var settle: Animation {
        // No bounce. `.snappy`'s default 0.15 was measured to overshoot this travel by 0.0629%,
        // which on the card is **0.18pt of width** — below one device pixel, so the "pop" the bounce
        // was there for does not exist. `.smooth` is `spring(bounce: 0)` and says what it does.
        if #available(macOS 14, *) { return .smooth(duration: settleDuration) }
        return .spring(response: settleDuration, dampingFraction: 1.0)
    }

    /// How far any shell's edge moves during the settle, in points.
    ///
    /// **A constant scale factor was the wrong model** and a flat 0.90 proved it: it gave the 56x28
    /// capsule 2.8pt of edge travel and the 292x124 card **14.6pt** — so the state with the most
    /// violent settle was the one whose content is text being read, arriving on top of an already
    /// instant 236pt jump and reading as a second, unrelated event. It also drew the card's 12pt
    /// transcript at 10.8pt while fading it in, which is the classic soft-text artefact.
    ///
    /// Scaling for constant *edge travel* inverts that: every state settles by the same visible
    /// distance, so the cue is uniform and no state is distorted more than another. 3pt is enough to
    /// read as seating and small enough that the card's radius drift falls from 1.60pt to 0.33pt and
    /// its text is drawn at 11.75pt rather than 10.8pt.
    static let settleEdgeTravel: CGFloat = 3.0

    /// The scale a shell of this size starts its settle at.
    ///
    /// Referenced to `max(height, width / 2)` so the bound holds on whichever axis dominates — a wide
    /// capsule settles horizontally, which is the axis that changed, while the card settles on both.
    /// Clamped to 0.86 so a degenerate size can never scale the pill to nothing.
    static func settleScale(width: CGFloat, height: CGFloat) -> CGFloat {
        let reference = max(height, width / 2)
        guard reference > 0 else { return 1 }
        return 1 - min(settleEdgeTravel / reference, 0.14)
    }

    /// The hands-free bead emerging from the pill, and being reabsorbed.
    ///
    /// Two durations for one shape, because the physics is already asymmetric and the timing should
    /// follow it: on the way out the neck survives ~91% of the travel and then lets go
    /// (`PillMetrics.neckFillet`), while on the way back it re-forms after about 7% and the rest of
    /// the movement is the lobe being absorbed. So the return is the half worth lingering on.
    ///
    /// No bounce, and that is a correction rather than a preference. These used `Motion.morph`
    /// (`spring(0.32, bounce: 0.19)`), whose overshoot pushes `extrusion` to 1.013 — and
    /// `PillMetrics.lobeCentreOffset` clamps to `0...1`, so the overshoot was discarded and all the
    /// bounce bought was a ~40ms tail of a spring oscillating invisibly against a clamp.
    static var beadEmerge: Animation {
        if #available(macOS 14, *) { return .smooth(duration: 0.30) }
        return .spring(response: 0.30, dampingFraction: 1.0)
    }

    static var beadRetract: Animation {
        if #available(macOS 14, *) { return .smooth(duration: 0.34) }
        return .spring(response: 0.34, dampingFraction: 1.0)
    }

    /// The state colour crossing to a new state's hue.
    ///
    /// `easeOut`, not a spring: colour has no momentum, and a spring on a colour reads as a flicker
    /// at the tail. This is the transition the pill was missing most — the tint and border were a
    /// hard cut, so every dictation began with the glass jumping from untinted to red in one frame,
    /// on *all* nine states rather than only the two that change size.
    static var tintCross: Animation { .easeOut(duration: 0.22) }

    /// The card's contents arriving after the shell has.
    ///
    /// Fades **in** only. Nothing in the pill ever fades *out* any more — an outgoing row dissolving
    /// on top of an incoming card is a second, independent ghost, and the fix for it was to make
    /// every removal instant (see `PillContent.content`). Fading only the arrival keeps the polish
    /// and cannot double anything, because there is never a moment with two states drawn.
    ///
    /// The short delay lets the shell land first, so it reads as an empty glass shape filling rather
    /// than as everything appearing at once. Much shorter than the 0.30s this replaces, which was
    /// timed against a 0.46s growth that no longer happens.
    /// Named for the same reason as `settleDuration`: the fill has to land *inside* the settle, and
    /// that is only checkable against numbers rather than against curves.
    static let contentInDuration: TimeInterval = 0.20
    static let contentInDelay: TimeInterval = 0.06

    static var contentIn: Animation {
        .easeOut(duration: contentInDuration).delay(contentInDelay)
    }

    /// How far a note-card row rises into place as it fades in.
    ///
    /// 5pt. It has to stay inside the card's vertical slack — three transcript lines leave about
    /// 6.8pt — because the shell's `clipShape` would otherwise show a row cut off at the top. Since
    /// the opacity starts at 0 the rise is never visible against the clip anyway; what it buys is
    /// direction, so the card reads as filling downward rather than switching on.
    static let cardRowRise: CGFloat = 5

    /// One row of the note card arriving, staggered by its position.
    ///
    /// The card used to fade its whole interior as a single opacity, so the destination, the
    /// transcript and the footer appeared at the same instant — which reads as a picture being
    /// uncovered rather than as a card being filled in. Top-down at 50ms apart is the difference.
    ///
    /// The last row lands at 0.14 + 0.18 = 0.32s, inside `settleDuration` (0.34s), so the interior
    /// finishes arriving just as the shell stops moving.
    static func cardRow(_ index: Int) -> Animation {
        .easeOut(duration: 0.18).delay(0.04 + 0.05 * Double(index))
    }

    /// Reduced-motion substitute: a short crossfade, never a spring.
    static var reduced: Animation { .easeInOut(duration: 0.14) }
}

// MARK: - Motion

/// Tracks the system Reduce Motion and Reduce Transparency settings.
///
/// The pill lives in an `NSPanel` via `NSHostingView`, so SwiftUI environment
/// propagation isn't reliable there — read AppKit directly and observe changes.
final class MotionPreference: ObservableObject {
    static let shared = MotionPreference()

    @Published var reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

    private var observer: NSObjectProtocol?

    private init() {
        // `NSWorkspace.shared.notificationCenter`, not `NotificationCenter.default`.
        //
        // Every notification declared on NSWorkspace is posted to the workspace's own
        // centre, so registering on the default centre meant this observer never fired:
        // turning Reduce Motion or Reduce Transparency on had no effect until the app was
        // relaunched. The pill kept spring-morphing, the companion kept hopping, and glass
        // kept sampling the wallpaper — for exactly the users who had asked it not to.
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let workspace = NSWorkspace.shared
            self?.reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
            self?.reduceTransparency = workspace.accessibilityDisplayShouldReduceTransparency
        }
    }
}

// MARK: - Elevation

/// Where a shadow is allowed. Two cases, and the shortness of the list is the
/// content: in this app exactly one thing floats.
///
/// `.overlay` (sheets, popovers, menus) used to be the third case and was never
/// called. It is deleted rather than wired up, because wiring it up would have
/// been the bug: a sheet, a popover and a menu are each their own window, and the
/// window server already draws their shadow. A 28pt SwiftUI shadow inside a
/// sheet's *content* would stack on top of the system's, and it would be clipped
/// by the sheet's own bounds while doing it.
///
/// `.flat` stays despite having no call sites either, because it is not a no-op
/// by accident — it is the app's in-window rule ("hierarchy comes from the rim,
/// not from a shadow") given a name, so a surface that wants no shadow can say so
/// and be reviewed. The rule has been broken once already, by the theme swatches.
enum Elevation {
    /// In-window cards, rows, sidebar. No shadow, ever.
    case flat
    /// The floating pill, and only the pill.
    case floating
}

extension View {
    @ViewBuilder
    func elevation(_ level: Elevation, dark: Bool) -> some View {
        switch level {
        case .flat:
            self
        case .floating:
            // Two-part: a tight contact shadow plus a wider ambient one. Dark
            // mode needs more opacity — there's less luminance to cast into.
            self.shadow(color: .black.opacity(dark ? 0.55 : 0.16), radius: 10, y: 3)
                .shadow(color: .black.opacity(dark ? 0.30 : 0.07), radius: 2, y: 1)
        }
    }
}


// MARK: - Appearance helper

extension NSAppearance {
    /// Whether this appearance is one of the dark variants.
    ///
    /// `NSAppearance` has no `isDark`; the supported test is to ask which of the
    /// known names it best matches, which also covers the high-contrast variants
    /// that a plain `name == .darkAqua` check would miss.
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
