import SwiftUI

/// The Notes screen: a searchable list of notes beside an editor.
///
/// Replaces the old `ScratchpadView`, which was a single shared text buffer
/// (`UserData.scratchpad`) presented as "Notes" — writing a second note
/// overwrote the first. State now lives in `NoteStore`, so the sidebar rebuilding
/// this view on navigation no longer risks the text.
struct NotesView: View {
    @ObservedObject private var store = NoteStore.shared
    @State private var searchText = ""
    /// Local mirror of the open note's body.
    ///
    /// `TextEditor` needs a `Binding<String>`, but binding it straight through to
    /// the store would run the full mutate-stamp-sort-persist path on every
    /// keystroke, reordering the list under the cursor as `modified` updates.
    /// Edits land here first and sync to the store, which debounces the disk.
    @State private var draftBody = ""
    @State private var draftTitle = ""
    /// Which note `draftBody` belongs to, so switching notes doesn't write one
    /// note's text into another.
    @State private var draftNoteID: UUID?
    /// Local mirror of the open meeting note's speaker labels.
    ///
    /// A draft rather than a direct binding for the same reason `draftBody` is one, but
    /// with sharper teeth: committing a rename rewrites every matching heading in the
    /// transcript (`NoteStore.renameSpeaker`), so doing it per keystroke would rewrite
    /// the body once per letter typed — and "Ana" would arrive as three separate
    /// renames whose intermediate headings ("**A:**", "**An:**") the next keystroke
    /// could no longer find. Commits on submit and on losing focus instead.
    @State private var draftSpeakers = MeetingSpeakers.default
    /// Which label field has the caret, so a rename commits when the user clicks away
    /// instead of only on Return. Clicking straight into the transcript to read it is
    /// the common next move, and losing the rename there would look like the feature
    /// simply did not work.
    @FocusState private var focusedSpeaker: SpeakerRole?
    /// Whether the notes search field has the caret.
    ///
    /// Added for one reason: the field had no focus indication at all. It is not used
    /// for any behaviour — see `searchField`.
    @FocusState private var searchFocused: Bool
    /// The action currently running, if any. Gates the buttons so two actions
    /// can't rewrite the same note concurrently.
    @State private var runningAction: NoteAction?
    @State private var actionMessage: String?
    @State private var actionMessageIsError = false

    /// Meeting capture is owned by the app delegate — it needs the single shared
    /// microphone and transcriber.
    ///
    /// `@ObservedObject`, not a computed property: the session publishes `state`,
    /// `elapsed`, and `heardOthers`, and a plain `AppDelegate.current?.meetingSession`
    /// lookup would read those without subscribing, so the timer would tick and the
    /// recording indicator would never redraw.
    @ObservedObject private var meeting = AppDelegate.current?.meetingSession ?? MeetingSession()
    @State private var meetingMessage: String?

    private var groups: [NoteGroup] { store.grouped(matching: searchText) }

