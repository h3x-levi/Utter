import AVFoundation
import AppKit
import Combine
import SwiftUI
import UtterCore

@MainActor @Observable
final class HomeViewModel {
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
    }

    struct Readiness: Equatable {
        var mic = false
        var ax = false
        var modelPresent = true
        var modelLoad: LocalWhisperProvider.LoadState = .idle
    }

    var readiness = Readiness()
    private(set) var hotkey = "Fn"
    private(set) var modelState: ModelStore.State?
    private(set) var robotAsleep = false
    private(set) var robotRoundness = RobotGeometry.defaultRoundness
    private(set) var showsTryIt = false
    var tryText = ""

    let status: CaptureStatus
    @ObservationIgnored private let library: LibraryViewModel
    @ObservationIgnored private let selection: SidebarSelection
    @ObservationIgnored private let models: ModelStore
    @ObservationIgnored private let openSettings: (SettingsGroup?) -> Void
    @ObservationIgnored private var watches: Set<AnyCancellable> = []
    @ObservationIgnored private var sleepTask: Task<Void, Never>?

    init(status: CaptureStatus, selection: SidebarSelection, library: LibraryViewModel,
         readiness: ReadinessMonitor, userData: UserData, models: ModelStore,
         openSettings: @escaping (SettingsGroup?) -> Void) {
        self.status = status
        self.selection = selection
        self.library = library
        self.models = models
        self.openSettings = openSettings

        Publishers.CombineLatest4(readiness.$micGranted, readiness.$axGranted, readiness.$modelPresent, readiness.$modelLoad)
            .sink { [weak self] mic, ax, present, load in
                MainActor.assumeIsolated { self?.readiness = Readiness(mic: mic, ax: ax, modelPresent: present, modelLoad: load) }
            }.store(in: &watches)
        userData.$hotkeyName.sink { [weak self] name in
            MainActor.assumeIsolated { self?.hotkey = name }
        }.store(in: &watches)
        models.$states.combineLatest(models.$active).sink { [weak self] states, active in
            MainActor.assumeIsolated { self?.modelState = states[active] }
        }.store(in: &watches)
    }

    // MARK: Derived

    /// Library's items, less one waiting out its undo window.
    private var items: LazyFilterSequence<[LibraryItem]> {
        let hidden = library.pendingDelete?.id
        return library.allItems.lazy.filter { $0.id != hidden }
    }

    /// Today's dictations and notes, newest first.
    var today: [LibraryItem] {
        let calendar = Calendar.current
        return items.filter { calendar.isDateInToday($0.date) }
    }

    func recent(_ limit: Int) -> [LibraryItem] { Array(items.prefix(limit)) }

    var copiedID: String? { library.copiedID }

    var summary: String { Self.summary(today, on: .now) }

    var needs: [Need] { Self.needs(readiness, modelState: modelState) }

    var robotState: RobotState { robotAsleep ? .sleep : Self.robotState(for: status.turn) }

    static func summary(_ today: [LibraryItem], on date: Date) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard !today.isEmpty else { return day }
        let words = today.reduce(0) { $0 + $1.words }
        let things = today.count == 1 ? "1 dictation or note" : "\(today.count) dictations and notes"
        return "\(day) · \(things), \(words == 1 ? "1 word" : "\(words.formatted()) words")"
    }

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

    static func cardTitle(_ count: Int) -> String {
        count == 1 ? "One thing left." : "\(count) things left."
    }

    static func robotState(for turn: CaptureStatus.Turn) -> RobotState {
        switch turn {
        case .idle: .idle
        case .preparing, .thinking: .waiting
        case .listening: .input
        case .landed: .success
        case .failed: .failure
        }
    }

    // MARK: Actions

    func appeared() {
        showsTryIt = library.allItems.isEmpty
        robotRoundness = CGFloat(UserDefaults.standard.companionHeadRoundness)
        turnChanged()
    }

    /// Wakes the robot on every turn and lets it fall asleep after 30 seconds of quiet.
    func turnChanged() {
        sleepTask?.cancel()
        robotAsleep = false
        guard status.turn != .listening, status.turn != .thinking else { return }
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.robotAsleep = true
        }
    }

    func grant(_ need: Need) {
        switch need {
        case .microphone:
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
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

    func open(_ item: LibraryItem) {
        library.search = ""
        selection.open(libraryItem: item.id)
    }

    func showAll() {
        library.search = ""
        selection.libraryFilter = .all
        selection.item = .library
    }

    func copy(_ item: LibraryItem) { library.copy(item) }
}

// MARK: - Screen

struct HomeScreen: View {
    @Bindable var model: HomeViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewport: CGFloat = 0
    @State private var recentRoom: CGFloat = 0

    private static let rowHeight: CGFloat = 46
    private static let lead = HomeHero.textLead

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.leading, Self.lead)
                    .padding(.trailing, 44)
                    .padding(.top, 14)
                HomeHero(today: model.today, open: open)
                    .padding(.top, 12)
                if !model.needs.isEmpty {
                    readiness.padding(.leading, Self.lead).padding(.trailing, 30).padding(.top, 14)
                }
                Group {
                    if model.showsTryIt {
                        tryIt
                        Spacer(minLength: 24)
                    } else {
                        recent
                    }
                    Text("Your voice is turned into text on this Mac. It is never uploaded.")
                        .font(.callout)
                        .foregroundStyle(Look.Color.ink3)
                        .padding(.leading, 6)
                        .padding(.vertical, 18)
                }
                .padding(.leading, Self.lead)
                .padding(.trailing, 30)
                .padding(.top, 18)
            }
            .frame(minHeight: viewport, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
        .onAppear { model.appeared() }
        .onChange(of: model.status.turn) { model.turnChanged() }
    }

    private func open(_ item: LibraryItem) {
        withAnimation(Look.Motion.settle.animation(reduceMotion: reduceMotion)) { model.open(item) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your voice today").pageTitle()
                Text(model.summary)
                    .monospacedDigit()
                    .foregroundStyle(Look.Color.ink2)
            }
            Spacer(minLength: 0)
            RobotPreview(state: model.robotState, roundness: model.robotRoundness)
                .frame(width: 38, height: 35)
                .accessibilityHidden(true)
        }
    }

    private var readiness: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.needs.enumerated()), id: \.element.id) { index, need in
                NeedRow(need: need, title: index == 0 ? HomeViewModel.cardTitle(model.needs.count) : nil) {
                    model.grant(need)
                }
            }
        }
        .padding(.vertical, Look.Card.inset)
        .panel()
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try it").font(.headline).foregroundStyle(Look.Color.ink2)
            TextField("Click here, hold \(model.hotkey) and say a sentence", text: $model.tryText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(14)
                .panel()
            HStack(spacing: 6) {
                Text("Hold")
                Look.Keycap(model.hotkey)
                Text("and talk. Let go and your words appear in the text box.")
            }
            .font(.callout)
            .foregroundStyle(Look.Color.ink2)
            .accessibilityElement(children: .combine)
        }
    }

    /// As many rows as the window has room for, so the card fills the page instead of leaving it empty.
    private var recent: some View {
        let fits = max(3, Int((recentRoom - 2 * Look.Card.inset) / Self.rowHeight))
        let items = model.recent(fits)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent")
                    .font(.headline)
                    .foregroundStyle(Look.Color.ink2)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: model.showAll) {
                    Text("See all in Library")
                        .font(.callout)
                        .foregroundStyle(Look.Color.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                }
                .buttonStyle(Look.RowStyle(radius: 8, scale: Look.Press.nav))
            }
            .padding(.horizontal, 6)
            Color.clear
                .frame(minHeight: 3 * Self.rowHeight + 2 * Look.Card.inset, maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { recentRoom = $0 }
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            RecentRow(item: item, copied: model.copiedID == item.id,
                                      copy: { model.copy(item) }, open: { open(item) })
                        }
                    }
                    .padding(Look.Card.inset)
                    .panel()
                }
        }
    }
}

