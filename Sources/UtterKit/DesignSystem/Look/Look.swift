import AppKit
import SwiftUI

enum Look {}

extension Look {
    struct Swatch {
        let light: NSColor
        let dark: NSColor
        let lightIncreased: NSColor
        let darkIncreased: NSColor
        let nsColor: NSColor

        init(light: NSColor, dark: NSColor, lightIncreased: NSColor? = nil, darkIncreased: NSColor? = nil) {
            let table = (light, dark, lightIncreased ?? light, darkIncreased ?? dark)
            (self.light, self.dark, self.lightIncreased, self.darkIncreased) = table
            nsColor = NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.aqua, .darkAqua,
                                                        .accessibilityHighContrastAqua,
                                                        .accessibilityHighContrastDarkAqua])
                let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
                let increased = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                    || match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
                return Swatch.select(table, dark: isDark, increased: increased)
            }
        }

        func resolved(dark isDark: Bool, increasedContrast: Bool) -> NSColor {
            Swatch.select((light, dark, lightIncreased, darkIncreased), dark: isDark, increased: increasedContrast)
        }

        private static func select(_ table: (NSColor, NSColor, NSColor, NSColor),
                                   dark: Bool, increased: Bool) -> NSColor {
            switch (dark, increased) {
            case (false, false): table.0
            case (true, false): table.1
            case (false, true): table.2
            case (true, true): table.3
            }
        }
    }

    enum Palette {
        static let tint = Swatch(light: .hex(0x2B3B5E), dark: .hex(0xDFE7F5),
                                 lightIncreased: .hex(0x16213A), darkIncreased: .hex(0xF1F5FC))
        static let mic = Swatch(light: .hex(0xE8452C), dark: .hex(0xFF5B45),
                                lightIncreased: .hex(0xC02A14), darkIncreased: .hex(0xFF7A66))
        static let groundTop = Swatch(light: .hex(0xF2F4F8), dark: .hex(0x13161F))
        static let groundBottom = Swatch(light: .hex(0xE8ECF2), dark: .hex(0x0D1017))
        static let fill = Swatch(light: .hex(0xFFFFFF, 0.6), dark: .hex(0xFFFFFF, 0.07))
        static let fillHover = Swatch(light: .hex(0xFFFFFF, 0.82), dark: .hex(0xFFFFFF, 0.11))
        static let edge = Swatch(light: .hex(0x14284A, 0.09), dark: .hex(0xFFFFFF, 0.1),
                                 lightIncreased: .hex(0x14284A, 0.35), darkIncreased: .hex(0xFFFFFF, 0.35))
        static let hover = Swatch(light: .hex(0x14284A, 0.06), dark: .hex(0xFFFFFF, 0.06))
        static let accent = Swatch(light: .hex(0x283A60, 0.09), dark: .hex(0xE2EAF8, 0.15))
        static let lens = Swatch(light: .hex(0xFFFFFF, 0.92), dark: .hex(0xE2EAF8, 0.17))
        static let ink2 = Swatch(light: .hex(0x121A2C, 0.64), dark: .hex(0xDEE6F4, 0.64),
                                 lightIncreased: .hex(0x121A2C, 0.82), darkIncreased: .hex(0xDEE6F4, 0.82))
        static let ink3 = Swatch(light: .hex(0x121A2C, 0.5), dark: .hex(0xD6E0F0, 0.42),
                                 lightIncreased: .hex(0x121A2C, 0.7), darkIncreased: .hex(0xD6E0F0, 0.66))
    }

    enum Color {
        /// Moonlight: the icon's navy ink in light mode, moonlit silver in dark.
        static let tint = SwiftUI.Color(nsColor: Palette.tint.nsColor)
        /// The live mic only.
        static let mic = SwiftUI.Color(nsColor: Palette.mic.nsColor)
        static let groundTop = SwiftUI.Color(nsColor: Palette.groundTop.nsColor)
        static let groundBottom = SwiftUI.Color(nsColor: Palette.groundBottom.nsColor)
        /// Content-layer cards: a fill and a hairline, never glass.
        static let fill = SwiftUI.Color(nsColor: Palette.fill.nsColor)
        static let fillHover = SwiftUI.Color(nsColor: Palette.fillHover.nsColor)
        static let edge = SwiftUI.Color(nsColor: Palette.edge.nsColor)
        static let hover = SwiftUI.Color(nsColor: Palette.hover.nsColor)
        static let accent = SwiftUI.Color(nsColor: Palette.accent.nsColor)
        static let lens = SwiftUI.Color(nsColor: Palette.lens.nsColor)
        /// v2's text ladder under `.primary`: secondary and tertiary ink.
        static let ink2 = SwiftUI.Color(nsColor: Palette.ink2.nsColor)
        static let ink3 = SwiftUI.Color(nsColor: Palette.ink3.nsColor)
    }

    /// Concentric radii: window 26, sidebar 18, cards 18 with 6 inside, rows 12.
    enum Card {
        static let radius: CGFloat = 18
        static let inset: CGFloat = 6
        static let rowRadius: CGFloat = radius - inset
    }

    enum Press {
        static let row: CGFloat = 0.985
        static let nav: CGFloat = 0.97
        static let button: CGFloat = 0.94
    }
}

extension NSColor {
    static func hex(_ rgb: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255,
                green: CGFloat(rgb >> 8 & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: alpha)
    }
}

