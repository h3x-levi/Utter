import SwiftUI

// MARK: - Navigation

/// A sidebar destination.
///
/// Split into two groups, following the reference layout: feature pages at the
/// top, utility items pinned to the bottom of the column. Settings is deliberately
/// *not* a page any more — it opens its own window.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case dictation = "Dictation"
    case dictionary = "Dictionary"
    case snippets = "Snippets"
    case commands = "Transforms"
    case notes = "Notes"
    /// The companion lives here, not in Settings: it is a thing you *look at and
    /// choose*, like your snippets, rather than a preference you set once. Buried in
    /// Settings it was also effectively hidden — nobody browses Settings for a
    /// character.
    case companion = "Companion"

    var id: String { rawValue }

    /// Every sidebar destination. There is only one group now.
    ///
    /// Privacy and About used to sit here *and* in the Settings window. They are
    /// configuration and reference, not places you work, so they live in Settings
    /// only — which also puts "Reset Utter" alongside the other settings instead
    /// of next to your snippets. The sidebar is now exactly the things you do and
    /// the content you own.
    static let primary: [SidebarItem] = [
        .dictation, .dictionary, .snippets, .commands, .notes, .companion,
    ]

    /// Outline glyphs. The reference uses outline icons throughout at a light
    /// stroke weight — filled symbols read heavier and more consumer.
    var icon: String {
        switch self {
        case .dictation: return "mic"
        case .dictionary: return "character.book.closed"
        case .snippets: return "scissors"
        case .commands: return "wand.and.rays"
        case .notes: return "note.text"
        case .companion: return "figure.wave"
        }
    }
    @MainActor

    var subtitle: String {
        switch self {
        case .dictation:
            let count = TranscriptionHistory.shared.totalWords
            return count == 1 ? "1 word dictated" : "\(count) words dictated"
        case .dictionary:
            let count = UserData.shared.dictionaryWords.count
            return count == 1 ? "1 word" : "\(count) words"
        case .snippets:
            let count = UserData.shared.snippets.count
            return count == 1 ? "1 snippet" : "\(count) snippets"
        case .commands:
            let count = UserData.shared.customAICommands.count
            return count == 1 ? "1 custom transform" : "\(count) custom transforms"
        case .notes:
            let count = NoteStore.shared.notes.count
            return count == 1 ? "1 note" : "\(count) notes"
        case .companion:
            return UserData.shared.companionEnabled ? "On" : "Off"
        }
    }
}

/// Which sidebar destination the main window is showing.
///
/// Shared state rather than `@State` inside a view, because something *outside* the window now has
/// to put a particular screen in front of the user: accepting the offer to transcribe a call has to
/// land on Notes, where the running-capture banner lives (`NotesView.meetingBar`). Notifying the
/// view would have raced its first layout — `showMainWindow` creates the window and shows it in one
/// call, so a post afterwards can arrive before an `onReceive` has subscribed — and state the view
/// *reads* cannot race, whichever order the two happen in.
///
/// It is now also what couples the two panes. The sidebar and the content column are separate
/// SwiftUI trees in separate hosting controllers (see the file note below), so there is no shared
/// `@State` they could both see; this object is the only thing joining them, and it already existed.
///
/// It also gives `--screen` one home. That parsing was inside the view's `@State` initialiser, which
/// is the one place a second window or a re-created view would silently have re-run it.
@MainActor
final class SidebarSelection: ObservableObject {
    static let shared = SidebarSelection()

    @Published var item: SidebarItem

    private init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--screen"), i + 1 < args.count,
           let item = SidebarItem.allCases.first(where: {
               $0.rawValue.lowercased() == args[i + 1].lowercased() }) {
            self.item = item
        } else {
            self.item = .dictation
        }
    }
}

