import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UtterCore

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable {
    case general, speech, shortcuts, companion, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .speech: "Speech"
        case .shortcuts: "Shortcuts"
        case .companion: "Companion"
        case .privacy: "Privacy"
        }
    }
}

// MARK: - Model

@MainActor @Observable
final class SettingsModel {
    static let shared = SettingsModel()

    var group: SettingsGroup = .general

    let userData: UserData
    let readiness: ReadinessMonitor
    let models: ModelStore
    let theme: ThemeManager
    let device: Device
    let appVersion: String

    private(set) var launchAtLogin: Bool
    var confirmingReset = false
    private(set) var resetDone = false
    private(set) var crashLogs: [CrashLogSummary] = []
    private(set) var lastRunCrashed = false
    private(set) var revealProblem: String?
    private(set) var micLevel: Float = 0

    @ObservationIgnored private let history: TranscriptionHistory
    @ObservationIgnored private let notes: NoteStore
    @ObservationIgnored private let dataFolders: [URL]
    @ObservationIgnored private let crashReports: () -> (logs: [CrashLogSummary], lastRunCrashed: Bool)
    @ObservationIgnored private let injectedMeeting: MeetingSession?
    @ObservationIgnored private let levels: AnyPublisher<Float, Never>?
    @ObservationIgnored private let openIssue: (String?, IssueCategory) -> Void
    @ObservationIgnored private let openSetup: () -> Void
    @ObservationIgnored private var levelWatch: AnyCancellable?
    @ObservationIgnored lazy var companion = CompanionSettingsModel(userData: userData, history: history)

    init(userData: UserData = .shared,
         readiness: ReadinessMonitor? = nil,
         models: ModelStore? = nil,
         theme: ThemeManager = .shared,
         meeting: MeetingSession? = nil,
         history: TranscriptionHistory = .shared,
         notes: NoteStore? = nil,
         dataFolders: [URL] = [AppDirectory.support] + AppDirectory.legacySupportDirectories,
         crashReports: (() -> (logs: [CrashLogSummary], lastRunCrashed: Bool))? = nil,
         levels: AnyPublisher<Float, Never>? = nil,
         openIssue: ((String?, IssueCategory) -> Void)? = nil,
         openSetup: (() -> Void)? = nil,
         device: Device = .current(),
         appVersion: String = ConfigManager.shared.appVersion,
         launchAtLogin: Bool = SMAppService.mainApp.status == .enabled) {
        self.userData = userData
        self.readiness = readiness ?? .shared
        self.models = models ?? .shared
        self.theme = theme
        injectedMeeting = meeting
        self.history = history
        self.notes = notes ?? .shared
        self.dataFolders = dataFolders
        self.crashReports = crashReports ?? Self.savedCrashReports
        self.levels = levels
        self.openIssue = openIssue ?? { AppDelegate.current?.openReportIssue(crashLog: $0, category: $1) }
        self.openSetup = openSetup ?? { AppDelegate.current?.showOnboarding() }
        self.device = device
        self.appVersion = appVersion
        self.launchAtLogin = launchAtLogin
    }

    // Resolved on use: the SwiftUI Settings scene can build this model before the app delegate exists.
    var meeting: MeetingSession {
        injectedMeeting ?? AppDelegate.current?.meetingSession ?? Self.idleMeeting
    }

    private static let idleMeeting = MeetingSession()

    // MARK: Preferences

    /// A toggle bound to a stored preference; `didSet` runs after the save, for side effects.
    func preference<Value>(_ key: ReferenceWritableKeyPath<UserData, Value>,
                           didSet: ((Value) -> Void)? = nil) -> Binding<Value> {
        Binding(get: { [userData] in userData[keyPath: key] },
                set: { [userData] value in
                    userData[keyPath: key] = value
                    userData.save()
                    didSet?(value)
                })
    }

    var hotkey: Binding<String> {
        Binding(get: { [userData] in userData.hotkeyName },
                set: { [userData] name in
                    userData.hotkeyName = name
                    userData.save()
                    NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
                })
    }

    var appearance: Binding<String> {
        Binding(get: { [theme] in theme.current.id }, set: { [theme] in theme.setTheme($0) })
    }

