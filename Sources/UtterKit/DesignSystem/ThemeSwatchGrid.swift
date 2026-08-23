import SwiftUI

/// The theme picker, as a grid of live previews.
///
/// This replaces a pop-up menu of theme *names*. A theme is a visual choice, so a
/// list of words is the one representation that shows nothing about it — you had
/// to select a theme to find out what it looked like, then select another to
/// compare. Each swatch here renders its own canvas, raised surface and accent,
/// so the control previews its own effect.
struct ThemeSwatchGrid: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared

    // No `GlassCluster` around this grid.
    //
    // There was one, citing Apple's batching guidance — but batching applies to
    // glass, and `ThemeSwatch` below draws no `glassEffect` at all: it is fills and
    // strokes, deliberately, because each swatch is a *picture of* a theme's
    // surfaces and glass would sample the real window instead of showing the theme.
    // A `GlassEffectContainer` with no glass inside it has no appearance of its
    // own, so the render was identical with and without it. All it did was tell the
    // next reader there is glass here.
    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(minimum: 0), spacing: Space.x3),
                count: 4
            ),
            alignment: .leading,
            spacing: Space.x3
        ) {
            ForEach(AppTheme.themes) { theme in
                ThemeSwatch(
                    theme: theme,
                    isSelected: themeManager.current.id == theme.id
                ) {
                    withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                        themeManager.setTheme(theme.id)
                    }
                }
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: Space.x2) {
                preview
                Text(theme.name)
                    .typo(.caption, ink: isSelected ? Ink.primary : Ink.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel("\(theme.name) theme")
    }

    /// A miniature of the app: canvas, a raised tile, and an accent dot.
    private var preview: some View {
        ZStack {
            Radius.rect(Radius.control).fill(canvas)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Radius.rect(2).fill(ink.opacity(0.55)).frame(width: 16, height: 3)
                }
                Radius.rect(3).fill(raised)
                    .frame(height: 12)
                    .overlay(Radius.rect(3).strokeBorder(ink.opacity(0.10), lineWidth: 0.5))
            }
            .padding(6)
        }
        .frame(height: 46)
        .overlay(
            // `hairlineHover`, not `Line.strong`: strong is `Color.primary` at 14% against a
            // 13% warm hairline, so the old hover was a 0.01 alpha step measuring 1.070:1 —
            // invisible, leaving the 0.02 scale below as the only cue. Same ramp at 0.26
            // steps 1.32:1 in light, 1.55:1 in dark. No fill wash here on purpose: this tile
            // previews the theme's own canvas, so tinting it would misreport the choice.
            Radius.rect(Radius.control).strokeBorder(
                isSelected ? Tint.accent : (isHovering ? Line.hairlineHover : Line.hairline),
                lineWidth: isSelected ? 2 : Line.width
            )
        )
        // The selected swatch lifts slightly. Small, and it reads as "this one"
        // without needing a checkmark on top of the artwork.
        //
        // Scale and the 2pt accent rim only — no shadow. There was one here, on
        // every swatch, and it was the only shadow drawn inside any window in the
        // app: `Elevation.flat` is documented "In-window cards, rows, sidebar. **No
        // shadow, ever**", and hierarchy in this design comes from the rim. Nothing
        // replaces it, because nothing needs to: selection is already carried three
        // ways over unselected — a 2pt accent border against a hairline, 1.0 scale
        // against 0.97, and the label stepping from secondary to primary ink. A
        // drop shadow was the fourth signal for one state, and the price was every
        // swatch reading as a floating card in a flat window.
        .scaleEffect(isSelected ? 1.0 : (isHovering ? 0.99 : 0.97))
    }

    // A theme that defers to the system has `nil` surfaces, so the swatch has to
    // resolve what the system would actually draw — otherwise System, Light and
    // Dark would all preview as empty.
    private var effectiveDark: Bool {
        theme.colorScheme.map { $0 == .dark } ?? (systemScheme == .dark)
    }

    private var canvas: Color {
        theme.canvas ?? (effectiveDark
            ? Color(red: 0.12, green: 0.12, blue: 0.13)
            : Color(red: 0.93, green: 0.93, blue: 0.94))
    }

    private var raised: Color {
        theme.raised ?? (effectiveDark
            ? Color(red: 0.18, green: 0.18, blue: 0.19)
            : .white)
    }

    private var ink: Color { effectiveDark ? .white : .black }

    private var accent: Color { theme.accent ?? Color(nsColor: .controlAccentColor) }
}