// MARK: - The window's structure
//
// There used to be a single `FlowMainView` here: `HStack(spacing: 0) { sidebar; content }`, with a
// hand-written `glassEffect(.regular, in: Rectangle())` on the sidebar column and a hand-drawn 30pt
// `Layout.toolbarBand` of padding standing in for a titlebar. It is gone, and this is the reason:
// none of it could inherit anything, because a `Rectangle` with a glass modifier on it is not a
// chrome *structure*, and macOS only attaches automatic Liquid Glass, automatic scroll-edge
// treatment and automatic accessibility adaptation to structures — a titlebar, an `NSToolbar`, an
// `NSSplitViewItem` sidebar, a sheet, a popover, a menu.
//
// So the shell is AppKit's now (`App.swift` → `showMainWindow`):
//
//     NSWindow  .titled + .fullSizeContentView, NSToolbar attached
//       └─ NSSplitViewController
//            ├─ NSSplitViewItem.sidebar(with: NSHostingController(FlowSidebar))
//            └─ NSSplitViewItem(viewController: NSHostingController(FlowContent))
//                 automaticallyAdjustsSafeAreaInsets = true      // macOS 26
//
// and this file supplies only the two SwiftUI panes that go inside it.
//
// What the system now draws that this file used to:
//
//   * The sidebar's material. AppKit wraps the sidebar item's view in an
//     `NSContainerConcentricGlassEffectView` on macOS 26 — real Liquid Glass, inset 8pt and
//     *concentric* with the window's corner radius, which a `glassEffect(.regular, in: Rectangle())`
//     cannot be. Below macOS 26 the same item supplies the translucent `.sidebar` material its
//     header documents. Whether it also substitutes for itself under Reduce Transparency — the
//     adaptation the HIG promises for standard components and withholds from custom ones — is
//     **unverified**, so `FlowSidebar` keeps its own opaque fill on that path rather than trust it.
//   * The titlebar band. Real chrome, 66pt with the toolbar attached, replacing 30pt of padding.
//     AppKit installs its `NSScrollPocket` / `PocketBlur` / `NSHardPocketView` stack there, i.e. the
//     macOS 26 scroll-edge effect, so content scrolling under the band is softened by the system.
//     The comment this file used to carry ("that needs toolbar glass this window does not have") is
//     answered: it has one now.
//   * The traffic-light clearance. The sidebar pane is handed a 58pt top safe-area inset, so the
//     wordmark clears the close button without a hand-tuned constant. Measured below.
//   * Content running *under* the sidebar. `automaticallyAdjustsSafeAreaInsets` makes the content
//     item's view the full window with a 176pt leading safe-area inset, instead of a 1004pt view
//     sitting beside the sidebar. This was structurally impossible with the `HStack`, and it is why
//     nothing could refract app content before: the glass had only the desktop to sample.
//
// Measured on macOS 26.5 (SDK 26.5) at the 1180x820 opening size, in top-down window points, with
// an offscreen probe that built exactly this structure and read back real view geometry:
//
//     titlebar + toolbar band ....... 66      (was 30, hand-drawn)
//     close button .................. y 19-33, x 19-33
//     sidebar glass ................. x 8-176, y 8-812   (concentric, system-drawn)
//     sidebar pane safe area ........ top 58
//     content pane .................. x 0-1180, y 0-820, safe area top 66 / left 176
//     wordmark ...................... x 20, y 74         (was x 12, y 46)
//     first line of content ......... x 200, y 90        (was x 192, y 54)
//     content plane (background) .... x 0-1180, y 0-820  — full window, under both glass surfaces
//
// The content moves down 36pt and right 8pt, and that is the honest price of a real band: the first
// line of text sits 24pt below the chrome in both layouts (54 - 30 = 24, 90 - 66 = 24). The gap did
// not change; the band did, because it stopped being padding.
//
// Two things AppKit does *not* supply and this file still does:
//
//   * The row selection and hover treatment (`SidebarRow`, `SidebarLift`). The panes host SwiftUI
//     buttons, not an `NSTableView`, so no system selection arrives. Swapping them for
//     `List(selection:).listStyle(.sidebar)` would get one — see `SidebarLift`'s note for why that
//     was not done here.
//   * The content layer itself (`FlowContent.windowSurface`). That is a standard material, which is
//     what the HIG asks for in the content layer, and it is deliberately not glass.

// MARK: - Sidebar pane

