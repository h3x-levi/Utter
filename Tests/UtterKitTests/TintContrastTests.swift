import AppKit
import SwiftUI
import Testing

@testable import UtterKit

/// The status colours, when they are used as *text*.
///
/// This pins a real, shipped defect. `Tint.warning`/`success`/`danger` are `NSColor.system*`,
/// which are tuned as **fills**; as 12pt text on this app's own `raised` surfaces they measured,
/// in a light theme:
///
///   * `Tint.warning` - **1.48:1** on Paper, 1.46:1 on Linen. Amber on cream, effectively invisible.
///   * `Tint.success` - 2.17:1 / 2.14:1
///   * `Tint.danger` - 3.48:1 / 3.44:1, and **3.46:1 on Graphite**, so it failed in a dark theme too
///
/// Every one of those call sites is a warning or an error, which makes them the strings a user
/// most needs to read - two were the only on-screen explanation of a failure. `Tint.*Text` are the
/// fixed variants, built the same way as `Tint.accentText` and for the same reason.
///
/// Tested rather than eyeballed because the failure is invisible in the one place it is most likely
/// to be checked: the developer's Mac was in a dark theme, where two of the three already passed.
/// A ratio is also exactly the kind of claim that should be computed, not recalled.
@Suite("Status colour contrast")
struct TintContrastTests {

    /// WCAG 2.x relative luminance.
    ///
    /// `usingColorSpace(.sRGB)` is required, not defensive: a dynamic `NSColor` built by
    /// `NSColor(name:dynamicProvider:)` has no components until it is resolved into a concrete
    /// space, and the system colours live in a catalog space where `redComponent` traps.
    private static func luminance(_ color: NSColor) -> Double {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        func channel(_ raw: CGFloat) -> Double {
            let v = Double(raw)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(srgb.redComponent)
            + 0.7152 * channel(srgb.greenComponent)
            + 0.0722 * channel(srgb.blueComponent)
    }

    private static func contrast(_ a: NSColor, _ b: NSColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The floor for body text at these sizes.
    private static let floor = 4.5

    /// Every theme's `raised` surface - the one these labels actually sit on.
    ///
    /// Taken from `ThemeManager`'s own definitions rather than restated, so a theme whose surface
    /// is retuned is checked against its new value instead of a stale copy. The system theme is
    /// skipped: its `raised` is nil and resolves to `NSColor.controlBackgroundColor`, which is
    /// covered by whichever appearance the test is running in anyway.
    private static func surfaces(isDark: Bool) -> [(name: String, color: NSColor)] {
        AppTheme.themes
            .filter { $0.colorScheme == (isDark ? .dark : .light) }
            .compactMap { theme in
                theme.raised.map { (theme.name, NSColor($0)) }
            }
    }

    /// Resolve a dynamic colour the way the screen will.
    private static func resolved(_ color: Color, isDark: Bool) -> NSColor {
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)!
        var out = NSColor.black
        appearance.performAsCurrentDrawingAppearance {
            out = NSColor(color).usingColorSpace(.sRGB) ?? .black
        }
        return out
    }

    @Test("Every status text colour clears 4.5:1 on every themed surface, both appearances",
          arguments: [false, true])
    func statusTextIsLegible(isDark: Bool) {
        let tokens: [(name: String, color: Color)] = [
            ("warningText", Tint.warningText),
            ("successText", Tint.successText),
            ("dangerText", Tint.dangerText),
        ]
        let backdrops = Self.surfaces(isDark: isDark)
        #expect(!backdrops.isEmpty, "no \(isDark ? "dark" : "light") themes found to test against")

        for (name, color) in tokens {
            let ink = Self.resolved(color, isDark: isDark)
            for backdrop in backdrops {
                let ratio = Self.contrast(ink, backdrop.color)
                #expect(ratio >= Self.floor,
                        "Tint.\(name) on \(backdrop.name) is \(String(format: "%.2f", ratio)):1, under the \(Self.floor):1 floor")
            }
        }
    }

