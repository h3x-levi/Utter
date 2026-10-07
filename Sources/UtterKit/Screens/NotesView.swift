import SwiftUI

/// The Notes screen: a searchable list of notes beside an editor.
///
/// Replaces the old `ScratchpadView`, which was a single shared text buffer
/// (`UserData.scratchpad`) presented as "Notes" - writing a second note
/// overwrote the first. State now lives in `NoteStore`, so the sidebar rebuilding
/// this view on navigation no longer risks the text.
///
/// The list is a real `List(selection:)` with real `Section` headers, replacing a
/// `ScrollView` + `LazyVStack` + `GlassSelectableRow`. That one change is what
/// supplies row hover, the selection fill in the correct appearance, the focus ring,
/// arrow-key and type-select navigation, and the accessibility table role - the old
/// list had none of them beyond a hand-drawn hover wash, and `GlassSelectableRow`'s
/// own doc comment names this exact conversion ("`List(selection:)`/`.listStyle(.inset)`
/// retires this whole type") as the reason it should not survive.
@MainActor
final class NoteEditorDraft: ObservableObject {
    @Published var draftBody = ""
    @Published var draftTitle = ""
    @Published var draftNoteID: UUID?
    @Published var draftSpeakers = MeetingSpeakers.default
    @Published var runningAction: NoteAction?
    @Published var actionMessage: String?
    @Published var actionMessageIsError = false
    @Published var pendingDeleteID: UUID?
    @Published var meetingMessage: String?
    @Published var searchText = ""

    func syncDraft(from note: Note?) {
        draftNoteID = note?.id
        draftBody = note?.body ?? ""
        draftSpeakers = note?.speakerLabels ?? .default
        draftTitle = (note?.titleIsCustom ?? false) ? (note?.title ?? "") : ""
    }

    func commitDraft(store: NoteStore) {
        guard let id = draftNoteID, store.notes.contains(where: { $0.id == id }) else { return }
        store.updateBody(draftBody, for: id)
        store.updateTitle(draftTitle, for: id)
    }

    func commitSpeakers(store: NoteStore) {
        guard let id = draftNoteID, store.notes.contains(where: { $0.id == id }) else { return }
        commitDraft(store: store)
        for role in SpeakerRole.allCases {
            store.renameSpeaker(role, to: draftSpeakers[role], in: id)
        }
        draftSpeakers = store.notes.first { $0.id == id }?.speakerLabels ?? .default
    }
}

struct NotesView: View {
    @ObservedObject private var store = NoteStore.shared
    @StateObject private var draft = NoteEditorDraft()
    @FocusState private var focusedSpeaker: SpeakerRole?
    @ObservedObject private var meeting = AppDelegate.current?.meetingSession ?? MeetingSession()

    private var groups: [NoteGroup] { store.grouped(matching: draft.searchText) }

