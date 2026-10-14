import AVFoundation
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import UtterCore

// MARK: - Navigation

enum SidebarItem: String, Hashable {
    case library = "Library"
    case words = "Words"
    /// Companion lives in Settings; `MainWindowModel.followRoute` hands this route to its tab.
    case companion = "Companion"

    var title: String { rawValue }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "Everything"
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

    var item: SidebarItem = .library
    var libraryFilter: LibraryFilter = .all
    var libraryItemID: String?
    var wordsSection: WordsViewModel.Section = .dictionary

    init(arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: "--screen"), index + 1 < arguments.count else { return }
        open(screen: arguments[index + 1])
    }

    func open(screen: String) {
        switch screen.lowercased() {
        case "dictations": openLibrary(.dictations)
        case "notes": openLibrary(.notes)
        case "meetings": openLibrary(.meetings)
        case "words", "dictionary": openWords(.dictionary)
        case "snippets": openWords(.snippets)
        case "commands", "transforms", "tools", "engine", "voiceengine": openWords(.commands)
        case "companion": item = .companion
        default: openLibrary(.all)
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

    func openLibrary(_ filter: LibraryFilter) {
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

// MARK: - Setup

/// What Utter still needs before dictation works, shown as a note at the top of Library.
@MainActor @Observable
final class SetupNeeds {
    enum Need: Equatable, Identifiable {
        case microphone
        case accessibility
        case model(downloading: Double?)
        case modelFailed(String)

        var id: String {
            switch self {
            case .microphone: "microphone"
            case .accessibility: "accessibility"
            case .model: "model"
            case .modelFailed: "modelFailed"
            }
        }

        var sentence: String {
            switch self {
            case .microphone: "Allow the microphone so Utter can hear you."
            case .accessibility: "Allow Accessibility so Utter can type into other apps."
            case .model(nil): "Download the speech model so Utter can turn speech into text."
            case .model: "Downloading the speech model."
            case .modelFailed(let reason): "The speech model didn't load. \(reason)"
            }
        }

        var actionTitle: String {
            switch self {
            case .microphone, .accessibility: "Allow"
            case .model: "Download"
            case .modelFailed: "Speech Settings"
            }
        }
    }

    struct Readiness: Equatable {
        var mic = false
        var ax = false
        var modelPresent = true
        var modelLoad: LocalWhisperProvider.LoadState = .idle
    }

    var readiness = Readiness()
    private(set) var modelState: ModelStore.State?
    /// A better model this Mac runs well, offered once until the user says Not now.
    private(set) var upgrade: SpeechModel?
    private(set) var upgradeState: ModelStore.State?
    let device: Device

    @ObservationIgnored private let models: ModelStore
    @ObservationIgnored private let openSettings: (SettingsGroup?) -> Void
    @ObservationIgnored private var watches: Set<AnyCancellable> = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let declinedKey = "declinedModelUpgrade"

    init(readiness: ReadinessMonitor, models: ModelStore, device: Device = .current(), defaults: UserDefaults = .standard,
         openSettings: @escaping (SettingsGroup?) -> Void) {
        self.models = models
        self.device = device
        self.defaults = defaults
        self.openSettings = openSettings
        Publishers.CombineLatest4(readiness.$micGranted, readiness.$axGranted, readiness.$modelPresent, readiness.$modelLoad)
            .sink { [weak self] mic, ax, present, load in
                MainActor.assumeIsolated { self?.readiness = Readiness(mic: mic, ax: ax, modelPresent: present, modelLoad: load) }
            }.store(in: &watches)
        models.$states.combineLatest(models.$active).sink { [weak self] states, active in
            MainActor.assumeIsolated {
                self?.modelState = states[active]
                self?.refreshUpgrade(states)
            }
        }.store(in: &watches)
    }

    private func refreshUpgrade(_ states: [SpeechModel.Tier: ModelStore.State]? = nil) {
        let offer = models.suggestedUpgrade(for: device)
        upgrade = offer?.tier.rawValue == defaults.string(forKey: Self.declinedKey) ? nil : offer
        upgradeState = upgrade.flatMap { (states ?? models.states)[$0.tier] }
    }

    /// Downloads the offered model; Utter switches to it once it's verified on disk.
    func downloadUpgrade() {
        if let upgrade { models.select(upgrade.tier) }
    }

    func declineUpgrade() {
        defaults.set(upgrade?.tier.rawValue, forKey: Self.declinedKey)
        refreshUpgrade()
    }

    var needs: [Need] { Self.needs(readiness, modelState: modelState) }

    static func needs(_ readiness: Readiness, modelState: ModelStore.State?) -> [Need] {
        var needs: [Need] = []
        if !readiness.mic { needs.append(.microphone) }
        if !readiness.ax { needs.append(.accessibility) }
        if !readiness.modelPresent {
            if case .downloading(let fraction) = modelState {
                needs.append(.model(downloading: fraction))
            } else {
                needs.append(.model(downloading: nil))
            }
        } else if case .failed(let reason) = readiness.modelLoad {
            needs.append(.modelFailed(reason))
        }
        return needs
    }

    /// "One thing left", shared by the Library card and the hub's stripe.
    static func cardTitle(_ count: Int) -> String {
        let number = ["One", "Two", "Three"][min(max(count, 1), 3) - 1]
        return "\(number) thing\(count == 1 ? "" : "s") left"
    }

    func grant(_ need: Need) {
        switch need {
        case .microphone:
            AccessibilityPermission.requestMicrophone()
        case .accessibility:
            AccessibilityPermission.openSettingsPane()
        case .model:
            if SpeechModel.isBundled(models.active) {
                openSettings(.speech)
            } else {
                models.download(models.active)
            }
        case .modelFailed:
            openSettings(.speech)
        }
    }
}

// MARK: - Composition root

/// The main window's screens and the services they share, built once per window.
@MainActor
final class MainWindowModel {
    let selection: SidebarSelection
    let status: CaptureStatus
    let setup: SetupNeeds
    let userData: UserData
    let library: LibraryViewModel
    let words: WordsViewModel
    let openSettings: (SettingsGroup?) -> Void
    let toggleHandsFree: () -> Void

    init(selection: SidebarSelection? = nil,
         status: CaptureStatus? = nil,
         readiness: ReadinessMonitor? = nil,
         userData: UserData? = nil,
         history: TranscriptionHistory? = nil,
         notes: NoteStore? = nil,
         models: ModelStore? = nil,
         meeting: MeetingSession? = nil,
         startMeeting: @escaping () async -> MeetingSession.StartOutcome = { .refused("") },
         openSettings: @escaping (SettingsGroup?) -> Void = { _ in },
         toggleHandsFree: @escaping () -> Void = {}) {
        let selection = selection ?? .shared
        let userData = userData ?? .shared
        let history = history ?? .shared
        self.selection = selection
        self.status = status ?? CaptureStatus()
        self.userData = userData
        self.openSettings = openSettings
        self.toggleHandsFree = toggleHandsFree
        setup = SetupNeeds(readiness: readiness ?? .shared, models: models ?? .shared, openSettings: openSettings)
        library = LibraryViewModel(selection: selection, history: history, store: notes ?? .shared,
                                   meeting: meeting, startMeetingCapture: startMeeting)
        words = WordsViewModel(userData: userData, history: history)
        words.section = selection.wordsSection
    }

    /// Companion lives in Settings: its route opens that tab and leaves the window on Library.
    func followRoute() {
        guard selection.item == .companion else { return }
        selection.item = .library
        openSettings(.companion)
    }
}

// MARK: - Window

/// One J-card: the spine, the main column, and on Library the fold.
struct MainWindowView: View {
    let model: MainWindowModel

    var body: some View {
        HStack(spacing: 0) {
            FlowSidebar(model: model)
            FlowContent(model: model)
        }
        .foregroundStyle(Mixtape.ink)
        .tint(Mixtape.pen)
        .background(Mixtape.paper)
        .ignoresSafeArea()
        .background(WindowChrome())
        .navigationTitle(model.selection.item.title)
        .onChange(of: model.selection.item, initial: true) { model.followRoute() }
    }
}

/// The spine: Library's filters, Words, and Settings at the foot, with the brand stripe down its edge.
struct FlowSidebar: View {
    let model: MainWindowModel

    var body: some View {
        let selection = model.selection
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(LibraryFilter.allCases.enumerated()), id: \.element) { index, filter in
                SpineRow(title: filter.title, count: model.library.count(filter),
                         current: selection.item != .words && selection.libraryFilter == filter) {
                    selection.openLibrary(filter)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
            Text("Vocabulary")
                .mixtapeCaps(10, tracking: 0.2)
                .foregroundStyle(Mixtape.ink3)
                .padding(EdgeInsets(top: 14, leading: 10, bottom: 4, trailing: 10))
                .accessibilityAddTraits(.isHeader)
            SpineRow(title: "Words", count: model.words.words.count, current: selection.item == .words) {
                selection.item = .words
            }
            .keyboardShortcut("5")
            Spacer(minLength: 16)
            SpineRow(title: "Settings") { model.openSettings(nil) }
        }
        .padding(EdgeInsets(top: 56, leading: 10, bottom: 10, trailing: 16))
        .frame(width: 214)
        .frame(maxHeight: .infinity)
        .background(Mixtape.spine)
        .overlay(alignment: .bottomLeading) { label }
        .overlay(alignment: .trailing) {
            VStack(spacing: 0) {
                Mixtape.red
                Mixtape.gold
                Mixtape.navy
            }
            .frame(width: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utter sections")
    }

    /// The spine's printed label, read bottom to top.
    private var label: some View {
        Text("Utter · \(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
            .mixtapeCaps(10.5, tracking: 0.34)
            .foregroundStyle(Mixtape.ink3)
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(-90), anchor: .topLeading)
            .offset(x: 22, y: -70)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SpineRow: View {
    let title: String
    var count: Int?
    var current = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .fontWeight(current ? .semibold : .regular)
                    .padding(.horizontal, 1)
                    .background {
                        if current {
                            LinearGradient(stops: [.init(color: .clear, location: 0.6), .init(color: Mixtape.mark, location: 0.6)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    }
                Spacer(minLength: 0)
                if let count {
                    Text(count, format: .number).font(Mixtape.mono(11)).foregroundStyle(Mixtape.ink3)
                }
            }
            .font(Mixtape.body(13.5))
            .foregroundStyle(current || hovering ? Mixtape.ink : Mixtape.ink2)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(current ? .isSelected : [])
    }
}

/// The main column under its toolbar row; Library adds the fold on the right.
struct FlowContent: View {
    let model: MainWindowModel

    @FocusState private var searchFocused: Bool

    var body: some View {
        let onWords = model.selection.item == .words
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ShellToolbar(model: model, searchFocused: $searchFocused)
                    .padding(EdgeInsets(top: 16, leading: 34, bottom: 0, trailing: 30))
                Group {
                    if onWords { WordsScreen(model: model.words) } else { LibraryScreen(window: model) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(minWidth: 400, maxWidth: .infinity)
            if !onWords { LibraryFold(window: model).frame(width: 360) }
        }
        .onChange(of: model.library.search) {
            if !model.library.search.isEmpty, model.selection.item != .library { model.selection.item = .library }
        }
    }
}

/// New note, Hands-free, Library's actions and the search line, as ghost pens on the page.
private struct ShellToolbar: View {
    let model: MainWindowModel
    let searchFocused: FocusState<Bool>.Binding

    var body: some View {
        @Bindable var library = model.library
        // Words binds its own ⌘N, and ⌘F where it has a search field.
        let onWords = model.selection.item == .words
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Button("New note") {
                model.library.newNote()
                model.selection.item = .library
            }
            .keyboardShortcut(onWords ? nil : KeyboardShortcut("n"))
            Button("Hands-free", action: model.toggleHandsFree)
                .help("Talk without holding the key. Press again to stop.")
            if !onWords { LibraryActions(model: model.library) }
            LineField("Search what you said", text: $library.search)
                .focused(searchFocused)
                .frame(minWidth: 120, idealWidth: 210, maxWidth: 210)
                .padding(.leading, 8)
        }
        .buttonStyle(.pen(.ghost, .small))
        .frame(height: 30)
        .background {
            Button("Find") { searchFocused.wrappedValue = true }
                .keyboardShortcut(onWords && model.words.section != .commands ? nil : KeyboardShortcut("f"))
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// Recording a meeting and exporting what's shown.
private struct LibraryActions: View {
    let model: LibraryViewModel

    var body: some View {
        Menu {
            Button("Record a Meeting", action: model.startMeeting).disabled(!model.canStartMeeting)
            Menu("Export What\u{2019}s Shown") {
                ForEach(LibraryViewModel.ExportFormat.allCases) { format in
                    Button(format.rawValue) { export(format) }
                }
            }
            .disabled(model.visibleItems.isEmpty)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.inkIcon)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Library actions")
        .help("Record a meeting or export")
    }

    private func export(_ format: LibraryViewModel.ExportFormat) {
        let text = model.exportText(format)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Utter \(model.filter.title).\(format.fileExtension)"
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.save(text, to: url)
        }
    }
}

/// Hides the window title and clears the title bar, so the J-card runs to the top and the traffic lights sit on the spine.
private struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.titleVisibility = .hidden
            window?.titlebarAppearsTransparent = true
        }
    }
}