/// The sidebar's contents. Draws no surface of its own on macOS 26 — the surface is the
/// `NSSplitViewItem` sidebar's own Liquid Glass, supplied by AppKit.
///
/// The column no longer sets its own width. `Layout.sidebarWidth` is expressed to AppKit as the
/// split item's `minimumThickness`/`maximumThickness` in `showMainWindow`, so there is one owner of
/// that number and it is the one the system lays out from; this fills whatever thickness it is given.
struct FlowSidebar: View {
    @ObservedObject private var selection = SidebarSelection.shared
    private var selected: SidebarItem { selection.item }

    /// Observed rather than read, and this is load-bearing: the design tokens are computed
    /// properties, so a theme change only reaches the surfaces below if *this* body is invalidated.
    /// `preferredColorScheme` alone restyles SwiftUI's own controls and does not re-read a token.
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// Opens the Settings window. Injected by the app delegate.
    var onOpenSettings: () -> Void = {}

    var body: some View {
        surface
            .preferredColorScheme(themeManager.current.colorScheme)
            .tint(Tint.accent)
    }

    /// The sidebar's backdrop, on the three paths that differ.
    ///
    /// The macOS 26 branch draws *nothing*, and that is the change: it used to be
    /// `column.glassEffect(.regular, in: Rectangle())`, and the system now puts the column inside an
    /// `NSContainerConcentricGlassEffectView` instead. Drawing anything here would composite over
    /// that and destroy it.
    ///
    /// The other two branches are unchanged, deliberately, down to the token values. AppKit's
    /// sidebar item supplies a translucent material below macOS 26 and is documented to adapt under
    /// Reduce Transparency, which makes both of these arguably redundant — but "arguably" is not
    /// "verified", the adaptation cannot be checked without the accessibility switch and a screen,
    /// and an opaque fill drawn over an opaque substitute is byte-identical to what shipped. So they
    /// stay: the cost is a material drawn twice on old systems, and the alternative risks an
    /// accessibility regression that no test in this suite would catch.
    ///
    /// `GlassSupport.active` is the whole condition now. It used to be paired with a lexical
    /// `#available(macOS 26.0, *)` because `glassEffect` does not exist below 26 and a runtime `Bool`
    /// cannot satisfy the compiler; with the call gone, so is the reason for the pairing.
    @ViewBuilder
    private var surface: some View {
        if GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            column
        } else if motion.reduceTransparency {
            column.background(Surface.canvas)
        } else {
            column.background(
                ZStack {
                    WindowBacking(material: .sidebar)
                    // A warm veil so the column reads warm on any wallpaper, thin
                    // enough to keep the material alive underneath.
                    Surface.canvas.opacity(Veil.windowShell(isDark: isDark))
                }
            )
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            wordmark
            navRows
            Spacer(minLength: Space.x4)
            bottomBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Brand mark, below the traffic lights.
    ///
    /// The top pad was `Layout.toolbarBand + Space.x4` (46pt) — a hand-tuned clearance for the
    /// window controls. AppKit hands this pane a 58pt top safe-area inset now, so the clearance is
    /// the system's and this is only the gap below the band: measured, the mark lands at y=74 with
    /// the close button ending at y=33. `Space.x2` rather than the old `Space.x4` because the band
    /// grew 36pt when it became real, and matching the old 16pt gap would have pushed the mark to 82.
    ///
    /// Known edge, not guarded: hiding the toolbar from its contextual menu drops that inset to 10pt
    /// and the mark would land on the window controls. Recoverable by showing the toolbar again, and
    /// guarding it would mean reading the safe area back out and flooring it — machinery for a case
    /// that costs a right-click to undo.
    private var wordmark: some View {
        HStack(spacing: Space.x2) {
            AppIconView(size: 17)
            Text("Utter").typo(.subheading, ink: Ink.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.x3)
        .padding(.top, Space.x2)
        .padding(.bottom, Space.x4)
    }

    /// No `GlassCluster` here.
    ///
    /// A `GlassEffectContainer` groups sibling `glassEffect`s into one render pass, and there is not
    /// one left in this app's sidebar: the rows draw plain fills (see `SidebarRow.rowBackground`) and
    /// the glass is the system's, outside this tree entirely. A container with no effects inside it
    /// is a no-op that reads, to the next person, as a promise that glass lives in here. Nesting one
    /// inside the system's sidebar glass would also be the glass-on-glass the HIG warns against.
    private var navRows: some View {
        VStack(spacing: 2) {
            ForEach(SidebarItem.primary) { item in
                SidebarRow(item: item, isSelected: selected == item) {
                    select(item)
                }
            }
        }
        .padding(.horizontal, Space.x2)
    }

    /// Usage summary plus the utility rows, pinned to the base of the column.
    ///
    /// macOS 26 has a system component for exactly this — `bottomAlignedAccessoryViewControllers`
    /// on the split item, which insets and pins its own accessory. Not used: it is 26-only, so it
    /// would need this `Spacer`-pinned layout kept alongside it as the pre-26 path, and two layouts
    /// for one footer is worse than one that already works on both.
    private var bottomBlock: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            UsageCard()
                // Same inset as the nav rows, so the card's left edge lines up
                // with the selection pills rather than hugging the window edge.
                .padding(.horizontal, Space.x2)
                .padding(.bottom, Space.x1)

            // Settings opens its own window rather than being a page, so this
            // is an action row, not a destination — hence never "selected".
            // No `GlassCluster`, for the reason given at `navRows`.
            SidebarRow(
                title: "Settings",
                icon: "gearshape",
                isSelected: false,
                action: onOpenSettings
            )
            .padding(.horizontal, Space.x2)
        }
        .padding(.bottom, Space.x3)
    }

