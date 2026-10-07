import SwiftUI

// MARK: - Navigation

/// A sidebar destination.
///
/// Split into two groups, following the reference layout: feature pages at the
/// top, utility items pinned to the bottom of the column. Settings is deliberately
/// *not* a page any more - it opens its own window.
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case studio = "Studio"
    case memory = "Memory"
    case voiceEngine = "Voice Engine"

    var id: String { rawValue }

    /// The three first-principles workspace destinations.
    static let primary: [SidebarItem] = [.studio, .memory, .voiceEngine]

    // Compatibility aliases for existing app entry points and UI automation.
    static var capture: SidebarItem { .studio }
    static var library: SidebarItem { .memory }
    static var tools: SidebarItem { .voiceEngine }
    static var companion: SidebarItem { .studio }
    static var dictation: SidebarItem { .studio }
    static var notes: SidebarItem { .memory }
    static var dictionary: SidebarItem { .voiceEngine }
    static var snippets: SidebarItem { .voiceEngine }
    static var commands: SidebarItem { .voiceEngine }

    /// Authentic Apple-designed SF Symbols.
    var icon: String {
        switch self {
        case .studio: return "waveform"
        case .memory: return "clock.arrow.circlepath"
        case .voiceEngine: return "sparkles"
        }
    }

    /// Native Apple app colorful squircle badge tint
    var badgeColor: Color {
        switch self {
        case .studio: return .blue
        case .memory: return .orange
        case .voiceEngine: return .purple
        }
    }

    @MainActor
    var subtitle: String {
        switch self {
        case .studio:
            let count = TranscriptionHistory.shared.totalWords
            return count == 1 ? "1 word dictated" : "\(count) words dictated"
        case .memory:
            let count = TranscriptionHistory.shared.entries.count + NoteStore.shared.notes.count
            return count == 1 ? "1 saved item" : "\(count) saved items"
        case .voiceEngine:
            let data = UserData.shared
            return "\(data.dictionaryWords.count) terms · \(data.snippets.count) snippets · \(data.customAICommands.count) styles"
        }
    }

    /// Whether this screen scrolls its own content, so `FlowContent` must not wrap it
    /// in an outer `ScrollView`.
    var ownsScrolling: Bool {
        switch self {
        case .memory: return true
        default: return false
        }
    }
}

/// Which sidebar destination the main window is showing.
@MainActor
final class SidebarSelection: ObservableObject {
    static let shared = SidebarSelection()

    @Published var item: SidebarItem

    private init() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else {
            self.item = .studio
            return
        }
        switch args[i + 1].lowercased() {
        case "dictation", "capture", "studio":
            self.item = .studio
        case "notes":
            WorkspaceSectionSelection.shared.memory = .notes
            self.item = .memory
        case "history", "transcripts", "library", "memory":
            WorkspaceSectionSelection.shared.memory = .all
            self.item = .memory
        case "dictionary":
            WorkspaceSectionSelection.shared.voiceEngine = .vocabulary
            self.item = .voiceEngine
        case "snippets":
            WorkspaceSectionSelection.shared.voiceEngine = .snippets
            self.item = .voiceEngine
        case "transforms", "commands", "tools", "engine", "voiceengine":
            WorkspaceSectionSelection.shared.voiceEngine = .styles
            self.item = .voiceEngine
        case "companion":
            self.item = .studio
        default:
            self.item = .studio
        }
    }
}

enum MemorySection: String, CaseIterable, Identifiable {
    case all = "All"
    case dictations = "Dictations"
    case notes = "Notes"
    case meetings = "Meetings"
    var id: String { rawValue }
}

enum VoiceEngineSection: String, CaseIterable, Identifiable {
    case vocabulary = "Vocabulary"
    case snippets = "Snippets"
    case styles = "Styles"
    var id: String { rawValue }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case transcripts = "Transcripts"
    case notes = "Notes"
    var id: String { rawValue }
}

enum ToolsSection: String, CaseIterable, Identifiable {
    case dictionary = "Dictionary"
    case snippets = "Snippets"
    case transforms = "Transforms"
    var id: String { rawValue }
}

@MainActor
final class WorkspaceSectionSelection: ObservableObject {
    static let shared = WorkspaceSectionSelection()
    @Published var memory: MemorySection = .all
    @Published var voiceEngine: VoiceEngineSection = .vocabulary

