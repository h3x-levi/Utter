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
