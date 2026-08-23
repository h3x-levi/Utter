import SwiftUI

/// The Notes screen: a searchable list of notes beside an editor.
///
/// Replaces the old `ScratchpadView`, which was a single shared text buffer
/// (`UserData.scratchpad`) presented as "Notes" — writing a second note
/// overwrote the first. State now lives in `NoteStore`, so the sidebar rebuilding
/// this view on navigation no longer risks the text.
///
/// The list is a real `List(selection:)` with real `Section` headers, replacing a
/// `ScrollView` + `LazyVStack` + `GlassSelectableRow`. That one change is what
/// supplies row hover, the selection fill in the correct appearance, the focus ring,
/// arrow-key and type-select navigation, and the accessibility table role — the old
/// list had none of them beyond a hand-drawn hover wash, and `GlassSelectableRow`'s
/// own doc comment names this exact conversion ("`List(selection:)`/`.listStyle(.inset)`
/// retires this whole type") as the reason it should not survive.
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
    /// The action currently running, if any. Gates the buttons so two actions
    /// can't rewrite the same note concurrently.
    @State private var runningAction: NoteAction?
    @State private var actionMessage: String?
    @State private var actionMessageIsError = false
    /// The note a delete has been *asked for* but not yet confirmed.
    ///
    /// Every delete path parks an id here rather than calling `store.delete` directly,
    /// so there is exactly one place the destructive act can happen and exactly one
    /// confirmation in front of it. See the `.confirmationDialog` on `body`.
    @State private var pendingDeleteID: UUID?

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
        HSplitView {
            noteList
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 380,
                       maxHeight: .infinity, alignment: .top)
            editor
                .frame(minWidth: 420, maxWidth: .infinity,
                       maxHeight: .infinity, alignment: .top)
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
        // Unchanged by the move to `List(selection:)`, and deliberately so: the list's
        // selection binding *is* `store.selectedNoteID`, so this still fires however the
        // selection moved — a click, an arrow key, type-select, or `startMeeting`
        // selecting the note it just created. A `List` can also clear the selection,
        // which the old rows could not; that resolves safely, because `commitDraft` and
        // `commitSpeakers` are keyed on `draftNoteID` rather than on the new selection,
        // so the outgoing note is still written before the editor empties.
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
        // Deleting a note is irreversible from the UI. `NoteStore.delete` removes it and
        // the next *differing* save overwrites the single retained generation at
        // `notes.previous.json`, so the window in which a mistake is recoverable is
        // seconds wide and requires a text editor to reach. The previous affordance was a
        // trash button that faded in under the pointer on row hover, one click from gone.
        //
        // A real `.confirmationDialog` is the whole fix: the system supplies the sheet,
        // the destructive-role button styling, Escape-to-cancel, the default button, and
        // the VoiceOver announcement. This is not an undo system and does not pretend to
        // be one — see `deleteWarning`, which says so.
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeleteID
        ) { id in
            Button("Delete Note", role: .destructive) {
                store.delete(id: id)
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: { id in
            Text(deleteWarning(for: id))
        }
    }

    /// What the user is actually agreeing to.
    ///
    /// Names the note rather than saying "this item": the delete can be started from a
    /// context menu on a row that is *not* the selected one, so the title is the only
    /// thing that confirms the right note is about to go. And it states the absence of
    /// undo plainly instead of the softer "this cannot be undone", because Utter really
    /// has no undo here and a vague warning invites the user to assume otherwise.
    private func deleteWarning(for id: UUID) -> String {
        let title = store.notes.first { $0.id == id }?.displayTitle ?? "This note"
        return "“\(title)” will be removed. Utter has no undo for a deleted note."
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
            SystemSearchField(text: $searchText, prompt: "Search notes")

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
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else if groups.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No matches",
                    message: "Nothing here matches “\(searchText)”."
                )
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            } else {
                notesList
            }
        }
    }

    /// The notes themselves.
    ///
    /// `List(selection:)` bound straight to `store.selectedNoteID`. The store's
    /// published selection *is* the list's selection, so there is no second copy to
    /// keep in step and no `onSelect` closure to route through.
    ///
    /// `.inset`, not `.sidebar`: this list lives *inside* a `BentoTile`, which
    /// `BentoView.swift` documents as a content-layer surface, and the source-list
    /// appearance is drawn for the window's own vibrant sidebar — the app already has
    /// one of those in `FlowMainView`, and a second would read as a nested hierarchy
    /// that isn't there. `alternatesRowBackgrounds` is left off for the neighbouring
    /// reason: striping is a data-table treatment and this list is a picker.
    /// `.scrollContentBackground(.hidden)` stops the list painting its own background
    /// on top of the tile's material.
    private var notesList: some View {
        List(selection: $store.selectedNoteID) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.notes) { note in
                        NoteRow(note: note)
                            .tag(note.id)
                            .contextMenu {
                                // Where macOS puts a per-row destructive action. It
                                // names the row it was opened on, not the selection,
                                // which is the behaviour of every Mac list — and the
                                // reason `deleteWarning` repeats the title back.
                                Button("Delete Note", role: .destructive) {
                                    pendingDeleteID = note.id
                                }
                            }
                    }
                } header: {
                    // A real `Section` header. The system supplies the grouping — the
                    // inset placement, and VoiceOver announcing which group a row is
                    // in — while `Typo.microLabel` keeps the reference layout's
                    // small-tracked-caps signature. `NoteStore.dateLabel` already
                    // uppercases, so the two compose without a `.textCase` override.
                    Text(group.label).typo(.microLabel, ink: Ink.tertiary)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        // ⌫ on the focused list — the third of the three delete paths a Mac user
        // expects (context menu, Delete key, an explicit button), and it routes through
        // the same confirmation as the other two. `onDeleteCommand` is macOS-only and
        // needs no availability gate at this deployment target.
        .onDeleteCommand {
            if let id = store.selectedNoteID { pendingDeleteID = id }
        }
        // A floor, not a cap.
        //
        // The old `.frame(minHeight: 200, maxHeight: 460)` is why an enlarged window
        // left this list short with empty tile beneath it. `maxHeight: .infinity` fills
        // whatever height the parent hands down.
        //
        // The floor is not belt-and-braces: `FlowContent` (FlowMainView.swift) still
        // wraps every screen in a vertical `ScrollView`, which proposes an *unbounded*
        // height, and a `List` given an unbounded proposal resolves to its ideal — for a
        // one-note list, very short. Until that wrapper is removed for this screen (it
        // is in the report, and it is also what stops two scroll views nesting), 320pt
        // is what keeps the list usable.
        .frame(minHeight: 320, maxHeight: .infinity)
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

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        if let note = store.selectedNote {
            BentoTile(
                title: nil,
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
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
                        // The explicit, always-visible delete — a document's own
                        // destructive action, next to its other document actions,
                        // rather than an icon that materialises on row hover. It is
                        // enabled for an empty note too: an empty note is exactly the
                        // one a user most wants to get rid of.
                        //
                        // `GlassIconButton` already carries `.help(label)` and
                        // `.accessibilityLabel(label)`, so all three buttons here have a
                        // tooltip and a VoiceOver name without a call-site modifier.
                        GlassIconButton(systemName: "trash", label: "Delete note",
                                        tint: Tint.danger) {
                            pendingDeleteID = note.id
                        }
                    }
                )
            ) {
                // `.plain` is the right style *here* and is not a hand-drawn one:
                // this is the document's own heading, set in the editorial serif, and
                // no Mac document app puts a bezel around its title. The caret is the
                // focus indication, which is what a click into a title gives you
                // anyway. The bezeled `.roundedBorder` fields on this screen are the
                // *form* fields — the speaker labels below.
                TextField(note.displayTitle, text: $draftTitle)
                    .textFieldStyle(.plain)
                    .typo(.serifHeading)
                    .onSubmit { commitDraft() }

                metadata(for: note)

                if note.source == .meeting {
                    speakerBar
                }

                // Stays `GlassTextEditor`, and that is a decision with a cited reason
                // rather than an omission: `GlassControls.swift` records that macOS has
                // no `TextEditorStyle` at this deployment target (`.roundedBorder` is
                // `@available(macOS, unavailable)`, `.plain` is macOS 14.0+), so a bare
                // `TextEditor` would draw no bezel and, worse, no focus ring at all.
                // It already *is* a real `TextEditor`; the well around it is the part
                // the SDK cannot supply here.
                //
                // What changes is that it now grows. `minHeight` drops 360 → 200 and
                // becomes a floor rather than the editor's actual size, and the outer
                // flexible frame is what fills an enlarged window: the proposal passes
                // through the component's own `.frame(minHeight:)` to the `TextEditor`,
                // so the well grows with the text area instead of the text area
                // scrolling inside a fixed 360pt well.
                GlassTextEditor(text: $draftBody, minHeight: 200)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
            }
        }
    }

    /// The note's own facts, as real `LabeledContent`.
    ///
    /// Two label/value pairs rather than one interpolated sentence ("Edited Jun 21,
    /// 3:04 PM") and one unlabelled number in the tile header. `LabeledContent` is the
    /// system control for exactly this, and it earns its place twice: VoiceOver
    /// announces "Edited, Jun 21, 3:04 PM" as a single labelled item instead of reading
    /// a fragment, and the word count stops being a bare "142 words" floating beside the
    /// action buttons where nothing said what was being counted.
    ///
    /// `.fixedSize()` on each: `LabeledContent`'s automatic style spreads label and
    /// value to the full width it is offered, which is right in a `Form` and wrong in a
    /// metadata row where the two pairs should sit next to each other.
    private func metadata(for note: Note) -> some View {
        let dateLabel = note.source == .meeting ? "Meeting" : "Edited"
        return HStack(spacing: Space.x4) {
            LabeledContent(dateLabel, value: timestamp(note.modified))
                .fixedSize()
            LabeledContent("Words", value: wordCount(draftBody))
                .fixedSize()
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .font(Typo.caption.font)
        .foregroundStyle(Ink.tertiary)
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

    /// One label field: a `TextField` in the system rounded bezel.
    ///
    /// `.roundedBorder` replaces a hand-drawn `Surface.sunken` well plus an accent
    /// focus ring drawn off `focusedSpeaker`. The bezel draws its own focus ring, its
    /// own pointer response and its own Increase Contrast behaviour, and it samples the
    /// themed window behind it — none of which a themed rectangle can do. This is the
    /// light-theme complaint in miniature: the old well and the tile it sat on were
    /// nearly the same value, so the field read as a faint outline and gave no response
    /// to anything.
    ///
    /// Deliberately *not* `GlassTextField`, though it now renders identically (that
    /// component is exactly `TextField` + `.roundedBorder`). `GlassTextField` takes no
    /// external focus binding, and this field's focus is *load bearing* —
    /// `focusedSpeaker` going `nil` is what commits a rename when the user clicks away
    /// (`onChange(of: focusedSpeaker)`, and see `commitSpeakers`). `.focused` has to be
    /// applied to the `TextField` itself; on a wrapper that merely contains one it binds
    /// nothing, and every rename not finished with Return would be silently lost. The
    /// component needs an optional focus-binding parameter before this can converge,
    /// which is in the report.
    ///
    /// `.font`, not `.typo(.callout)`: `Typo.callout` carries `Ink.secondary`, and
    /// dimming editable text inside a native bezel is both wrong for the control and a
    /// contrast regression. The type scale is the part worth keeping.
    private func speakerField(role: SpeakerRole) -> some View {
        TextField(
            MeetingSpeakers.default[role],
            text: Binding(get: { draftSpeakers[role] }, set: { draftSpeakers[role] = $0 })
        )
        .textFieldStyle(.roundedBorder)
        .font(Typo.callout.font)
        .accessibilityLabel(role == .you ? "Name for your microphone"
                                         : "Name for the call’s audio")
        .focused($focusedSpeaker, equals: role)
        .onSubmit { commitSpeakers() }
        .frame(width: 130)
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

    /// Just the number. The word "Words" is the `LabeledContent` label now, so the
    /// singular/plural branch this used to carry has gone with the sentence form.
    private func wordCount(_ text: String) -> String {
        String(text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count)
    }

    private func timestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        return fmt.string(from: date)
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

/// One row in the notes list — content only.
///
/// Everything that used to be drawn here belongs to the enclosing
/// `List(selection:)` now: the row background, the hover wash, the selection fill in
/// the correct appearance, the focus ring, arrow-key and type-select navigation, and
/// the accessibility table role. So `GlassSelectableRow`, the `@State isHovering`,
/// the `.onHover { withAnimation { … } }` and the `.opacity(isHovering ? 1 : 0)` that
/// faded a trash button in and out are all gone, along with the two defects their doc
/// comment recorded — an unanimated hover, and a conditionally-inserted trash that
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
/// hover is a fine Mac convention — doing it with opacity alone is the defect, and
/// pairing an invisible trigger with an irreversible act (see `NotesView.deleteWarning`)
/// is the worst version of it.
///
/// The three replacements are the three a Mac user already knows, and all of them are
/// reachable by pointer, keyboard *and* VoiceOver, which the hover button never was:
/// right-click the row, press ⌫ with the list focused, or use the editor's own
/// always-visible trash button. All three go through one confirmation.
///
/// If a hover-revealed action is ever wanted back here for pointer discoverability,
/// hide the behaviour along with the pixels —
/// `.opacity(hovering ? 1 : 0).allowsHitTesting(hovering).accessibilityHidden(!hovering)`
/// — rather than relying on opacity to do it.
///
/// **The colours here are deliberately the system's, not the theme's.** `Ink.*` are
/// absolute themed values, and an absolute value cannot invert when the system fills
/// the row with the selection colour — the selected note's title would have stayed a
/// dark themed grey on an accent fill. The type scale (`Typo.*.font`) is the part of
/// the token that still applies; the foreground is left to the list for the title and
/// set to the semantic `.secondary` for the preview, both of which AppKit remaps for a
/// selected row.
private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.displayTitle)
                .font(Typo.callout.font)
                .lineLimit(1)
            if let preview = previewLine {
                Text(preview)
                    .font(Typo.caption.font)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        // The whole row width is the target, so a click or a hover lands anywhere on
        // it rather than only on the text.
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
/// This replaces a hand-drawn search control — a `Surface.sunken` well, a
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
/// with no delegate and no items — `App.swift` says so in as many words. `.searchable`
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
