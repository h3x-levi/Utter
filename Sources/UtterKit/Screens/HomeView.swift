import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import ApplicationServices

@MainActor
private final class HomeViewModel: ObservableObject {
    @Published var searchText = ""
}

struct HomeView: View {
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var userData = UserData.shared
    @StateObject private var model = HomeViewModel()

    private static let searchWidth: CGFloat = 196

    private var filteredGroups: [HistoryGroup] {
        let groups = history.groupedByDate
        if model.searchText.isEmpty { return groups }
        return groups.compactMap { group in
            let filtered = group.entries.filter {
                $0.text.localizedCaseInsensitiveContains(model.searchText)
            }
            return filtered.isEmpty ? nil : HistoryGroup(id: group.id, label: group.label, entries: filtered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            BentoRow(columns: 4) {
                BentoStat(
                    value: history.totalWords.formatted(),
                    label: "Words Dictated",
                    systemImage: "mic",
                    tint: Tint.accent
                )
                BentoStat(
                    value: history.averageWPM,
                    label: "Avg Speed",
                    systemImage: "speedometer",
                    tint: Color.cyan
                )
                BentoStat(
                    value: history.entries.count.formatted(),
                    label: "Dictations",
                    systemImage: "waveform",
                    tint: Color.purple
                )
                BentoStat(
                    value: history.streakDays > 0 ? "\(history.streakDays) Days" : "\u{2014}",
                    label: "Day Streak",
                    systemImage: "flame",
                    tint: Color.orange
                )
            }

            // 7-Day Dictation Activity Bar Chart
            WeeklyActivityChart()

            // Readiness — a wide tile, since every row is live state.
            ReadyPanel(transcriptionCount: history.entries.count)

            // History tile, with search and export in its header.
            BentoTile(
                title: "History",
                systemImage: "clock.arrow.circlepath",
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
                        // `GlassTextField`, not a hand-rolled well — and it is now a
                        // real `TextField` with `.textFieldStyle(.roundedBorder)`
                        // inside, so the focus ring this screen used to lack comes
                        // from AppKit. That gap was an accessibility defect, not
                        // drift: a keyboard user tabbing into the search field on the
                        // app's landing screen got no indication that they had.
                        GlassTextField(
                            placeholder: "Search",
                            text: $model.searchText,
                            systemImage: "magnifyingglass"
                        )
                        .frame(width: Self.searchWidth)

                        Menu {
                            Button("Markdown") { exportHistory(format: .markdown) }
                            Button("Comma-separated values") { exportHistory(format: .csv) }
                            Button("Plain text") { exportHistory(format: .text) }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Ink.secondary)
                        }
                        .menuStyle(.button)
                        .buttonStyle(.bordered)
                        .menuIndicator(.hidden)
                        .disabled(history.entries.isEmpty)
                        .help("Export history")
                        .accessibilityLabel("Export history")
                    }
                )
            ) {
                if history.entries.isEmpty {
                    EmptyStateView(
                        icon: "waveform",
                        title: "Nothing dictated yet",
                        message: "Hold \(userData.hotkeyName) anywhere in macOS and start talking. "
                            + "What you say gets typed into whatever app you\u{2019}re using."
                    )
                } else if filteredGroups.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No matches for \u{201C}\(model.searchText)\u{201D}",
                        message: "Try a shorter phrase, or a single word.",
                        actionLabel: "Clear search",
                        action: { model.searchText = "" }
                    )
                } else {
                    // `LazyVStack`, not `VStack`: history is unbounded (300+ entries
                    // on this machine after a fortnight) and a plain VStack builds
                    // and measures every row on every scroll frame, which is what
                    // made trackpad scrolling stutter while dragging the scrollbar —
                    // which only moves the clip rect — stayed smooth.
                    LazyVStack(alignment: .leading, spacing: Space.x3) {
                        ForEach(filteredGroups) { group in
                            // Inner stack stays eager: a day's entries are few, and
                            // nesting lazy containers costs more than it saves.
                            VStack(alignment: .leading, spacing: Space.x1) {
                                // A real `Section` (macOS 10.15), so the day header and
                                // the rows it labels are one construct rather than two
                                // siblings that happen to be adjacent in a stack.
                                //
                                // Be precise about what this buys, because outside a
                                // `List` it is less than it looks: a `Section` in a
                                // plain stack renders header-then-content in order and
                                // adds no VoiceOver grouping — the `.isHeader` trait
                                // still comes from `SectionHeader` itself. What it does
                                // buy is that the grouping is now stated in the
                                // framework's own vocabulary, so if the history ever
                                // becomes a real `List` the rows are already shaped for
                                // it. That move is blocked from here: this view is
                                // inside `FlowMainView`'s `ScrollView`, and a `List`
                                // (itself a scroll container) nested in one either
                                // collapses or scrolls twice.
                                //
                                // The `Section` is inside the per-group `VStack` rather
                                // than a direct child of the `LazyVStack` on purpose.
                                // A lazy stack flattens a section's header and content
                                // into its own layout, so hoisting it would apply
                                // `Space.x3` (12pt) between every row in a day instead
                                // of `Space.x1` (4pt) — tripling the height of a
                                // 300-row list and putting the day header as far from
                                // its first row as the days are from each other. Nested
                                // this way the geometry is unchanged. The cost is that
                                // `pinnedViews: [.sectionHeaders]` (sticky date
                                // headers) is off the table, which nobody asked for and
                                // which would need an opaque backing on the header to
                                // be legible over scrolling text.
                                Section {
                                    ForEach(group.entries) { entry in
                                        HistoryRow(entry: entry, onDelete: {
                                            history.delete(entry: entry)
                                        })
                                    }
                                } header: {
                                    SectionHeader(title: group.label)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Ink.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 27)
    }

    // MARK: - Export

    private enum ExportFormat { case markdown, csv, text }

    private func exportHistory(format: ExportFormat) {
        let entries = history.entries
        guard !entries.isEmpty else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var content: String
        var ext: String
        var contentType: UTType

        switch format {
        case .markdown:
            ext = "md"
            // UTType.markdown isn't available on macOS 13; resolve by extension
            // so the save panel doesn't coerce the filename to .txt.
            contentType = UTType(filenameExtension: "md") ?? .plainText
            content = entries
                .map { "**\(fmt.string(from: $0.timestamp))** — \($0.text)" }
                .joined(separator: "\n\n---\n\n")
        case .csv:
            ext = "csv"
            contentType = .commaSeparatedText
            var lines = ["Timestamp,Words,Text"]
            for entry in entries {
                let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"")
                lines.append("\"\(fmt.string(from: entry.timestamp))\",\(entry.wordCount),\"\(escaped)\"")
            }
            content = lines.joined(separator: "\n")
        case .text:
            ext = "txt"
            contentType = .plainText
            content = entries
                .map { "[\(fmt.string(from: $0.timestamp))]\n\($0.text)" }
                .joined(separator: "\n\n")
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "utter-history.\(ext)"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                // Surface the failure instead of silently doing nothing.
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Couldn’t save the export"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
}

// MARK: - Ready panel

@MainActor
private final class ReadyPanelModel: ObservableObject {
    @Published var expanded = true
}

struct ReadyPanel: View {
    let transcriptionCount: Int

    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var readiness = ReadinessMonitor.shared
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var model = ReadyPanelModel()

    private var collapseCurve: Animation {
        motion.reduceMotion ? Motion.reduced : Motion.layout
    }

    private var micGranted: Bool { readiness.micGranted }
    private var axGranted: Bool { readiness.axGranted }
    private var modelPresent: Bool { readiness.modelPresent }
    private var aiState: LocalAIEngine.Availability { readiness.aiState }

    private var allReady: Bool {
        micGranted && axGranted && modelPresent && readiness.modelLoad == .ready
    }

    private var modelValue: String {
        switch readiness.modelLoad {
        case .loading, .idle:
            return modelPresent ? "Loading\u{2026}" : "Missing"
        case .ready:
            return "Whisper small \u{00B7} ready"
        case .failed:
            return "Failed to load"
        }
    }

    private var modelState: StatusRow.State {
        switch readiness.modelLoad {
        case .ready: return .ok
        case .loading, .idle: return modelPresent ? .neutral : .attention
        case .failed: return .attention
        }
    }

    private var isPreparing: Bool {
        readiness.modelLoad == .loading || readiness.modelLoad == .idle
    }

    private var shouldCollapse: Bool { allReady && transcriptionCount >= 5 }

    private var disclosure: Binding<Bool> {
        Binding(
            get: { model.expanded },
            set: { open in withAnimation(collapseCurve) { model.expanded = open } }
        )
    }

    var body: some View {
        BentoTile(title: nil) {
            if shouldCollapse {
                DisclosureGroup(isExpanded: disclosure) {
                    panelContent
                } label: {
                    if model.expanded { heading } else { summary }
                }
            } else {
                VStack(alignment: .leading, spacing: Space.x3) {
                    heading
                    panelContent
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            readiness.startPolling()
            model.expanded = !shouldCollapse
        }
        .onDisappear { readiness.stopPolling() }
    }

    @ViewBuilder
    private var heading: some View {
        HStack(spacing: Space.x2) {
            if isPreparing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, Space.x1)
                Text("Getting ready\u{2026}").typo(.heading)
            } else {
                Text("Hold").typo(.heading)
                Keycap(key: userData.hotkeyName)
                Text("to dictate").typo(.heading)
            }
            Spacer()
        }
    }

    private var summary: some View {
        HStack(spacing: Space.x2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tint.success)
            Text("Everything ready").typo(.body)
            Text("Hold").typo(.caption)
            Keycap(key: userData.hotkeyName)
            Text("to dictate").typo(.caption)
            Spacer()
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            HairlineDivider()

            StatusRow(
                label: "Microphone",
                value: micGranted ? "Allowed" : "Not allowed",
                state: micGranted ? .ok : .attention,
                actionLabel: micGranted ? nil : "Grant",
                action: micGranted ? nil : { openPane("Privacy_Microphone") }
            )
            StatusRow(
                label: "Accessibility",
                value: axGranted ? "Allowed" : "Not allowed",
                state: axGranted ? .ok : .attention,
                actionLabel: axGranted ? nil : "Grant",
                action: axGranted ? nil : { openPane("Privacy_Accessibility") }
            )
            StatusRow(
                label: "Speech model",
                value: modelValue,
                state: modelState
            )
            StatusRow(
                label: "AI commands",
                value: aiState.isReady ? "On-device" : "Unavailable",
                state: aiState.isReady ? .ok : .neutral
            )
            StatusRow(label: "Network", value: "Never used", state: .ok)
        }
    }

    private func openPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - History row

private struct HoverTextSelection: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.textSelection(.enabled) } else { content.textSelection(.disabled) }
    }
}

