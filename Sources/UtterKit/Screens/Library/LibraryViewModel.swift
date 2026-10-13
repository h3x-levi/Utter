import AppKit
import Combine
import SwiftUI
import UtterCore

/// One dictation, note or meeting, as Home and Library list it.
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
    /// How long a meeting ran: from the note's creation to its last appended turn.
    let duration: TimeInterval
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
        duration = 0
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
        duration = note.modified.timeIntervalSince(note.created)
        you = note.source == .meeting ? note.speakerLabels.you : nil
    }

    var kindName: String {
        switch kind {
        case .dictation: "Dictation"
        case .note: "Note"
        case .meeting: "Meeting"
        }
    }

    var symbol: String {
        switch kind {
        case .dictation: "waveform"
        case .note: "note.text"
        case .meeting: "person.2"
        }
    }

    /// The first line that isn't the title, so a note's row doesn't show its title twice.
    var preview: String? {
        guard kind == .note else { return nil }
        return body.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && $0 != title && !$0.hasPrefix("#") }
    }

    var turns: [Turn] { Self.turns(in: body) }

    /// The first turn from each side, so a meeting's row previews You and Others.
    var previewTurns: [Turn] {
        let turns = turns
        return [turns.first { $0.speaker == you }, turns.first { $0.speaker != you }].compactMap { $0 }
    }

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

    struct Day: Identifiable {
        let id: Date
        let title: String
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

    private(set) var entries: [TranscriptionEntry] = [] { didSet { rebuild() } }
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
    private(set) var meetingState: MeetingSession.State = .idle
    var problem: String?

    let meeting: MeetingSession?
    @ObservationIgnored let selection: SidebarSelection
    @ObservationIgnored private let history: TranscriptionHistory
    @ObservationIgnored private let store: NoteStore
    @ObservationIgnored private let prepareMeeting: () -> String?
    @ObservationIgnored private let startMeetingCapture: () async -> UUID?
    @ObservationIgnored private let runAction: (NoteAction, UUID) async -> NoteActionResult
    @ObservationIgnored private var draftNoteID: UUID?
    @ObservationIgnored private var watches: Set<AnyCancellable> = []
    @ObservationIgnored private var deleteTask: Task<Void, Never>?
    @ObservationIgnored private var copyTask: Task<Void, Never>?

    static let undoWindow: Duration = .seconds(6)

    init(selection: SidebarSelection, history: TranscriptionHistory, store: NoteStore,
         meeting: MeetingSession? = nil,
         prepareMeeting: (() -> String?)? = nil,
         startMeetingCapture: @escaping () async -> UUID? = { nil },
         runAction: ((NoteAction, UUID) async -> NoteActionResult)? = nil) {
        self.selection = selection
        self.history = history
        self.store = store
        self.meeting = meeting
        self.prepareMeeting = prepareMeeting ?? { MeetingSession.prepare() }
        self.startMeetingCapture = startMeetingCapture
        self.runAction = runAction ?? { await NoteActionRunner.run($0, noteID: $1, store: store) }

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

    var isInspecting: Bool { selectedItem != nil }
    var inspectorWidth: CGFloat = 440

    // MARK: Derived

    var visibleItems: [Item] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return allItems.filter { item in
            filter.includes(item.kind) && item.id != pendingDelete?.id
                && (query.isEmpty || item.title.localizedCaseInsensitiveContains(query)
                    || item.body.localizedCaseInsensitiveContains(query))
        }
    }

    var days: [Day] { Self.days(visibleItems) }

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

    /// Newest-first items in the groups Notes uses: Today, Yesterday, Previous 30 Days, then months, then years.
    static func days(_ items: [Item], now: Date = Date(), calendar: Calendar = .current) -> [Day] {
        var days: [Day] = []
        for item in items {
            let (start, title) = group(item.date, now: now, calendar: calendar)
            if days.last?.id == start {
                days[days.count - 1].items.append(item)
            } else {
                days.append(Day(id: start, title: title, items: [item]))
            }
        }
        return days
    }

    static func group(_ date: Date, now: Date, calendar: Calendar) -> (start: Date, title: String) {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
        switch calendar.dateComponents([.day], from: day, to: today).day ?? 0 {
        case ...0: return (today, "Today")
        case 1: return (day, "Yesterday")
        case 2...30: return (calendar.date(byAdding: .day, value: -30, to: today) ?? day, "Previous 30 Days")
        default:
            if calendar.isDate(date, equalTo: now, toGranularity: .year) {
                let month = calendar.dateInterval(of: .month, for: date)?.start ?? day
                return (month, month.formatted(style.month(.wide)))
            }
            let year = calendar.dateInterval(of: .year, for: date)?.start ?? day
            return (year, year.formatted(style.year()))
        }
    }

    /// "Today, 11:00 AM".
    static func stamp(_ date: Date) -> String {
        "\(dayTitle(date)), \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func dayTitle(_ day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
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

    // MARK: Copy, delete, undo

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
