import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UtterCore

enum SettingsGroup: String, CaseIterable, Identifiable, Hashable {
    case general, speech, shortcuts, privacy, help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .speech: "Speech"
        case .shortcuts: "Shortcuts"
        case .privacy: "Privacy"
        case .help: "Help"
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

/// Settings in its own 760 pt window: the tab strip rides the toolbar glass, and each pane is a
/// column of custom groups 70 pt in from either edge.
struct SettingsWindowView: View {
    @Bindable var model: SettingsModel
    @ObservedObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: SettingsModel? = nil) {
        let model = model ?? .shared
        self.model = model
        theme = model.theme
    }

    var body: some View {
        ZStack {
            ScrollView {
                pane
                    .padding(.horizontal, 70)
                    .padding(.top, 4)
                    .padding(.bottom, 30)
            }
            .hardTopScrollEdge()
            .id(model.group)
            .transition(PaneMotion.paneTransition(reduceMotion: reduceMotion))
        }
        .background { PaneGround().ignoresSafeArea() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                PaneSegmented(title: "Settings section", selection: tab, onGlass: true,
                              options: SettingsGroup.allCases.map { ($0, $0.title) })
            }
        }
        .foregroundStyle(Pane.ink)
        .tint(Look.Color.tint)
        .preferredColorScheme(theme.current.colorScheme)
    }

    private var tab: Binding<SettingsGroup> {
        Binding(get: { model.group }, set: { group in
            withAnimation(PaneMotion.pane(reduceMotion: reduceMotion)) { model.group = group }
        })
    }

    @ViewBuilder
    private var pane: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch model.group {
            case .general: GeneralSettingsContent(model: model)
            case .speech: SpeechSettingsContent(model: model)
            case .shortcuts: ShortcutSettingsContent(model: model)
            case .privacy: PrivacySettingsContent(model: model)
            case .help: HelpSettingsContent(model: model)
            }
        }
    }

    /// The Settings window, shared by `AppDelegate.showSettingsWindow` and the snapshot tests.
    static func makeWindow(model: SettingsModel? = nil) -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsWindowView(model: model))
        // The hosting view must never size the window: that is the ~133 pt collapse `showMainWindow` guards.
        hosting.sizingOptions = []
        hosting.sceneBridgingOptions = .all
        let size = NSSize(width: Layout.settingsIdealWidth, height: Layout.settingsIdealHeight)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Settings"
        window.toolbarStyle = .preference
        window.isRestorable = false
        // Sized first: adopting a zero-sized view lays the toolbar out clipped, and its overflow button never clears.
        hosting.view.frame = NSRect(origin: .zero, size: size)
        window.contentViewController = hosting
        window.contentMinSize = NSSize(width: Layout.settingsMinWidth, height: Layout.settingsMinHeight)
        window.contentMaxSize = NSSize(width: Layout.settingsIdealWidth, height: .greatestFiniteMagnitude)
        window.isReleasedWhenClosed = false
        return window
    }
}

// MARK: - Moonlight pane pieces

/// The v2 Moonlight tokens for content surfaces: tinted-white ink at 95, 64 and 42 percent, and fills
/// with a hairline instead of glass.
enum Pane {
    static let ink = swatch(light: .hex(0x0E1320), dark: .hex(0xF4F7FC, 0.95), darkIncreased: .white)
    static let ink2 = swatch(light: .hex(0x121A2C, 0.64), dark: .hex(0xDEE6F4, 0.64),
                             lightIncreased: .hex(0x121A2C, 0.82), darkIncreased: .hex(0xDEE6F4, 0.85))
    static let ink3 = swatch(light: .hex(0x121A2C, 0.44), dark: .hex(0xD6E0F0, 0.42),
                             lightIncreased: .hex(0x121A2C, 0.7), darkIncreased: .hex(0xD6E0F0, 0.7))
    static let fill = swatch(light: .hex(0xFFFFFF, 0.6), dark: .hex(0xFFFFFF, 0.07))
    static let fillHover = swatch(light: .hex(0xFFFFFF, 0.82), dark: .hex(0xFFFFFF, 0.11))
    static let edge = swatch(light: .hex(0xFFFFFF, 0.85), dark: .hex(0xFFFFFF, 0.1),
                             lightIncreased: .hex(0x142846, 0.35), darkIncreased: .hex(0xFFFFFF, 0.4))
    static let highlight = swatch(light: .white, dark: .hex(0xFFFFFF, 0.15))
    static let row = swatch(light: .hex(0x142846, 0.055), dark: .hex(0xFFFFFF, 0.06))
    static let track = swatch(light: .hex(0x142846, 0.12), dark: .hex(0xFFFFFF, 0.08))
    static let sep = swatch(light: .hex(0x142846, 0.08), dark: .hex(0xFFFFFF, 0.065),
                            lightIncreased: .hex(0x142846, 0.3), darkIncreased: .hex(0xFFFFFF, 0.3))
    static let accent = swatch(light: .hex(0x283A60, 0.09), dark: .hex(0xE2EAF8, 0.15))
    static let groundTop = swatch(light: .hex(0xF2F4F8), dark: .hex(0x13161F))
    static let groundBottom = swatch(light: .hex(0xE8ECF2), dark: .hex(0x0D1017))

