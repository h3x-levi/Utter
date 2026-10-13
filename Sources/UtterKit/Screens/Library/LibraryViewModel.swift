import AppKit
import Combine
import SwiftUI
import UtterCore

/// One dictation, note or meeting: a track on Library's tape.
struct LibraryItem: Identifiable, Hashable {
    enum Kind { case dictation, note, meeting }

    struct Turn: Identifiable, Hashable {
        let id: Int
        let speaker: String?
        let text: String
    }

    static let dictationPrefix = "dictation-"
    static let notePrefix = "note-"
    static func dictationID(_ id: UUID) -> String { dictationPrefix + id.uuidString }
    static func noteID(_ id: UUID) -> String { notePrefix + id.uuidString }

    let id: String
    let uuid: UUID
    let kind: Kind
    let date: Date
    let title: String
    let body: String
    let words: Int
    /// Seconds of recorded speech, or how long a meeting ran; 0 when unknown.
    let duration: TimeInterval
    /// The app a dictation was typed into; empty when unknown.
    let app: String
    /// A meeting's label for the user's own microphone.
    let you: String?

    init(_ entry: TranscriptionEntry) {
        id = Self.dictationID(entry.id)
        uuid = entry.id
        kind = .dictation
        date = entry.timestamp
        title = entry.text
        body = entry.text
        words = entry.wordCount
        duration = entry.duration
        app = entry.app
        you = nil
    }

    init(_ note: Note) {
        id = Self.noteID(note.id)
        uuid = note.id
        kind = note.source == .meeting ? .meeting : .note
        date = note.source == .meeting ? note.created : note.modified
        title = note.displayTitle
        body = note.body
        words = note.wordCount
        duration = note.source == .meeting ? note.modified.timeIntervalSince(note.created) : 0
        app = ""
        you = note.source == .meeting ? note.speakerLabels.you : nil
    }

    var kindName: String {
        switch kind {
        case .dictation: "Dictation"
        case .note: "Note"
        case .meeting: "Meeting"
        }
    }

    /// Where the words went, for the fold's meta line.
    var destination: String {
        kind == .dictation && !app.isEmpty ? "Into \(app)" : kindName
    }

    /// Seconds of talk: the recorded length, or about 2.4 words a second when none was recorded.
    var talkTime: TimeInterval { duration > 0 ? duration : max(3, (Double(words) / 2.4).rounded()) }

    /// A note's title, or a dictation's first clause.
    var heading: String {
        guard kind == .dictation else { return title }
        let clause = title.split(whereSeparator: { ",.?!;:".contains($0) }).first?.trimmingCharacters(in: .whitespaces)
        return clause.flatMap { $0.isEmpty ? nil : $0 } ?? title
    }

    var isMorning: Bool { Calendar.current.component(.hour, from: date) < 12 }

    var turns: [Turn] { Self.turns(in: body) }

    /// A meeting body split at its `**Speaker:**` headings; lines without one join the turn above.
    static func turns(in body: String) -> [Turn] {
        var turns: [Turn] = []
        for line in body.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }) where !line.isEmpty && !line.hasPrefix("#") {
            if line.hasPrefix("**"), let close = line.range(of: ":**") {
                let speaker = String(line[line.index(line.startIndex, offsetBy: 2)..<close.lowerBound])
                let text = line[close.upperBound...].trimmingCharacters(in: .whitespaces)
                turns.append(Turn(id: turns.count, speaker: speaker, text: text))
            } else if let last = turns.last {
                turns[turns.count - 1] = Turn(id: last.id, speaker: last.speaker, text: last.text + "\n" + line)
            } else {
                turns.append(Turn(id: 0, speaker: nil, text: line))
            }
        }
        return turns
    }
}

@MainActor @Observable
final class LibraryViewModel {
    typealias Item = LibraryItem

    /// One day of tracks; `id` is the day's start and `items` run oldest first.
    struct Day: Identifiable {
        let id: Date
        var items: [Item]
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case markdown = "Markdown"
        case csv = "CSV"
        case text = "Plain Text"

        var id: String { rawValue }
        var fileExtension: String {
            switch self {
            case .markdown: "md"
            case .csv: "csv"
            case .text: "txt"
            }
        }
    }

