import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import ApplicationServices

struct HomeView: View {
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var userData = UserData.shared
    @State private var searchText = ""

    /// Width of the history search field.
    ///
    /// `GlassTextField` fills the width it is given, and this one sits in a tile
    /// header beside the export menu, so it needs a fixed one rather than a `Spacer`
    /// fight. Derived from what the hand-rolled field it replaced offered: 150pt of
    /// text area, plus `GlassTextField`'s own `Space.x3` padding each side, its 12pt
    /// glyph and the `Space.x2` gap after it — 150 + 12 + 12 + 12 + 8 = 194, rounded
    /// up to the 4pt grid.
    private static let searchWidth: CGFloat = 196

    private var filteredGroups: [HistoryGroup] {
        let groups = history.groupedByDate
        if searchText.isEmpty { return groups }
        return groups.compactMap { group in
            let filtered = group.entries.filter {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : HistoryGroup(id: group.id, label: group.label, entries: filtered)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            // Stat tiles — the smallest bento units, side by side.
            BentoRow(columns: 3) {
                BentoStat(
                    value: "\(history.totalWords)",
                    label: "WORDS DICTATED",
                    systemImage: "text.word.spacing"
                )
                BentoStat(
                    value: "\(history.entries.count)",
                    label: "DICTATIONS",
                    systemImage: "waveform",
                    tint: Tint.success
                )
                BentoStat(
                    value: history.streakDays > 0 ? "\(history.streakDays)" : "\u{2014}",
                    label: "DAY STREAK",
                    systemImage: "flame",
                    tint: Tint.handsFree
                )
            }

            // Readiness — a wide tile, since every row is live state.
            ReadyPanel(transcriptionCount: history.entries.count)

            // History tile, with search and export in its header.
            BentoTile(
                title: "History",
                systemImage: "clock.arrow.circlepath",
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
                        // `GlassTextField`, not a hand-rolled well.
                        //
                        // This was a copy of the component's *appearance* without its
                        // behaviour: same `Surface.sunken` fill and `Radius.field`
                        // shape, 26pt instead of 30, and **no focus ring**. That is an
                        // accessibility gap rather than drift — a keyboard user
                        // tabbing into the search field on the app's landing screen got
                        // no indication that they had. The component animates the ring
                        // at `Tint.accent.opacity(0.7)`, 1.5pt (`GlassTextField`).
                        GlassTextField(
                            placeholder: "Search",
                            text: $searchText,
                            systemImage: "magnifyingglass"
                        )
                        .frame(width: Self.searchWidth)

                        Menu {
                            Button("Markdown") { exportHistory(format: .markdown) }
                            Button("Comma-separated values") { exportHistory(format: .csv) }
                            Button("Plain text") { exportHistory(format: .text) }
                        } label: {
                            // Explicit ink, not the ambient tint. Inheriting the
                            // accent put this icon at **1.39:1** on the tile —
                            // below the point where a shape reads as a control at
                            // all, and this is a button, not decoration.
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Ink.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 24)
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
                        title: "No matches for \u{201C}\(searchText)\u{201D}",
                        message: "Try a shorter phrase, or a single word.",
                        actionLabel: "Clear search",
                        action: { searchText = "" }
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
                                SectionHeader(title: group.label)
                                ForEach(group.entries) { entry in
                                    HistoryRow(entry: entry, onDelete: {
                                        history.delete(entry: entry)
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
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

/// Replaces the old decorative feature cards with live state. Every row here
/// reflects something real, so it stays honest — and it answers the only
/// question a new user actually has: "is this thing working?"
struct ReadyPanel: View {
    let transcriptionCount: Int

    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var readiness = ReadinessMonitor.shared
    @ObservedObject private var motion = MotionPreference.shared
    @State private var expanded = true

    /// The collapse/expand curve.
    ///
    /// This is the largest single piece of travel on the Home screen — the panel goes
    /// from a 38pt bar to five status rows and a heading, roughly 200pt of height —
    /// and it was the one place `Motion.layout` ran unbranched while eight smaller
    /// movements in the same app were already checking. Reduce Motion cannot
    /// meaningfully be honoured on a hover wash and ignored on this.
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

    /// The model row states where the engine actually is — "bundled" alone was
    /// misleading during the several seconds it takes to load 181 MB.
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

    /// Collapse once everything works and the user is past the first few
    /// dictations, so it stops occupying prime space for regulars.
    private var shouldCollapse: Bool { allReady && transcriptionCount >= 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if shouldCollapse && !expanded {
                Button {
                    withAnimation(collapseCurve) { expanded = true }
                } label: {
                    HStack(spacing: Space.x2) {
                        Circle().fill(Tint.success).frame(width: 7, height: 7)
                        Text("Everything ready").typo(.body)
                        Text("Hold").typo(.caption)
                        Keycap(key: userData.hotkeyName)
                        Text("to dictate").typo(.caption)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Ink.tertiary)
                    }
                    .padding(.horizontal, Space.cardPadding)
                    .frame(height: 38)
                    // The card's own shape, not a `Rectangle`.
                    //
                    // `.card(radius: Radius.panel, padding: 0)` below draws a 16pt corner
                    // over exactly these bounds — padding 0, so the label's frame *is* the
                    // card's frame — and a rectangular hit region therefore accepted clicks
                    // in four corners where nothing is painted. This is the widest radius in
                    // the app on the shortest surface (38pt), so those corners are the
                    // largest unpainted target it has.
                    //
                    // Fixed radius rather than `ConcentricRectangle`: at inset 0 the
                    // concentric answer *is* `Radius.panel`, so the API would resolve to this
                    // number by a longer route and add an availability branch to reach it.
                    // See the note above `Radius` for the measurements.
                    .contentShape(Radius.rect(Radius.panel))
                }
                .buttonStyle(.plain)
                // Same material as the expanded BentoTile it replaces, so
                // collapsing changes the size and not the surface. Padding is
                // applied to the label above, since the row is a fixed height.
                .card(radius: Radius.panel, padding: 0)
            } else {
                BentoTile(
                    title: nil,
                    accessory: shouldCollapse ? AnyView(
                        IconButton(systemName: "chevron.up", label: "Collapse") {
                            withAnimation(collapseCurve) { expanded = false }
                        }
                    ) : nil
                ) {
                  VStack(alignment: .leading, spacing: Space.x3) {
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
            }
        }
        // Full content width, like every other tile on the screen. A
        // `readingWidth` cap here made this tile ~120pt narrower than the stat
        // row above and the history tile below, so its right edge sat inside
        // theirs — the one thing a bento layout cannot do. A reading-measure cap
        // is right for prose; these are short label/value rows.
        .frame(maxWidth: .infinity)
        .onAppear {
            readiness.startPolling()
            expanded = !shouldCollapse
        }
        .onDisappear { readiness.stopPolling() }
    }

    private func openPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - History row

struct HistoryRow: View {
    let entry: TranscriptionEntry
    var onDelete: () -> Void = {}

    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @State private var copied = false
    @State private var expanded = false
    @ObservedObject private var motion = MotionPreference.shared

    private var isTruncatable: Bool { entry.text.count > 160 }

    var body: some View {
        HStack(alignment: .top, spacing: Space.x3) {
            // Locale-aware and tabular, so the column doesn't jitter.
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .typo(.timestamp)
                .frame(width: 72, alignment: .trailing)

            VStack(alignment: .leading, spacing: Space.x1) {
                Text(entry.text)
                    .typo(.transcript)
                    .lineLimit(expanded ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                HStack(spacing: Space.x2) {
                    if isTruncatable {
                        // Unbounded travel, not a fixed step: the row goes from a
                        // 3-line clamp to however long the transcription is, which for
                        // a dictated paragraph is the tallest thing on the screen. It
                        // was the only expand in the app with no Reduce Motion branch.
                        Button(expanded ? "Show less" : "Show more") {
                            withAnimation(motion.reduceMotion ? Motion.reduced : Motion.layout) {
                                expanded.toggle()
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

            // Fixed width so the row doesn't reflow when actions appear.
            HStack(spacing: Space.x1) {
                if isHovering || isFocused {
                    IconButton(systemName: "arrow.uturn.left.square",
                               label: "Paste into the previous app") {
                        reinject(entry.text)
                    }
                    IconButton(systemName: copied ? "checkmark" : "doc.on.doc",
                               label: copied ? "Copied" : "Copy transcription",
                               tint: copied ? Tint.success : nil) {
                        copy()
                    }
                    IconButton(systemName: "trash", label: "Delete transcription") {
                        // Not in the audit's list, but the same class: removing a row
                        // slides every row below it up the list, which is travel.
                        withAnimation(motion.reduceMotion ? Motion.reduced : Motion.listChange) {
                            onDelete()
                        }
                    }
                }
            }
            .frame(width: 88, alignment: .trailing)
            .accessibilityValue(copied ? "Copied" : "")
        }
        .padding(.vertical, Space.rowPaddingV)
        .padding(.horizontal, Space.rowPaddingH)
        .frame(minHeight: Layout.rowMinHeight)
        .rowFill()
        .overlay(
            Radius.rect(Radius.control)
                .strokeBorder(Line.focus, lineWidth: Line.focusWidth)
                .opacity(isFocused ? 1 : 0)
                .padding(-1)
        )
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        .focusable()
        .focused($isFocused)
        // Hover-only actions are unreachable by keyboard and invisible to
        // VoiceOver, so mirror all three in a context menu.
        .contextMenu {
            Button("Paste into the previous app") { reinject(entry.text) }
            Button("Copy transcription") { copy() }
            Divider()
            Button("Delete transcription", role: .destructive) { onDelete() }
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
    }

    /// Hide Utter so the previously-focused app regains focus, then paste there.
    /// The short delay lets macOS finish the focus switch before we inject.
    private func reinject(_ text: String) {
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            TextInjector.typeText(text)
        }
    }
}
