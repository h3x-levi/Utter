import Observation
import SwiftUI
import UtterCore

/// Where a deep link into the Companion tab should land.
enum CompanionSection: String, CaseIterable, Identifiable {
    case companion = "Companion"
    case remember = "Remember"

    var id: String { rawValue }
}

@MainActor
final class CompanionSectionSelection: ObservableObject {
    static let shared = CompanionSectionSelection()
    @Published var section: CompanionSection = .companion
}

@MainActor @Observable
final class CompanionSettingsModel {
    let userData: UserData
    let memories: CompanionMemoryStore
    let notifications: CompanionNotificationScheduler
    let selection: CompanionSectionSelection
    let history: TranscriptionHistory
    let notes: NoteStore

    var confirmingDeleteAll = false
    var roundness: Double {
        didSet { defaults.companionHeadRoundness = roundness }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(userData: UserData = .shared,
         memories: CompanionMemoryStore? = nil,
         notifications: CompanionNotificationScheduler? = nil,
         selection: CompanionSectionSelection? = nil,
         history: TranscriptionHistory? = nil,
         notes: NoteStore? = nil,
         defaults: UserDefaults = .standard) {
        self.userData = userData
        self.memories = memories ?? .shared
        self.notifications = notifications ?? .shared
        self.selection = selection ?? .shared
        self.history = history ?? .shared
        self.notes = notes ?? .shared
        self.defaults = defaults
        roundness = defaults.companionHeadRoundness
    }

    /// Today's goal progress; a stored day that is not today counts as nothing done yet.
    var today: CompanionProgress {
        let progress = userData.companionProgress
        return progress.day == CompanionProgress.dayStamp(Date()) ? progress : .today()
    }

    /// Today's tape, oldest first: the same tracks the hub and Library count (dictations, notes and meetings).
    var todayTape: [TapeSegment<String>] {
        let items = HubTrack.tape(history.entries, notes.notes).filter { Calendar.current.isDateInToday($0.date) }
            .reversed().map(\.item)
        return TapeSegment.today(items, unkept: userData.unkeptWordsToday(onTape: TapeSegment.dictatedWords(items)))
    }

    var wordsToday: Int { todayTape.reduce(0) { $0 + $1.words } }

    func binding<Value>(_ key: ReferenceWritableKeyPath<UserData, Value>) -> Binding<Value> {
        Binding(get: { [userData] in userData[keyPath: key] },
                set: { [userData] value in
                    userData[keyPath: key] = value
                    userData.save()
                })
    }

    func complete(_ memory: CompanionMemory) { memories.complete(id: memory.id) }
    func delete(_ memory: CompanionMemory) { memories.delete(id: memory.id) }
    func deleteAll() { memories.deleteAll() }
}

/// The Companion tab of Settings: the robot on its stage, its reminders, and the length of the daily tape.
struct CompanionSettingsContent: View {
    @State private var model: CompanionSettingsModel
    @ObservedObject private var userData: UserData
    @ObservedObject private var memories: CompanionMemoryStore
    @ObservedObject private var notifications: CompanionNotificationScheduler
    @ObservedObject private var history: TranscriptionHistory

    init(model: CompanionSettingsModel? = nil) {
        let model = model ?? CompanionSettingsModel()
        _model = State(initialValue: model)
        userData = model.userData
        memories = model.memories
        notifications = model.notifications
        history = model.history
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            stage
            SettingsSection("Companion", detail: "beside the pill") {
                toggle("Show beside the pill", "Listens with you and sleeps when you\u{2019}re idle", \.companionEnabled)
                SettingsRow("Size") {
                    SettingsChoice(title: "Size", selection: model.binding(\.companionSize),
                                   options: CompanionSize.allCases.map { ($0, $0.label) })
                }
                SettingsRow("Head shape", "Square to round") {
                    SettingsChoice(title: "Head shape",
                                   selection: Binding(get: { [0.0, 50, 100].min { abs($0 - model.roundness) < abs($1 - model.roundness) } ?? 50 },
                                                      set: { model.roundness = $0 }),
                                   options: [(0, "Square"), (50, "Soft"), (100, "Round")])
                }
                toggle("Quiet mode", "Sleeps and holds its reminders", \.companionQuietMode)
                toggle("Go quiet on its own", "While you share your screen or record a meeting", \.companionAutomaticQuietMode)
            }
        }
        reminders
        dailyTape
            .confirmationDialog("Delete all private reminders?", isPresented: $model.confirmingDeleteAll) {
                Button("Delete All", role: .destructive) { model.deleteAll() }
            } message: {
                Text("This removes every saved reminder and memory, and cancels its notification.")
            }
            .task { await notifications.refreshState() }
    }