@MainActor
private final class HistoryRowModel: ObservableObject {
    @Published var isHovering = false
    @Published var copied = false
    @Published var expanded = false

    func copy(text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copied = false
        }
    }
}

struct HistoryRow: View {
    let entry: TranscriptionEntry
    var onDelete: () -> Void = {}

    @StateObject private var model = HistoryRowModel()
    @FocusState private var isFocused: Bool
    @ObservedObject private var motion = MotionPreference.shared

    private var isTruncatable: Bool { entry.text.count > 160 }

    var body: some View {
        HStack(alignment: .top, spacing: Space.x3) {
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .typo(.timestamp)
                .frame(width: 72, alignment: .trailing)

            VStack(alignment: .leading, spacing: Space.x1) {
                Text(entry.text)
                    .typo(.transcript)
                    .lineLimit(model.expanded ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(HoverTextSelection(active: model.isHovering || isFocused))

                HStack(spacing: Space.x2) {
                    if isTruncatable {
                        Button(model.expanded ? "Show less" : "Show more") {
                            withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                                model.expanded.toggle()
                            }
                        }
                        .buttonStyle(.plain)
                        .typo(.caption, ink: Tint.accentText)
                    }
                    if !entry.language.isEmpty {
                        Text(entry.language).typo(.caption)
                    }
                }
            }

            HStack(spacing: Space.x1) {
                if model.isHovering || isFocused {
                    IconButton(systemName: "square.and.pencil",
                                label: "Create note from transcription") {
                        NoteStore.shared.create(body: entry.text)
                    }
                    IconButton(systemName: "arrow.uturn.left.square",
                                label: "Paste into the previous app") {
                        reinject(entry.text)
                    }
                    IconButton(systemName: model.copied ? "checkmark" : "doc.on.doc",
                                label: model.copied ? "Copied" : "Copy transcription",
                                tint: model.copied ? Tint.success : nil) {
                        model.copy(text: entry.text)
                    }
                    IconButton(systemName: "trash", label: "Delete transcription") {
                        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.listChange) {
                            onDelete()
                        }
                    }
                }
            }
            .frame(width: 116, alignment: .trailing)
            .accessibilityValue(model.copied ? "Copied" : "")
        }
        .padding(.vertical, Space.rowPaddingV)
        .padding(.horizontal, Space.rowPaddingH)
        .frame(minHeight: Layout.rowMinHeight)
        .rowFill(isHovering: model.isHovering)
        .overlay(
            Radius.rect(Radius.control)
                .strokeBorder(Line.focus, lineWidth: Line.focusWidth)
                .opacity(isFocused ? 1 : 0)
                .padding(-1)
        )
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { model.isHovering = hovering }
        }
        .focusable()
        .focused($isFocused)
        .contextMenu {
            Button("Create Note from Transcription") { NoteStore.shared.create(body: entry.text) }
            Button("Paste into the previous app") { reinject(entry.text) }
            Button("Copy transcription") { model.copy(text: entry.text) }
            Divider()
            Button("Delete transcription", role: .destructive) { onDelete() }
        }
    }

    private func reinject(_ text: String) {
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            TextInjector.typeText(text)
        }
    }
}

