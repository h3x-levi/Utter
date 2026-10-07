import SwiftUI
import AppKit

/// An appearance choice: a light/dark preference plus an accent tint.
///
/// Earlier versions carried per-theme pill and sidebar colours. Those are gone  - 
/// the UI now uses semantic system colours so light/dark and Increase Contrast
/// are handled by macOS. What a theme still meaningfully controls is the
/// appearance and the accent, and both are actually applied (see `Tint.accent`).
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    /// `nil` means "follow macOS".
    let colorScheme: ColorScheme?
    /// `nil` means "follow the System Settings accent colour".
    let accent: Color?
    /// Window background. `nil` = system window colour.
    let canvas: Color?
    /// Tile/card background sitting on `canvas`.
    let raised: Color?
    /// Editable wells (text fields, editors).
    let sunken: Color?

    /// The theme list.
    ///
    /// Every surface is WARM. The reference design's entire neutral ramp is warm
    /// greige, and a cool gray canvas next to warm hairlines reads as two design
    /// systems fighting. These are the values the glass tints toward, so they set
    /// the app's whole temperature.
    /// The theme list.
    ///
    /// Each theme is a genuinely different room, not a different shade of grey.
    /// The previous set was too timid to notice - Paper and Linen differed by
    /// **2-4 units out of 255** in their canvas, which is invisible, and every
    /// dark theme was a near-neutral charcoal. A theme people can choose has to be
    /// a choice they can see, so each now commits to a hue: the canvas carries
    /// real saturation, and the accent is drawn from the same family rather than
    /// being an unrelated system colour.
    static let themes: [AppTheme] = [
        AppTheme(id: "system", name: "System", icon: "circle.lefthalf.filled",
                 colorScheme: nil, accent: nil,
                 canvas: nil, raised: nil, sunken: nil),

        // Warm cream and amber - the default light look.
        AppTheme(id: "paper", name: "Paper", icon: "sun.max",
                 colorScheme: .light,
                 accent: Color(red: 0.839, green: 0.502, blue: 0.106),
                 canvas: Color(red: 0.965, green: 0.937, blue: 0.882),
                 raised: Color(red: 1.0, green: 0.988, blue: 0.965),
                 sunken: Color(red: 0.980, green: 0.957, blue: 0.914)),

        // Cool blue-grey and slate: a clearly *cold* light theme, so the
        // difference from Paper is temperature, not brightness.
        AppTheme(id: "linen", name: "Linen", icon: "snowflake",
                 colorScheme: .light,
                 accent: Color(red: 0.180, green: 0.408, blue: 0.647),
                 canvas: Color(red: 0.890, green: 0.914, blue: 0.941),
                 raised: Color(red: 0.976, green: 0.984, blue: 0.996),
                 sunken: Color(red: 0.937, green: 0.953, blue: 0.973)),

        // True neutral charcoal - deliberately the only *unhued* dark theme, so it
        // reads as "no colour" beside Violet, Pine and Ember. Measured at the
        // previous warm value it sat only dE 7.9 from Pine, which is subtle rather
        // than a distinct choice; a lighter, flatter grey separates it clearly.
        AppTheme(id: "graphite", name: "Graphite", icon: "moon",
                 colorScheme: .dark,
                 accent: Color(red: 0.643, green: 0.678, blue: 0.729),
                 canvas: Color(red: 0.145, green: 0.145, blue: 0.149),
                 raised: Color(red: 0.216, green: 0.216, blue: 0.220),
                 sunken: Color(red: 0.176, green: 0.176, blue: 0.180)),

        // Deep indigo. Noticeably violet, not "dark grey with a purple dot".
        AppTheme(id: "violet", name: "Violet", icon: "sparkles",
                 colorScheme: .dark,
                 accent: Color(red: 0.639, green: 0.510, blue: 0.980),
                 canvas: Color(red: 0.086, green: 0.071, blue: 0.153),
                 raised: Color(red: 0.145, green: 0.125, blue: 0.235),
                 sunken: Color(red: 0.110, green: 0.094, blue: 0.192)),

        // Deep forest green.
        AppTheme(id: "pine", name: "Pine", icon: "leaf",
                 colorScheme: .dark,
                 accent: Color(red: 0.400, green: 0.808, blue: 0.639),
                 canvas: Color(red: 0.043, green: 0.106, blue: 0.086),
                 raised: Color(red: 0.078, green: 0.176, blue: 0.149),
                 sunken: Color(red: 0.059, green: 0.137, blue: 0.114)),

        // Deep oxblood and warm orange.
        AppTheme(id: "ember", name: "Ember", icon: "flame",
                 colorScheme: .dark,
                 accent: Color(red: 0.972, green: 0.596, blue: 0.286),
                 canvas: Color(red: 0.129, green: 0.055, blue: 0.043),
                 raised: Color(red: 0.208, green: 0.098, blue: 0.075),
                 sunken: Color(red: 0.161, green: 0.071, blue: 0.055)),
    ]

    static func find(_ id: String) -> AppTheme {
        themes.first { $0.id == id } ?? themes[0]
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// The theme that defers to the macOS appearance. Also the default.
    static let systemThemeID = "system"

    @Published var current: AppTheme = AppTheme.find(UserData.shared.appTheme)

    private init() {}

    /// Views observe `current` directly, so publishing is enough - there is no
    /// separate notification to post.
    func setTheme(_ id: String) {
        current = AppTheme.find(id)
        UserData.shared.appTheme = id
        UserData.shared.save()
        applyAppearance()
    }

    /// Push the theme's light/dark preference onto `NSApp` itself.
    ///
    /// This is required, not belt-and-braces. `preferredColorScheme` restyles
    /// SwiftUI's own views but does **not** change the `NSAppearance` that dynamic
    /// `NSColor`s resolve against - so every token built with
    /// `NSColor(name:dynamicProvider:)` kept returning its light-mode value inside
    /// a dark window. That is what made the selected sidebar label resolve to warm
    /// near-black on a dark pill (measured 2.15:1, unreadable) while its
    /// unselected neighbours were correctly near-white, and what left the
    /// onboarding window in light mode while the main window was dark.
    ///
    /// Setting `NSApp.appearance` fixes both at the source: AppKit and SwiftUI
    /// then agree on one appearance for the whole process.
    func applyAppearance() {
        let name: NSAppearance.Name? = {
            switch current.colorScheme {
            case .some(.dark): return .darkAqua
            case .some(.light): return .aqua
            default: return nil          // follow the system
            }
        }()
        NSApp?.appearance = name.flatMap { NSAppearance(named: $0) }
    }
}