    private(set) var entries: [TranscriptionEntry] = [] {
        didSet {
            if !oldValue.isEmpty, let newest = entries.max(by: { $0.timestamp < $1.timestamp }),
               !oldValue.contains(where: { $0.id == newest.id }) {
                freshID = Item.dictationID(newest.id)
            }
            rebuild()
        }
    }
    /// The dictation that just arrived; its row writes itself in once.
    private(set) var freshID: String?
    private(set) var notes: [Note] = [] {
        didSet {
            guard let patched = Self.replacingEditedNote(in: allItems, old: oldValue, new: notes) else { return rebuild() }
            allItems = patched
        }
    }
    private(set) var allItems: [Item] = []
    var search = ""
    private(set) var pendingDelete: Item?
    var titleDraft = "" { didSet { commitTitle() } }
    var speakerDrafts = MeetingSpeakers.default
    var namingSpeakers = false
    var editingTranscript = false
    private(set) var runningAction: NoteAction?
    private(set) var actionMessage: String?
    private(set) var actionFailed = false
    private(set) var meetingMessage: String?
    private(set) var copiedID: String?
    /// Tracks pasted again this session; they carry a drawn tick.
    private(set) var pastedIDs: Set<String> = []
    private(set) var meetingState: MeetingSession.State = .idle
    var problem: String?

    let meeting: MeetingSession?
    @ObservationIgnored let selection: SidebarSelection
    @ObservationIgnored private let history: TranscriptionHistory
    @ObservationIgnored private let store: NoteStore
    @ObservationIgnored private let prepareMeeting: () -> String?
    @ObservationIgnored private let startMeetingCapture: () async -> UUID?
    @ObservationIgnored private let runAction: (NoteAction, UUID) async -> NoteActionResult
    @ObservationIgnored private let paste: @MainActor (String) -> Void
    @ObservationIgnored private var draftNoteID: UUID?
    @ObservationIgnored private var watches: Set<AnyCancellable> = []
    @ObservationIgnored private var deleteTask: Task<Void, Never>?
    @ObservationIgnored private var copyTask: Task<Void, Never>?

    static let undoWindow: Duration = .seconds(6)

    init(selection: SidebarSelection, history: TranscriptionHistory, store: NoteStore,
         meeting: MeetingSession? = nil,
         prepareMeeting: (() -> String?)? = nil,
         startMeetingCapture: @escaping () async -> UUID? = { nil },
         runAction: ((NoteAction, UUID) async -> NoteActionResult)? = nil,
         paste: @escaping @MainActor (String) -> Void = LibraryViewModel.pasteIntoPreviousApp) {
        self.selection = selection
        self.history = history
        self.store = store
        self.meeting = meeting
        self.prepareMeeting = prepareMeeting ?? { MeetingSession.prepare() }
        self.startMeetingCapture = startMeetingCapture
        self.runAction = runAction ?? { await NoteActionRunner.run($0, noteID: $1, store: store) }
        self.paste = paste

        history.$entries.sink { [weak self] entries in
            MainActor.assumeIsolated {
                guard let self else { return }
                withAnimation(Self.arrival(from: self.entries.count, to: entries.count)) { self.entries = entries }
            }
        }.store(in: &watches)
        store.$notes.sink { [weak self] notes in
            MainActor.assumeIsolated {
                guard let self else { return }
                withAnimation(Self.arrival(from: self.notes.count, to: notes.count)) { self.notes = notes }
            }
        }.store(in: &watches)
        meeting?.$state.sink { [weak self] state in
            MainActor.assumeIsolated { self?.meetingState = state }
        }.store(in: &watches)
    }

    private func rebuild() {
        allItems = (entries.map(Item.init) + notes.map(Item.init)).sorted { $0.date > $1.date }
    }

    /// `items` with one edited note's item moved into place, or nil when the change was more than one edit.
    static func replacingEditedNote(in items: [Item], old: [Note], new: [Note]) -> [Item]? {
        guard old.count == new.count else { return nil }
        let edits = zip(old, new).filter { $0 != $1 }
        if edits.isEmpty { return items }
        guard edits.count == 1, let edit = edits.first, edit.0.id == edit.1.id,
              let index = items.firstIndex(where: { $0.id == Item.noteID(edit.1.id) }) else { return nil }
        let item = Item(edit.1)
        var items = items
        items.remove(at: index)
        items.insert(item, at: items.firstIndex { $0.date < item.date } ?? items.endIndex)
        return items
    }

    // MARK: Route

    var filter: LibraryFilter {
        get { selection.libraryFilter }
        set { selection.libraryFilter = newValue }
    }

    var selectedID: String? {
        get { selection.libraryItemID }
        set { selection.libraryItemID = newValue }
    }

    // MARK: Derived

    var visibleItems: [Item] {
        let query = self.query
        return allItems.filter { item in
            filter.includes(item.kind) && item.id != pendingDelete?.id
                && (query.isEmpty || item.title.localizedCaseInsensitiveContains(query)
                    || item.body.localizedCaseInsensitiveContains(query))
        }
    }

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The days on screen, newest first. Without a search today always leads, so its date heads the page.
    var days: [Day] {
        var days = Self.days(visibleItems)
        let today = Calendar.current.startOfDay(for: .now)
        if query.isEmpty, days.first?.id != today { days.insert(Day(id: today, items: []), at: 0) }
        return days
    }