// MARK: - Weekly Activity Bar Chart

struct WeeklyActivityChart: View {
    @ObservedObject private var history = TranscriptionHistory.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    struct DayMetric: Identifiable {
        let id = UUID()
        let dayName: String
        let date: Date
        let count: Int
        let isToday: Bool
    }

    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt
    }()

    private var chartData: (days: [DayMetric], maxCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var days: [DayMetric] = []
        var maximum = 10

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let count = history.entries.filter { $0.timestamp >= date && $0.timestamp < nextDate }.reduce(0) { $0 + $1.wordCount }
            let isToday = calendar.isDateInToday(date)
            if count > maximum { maximum = count }
            days.append(DayMetric(
                dayName: isToday ? "Today" : Self.dayFormatter.string(from: date),
                date: date,
                count: count,
                isToday: isToday
            ))
        }
        return (days, maximum)
    }

    var body: some View {
        let (days, maxCount) = chartData
        BentoTile(
            title: "7-Day Dictation Activity",
            systemImage: "chart.bar.xaxis",
            tint: Tint.accent
        ) {
            VStack(alignment: .leading, spacing: Space.x2) {
                HStack(alignment: .bottom, spacing: Space.x3) {
                    ForEach(days) { metric in
                        VStack(spacing: Space.x1) {
                            Text(metric.count > 0 ? "\(metric.count)" : "0")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(metric.isToday ? Tint.accent : Ink.secondary)
                                .monospacedDigit()

                            let heightFraction = CGFloat(metric.count) / CGFloat(maxCount)
                            let barHeight = max(6, heightFraction * 44)

                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(
                                        metric.isToday
                                            ? LinearGradient(colors: [Tint.accent, Tint.accent.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                                            : LinearGradient(colors: [Color.primary.opacity(0.25), Color.primary.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(height: barHeight)
                            }
                            .frame(height: 48)

                            Text(metric.dayName)
                                .font(.system(size: 11, weight: metric.isToday ? .bold : .regular))
                                .foregroundStyle(metric.isToday ? Tint.accent : Ink.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, Space.x1)
            }
        }
    }
}
