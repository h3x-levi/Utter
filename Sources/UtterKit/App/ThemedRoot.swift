import SwiftUI

/// The root of an AppKit-hosted window's SwiftUI tree: applies the theme from a body that observes
/// `ThemeManager`, so an open window restyles when the theme changes. `ThemeManager.applyAppearance()`
/// sets `NSApp.appearance` for dynamic `NSColor`s; this restyles SwiftUI. No `.id(theme)`: rebuilding
/// the subtree would throw away the window's `@State`.
struct ThemedRoot<Content: View>: View {
    @ObservedObject private var theme = ThemeManager.shared
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .preferredColorScheme(theme.current.colorScheme)
    }
}
