import SwiftUI

// MARK: - The window's structure
//
// There used to be a single `SettingsWindowView` here: `HStack(spacing: 0) { groupList;
// paneDivider; detail }`, with `.frame(width: 152)` on the column, a hand-written
// `flushChromeGlass` on it, and `Layout.toolbarBand + Space.x3` of padding in both panes
// standing in for a titlebar. All of it is gone, for the reason `FlowMainView.swift` records for
// the main window: macOS only attaches automatic Liquid Glass, automatic scroll-edge treatment
// and automatic accessibility adaptation to chrome *structures* — a titlebar, an `NSToolbar`, an
// `NSSplitViewItem` sidebar — and an `HStack` is not one, so this layout could not inherit any of
// it however the glass was applied inside it. This was the same shape of window as the main one,
// carrying the same substitutes; it is now the same structure.
//
// The shell is AppKit's (`App.swift` → `showSettingsWindow`):
//
//     NSWindow  .titled + .fullSizeContentView, NSToolbar attached
//       └─ NSSplitViewController
//            ├─ NSSplitViewItem.sidebar(with: NSHostingController(SettingsSidebar))
//            └─ NSSplitViewItem(viewController: NSHostingController(SettingsDetail))
//                 automaticallyAdjustsSafeAreaInsets = true      // macOS 26
//
// and this file supplies only the two panes that go inside it.
//
// Measured offscreen on macOS 26.6.1 (SDK 26.5, arm64) at the 720x500 opening size, by a probe
// that assembled exactly this structure, forced layout and read back real view geometry without
// ever ordering a window front. Window points, top-down:
//
//                                    before (HStack)        after (split + toolbar)
//     titlebar band ................ 32, painting nothing   66, system-drawn
//     window controls .............. close y 9-33           close y 19-33
//     group-list surface ........... x 0-152,   y 0-500     x 8-160, y 8-492  (glass, concentric)
//     group-list safe area ......... top 32, ignored        top 58
//     "SETTINGS" label ............. y 42 (hand-tuned)      y 74 (58 + Space.x2)
//     detail pane frame ............ x 153-720, y 0-500     x 0-720, y 0-500
//     detail safe area ............. top 32, ignored        top 66, left 160
//     "General" heading ............ x 177, y 42            x 184, y 90
//     detail scroll contentInsets .. top 0                  top 66, visibleRect.y -66
//     scroll-edge pocket ........... none over the panes    NSScrollPocket / PocketBlur /
//                                                           NSHardPocketView, x 160-720, y 0-66
//     split divider view ........... hand-drawn 1pt rect    NSSplitDividerView, width 0
//
// What the system now draws that this file used to:
//
//   * **The group list's material.** AppKit wraps the sidebar item's view in an
//     `NSContainerConcentricGlassEffectView` on macOS 26 — real Liquid Glass, inset 8pt and
//     *concentric* with the window's corner radius, which the `glassEffect(.regular, in:
//     Rectangle())` behind `flushChromeGlass` structurally cannot be. Below 26 the same item
//     supplies the translucent `.sidebar` material its header documents.
//   * **The titlebar band.** Real chrome at 66pt, replacing 30pt of padding, with AppKit's
//     `NSScrollPocket` / `PocketBlur` / `NSHardPocketView` stack installed over the detail pane —
//     the macOS 26 scroll-edge effect, unasked for. Detail content scrolls *under* the band.
//   * **The traffic-light clearance.** The group list is handed a 58pt top safe-area inset, so
//     `Layout.toolbarBand` has nothing left to stand in for. That token is deleted.
//   * **Detail content running under the group list.** `automaticallyAdjustsSafeAreaInsets` makes
//     the detail item's view the whole window with a 160pt leading inset (152pt column + the
//     glass's 8pt outset) instead of a 567pt view beside the column. Measured with the flag off:
//     x 153-720 with no leading inset, i.e. byte-for-byte the old `HStack`. This is why the glass
//     had nothing but the desktop to refract before, and why `windowBackground` now reaches under
//     it: same surface, same veil, larger frame.
//   * **The separator.** `NSSplitDividerView` is 0pt wide on this configuration, with a
//     `_NSSplitViewShadowView` at the column's trailing edge instead — so `paneDivider` cannot
//     double up with a system line on macOS 26. It is kept for the paths that have no glass, and
//     it is load-bearing there: see its own note.
//
// Selection and hover are the system's too, as of this pass. The column was a `VStack` of
// `Button`s (`SettingsGroupRow`) carrying a hand-drawn white wash; it is now `List(selection:)`
// under `.listStyle(.sidebar)` — an `NSTableView` — which supplies the hover fill, the selection
// fill, arrow-key navigation and outline-row accessibility that a stack of buttons cannot.
//
// This is the swap `SidebarLift`'s note in FlowMainView.swift asked for and declined to make
// blind: "Worth doing as its own change, with the screen in front of someone." Both columns took
// it in the same pass — the main window's sidebar is a `List` too now, and `SidebarLift` and
// `SidebarRow` are deleted, so nothing in the package computes a sidebar row's fill any more.
//
// The trade that note described was that it would give up a *measured* invariant for one only a
// screen can check, and half of that turned out to be worth nothing: `SidebarLiftTests` passed
// while the reported bug shipped. It proved the lifts were **ordered** — `B + k(1-B)` is monotonic
// in k, so `0 < hover < selected` held over every backdrop — and light-mode hover was invisible
// anyway, because over a ~230/255 sidebar there are only ~25 units of headroom above the backdrop
// and 0.35 of that sits under the perceptual threshold. Ordering is not contrast, and a test that
// checks the arithmetic of a hand-painted wash cannot tell you whether anyone can see it. It has
// been replaced by `Tests/UtterKitTests/SidebarNavigationTests.swift`, which pins what code can
// actually decide: tag uniqueness, `primary == allCases`, every `item.icon` resolving as a real SF
// Symbol. What the system row's rendered contrast comes to, in both appearances over macOS 26
// glass, still has to be checked by looking at a screen — the difference is that the OS corrects
// it, rather than another hand-tuned opacity here.
//
// Two numbers the table above records for this column are therefore **no longer measured**: the
// "SETTINGS" label's y=74 was the hand-tuned `Space.x2` under the 58pt inset, and rows were
// `Layout.sidebarRowHeight` tall. A `List` positions its own section headers and sizes its own
// rows. Both want re-measuring on a screen; neither is load-bearing beyond the two columns
// reading as one design, which is the thing to check there.
//
// **The detail pane is still not glass**, and that is not an omission: it is the content layer,
// and GlassSurface.swift's opening note quotes the HIG's instruction not to put Liquid Glass
// behind content. Group headers stay small uppercase tracked labels ("SETTINGS", "ABOUT") — the
// reference design's signature label style, now carried by real `Section` headers.