    private func select(_ item: SidebarItem) {
        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.listChange) {
            selection.item = item
        }
    }
}

// MARK: - Content pane

/// The content column: the screens themselves, and the window's content layer.
///
/// Full-bleed, and now genuinely so. The view this sits in is the *whole window* — AppKit gives the
/// content split item a 1180x820 frame with a 176pt leading safe-area inset rather than a 1004pt
/// frame beside the sidebar — so `windowSurface` extends under the sidebar's glass and under the
/// titlebar band, and both have app content to refract instead of only the desktop. Measured: the
/// background lands at x 0-1180, y 0-820; the first line of text at x=200 (176 + `Space.x6`).
///
/// Two modifiers are deleted rather than adjusted, because the system supplies what each faked:
///
///   * `.ignoresSafeArea(.container, edges: .top)` — it existed to cancel the titlebar inset that
///     stacked with the hand-drawn band, and to let the sidebar's glass run full height. The band is
///     the inset now, and the sidebar's full-height layout is AppKit's (`allowsFullHeightLayout`,
///     default true on a `.fullSizeContentView` window — measured: glass 8pt to 812pt in an 820pt
///     window, i.e. up behind the window controls).
///   * `.padding(.top, Layout.toolbarBand)` — 30pt of padding standing in for a titlebar. The real
///     band is 66pt and arrives as a safe-area inset, which SwiftUI converts into the scroll view's
///     `contentInsets` rather than into a smaller scroll view: measured `contentInsets.top = 66` on a
///     full-window `HostingScrollView`, `documentVisibleRect.y = -66`. So content scrolls *under*
///     the band and the system's scroll-edge pocket softens the cut — which is precisely the
///     vertical bleed the old comment here said would read correctly and could not be had. It needed
///     no `contentMargins` (macOS 14+, so it would have needed a second path anyway).
struct FlowContent: View {
    @ObservedObject private var selection = SidebarSelection.shared
    private var selected: SidebarItem { selection.item }