    /// Every live item by day, oldest first: the tape, the track numbers and each day's summary count all of them.
    var tapes: [Date: [Item]] {
        let calendar = Calendar.current
        return Dictionary(grouping: allItems.reversed().filter { $0.id != pendingDelete?.id }) { calendar.startOfDay(for: $0.date) }
    }

    static func trackNumber(_ item: Item, in tapes: [Date: [Item]]) -> Int {
        (tapes[Calendar.current.startOfDay(for: item.date)]?.firstIndex { $0.id == item.id } ?? 0) + 1
    }

    func count(_ filter: LibraryFilter) -> Int {
        allItems.reduce(0) { $0 + (filter.includes($1.kind) && $1.id != pendingDelete?.id ? 1 : 0) }
    }

    var selectedItem: Item? {
        guard let id = selectedID, id != pendingDelete?.id else { return nil }
        return allItems.first { $0.id == id }
    }

    var selectedNote: Note? {
        guard let item = selectedItem, item.kind != .dictation else { return nil }
        return notes.first { $0.id == item.uuid }
    }

    var selectedEntry: TranscriptionEntry? {
        guard let item = selectedItem, item.kind == .dictation else { return nil }
        return entries.first { $0.id == item.uuid }
    }

    private var meetingIsLive: Bool { meetingState == .recording || meetingState == .finishing }

    var canStartMeeting: Bool { meeting != nil && !meetingIsLive }

    /// False for the note a meeting is still writing into, whose later turns would have nowhere to go.
    func canDelete(_ item: Item) -> Bool { !meetingIsLive || item.uuid != meeting?.noteID }

    /// Items by calendar day, newest day first, each day's items oldest first.
    static func days(_ items: [Item], calendar: Calendar = .current) -> [Day] {
        var days: [Day] = []
        for item in items.sorted(by: { $0.date > $1.date }) {
            let start = calendar.startOfDay(for: item.date)
            if days.last?.id == start {
                days[days.count - 1].items.insert(item, at: 0)
            } else {
                days.append(Day(id: start, items: [item]))
            }
        }
        return days
    }