// MARK: - Selection

/// Which pane the Settings window is showing.
///
/// This was `@State` on one view. The window is an `NSSplitViewController` with two hosting
/// controllers now, so the group list and the detail pane are separate SwiftUI trees with no
/// `@State` either could see; this object is the only thing joining them, exactly as
/// `SidebarSelection` joins the main window's two panes.
///
/// Behaviour is unchanged rather than assumed to be: `showSettingsWindow` stores its window in
/// `settingsWindow` and never clears the slot (`isReleasedWhenClosed = false`), so the old
/// `@State` already outlived a close and Settings already reopened on the pane you left. A
/// singleton does the same thing.
@MainActor
final class SettingsSelection: ObservableObject {
    static let shared = SettingsSelection()

    @Published var group: SettingsGroup = .general

    private init() {}
}

// MARK: - Group list pane

/// The settings group list: this window's navigation column.
///
/// The HIG names this element by name — Liquid Glass "forms a distinct functional layer for
/// controls and navigation elements — like tab bars and sidebars — that floats above the content
/// layer". This is a navigation column carrying controls, running the full height of the window;
/// the detail pane beside it is prose and cards. That is the test GlassSurface.swift states, and
/// this passes it on both halves. What changed is who draws the material: AppKit, not this file.
///
/// AppKit owns the width, collapse behavior, divider, selection, and keyboard navigation.
struct SettingsSidebar: View {
    @ObservedObject private var selection = SettingsSelection.shared
    /// Observed rather than read, and load-bearing: the design tokens are computed properties, so
    /// a theme change only reaches the surfaces below if *this* body is invalidated.
    /// `preferredColorScheme` alone restyles SwiftUI's own controls and does not re-read a token.
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared

