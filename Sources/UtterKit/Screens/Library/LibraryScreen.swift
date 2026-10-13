import AppKit
import SwiftUI
import UtterCore

/// Library's main column: today's tape, then each day's tracks on the rules, Side A and Side B for Everything.
struct LibraryScreen: View {
    let window: MainWindowModel
    @ObservedObject private var userData: UserData

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool
    @State private var viewport: CGFloat = 0

    init(window: MainWindowModel) {
        self.window = window
        userData = window.userData
    }

    private var model: LibraryViewModel { window.library }
    private var query: String { model.search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var twoSides: Bool { model.filter == .all && query.isEmpty }

    var body: some View {
        let tapes = model.tapes
        VStack(spacing: 0) {
            tape(tapes[Calendar.current.startOfDay(for: .now)] ?? [])
                .padding(.top, 16)
            list(model.days, tapes: tapes)
        }
        .overlay(alignment: .bottom) { undoBar }
        // AppKit hands a new window's first focus to its first text field, the search line; the tracks come first.
        .onAppear { DispatchQueue.main.async { listFocused = true } }
        .alert("Export failed", isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    // MARK: Tape

    private func tape(_ today: [LibraryItem]) -> some View {
        let dictated = today.filter { $0.kind == .dictation }.reduce(0) { $0 + $1.words }
        let segments = today.map { TapeSegment(id: $0.id, words: $0.words, label: $0.title) }
            + TapeSegment.unkept(userData.unkeptWordsToday(onTape: dictated), id: Self.unkeptID)
        return TapeStripe(status: stripeStatus, segments: segments, goal: userData.tapeGoal, selected: model.selectedID,
                          insets: EdgeInsets(top: 0, leading: 34, bottom: 0, trailing: 30)) { id in
            if id != Self.unkeptID { model.selection.open(libraryItem: id) }
        }
    }

    private static let unkeptID = "unkept"

    private var stripeStatus: TapeStripe<String>.Status {
        if window.status.turn == .listening || model.meetingState == .recording { return .recording }
        return window.setup.needs.isEmpty ? .ready : .setup
    }

    // MARK: List

    private func list(_ days: [LibraryViewModel.Day], tapes: [Date: [LibraryItem]]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    notices
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            dayBlock(day, tape: tapes[day.id] ?? [], first: index == 0)
                        }
                    }
                    if days.isEmpty { searchEmpty.padding(.top, 22) }
                    HStack(spacing: 34) {
                        RuledBackground()
                        if twoSides { RuledBackground() }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.leading, 34)
                .padding(.trailing, 30)
                .frame(minHeight: viewport, alignment: .top)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onMoveCommand(perform: move)
            .onDeleteCommand { if let item = model.selectedItem { model.delete(item) } }
            .background {
                // ⌘ combos reach SwiftUI as key equivalents, never onKeyPress; off unless the list has focus, so editors keep ⌘⌫.
                Button("Delete Track") { if let item = model.selectedItem { model.delete(item) } }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(!listFocused || model.selectedItem == nil)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
            .onKeyPress(.return) {
                guard let item = model.selectedItem, item.kind == .dictation, window.setup.readiness.ax else { return .ignored }
                model.pasteAgain(item)
                return .handled
            }
            .onCopyCommand {
                guard let item = model.selectedItem else { return [] }
                model.copy(item)
                return [NSItemProvider(object: item.body as NSString)]
            }
            .onExitCommand { model.selectedID = nil }
            .onChange(of: model.selectedID, initial: true) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let meeting = model.meeting {
            MeetingNote(meeting: meeting, message: model.meetingMessage, retry: model.startMeeting, stop: model.stopMeeting)
        }
        let needs = window.setup.needs
        if let need = needs.first {
            InkNote(Text(SetupNeeds.cardTitle(needs.count)).bold().foregroundStyle(Mixtape.ink) + Text(" \(need.sentence)")) {
                if case .model(let fraction?) = need {
                    ProgressView(value: fraction)
                        .frame(width: 120)
                        .tint(Mixtape.ink)
                        .accessibilityLabel("Downloading the speech model")
                } else {
                    Button(need.actionTitle) { window.setup.grant(need) }
                        .buttonStyle(.pen(.fill, .small))
                        .accessibilityHint(need.sentence)
                }
            }
            .padding(.top, 18)
        } else if let upgrade = window.setup.upgrade {
            InkNote(Text("This Mac can run \(upgrade.displayName).").bold().foregroundStyle(Mixtape.ink)
                    + Text(" \(window.setup.device.recommendationReason)")) {
                if case .downloading(let fraction) = window.setup.upgradeState {
                    ProgressView(value: fraction)
                        .frame(width: 120)
                        .tint(Mixtape.ink)
                        .accessibilityLabel("Downloading \(upgrade.displayName)")
                } else {
                    Button("Download \(upgrade.displayName) \u{00B7} \(upgrade.sizeMB) MB", action: window.setup.downloadUpgrade)
                        .buttonStyle(.pen(.fill, .small))
                    Button("Not now", action: window.setup.declineUpgrade)
                        .buttonStyle(.pen(.ghost, .small))
                }
            }
            .padding(.top, 18)
        }
    }

    private func dayBlock(_ day: LibraryViewModel.Day, tape: [LibraryItem], first: Bool) -> some View {
        let isToday = Calendar.current.isDateInToday(day.id)
        return VStack(alignment: .leading, spacing: 0) {
            Text(LibraryViewModel.dayTitle(day.id))
                .mixtapeCaps(isToday ? 30 : 22, tracking: 0.02)
                .padding(.top, first ? 22 : 44)
                .accessibilityAddTraits(.isHeader)
            Text(LibraryViewModel.summary(tape) + (isToday ? ", all on this Mac" : ""))
                .font(Mixtape.body(13))
                .foregroundStyle(Mixtape.ink3)
                .padding(.top, 7)
            Group {
                if day.items.isEmpty {
                    tapeEmpty
                } else if twoSides {
                    let morning = day.items.filter(\.isMorning)
                    let later = day.items.filter { !$0.isMorning }
                    HStack(alignment: .top, spacing: 34) {
                        side("Side A", detail: "morning · \(morning.count)", morning, tape: tape)
                        side("Side B", detail: "afternoon and evening · \(later.count)", later, tape: tape)
                    }
                } else {
                    side(query.isEmpty ? model.filter.title : "Found", detail: "\(day.items.count)", day.items, tape: tape)
                }
            }
            .padding(.top, 22)
        }
    }

    private func side(_ title: String, detail: String, _ items: [LibraryItem], tape: [LibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader(title, detail: detail)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    row(item, number: (tape.firstIndex { $0.id == item.id } ?? 0) + 1)
                }
            }
            .background(alignment: .top) { RuledBackground() }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func row(_ item: LibraryItem, number: Int) -> some View {
        if item.id == model.freshID { track(item, number: number).modifier(WriteOn()) } else { track(item, number: number) }
    }

    private func track(_ item: LibraryItem, number: Int) -> some View {
        TrackRow(number: number, title: item.title, time: LibraryViewModel.clock(item.talkTime),
                 selected: item.id == model.selectedID, ticked: model.pastedIDs.contains(item.id),
                 emphasized: item.kind == .meeting, highlight: query)
            .id(item.id)
            .onTapGesture {
                listFocused = true
                model.selectedID = item.id
            }
            .contextMenu { menu(item) }
            .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: -6)), removal: .opacity))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                listFocused = true
                model.selectedID = item.id
            }
    }

    @ViewBuilder
    private func menu(_ item: LibraryItem) -> some View {
        Button("Copy") { model.copy(item) }.keyboardShortcut("c")
        if item.kind == .dictation, let entry = model.entries.first(where: { $0.id == item.uuid }) {
            Button("Paste Again") { model.pasteAgain(item) }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!window.setup.readiness.ax)
            Button("Convert to Note") { model.convertToNote(entry) }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(item) }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(!model.canDelete(item))
    }

    /// Arrow keys step through the tracks in the order they're shown; keyboard moves never animate.
    private func move(_ direction: MoveCommandDirection) {
        let items = model.days.flatMap(\.items)
        guard !items.isEmpty, direction == .up || direction == .down else { return }
        let index = items.firstIndex { $0.id == model.selectedID }
        let next = direction == .up ? max((index ?? 1) - 1, 0) : min((index ?? -1) + 1, items.count - 1)
        withTransaction(\.disablesAnimations, true) { model.selectedID = items[next].id }
    }

    // MARK: Empty states

    @ViewBuilder
    private var tapeEmpty: some View {
        switch model.filter {
        case .meetings:
            TapeNote(title: "No meetings yet", message: "Record a meeting and Utter writes down what you and the others say.") {
                Button("Record a meeting", action: model.startMeeting).buttonStyle(.pen(.outline, .small)).disabled(!model.canStartMeeting)
            }
        case .notes:
            TapeNote(title: "No notes yet", message: "Write one here, or press \(KeyChord.noteCapture.symbols) to talk into a new note.") {
                Button("New note", action: model.newNote).buttonStyle(.pen(.outline, .small))
            }
        case .all, .dictations:
            TapeNote(title: "Nothing on this tape yet",
                     message: "Hold \(userData.hotkeyName) and talk in any app; every track lands here.") {}
        }
    }

    private var searchEmpty: some View {
        TapeNote(title: "Nothing matches \u{201C}\(query)\u{201D}",
                 message: "Utter looks through every track, note and meeting on this Mac.") {
            Button("Clear search") { model.search = "" }.buttonStyle(.pen(.ghost, .small))
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let item = model.pendingDelete {
            HStack(spacing: 14) {
                Text("Deleted \u{201C}\(item.title)\u{201D}")
                    .font(Mixtape.body(12.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button(action: model.undoDelete) {
                    HStack(spacing: 6) {
                        Text("Undo").mixtapeCaps(11, tracking: 0.1)
                        Text("\u{2318}Z").font(Mixtape.mono(11)).opacity(0.7)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("z")
            }
            .foregroundStyle(Mixtape.paper)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(Mixtape.ink, in: Capsule())
            .padding(.bottom, 16)
            .frame(maxWidth: 420)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// A bold line and a quiet one, where a list or the fold has nothing to show.
struct TapeNote<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).fontWeight(.semibold).foregroundStyle(Mixtape.ink2)
            Text(message).foregroundStyle(Mixtape.ink3).fixedSize(horizontal: false, vertical: true)
            action.padding(.top, 9)
        }
        .font(Mixtape.body(12.5))
        .lineSpacing(2)
        .padding(.vertical, 20)
        .frame(maxWidth: 360, alignment: .leading)
    }
}

// MARK: - Fold

/// The right pane: the chosen track with Paste again, Copy and More.
struct LibraryFold: View {
    let window: MainWindowModel

    var body: some View {
        Group {
            if let item = window.library.selectedItem {
                FoldContent(window: window, item: item).id(item.id)
            } else {
                TapeNote(title: "Choose a track", message: "It opens here with Paste again and Copy.") { LibraryKeys() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(EdgeInsets(top: 24, leading: 26, bottom: 24, trailing: 26))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Mixtape.fold)
        .overlay(alignment: .leading) {
            FoldEdge()
                .stroke(Mixtape.rule2, style: StrokeStyle(lineWidth: 1.5, dash: [4.5, 3]))
                .frame(width: 1.5)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Details")
    }

    private struct FoldEdge: Shape {
        func path(in rect: CGRect) -> Path {
            Path { $0.addLines([CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY)]) }
        }
    }
}

/// Reads `item` rather than the selection, so it keeps its content while the selection changes.
private struct FoldContent: View {
    let window: MainWindowModel
    let item: LibraryItem

    @State private var renaming = false
    @State private var addedName: String?
    @FocusState private var titleFocused: Bool
    @FocusState private var focusedSpeaker: SpeakerRole?

    private var model: LibraryViewModel { window.library }
    private var note: Note? { item.kind == .dictation ? nil : model.notes.first { $0.id == item.uuid } }
    private var entry: TranscriptionEntry? { item.kind == .dictation ? model.entries.first { $0.id == item.uuid } : nil }

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            heading
            meta.padding(.top, 8)
            status
            text.padding(.top, 12)
            buttons.padding(.top, 20)
            heardName
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $model.namingSpeakers) { speakers }
        .onAppear {
            if let note { model.edit(note) }
            window.words.refreshSuggestions()
        }
        .onChange(of: focusedSpeaker) { if focusedSpeaker == nil { model.commitSpeakers() } }
        .onDisappear { model.commitSpeakers() }
    }

    @ViewBuilder
    private var heading: some View {
        @Bindable var model = model
        if renaming, let note {
            TextField(note.displayTitle, text: $model.titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .focused($titleFocused)
                .onSubmit { renaming = false }
                .onChange(of: titleFocused) { if !titleFocused { renaming = false } }
                .onAppear { titleFocused = true }
                .accessibilityLabel("Title")
        } else {
            Text(note?.displayTitle ?? item.heading)
                .mixtapeCaps(18, tracking: 0.01)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .onTapGesture(count: 2) { if note != nil { renaming = true } }
        }
    }

    private var meta: some View {
        let number = LibraryViewModel.trackNumber(item, in: model.tapes)
        let words = item.words == 1 ? "1 word" : "\(item.words) words"
        return Text("Track \(String(format: "%02d", number)) · \(item.destination)\n"
                    + "\(item.date.formatted(date: .omitted, time: .shortened)) · \(LibraryViewModel.clock(item.talkTime)) · \(words)")
            .font(Mixtape.mono(11.5, .semibold))
            .foregroundStyle(Mixtape.ink3)
            .lineSpacing(3)
    }

    @ViewBuilder
    private var status: some View {
        if note != nil {
            if let running = model.runningAction {
                Label(running.runningLabel, systemImage: "sparkles")
                    .font(Mixtape.body(12.5))
                    .foregroundStyle(Mixtape.ink2)
                    .padding(.top, 10)
            } else if let message = model.actionMessage {
                Text(message)
                    .font(Mixtape.body(12.5))
                    .foregroundStyle(model.actionFailed ? Mixtape.red : Mixtape.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var text: some View {
        if let note, note.source == .meeting, !model.editingTranscript {
            fitting { turns }
        } else if let note {
            TextEditor(text: model.body(of: note))
                .font(Mixtape.body(16.5))
                .foregroundStyle(Mixtape.penInk)
                .lineSpacing(14)
                .scrollContentBackground(.hidden)
                .padding(.leading, -5)
                .frame(minHeight: 3 * Mixtape.ruleSpacing, maxHeight: .infinity)
                .accessibilityLabel("Note text")
        } else {
            fitting {
                Text(item.body)
                    .font(Mixtape.body(16.5))
                    .foregroundStyle(Mixtape.penInk)
                    .lineSpacing(14.3)
                    .textSelection(.enabled)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .top) { RuledBackground() }
            }
        }
    }

    /// The text at its own height when it fits, so the buttons follow it; scrolling when it doesn't.
    private func fitting(@ViewBuilder _ content: () -> some View) -> some View {
        let content = content()
        return ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
    }

    private var turns: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(item.turns) { turn in
                let isYou = turn.speaker == note?.speakerLabels.you
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(turn.speaker ?? "")
                        .mixtapeCaps(10.5, tracking: 0.14)
                        .foregroundStyle(isYou ? Mixtape.red : Mixtape.ink3)
                        .lineLimit(1)
                        .frame(width: 58, alignment: .leading)
                    Text(turn.text)
                        .font(Mixtape.body(14))
                        .foregroundStyle(isYou ? Mixtape.ink : Mixtape.ink2)
                        .lineSpacing(17)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 8.5)
                .accessibilityElement(children: .combine)
            }
        }
        .textSelection(.enabled)
        .background(alignment: .top) { RuledBackground() }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if item.kind == .dictation {
                let ax = window.setup.readiness.ax
                Button("Paste again") { model.pasteAgain(item) }
                    .buttonStyle(.pen(.fill))
                    .disabled(!ax)
                    .help(ax ? "Types it again into the app you were using (\u{21A9})" : "Allow Accessibility so Utter can paste")
            }
            Button(model.copiedID == item.id ? "Copied" : "Copy") { model.copy(item) }
                .buttonStyle(.pen())
                .help("Copy (\u{2318}C)")
            more
            Button { model.delete(item) } label: { Image(systemName: "trash") }
                .buttonStyle(.inkIcon)
                .disabled(!model.canDelete(item))
                .help("Delete (\u{232B})")
                .accessibilityLabel("Delete")
        }
    }

    private var more: some View {
        Menu {
            if let entry {
                Button("Convert to Note") { model.convertToNote(entry) }
            }
            if let note {
                Button("Rename") { renaming = true }
                if note.source == .meeting {
                    Button(model.editingTranscript ? "Show Transcript" : "Edit as Text") { model.editingTranscript.toggle() }
                    Button("Rename Speakers\u{2026}") { model.namingSpeakers = true }
                }
                Menu("Improve") {
                    ForEach(NoteAction.allCases) { action in
                        Button { model.run(action, on: note) } label: { Label(action.title, systemImage: action.systemImage) }
                    }
                }
                .disabled(model.runningAction != nil || note.body.isEmpty)
            }
            ShareLink("Share", item: item.body)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(.inkIcon)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private var heardName: some View {
        if item.kind == .dictation {
            Group {
                if let addedName {
                    InkNote(Text(addedName).bold().foregroundStyle(Mixtape.ink) + Text(" is in your Words now."))
                } else if let name = window.words.heardName(in: item.body) {
                    InkNote(Text("Utter heard a new name, ") + Text(name).bold().foregroundStyle(Mixtape.ink)
                            + Text(". Add it to Words so it\u{2019}s always spelled right?")) {
                        Button("Add to Words") {
                            window.words.addWord(name)
                            addedName = name
                        }
                        .buttonStyle(.pen(.fill, .small))
                        Button("Not now") { window.words.decline(name) }
                            .buttonStyle(.pen(.ghost, .small))
                    }
                }
            }
            .padding(.top, 22)
        }
    }

    private var speakers: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename speakers").mixtapeCaps(15, tracking: 0.04).foregroundStyle(Mixtape.ink)
            speakerField(.you, label: "Your microphone")
            speakerField(.others, label: "The call")
            Text("Utter hears your microphone and the call separately. It can't tell two people in the call apart.")
                .font(Mixtape.body(12.5))
                .foregroundStyle(Mixtape.ink3)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done") { model.namingSpeakers = false }
                    .buttonStyle(.pen(.fill, .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(Mixtape.paper)
        .onDisappear { model.commitSpeakers() }
    }

    private func speakerField(_ role: SpeakerRole, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Mixtape.body(11.5, .semibold)).foregroundStyle(Mixtape.ink3).accessibilityHidden(true)
            TextField(label, text: Binding(get: { model.speakerDrafts[role] }, set: { model.speakerDrafts[role] = $0 }),
                      prompt: Text(MeetingSpeakers.default[role]))
                .accessibilityLabel(label)
                .focused($focusedSpeaker, equals: role)
                .onSubmit { model.commitSpeakers() }
                .inkLine()
        }
    }
}

// MARK: - Meeting note

/// The recording banner: while a call is recorded it says so, with the time and Stop.
private struct MeetingNote: View {
    @ObservedObject var meeting: MeetingSession
    let message: String?
    let retry: () -> Void
    let stop: () -> Void

    var body: some View {
        if meeting.state != .idle || message != nil {
            note.padding(.top, 18)
        }
    }

    @ViewBuilder
    private var note: some View {
        switch meeting.state {
        case .recording:
            InkNote(Text("Recording this meeting ").bold().foregroundStyle(Mixtape.ink)
                    + Text(String(format: "%d:%02d", meeting.elapsed / 60, meeting.elapsed % 60)).font(Mixtape.mono(12, .semibold))
                    + Text(meeting.heardOthers ? "" : "\nNothing heard from the others yet. Check the call isn't muted or on a headset Utter can't hear.")) {
                Button("Stop", action: stop).buttonStyle(.pen(.fill, .small))
            }
        case .finishing:
            InkNote(Text("Finishing the transcript"))
        case .failed(let why):
            InkNote(Text(why)) {
                Button("Try again", action: retry).buttonStyle(.pen(.outline, .small))
            }
        case .idle:
            InkNote(Text(message ?? ""))
        }
    }
}

/// The fold's empty state: the keys that work on the selected track.
private struct LibraryKeys: View {
    private static let keys: [([String], String)] = [
        (["\u{2191}", "\u{2193}"], "choose a track"),
        (["\u{21A9}"], "paste it again"),
        (["\u{2318}C"], "copy"),
        (["\u{232B}"], "delete"),
        (["\u{2318}Z"], "undo a delete"),
        (["\u{2318}N"], "new note"),
        (["\u{2318}F"], "search"),
        (["\u{2318}1", "\u{2318}4"], "switch lists"),
    ]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 7) {
            ForEach(Self.keys, id: \.1) { caps, label in
                GridRow {
                    HStack(spacing: 4) { ForEach(caps, id: \.self) { Keycap($0) } }
                    Text(label).foregroundStyle(Mixtape.ink3)
                }
            }
        }
        .font(Mixtape.body(12))
        .accessibilityElement(children: .combine)
    }
}