    /// Observed for the same reason as in `FlowSidebar`: the tokens are computed properties and a
    /// theme change has to invalidate this body to be seen.
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    /// Both feed `SidebarItem.subtitle`, which is rendered here.
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var userData = UserData.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text(selected.rawValue).typo(.title)
                    Text(selected.subtitle).typo(.lede)
                }
                .padding(.bottom, Space.groupGap)

                detailView
                    .transition(.opacity)
                    .id(selected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Equal padding on all four sides. The bottom edge previously had
            // none, so the last tile ran off the bottom of the viewport and was
            // clipped by it. This is also the only thing holding text off the window's
            // right and bottom edges, and — via the leading safe-area inset it now sits
            // inside — off the sidebar's glass.
            .padding(Space.x6)
        }
        // Always show the scroll indicator.
        //
        // The content is taller than the viewport, so the last tile is cut off at
        // the window's bottom edge. That is correct scroll behaviour, but with the
        // indicator hidden it read as a layout bug — nothing told the user there
        // was more below, and macOS hides overlay scrollers until you scroll.
        //
        // Note: `scrollEdgeEffectStyle` is still not set here. It collapsed the window to ~133pt
        // when tried, it is `macos(26.1)` rather than 26.0, and the band's pocket already applies
        // the system's edge treatment without being asked. Nothing left to gain for that risk.
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.ignoresSafeArea()` on the surface, not on the scroll view: the plane has to reach the
        // window's edges so the sidebar glass and the titlebar pocket have something to sample,
        // while the scroll *content* stays inside the safe area. Applied at the call site rather
        // than inside `windowSurface` so the Reduce Transparency branch is covered without that
        // branch being edited.
        .background(windowSurface.ignoresSafeArea())
        .preferredColorScheme(themeManager.current.colorScheme)
        .tint(Tint.accent)
    }

    // MARK: Window surface

    /// The window's one continuous surface — the surface every screen's text sits directly on.
    ///
    /// This is the *content* layer in the HIG's sense: "use standard materials for
    /// elements in the content layer, such as app backgrounds." So it is a
    /// `NSVisualEffectView` plus a themed veil, never `glassEffect`. The glass in
    /// this window is the sidebar's, and it is AppKit's, floating above this.
    ///
    /// The material and the veil are the ones the content *card* used — `.contentBackground`
    /// and `Veil.contentSurface` — kept unchanged when the card was deleted, because carrying text
    /// is this surface's job. Note that this inverts what those two token names imply: with the card
    /// gone the window shell *is* the content surface, and `Veil.windowShell` now describes only the
    /// sidebar's pre-macOS-26 strip. All three of the ramp's veils therefore still have exactly one
    /// user each, and the ramp the tests pin still holds where it is about nesting: plane 0.72 under
    /// tiles at 0.86 (`Veil.nestedSurface`, via `BentoTile`). The sidebar strip's 0.42 is not part of
    /// that ordering and must not be read as breaking it: it is chrome sitting *above* the plane, and
    /// being thinner than what it covers is its job. On macOS 26 it is not a veil at all — it is the
    /// system's glass.
    ///
    /// Working the arithmetic on the tokens: `Ink.secondary` lands at ~5.8:1 on the
    /// card's mix (raised at 0.72 over a light material), ~5.3:1 on the old window
    /// mix (canvas at 0.42), and ~4.1:1 on that same mix if the material tracks a
    /// black wallpaper — under the 4.5:1 floor for body text. The veil opacities
    /// are exact; the material's own luminance is assumed (0.93 light / 0.75 behind
    /// black), so treat the two lower figures as an estimate of a real hazard
    /// rather than a screenshot measurement. Either way the content region's tone
    /// is byte-for-byte what it was before the split-view change: the same material and the same
    /// veil, over a larger frame.
    @ViewBuilder
    private var windowSurface: some View {
        if motion.reduceTransparency {
            Surface.raised
        } else if #available(macOS 26.0, *) {
            ZStack {
                WindowBacking(material: .contentBackground).ignoresSafeArea()
                Surface.raised.opacity(Veil.contentSurface(isDark: isDark))
                    .ignoresSafeArea()
            }
        } else {
            ZStack {
                WindowBacking(material: .contentBackground).ignoresSafeArea()
                Surface.raised.opacity(Veil.contentSurfaceLegacy(isDark: isDark))
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selected {
        case .dictation: HomeView()
        case .dictionary: DictionaryView()
        case .snippets: SnippetsView()
        case .commands: StyleView()
        case .notes: NotesView()
        case .companion: CompanionSettingsContent()
        }
    }
}

// MARK: - Sidebar row

/// One sidebar row.
///
/// The selected row is a full-width rounded rect filled with a neutral white
/// wash — not glass, not an accent tint. It reads as lifted off the sidebar
/// because it is literally lighter than it, in both appearances. The reference
/// uses no accent colour here at all, and that restraint is deliberate: a
/// saturated fill in a 168pt column dominates the window. The label steps from
/// secondary to primary ink instead.
///
/// Hover is the same gesture at `SidebarLift`'s reduced strength, and that is a
/// fix, not a detail — see the type's own note.
private struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    init(item: SidebarItem, isSelected: Bool, action: @escaping () -> Void) {
        self.title = item.rawValue
        self.icon = item.icon
        self.isSelected = isSelected
        self.action = action
    }

    init(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.x2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(isSelected ? Ink.primary : Ink.secondary)
                Text(title)
                    .typo(.callout, ink: isSelected ? Ink.primary : Ink.secondary)
                    .fontWeight(isSelected ? .medium : .regular)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.x2)
            .frame(height: Layout.sidebarRowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .contentShape(Radius.rect(Radius.control))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) {
                isHovering = hovering
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var rowBackground: some View {
        let shape = Radius.rect(Radius.control)
        if isSelected {
            // Same routing as `FlowSidebar.surface`: one helper for the decision. The
            // `#available` that used to sit here is gone with the `glassEffect` call it was
            // guarding; what is left is policy, and `GlassSupport.active` owns that.
            if GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
                // A plain white wash on the sidebar's glass. No `glassEffect` on
                // this row, and that is measured, not taste.
                //
                // Glass here rendered the pill at 42 against a 49 sidebar —
                // *darker*, reading as a punched hole, with a bright 61 lensing rim
                // around it. The material was working correctly; it just isn't the
                // effect a selection needs. Glass dims what is behind it, and its
                // backdrop is already a translucent material, so glass-on-material
                // cannot go lighter than its own backdrop. The HIG says the same
                // thing prescriptively: "avoid applying the material to both
                // layers. Instead, use fills, transparency, and vibrancy for the
                // top elements."
                //
                // That measurement survives the move to the system's sidebar glass, and the
                // z-order it depends on survives with it: the probe found this tree hosted at
                // `NSContainerConcentricGlassEffectView` → `_NSCoreHostingView<RootView>`, i.e.
                // the SwiftUI content is a *subview* of the glass, exactly as `glassEffect`
                // rendered behind its own content. So this fill still composites on top of the
                // material and can still only add light. If it had gone the other way — glass
                // over the rows — the wash would have had to become a vibrancy treatment instead.
                shape.fill(Color.white.opacity(SidebarLift.selected(isDark: isDark)))
            } else {
                shape.fill(Surface.raised)
                    .overlay(shape.strokeBorder(Line.hairline, lineWidth: Line.width))
            }
        } else if isHovering {
            shape.fill(Color.white.opacity(SidebarLift.hover(isDark: isDark)))
        } else {
            Color.clear
        }
    }
}

