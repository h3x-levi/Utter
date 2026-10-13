import SwiftUI
import AppKit
import UtterCore

/// An appearance choice: follow macOS, or force light or dark.
struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    /// `nil` means "follow macOS".
    let colorScheme: ColorScheme?

    static let system = AppTheme(id: "system", name: "System", colorScheme: nil)
    static let light = AppTheme(id: "light", name: "Light", colorScheme: .light)
    static let dark = AppTheme(id: "dark", name: "Dark", colorScheme: .dark)

    static let themes: [AppTheme] = [.system, .light, .dark]

    /// Resolves a stored id, including the named themes earlier versions saved.
    static func find(_ id: String) -> AppTheme {
        switch id {
        case "light", "paper", "linen": .light
        case "dark", "graphite", "violet", "pine", "ember": .dark
        default: .system
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let systemThemeID = AppTheme.system.id

    @Published private(set) var current: AppTheme

    private let userData: UserData

    init(userData: UserData = .shared) {
        self.userData = userData
        current = AppTheme.find(userData.appTheme)
    }

    func setTheme(_ id: String) {
        current = AppTheme.find(id)
        userData.appTheme = current.id
        userData.save()
        applyAppearance()
    }

    /// `preferredColorScheme` restyles SwiftUI views but not the `NSAppearance` dynamic
    /// `NSColor`s resolve against, so the process appearance is set as well.
    func applyAppearance() {
        let name: NSAppearance.Name? = switch current.colorScheme {
        case .dark: .darkAqua
        case .light: .aqua
        default: nil
        }
        NSApp?.appearance = name.flatMap { NSAppearance(named: $0) }
    }
}