    // No `@Environment(\.colorScheme)` / `isDark` here any more. They existed to feed
    // `SidebarLift`, which the `List` replaced; nothing else in this pane resolves per appearance,
    // and the two modifiers below are what carry the theme down.

    /// The two modifiers applied per pane rather than by wrapping both in `ThemedRoot`, following
    /// `FlowSidebar`/`FlowContent` and `ThemedRoot`'s own note: "each pane observes the manager
    /// directly, and swapping that for `ThemedRoot` would bet on a propagation equivalence no test
    /// here can check." This window used `ThemedRoot` while it was one tree; two trees make it the
    /// main window's case, so it takes the main window's answer. Both halves of a theme change
    /// still arrive — `preferredColorScheme` here, `NSApp.appearance` from `ThemeManager.setTheme`
    /// — and a theme change reaches an already-open window because the manager is observed above,
    /// which is the bug `ThemeManager` documents.
    var body: some View {
        column
            .preferredColorScheme(theme.current.colorScheme)
    }

    /// No background on any path, and that is deliberate on all three.
    ///
    /// On macOS 26 the surface is the split item's own Liquid Glass, and drawing anything here
    /// would composite over it and destroy it — the same line `FlowSidebar.surface` records.
    /// Below 26, and under Reduce Transparency, this column drew *nothing* before either: it was
    /// `flushChromeGlass`, which is a passthrough on both of those paths, over the one
    /// `windowBackground` that covered the whole window. That has not changed, because the detail
    /// pane's plane still covers the whole window — it is behind this column now instead of beside
    /// it (measured x 0-720, y 0-500). So those two paths are byte-identical to what shipped,
    /// which is the only way to leave them without an accessibility switch and a screen to check.
    ///
    /// What is **unverified** is what AppKit adds underneath: the sidebar item is documented to
    /// supply a translucent material below macOS 26 and to adapt under Reduce Transparency. If it
    /// does, this column gains a material it did not have on those paths — closer to the macOS 26
    /// look, not further from it — and `paneDivider` still separates the panes either way.
    ///
    /// `.scrollContentBackground(.hidden)` is the one thing the `List` needs to keep that promise.
    /// `.listStyle(.sidebar)` paints a sidebar material of its own, and drawing that *inside* the
    /// split item's Liquid Glass is the glass-on-glass the HIG warns against — two materials
    /// sampling each other rather than the window. Hidden, the rows composite straight onto
    /// AppKit's glass, exactly as the buttons did. Whether hiding the scroll background also
    /// suppresses every part of the `.sidebar` style's own fill is **not verifiable from here** —
    /// it needs the window on a screen in both appearances.
    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            // No `GlassCluster` around the list.
            //
            // A `GlassEffectContainer` batches sibling `glassEffect` views into one render pass,
            // and there is not one glass view in this subtree — the rows' fills are the table
            // view's, and the glass is the system's, outside this tree entirely. A container here
            // would group nothing while claiming a batching win, and nesting one inside the
            // system's sidebar glass would be glass on glass. `FlowSidebar.navRows` records the
            // same for the same reason.
            //
            // The two `Section`s replace two hand-padded `Text` labels above two `VStack`s. They
            // keep `.typo(.microLabel)` — the reference design's uppercase tracked label, which is
            // a *font* decision the list style has no opinion about — while the list supplies the
            // header's inset, its spacing to the rows and, on macOS, its collapse affordance.
            List(selection: animatedSelection) {
                Section("Settings") {
                    ForEach(SettingsGroup.settingsGroup, content: row)
                }

                Section("About") {
                    ForEach(SettingsGroup.aboutGroup, content: row)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, Layout.sidebarRowHeight)

            // Version pinned to the base, like the reference. The HIG warns against putting
            // anything critical at the bottom of a sidebar, which is exactly why the version
            // string lives here.
            //
            // Outside the `List`, not a last row in it: it is not selectable, and a row in a
            // single-selection table that cannot be selected is a row the arrow keys walk into and
            // stop dead on. Keeping it a sibling below the list also keeps it pinned when the list
            // scrolls, which is what the old `Spacer(minLength:)` was doing by hand.
            Text("Utter \(ConfigManager.shared.appVersion)")
                .typo(.caption, ink: Ink.tertiary)
                .padding(.horizontal, Space.x3)
                .padding(.bottom, Space.x3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .trailing) { paneDivider }
    }