private struct NeedRow: View {
    let need: HomeViewModel.Need
    let title: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Look.Color.tint).frame(width: 9, height: 9).accessibilityHidden(true)
            Group {
                if let title {
                    Text("\(Text(title).fontWeight(.semibold).foregroundStyle(.primary)) \(sentence)")
                } else {
                    Text(sentence)
                }
            }
            .foregroundStyle(Look.Color.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if case .model(let fraction?) = need {
                ProgressView(value: fraction)
                    .frame(width: 120)
                    .tint(Look.Color.tint)
                    .accessibilityLabel("Downloading the speech model")
            } else {
                Button(actionTitle, action: action)
                    .glassButton(prominent: true)
                    .accessibilityHint(sentence)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
    }

    private var sentence: String {
        switch need {
        case .microphone: "Allow the microphone so Utter can hear you."
        case .accessibility: "Allow Accessibility so Utter can type into other apps."
        case .model(nil): "Download the speech model so Utter can turn speech into text."
        case .model: "Downloading the speech model."
        case .modelFailed(let reason): "The speech model didn't load. \(reason)"
        }
    }

    private var actionTitle: String {
        switch need {
        case .microphone, .accessibility: "Grant"
        case .model: "Download"
        case .modelFailed: "Speech Settings"
        }
    }
}

private struct RecentRow: View {
    let item: LibraryItem
    let copied: Bool
    let copy: () -> Void
    let open: () -> Void

    @Environment(\.libraryTransition) private var transition
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Circle()
                    .fill(RibbonTint.color(RibbonTint.liquid(for: item), dark: scheme == .dark))
                    .frame(width: 7, height: 7)
                    .frame(width: 10)
                Text(item.title)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sharedWords(item.id, in: transition, isSource: true)
                HStack(spacing: 8) {
                    if copied || item.kind != .dictation { Text(copied ? "Copied" : item.kindName) }
                    Text(item.date, format: Calendar.current.isDateInToday(item.date)
                         ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).hour().minute())
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(Look.Color.ink3)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
        }
        .buttonStyle(Look.RowStyle())
        .contextMenu {
            Button("Copy", action: copy)
            Button("Open in Library", action: open)
        }
        .accessibilityLabel(item.title)
        .accessibilityValue("\(item.kindName), \(item.date.formatted(date: .omitted, time: .shortened))")
        .accessibilityHint("Opens it in Library")
        .accessibilityAction(named: "Copy", copy)
    }
}