    static let subtitle = Font.system(size: 11.5)

    private static func swatch(light: NSColor, dark: NSColor,
                               lightIncreased: NSColor? = nil, darkIncreased: NSColor? = nil) -> Color {
        Color(nsColor: Look.Swatch(light: light, dark: dark,
                                   lightIncreased: lightIncreased, darkIncreased: darkIncreased).nsColor)
    }
}

/// The motion vocabulary from the motion research: every token collapses to a short fade under Reduce Motion.
enum PaneMotion {
    static let reduced = Animation.easeOut(duration: 0.18)
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.62)

    static func lens(reduceMotion: Bool) -> Animation { reduceMotion ? reduced : .snappy(duration: 0.4) }
    static func pane(reduceMotion: Bool) -> Animation { reduceMotion ? reduced : .easeOut(duration: 0.2) }
    static func page(reduceMotion: Bool) -> Animation { reduceMotion ? .easeOut(duration: 0.14) : .spring(duration: 0.46, bounce: 0.16) }
    static func hover(_ entering: Bool) -> Animation { .easeOut(duration: entering ? 0.12 : 0.15) }

    static func paneTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity)
    }
}

/// The window's one continuous ground, Moonlight navy in dark and cool paper in light.
struct PaneGround: View {
    var body: some View {
        LinearGradient(colors: [Pane.groundTop, Pane.groundBottom], startPoint: .top, endPoint: .bottom)
    }
}

/// A titled group of rows on one rounded fill. Each row draws a hairline on its top edge and the
/// stack masks off its first point, so separators only ever fall between rows.
struct PaneGroup<Content: View>: View {
    var title: String?
    var note: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Pane.ink3)
                    .padding(.horizontal, 8)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content }
                .mask { Rectangle().padding(.top, 1).padding(.horizontal, -24).padding(.bottom, -24) }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .background { PaneCard() }
            if let note {
                Text(note)
                    .font(Pane.subtitle)
                    .foregroundStyle(Pane.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
    }
}

/// One row: a 13 pt label with an optional 11.5 pt line under it, and its control on the trailing edge.
struct PaneRow<Label: View, Trailing: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) { label }
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(.body)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
        .overlay(alignment: .top) { Rectangle().fill(Pane.sep).frame(height: 1) }
    }
}

extension PaneRow where Label == PaneRowLabel {
    init(_ title: String, _ detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        label = PaneRowLabel(title: title, detail: detail)
        self.trailing = trailing()
    }
}

extension PaneRow where Label == PaneRowLabel, Trailing == EmptyView {
    init(_ title: String, _ detail: String? = nil) {
        self.init(title, detail) { EmptyView() }
    }
}

struct PaneRowLabel: View {
    let title: String
    let detail: String?

    var body: some View {
        Text(title)
        if let detail {
            Text(detail)
                .font(Pane.subtitle)
                .foregroundStyle(Pane.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A prose card: a bold first line, then body copy in the secondary ink.
struct PaneNote: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold).foregroundStyle(Pane.ink)
            Text(text).foregroundStyle(Pane.ink2)
        }
        .font(.body)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background { PaneCard() }
    }
}

/// The content-layer surface: a translucent fill, a hairline lit from above, and a soft lift.
struct PaneCard: View {
    var radius: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(Pane.fill)
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [Pane.highlight, Pane.edge],
                                                  startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2)),
                                   lineWidth: 1)
            }
            .shadow(color: scheme == .dark ? .black.opacity(0.18) : Color(red: 0.12, green: 0.2, blue: 0.35).opacity(0.08),
                    radius: 7, y: 4)
    }
}

/// The selection lozenge: light from above over the accent wash.
struct PaneLens: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        Capsule()
            .fill(LinearGradient(colors: dark ? [.white.opacity(0.15), .white.opacity(0.03)] : [.white, .white.opacity(0.7)],
                                 startPoint: .top, endPoint: .bottom))
            .background(Capsule().fill(Pane.accent))
            .overlay {
                Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.22 : 1), .clear],
                                                      startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .shadow(color: dark ? .black.opacity(0.2) : Color(red: 0.08, green: 0.16, blue: 0.27).opacity(0.12),
                    radius: dark ? 4 : 5, y: 2)
    }
}