    /// One row. `Label`, not an `HStack` of a sized `Image` and a weighted `Text`: the sidebar list
    /// style already sizes the glyph, aligns the two columns, and steps the label's weight and ink
    /// on selection — which is why `isSelected` is gone from here. `.tag` is what makes the row
    /// selectable at all; `ForEach` over `Identifiable` matches on `id` (a `String` here), and the
    /// selection is a `SettingsGroup`, so without the tag nothing would ever select.
    private func row(_ item: SettingsGroup) -> some View {
        Label(item.title, systemImage: item.icon)
            .tag(item)
    }

    /// The selection binding, with the crossfade kept.
    ///
    /// `List` writes its selection directly, outside any transaction, and `SettingsDetail` fades
    /// panes with `.transition(.opacity)` keyed on `.id(group)` — so a bare `$selection.group`
    /// would turn that crossfade into a hard cut. The write is wrapped here instead, in the same
    /// curve the deleted `select(_:)` used, so the animation survives the control swap and still
    /// collapses under Reduce Motion.
    private var animatedSelection: Binding<SettingsGroup> {
        Binding(
            get: { selection.group },
            set: { newValue in
                withAnimation(motion.reduceMotion ? Motion.reduced : Motion.listChange) {
                    selection.group = newValue
                }
            }
        )
    }

    /// The rule between the two panes — on the paths where this column draws no glass.
    ///
    /// It moved from a sibling `Rectangle` in the deleted `HStack` to a trailing overlay on this
    /// pane, which is the only place it can live now that the panes are separate hosting
    /// controllers. It lands on the column's own trailing edge, so it is the pane boundary by
    /// construction whether or not the glass wrapper's 8pt outset is present — which matters,
    /// because whether that wrapper survives Reduce Transparency is exactly what cannot be
    /// checked from here.
    ///
    /// Still load-bearing, and now more so. Under Reduce Transparency both panes resolve to the
    /// same flat `Surface.canvas` — this column draws nothing and `windowBackground`'s
    /// Reduce Transparency branch is that colour — so without this hairline there is nothing
    /// dividing them at all. `GlassSupportTests` pins the invariant: exactly one separator on
    /// every configuration, a live glass edge or this line, never both.
    ///
    /// Dropped on the glass path for two measured reasons. The material draws its own silhouette
    /// — its highlights "move in space, causing light to travel around the material, defining its
    /// silhouette", which is why `ChromeGlass.glass` refuses to stroke a rim on macOS 26 — and
    /// AppKit's own `NSSplitDividerView` is 0pt wide here, with a `_NSSplitViewShadowView` at the
    /// column's trailing edge doing the separating. A static 1pt line butted against that would be
    /// a seam through the glass beside a system shadow.
    ///
    /// Not `.ignoresSafeArea()`, unlike the version it replaces: this runs the height of the
    /// column's safe area, so it stops at the band's lower edge rather than crossing a titlebar
    /// the system now paints. Measured, at 720x500: window x 159-160, y 66-492 — the column's
    /// trailing edge, from the band's lower edge to the column's foot, immediately beside the
    /// 160pt leading inset where the detail pane's content region begins.
    ///
    /// `GlassSupport.active` needs no `#available` — it names no macOS 26 symbol, it answers the
    /// policy question, and the answer is `false` on every earlier OS.
    @ViewBuilder
    private var paneDivider: some View {
        if !GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            Rectangle()
                .fill(Line.hairline)
                .frame(width: 1)
        }
    }
}

// MARK: - Detail pane