    var body: some View {
        HStack(alignment: .top, spacing: Space.x3) {
            noteList
                .frame(width: 260)
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { syncDraft(from: store.selectedNote) }
        // Switching notes in the list swaps the editor's contents. Flush the
        // outgoing note first so an unsynced keystroke isn't lost.
        // Adopt a change the store made underneath the editor.
        //
        // `draftBody` is a local mirror, and dictation does not go through it: ⌃⌥N and
        // meeting capture both append straight to `NoteStore`. With the Notes screen open on
        // the note being appended to, the editor kept showing the pre-dictation text — and
        // then `.onDisappear` ran `commitDraft()` + `writeToDisk()`, writing the stale mirror
        // back over the note and erasing the dictation from memory and from disk. Switching
        // tabs after dictating into an open note lost the dictation outright.
        //
        // Keyed on `draftNoteID`, not on the selection: a selection change alters the id and
        // the body in the same view update, and the firing order of two sibling `.onChange`
        // modifiers is not specified — so comparing against the note the draft actually
        // belongs to is what stops this pulling one note's text into another's draft.
        //
        // One narrow conflict remains and it resolves the safe way: text typed but not yet
        // debounced when an append lands is superseded by the store's copy. Losing a
        // keystroke or two beats losing the whole dictation, and typing into a note while
        // dictating into the same note is a genuinely conflicting instruction.
        .onChange(of: store.selectedNote?.body) { latest in
            guard let id = draftNoteID,
                  store.selectedNoteID == id,
                  let latest,
                  latest != draftBody else { return }
            draftBody = latest
        }
        .onChange(of: store.selectedNoteID) { _ in
            commitSpeakers()
            commitDraft()
            syncDraft(from: store.selectedNote)
        }
        // Focus left both label fields: commit. `nil` is the only case that matters —
        // moving between the two fields also fires here, and committing then is
        // harmless because the store ignores unchanged names.
        .onChange(of: focusedSpeaker) { focus in
            if focus == nil { commitSpeakers() }
        }
        .onDisappear { commitSpeakers(); commitDraft(); store.writeToDisk() }
    }

    // MARK: - List

    private var noteList: some View {
        BentoTile(
            title: "Notes",
            systemImage: "note.text",
            accessory: AnyView(
                GlassIconButton(systemName: "plus", label: "New note") {
                    commitDraft()
                    let note = store.create()
                    syncDraft(from: note)
                }
            )
        ) {
            meetingBar
            searchField

            if store.notes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No notes yet",
                    // Name the hotkey: it existed but appeared nowhere a user would
                    // look, so the feature was effectively undiscoverable.
                    message: "Start one here, press ⌃⌥N to dictate straight into Utter, "
                             + "or say \u{201C}start a new note\u{201D} while dictating.",
                    actionLabel: "New note"
                ) {
                    let note = store.create()
                    syncDraft(from: note)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else if groups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No matches",
                    message: "Nothing here matches “\(searchText)”."
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Space.x3) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: Space.x1) {
                                Text(group.label)
                                    .typo(.microLabel, ink: Ink.tertiary)
                                ForEach(group.notes) { note in
                                    NoteRow(
                                        note: note,
                                        isSelected: note.id == store.selectedNoteID
                                    ) {
                                        store.selectedNoteID = note.id
                                    } onDelete: {
                                        store.delete(id: note.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, Space.x1)
                }
                .frame(minHeight: 200, maxHeight: 460)
            }
        }
    }

    // MARK: - Meeting capture

