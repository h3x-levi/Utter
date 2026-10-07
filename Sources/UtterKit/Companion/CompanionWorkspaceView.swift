import SwiftUI
import AppKit

enum CompanionSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case remember = "Remember"
    case rewards = "Rewards"
    case customize = "Customize"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "sparkles"
        case .remember: return "brain.head.profile"
        case .rewards: return "trophy"
        case .customize: return "slider.horizontal.3"
        }
    }
}

@MainActor
final class CompanionSectionSelection: ObservableObject {
    static let shared = CompanionSectionSelection()
    @Published var section: CompanionSection = .today
}

struct CompanionSettingsContent: View {
    @ObservedObject private var selection = CompanionSectionSelection.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            Picker("Companion section", selection: $selection.section) {
                ForEach(CompanionSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 620)
            .accessibilityLabel("Companion section")

            Group {
                switch selection.section {
                case .today: CompanionTodayView()
                case .remember: CompanionRememberView()
                case .rewards: CompanionRewardsView()
                case .customize: CompanionCustomizeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            _ = UserData.shared.syncCompanionLifetimeWords(
                TranscriptionHistory.shared.totalWords
            )
            CompanionMemoryStore.shared.restoreScheduledNotifications()
            await CompanionNotificationScheduler.shared.refreshState()
        }
    }
}

private struct CompanionTodayView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var memories = CompanionMemoryStore.shared
    @ObservedObject private var selection = CompanionSectionSelection.shared

