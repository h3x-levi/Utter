import Observation
import SwiftUI
import UtterCore

/// Where a deep link into the Companion section should land.
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
final class CompanionScreenModel {
    let userData: UserData
    let memories: CompanionMemoryStore
    let notifications: CompanionNotificationScheduler
    let selection: CompanionSectionSelection

    var confirmingDeleteAll = false
    var roundness: Double {
        didSet { defaults.companionHeadRoundness = roundness }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(userData: UserData = .shared,
         memories: CompanionMemoryStore? = nil,
         notifications: CompanionNotificationScheduler? = nil,
         selection: CompanionSectionSelection? = nil,
         defaults: UserDefaults = .standard) {
        self.userData = userData
        self.memories = memories ?? .shared
        self.notifications = notifications ?? .shared
        self.selection = selection ?? .shared
        self.defaults = defaults
        roundness = defaults.companionHeadRoundness
    }

    /// Today's goal progress; a stored day that is not today counts as nothing done yet.
    var today: CompanionProgress {
        let progress = userData.companionProgress
        return progress.day == CompanionProgress.dayStamp(Date()) ? progress : .today()
    }

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

/// The main window's Companion section: the robot, its reminders and goals, and what it remembers.
struct CompanionScreen: View {
    @State private var model: CompanionScreenModel
    @ObservedObject private var userData: UserData
    @ObservedObject private var memories: CompanionMemoryStore
    @ObservedObject private var notifications: CompanionNotificationScheduler
    @ObservedObject private var selection: CompanionSectionSelection

    init(model: CompanionScreenModel? = nil) {
        let model = model ?? CompanionScreenModel()
        _model = State(initialValue: model)
        userData = model.userData
        memories = model.memories
        notifications = model.notifications
        selection = model.selection
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A small friend that floats beside the pill, listens with you and keeps your reminders.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 560, alignment: .leading)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) { stage; robotOptions }
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 16) { stage; robotOptions }
                    }
                    reminders
                    goals
                    remember.id(CompanionSection.remember)
                    if !memories.completed.isEmpty { done }
                }
                .toggleStyle(.switch)
                .contentEdge()
            }
            .contentScrollEdge()
            .tint(Look.Color.tint)
            .confirmationDialog("Delete all memories?", isPresented: $model.confirmingDeleteAll) {
                Button("Delete All", role: .destructive) { model.deleteAll() }
            } message: {
                Text("This removes every saved memory and cancels its reminder.")
            }
            .onAppear { scrollIfAsked(proxy) }
            .onChange(of: selection.section) { _, _ in scrollIfAsked(proxy) }
            .task { await notifications.refreshState() }
        }
    }

    private var stage: some View {
        RobotPreview(roundness: model.roundness)
            .frame(width: 150, height: 150)
            .frame(width: 330, height: 300)
            .cardBackground()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your companion")
    }

    private var robotOptions: some View {
        VStack(spacing: 0) {
            OptionRow("Show on desktop", subtitle: "Floats near the pill") {
                Toggle("Show on desktop", isOn: model.binding(\.companionEnabled)).labelsHidden()
            }
            RowRule()
            OptionRow("Size") {
                LensPicker(selection: model.binding(\.companionSize), options: CompanionSize.allCases, title: \.label)
                    .accessibilityLabel("Size")
            }
            RowRule()
            OptionRow("Head shape", subtitle: "Square to round") {
                Slider(value: $model.roundness, in: 0...100)
                    .controlSize(.small)
                    .frame(width: 150)
                    .accessibilityLabel("Head shape")
            }
            RowRule()
            OptionRow("Quiet mode", subtitle: "Sleeps and holds its reminders") {
                Toggle("Quiet mode", isOn: model.binding(\.companionQuietMode)).labelsHidden()
            }
            RowRule()
            OptionRow("Go quiet automatically", subtitle: "While you share your screen or record a meeting") {
                Toggle("Go quiet while screen sharing or recording a meeting",
                       isOn: model.binding(\.companionAutomaticQuietMode)).labelsHidden()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentCard()
    }

    private var reminders: some View {
        VStack(spacing: 0) {
            CardHeader("Reminders", subtitle: "Right-click your companion to mark a reminder done.")
            minutes("Stretch", \.companionStretchMinutes, repeats: true, choices: [15, 20, 30, 45, 60, 90, 120])
            RowRule()
            minutes("Water", \.companionWaterMinutes, repeats: true, choices: [15, 20, 30, 45, 60, 90, 120])
            RowRule()
            minutes("Focus", \.companionPomodoroFocusMinutes, repeats: false, choices: [15, 20, 25, 30, 45, 50, 60, 90],
                    subtitle: "The timer runs when Focus and Break are both set")
            RowRule()
            minutes("Break", \.companionPomodoroBreakMinutes, repeats: false, choices: [5, 10, 15, 20, 30])
            RowRule()
            OptionRow("Reminder sound") {
                Toggle("Reminder sound", isOn: model.binding(\.companionSounds)).labelsHidden()
            }
            RowRule()
            OptionRow("Your name", subtitle: "Used when it reminds you") {
                TextField("Your name", text: model.binding(\.companionUserName), prompt: Text("Optional"))
                    .fieldBox()
                    .frame(width: 220)
            }
            RowRule()
            OptionRow("Pinned note", subtitle: "Shown beside your companion") {
                TextField("Pinned note", text: model.binding(\.companionPinnedMessage), prompt: Text("Nothing pinned"))
                    .fieldBox()
                    .frame(width: 260)
            }
        }
        .contentCard()
    }

    private var goals: some View {
        VStack(spacing: 0) {
            CardHeader("Daily goals") {
                Toggle("Daily goals", isOn: model.binding(\.companionGoalsEnabled)).labelsHidden()
            }
            if userData.companionGoalsEnabled {
                let today = model.today
                goal("Words dictated", \.companionDictationGoal, done: today.dictationWords,
                     choices: [250, 500, 1_000, 2_000, 3_000, 5_000, 10_000])
                RowRule()
                goal("Water breaks", \.companionHydrationGoal, done: today.hydration, choices: [2, 4, 6, 8, 10, 12])
                RowRule()
                goal("Stretches", \.companionStretchGoal, done: today.stretches, choices: [1, 2, 3, 4, 5, 6, 8, 10])
                RowRule()
                goal("Focus blocks", \.companionFocusGoal, done: today.focusBlocks, choices: [1, 2, 3, 4, 5, 6, 8])
            }
        }
        .contentCard()
    }

    private var remember: some View {
        VStack(spacing: 0) {
            CardHeader("Remember", subtitle: "\(notifications.state.message) Memories stay on this Mac.") {
                if !memories.memories.isEmpty {
                    Button(role: .destructive) { model.confirmingDeleteAll = true } label: {
                        Text("Delete All\u{2026}").foregroundStyle(.red)
                    }
                        .buttonStyle(Look.ActionStyle())
                }
            }
            if memories.active.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    LivingMark(tint: .secondary).frame(width: 28, height: 20).padding(.top, 12)
                    EmptyNote(title: "Nothing to remember yet",
                              message: "Press \u{2303}\u{2325}R and say what to remember, like \u{201C}remind me to call Sam at 4.\u{201D}")
                }
                .padding(.leading, 12)
            }
            ForEach(memories.active) { memory in
                if memory.id != memories.active.first?.id { RowRule() }
                CompanionMemoryRow(memory: memory, done: { model.complete(memory) }, delete: { model.delete(memory) })
            }
        }
        .contentCard()
    }

    private var done: some View {
        VStack(spacing: 0) {
            CardHeader("Done")
            ForEach(memories.completed) { memory in
                if memory.id != memories.completed.first?.id { RowRule() }
                CompanionMemoryRow(memory: memory, done: nil, delete: { model.delete(memory) })
            }
        }
        .contentCard()
    }

    private func minutes(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, repeats: Bool,
                         choices: [Int], subtitle: String? = nil) -> some View {
        OptionRow(title, subtitle: subtitle) {
            menu(title, key, choices: choices) { $0 == 0 ? "Off" : repeats ? "Every \($0) min" : "\($0) min" }
        }
    }

    private func goal(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, done: Int, choices: [Int]) -> some View {
        let target = userData[keyPath: key]
        return OptionRow(title, subtitle: target == 0 ? nil : "\(done.formatted()) of \(target.formatted()) today") {
            menu(title, key, choices: choices) { $0 == 0 ? "Off" : "\($0.formatted()) a day" }
        }
    }

    /// A compact menu of common values; the stored value is always offered, so an odd one is never lost.
    private func menu(_ title: String, _ key: ReferenceWritableKeyPath<UserData, Int>, choices: [Int],
                      label: @escaping (Int) -> String) -> some View {
        let values = Set(choices + [0, userData[keyPath: key]]).sorted()
        return Picker(title, selection: model.binding(key)) {
            ForEach(values, id: \.self) { Text(label($0)).monospacedDigit().tag($0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }

    private func scrollIfAsked(_ proxy: ScrollViewProxy) {
        guard selection.section == .remember else { return }
        withAnimation { proxy.scrollTo(CompanionSection.remember, anchor: .top) }
        selection.section = .companion
    }
}

private struct CompanionMemoryRow: View {
    let memory: CompanionMemory
    let done: (() -> Void)?
    let delete: () -> Void

    var body: some View {
        let due = memory.isCompleted ? nil : memory.remindAt?.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        OptionRow(memory.text, subtitle: due) {
            HStack(spacing: 6) {
                if let done {
                    Button("Done", action: done)
                        .buttonStyle(Look.ActionStyle())
                        .accessibilityLabel("Mark done: \(memory.text)")
                }
                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash").frame(width: 26, height: 26)
                }
                .buttonStyle(Look.RowStyle(radius: 8, scale: Look.Press.button))
                .help("Delete")
                .accessibilityLabel("Delete: \(memory.text)")
            }
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(memory.isCompleted ? .secondary : .primary)
    }
}

/// The robot as a SwiftUI view, for the Companion screen and Home. It naps after 30 s like the floating one,
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