    var body: some View {
        HSplitView {
            noteList
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 380,
                       maxHeight: .infinity, alignment: .top)
            editor
                .frame(minWidth: 420, maxWidth: .infinity,
                       maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { draft.syncDraft(from: store.selectedNote) }
        .onChange(of: store.selectedNote?.body) { latest in
            guard let id = draft.draftNoteID,
                  store.selectedNoteID == id,
                  let latest,
                  latest != draft.draftBody else { return }
            draft.draftBody = latest
        }
        .onChange(of: store.selectedNoteID) { _ in
            draft.commitSpeakers(store: store)
            draft.commitDraft(store: store)
            draft.syncDraft(from: store.selectedNote)
        }
        .onChange(of: focusedSpeaker) { focus in
            if focus == nil { draft.commitSpeakers(store: store) }
        }
        .onDisappear {
            draft.commitSpeakers(store: store)
            draft.commitDraft(store: store)
            store.writeToDisk()
        }
        // Deleting a note is irreversible from the UI. `NoteStore.delete` removes it and
        // the next *differing* save overwrites the single retained generation at
        // `notes.previous.json`, so the window in which a mistake is recoverable is
        // seconds wide and requires a text editor to reach. The previous affordance was a
        // trash button that faded in under the pointer on row hover, one click from gone.
        //
        // A real `.confirmationDialog` is the whole fix: the system supplies the sheet,
        // the destructive-role button styling, Escape-to-cancel, the default button, and
        // the VoiceOver announcement. This is not an undo system and does not pretend to
        // be one - see `deleteWarning`, which says so.
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(
                get: { draft.pendingDeleteID != nil },
                set: { if !$0 { draft.pendingDeleteID = nil } }
            ),
            titleVisibility: .visible,
            presenting: draft.pendingDeleteID
        ) { id in
            Button("Delete Note", role: .destructive) {
                store.delete(id: id)
                draft.pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { draft.pendingDeleteID = nil }
        } message: { id in
            Text(deleteWarning(for: id))
        }
    }

    private func deleteWarning(for id: UUID) -> String {
        let title = store.notes.first { $0.id == id }?.displayTitle ?? "This note"
        return "“\(title)” will be removed. Utter has no undo for a deleted note."
    }

    // MARK: - List

    private var noteList: some View {
        ContentSection(
            title: "Notes",
            systemImage: "note.text",
            accessory: AnyView(
                GlassIconButton(systemName: "plus", label: "New note") {
                    draft.commitDraft(store: store)
                    let note = store.create()
                    draft.syncDraft(from: note)
                }
            )
        ) {
            meetingBar
            SystemSearchField(text: $draft.searchText, prompt: "Search notes")

            if store.notes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No notes yet",
                    message: "Start one here, press ⌃⌥N to dictate straight into Utter, "
                             + "or say \u{201C}start a new note\u{201D} while dictating.",
                    actionLabel: "New note"
                ) {
                    let note = store.create()
                    draft.syncDraft(from: note)
                }
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else if groups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No matches",
                    message: "Nothing here matches “\(draft.searchText)”."
                )
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else {
                notesList
            }
        }
    }

    private var notesList: some View {
        List(selection: $store.selectedNoteID) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.notes) { note in
                        NoteRow(note: note)
                            .tag(note.id)
                            .contextMenu {
                                Button("Delete Note", role: .destructive) {
                                    draft.pendingDeleteID = note.id
                                }
                            }
                    }
                } header: {
                    Text(group.label).typo(.microLabel, ink: Ink.tertiary)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .onDeleteCommand {
            if let id = store.selectedNoteID { draft.pendingDeleteID = id }
        }
        .frame(minHeight: 320, maxHeight: .infinity)
    }

    // MARK: - Meeting capture

    @ViewBuilder
    private var meetingBar: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            switch meeting.state {
            case .recording:
                HStack(spacing: Space.x2) {
                    Circle()
                        .fill(Tint.danger)
                        .frame(width: 8, height: 8)
                    Text("Recording this meeting")
                        .typo(.callout)
                    Text(elapsedLabel)
                        .typo(.caption, ink: Ink.tertiary)
                        .monospacedDigit()
                    Spacer(minLength: Space.x1)
                    GlassButton(title: "Stop", systemImage: "stop.fill") {
                        Task { await meeting.stop() }
                    }
                }
                if !meeting.heardOthers {
                    Text("No audio from other participants yet - check the meeting isn’t muted or on a headset Utter can’t hear.")
                        .typo(.caption, ink: Tint.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .finishing:
                HStack(spacing: Space.x2) {
                    ProgressView().controlSize(.small)
                    Text("Finishing the transcript…").typo(.caption, ink: Ink.secondary)
                }

            case .failed(let why):
                Text(why)
                    .typo(.caption, ink: Tint.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
                GlassButton(title: "Try again", systemImage: "arrow.clockwise") {
                    startMeeting()
                }

            case .idle:
                GlassButton(title: "Record a meeting", systemImage: "person.wave.2") {
                    startMeeting()
                }
            }

            if let meetingMessage = draft.meetingMessage {
                Text(meetingMessage)
                    .typo(.caption, ink: Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var elapsedLabel: String {
        let total = meeting.elapsed
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func startMeeting() {
        guard let delegate = AppDelegate.current else { return }
        draft.meetingMessage = nil

        if let why = MeetingSession.prepare() {
            draft.meetingMessage = why
            return
        }

        Task { @MainActor in
            let id = await meeting.start(
                recorder: delegate.audioRecorder,
                transcriber: delegate.transcriptionService
            )
            if let id {
                store.selectedNoteID = id
                draft.syncDraft(from: store.notes.first { $0.id == id })
            }
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let note = store.selectedNote {
            ContentSection(
                title: nil,
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
                        if note.source == .dictated {
                            GlassChip(text: "dictated", systemImage: "mic")
                        }
                        GlassIconButton(systemName: "doc.on.doc", label: "Copy note") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(draft.draftBody, forType: .string)
                        }
                        .disabled(draft.draftBody.isEmpty)
                        GlassIconButton(systemName: "square.and.arrow.up", label: "Export as Markdown") {
                            exportMarkdown(note)
                        }
                        .disabled(draft.draftBody.isEmpty)
                        GlassIconButton(systemName: "trash", label: "Delete note",
                                        tint: Tint.danger) {
                            draft.pendingDeleteID = note.id
                        }
                    }
                )
            ) {
                TextField(note.displayTitle, text: $draft.draftTitle)
                    .textFieldStyle(.plain)
                    .typo(.serifHeading)
                    .onSubmit { draft.commitDraft(store: store) }

                metadata(for: note)

                if note.source == .meeting {
                    speakerBar
                }

                GlassTextEditor(text: $draft.draftBody, minHeight: 200)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: draft.draftBody) { _ in scheduleSync() }

                actionBar(for: note)
            }
        } else {
            ContentSection(title: nil) {
                EmptyStateView(
                    icon: "note.text",
                    title: "Nothing selected",
                    message: "Pick a note on the left, or press + to start a new one."
                )
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            }
        }
    }

    private func metadata(for note: Note) -> some View {
        let dateLabel = note.source == .meeting ? "Meeting" : "Edited"
        return HStack(spacing: Space.x4) {
            LabeledContent(dateLabel, value: timestamp(note.modified))
                .fixedSize()
            LabeledContent("Words", value: wordCount(draft.draftBody))
                .fixedSize()
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .font(Typo.caption.font)
        .foregroundStyle(Ink.tertiary)
    }

    // MARK: - Speaker labels

    @ViewBuilder
    private var speakerBar: some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x2) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.tertiary)
                speakerField(role: .you)
                speakerField(role: .others)
                Spacer(minLength: 0)
            }
            Text("Utter labels your microphone and the call’s audio separately. It can’t tell two "
                 + "people in the call apart, so rename the second label only if one person was speaking.")
                .typo(.caption, ink: Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func speakerField(role: SpeakerRole) -> some View {
        TextField(
            MeetingSpeakers.default[role],
            text: Binding(get: { draft.draftSpeakers[role] }, set: { draft.draftSpeakers[role] = $0 })
        )
        .textFieldStyle(.roundedBorder)
        .font(Typo.callout.font)
        .accessibilityLabel(role == .you ? "Name for your microphone"
                                         : "Name for the call’s audio")
        .focused($focusedSpeaker, equals: role)
        .onSubmit { draft.commitSpeakers(store: store) }
        .frame(width: 130)
    }

    // MARK: - AI actions

    @ViewBuilder
    private func actionBar(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            HStack(spacing: Space.x2) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.purple)
                Text("Apple Intelligence Actions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
                Spacer()
            }
            .padding(.top, Space.x1)

            FlowLayout(spacing: Space.x2) {
                ForEach(NoteAction.allCases) { action in
                    Button {
                        run(action, on: note.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.purple)
                            Text(action.title)
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(draft.runningAction != nil || draft.draftBody.isEmpty)
                }
            }

            if let runningAction = draft.runningAction {
                HStack(spacing: Space.x2) {
                    ProgressView().controlSize(.small)
                    Text(runningAction.runningLabel).typo(.caption, ink: Ink.secondary)
                }
            } else if let actionMessage = draft.actionMessage {
                Text(actionMessage)
                    .typo(.caption, ink: draft.actionMessageIsError ? Tint.dangerText : Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func run(_ action: NoteAction, on id: UUID) {
        draft.commitDraft(store: store)
        draft.runningAction = action
        draft.actionMessage = nil

        Task { @MainActor in
            let result = await NoteActionRunner.run(action, noteID: id)
            draft.runningAction = nil
            switch result {
            case .applied:
                draft.actionMessageIsError = false
                draft.actionMessage = nil
                draft.syncDraft(from: store.notes.first { $0.id == id })
            case .nothingToDo(let why):
                draft.actionMessageIsError = false
                draft.actionMessage = why
            case .rejected(let why):
                draft.actionMessageIsError = true
                draft.actionMessage = why
            case .unavailable(let why):
                draft.actionMessageIsError = true
                draft.actionMessage = why
            }
        }
    }

    // MARK: - Export

    private func exportMarkdown(_ note: Note) {
        draft.commitDraft(store: store)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = safeFilename(for: note) + ".md"
        panel.allowedContentTypes = [.init(filenameExtension: "md")].compactMap { $0 }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let contents = "# \(note.displayTitle)\n\n\(draft.draftBody)\n"
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            draft.actionMessageIsError = true
            draft.actionMessage = "Couldn’t save that file: \(error.localizedDescription)"
        }
    }

    private func safeFilename(for note: Note) -> String {
        let base = note.displayTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(base.prefix(80))
        return trimmed.isEmpty || trimmed.hasPrefix(".") ? "Note" : trimmed
    }

    private func wordCount(_ text: String) -> String {
        String(text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count)
    }

    private func timestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
    }

    private func scheduleSync() {
        draft.commitDraft(store: store)
    }
}

/// One row in the notes list - content only.
///
/// Everything that used to be drawn here belongs to the enclosing
/// `List(selection:)` now: the row background, the hover wash, the selection fill in
/// the correct appearance, the focus ring, arrow-key and type-select navigation, and
/// the accessibility table role. So `GlassSelectableRow`, the `@State isHovering`,
/// the `.onHover { withAnimation { … } }` and the `.opacity(isHovering ? 1 : 0)` that
/// faded a trash button in and out are all gone, along with the two defects their doc
/// comment recorded - an unanimated hover, and a conditionally-inserted trash that
/// took 28pt of the title's width with it when it appeared. A list row cannot have
/// either defect if the list draws the row.
///
/// The trash button itself is gone on purpose, not by accident of the migration, and
/// the reason is worth keeping because the same `.opacity(isHovering ? 1 : 0)` pattern
/// is used for row actions in `WordRow`, `CustomCommandRow` and `HistoryRow`:
/// **`.opacity(0)` hides the pixels and keeps the behaviour.** Unlike `.hidden()`, it
/// removes a view from neither hit-testing nor the accessibility tree, so every note
/// row carried a live, focusable, VoiceOver-announced *delete* control with no visual
/// presence. A click into apparently-empty row space could delete a note; Tab could
/// land focus on nothing; VoiceOver announced a button that was not there. Reveal-on-
/// hover is a fine Mac convention - doing it with opacity alone is the defect, and
/// pairing an invisible trigger with an irreversible act (see `NotesView.deleteWarning`)
/// is the worst version of it.
///
/// The three replacements are the three a Mac user already knows, and all of them are
/// reachable by pointer, keyboard *and* VoiceOver, which the hover button never was:
/// right-click the row, press ⌫ with the list focused, or use the editor's own
/// always-visible trash button. All three go through one confirmation.
///
/// If a hover-revealed action is ever wanted back here for pointer discoverability,
/// hide the behaviour along with the pixels  - 
/// `.opacity(hovering ? 1 : 0).allowsHitTesting(hovering).accessibilityHidden(!hovering)`
/// - rather than relying on opacity to do it.
///
/// **The colours here are deliberately the system's, not the theme's.** `Ink.*` are
/// absolute themed values, and an absolute value cannot invert when the system fills
/// the row with the selection colour - the selected note's title would have stayed a
/// dark themed grey on an accent fill. The type scale (`Typo.*.font`) is the part of
/// the token that still applies; the foreground is left to the list for the title and
/// set to the semantic `.secondary` for the preview, both of which AppKit remaps for a
/// selected row.
private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: Space.x2) {
            Image(systemName: note.source == .meeting ? "person.2.fill" : (note.source == .dictated ? "waveform" : "note.text"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(note.source == .meeting ? Tint.accent : (note.source == .dictated ? Tint.handsFree : Ink.tertiary))
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(note.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                }

                if let preview = previewLine {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Body text with the title line dropped, so the preview isn't the title twice.
    private var previewLine: String? {
        let lines = note.body
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        return lines.dropFirst().first
    }
}

/// The system search field.
///
/// This replaces a hand-drawn search control - a `Surface.sunken` well, a
/// magnifying-glass `Image`, an `IconButton` clear button, and an accent focus ring
/// drawn off a `@FocusState` that existed for no other purpose. All four are
/// `NSSearchField`'s own job, and it does them in the current appearance, at the
/// current control size, with Increase Contrast honoured and with the clear button
/// appearing and disappearing on its own. The hand-drawn version notably had **no
/// focus indication at all** before a ring was bolted on, which is the whole class of
/// defect this screen was rewritten for.
///
/// `.searchable(text:placement:prompt:)` is the SwiftUI answer and it cannot be used
/// here. This screen is hosted in an `NSHostingController` inside an
/// `NSSplitViewController` (`App.swift`), with no `NavigationStack` or
/// `NavigationSplitView` above it, and the window's `NSToolbar` is built by AppKit
/// with no delegate and no items - `App.swift` says so in as many words. `.searchable`
/// needs one of those to place a field into, and with neither present the likely
/// outcome is no field rendered at all, which would silently remove search from the
/// screen holding the user's only copy of their own writing. The shell change that
/// unlocks it is in the report; until then `NSSearchField` is the genuine system
/// control that can actually be reached from here.
private struct SystemSearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        // Filter as the user types rather than on Return: the list is the result.
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        // Target/action *as well as* the delegate, deliberately. `controlTextDidChange`
        // covers typing; the built-in clear button empties the field through the
        // control's action rather than a text-change notification, so a delegate alone
        // can leave the binding holding a query the field no longer shows. Both funnel
        // into one setter that drops a no-op, so the overlap costs nothing.
        field.target = context.coordinator
        field.action = #selector(Coordinator.searchFieldChanged(_:))
        // No `recentsAutosaveName` and no `searchMenuTemplate`, which is the default
        // and is being left alone on purpose: searching your own notes should not
        // leave a list of what you searched for on disk.
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.text = $text
        field.placeholderString = prompt
        // Only when it differs. Assigning `stringValue` unconditionally would reset the
        // insertion point to the end of the field on every keystroke.
        if field.stringValue != text { field.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            push(field.stringValue)
        }

        @objc func searchFieldChanged(_ sender: NSSearchField) {
            push(sender.stringValue)
        }

        private func push(_ value: String) {
            guard text.wrappedValue != value else { return }
            text.wrappedValue = value
        }
    }
}
