import AppKit
import CoreText
import SwiftUI

/// The Live Captions design system: tokens here, components in `LookComponents.swift`.
///
/// One namespace so it can live beside the old `Space`/`Radius`/`Typo` tokens until the screens
/// migrate. Inside it `Color` and `Font` mean `Look.Color` and `Look.Font`; say `SwiftUI.Color`
/// for the framework type.
enum Look {}

// MARK: - Colour

extension Look {
    /// One colour in each appearance. `Palette` is the AppKit face of the tokens, `Color` the SwiftUI one.
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
                // A constructed high-contrast appearance resolves as plain aqua; the workspace flag carries Increase Contrast.
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
        static let ground = Swatch(light: .hex(0xF2F2F4), dark: .hex(0x1C1C1E))
        static let well = Swatch(light: .hex(0xFFFFFF), dark: .hex(0x2C2C2E))
        static let wellRaised = Swatch(light: .hex(0xFFFFFF), dark: .hex(0x3A3A3C))

        static let ink = Swatch(light: .hex(0x111113), dark: .hex(0xF5F5F7),
                                lightIncreased: .hex(0x000000), darkIncreased: .hex(0xFFFFFF))
        static let inkSecondary = Swatch(light: .hex(0x55555C), dark: .hex(0xC2C2C7),
                                         lightIncreased: .hex(0x3A3A3F), darkIncreased: .hex(0xDCDCE0))
        static let inkTertiary = Swatch(light: .hex(0x6B6B72), dark: .hex(0xA6A6AB),
                                        lightIncreased: .hex(0x4A4A50), darkIncreased: .hex(0xC2C2C7))
        static let hairline = Swatch(light: .hex(0x111113, 0.09), dark: .hex(0xFFFFFF, 0.12),
                                     lightIncreased: .hex(0x000000, 0.32), darkIncreased: .hex(0xFFFFFF, 0.40))

        static let plate = Swatch(light: .hex(0x0A0A0C, 0.88), dark: .hex(0x0A0A0C, 0.88),
                                  lightIncreased: .hex(0x000000), darkIncreased: .hex(0x000000))
        static let plateInk = Swatch(light: .hex(0xFFFFFF), dark: .hex(0xFFFFFF))
        static let plateInkSecondary = Swatch(light: .hex(0xFFFFFF, 0.62), dark: .hex(0xFFFFFF, 0.62),
                                              lightIncreased: .hex(0xFFFFFF, 0.78), darkIncreased: .hex(0xFFFFFF, 0.78))
        static let live = Swatch(light: .hex(0xFFD60A), dark: .hex(0xFFD60A))

        /// `systemRed`'s published values, spelled out so every appearance is testable.
        static let mic = Swatch(light: .hex(0xFF3B30), dark: .hex(0xFF453A),
                                lightIncreased: .hex(0xD70015), darkIncreased: .hex(0xFF6961))
        static let ok = Swatch(light: .hex(0x1E7B34), dark: .hex(0x30D158),
                               lightIncreased: .hex(0x155C26), darkIncreased: .hex(0x30DB5B))
        static let warn = Swatch(light: .hex(0xA04D00), dark: .hex(0xFF9F0A),
                                 lightIncreased: .hex(0x7A3A00), darkIncreased: .hex(0xFFB340))
    }

    enum Color {
        static let ground = SwiftUI.Color(nsColor: Palette.ground.nsColor)
        static let well = SwiftUI.Color(nsColor: Palette.well.nsColor)
        static let wellRaised = SwiftUI.Color(nsColor: Palette.wellRaised.nsColor)
        static let ink = SwiftUI.Color(nsColor: Palette.ink.nsColor)
        static let inkSecondary = SwiftUI.Color(nsColor: Palette.inkSecondary.nsColor)
        static let inkTertiary = SwiftUI.Color(nsColor: Palette.inkTertiary.nsColor)
        static let hairline = SwiftUI.Color(nsColor: Palette.hairline.nsColor)
        static let plate = SwiftUI.Color(nsColor: Palette.plate.nsColor)
        static let plateInk = SwiftUI.Color(nsColor: Palette.plateInk.nsColor)
        static let plateInkSecondary = SwiftUI.Color(nsColor: Palette.plateInkSecondary.nsColor)
        /// Caption yellow. Live words only, and only on a plate.
        static let live = SwiftUI.Color(nsColor: Palette.live.nsColor)
        /// The live mic only.
        static let mic = SwiftUI.Color(nsColor: Palette.mic.nsColor)
        static let ok = SwiftUI.Color(nsColor: Palette.ok.nsColor)
        static let warn = SwiftUI.Color(nsColor: Palette.warn.nsColor)
    }
}

private extension NSColor {
    static func hex(_ rgb: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255,
                green: CGFloat(rgb >> 8 & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: alpha)
    }
}

// MARK: - Type

extension Look {
    /// Three content sizes (15, 13, 11) plus the plate's two.
    enum Font {
        static let plateHero = SwiftUI.Font.system(size: 28, weight: .semibold)
        /// Display optical size at 17pt; the system face would switch to Text below 20pt.
        static let platePill = SwiftUI.Font(displayFace(size: 17, weight: .semibold) as CTFont)
        static let body = SwiftUI.Font.system(size: 15)
        static let secondary = SwiftUI.Font.system(size: 13)
        static let heading = SwiftUI.Font.system(size: 13, weight: .semibold)
        /// Uppercase with `tagTracking`; `SoundTag` applies both.
        static let tag = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let tagTracking: CGFloat = 11 * 0.06
        /// SF Mono, whose figures are already tabular.
        static let mono = SwiftUI.Font.system(size: 11, design: .monospaced)

        static func displayFace(size: CGFloat, weight: NSFont.Weight) -> NSFont {
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            let opticalSize = NSFontDescriptor.AttributeName(rawValue: kCTFontOpticalSizeAttribute as String)
            return NSFont(descriptor: base.fontDescriptor.addingAttributes([opticalSize: 28]), size: size) ?? base
        }
    }
}

// MARK: - Space, radius

extension Look {
    /// One 4pt rhythm.
    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
        static let x7: CGFloat = 28
        static let x8: CGFloat = 32
    }

    enum Radius {
        static let plate: CGFloat = 10
        static let well: CGFloat = 12
        static let control: CGFloat = 7
    }
}

// MARK: - Motion

extension Look {
    enum Motion: CaseIterable {
        /// The plate growing, moving and leaving.
        case plate
        /// Anything coming to rest after a state change.
        case settle
        /// Only after a drag is released.
        case fling
        /// A live word cooling to white.
        case cool
        /// The Reduce Motion substitute for all of the above.
        case reduced

        func animation(reduceMotion: Bool) -> Animation {
            if reduceMotion { return .easeInOut(duration: 0.15) }
            switch self {
            case .plate: return .spring(response: 0.32, dampingFraction: 1.0)
            case .settle: return .spring(response: 0.4, dampingFraction: 1.0)
            case .fling: return .spring(response: 0.4, dampingFraction: 0.82)
            case .cool: return .easeOut(duration: 0.15)
            case .reduced: return .easeInOut(duration: 0.15)
            }
        }
    }
}

extension View {
    /// `.animation(_:value:)` with the motion swapped for `Look.Motion.reduced` under Reduce Motion.
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