    private var stage: some View {
        RobotPreview(roundness: model.roundness)
            .frame(width: 116, height: 116)
            .frame(width: 168, height: 170)
            .background(Mixtape.spine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Mixtape.rule) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your companion")
    }

    private var reminders: some View {
        SettingsSection("Reminders", detail: "it taps the pill, gently") {
            minutes("Stretch", \.companionStretchMinutes, choices: [15, 20, 30, 45, 60, 90, 120])
            minutes("Water", \.companionWaterMinutes, choices: [15, 20, 30, 45, 60, 90, 120])
            focusTimer
            toggle("Reminder sound", nil, \.companionSounds)
            SettingsRow("Your name", "Used when it reminds you") {
                SettingsField("Optional", label: "Your name", text: model.binding(\.companionUserName)).frame(width: 220)
            }
            SettingsRow("Pinned note", "Shown beside your companion") {
                SettingsField("Nothing pinned", label: "Pinned note", text: model.binding(\.companionPinnedMessage)).frame(width: 260)
            }
            privateReminders.id(CompanionSection.remember)
            ForEach(memories.active) { memory in
                MemoryRow(memory: memory, done: { model.complete(memory) }, delete: { model.delete(memory) })
            }
            ForEach(memories.completed) { memory in
                MemoryRow(memory: memory, done: nil, delete: { model.delete(memory) })
            }
        }
    }

    private var privateReminders: some View {
        let waiting = memories.active.count
        return SettingsRow("Private reminders",
                           "Say one with \(KeyChord.memoryCapture.symbols); it never leaves Utter. \(notifications.state.message)") {
            HStack(spacing: 10) {
                Text(waiting == 0 ? "none yet" : "\(waiting) waiting")
                    .font(Mixtape.mono(12))
                    .foregroundStyle(Mixtape.ink3)
                if !memories.memories.isEmpty {
                    Button { model.confirmingDeleteAll = true } label: {
                        Text("Delete all\u{2026}").foregroundStyle(Mixtape.red)
                    }
                    .buttonStyle(.pen(.ghost, .small))
                }
            }
        }
    }

    private var dailyTape: some View {
        let length = userData.companionDictationGoal
        let today = model.today
        return SettingsSection("Daily tape", detail: "your word goal") {
            SettingsRow("Tape length", length > 0 ? "\(model.wordsToday.formatted()) of \(length.formatted()) words today"
                                                  : "\(model.wordsToday.formatted()) words today") {
                pick("Tape length", \.companionDictationGoal, choices: [0, 250, 500, 1_000, 2_000, 3_000, 5_000, 10_000]) {
                    "\($0.formatted()) words"
                }
            }
            toggle("Daily goals", "Water, stretch and focus goals, and a cheer when you reach one", \.companionGoalsEnabled)
            if userData.companionGoalsEnabled {
                goal("Water breaks", \.companionHydrationGoal, done: today.hydration, choices: [2, 4, 6, 8, 10, 12])
                goal("Stretches", \.companionStretchGoal, done: today.stretches, choices: [1, 2, 3, 4, 5, 6, 8, 10])
                goal("Focus blocks", \.companionFocusGoal, done: today.focusBlocks, choices: [1, 2, 3, 4, 5, 6, 8])
            }
        }
    }