    private var nextReward: CompanionReward? {
        CompanionReward.allCases.first {
            !userData.companionRewardUnlocked($0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.x5) {
                CompanionStageCard()

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 250), spacing: Space.groupGap),
                        GridItem(.flexible(minimum: 250), spacing: Space.groupGap),
                    ],
                    alignment: .leading,
                    spacing: Space.groupGap
                ) {
                SettingsCard(title: "Your companion") {
                    HStack(spacing: Space.x4) {
                        if let style = CodePixelCatStyle(rawValue: userData.companionCharacter) {
                            CodePixelCatView(
                                style: style,
                                mood: userData.companionEnabled ? .resting : .loaf,
                                pose: .neutral,
                                size: 44,
                                elapsed: 1.0
                            )
                            .frame(width: 44, height: 44)
                        } else {
                            CodePixelCatView(
                                style: .orange,
                                mood: userData.companionEnabled ? .resting : .loaf,
                                pose: .neutral,
                                size: 44,
                                elapsed: 1.0
                            )
                            .frame(width: 44, height: 44)
                        }
                        VStack(alignment: .leading, spacing: Space.x1) {
                            Text(userData.companionEnabled ? "Ready on your desktop" : "Taking a break")
                                .typo(.body)
                            Text(userData.companionEnabled
                                 ? "Dictate, complete goals, and check in to unlock natural rewards."
                                 : "Turn the companion on in Customize when you want it back.")
                                .typo(.caption)
                        }
                        Spacer()
                    }
                    HStack {
                        Button("Remember something") { selection.section = .remember }
                            .buttonStyle(.borderedProminent)
                        Button("Customize") { selection.section = .customize }
                            .buttonStyle(.bordered)
                    }
                }

                SettingsCard(title: "Next reward") {
                    if let reward = nextReward {
                        RewardProgress(
                            title: reward.title,
                            detail: reward.detail,
                            current: userData.companionProgress.lifetimeWords,
                            target: reward.wordRequirement
                        )
                        Button("See all rewards") { selection.section = .rewards }
                            .buttonStyle(.bordered)
                    } else {
                        Label("Every reward unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Tint.accent)
                        Text("\(userData.companionProgress.lifetimeWords.formatted()) words dictated")
                            .typo(.caption)
                    }
                }

                SettingsCard(title: "Remembered") {
                    if memories.active.isEmpty {
                        CompanionEmptyState(
                            title: "Nothing pending",
                            systemImage: "checkmark.circle",
                            detail: "Ask Utter to remember anything, with or without a reminder time."
                        )
                        .frame(minHeight: 120)
                    } else {
                        ForEach(memories.active.prefix(3)) { memory in
                            MemorySummaryRow(memory: memory)
                        }
                        Button("Open Remember") { selection.section = .remember }
                            .buttonStyle(.bordered)
                    }
                }

                SettingsCard(title: "Today’s goals") {
                    DailyProgressRow(
                        title: "Words",
                        value: userData.companionProgress.dictationWords,
                        target: userData.companionDictationGoal
                    )
                    DailyProgressRow(
                        title: "Water",
                        value: userData.companionProgress.hydration,
                        target: userData.companionHydrationGoal
                    )
                    DailyProgressRow(
                        title: "Stretch",
                        value: userData.companionProgress.stretches,
                        target: userData.companionStretchGoal
                    )
                    DailyProgressRow(
                        title: "Focus",
                        value: userData.companionProgress.focusBlocks,
                        target: userData.companionFocusGoal
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.pageInset)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
final class CompanionRememberViewModel: ObservableObject {
    @Published var input = ""
    @Published var proposal: CompanionMemoryProposal? = nil
    @Published var hasReminder = false
    @Published var isParsing = false
    @Published var errorMessage: String? = nil
    @Published var confirmDeleteAll = false

    func review() {
        errorMessage = nil
        isParsing = true
        Task {
            do {
                let parsed = try await CompanionMemoryParser.parse(input)
                await MainActor.run {
                    self.proposal = parsed
                    self.hasReminder = parsed.remindAt != nil
                    self.isParsing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isParsing = false
                }
            }
        }
    }

    func save(store: CompanionMemoryStore) {
        guard let proposal else { return }
        do {
            _ = try store.add(proposal: proposal, source: .typed)
            input = ""
            self.proposal = nil
            hasReminder = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CompanionRememberView: View {
    @ObservedObject private var store = CompanionMemoryStore.shared
    @ObservedObject private var notifications = CompanionNotificationScheduler.shared
    @StateObject private var model = CompanionRememberViewModel()

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Space.groupGap) {
                    composer.frame(minWidth: 360)
                    memoryList.frame(minWidth: 360)
                }
                VStack(alignment: .leading, spacing: Space.groupGap) {
                    composer
                    memoryList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.pageInset)
        }
        .alert("Delete all memories?", isPresented: $model.confirmDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { store.deleteAll() }
        } message: {
            Text("This permanently removes every saved memory and cancels its reminder.")
        }
    }

    private var composer: some View {
        SettingsCard(title: "Ask Utter to remember") {
            Text("Type naturally, for example: “Remind me to send the proposal tomorrow at 9.” Apple Intelligence runs on this Mac when available; a system date parser is the fallback.")
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)

            GlassTextEditor(text: $model.input, minHeight: 110)
                .accessibilityLabel("What should Utter remember?")

            HStack {
                Button {
                    AppDelegate.current?.toggleMemoryCapture()
                } label: {
                    Label("Speak", systemImage: "mic")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Review") { model.review() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isParsing || model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.isParsing {
                ProgressView("Understanding…")
                    .controlSize(.small)
            }

            if let proposal = model.proposal {
                Divider()
                Text("Review before saving").typo(.body)
                TextField(
                    "Memory",
                    text: Binding(
                        get: { proposal.text },
                        set: { model.proposal?.text = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Toggle("Remind me", isOn: $model.hasReminder)
                    .onChange(of: model.hasReminder) { enabled in
                        if enabled, model.proposal?.remindAt == nil {
                            model.proposal?.remindAt = Calendar.current.date(
                                byAdding: .hour, value: 1, to: Date()
                            )
                        } else if !enabled {
                            model.proposal?.remindAt = nil
                        }
                    }

                if model.hasReminder {
                    DatePicker(
                        "When",
                        selection: Binding(
                            get: { model.proposal?.remindAt ?? Date().addingTimeInterval(3_600) },
                            set: { model.proposal?.remindAt = $0 }
                        ),
                        in: Date().addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                HStack {
                    Button("Cancel") {
                        model.proposal = nil
                        model.hasReminder = false
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Save memory") { model.save(store: store) }
                        .buttonStyle(.borderedProminent)
                }
            }

            if let visibleError = model.errorMessage ?? store.lastError {
                Label(visibleError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tint.danger)
                    .typo(.caption)
            }

            Divider()
            Label(notifications.state.message, systemImage: notificationSymbol)
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text("Private by default: memories and reminder times are stored only in Utter’s Application Support folder on this Mac. You can edit or delete each one below.")
                .typo(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if !store.memories.isEmpty {
                Button("Delete all memories", role: .destructive) {
                    model.confirmDeleteAll = true
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var memoryList: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            SettingsCard(title: "Pending") {
                if store.active.isEmpty {
                    CompanionEmptyState(
                        title: "No memories yet",
                        systemImage: "brain",
                        detail: "Saved memories and reminders appear here."
                    )
                    .frame(minHeight: 160)
                } else {
                    ForEach(store.active) { memory in
                        MemoryRow(memory: memory)
                        if memory.id != store.active.last?.id { Divider() }
                    }
                }
            }

            if !store.completed.isEmpty {
                SettingsCard(title: "Completed") {
                    ForEach(store.completed.prefix(8)) { memory in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Tint.accent)
                            Text(memory.text).lineLimit(2)
                            Spacer()
                            Button("Delete") { store.delete(id: memory.id) }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }

    private var notificationSymbol: String {
        switch notifications.state {
        case .authorized: return "bell.badge.fill"
        case .denied, .failed: return "bell.slash.fill"
        case .unknown: return "bell"
        }
    }
}

private struct CompanionRewardsView: View {
    @ObservedObject private var userData = UserData.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.groupGap) {
                SettingsCard(title: "Progress") {
                    let unlocked = CompanionReward.allCases.filter(userData.companionRewardUnlocked)
                    HStack(alignment: .firstTextBaseline) {
                        Text(userData.companionProgress.lifetimeWords.formatted())
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                        Text("words dictated").typo(.caption)
                        Spacer()
                        Text("\(unlocked.count) of \(CompanionReward.allCases.count) unlocked")
                            .typo(.caption)
                    }
                    Text("Rewards are earned through ordinary use. There are no purchases, loot boxes, streak penalties, or expiring items.")
                        .typo(.caption)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 220), spacing: Space.groupGap),
                    ],
                    alignment: .leading,
                    spacing: Space.groupGap
                ) {
                    ForEach(CompanionReward.allCases) { reward in
                        RewardTile(
                            reward: reward,
                            unlocked: userData.companionRewardUnlocked(reward),
                            words: userData.companionProgress.lifetimeWords
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Space.pageInset)
        }
    }
}

@MainActor
final class MemoryRowModel: ObservableObject {
    @Published var isEditing = false
    @Published var draft = ""
    @Published var hasReminder = false
    @Published var reminder = Date().addingTimeInterval(3_600)
    @Published var errorMessage: String? = nil

    func beginEdit(memory: CompanionMemory) {
        draft = memory.text
        hasReminder = memory.remindAt != nil
        reminder = memory.remindAt ?? Date().addingTimeInterval(3_600)
        errorMessage = nil
        isEditing = true
    }

    func saveEdit(memory: CompanionMemory, store: CompanionMemoryStore) {
        var updated = memory
        updated.text = draft
        updated.remindAt = hasReminder ? reminder : nil
        do {
            try store.update(updated)
            errorMessage = nil
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MemoryRow: View {
    let memory: CompanionMemory
    @ObservedObject private var store = CompanionMemoryStore.shared
    @StateObject private var model = MemoryRowModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            if model.isEditing {
                TextField("Memory", text: $model.draft)
                    .textFieldStyle(.roundedBorder)
                Toggle("Remind me", isOn: $model.hasReminder)
                if model.hasReminder {
                    DatePicker(
                        "When",
                        selection: $model.reminder,
                        in: Date().addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                HStack {
                    Button("Cancel") { model.isEditing = false }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save") { model.saveEdit(memory: memory, store: store) }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Space.x1) {
                        Text(memory.text).typo(.body)
                        HStack(spacing: Space.x2) {
                            Label(memory.source.label, systemImage: memory.source == .spoken ? "mic" : "keyboard")
                            if let remindAt = memory.remindAt {
                                Label(
                                    remindAt.formatted(date: .abbreviated, time: .shortened),
                                    systemImage: "bell"
                                )
                            } else {
                                Label("No reminder", systemImage: "brain")
                            }
                        }
                        .typo(.caption)
                    }
                    Spacer()
                    Menu {
                        Button("Edit") { model.beginEdit(memory: memory) }
                        Button("Done") { store.complete(id: memory.id) }
                        if memory.remindAt != nil {
                            Button("Snooze 10 minutes") { store.snooze(id: memory.id) }
                        }
                        Divider()
                        Button("Delete", role: .destructive) { store.delete(id: memory.id) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityLabel("Actions for \(memory.text)")
                }
                Button("Done") { store.complete(id: memory.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tint.danger)
                    .typo(.caption)
            }
        }
    }
}

private struct MemorySummaryRow: View {
    let memory: CompanionMemory

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: memory.remindAt == nil ? "brain" : "bell")
                .foregroundStyle(Tint.accent)
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(memory.text).lineLimit(1)
                if let date = memory.remindAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .typo(.caption)
                }
            }
            Spacer()
        }
    }
}

private struct DailyProgressRow: View {
    let title: String
    let value: Int
    let target: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(target == 0 ? "Off" : "\(min(value, target)) / \(target)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        if target > 0 {
            ProgressView(value: Double(min(value, target)), total: Double(target))
                .accessibilityLabel(title)
                .accessibilityValue("\(value) of \(target)")
        }
    }
}

private struct RewardProgress: View {
    let title: String
    let detail: String
    let current: Int
    let target: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(title).typo(.body)
                Text("\(detail) · \(target.formatted()) words").typo(.caption)
            }
            Spacer()
            Text("\(min(current, target).formatted()) / \(target.formatted())")
                .typo(.caption)
                .monospacedDigit()
        }
        ProgressView(value: Double(min(current, target)), total: Double(target))
    }
}

private struct RewardTile: View {
    let reward: CompanionReward
    let unlocked: Bool
    let words: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            HStack {
                Image(systemName: reward.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(unlocked ? Tint.accent : Ink.secondary)
                Spacer()
                Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(unlocked ? Tint.accent : Ink.secondary)
            }
            Text(reward.title).typo(.body)
            Text(unlocked
                 ? "\(reward.detail) · Unlocked"
                 : "\(reward.detail) · \(reward.wordRequirement.formatted()) words")
                .typo(.caption)
            if !unlocked {
                ProgressView(
                    value: Double(min(words, reward.wordRequirement)),
                    total: Double(reward.wordRequirement)
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .card()
        .accessibilityElement(children: .combine)
    }
}

private struct CompanionEmptyState: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        VStack(spacing: Space.x3) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(Ink.secondary)
            Text(title).typo(.body)
            Text(detail)
                .typo(.caption)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Interactive Companion Stage & Mood Card

@MainActor
private final class CompanionStageCardModel: ObservableObject {
    @Published var activeToyAction: String?
    @Published var activeMood: CompanionMood = .resting

    func triggerToy(_ actionText: String, sound: Bool, userData: UserData) {
        withAnimation {
            activeToyAction = actionText
            activeMood = actionText.contains("nap") ? .sleepy : .delighted
        }
        if sound && userData.companionSounds {
            SoundPlayer.playDone()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation {
                self?.activeToyAction = nil
                self?.activeMood = .resting
            }
        }
    }
}

private struct CompanionStageCard: View {
    @ObservedObject private var userData = UserData.shared
    @StateObject private var model = CompanionStageCardModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            HStack(alignment: .center, spacing: Space.x4) {
                cat(mood: userData.companionEnabled ? model.activeMood : .loaf)
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Space.x1) {
                    Text(userData.companionEnabled ? "Here with you" : "Taking a break")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text(model.activeToyAction ?? "A small companion for the quiet moments at your desk.")
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(userData.companionEnabled ? "On your desktop" : "Paused", systemImage: "circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(userData.companionEnabled ? Tint.success : Ink.secondary)
                        .labelStyle(.titleAndIcon)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Space.x2) {
                Button {
                    model.triggerToy("Your companion is enjoying a little play break.", sound: false, userData: userData)
                } label: {
                    Label("Play", systemImage: "sparkle")
                }
                .buttonStyle(.bordered)
                .disabled(!userData.companionEnabled)

                Button {
                    model.triggerToy("Your companion is settling in for a nap.", sound: false, userData: userData)
                } label: {
                    Label("Rest", systemImage: "moon.zzz")
                }
                .buttonStyle(.bordered)
                .disabled(!userData.companionEnabled)

                Spacer()
                Text("No streaks or decay")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
            }
        }
        .padding(.vertical, Space.x2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func cat(mood: CompanionMood) -> some View {
        if let style = CodePixelCatStyle(rawValue: userData.companionCharacter) {
            CodePixelCatView(style: style, mood: mood, pose: .neutral, size: 80, elapsed: 1.0)
        } else {
            CodePixelCatView(style: .orange, mood: mood, pose: .neutral, size: 80, elapsed: 1.0)
        }
    }
}