    // Compatibility shims
    var library: LibrarySection {
        get { memory == .notes ? .notes : .transcripts }
        set { memory = (newValue == .notes ? .notes : .all) }
    }
    var tools: ToolsSection {
        get {
            switch voiceEngine {
            case .vocabulary: return .dictionary
            case .snippets: return .snippets
            case .styles: return .transforms
            }
        }
        set {
            switch newValue {
            case .dictionary: voiceEngine = .vocabulary
            case .snippets: voiceEngine = .snippets
            case .transforms: voiceEngine = .styles
            }
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
// treatment and automatic accessibility adaptation to structures - a titlebar, an `NSToolbar`, an
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
//     `NSContainerConcentricGlassEffectView` on macOS 26 - real Liquid Glass, inset 8pt and
//     *concentric* with the window's corner radius, which a `glassEffect(.regular, in: Rectangle())`
//     cannot be. Below macOS 26 the same item supplies the translucent `.sidebar` material its
//     header documents. Whether it also substitutes for itself under Reduce Transparency - the
//     adaptation the HIG promises for standard components and withholds from custom ones - is
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
//     wordmark ...................... x 16, y 74         (x 20 when it padded by `x3`)
//     first line of content ......... x 200, y 90        (was x 192, y 54)
//     content plane (background) .... x 0-1180, y 0-820  - full window, under both glass surfaces
//
// The content moves down 36pt and right 8pt, and that is the honest price of a real band: the first
// line of text sits 24pt below the chrome in both layouts (54 - 30 = 24, 90 - 66 = 24). The gap did
// not change; the band did, because it stopped being padding.
//
// And one more the system took over after that measurement pass:
//
//   * Row hover, selection, keyboard traversal, the focus ring and list semantics for VoiceOver.
//     `navRows` is a real `List(selection:).listStyle(.sidebar)` now - an `NSTableView` - so all of
//     that arrives from AppKit in both appearances. It replaced a `Button`-per-row (`SidebarRow`)
//     whose fills were hand-drawn white washes (`SidebarLift`: selected 0.75, hover 0.35 in light
//     mode). Those numbers were the reported bug rather than a near miss: a white lift over a light
//     backdrop has almost nowhere left to go, so hover on a light theme was close to invisible while
//     the same wash over the dark sidebar's measured 49/255 was a clear ~10-unit step. The lift was
//     provably *ordered* - that is what its test pinned - and still not visible, which is the gap
//     between an invariant that can be computed and one that has to be seen. AppKit's row treatment
//     is per-appearance by construction, so the question stops being ours.
//
// One thing AppKit does *not* supply and this file still does:
//
//   * The content layer itself (`FlowContent.windowSurface`). That is a standard material, which is
//     what the HIG asks for in the content layer, and it is deliberately not glass.

// MARK: - Sidebar pane

/// The sidebar's contents. Draws no surface of its own on macOS 26 - the surface is the
/// `NSSplitViewItem` sidebar's own Liquid Glass, supplied by AppKit.
///
/// AppKit owns the width, collapse behavior, divider, selection, and keyboard navigation.
struct FlowSidebar: View {
    @ObservedObject private var selection = SidebarSelection.shared

    /// Observed rather than read, and this is load-bearing: the design tokens are computed
    /// properties, so a theme change only reaches the surfaces below if *this* body is invalidated.
    /// `preferredColorScheme` alone restyles SwiftUI's own controls and does not re-read a token.
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        surface
            .preferredColorScheme(themeManager.current.colorScheme)
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
    /// Reduce Transparency, which makes both of these arguably redundant - but "arguably" is not
    /// "verified", the adaptation cannot be checked without the accessibility switch and a screen,
    /// and an opaque fill drawn over an opaque substitute is byte-identical to what shipped. So they
    /// stay: the cost is a material drawn twice on old systems, and the alternative risks an
    /// accessibility regression that no test in this suite would catch.
    ///
    /// `GlassSupport.active` is the whole condition now. It used to be paired with a lexical
    /// `#available(macOS 26.0, *)` because `glassEffect` does not exist below 26 and a runtime `Bool`
    /// cannot satisfy the compiler; with the call gone, so is the reason for the pairing.
    ///
    /// This stays the column's *only* backdrop even though `navRows` is a `List` now: the list is
    /// given `.scrollContentBackground(.hidden)`, so `.sidebar`'s own material cannot composite a
    /// second copy over AppKit's glass - or over the fill drawn on the two branches below.
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

    /// The `Spacer(minLength: Space.x4)` that used to pin the footer down is gone, and its removal
    /// is a correctness fix rather than tidying. `navRows` is a `List` now, which is *greedy* in the
    /// vertical axis; a `Spacer` is equally flexible. Two fully flexible siblings in one `VStack`
    /// have no defined split between them, so the footer's position would have depended on how the
    /// stack chose to divide the slack - and a 50/50 division parks it in the middle of the column.
    /// The list takes the space it wants, the footer sits under it, and the 16pt gap the spacer's
    /// `minLength` was really there for is now `bottomBlock`'s own top padding.
    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
            navRows
            bottomBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// A small product anchor gives the work navigation a clear start, while the
    /// split-view item continues to own its material, focus and row selection.
    private var brandHeader: some View {
        HStack(spacing: Space.x2) {
            Image(systemName: "waveform")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Utter")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                Text("Private voice workspace")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Ink.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.x3)
        .padding(.top, Space.x2)
        .padding(.bottom, Space.x1)
    }

    /// The navigation rows: a system sidebar list.
    ///
    /// This was a `VStack` of six `Button`s drawing their own selected and hover fills. It is an
    /// `NSTableView` now, and everything the buttons could not do arrives with it: a per-appearance
    /// selection pill and pointer highlight, up/down-arrow traversal, the keyboard focus ring, and
    /// `AXOutline`/`AXRow` semantics instead of six unrelated `AXButton`s. The rows carry no ink or
    /// weight overrides any more either - the style inverts the label and its glyph on the selected
    /// row itself, which is why `Label` is handed the plain title and symbol.
    ///
    /// The selection binding is not `$selection.item` directly, and that is deliberate: routing the
    /// write through `select(_:)` keeps the `Motion.listChange` transaction that `FlowContent`'s
    /// `.transition(.opacity).id(selected)` animates from. Bound straight to the published property
    /// the pane swap would become an instant cut.
    ///
    /// The overload taken is `List(selection: Binding<SidebarItem>)` - non-optional, macOS 13.0+ and
    /// macOS-only. Worth naming because it is the one that makes the state machine honest: there is
    /// no `nil`, so a click on empty space or a ⌘-click cannot leave the sidebar with nothing
    /// selected while `FlowContent` still shows a screen. The `Binding<SelectionValue?>` overload
    /// would have needed a hand-written setter that refuses `nil`, i.e. the same guarantee written
    /// out and then trusted.
    ///
    /// No `GlassCluster` either. A `GlassEffectContainer` groups sibling `glassEffect`s into one
    /// render pass and there is not one left in this sidebar: the rows are the system's and the
    /// glass is the system's, outside this tree entirely. Nesting a container inside the sidebar's
    /// own glass would be the glass-on-glass the HIG warns against.
    private var navRows: some View {
        List(selection: route) {
            ForEach(SidebarItem.primary) { item in row(item) }
        }
        .listStyle(.sidebar)
        // The sidebar's material is AppKit's (or `surface`'s, pre-26). A list draws its own on top
        // of it by default, which is the glass-on-material the HIG rules out and, on the pre-26
        // path, a second copy of a material this file already placed.
        .scrollContentBackground(.hidden)
        .accessibilityLabel("Utter workspace navigation")
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            Text(item.rawValue)
                .font(.system(size: 13, weight: selection.item == item ? .semibold : .regular))
        } icon: {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(selection.item == item ? Color.accentColor : Ink.secondary)
                .frame(width: 20, alignment: .center)
        }
        .frame(minHeight: Layout.mainSidebarRowHeight)
        .tag(item)
    }

    /// Selection as the list wants it, with `select(_:)`'s animation kept - see `navRows`.
    private var route: Binding<SidebarItem> {
        Binding(get: { selection.item }, set: { select($0) })
    }

    /// Usage summary pinned to the base of the column.
    ///
    /// macOS 26 has a system component for exactly this - `bottomAlignedAccessoryViewControllers`
    /// on the split item, which insets and pins its own accessory. Not used: it is 26-only, so it
    /// would need this layout kept alongside it as the pre-26 path, and two layouts for one footer
    /// is worse than one that already works on both. It is `navRows`' greed that pins this to the
    /// base now, not a `Spacer` - see `column`.
    private var bottomBlock: some View {
        VStack(spacing: Space.x2) {
            UsageCard()
            Button {
                AppDelegate.current?.showSettingsWindow()
            } label: {
                Label("Settings…", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, Space.x2)
            Button(action: {
                AppDelegate.current?.openReportIssue()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.system(size: 11))
                    Text("Report Issue / Feedback")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9))
                }
                .foregroundStyle(Ink.secondary)
                .padding(.horizontal, Space.x2)
                .padding(.vertical, Space.x1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Report an Issue or Send Feedback")
        }
        .padding(.horizontal, Space.x2)
        .padding(.bottom, Space.x1)
        .padding(.top, Space.x4)
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
/// Full-bleed, and now genuinely so. The view this sits in is the *whole window* - AppKit gives the
/// content split item a 1180x820 frame with a 176pt leading safe-area inset rather than a 1004pt
/// frame beside the sidebar - so `windowSurface` extends under the sidebar's glass and under the
/// titlebar band, and both have app content to refract instead of only the desktop. Measured: the
/// background lands at x 0-1180, y 0-820; the first line of text at x=200 (176 + `Space.x6`).
///
/// Two modifiers are deleted rather than adjusted, because the system supplies what each faked:
///
///   * `.ignoresSafeArea(.container, edges: .top)` - it existed to cancel the titlebar inset that
///     stacked with the hand-drawn band, and to let the sidebar's glass run full height. The band is
///     the inset now, and the sidebar's full-height layout is AppKit's (`allowsFullHeightLayout`,
///     default true on a `.fullSizeContentView` window - measured: glass 8pt to 812pt in an 820pt
///     window, i.e. up behind the window controls).
///   * `.padding(.top, Layout.toolbarBand)` - 30pt of padding standing in for a titlebar. The real
///     band is 66pt and arrives as a safe-area inset, which SwiftUI converts into the scroll view's
///     `contentInsets` rather than into a smaller scroll view: measured `contentInsets.top = 66` on a
///     full-window `HostingScrollView`, `documentVisibleRect.y = -66`. So content scrolls *under*
///     the band and the system's scroll-edge pocket softens the cut - which is precisely the
///     vertical bleed the old comment here said would read correctly and could not be had. It needed
///     no `contentMargins` (macOS 14+, so it would have needed a second path anyway).
struct FlowContent: View {
    @ObservedObject private var selection = SidebarSelection.shared
    private var selected: SidebarItem { selection.item }

    /// Observed for the same reason as in `FlowSidebar`: the tokens are computed properties and a
    /// theme change has to invalidate this body to be seen.
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    /// History and notes feed `SidebarItem.subtitle`, which is rendered here.
    ///
    /// `noteStore` was missing, and the count in the heading is a plain
    /// `NoteStore.shared.notes.count` read (`SidebarItem.subtitle`, `.notes` branch)  - 
    /// a read with no subscription. So creating or dictating a note while sitting on
    /// Notes invalidated nothing here and the heading kept whatever it was built with:
    /// "0 notes" over a screen with a note on it, correcting itself only when some
    /// unrelated publisher happened to rebuild this body. No launch cost - `subtitle`
    /// already touches `NoteStore.shared` the first time the window builds.
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var noteStore = NoteStore.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            if selected.ownsScrolling {
                // A screen that scrolls itself gets the window's full height and no
                // outer scroller - see `SidebarItem.ownsScrolling` for what nesting one
                // inside the other did to Notes.
                column.frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    column
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .id(selected)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.ignoresSafeArea()` on the surface, not on the scroll view: the plane has to reach the
        // window's edges so the sidebar glass and the titlebar pocket have something to sample,
        // while the scroll *content* stays inside the safe area. Applied at the call site rather
        // than inside `windowSurface` so the Reduce Transparency branch is covered without that
        // branch being edited.
        .background(windowSurface.ignoresSafeArea())
        .preferredColorScheme(themeManager.current.colorScheme)
    }

    /// The heading and the screen under it, with the window's margins. Shared by both
    /// branches above so the two containers cannot drift apart.
    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Space.x1) {
                    Text(selected.rawValue)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    if selected != .studio {
                        Text(selected.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.secondary)
                    }
                }
                Spacer()
                Label("On-device", systemImage: "lock.shield")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.bottom, Space.x5)

            detailView
                .transition(.opacity)
                .id(selected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.pageInset)
        .padding(.top, Space.x5)
        .padding(.bottom, Space.pageInset)
    }

    // MARK: Window surface

    private var windowSurface: some View {
        ZStack {
            WindowBacking(material: .contentBackground)
            Surface.canvas.opacity(Veil.contentSurface(isDark: isDark))
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selected {
        case .studio: StudioWorkspaceView()
        case .memory: MemoryTimelineView()
        case .voiceEngine: VoiceEngineView()
        }
    }
}

// `SidebarRow` and `SidebarLift` lived here and are deleted, not adjusted.
//
// `SidebarRow` was a `Button` per row with `@State isHovering`, an `.onHover` animation, a
// `Radius.control` fill and an `.accessibilityAddTraits(.isSelected)` - about ninety lines
// reimplementing one `NSTableView` row, and reimplementing it worse: no keyboard traversal, no
// focus ring, and six sibling `AXButton`s where a list reports rows.
//
// `SidebarLift` held the two numbers it filled with, white in both appearances, selected 0.75 /
// hover 0.35 in light mode and 0.10 / 0.05 in dark. They were not arbitrary and they were not
// unordered: `0 < hover < selected` held for every backdrop, because a lift *k* over a backdrop *B*
// composites to `B + k(1 - B)`, monotonic in *k*. The old `SidebarLiftTests` pinned exactly that,
// and it passed, and hover on a light theme was still invisible - because ordering is not contrast.
// Over the dark sidebar's measured 49/255 the two steps were ~10 units each; over a light theme's
// ~230/255 there is barely 25 units of headroom left to divide, and 0.35 of it lands under the
// threshold the report described as "no indication the mouse is hovering, nothing in light themes".
//
// AppKit's selection and hover are per-appearance by construction - a light-mode row darkens, a
// dark-mode row lightens - which is the correction, and it is not a number this app can hold. The
// hard-won part of the old note survives as fact: a `glassEffect` on the row measured 42 against
// the 49 sidebar, i.e. *darker*, a punched hole with a bright 61 lensing rim, because glass over a
// material cannot go lighter than its own backdrop. That is why the replacement is a system list
// and not a glass pill.
//
// `SettingsWindowView.SettingsGroupRow` was the enum's second caller, and the old note gave that as
// one of three reasons not to make this change: the numbers could not be deleted from this file
// while another window still used them. That reason expired - Settings' column is a
// `List(selection:)` now too, so at the time of writing the enum had no live call site left in
// either window and this deletion breaks nothing. Verified by grep across `Sources` and `Tests`, not
// by a build; five packages' worth of concurrent edits are in flight and the integration build is
// someone else's.

// MARK: - Usage card

/// Words dictated, pinned above the utility rows.
///
/// The reference uses this slot for a weekly quota and an upgrade button. Utter
/// has no quota and nothing to sell, so the slot shows something true instead:
/// how much has actually been dictated. Inventing a fake limit to fill the shape
/// would be worse than leaving it out.
private struct UsageCard: View {
    @ObservedObject private var history = TranscriptionHistory.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(history.totalWords)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text("words")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
            }
            Text("Dictated on this Mac. No limits, no account.")
                .typo(.caption, ink: Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Space.x2)
        .padding(.top, Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// `FlowMainView` lived here - one view holding `HStack { sidebar; content }` - and is deleted rather
// than kept as a wrapper. It cannot exist in the new structure: the sidebar and the content are
// separate `NSSplitViewItem`s with separate hosting controllers, which is the entire mechanism by
// which the system supplies the sidebar's material and lets content run underneath it. Comments in
// `GlassSurface.swift`, `GlassControls.swift`, `ThemedRoot.swift`, `SettingsWindowView.swift`,
// `OnboardingView.swift` and `MeetingOfferPanel.swift` still cite `FlowMainView.<member>`; the
// members they name are now on `FlowSidebar` or `FlowContent` above, and those files belong to
// other owners.
//
// `OpenRim` - a three-sided rounded-rect stroke - also lived here. It drew the content card's border
// on every edge except the one abutting the sidebar, which is a shape that only makes sense when
// there is a card with a seam to avoid. There is neither.