    func setLaunchAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func openSystemSettings(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    func runSetupAgain() { openSetup() }

    /// Lands the window on the Companion tab, scrolled to `section`.
    func showCompanion(_ section: CompanionSection = .companion) {
        group = .companion
        companion.selection.section = section
    }

    // MARK: Reset

    func reset() {
        history.deleteAll()
        notes.deleteAll()
        userData.dictionaryWords.removeAll()
        userData.snippets.removeAll()
        userData.customAICommands.removeAll()
        userData.scratchpad = ""
        userData.lastTranscription = ""
        userData.selectedLanguage = "english"
        userData.voiceCommandsEnabled = true
        userData.spokenPunctuationEnabled = false
        userData.hotkeyName = "Fn"
        theme.setTheme(ThemeManager.systemThemeID)
        // A queued write landing after the delete would bring back settings the user just erased.
        userData.discardPendingSave()
        let files = FileManager.default
        for folder in dataFolders {
            try? files.removeItem(at: folder)
        }
        // The stores keep the support folder's URL for the whole launch, so their next save needs it back.
        if let support = dataFolders.first {
            try? files.createDirectory(at: support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        resetDone = true
    }

    // MARK: Help

    func loadCrashReports() {
        (crashLogs, lastRunCrashed) = crashReports()
    }

    func reportIssue(crashLog: String? = nil) {
        openIssue(crashLog, .bug)
    }

    func copy(_ log: CrashLogSummary) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log.content, forType: .string)
    }

    func reveal(_ url: URL, isDirectory: Bool = false) {
        revealProblem = nil
        let workspace = NSWorkspace.shared
        if isDirectory {
            if workspace.selectFile(nil, inFileViewerRootedAtPath: url.path) { return }
            if workspace.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path) { return }
            revealProblem = "Couldn\u{2019}t open \(url.path)."
        } else {
            if workspace.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path) { return }
            revealProblem = "Couldn\u{2019}t show \(url.lastPathComponent). It may have been deleted."
        }
    }

    func startMicTest() {
        let source = levels ?? AppDelegate.current?.audioRecorder?.$inputLevel.eraseToAnyPublisher()
        levelWatch = source?.sink { [weak self] in self?.micLevel = $0 }
    }

    func stopMicTest() {
        levelWatch = nil
        micLevel = 0
    }

    static let systemReportsFolder = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)

    private static func savedCrashReports() -> (logs: [CrashLogSummary], lastRunCrashed: Bool) {
        let reporter = CrashReporter.shared
        let logs = reporter.crashLogs.map { CrashLogSummary(url: $0.url, date: $0.date, content: $0.content) }
        return (logs, reporter.previousRunCrashed)
    }
}

// MARK: - Window

/// Settings as a J-card: the tab name, outlined caps tabs, today's tape, then rows on the rules.
struct SettingsWindowView: View {
    @Bindable var model: SettingsModel
    @ObservedObject private var theme: ThemeManager
    @ObservedObject private var userData: UserData
    @ObservedObject private var history: TranscriptionHistory
    @ObservedObject private var companionSelection: CompanionSectionSelection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: SettingsModel? = nil) {
        let model = model ?? .shared
        self.model = model
        theme = model.theme
        userData = model.userData
        history = model.companion.history
        companionSelection = model.companion.selection
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            TapeStripe("Daily tape", segments: model.companion.todayTape, goal: userData.tapeGoal)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) { pane }
                        .padding(.horizontal, 56)
                        .padding(.top, 22)
                        .padding(.bottom, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(model.group)
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)),
                                                                           removal: .opacity))
                }
                .onAppear { scrollIfAsked(proxy) }
                .onChange(of: companionSelection.section) { _, _ in scrollIfAsked(proxy) }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Mixtape.paper)
        .foregroundStyle(Mixtape.ink)
        .tint(Mixtape.ink)
        .preferredColorScheme(theme.current.colorScheme)
    }

    private var header: some View {
        VStack(spacing: 16) {
            Text(model.group.title)
                .font(Mixtape.body(12))
                .foregroundStyle(Mixtape.ink3)
                .accessibilityHidden(true)
            SettingsTabs(selection: tab)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .top)
    }

    private var tab: Binding<SettingsGroup> {
        Binding(get: { model.group }, set: { group in
            withAnimation(.easeOut(duration: reduceMotion ? 0.18 : 0.2)) { model.group = group }
        })
    }

    @ViewBuilder
    private var pane: some View {
        switch model.group {
        case .general: GeneralSettingsContent(model: model)
        case .speech: SpeechSettingsContent(model: model)
        case .shortcuts: ShortcutSettingsContent(model: model)
        case .companion: CompanionSettingsContent(model: model.companion)
        case .privacy: PrivacySettingsContent(model: model)
        }
    }

    private func scrollIfAsked(_ proxy: ScrollViewProxy) {
        guard companionSelection.section == .remember, model.group == .companion else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { proxy.scrollTo(CompanionSection.remember, anchor: .top) }
        companionSelection.section = .companion
    }

    /// The Settings window, shared by `AppDelegate.showSettingsWindow` and the snapshot tests.
    static func makeWindow(model: SettingsModel? = nil) -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsWindowView(model: model))
        // The hosting view must never size the window: that is the ~133 pt collapse `showMainWindow` guards.
        hosting.sizingOptions = []
        let size = NSSize(width: Layout.settingsIdealWidth, height: Layout.settingsIdealHeight)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isRestorable = false
        hosting.view.frame = NSRect(origin: .zero, size: size)
        window.contentViewController = hosting
        window.contentMinSize = NSSize(width: Layout.settingsMinWidth, height: Layout.settingsMinHeight)
        window.contentMaxSize = NSSize(width: Layout.settingsIdealWidth, height: .greatestFiniteMagnitude)
        window.isReleasedWhenClosed = false
        return window
    }
}