    /// A selected row's label must clear the body-text floor on **every** theme's accent.
    ///
    /// This is the test that would have caught the bug it was written for. `NSTableView`
    /// inverts a selected row's label to white unconditionally, which is right for the
    /// system accents - `selectedContentBackgroundColor` carries white at 5.37:1 - and
    /// wrong for six of these seven, where white measures between 1.92:1 and 4.02:1. So
    /// hardcoding either ink fails: white fails Paper, Graphite, Violet, Pine, Ember and
    /// the system accent; black fails Linen. Only the measured choice passes all seven,
    /// and that is exactly what this asserts.
    ///
    /// `Tint.ink(on:)` rather than `Tint.onAccent` so no theme has to be installed into
    /// `ThemeManager.shared` - the rule is a pure function of the fill.
    @Test("Tint.ink(on:) clears 4.5:1 on every theme's accent, and neither ink alone would")
    func selectedRowInkIsLegible() {
        let accents: [(name: String, color: NSColor)] =
            AppTheme.themes.compactMap { theme in
                theme.accent.map { (theme.name, NSColor($0)) }
            } + [("System", NSColor.controlAccentColor)]
        #expect(accents.count >= 7, "expected every themed accent plus the system one")

        var whiteFailures = 0
        var blackFailures = 0
        let black = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.847)

        for accent in accents {
            // The chosen ink must clear the floor. Composited, because both candidate
            // inks are translucent over the fill they sit on.
            let chosen = Tint.ink(on: accent.color)
            let ratio = Self.contrast(Self.composite(chosen, over: accent.color), accent.color)
            #expect(ratio >= Self.floor,
                    "Tint.ink(on:) gives \(String(format: "%.2f", ratio)):1 on \(accent.name)'s accent, under the \(Self.floor):1 floor")

            if Self.contrast(.white, accent.color) < Self.floor { whiteFailures += 1 }
            if Self.contrast(Self.composite(black, over: accent.color), accent.color) < Self.floor {
                blackFailures += 1
            }
        }

        // Records *why* the choice has to be measured. If either of these drops to zero
        // the token could be replaced by a constant, and this is what says so.
        #expect(whiteFailures > 0,
                "white now clears \(Self.floor):1 on every accent - Tint.ink(on:) could be a constant")
        #expect(blackFailures > 0,
                "black now clears \(Self.floor):1 on every accent - Tint.ink(on:) could be a constant")
    }

    /// Flatten a translucent ink onto its backdrop, so the ratio is the one drawn.
    private static func composite(_ ink: NSColor, over backdrop: NSColor) -> NSColor {
        guard let top = ink.usingColorSpace(.sRGB),
              let bottom = backdrop.usingColorSpace(.sRGB) else { return ink }
        let alpha = top.alphaComponent
        return NSColor(srgbRed: top.redComponent * alpha + bottom.redComponent * (1 - alpha),
                       green: top.greenComponent * alpha + bottom.greenComponent * (1 - alpha),
                       blue: top.blueComponent * alpha + bottom.blueComponent * (1 - alpha),
                       alpha: 1)
    }

    /// The fill variants are deliberately left alone, so this records *why* the text ones exist.
    ///
    /// If a future change makes the raw system colours pass as text, `Tint.*Text` becomes dead
    /// weight and this test is what says so. It is written to fail in that case rather than to
    /// assert the bug forever: `warning` is the worst of the three by a wide margin, and it is the
    /// one whose failure was severe enough to be worth a token.
    @Test("The raw fill colours still fail as light-mode text, which is why the text tokens exist")
    func rawFillsWouldStillFail() {
        let lightSurfaces = Self.surfaces(isDark: false)
        let raw = Self.resolved(Tint.warning, isDark: false)
        for backdrop in lightSurfaces {
            let ratio = Self.contrast(raw, backdrop.color)
            #expect(ratio < Self.floor,
                    "Tint.warning now measures \(String(format: "%.2f", ratio)):1 on \(backdrop.name) - if the system colour or the surface changed so the raw fill passes as text, Tint.warningText may no longer be needed.")
        }
    }
}
