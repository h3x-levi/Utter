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
    /// A `TextField` fills the width it is offered, and this one sits in a tile header
    /// beside the export menu, so it needs a fixed one rather than a `Spacer` fight.
    ///
    /// 196 is kept as the slot width, but the arithmetic that used to justify it is
    /// gone: it added up the hand-drawn well's own `Space.x3` insets (150 + 12 + 12 +
    /// 12 + 8), and `GlassTextField` is now a `TextField` with
    /// `.textFieldStyle(.roundedBorder)`, whose insets belong to the system bezel and
    /// are not this file's to add up. What is left is a measured-by-eye slot: ~176pt
    /// of field after the 12pt glyph and its `Space.x2` gap, which is a comfortable
    /// search measure and leaves the header room for the export button.
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
            BentoTile(title: "Activity") {
                VStack(alignment: .leading, spacing: 0) {
                    activityRow("Words dictated", value: history.totalWords.formatted())
                    Divider()
                    activityRow("Dictations", value: history.entries.count.formatted())
                    Divider()
                    activityRow(
                        "Day streak",
                        value: history.streakDays > 0
                            ? history.streakDays.formatted()
                            : "\u{2014}"
                    )
                }
            }

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
                            text: $searchText,
                            systemImage: "magnifyingglass"
                        )
                        .frame(width: Self.searchWidth)

                        // Not `.searchable`, which is the obvious system answer and
                        // does not apply: on macOS it places its field in the
                        // surrounding `NavigationStack`/`NavigationSplitView`'s
                        // toolbar, and this screen is inside neither — it is a tab
                        // body in `FlowMainView`. With nowhere to put the field the
                        // modifier renders nothing, so the search would disappear.
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
                        // `.menuStyle(.button)` + `.buttonStyle(.bordered)`, which is
                        // verbatim what the SDK's own deprecation on
                        // `.menuStyle(.borderlessButton)` tells you to use ("Use
                        // .menuStyle(.button) and .buttonStyle(.bordered)", macOS
                        // 11.0 deprecated). Both macOS 13.0, under the 13.3 floor.
                        //
                        // It is also the fix for this button rather than only a
                        // deprecation cleanup. `.borderlessButton` drew no bezel and
                        // no hover, so the export affordance on the History tile was
                        // a 12pt grey glyph floating in the header — indistinguishable
                        // from decoration until clicked. `.bordered` gives it the
                        // system's resting bezel and the system's hover, which is the
                        // whole complaint about this app's light themes.
                        //
                        // `.frame(width: 24)` is gone with it: that width was sized to
                        // a bare glyph and would clip a bezelled button's insets.
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
        Color.clear
            .overlay(alignment: .leading) {
                Text(label)
            }
            .overlay(alignment: .trailing) {
                Text(value)
                .foregroundStyle(.secondary)
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

    /// Writes `expanded` inside `withAnimation(collapseCurve)`.
    ///
    /// `DisclosureGroup(isExpanded:)` sets the binding itself when its chevron is
    /// clicked, and it animates that with SwiftUI's default curve. Routing the write
    /// through here keeps `collapseCurve` — and therefore the Reduce Motion branch —
    /// on the largest single piece of travel on the Home screen, which is the entire
    /// reason `collapseCurve` exists. It is the same `withAnimation(collapseCurve)`
    /// the hand-rolled expander did in its button actions, moved to where the system
    /// control writes.
    private var disclosure: Binding<Bool> {
        Binding(
            get: { expanded },
            set: { open in withAnimation(collapseCurve) { expanded = open } }
        )
    }

    var body: some View {
        BentoTile(title: nil) {
            if shouldCollapse {
                // `DisclosureGroup` (macOS 11.0, under the 13.3 floor), not a
                // hand-rolled expander.
                //
                // What this replaces is a whole second surface. The collapsed state
                // was a `.buttonStyle(.plain)` `Button` wrapping a fixed 38pt row with
                // its own `.card(radius: Radius.panel, padding: 0)` material, a
                // hand-computed `.contentShape(Radius.rect(Radius.panel))` to stop the
                // four unpainted corners of that card from eating clicks, and a
                // hand-drawn `chevron.down` — while the expanded state carried a
                // *second* hand-drawn `chevron.up` in an `IconButton` accessory. Two
                // chevrons, two surfaces and a hit-region calculation, for one
                // disclosure.
                //
                // The system supplies all of it: one chevron that knows which way it
                // points, its own hit region, hover and pressed feedback, Space-bar
                // activation, and the expanded/collapsed state VoiceOver announces —
                // which the hand-rolled `Button` never did. It read as "Everything
                // ready, Hold ⌥, to dictate, button", with nothing to say that
                // activating it would reveal five rows.
                DisclosureGroup(isExpanded: disclosure) {
                    panelContent
                } label: {
                    // A disclosure label is visible in both states, so it carries
                    // whichever line the old two-branch layout showed: the heading
                    // when open, the one-line summary when shut.
                    if expanded { heading } else { summary }
                }
            } else {
                // Not collapsible: something is still missing, or the user is inside
                // their first five dictations. No disclosure affordance at all, which
                // is what this branch did before — a `DisclosureGroup` here would
                // offer to hide the readiness rows that are the only reason the panel
                // is on screen.
                VStack(alignment: .leading, spacing: Space.x3) {
                    heading
                    panelContent
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

    /// The open state's heading: what to press, or that the engine is still loading.
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

    /// The shut state's one-liner: the five rows below, said in a sentence.
    private var summary: some View {
        HStack(spacing: Space.x2) {
            // `checkmark.circle.fill`, the same glyph `StatusRow` draws for `.ok`, not
            // a 7pt `Circle` filled green. The collapsed line now says what the five
            // rows it stands in for say, in the same shape — and the meaning stops
            // resting on hue alone, which a bare tinted dot cannot avoid.
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

    /// The divider and the five live rows — identical in both branches, which is why
    /// they are one property rather than two copies that can drift apart.
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

/// Applies text selection only when `active`, without changing the view's identity per frame.
///
/// `.textSelection(.enabled)` and `.disabled` are different types, so they cannot be chosen with a
/// ternary; a `ViewModifier` erases the difference. Selection realises several AppKit-hosted views
/// per row, so keeping it off until a pointer or keyboard is actually on the row is what takes that
/// cost off the scroll path — see the call site in `HistoryRow`.
private struct HoverTextSelection: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.textSelection(.enabled) } else { content.textSelection(.disabled) }
    }
}

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
                    // Selectable only while the row is hovered or focused, not for every visible
                    // row all the time. `.textSelection(.enabled)` realises ~4 AppKit-hosted views
                    // per row, and doing that for every row as it enters the lazy viewport is a
                    // large per-frame cost while scrolling the history — part of the "mouse wheel
                    // lags" the user reported. Applied through a modifier because the enabled and
                    // disabled selectability types are not the same type and cannot be ternaried;
                    // the modifier erases that, and switches once per hover rather than per frame.
                    .modifier(HoverTextSelection(active: isHovering || isFocused))

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
        // Was `.rowFill()`, which reads no state — so this row, on the app's default
        // screen, had a hover step of exactly 1.000:1 while its four siblings all moved
        // their fill. The three action buttons still appeared, which is why it read as
        // "controls materialise out of nowhere" rather than as nothing happening.
        .rowFill(isHovering: isHovering)
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