    /// Start/stop control for meeting capture, plus an unmissable indicator while
    /// it runs.
    ///
    /// The indicator is not decoration. Recording a call captures other people's
    /// voices, so the app must make that state obvious at all times rather than
    /// leaving it to a menu-bar glyph the user isn't looking at. It also reports
    /// whether anything has actually been *heard* on the system tap — a silent tap
    /// looks exactly like a working one until someone speaks, and silently
    /// recording nothing for an hour is the worst outcome here.
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
                    Text("No audio from other participants yet — check the meeting isn’t muted or on a headset Utter can’t hear.")
                        .typo(.caption, ink: Tint.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .finishing:
                HStack(spacing: Space.x2) {
                    ProgressView().controlSize(.small)
                    Text("Finishing the transcript…").typo(.caption, ink: Ink.secondary)
                }

            case .failed(let why):
                // Show the reason *and* the button. A failure with no way to try
                // again reads as a dead feature — and the most common failure is
                // "permission not granted yet", which the user fixes and returns
                // from expecting to press the button once more.
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

            if let meetingMessage {
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
        meetingMessage = nil

        // Explain and request before starting, rather than letting the capture fail
        // at the moment the user expects it to be recording. Shared with the offer
        // card's path — see `MeetingSession.prepare`, which exists because these two
        // had already drifted apart on what a denial means.
        if let why = MeetingSession.prepare() {
            meetingMessage = why
            return
        }

        Task { @MainActor in
            let id = await meeting.start(
                recorder: delegate.audioRecorder,
                transcriber: delegate.transcriptionService
            )
            if let id {
                store.selectedNoteID = id
                syncDraft(from: store.notes.first { $0.id == id })
            }
        }
    }

    /// The notes search field.
    ///
    /// **Still hand-rolled, and that is a handoff rather than a decision.**
    /// `GlassTextField` is the app's field and `HomeView`'s copy of this has now been
    /// replaced by it — but this one carries a clear button, which the component has
    /// no parameter for. Adopting it as-is would delete that button, and adding a
    /// fourth copy of the *well* to keep it is what produced the drift in the first
    /// place. `GlassTextField` needs a `trailingAccessory` (or an
    /// `onClear: (() -> Void)?`) variant; it lives in `DesignSystem/GlassControls.swift`,
    /// which another change owns, so the request is in the report.
    ///
    /// What is fixed here and now is the part that was not drift: **there was no focus
    /// ring**. A keyboard user tabbing into the search field got no indication of it.
    /// The ring below is `GlassTextField`'s, value for value — `Tint.accent.opacity(0.7)`
    /// at 1.5pt, animated on `Motion.hoverIn` (`GlassTextField`) — so
    /// adopting the variant later is a deletion, not a redesign.
    private var searchField: some View {
        HStack(spacing: Space.x2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Ink.secondary)
            TextField("Search notes", text: $searchText)
                .textFieldStyle(.plain)
                .typo(.callout)
                .focused($searchFocused)
            if !searchText.isEmpty {
                // `IconButton`, not `GlassIconButton`.
                //
                // `GlassIconButton` is a *chrome* control: since it gained a persistent
                // `glassEffect(.regular.interactive(), in: Circle())` — the rest state
                // `.interactive()` needs in order to have anything to modulate — it
                // draws glass whether or not the pointer is on it. Two things follow
                // and both are wrong here. It is 28×28 inside a well pinned to 26,
                // so the disc protrudes a point top and bottom; and it puts glass
                // *inside* a `Surface.sunken` text field, which is the content layer.
                // GlassSurface.swift is explicit that glass belongs to chrome and
                // "no paragraph of text is ever asked to sit on a surface that warps
                // what's behind it" — a field is that surface.
                //
                // `IconButton` is the content-layer equivalent and already the app's
                // answer: 26×26, so it sits flush in the well, and a plain
                // `Surface.fillHover` wash on hover instead of a material.
                IconButton(systemName: "xmark.circle.fill", label: "Clear search") {
                    searchText = ""
                }
            }
        }
        .padding(.horizontal, Space.x2)
        .frame(height: 26)
        .background(Radius.rect(Radius.field).fill(Surface.sunken))
        .overlay(
            Radius.rect(Radius.field).strokeBorder(
                searchFocused ? Tint.accent.opacity(0.7) : Line.hairline,
                lineWidth: searchFocused ? 1.5 : Line.width
            )
        )
        .animation(Motion.hoverIn, value: searchFocused)
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let note = store.selectedNote {
            BentoTile(
                title: nil,
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
                        Text(wordLabel(for: draftBody))
                            .typo(.caption, ink: Ink.tertiary)
                            .monospacedDigit()
                        if note.source == .dictated {
                            GlassChip(text: "dictated", systemImage: "mic")
                        }
                        GlassIconButton(systemName: "doc.on.doc", label: "Copy note") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(draftBody, forType: .string)
                        }
                        .disabled(draftBody.isEmpty)
                        GlassIconButton(systemName: "square.and.arrow.up", label: "Export as Markdown") {
                            exportMarkdown(note)
                        }
                        .disabled(draftBody.isEmpty)
                    }
                )
            ) {
                TextField(note.displayTitle, text: $draftTitle)
                    .textFieldStyle(.plain)
                    .typo(.serifHeading)
                    .onSubmit { commitDraft() }

                Text(dateLine(for: note))
                    .typo(.caption, ink: Ink.tertiary)

                if note.source == .meeting {
                    speakerBar(for: note)
                }

                GlassTextEditor(text: $draftBody, minHeight: 360)
                    .onChange(of: draftBody) { _ in scheduleSync() }

                actionBar(for: note)
            }
        } else {
            BentoTile(title: nil) {
                EmptyStateView(
                    icon: "note.text",
                    title: "Nothing selected",
                    message: "Pick a note on the left, or press + to start a new one."
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            }
        }
    }

    // MARK: - Speaker labels

    /// Rename the two capture sources on a meeting note.
    ///
    /// This exists because Utter genuinely cannot work out who is talking, and the
    /// honest response to that is to hand the naming to the person who was in the
    /// meeting rather than to guess. The microphone is one known person; system audio
    /// is every remote participant already mixed into one stream by the conferencing
    /// app, so "Others" is the most specific thing a *measurement* supports. The
    /// caption says so rather than leaving the user to discover it from a transcript
    /// that merged two colleagues under one name.
    @ViewBuilder
    private func speakerBar(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: Space.x1) {
            HStack(spacing: Space.x2) {
                Image(systemName: "person.wave.2")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.tertiary)
                speakerField(role: .you, note: note)
                speakerField(role: .others, note: note)
                Spacer(minLength: 0)
            }
            Text("Utter labels your microphone and the call’s audio separately. It can’t tell two "
                 + "people in the call apart, so rename the second label only if one person was speaking.")
                .typo(.caption, ink: Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One label field, styled like the search field so the two read as the same kind
    /// of control.
    ///
    /// This one genuinely cannot be `GlassTextField`: the component owns its focus in a
    /// `private @FocusState` (`GlassTextField.isFocused`), and this field's focus is *load
    /// bearing* — `focusedSpeaker` going `nil` is what commits a rename when the user
    /// clicks away (`onChange(of: focusedSpeaker)`, and see `commitSpeakers`). Handing
    /// that to a component that keeps its focus private would lose every rename not
    /// finished with Return. So the ring is drawn here off the focus state that already
    /// exists, with `GlassTextField`'s own values; the component needs an optional
    /// external focus binding before this can converge, which is in the report.
    @ViewBuilder
    private func speakerField(role: SpeakerRole, note: Note) -> some View {
        TextField(
            MeetingSpeakers.default[role],
            text: Binding(get: { draftSpeakers[role] }, set: { draftSpeakers[role] = $0 })
        )
        .textFieldStyle(.plain)
        .typo(.callout)
        .accessibilityLabel(role == .you ? "Name for your microphone"
                                         : "Name for the call’s audio")
        .focused($focusedSpeaker, equals: role)
        .onSubmit { commitSpeakers() }
        .frame(width: 130)
        .padding(.horizontal, Space.x2)
        .frame(height: 24)
        .background(Radius.rect(Radius.field).fill(Surface.sunken))
        .overlay(
            Radius.rect(Radius.field).strokeBorder(
                focusedSpeaker == role ? Tint.accent.opacity(0.7) : Line.hairline,
                lineWidth: focusedSpeaker == role ? 1.5 : Line.width
            )
        )
        .animation(Motion.hoverIn, value: focusedSpeaker)
    }

    /// Apply both label drafts to the open note.
    ///
    /// Keyed off `draftNoteID` rather than a passed-in note, so this composes into the
    /// existing commit points (`onChange(of: selectedNoteID)`, `onDisappear`) the same
    /// way `commitDraft` does — those fire *after* the selection has already moved on,
    /// and renaming the newly selected note would be a real corruption rather than a
    /// lost keystroke.
    private func commitSpeakers() {
        guard let id = draftNoteID, store.notes.contains(where: { $0.id == id }) else { return }
        // Push the editor's text through first: `renameSpeaker` rewrites the stored
        // body, and an uncommitted keystroke would be overwritten when the editor
        // adopts the store's copy.
        commitDraft()
        for role in SpeakerRole.allCases {
            store.renameSpeaker(role, to: draftSpeakers[role], in: id)
        }
        // Blank or unchanged names are ignored by the store, so pull the authoritative
        // labels back rather than leaving an emptied field looking accepted.
        draftSpeakers = store.notes.first { $0.id == id }?.speakerLabels ?? .default
    }

    // MARK: - AI actions

    /// The on-device document actions, plus whatever the last one had to say.
    ///
    /// Feedback is shown inline rather than in an alert: three of the five outcomes
    /// are "nothing happened, and here is why", and an alert for that is heavier
    /// than the information deserves.
    @ViewBuilder
    private func actionBar(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            // Wraps rather than clipping: five labelled buttons come to roughly
            // 685pt against a ~700pt editor column at the default window size, so
            // a narrower window or larger system text would cut the last one off.
            // Same layout the placeholder chips use.
            FlowLayout(spacing: Space.x2) {
                ForEach(NoteAction.allCases) { action in
                    GlassButton(title: action.title, systemImage: action.systemImage) {
                        run(action, on: note.id)
                    }
                    .disabled(runningAction != nil || draftBody.isEmpty)
                }
            }

            if let runningAction {
                HStack(spacing: Space.x2) {
                    ProgressView().controlSize(.small)
                    Text(runningAction.runningLabel).typo(.caption, ink: Ink.secondary)
                }
            } else if let actionMessage {
                Text(actionMessage)
                    .typo(.caption, ink: actionMessageIsError ? Tint.dangerText : Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func run(_ action: NoteAction, on id: UUID) {
        // Push the editor's text into the store first: the action reads the note
        // from the store, so an uncommitted keystroke would be invisible to it.
        commitDraft()
        runningAction = action
        actionMessage = nil

        Task { @MainActor in
            let result = await NoteActionRunner.run(action, noteID: id)
            runningAction = nil
            switch result {
            case .applied:
                actionMessageIsError = false
                actionMessage = nil
                // The action rewrote the note, so refresh the editor from the store.
                syncDraft(from: store.notes.first { $0.id == id })
            case .nothingToDo(let why):
                actionMessageIsError = false
                actionMessage = why
            case .rejected(let why):
                actionMessageIsError = true
                actionMessage = why
            case .unavailable(let why):
                actionMessageIsError = true
                actionMessage = why
            }
        }
    }

    // MARK: - Export

    /// Save the note as a `.md` file. Markdown because the AI actions already emit
    /// it, so an exported note keeps its structure in any editor.
    private func exportMarkdown(_ note: Note) {
        commitDraft()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = safeFilename(for: note) + ".md"
        panel.allowedContentTypes = [.init(filenameExtension: "md")].compactMap { $0 }
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Lead with the title as an H1 so the file stands alone; the body may or
        // may not repeat it, and a document with no heading reads as a fragment.
        let contents = "# \(note.displayTitle)\n\n\(draftBody)\n"
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            actionMessageIsError = true
            actionMessage = "Couldn’t save that file: \(error.localizedDescription)"
        }
    }

    /// A filename that survives the filesystem: no separators, no leading dot.
    private func safeFilename(for note: Note) -> String {
        let base = note.displayTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(base.prefix(80))
        return trimmed.isEmpty || trimmed.hasPrefix(".") ? "Note" : trimmed
    }

    private func wordLabel(for text: String) -> String {
        let count = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        return count == 1 ? "1 word" : "\(count) words"
    }

    private func dateLine(for note: Note) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        let edited = fmt.string(from: note.modified)
        return note.source == .meeting ? "Meeting · \(edited)" : "Edited \(edited)"
    }

    // MARK: - Draft syncing

    private func syncDraft(from note: Note?) {
        draftNoteID = note?.id
        draftBody = note?.body ?? ""
        draftSpeakers = note?.speakerLabels ?? .default
        // Only show a title the user actually chose.
        //
        // Keying off `titleIsCustom` rather than emptiness: `create(body:)` stores a
        // *derived* title, which is non-empty with `titleIsCustom == false`. Loading
        // that into the field meant the next body keystroke ran `commitDraft` →
        // `updateTitle(<derived text>)` → `titleIsCustom = true`, silently pinning
        // the title to whatever the first line happened to be at creation. Rewriting
        // the body then left the old title in the list forever.
        //
        // The placeholder shows the derived title, so the field still reads as
        // populated — it just isn't owned by the user until they type in it.
        draftTitle = (note?.titleIsCustom ?? false) ? (note?.title ?? "") : ""
    }

    private func scheduleSync() {
        // The store already debounces its own disk writes, so pushing on every
        // keystroke is cheap and keeps the list preview current.
        commitDraft()
    }

    private func commitDraft() {
        guard let id = draftNoteID, store.notes.contains(where: { $0.id == id }) else { return }
        store.updateBody(draftBody, for: id)
        store.updateTitle(draftTitle, for: id)
    }
}

/// One row in the notes list.
///
/// `GlassSelectableRow` (GlassControls.swift), not a fourth hand-rolled
/// selection. A notes list *is* the picker for the editor beside it, which is exactly
/// the semantics that component describes, and it was previously used in one place in
/// the whole app (`DiagnosticsView`) while three screens rolled their own. Converging
/// costs nothing structurally: this row was already a `Button` with
/// `.buttonStyle(.plain)` wrapping a `GlassIconButton`, and that is precisely what
/// `GlassSelectableRow` is, so nesting depth is unchanged.
///
/// Two defects went with it.
///
/// **The hover was the only unanimated row hover in the app** — a bare
/// `.onHover { isHovering = $0 }`, so the wash snapped on and off while every other
/// row type in Utter crosses it on `Motion.hoverIn`/`hoverOut`. The component does
/// that itself.
///
/// **The trash button was conditionally inserted**, where `WordRow`, `SnippetRow`,
/// `CustomCommandRow` and `HistoryRow` all fade theirs with `.opacity(isHovering ? 1 : 0)`.
/// So in Notes alone the icon popped into existence — and it took the row's layout with
/// it, since appearing claimed 28pt the title had been using. It now holds its slot and
/// fades, which is both the app's pattern and the reason `HistoryRow` gives for its own
/// fixed-width action column.
///
/// The local `isHovering` survives only to drive that fade; the component keeps its own
/// hover state private, so the two track the same region independently. Noted in the
/// report as something `GlassSelectableRow` could hand to its content builder.
private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        GlassSelectableRow(isSelected: isSelected, action: onSelect) {
            HStack(alignment: .top, spacing: Space.x2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .typo(.callout)
                        .lineLimit(1)
                    if let preview = previewLine {
                        Text(preview)
                            .typo(.caption, ink: Ink.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Space.x1)
                GlassIconButton(systemName: "trash", label: "Delete note",
                                tint: Tint.danger, action: onDelete)
                    .opacity(isHovering ? 1 : 0)
            }
            .onHover { hovering in
                withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) {
                    isHovering = hovering
                }
            }
        }
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

    // `rowBackground` is gone: `GlassSelectableRow` draws it.
    //
    // Its doc comment argued against *tinted glass* behind a label, measured at
    // 1.17:1 — and that argument still holds, which is why the replacement is not
    // glass either. `GlassSelectableRow` reaches the same conclusion in its own note
    // ("Selection is an accent wash plus a rim, not tinted glass: tinted glass behind
    // a label measured 1.17:1"), so nothing that measurement bought is being given
    // back. The selection changes appearance: a neutral white lift becomes the accent
    // wash every other selectable row in the app uses.
}
