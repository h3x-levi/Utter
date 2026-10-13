import Combine
import SwiftUI
import UtterCore

// MARK: - Navigation

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case library = "Library"
    case words = "Words"
    case companion = "Companion"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .words: "textformat"
        case .companion: "face.smiling"
        }
    }

    var shortcut: KeyEquivalent { KeyEquivalent(Character(String(Self.allCases.firstIndex(of: self)! + 1))) }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dictations = "Dictations"
    case notes = "Notes"
    case meetings = "Meetings"

    var id: String { rawValue }
    var title: String { rawValue }

    func includes(_ kind: LibraryItem.Kind) -> Bool {
        switch self {
        case .all: true
        case .dictations: kind == .dictation
        case .notes: kind == .note
        case .meetings: kind == .meeting
        }
    }
}

/// The main window's route, including the section inside a screen.
@MainActor @Observable
final class SidebarSelection {
    static let shared = SidebarSelection()

    var item: SidebarItem = .home
    var libraryFilter: LibraryFilter = .all
    var libraryItemID: String?
    var wordsSection: WordsViewModel.Section = .dictionary

    init(arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: "--screen"), index + 1 < arguments.count else { return }
        open(screen: arguments[index + 1])
    }

    func open(screen: String) {
        switch screen.lowercased() {
        case "library", "memory", "history", "transcripts", "all": openLibrary(.all)
        case "dictations": openLibrary(.dictations)
        case "notes": openLibrary(.notes)
        case "meetings": openLibrary(.meetings)
        case "words", "dictionary": openWords(.dictionary)
        case "snippets": openWords(.snippets)
        case "commands", "transforms", "tools", "engine", "voiceengine": openWords(.commands)
        case "companion": item = .companion
        default: item = .home
        }
    }

    /// Shows one dictation or note in Library, widening the filter if it might hide it. A note id may be a meeting.
    func open(libraryItem id: String) {
        let kinds: [LibraryItem.Kind] = id.hasPrefix(LibraryItem.dictationPrefix) ? [.dictation] : [.note, .meeting]
        if !kinds.allSatisfy(libraryFilter.includes) { libraryFilter = .all }
        libraryItemID = id
        item = .library
    }

    func openNote(_ id: UUID) { open(libraryItem: LibraryItem.noteID(id)) }

    private func openLibrary(_ filter: LibraryFilter) {
        libraryFilter = filter
        item = .library
    }

    private func openWords(_ section: WordsViewModel.Section) {
        wordsSection = section
        item = .words
    }
}

// MARK: - Live capture state

/// A read-only view of the dictation turn, mirrored from the pill's published state.
@MainActor @Observable
final class CaptureStatus {
    enum Turn: Equatable { case preparing, idle, listening, thinking, landed, failed }

    private(set) var pill: PillState
    private(set) var turn: Turn
    @ObservationIgnored private var watch: AnyCancellable?

    init(source: PillStateModel? = nil) {
        let pill = source?.state ?? .idle
        self.pill = pill
        turn = Self.turn(from: .idle, to: pill, current: .idle)
        watch = source?.$state.removeDuplicates().sink { [weak self] state in
            MainActor.assumeIsolated { self?.apply(state) }
        }
    }

    func apply(_ next: PillState) {
        turn = Self.turn(from: pill, to: next, current: turn)
        pill = next
    }

    nonisolated static func turn(from old: PillState, to new: PillState, current: Turn) -> Turn {
        switch new {
        case .preparing: return .preparing
        case .recording, .handsFree, .capturingNote, .capturingMemory: return .listening
        case .processing: return .thinking
        case .error: return .failed
        case .idle, .notice, .island:
            if case .processing = old { return .landed }
            return current == .landed ? .landed : .idle
        }
    }

    nonisolated static func line(for state: PillState, micGranted: Bool, axGranted: Bool, hotkey: String) -> String {
        switch state {
        case .preparing: return "Getting ready"
        case .recording, .handsFree: return "Listening"
        case .capturingNote: return "Listening for a note"
        case .capturingMemory: return "Listening to remember"
        case .processing(let phase): return phase.rawValue
        case .error(let message), .notice(let message): return message
        case .island: return "Your words are ready to copy"
        case .idle:
            if !micGranted { return "Needs microphone access" }
            if !axGranted { return "Needs Accessibility access" }
            return "Ready. Hold \(hotkey) to talk."
        }
    }
}