    private var focusTimer: some View {
        let focus = userData.companionPomodoroFocusMinutes
        let rest = userData.companionPomodoroBreakMinutes
        return SettingsRow("Focus timer", "Runs when focus and break are both set") {
            SettingsPick("Focus timer", value: focus == 0 || rest == 0 ? "off" : "\(focus) min, then \(rest)") {
                Section("Focus") {
                    picker("Focus", \.companionPomodoroFocusMinutes, choices: [0, 15, 20, 25, 30, 45, 50, 60, 90]) { "\($0) min" }
                }
                Section("Break") {
                    picker("Break", \.companionPomodoroBreakMinutes, choices: [0, 5, 10, 15, 20, 30]) { "\($0) min" }
                }
            }
        }
    }

    private func toggle(_ title: String, _ detail: String?, _ key: ReferenceWritableKeyPath<UserData, Bool>) -> some View {
        SettingsRow(title, detail) {
            Toggle(title, isOn: model.binding(key)).toggleStyle(.settingsSwitch)
        }
    }

    private func minutes(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, choices: [Int]) -> some View {
        SettingsRow(title) {
            pick(title, key, choices: choices + [0]) { "every \($0) min" }
        }
    }

    private func goal(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, done: Int, choices: [Int]) -> some View {
        let target = userData[keyPath: key]
        return SettingsRow(title, target == 0 ? nil : "\(done.formatted()) of \(target.formatted()) today") {
            pick(title, key, choices: choices + [0]) { "\($0.formatted()) a day" }
        }
    }

    private func pick(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, choices: [Int],
                      label: @escaping (Int) -> String) -> some View {
        let value = userData[keyPath: key]
        return SettingsPick(title, value: value == 0 ? "off" : label(value)) {
            picker(title, key, choices: choices, label: label)
        }
    }

    /// The common values; the stored one is always offered, so an odd one is never lost.
    private func picker(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, choices: [Int],
                        label: @escaping (Int) -> String) -> some View {
        let values = Set(choices + [userData[keyPath: key]]).sorted()
        return Picker(title, selection: model.binding(key)) {
            ForEach(values, id: \.self) { Text($0 == 0 ? "Off" : label($0)).tag($0) }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}

private struct MemoryRow: View {
    let memory: CompanionMemory
    let done: (() -> Void)?
    let delete: () -> Void

    var body: some View {
        let due = memory.isCompleted ? nil : memory.remindAt?.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        SettingsRow {
            HStack(spacing: 6) {
                Text(memory.text).foregroundStyle(memory.isCompleted ? Mixtape.ink3 : Mixtape.ink)
                if memory.isCompleted {
                    DrawnStroke(InkTick(), lineWidth: 1.8).frame(width: 12, height: 10).accessibilityLabel("Done")
                }
            }
            if let due {
                Text(due).font(Mixtape.mono(11.5)).foregroundStyle(Mixtape.ink3)
            }
        } trailing: {
            HStack(spacing: 4) {
                if let done {
                    Button("Done", action: done)
                        .buttonStyle(.pen(.ghost, .small))
                        .accessibilityLabel("Mark done: \(memory.text)")
                }
                Button(action: delete) { Image(systemName: "trash") }
                    .buttonStyle(.inkIcon)
                    .help("Delete")
                    .accessibilityLabel("Delete: \(memory.text)")
            }
        }
        .padding(.leading, 16)
    }
}

/// The robot as a SwiftUI view, for the Companion tab and Home. It naps after 30 s like the floating one,
/// and holds still unless its window is key.
struct RobotPreview: NSViewRepresentable {
    var state: RobotState = .idle
    var roundness: CGFloat = RobotGeometry.defaultRoundness

    @Environment(\.controlActiveState) private var activeState

    final class Coordinator {
        var state: RobotState?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> RobotView {
        let view = RobotView(frame: .zero)
        view.palette = .utter
        return view
    }

    func updateNSView(_ view: RobotView, context: Context) {
        if view.roundness != roundness { view.roundness = roundness }
        if activeState == .key { view.resume() } else { view.pause() }
        guard context.coordinator.state != state else { return }
        context.coordinator.state = state
        view.play(state)
    }
}