    /// "Tuesday 13 October" for today and older dates, "Yesterday" for yesterday; a year only when it isn't this one.
    static func dayTitle(_ day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) { return "Yesterday" }
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).day().month(.wide)
        return day.formatted(calendar.isDate(day, equalTo: now, toGranularity: .year) ? style : style.year())
    }

    /// "12 tracks · 32 min 54 s of talk".
    static func summary(_ items: [Item]) -> String {
        let tracks = items.count == 1 ? "1 track" : "\(items.count) tracks"
        return "\(tracks) · \(talk(items.reduce(0) { $0 + $1.talkTime })) of talk"
    }

    /// A running time: "0:08", "32:00", "1:02:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// A length of talk: "40 s", "32 min 54 s", "1 h 2 min".
    static func talk(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        if total < 3600 { return "\(total / 60) min \(total % 60) s" }
        return "\(total / 3600) h \(total / 60 % 60) min"
    }

    // MARK: Notes

    func newNote() {
        let note = store.create()
        if !filter.includes(.note) { filter = .all }
        selectedID = Item.noteID(note.id)
    }

    /// Makes the note on screen the one ⌃⌥N adds to and loads its drafts; called when the inspector shows a different note.
    func edit(_ note: Note) {
        store.selectedNoteID = note.id
        commitSpeakers()
        editingTranscript = false
        draftNoteID = nil
        titleDraft = note.titleIsCustom ? note.title : ""
        speakerDrafts = note.speakerLabels
        draftNoteID = note.id
    }

    func body(of note: Note) -> Binding<String> {
        Binding(get: { [weak self] in self?.notes.first { $0.id == note.id }?.body ?? note.body },
                set: { [weak self] in self?.store.updateBody($0, for: note.id) })
    }

    private func commitTitle() {
        guard let id = draftNoteID else { return }
        store.updateTitle(titleDraft, for: id)
    }

    func commitSpeakers() {
        guard let id = draftNoteID, notes.first(where: { $0.id == id })?.source == .meeting else { return }
        for role in SpeakerRole.allCases { store.renameSpeaker(role, to: speakerDrafts[role], in: id) }
        speakerDrafts = notes.first { $0.id == id }?.speakerLabels ?? .default
    }

    func convertToNote(_ entry: TranscriptionEntry) {
        let note = store.create(body: entry.text, source: .dictated)
        if !filter.includes(.note) { filter = .all }
        selectedID = Item.noteID(note.id)
    }

    func run(_ action: NoteAction, on note: Note) {
        runningAction = action
        actionMessage = nil
        Task {
            let result = await runAction(action, note.id)
            runningAction = nil
            switch result {
            case .applied:
                actionMessage = nil
                if let updated = notes.first(where: { $0.id == note.id }) { edit(updated) }
            case .nothingToDo(let why):
                actionFailed = false
                actionMessage = why
            case .rejected(let why), .unavailable(let why):
                actionFailed = true
                actionMessage = why
            }
        }
    }

    // MARK: Paste, copy, delete, undo

    func pasteAgain(_ item: Item) {
        paste(item.body)
        pastedIDs.insert(item.id)
    }

    /// Hiding Utter hands focus back to the app underneath; the paste waits for it to come to the front.
    static func pasteIntoPreviousApp(_ text: String) {
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { TextInjector.typeText(text) }
    }

    func copy(_ item: Item) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.body, forType: .string)
        copiedID = item.id
        copyTask?.cancel()
        copyTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copiedID = nil
        }
    }

    /// Hides the item at once and removes it for good when the undo window closes.
    func delete(_ item: Item) {
        guard canDelete(item) else { return }
        commitPendingDelete()
        withAnimation(Self.motion(.smooth(duration: 0.2))) {
            if selectedID == item.id {
                let visible = visibleItems
                let index = visible.firstIndex(of: item) ?? 0
                let neighbour = visible.indices.contains(index + 1) ? visible[index + 1] : (index > 0 ? visible[index - 1] : nil)
                selectedID = neighbour?.id
            }
            pendingDelete = item
        }
        AccessibilityNotification.Announcement("Deleted. Undo is available.").post()
        deleteTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            self?.commitPendingDelete()
        }
    }

    func undoDelete() {
        deleteTask?.cancel()
        guard let item = pendingDelete else { return }
        withAnimation(Self.motion(.snappy(duration: 0.3))) {
            pendingDelete = nil
            selectedID = item.id
        }
    }

    func commitPendingDelete() {
        deleteTask?.cancel()
        guard let item = pendingDelete else { return }
        withAnimation(Self.motion(.smooth(duration: 0.2))) { pendingDelete = nil }
        switch item.kind {
        case .dictation:
            if let entry = entries.first(where: { $0.id == item.uuid }) { history.delete(entry: entry) }
        case .note, .meeting:
            store.delete(id: item.uuid)
        }
    }

    // MARK: Motion

    /// One item arriving or leaving moves; a load, a filter or a search swaps at once.
    static func arrival(from old: Int, to new: Int) -> Animation? {
        abs(new - old) == 1 ? motion(.snappy(duration: 0.3)) : nil
    }

    private static func motion(_ animation: Animation) -> Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .easeOut(duration: 0.18) : animation
    }

    // MARK: Meetings

    func startMeeting() {
        meetingMessage = nil
        if let why = prepareMeeting() {
            meetingMessage = why
            return
        }
        Task {
            guard let id = await startMeetingCapture() else {
                if case .failed(let why) = meeting?.state { meetingMessage = why }
                return
            }
            selection.openNote(id)
        }
    }

    func stopMeeting() {
        Task { await meeting?.stop(store: store) }
    }

    // MARK: Export

    func exportText(_ format: ExportFormat) -> String { Self.export(visibleItems, as: format) }

    func save(_ text: String, to url: URL) {
        Task {
            let failure: String? = await Task.detached(priority: .userInitiated) {
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if let failure { problem = "Couldn't save \(url.lastPathComponent). \(failure)" }
        }
    }

    static func export(_ items: [Item], as format: ExportFormat) -> String {
        let stamp = Date.ISO8601FormatStyle(timeZone: .current).year().month().day().time(includingFractionalSeconds: false)
            .dateTimeSeparator(.space).timeSeparator(.colon)
        switch format {
        case .markdown:
            return items.map { "## \($0.title)\n\n\($0.date.formatted(stamp))\n\n\($0.body)\n" }
                .joined(separator: "\n---\n\n")
        case .csv:
            func cell(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            let rows = items.map { [cell($0.date.formatted(stamp)), cell($0.kindName), String($0.words), cell($0.title), cell($0.body)]
                .joined(separator: ",") }
            return (["Date,Kind,Words,Title,Text"] + rows).joined(separator: "\n") + "\n"
        case .text:
            return items.map { "\($0.date.formatted(stamp))  \($0.title)\n\($0.body)" }.joined(separator: "\n\n") + "\n"
        }
    }
}