extension Look {
    enum Motion: CaseIterable {
        case settle
        case fling
        /// Press and release on rows, nav items and buttons.
        case press
        /// A section swap: a short fade, because it happens many times a day.
        case pane
        /// The sidebar's selection lens moving between rows.
        case lens
        /// Hover fills and captions.
        case quick
        case reduced

        func animation(reduceMotion: Bool) -> Animation {
            if reduceMotion { return .easeInOut(duration: 0.15) }
            switch self {
            case .settle: return .spring(response: 0.4, dampingFraction: 1.0)
            case .fling: return .spring(response: 0.4, dampingFraction: 0.82)
            case .press: return .spring(response: 0.22, dampingFraction: 0.62)
            case .pane: return .easeOut(duration: 0.15)
            case .lens: return .snappy(duration: 0.4)
            case .quick: return .easeOut(duration: 0.12)
            case .reduced: return .easeInOut(duration: 0.15)
            }
        }
    }
}

extension View {
    /// Scales on press with the press spring; under Reduce Motion it dims instead.
    func pressEffect(_ pressed: Bool, scale: CGFloat) -> some View {
        modifier(PressEffect(pressed: pressed, scale: scale))
    }

    /// The page's one large title: 34 pt bold with tight tracking.
    func pageTitle() -> some View {
        font(.system(size: 34, weight: .bold))
            .tracking(-0.9)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct PressEffect: ViewModifier {
    let pressed: Bool
    let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed && !reduceMotion ? scale : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .animation(Look.Motion.press.animation(reduceMotion: reduceMotion), value: pressed)
    }
}

extension Look {
    /// A row, nav item or link: a rounded hover fill and a small press scale.
    /// `quiet` labels sit in secondary ink until hovered or selected.
    struct RowStyle: SwiftUI.ButtonStyle {
        var radius: CGFloat = Card.rowRadius
        var scale: CGFloat = Press.row
        var quiet = false
        var selected = false

        func makeBody(configuration: Configuration) -> some View {
            Row(configuration: configuration, style: self)
        }

        private struct Row: View {
            let configuration: Configuration
            let style: RowStyle
            @State private var hovering = false
            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            var body: some View {
                let shape = RoundedRectangle(cornerRadius: style.radius, style: .continuous)
                configuration.label
                    .foregroundStyle(!style.quiet || hovering || style.selected ? AnyShapeStyle(.primary) : AnyShapeStyle(Look.Color.ink2))
                    .contentShape(shape)
                    .background(hovering && !style.selected ? Look.Color.hover : .clear, in: shape)
                    .animation(Motion.quick.animation(reduceMotion: reduceMotion), value: hovering)
                    .pressEffect(configuration.isPressed, scale: style.scale)
                    .onHover { hovering = $0 }
            }
        }
    }

    /// Moonlight action buttons in the content layer: a fill and a hairline, never glass.
    struct ActionStyle: SwiftUI.ButtonStyle {
        var prominent = false

        func makeBody(configuration: Configuration) -> some View {
            Action(configuration: configuration, prominent: prominent)
        }

        private struct Action: View {
            let configuration: Configuration
            let prominent: Bool
            @State private var hovering = false
            @Environment(\.isEnabled) private var enabled

            var body: some View {
                configuration.label
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background {
                        if prominent {
                            Capsule().fill(Look.Color.accent)
                            Capsule().fill(LinearGradient(colors: [.white.opacity(hovering ? 0.22 : 0.14), .white.opacity(0)],
                                                          startPoint: .top, endPoint: .bottom))
                        } else {
                            Capsule().fill(hovering ? Look.Color.fillHover : Look.Color.fill)
                        }
                    }
                    .overlay {
                        Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.16), Look.Color.edge],
                                                              startPoint: .top, endPoint: .center))
                    }
                    .contentShape(Capsule())
                    .opacity(enabled ? 1 : 0.5)
                    .pressEffect(configuration.isPressed, scale: Press.button)
                    .onHover { hovering = $0 }
            }
        }
    }
}

extension View {
    func lookAnimation<V: Equatable>(_ motion: Look.Motion, value: V) -> some View {
        modifier(LookAnimation(motion: motion, value: value))
    }
}

private struct LookAnimation<V: Equatable>: ViewModifier {
    let motion: Look.Motion
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
}

extension Look {
    struct Keycap: View {
        let key: String

        init(_ key: String) { self.key = key }

        var body: some View {
            Text(key)
                .font(.callout.monospaced())
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .frame(minWidth: 28, minHeight: 22)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.separator) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(key) key")
        }
    }

    /// The live mic. It keeps its frame when off so lighting it never reflows.
    struct LiveDot: View {
        var isLive = true

        var body: some View {
            Circle()
                .fill(Color.mic)
                .frame(width: 8, height: 8)
                .opacity(isLive ? 1 : 0)
                .accessibilityLabel("Microphone live")
                .accessibilityHidden(!isLive)
        }
    }

    /// A state beside a name: a symbol in a system colour, the words in secondary text.
    struct Status: View {
        enum Kind { case neutral, ok, warn }

        let text: String
        var kind: Kind = .neutral

        var body: some View {
            Label {
                Text(text).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: symbol).foregroundStyle(color)
            }
            .font(.callout)
        }

        private var symbol: String {
            switch kind {
            case .neutral: "circle"
            case .ok: "checkmark.circle.fill"
            case .warn: "exclamationmark.triangle.fill"
            }
        }

        private var color: SwiftUI.Color {
            switch kind {
            case .neutral: .secondary
            case .ok: .green
            case .warn: .orange
            }
        }
    }
}