/// A segmented choice whose lens slides to the picked option.
struct PaneSegmented<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    var onGlass = false
    let options: [(Value, String)]

    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let picked = option.0 == selection
                Button { selection = option.0 } label: {
                    Text(option.1)
                        .font(.system(size: 12.5))
                        .foregroundStyle(picked ? Pane.ink : Pane.ink2)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background {
                            if picked { PaneLens().matchedGeometryEffect(id: "lens", in: lens) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(PanePressStyle(scale: 0.97))
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
        .padding(3)
        .background {
            if !onGlass || !GlassSupport.available { Capsule().fill(Pane.row) }
        }
        .fixedSize()
        .animation(PaneMotion.lens(reduceMotion: reduceMotion), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// Hover fill and press scale for anything clickable; Reduce Motion keeps the fill and drops the scale.
struct PanePressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var radius: CGFloat = 999
    var hoverFill = true

    func makeBody(configuration: Configuration) -> some View {
        PanePress(configuration: configuration, style: self)
    }
}

private struct PanePress: View {
    let configuration: ButtonStyleConfiguration
    let style: PanePressStyle
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .background {
                if style.hoverFill {
                    RoundedRectangle(cornerRadius: style.radius, style: .continuous)
                        .fill(Pane.row)
                        .opacity(hovered || configuration.isPressed ? 1 : 0)
                }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? style.scale : 1)
            .animation(reduceMotion ? PaneMotion.reduced : PaneMotion.press, value: configuration.isPressed)
            .animation(PaneMotion.hover(hovered), value: hovered)
            .onHover { hovered = $0 && isEnabled }
    }
}

/// The three v2 buttons: a borderless one, a solo fill with a hairline, and the lens-lit primary.
struct PaneButtonStyle: ButtonStyle {
    enum Kind { case plain, solo, prime }
    var kind: Kind = .solo

    func makeBody(configuration: Configuration) -> some View {
        PaneButton(configuration: configuration, kind: kind)
    }
}

private struct PaneButton: View {
    let configuration: ButtonStyleConfiguration
    let kind: PaneButtonStyle.Kind
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(configuration.role == .destructive ? Color.red : kind == .plain ? Pane.ink2 : Pane.ink)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background { surface }
            .contentShape(Capsule())
            .brightness(kind == .prime && hovered ? 0.05 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? PaneMotion.reduced : PaneMotion.press, value: configuration.isPressed)
            .animation(PaneMotion.hover(hovered), value: hovered)
            .onHover { hovered = $0 && isEnabled }
    }

    @ViewBuilder
    private var surface: some View {
        let lit = hovered || configuration.isPressed
        switch kind {
        case .plain:
            Capsule().fill(Pane.row).opacity(lit ? 1 : 0)
        case .solo:
            Capsule().fill(lit ? Pane.fillHover : Pane.fill)
                .overlay {
                    Capsule().strokeBorder(LinearGradient(colors: [Pane.highlight, Pane.edge],
                                                          startPoint: .top, endPoint: .center), lineWidth: 1)
                }
        case .prime:
            PaneLens()
        }
    }
}

extension ButtonStyle where Self == PaneButtonStyle {
    static func pane(_ kind: PaneButtonStyle.Kind = .solo) -> PaneButtonStyle { PaneButtonStyle(kind: kind) }
}

/// The v2 switch: a 38 x 22 track with a white knob that springs across 16 pt.
struct PaneSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        PaneSwitch(configuration: configuration)
    }
}

extension ToggleStyle where Self == PaneSwitchStyle {
    static var pane: PaneSwitchStyle { PaneSwitchStyle() }
}

private struct PaneSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let on = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            Capsule()
                .fill(on ? Look.Color.tint.opacity(0.6) : Pane.track)
                .overlay { Capsule().strokeBorder(Pane.edge) }
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                        .frame(width: 16, height: 16)
                        .padding(3)
                }
                .frame(width: 38, height: 22)
        }
        .buttonStyle(PanePressStyle(scale: 0.94, hoverFill: false))
        .animation(PaneMotion.lens(reduceMotion: reduceMotion), value: on)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

/// A state beside a name: granted reads in the Moonlight ink with a check, a warning gets an amber dot.
struct PaneStatus: View {
    let text: String
    var kind: Look.Status.Kind = .neutral

    var body: some View {
        HStack(spacing: 5) {
            switch kind {
            case .ok: Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
            case .warn: Circle().fill(Color.orange).frame(width: 7, height: 7)
            case .neutral: EmptyView()
            }
            Text(text)
        }
        .font(.system(size: 12.5, weight: kind == .ok ? .semibold : .regular))
        .foregroundStyle(kind == .ok ? Look.Color.tint : Pane.ink2)
    }
}

/// A thin level or progress bar in the Moonlight ink.
struct PaneMeter: View {
    let value: Double
    var width: CGFloat = 120

    var body: some View {
        Capsule()
            .fill(Pane.row)
            .overlay(alignment: .leading) {
                Capsule().fill(Look.Color.tint).frame(width: max(4, width * min(max(value, 0), 1)))
            }
            .frame(width: width, height: 4)
    }
}

extension View {
    /// The hard scroll edge under the toolbar on macOS 26, which replaces a titlebar hairline.
    @ViewBuilder
    func hardTopScrollEdge() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