// MARK: - Composition root

/// The main window's screens and the services they share, built once per window.
@MainActor
final class MainWindowModel {
    let selection: SidebarSelection
    let status: CaptureStatus
    let readiness: ReadinessMonitor
    let userData: UserData
    let home: HomeViewModel
    let library: LibraryViewModel
    let words: WordsViewModel
    let openSettings: (SettingsGroup?) -> Void
    let openSetup: () -> Void
    let toggleHandsFree: () -> Void

    init(selection: SidebarSelection? = nil,
         status: CaptureStatus? = nil,
         readiness: ReadinessMonitor? = nil,
         userData: UserData? = nil,
         history: TranscriptionHistory? = nil,
         notes: NoteStore? = nil,
         models: ModelStore? = nil,
         meeting: MeetingSession? = nil,
         startMeeting: @escaping () async -> UUID? = { nil },
         openSettings: @escaping (SettingsGroup?) -> Void = { _ in },
         openSetup: @escaping () -> Void = {},
         toggleHandsFree: @escaping () -> Void = {}) {
        let selection = selection ?? .shared
        let status = status ?? CaptureStatus()
        let readiness = readiness ?? .shared
        let userData = userData ?? .shared
        let history = history ?? .shared
        let notes = notes ?? .shared
        let models = models ?? .shared
        self.selection = selection
        self.status = status
        self.readiness = readiness
        self.userData = userData
        self.openSettings = openSettings
        self.openSetup = openSetup
        self.toggleHandsFree = toggleHandsFree
        library = LibraryViewModel(selection: selection, history: history, store: notes,
                                   meeting: meeting, startMeetingCapture: startMeeting)
        home = HomeViewModel(status: status, selection: selection, library: library, readiness: readiness,
                             userData: userData, models: models, openSettings: openSettings)
        words = WordsViewModel(userData: userData, history: history)
        words.section = selection.wordsSection
    }
}

// MARK: - Window

struct MainWindowView: View {
    let model: MainWindowModel

    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var library = model.library
        NavigationSplitView {
            FlowSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 236, max: 300)
        } detail: {
            FlowContent(model: model, searchFocused: $searchFocused)
        }
        .tint(Look.Color.tint)
        .searchable(text: $library.search, placement: .toolbar, prompt: "Search what you said")
        .modifier(SearchFocus(focused: $searchFocused))
        .onChange(of: library.search) {
            if !library.search.isEmpty, model.selection.item != .library { model.selection.item = .library }
        }
        .background { shortcuts }
    }

    // Keyboard switches never animate.
    private var shortcuts: some View {
        ForEach(SidebarItem.allCases) { item in
            Button(item.title) {
                withTransaction(\.disablesAnimations, true) { model.selection.item = item }
            }
            .keyboardShortcut(item.shortcut)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

struct FlowSidebar: View {
    let model: MainWindowModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var lens

    var body: some View {
        let current = model.selection.item
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SidebarItem.allCases) { item in
                SidebarRow(title: item.title, icon: item.icon, selected: item == current) {
                    withAnimation(Look.Motion.pane.animation(reduceMotion: reduceMotion)) { model.selection.item = item }
                }
                .background { if item == current { selectionLens } }
            }
            Spacer(minLength: 16)
            SidebarRow(title: "Set up Utter", icon: "checklist", action: model.openSetup)
            SidebarRow(title: "Settings", icon: "gearshape") { model.openSettings(nil) }
        }
        .animation(Look.Motion.lens.animation(reduceMotion: reduceMotion), value: current)
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utter sections")
    }

    @ViewBuilder
    private var selectionLens: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        let drawn = shape.fill(Look.Color.lens)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.22), Look.Color.edge],
                                                  startPoint: .top, endPoint: .center))
            }
        if reduceMotion {
            drawn.transition(.opacity)
        } else {
            drawn.matchedGeometryEffect(id: "lens", in: lens)
        }
    }
}