/// How far a sidebar row lifts off the sidebar when hovered and when selected.
///
/// Both toward **white**, both in both appearances — that is the whole content of
/// this type, and it is here because getting it wrong shipped.
///
/// The selected branch was fixed for this once: `Color.primary.opacity(…)` inverts
/// per appearance, so in light mode it painted a near-black pill 108 units *darker*
/// than the sidebar. Hover was left on `Surface.fillHover`, which is the same
/// `Color.primary` wash — so on a light theme the pointer arriving at a row
/// darkened it and clicking then jumped it to 75% white. One control, two opposite
/// directions, which reads as a rendering fault rather than as feedback.
///
/// The invariant is `0 < hover < selected` in both appearances, and the numbers are
/// a ratio rather than two independent tunings: hover is ~47% of the selection's
/// lift, so the ordering survives whatever the backdrop turns out to be. Composited
/// over a backdrop *B*, a lift *k* lands at `B + k(1 - B)`, which is monotonic in
/// *k* for any *B* — so no wallpaper, theme or material can reorder the three
/// states. That is what makes this survive the sidebar becoming a system glass surface: the
/// backdrop changed, the ordering cannot.
///
/// Where that is tightest, stated honestly: on the Reduce Transparency path in a
/// light theme the selected fill is `Surface.raised` rather than a wash (Paper:
/// 0.988 green against a 0.937 canvas), and hover computes to 0.959 — about 76% of
/// the way there. Still ordered, and the selected row additionally carries a
/// hairline rim, medium weight and primary ink, which is what separates them there.
/// On the glass path both steps are even: against the 49/255 sidebar measured
/// above, dark-mode hover lands at 59 and selection at 70 — two ~10-unit steps.
/// Light mode works out to ~9 then ~10 units, but only for an assumed 230/255
/// backdrop; that figure is arithmetic on an estimate, not a screenshot.
///
/// **Why this is not the system's selection.** `List(selection:).listStyle(.sidebar)` would hand the
/// job to `NSTableView` and bring keyboard navigation and list semantics with it, which these
/// buttons genuinely lack. It was not taken, for three reasons and none of them is inertia. The
/// contrast property above is *measured* and pinned by `SidebarLiftTests`; the system treatment's
/// rendered contrast on macOS 26 glass, in both appearances, can only be checked by looking at a
/// screen, so the swap trades a proven invariant for an assumed one — and the assumption is exactly
/// the one that already failed here once (42 against 49, darker). `SettingsWindowView` is a second
/// caller of these numbers, so they cannot be deleted from this file anyway. And a `List` brings its
/// own row metrics, which would move `Layout.sidebarRowHeight` and the footer out of the layout
/// that was just re-measured. Worth doing as its own change, with the screen in front of someone.
///
/// `SettingsWindowView`'s group rows are the same control in a different window and
/// currently carry their own copy of these numbers (0.40 rather than 0.35 for light
/// hover). They should call this instead, so two nav columns in one app cannot
/// drift apart — flagged to that file's owner rather than changed from here.
enum SidebarLift {
    static func selected(isDark: Bool) -> Double { isDark ? 0.10 : 0.75 }
    static func hover(isDark: Bool) -> Double { isDark ? 0.05 : 0.35 }
}