// MARK: - Mixtape settings pieces

/// The section tabs: outlined caps pills, the current one filled with ink. Command-1 to 5 switch them.
struct SettingsTabs: View {
    @Binding var selection: SettingsGroup

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(SettingsGroup.allCases.enumerated()), id: \.element) { index, group in
                let picked = group == selection
                Button(group.title) { selection = group }
                    .buttonStyle(CapsChipStyle(kind: .tab, picked: picked))
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Settings section")
    }
}

/// A choice of a few options as outlined caps segments; the picked one takes the ink border and a wash.
struct SettingsChoice<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let picked = option.0 == selection
                Button(option.1) { selection = option.0 }
                    .buttonStyle(CapsChipStyle(kind: .choice, picked: picked))
                    .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .fixedSize()
        .animation(.easeOut(duration: 0.15), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct CapsChipStyle: ButtonStyle {
    enum Kind { case tab, choice }
    let kind: Kind
    let picked: Bool

    func makeBody(configuration: Configuration) -> some View {
        Chip(configuration: configuration, kind: kind, picked: picked)
    }

    private struct Chip: View {
        let configuration: Configuration
        let kind: Kind
        let picked: Bool
        @State private var hovering = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let tab = kind == .tab
            configuration.label
                .mixtapeCaps(10.5, tracking: tab ? 0.1 : 0.08)
                .lineLimit(1)
                .foregroundStyle(tab && picked ? Mixtape.paper : picked || hovering ? Mixtape.ink : Mixtape.ink2)
                .padding(.horizontal, tab ? 13 : 11)
                .frame(height: tab ? 28 : 26)
                .background(Capsule().fill(picked ? (tab ? Mixtape.ink : Mixtape.wash) : .clear))
                .overlay(Capsule().strokeBorder(border, lineWidth: 1.5))
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
                .animation(Mixtape.press, value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .onHover { hovering = $0 }
        }

        private var border: Color {
            if picked { return Mixtape.ink }
            return hovering && kind == .tab ? Mixtape.ink2 : Mixtape.rule2
        }
    }
}

/// A section: caps title over the ink rule, its rows, and an optional footnote.
struct SettingsSection<Content: View>: View {
    let title: String
    var detail: String?
    var note: String?
    @ViewBuilder var content: Content

    init(_ title: String, detail: String? = nil, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader(title, detail: detail)
            content
            if let note {
                Text(note)
                    .font(Mixtape.body(12))
                    .foregroundStyle(Mixtape.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }
}

/// One row on the rules: a 13.5 pt label with an optional 12 pt line under it, its control trailing.
struct SettingsRow<Label: View, Trailing: View>: View {
    var minHeight: CGFloat = 51
    @ViewBuilder var label: Label
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) { label }
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(Mixtape.body(13.5))
        .foregroundStyle(Mixtape.ink)
        .padding(.vertical, 10)
        .frame(minHeight: minHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Mixtape.rule).frame(height: 1) }
    }
}

extension SettingsRow where Label == SettingsRowLabel {
    init(_ title: String, _ detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        minHeight = detail == nil ? 51 : 68
        label = SettingsRowLabel(title: title, detail: detail)
        self.trailing = trailing()
    }
}

extension SettingsRow where Label == SettingsRowLabel, Trailing == EmptyView {
    init(_ title: String, _ detail: String? = nil) {
        self.init(title, detail) { EmptyView() }
    }
}

struct SettingsRowLabel: View {
    let title: String
    let detail: String?

    var body: some View {
        Text(title)
        if let detail {
            SettingsDetail(detail)
        }
    }
}

