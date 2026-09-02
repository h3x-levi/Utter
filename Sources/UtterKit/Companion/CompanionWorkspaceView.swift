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
            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 280), spacing: Space.groupGap),
                    GridItem(.flexible(minimum: 280), spacing: Space.groupGap),
                ],
                alignment: .leading,
                spacing: Space.groupGap
            ) {
                SettingsCard(title: "Your companion") {
                    HStack(spacing: Space.x4) {
                        Image(systemName: userData.companionEnabled
                              ? "figure.wave.circle.fill" : "moon.zzz")
                            .font(.system(size: 38))
                            .foregroundStyle(userData.companionEnabled ? Tint.accent : Ink.secondary)
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
    }
}

private struct CompanionRememberView: View {
    @ObservedObject private var store = CompanionMemoryStore.shared
    @ObservedObject private var notifications = CompanionNotificationScheduler.shared
    @State private var input = ""
    @State private var proposal: CompanionMemoryProposal?
    @State private var hasReminder = false
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var confirmDeleteAll = false

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
        .alert("Delete all memories?", isPresented: $confirmDeleteAll) {
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

            GlassTextEditor(text: $input, minHeight: 110)
                .accessibilityLabel("What should Utter remember?")

            HStack {
                Button {
                    AppDelegate.current?.toggleMemoryCapture()
                } label: {
                    Label("Speak", systemImage: "mic")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Review") { review() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isParsing || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if isParsing {
                ProgressView("Understanding…")
                    .controlSize(.small)
            }

            if let proposal {
                Divider()
                Text("Review before saving").typo(.body)
                TextField(
                    "Memory",
                    text: Binding(
                        get: { proposal.text },
                        set: { self.proposal?.text = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Toggle("Remind me", isOn: $hasReminder)
                    .onChange(of: hasReminder) { enabled in
                        if enabled, self.proposal?.remindAt == nil {
                            self.proposal?.remindAt = Calendar.current.date(
                                byAdding: .hour, value: 1, to: Date()
                            )
                        } else if !enabled {
                            self.proposal?.remindAt = nil
                        }
                    }

                if hasReminder {
                    DatePicker(
                        "When",
                        selection: Binding(
                            get: { self.proposal?.remindAt ?? Date().addingTimeInterval(3_600) },
                            set: { self.proposal?.remindAt = $0 }
                        ),
                        in: Date().addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                HStack {
                    Button("Cancel") {
                        self.proposal = nil
                        hasReminder = false
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Save memory") { save() }
                        .buttonStyle(.borderedProminent)
                }
            }

            if let visibleError = errorMessage ?? store.lastError {
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
                    confirmDeleteAll = true
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

    private func review() {
        errorMessage = nil
        isParsing = true
        Task {
            do {
                let parsed = try await CompanionMemoryParser.parse(input)
                await MainActor.run {
                    proposal = parsed
                    hasReminder = parsed.remindAt != nil
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isParsing = false
                }
            }
        }
    }

    private func save() {
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

private struct MemoryRow: View {
    let memory: CompanionMemory
    @ObservedObject private var store = CompanionMemoryStore.shared
    @State private var isEditing = false
    @State private var draft = ""
    @State private var hasReminder = false
    @State private var reminder = Date().addingTimeInterval(3_600)
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            if isEditing {
                TextField("Memory", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Toggle("Remind me", isOn: $hasReminder)
                if hasReminder {
                    DatePicker(
                        "When",
                        selection: $reminder,
                        in: Date().addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                HStack {
                    Button("Cancel") { isEditing = false }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Save") { saveEdit() }
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
                        Button("Edit") { beginEdit() }
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
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tint.danger)
                    .typo(.caption)
            }
        }
    }

    private func beginEdit() {
        draft = memory.text
        hasReminder = memory.remindAt != nil
        reminder = memory.remindAt ?? Date().addingTimeInterval(3_600)
        errorMessage = nil
        isEditing = true
    }

    private func saveEdit() {
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