// MARK: - Usage card

/// Words dictated, pinned above the utility rows.
///
/// The reference uses this slot for a weekly quota and an upgrade button. Utter
/// has no quota and nothing to sell, so the slot shows something true instead:
/// how much has actually been dictated. Inventing a fake limit to fill the shape
/// would be worse than leaving it out.
private struct UsageCard: View {
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            // One colour for the whole metric. An accent number beside a grey
            // word read as a rendering glitch rather than as emphasis; the
            // number carries the emphasis through weight and size instead.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Primary ink, not the accent.
                //
                // Accent-on-cream measured 2.42:1 here. The number is already the
                // biggest, heaviest thing in the card, so it does not need colour
                // to carry emphasis — and the accent survives in the card's rim.
                Text("\(history.totalWords)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text("words")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Ink.secondary)
            }
            Text("Dictated on this Mac. No limits, no account.")
                .typo(.caption, ink: Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    @ViewBuilder
    private var cardBackground: some View {
        // No glass behind this card, because it holds text.
        //
        // Text composited onto a Liquid Glass surface loses subpixel font
        // smoothing — the compositor has to blend glyphs into a live material, so
        // it falls back to grayscale antialiasing. Measured on screenshots, glyph
        // edges on glass were ~3x softer than the same text elsewhere, which is
        // exactly the "blurry selected options" complaint. A flat fill restores
        // crisp text and the accent rim still carries the card's identity.
        let shape = Radius.rect(Radius.field)
        shape.fill(Surface.fillSubtle)
            .overlay(shape.strokeBorder(Tint.accent.opacity(0.28),
                                        lineWidth: Line.width))
    }
}

// `FlowMainView` lived here — one view holding `HStack { sidebar; content }` — and is deleted rather
// than kept as a wrapper. It cannot exist in the new structure: the sidebar and the content are
// separate `NSSplitViewItem`s with separate hosting controllers, which is the entire mechanism by
// which the system supplies the sidebar's material and lets content run underneath it. Comments in
// `GlassSurface.swift`, `GlassControls.swift`, `ThemedRoot.swift`, `SettingsWindowView.swift`,
// `OnboardingView.swift` and `MeetingOfferPanel.swift` still cite `FlowMainView.<member>`; the
// members they name are now on `FlowSidebar` or `FlowContent` above, and those files belong to
// other owners.
//
// `OpenRim` — a three-sided rounded-rect stroke — also lived here. It drew the content card's border
// on every edge except the one abutting the sidebar, which is a shape that only makes sense when
// there is a card with a seam to avoid. There is neither.
