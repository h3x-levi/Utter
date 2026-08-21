import SwiftUI

/// The root of an AppKit-hosted window's SwiftUI tree.
///
/// Applies the theme's appearance and accent from *inside a body that observes*
/// `ThemeManager`, which is the entire point. The onboarding and What's New windows
/// used to read `ThemeManager.shared.current.colorScheme` at the
/// `NSHostingView(rootView:)` call site: a value, not a dependency, so each window
/// kept whichever theme was current when it was created and only picked up a new
/// one when it was closed and reopened. The main window never had the bug because it
/// applies the same two modifiers from its own body, where the manager is observed —
/// now once per pane, since the window is an `NSSplitViewController` with two hosting
/// controllers (`FlowMainView.swift:197`, `:402`). Deliberately not routed through
/// this type: each pane observes the manager directly, and swapping that for
/// `ThemedRoot` would bet on a propagation equivalence no test here can check.
///
/// Both halves of a theme change are needed. `preferredColorScheme` restyles
/// SwiftUI's own views and pins the hosting view's `NSAppearance`;
/// `ThemeManager.applyAppearance()` — called from `setTheme`, so it runs on every
/// change — sets `NSApp.appearance` so dynamic `NSColor` tokens resolve against the
/// same appearance. Neither one covers the other.
///
/// Deliberately no `.id(theme.current.id)`. Keying the subtree on the theme rebuilds
/// it on every republish, which is what made the pill appear to pulse forever (see
/// the note in `PillWindow.swift:293`), and would also throw away the `@State` a
/// window is holding — the selected Settings group, the onboarding step. Observing
/// here invalidates this body instead, and the tokens are computed properties, so
/// the surfaces below re-read the new values.
struct ThemedRoot<Content: View>: View {
    @ObservedObject private var theme = ThemeManager.shared
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .preferredColorScheme(theme.current.colorScheme)
            .tint(Tint.accent)
    }
}