private struct SidebarRow: View {
    let title: String
    let icon: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon).frame(width: 18)
            }
            .font(.body)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        }
        .buttonStyle(Look.RowStyle(radius: 10, scale: Look.Press.nav, quiet: true, selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The detail column: the screen for the current route over one continuous Moonlight ground.
struct FlowContent: View {
    let model: MainWindowModel
    let searchFocused: FocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Words binds its own ⌘N, and ⌘F where it has a search field.
        let onWords = model.selection.item == .words
        screen
            .id(model.selection.item)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
            .navigationTitle(model.selection.item.title)
            .frame(minWidth: 420, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
            .background { MoonlightGround().ignoresSafeArea() }
            .modifier(ShellChrome(onHome: model.selection.item == .home))
            .modifier(ShellToolbar(newNote: newNote, newNoteShortcut: !onWords, toggleHandsFree: model.toggleHandsFree))
            .background {
                Button("Find") { searchFocused.wrappedValue = true }
                    .keyboardShortcut(onWords && model.words.section != .commands ? nil : KeyboardShortcut("f"))
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
    }

    private func newNote() {
        model.library.newNote()
        model.selection.item = .library
    }

    @ViewBuilder
    private var screen: some View {
        switch model.selection.item {
        case .home: HomeScreen(model: model.home)
        case .library: LibraryScreen(model: model.library)
        case .words: VoiceEngineView(model: model.words)
        case .companion: CompanionScreen()
        }
    }
}

/// Two pieces of toolbar glass: New Note, then Hands-free.
private struct ShellToolbar: ViewModifier {
    let newNote: () -> Void
    let newNoteShortcut: Bool
    let toggleHandsFree: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.toolbar {
                ToolbarSpacer(.flexible)
                ToolbarItem(placement: .primaryAction) { newNoteButton }
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { handsFreeButton }
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .primaryAction) { newNoteButton }
                ToolbarItem(placement: .primaryAction) { handsFreeButton }
            }
        }
    }

    private var newNoteButton: some View {
        Button(action: newNote) { Label("New Note", systemImage: "square.and.pencil").labelStyle(.titleAndIcon) }
            .keyboardShortcut(newNoteShortcut ? KeyboardShortcut("n") : nil)
            .help("New Note")
    }

    private var handsFreeButton: some View {
        Button(action: toggleHandsFree) { Label("Hands-free", systemImage: "lock.fill").labelStyle(.titleAndIcon) }
            .help("Talk without holding the key. Press again to stop.")
    }
}

/// Home carries its title in the content; every screen gets the hard scroll edge instead of a hairline.
private struct ShellChrome: ViewModifier {
    let onHome: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.toolbar(removing: onHome ? .title : nil).scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
    }
}

/// The window's one ground, v2's Moonlight gradient; it runs under the floating sidebar and the toolbar.
struct MoonlightGround: View {
    var body: some View {
        LinearGradient(colors: [Look.Color.groundTop, Look.Color.groundBottom], startPoint: .top, endPoint: .bottom)
    }
}

private struct SearchFocus: ViewModifier {
    let focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(macOS 15, *) { content.searchFocused(focused) } else { content }
    }
}

// MARK: - Shared pieces

extension EnvironmentValues {
    /// Pairs a Home row with the Library detail it opens, so the words appear to travel.
    @Entry var libraryTransition: Namespace.ID?
}

extension View {
    /// Content-layer action buttons in Moonlight: a fill and a hairline, since glass is for navigation only.
    func glassButton(prominent: Bool = false) -> some View {
        buttonStyle(Look.ActionStyle(prominent: prominent))
    }

    /// A content card: v2's fill and hairline at radius 18. Mid-window cards sit far from the window's
    /// corners, so a concentric shape would resolve to its minimum anyway.
    func panel() -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: Look.Card.radius, style: .continuous)
            shape.fill(Look.Color.fill)
                .overlay {
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.15), Look.Color.edge],
                                                      startPoint: .top, endPoint: .init(x: 0.5, y: 0.12)))
                }
        }
    }

    func sharedWords(_ id: String, in namespace: Namespace.ID?, isSource: Bool) -> some View {
        modifier(SharedWords(id: id, namespace: namespace, isSource: isSource))
    }
}

private struct SharedWords: ViewModifier {
    let id: String
    let namespace: Namespace.ID?
    let isSource: Bool

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace, properties: .frame, isSource: isSource)
        } else {
            content
        }
    }
}

/// The small mark over an empty list, with one next step.
struct EmptyMark<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                LivingMark(tint: .secondary).frame(height: 40)
            }
        } description: {
            Text(message)
        } actions: {
            actions
        }
    }
}