/// The selected group's rows, and the window's content layer.
///
/// Full-bleed, and now genuinely so: the view this sits in is the *whole window* — AppKit gives
/// the detail split item a 720x500 frame with a 160pt leading safe-area inset rather than a 567pt
/// frame beside the column — so `windowBackground` extends under the group list's glass and under
/// the titlebar band, and both have app content to refract instead of only the desktop. Measured:
/// the background lands at x 0-720, y 0-500; the first heading at x=184 (160 + `Space.x6`), y=90.
///
/// Three modifiers are deleted rather than adjusted, because the system supplies what each faked:
///
///   * `.ignoresSafeArea(.container, edges: .top)` on the root — it existed to cancel the 32pt
///     titlebar inset that stacked with the hand-drawn band, and to let the glass column run full
///     height. The band *is* the inset now, and the column's full-height layout is AppKit's
///     (`allowsFullHeightLayout`, free on a `.fullSizeContentView` window — measured: glass y 8 to
///     492 in a 500pt window, i.e. up behind the window controls). It is not simply moved here:
///     the background carries `.ignoresSafeArea()` at the call site instead, so the plane reaches
///     the window's edges while the scroll *content* stays inside the safe area.
///   * `.padding(.top, Layout.toolbarBand + Space.x3)` — 42pt standing in for a titlebar. The real
///     band is 66pt and arrives as a safe-area inset, which SwiftUI turns into the scroll view's
///     `contentInsets` rather than a shorter scroll view: measured `contentInsets.top = 66`,
///     `documentVisibleRect.y = -66`. Content scrolls under the band and the system's pocket
///     softens the cut. No `contentMargins` needed, and `scrollEdgeEffectStyle` is deliberately
///     still not set here — it collapsed a window to ~133pt when tried, it is `macos(26.1)` rather
///     than 26.0, and the pocket is already doing the job.
///   * The three-way top/horizontal/bottom padding, folded into one uniform `Space.x6` inset, the
///     same as `FlowContent`. The heading now sits 24pt below the band instead of 12pt below a
///     band that painted nothing: 12 would have been the arithmetically "unchanged" gap, but the
///     old gap was measured against nothing being drawn, and 24 is what the main window sits at
///     under the identical band.
struct SettingsDetail: View {
    @ObservedObject private var selection = SettingsSelection.shared
    /// Observed for the same reason as in `SettingsSidebar`: the tokens are computed properties
    /// and a theme change has to invalidate this body to be seen. This is the dependency that
    /// `windowBackground` needs — it resolves `Surface.canvas`, which reads
    /// `ThemeManager.shared.current`, and reading that at a call site is a value, not a
    /// dependency. Without it the window held the old canvas: invisible when the appearance
    /// flipped too, obvious between two themes of the same appearance (Paper → Linen).
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var group: SettingsGroup { selection.group }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            Text(group.title)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, Space.pageInset)
                .padding(.top, Space.pageInset)

            if group.ownsScrolling {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    detail
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.pageInset)
                        .padding(.bottom, Space.pageInset)
                }
                // A pane is a new destination, not another document at the previous pane's
                // absolute scroll offset. Recreate the scroller with the selection so Speech
                // cannot open halfway through its model list after leaving a long General pane.
                .id(group)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.ignoresSafeArea()` on the surface, not on the scroll view: the plane has to reach the
        // window's edges so the column's glass and the titlebar pocket have something to sample,
        // while the scroll content stays inside the safe area. Applied at the call site so the
        // Reduce Transparency branch is covered without that branch being edited — the same
        // arrangement as `FlowContent`.
        .background(windowBackground.ignoresSafeArea())
        .preferredColorScheme(theme.current.colorScheme)
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch group {
            case .general: GeneralSettingsContent()
            case .speech: SpeechSettingsContent()
            case .appearance: AppearanceSettingsContent()
            case .companion: CompanionSettingsContent()
            case .privacy: PrivacySettingsContent()
            case .diagnostics: DiagnosticsSettingsContent()
            case .about: AboutContent()
            }
        }
        .transition(.opacity)
        .id(group)
    }

    /// The window's content plane — and, on macOS 26, the surface the group list's glass refracts.
    /// Unchanged, down to the token values, and now covering the whole window rather than the
    /// region beside the column.
    ///
    /// Still `.underWindowBackground` plus `Veil.windowShell`, deliberately, rather than following
    /// `FlowContent` to `.contentBackground` plus `Veil.contentSurface`. Two reasons: the
    /// alignment to `windowShell` was itself a deliberate fix (the note below), and switching
    /// veils would retone every pixel of this window — including the contrast of every card in the
    /// detail pane — to fix nothing that was reported. The thinner veil also means the glass
    /// column here samples more desktop than the main window's does, which reads as *more* glass,
    /// not less.
    ///
    /// The contrast hazard `FlowContent.windowSurface` records for this mix (`Ink.secondary`
    /// estimated at ~4.1:1 when the material tracks a black wallpaper) is unchanged by this pass:
    /// the rows already sat on this exact stack, and putting a larger frame under the same glass
    /// does not thin the veil.
    private var windowBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }
}

// MARK: - Groups

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable {
    case general, speech, appearance, companion, privacy, diagnostics, about

    var id: String { rawValue }

    /// The two groups shown under each header. Named `...Group` to avoid
    /// colliding with the `about` case itself.
    /// `.companion` is deliberately absent: it moved to the main window's sidebar,
    /// where a visual choice belongs. Listing it in both places would be the same
    /// duplication that put Privacy and About in two menus.
    static let settingsGroup: [SettingsGroup] = [.general, .speech, .appearance]
    /// Diagnostics sits beside Privacy rather than in the settings group: like
    /// Privacy and About it reports on the app rather than configuring it —
    /// there is nothing on the pane to set.
    static let aboutGroup: [SettingsGroup] = [.privacy, .diagnostics, .about]

    var title: String {
        switch self {
        case .general: return "General"
        case .speech: return "Speech"
        case .appearance: return "Appearance"
        case .companion: return "Companion"
        case .privacy: return "Privacy"
        case .diagnostics: return "Diagnostics"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .speech: return "waveform"
        case .appearance: return "paintbrush"
        // A face, for the one pane that is about a character. `pawprint` was the
        // obvious pick and is wrong: two of the four characters aren't animals.
        case .companion: return "face.smiling"
        case .privacy: return "lock.shield"
        // `stethoscope`, not `ladybug`: the pane reports on the app's health, and
        // a bug glyph in shipped settings suggests the app has one.
        case .diagnostics: return "stethoscope"
        case .about: return "info.circle"
        }
    }

    var ownsScrolling: Bool {
        switch self {
        case .general, .speech, .appearance, .companion, .privacy, .about:
            return true
        case .diagnostics:
            return false
        }
    }
}

// `SettingsGroupRow` is gone: a `Button` per row, a `@State isHovering` + `.onHover` pair, a
// hand-written `.accessibilityAddTraits(.isSelected)`, and a three-branch `background` painting
// `SidebarLift`'s white washes. `List(selection:)` supplies every one of those, so what is left of
// a row is `Label(_:systemImage:).tag(_:)` in `SettingsSidebar.row`. The one thing it did that had
// to be re-supplied by hand is the selection *animation* — see `animatedSelection`.

// MARK: - Appearance

/// Theme selection, split out of General.
///
/// It was previously one card among many in a long General pane; with a real
/// settings window there is room to give appearance its own group, which is also
/// where a user looks for it.
///
/// `Form` + `Section` rather than `SettingsCard`, with the description moved from above the grid to
/// the section's `footer`. That is the order System Settings uses — control first, explanation
/// under it, in the footer's own secondary ink — and it is the reason the caption no longer sets
/// `.typo(.caption)` or `fixedSize`: a grouped form's footer already carries that size, that ink
/// and multi-line wrapping. The string itself is unchanged.
struct AppearanceSettingsContent: View {
    var body: some View {
        Form {
            Section {
                ThemeSwatchGrid()
            } header: {
                Text("Theme")
            } footer: {
                Text("Sets the appearance and accent colour, across the window and the pill.")
            }
        }
        .settingsForm()
    }
}