/// The 12 pt line under a row's label.
struct SettingsDetail: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Mixtape.body(12))
            .foregroundStyle(Mixtape.ink3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A paragraph set straight on the page: a bold first sentence, then the rest in secondary ink.
struct SettingsProse: View {
    let title: String
    let text: String

    var body: some View {
        (Text(title).fontWeight(.semibold).foregroundStyle(Mixtape.ink) + Text(" ") + Text(text).foregroundStyle(Mixtape.ink2))
            .font(Mixtape.body(13.5))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The ink-outline switch: a 40 x 22 outline whose knob springs across and fills with ink when on.
struct SettingsSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        InkSwitch(configuration: configuration)
    }
}

extension ToggleStyle where Self == SettingsSwitchStyle {
    static var settingsSwitch: SettingsSwitchStyle { SettingsSwitchStyle() }
}

private struct InkSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let on = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(on ? Mixtape.ink : .clear)
                .overlay { Capsule().strokeBorder(on ? Mixtape.ink : Mixtape.ink2, lineWidth: 1.5) }
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(on ? Mixtape.paper : Mixtape.ink2).frame(width: 15, height: 15).padding(3.5)
                }
                .frame(width: 40, height: 22)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.62), value: on)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// The `pick` menu: its value in mono semibold over an ink underline that curves up at the ends.
struct SettingsPick<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder var content: Content

    init(_ title: String, value: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.value = value
        self.content = content()
    }

    var body: some View {
        Menu { content } label: {
            HStack(spacing: 8) {
                Text(value).font(Mixtape.mono(12, .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Mixtape.ink3)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(PickStyle())
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

private struct PickStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Pick(configuration: configuration)
    }

    private struct Pick: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .lineLimit(1)
                .foregroundStyle(Mixtape.ink)
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .frame(height: 28)
                .background(Capsule().fill(hovering || configuration.isPressed ? Mixtape.wash : .clear))
                .overlay { PickLine().fill(Mixtape.ink, style: FillStyle(eoFill: true)) }
                .contentShape(Capsule())
                .animation(.easeOut(duration: 0.12), value: hovering)
                .onHover { hovering = $0 }
        }
    }

    /// A 1.5 pt bottom border on a capsule, as CSS draws it: full width at the foot, tapering up the ends.
    private struct PickLine: Shape {
        func path(in rect: CGRect) -> Path {
            let r = rect.height / 2
            var path = Path()
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - 1.5),
                                cornerSize: CGSize(width: r, height: r - 1.5))
            return path.intersection(Path(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: r)), eoFill: true)
        }
    }
}

/// A text field written on a line: ink underline, red while typing.
struct SettingsField: View {
    let placeholder: String
    var label: String?
    @Binding var text: String
    var axis: Axis = .horizontal
    @FocusState private var focused: Bool

    init(_ placeholder: String, label: String? = nil, text: Binding<String>, axis: Axis = .horizontal) {
        self.placeholder = placeholder
        self.label = label
        _text = text
        self.axis = axis
    }

    var body: some View {
        TextField("", text: $text, axis: axis)
            .textFieldStyle(.plain)
            .font(Mixtape.body(13.5))
            .foregroundStyle(Mixtape.ink)
            .tint(Mixtape.red)
            .focused($focused)
            .accessibilityLabel(label ?? placeholder)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(Mixtape.body(13.5)).foregroundStyle(Mixtape.ink3)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(focused ? Mixtape.red : Mixtape.ink).frame(height: 1.5)
            }
    }
}

/// A state beside a name: granted gets a drawn tick, a warning a gold dot.
struct SettingsStatus: View {
    let text: String
    var kind: Look.Status.Kind = .neutral

    var body: some View {
        HStack(spacing: 6) {
            switch kind {
            case .ok: DrawnStroke(InkTick(), lineWidth: 1.8).frame(width: 12, height: 10)
            case .warn: Circle().fill(Mixtape.gold).frame(width: 7, height: 7)
            case .neutral: EmptyView()
            }
            Text(text)
        }
        .font(Mixtape.body(12.5, kind == .neutral ? .regular : .medium))
        .foregroundStyle(kind == .neutral ? Mixtape.ink3 : Mixtape.ink2)
        .lineLimit(1)
    }
}

/// A thin level or progress line: red tape on a faint track.
struct SettingsMeter: View {
    let value: Double
    var width: CGFloat = 120

    var body: some View {
        Capsule()
            .fill(Mixtape.rule2)
            .overlay(alignment: .leading) {
                Capsule().fill(Mixtape.red).frame(width: max(4, width * min(max(value, 0), 1)))
            }
            .frame(width: width, height: 4)
    }
}

/// A key legend, as the mock's `kbd`.
struct SettingsKeycap: View {
    let key: String

    init(_ key: String) { self.key = key }

    var body: some View {
        Text(key)
            .font(Mixtape.mono(11))
            .foregroundStyle(Mixtape.ink2)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .overlay { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Mixtape.rule2) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(key) key")
    }
}
