import Foundation
import os

/// Where a note's text came from. Kept so the UI can distinguish a typed note
/// from a dictated one without inspecting the text, and so meeting captures can
/// be presented differently later.
enum NoteSource: String, Codable, Sendable {
    case typed
    case dictated
    case meeting
}

/// One durable note.
///
/// This is the unit the old scratchpad could not express: `UserData.scratchpad`
/// was a single `String`, so there was exactly one note and writing a second one
/// overwrote the first.
struct Note: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    /// Derived from the body by `derivedTitle` unless the user typed one, in
    /// which case `titleIsCustom` pins it.
    var title: String
    var body: String
    var created: Date
    var modified: Date
    var tags: [String]
    var source: NoteSource
    /// Set once the user edits the title, so later body edits stop renaming it.
    var titleIsCustom: Bool

    /// What this meeting note calls its two audio sources, once the user has renamed
    /// either of them. `nil` on notes that aren't meetings, and on meeting notes
    /// nobody has renamed.
    ///
    /// Optional rather than defaulted to `MeetingSpeakers.default`, and the difference
    /// is not cosmetic: the synthesised `Codable` decoder fails on a *missing* key for
    /// a non-optional property, so a stored default would have made every existing
    /// `notes.json` undecodable - and `NoteStore.load` responds to an undecodable file
    /// by moving the user's entire notes file aside. Optional decodes absent as `nil`.
    /// `MeetingSpeakers.default` covers the `nil` case at every read instead.
    var speakers: MeetingSpeakers?

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String = "",
        created: Date = Date(),
        modified: Date = Date(),
        tags: [String] = [],
        source: NoteSource = .typed,
        titleIsCustom: Bool = false,
        speakers: MeetingSpeakers? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.created = created
        self.modified = modified
        self.tags = tags
        self.source = source
        self.titleIsCustom = titleIsCustom
        self.speakers = speakers
    }

    /// The labels to use for this note's turns - the user's, where they set one.
    var speakerLabels: MeetingSpeakers { speakers ?? .default }

    /// First non-empty line, trimmed. Markdown heading markers are stripped so a
    /// note starting `# Standup` titles as "Standup" rather than "# Standup".
    ///
    /// Deliberately a plain heuristic: it is instant and predictable, and it
    /// costs nothing when Apple Intelligence is unavailable. AI titling is
    /// offered as an explicit action instead of running behind the user's back.
    static func derivedTitle(from body: String) -> String {
        // Split on any newline, not the literal "\n".
        //
        // Swift treats CRLF as a single grapheme cluster, so `split(separator: "\n")`
        // never matches it - a body pasted from Windows or a Markdown file came back
        // as one "line" and the title ended up 25+ characters with an embedded
        // newline in the middle. `\.isNewline` covers CR, LF, CRLF, and the Unicode
        // line separators.
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let firstLine else { return "" }

        var line = firstLine.trimmingCharacters(in: .whitespaces)
        while line.hasPrefix("#") { line.removeFirst() }
        line = line.trimmingCharacters(in: .whitespaces)

        guard !line.isEmpty else { return "" }
        guard line.count > 60 else { return line }

        // Cut on a word boundary so titles don't end mid-word.
        let clipped = line.prefix(60)
        if let lastSpace = clipped.lastIndex(of: " "), clipped.distance(from: clipped.startIndex, to: lastSpace) > 30 {
            return String(clipped[clipped.startIndex..<lastSpace]) + "…"
        }
        return String(clipped) + "…"
    }

    /// What to show in a list. Never empty, so a blank new note is still findable.
    var displayTitle: String {
        if !title.isEmpty { return title }
        let derived = Self.derivedTitle(from: body)
        return derived.isEmpty ? "Untitled note" : derived
    }

    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

/// The two on-disk timestamp shapes for `notes.json`.
///
/// Built once: `ISO8601DateFormatter` is expensive to construct and these run per
/// note on every save.
///
/// Deliberately *outside* `NoteStore`, which is `@MainActor`. `JSONEncoder`'s and
/// `JSONDecoder`'s `.custom` date strategies take `@Sendable` closures, so reading a
/// main-actor-isolated static from inside one is a warning today and an error in the
/// Swift 6 language mode - the closure is declared as safe to run anywhere while
/// reaching for state that is not. Hoisting them says what is actually true: these
/// are configured here, never mutated afterwards, and Foundation's date formatters
/// have been documented as safe for concurrent formatting and parsing since
/// macOS 10.9. Encoding is serialized by NoteStore's persistence queue; initial
/// decoding occurs during store construction.
enum NoteDateFormat {
    /// What `writeToDisk` emits, and the preferred shape on read.
    static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// The legacy shape: files written before the fractional-seconds fix carry
    /// whole-second stamps and must still load.
    static let whole: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

/// Notes grouped under a date heading, mirroring `HistoryGroup` so the notes list
/// and the history list read the same way.
struct NoteGroup: Identifiable {
    let id: String
    let label: String
    let notes: [Note]
}

/// Where a dictated capture will land.
///
/// One authority for a decision two places need. `AppDelegate.deliverToNote` files the
/// finished text, and the pill's note box has to *name* the destination while the user is
/// still talking - before any text exists. Two copies of the rule would drift, and the
/// failure mode is the pill confidently naming a note the text does not go into.
enum NoteCaptureDestination: Equatable {
    /// A new note will be created for this capture.
    case newNote
    /// The text will be appended to a note that is already open.
    case appending(id: UUID, title: String)

    /// Resolve the destination from the preference and the store's contents.
    ///
    /// Pure and taking its inputs, so it can be tested without the singleton - which is
    /// bound to the real Application Support directory.
    ///
    /// The `notes` lookup is not redundant: `selectedNoteID` survives a note being
    /// deleted from under it (`delete(id:)` reassigns it, `deleteAll` clears it, but a
    /// file reloaded from disk can name an id that is gone), and appending to an id that
    /// no longer exists would silently drop the capture.
    static func resolve(appendsToOpenNote: Bool,
                        selectedID: UUID?,
                        notes: [Note]) -> NoteCaptureDestination {
        guard appendsToOpenNote,
              let selectedID,
              let note = notes.first(where: { $0.id == selectedID })
        else { return .newNote }
        return .appending(id: selectedID, title: note.displayTitle)
    }

    /// What the pill calls it. Short: it shares a 272pt line with the elapsed timer.
    var label: String {
        switch self {
        case .newNote: return "New note"
        case .appending(_, let title): return "Adding to \(title)"
        }
    }
}

/// Durable storage for notes.
///
/// Modelled on `TranscriptionHistory` - singleton `ObservableObject`, one JSON
/// file under Application Support, date-grouped for display - with two
/// deliberate departures:
///
///   * **Its own file.** `UserData.save()` re-serialises every preference on each
///     call; notes riding along in that blob would mean a keystroke in a note
///     rewrites the whole settings file, and a corrupt write loses both.
///   * **No entry cap.** `TranscriptionHistory` keeps `.prefix(1000)`, which is
///     right for a rolling log of things already typed elsewhere. For notes  - 
///     the only copy of the user's own writing - silently dropping the oldest
///     would be data loss.
@MainActor
final class NoteStore: ObservableObject {
    private static let live = NoteStore()
    static var preview: NoteStore?
    static var shared: NoteStore { preview ?? live }

    /// Preserve mutation order while keeping JSON encoding, backup copying, and
    /// atomic disk replacement off the UI actor.
    private nonisolated static let persistenceQueue = DispatchQueue(
        label: "utter.notes.persistence",
        qos: .utility
    )
    private nonisolated static let performanceLog = Logger(
        subsystem: "utter.dictation.app",
        category: "persistence-performance"
    )

    @Published private(set) var notes: [Note] = []

    /// The note the UI currently has open. Voice capture appends here when set,
    /// which is what makes "keep talking into the same note" work.
    @Published var selectedNoteID: UUID?

    private let storageDir: URL?

    private var notesURL: URL? { storageDir?.appendingPathComponent("notes.json") }

    /// The generation before the current one. See `writeToDisk`.
    private var previousNotesURL: URL? { storageDir?.appendingPathComponent("notes.previous.json") }

    /// Coalesces disk writes while the user types. Same shape as the old
    /// `ScratchpadSaver`, kept inside the store so every mutation path benefits
    /// rather than only the text editor.
    private var saveWorkItem: DispatchWorkItem?

    init(storageDir: URL? = AppDirectory.support, seed: [Note] = [], selectedID: UUID? = nil) {
        self.storageDir = storageDir
        load()
        if !seed.isEmpty {
            notes = seed
            selectedNoteID = selectedID
        }
    }

    // MARK: - Reading

    var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    /// Where the next dictated capture will land.
    ///
    /// The preference is passed in rather than read from `UserData.shared`, the same way
    /// `migrateLegacyScratchpadIfNeeded` takes it: the store has no business reaching for
    /// global preferences, and the decision stays testable.
    func captureDestination(appendsToOpenNote: Bool) -> NoteCaptureDestination {
        .resolve(appendsToOpenNote: appendsToOpenNote,
                 selectedID: selectedNoteID,
                 notes: notes)
    }

    private var cacheGeneration: Int = 0
    private var cachedQuery: String?
    private var cachedGroupGeneration: Int = -1
    private var cachedGroups: [NoteGroup] = []

    private func invalidateGroupCache() {
        cacheGeneration &+= 1
    }

    /// Newest first, grouped by modification date.
    ///
    /// Grouping and labelling deliberately match `TranscriptionHistory`
    /// (TODAY / YESTERDAY / weekday / full date) so the two screens agree.
    func grouped(matching search: String = "") -> [NoteGroup] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if cachedGroupGeneration == cacheGeneration, cachedQuery == query {
            return cachedGroups
        }

        let filtered = query.isEmpty ? notes : notes.filter {
            $0.body.localizedCaseInsensitiveContains(query)
                || $0.displayTitle.localizedCaseInsensitiveContains(query)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }

        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { note -> String in
            let c = cal.dateComponents([.year, .month, .day], from: note.modified)
            return "\(c.year!)-\(c.month!)-\(c.day!)"
        }

        let result = groups.map { key, notes in
            let sorted = notes.sorted { $0.modified > $1.modified }
            return NoteGroup(
                id: key,
                label: Self.dateLabel(for: sorted.first?.modified ?? Date()),
                notes: sorted
            )
        }
        .sorted { ($0.notes.first?.modified ?? .distantPast) > ($1.notes.first?.modified ?? .distantPast) }

        cachedQuery = query
        cachedGroupGeneration = cacheGeneration
        cachedGroups = result
        return result
    }

    static func dateLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }

        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        let fmt = DateFormatter()
        if days < 7 {
            fmt.dateFormat = "EEEE"
        } else {
            fmt.dateFormat = "MMMM d, yyyy"
        }
        return fmt.string(from: date).uppercased()
    }

    // MARK: - Writing

    @discardableResult
    func create(body: String = "", source: NoteSource = .typed, select: Bool = true) -> Note {
        var note = Note(source: source)
        note.body = body
        note.title = Note.derivedTitle(from: body)
        insert(note, select: select)
        return note
    }

    private func insert(_ note: Note, select: Bool) {
        notes.insert(note, at: 0)
        invalidateGroupCache()
        if select { selectedNoteID = note.id }
        scheduleSave()
    }

    func updateBody(_ body: String, for id: UUID) {
        mutate(id) { note in
            guard note.body != body else { return false }
            note.body = body
            // Keep the title tracking the text until the user takes it over.
            if !note.titleIsCustom {
                note.title = Note.derivedTitle(from: body)
            }
            return true
        }
    }

    func updateTitle(_ title: String, for id: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        mutate(id) { note in
            guard note.title != trimmed else { return false }
            note.title = trimmed
            // An empty title hands control back to the body-derived heuristic.
            note.titleIsCustom = !trimmed.isEmpty
            return true
        }
    }

    /// Add dictated text to an existing note.
    ///
    /// Separated from `updateBody` because appending is the voice path: it must
    /// never clobber what is already there, and it inserts a blank line so
    /// successive captures don't run together into one paragraph.
    func append(_ text: String, to id: UUID) {
        let addition = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addition.isEmpty else { return }

        mutate(id) { note in
            if note.body.isEmpty {
                note.body = addition
            } else {
                let separator = note.body.hasSuffix("\n") ? "\n" : "\n\n"
                note.body += separator + addition
            }
            if !note.titleIsCustom {
                note.title = Note.derivedTitle(from: note.body)
            }
            return true
        }
    }

    /// Rename one of a meeting note's speaker labels - in the stored labels *and* in
    /// the transcript already written.
    ///
    /// Both halves are load-bearing:
    ///
    ///   * Without the body rewrite the visible transcript would keep saying "Others"
    ///     while a field elsewhere claimed otherwise, and the exported Markdown - which
    ///     carries no mapping - would keep the old label forever.
    ///   * Without the stored label the next 30-second window of a *live* meeting would
    ///     append "Others" again, undoing the rename the user just made.
    ///
    /// Blank names are ignored rather than accepted: an empty heading (`**:**`) would
    /// leave the turn unattributed with no way to tell which stream it came from.
    func renameSpeaker(_ role: SpeakerRole, to name: String, in id: UUID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        mutate(id) { note in
            var speakers = note.speakerLabels
            let old = speakers[role]
            guard old != trimmed else { return false }
            speakers[role] = trimmed
            note.speakers = speakers
            note.body = MeetingTranscript.relabel(note.body, from: old, to: trimmed)
            // Deliberately does not re-derive the title: a meeting note's title is its
            // date heading, and renaming a speaker is not a reason to change it.
            return true
        }
    }

    func setTags(_ tags: [String], for id: UUID) {
        mutate(id) { note in
            let cleaned = tags
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard note.tags != cleaned else { return false }
            note.tags = cleaned
            return true
        }
    }

    func delete(id: UUID) {
        notes.removeAll { $0.id == id }
        invalidateGroupCache()
        if selectedNoteID == id { selectedNoteID = notes.first?.id }
        scheduleSave()
    }

    /// Erase every note. Used by Privacy → Clear All Data, which must leave
    /// nothing behind.
    func deleteAll() {
        notes.removeAll()
        invalidateGroupCache()
        selectedNoteID = nil
        // Write through immediately rather than on the debounce: a user clearing
        // their data should not have it linger on disk for another second.
        saveWorkItem?.cancel()
        writeToDisk()
        flushPendingWrites()
    }

    /// Applies a change and stamps `modified`. The closure returns false when
    /// nothing actually changed, so no-op edits don't reorder the list or dirty
    /// the file - SwiftUI binds `TextEditor` tightly enough that it re-sends the
    /// same value.
    private func mutate(_ id: UUID, _ change: (inout Note) -> Bool) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[index]
        guard change(&note) else { return }
        note.modified = Date()
        notes[index] = note
        invalidateGroupCache()
        scheduleSave()
    }

    // MARK: - Migration

    /// Move the legacy single-buffer scratchpad into a real note, once.
    ///
    /// The old feature stored all note text in `UserData.scratchpad`. Dropping it
    /// on upgrade would delete whatever the user last wrote, so this runs before
    /// the notes UI is first shown and clears the old key only after the note is
    /// safely on disk.
    func migrateLegacyScratchpadIfNeeded(userData: UserData = .shared) {
        let legacy = userData.scratchpad.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !legacy.isEmpty else { return }

        var note = Note(source: .typed)
        note.body = userData.scratchpad
        note.title = Note.derivedTitle(from: userData.scratchpad)
        insert(note, select: true)
        writeToDisk()
        flushPendingWrites()

        userData.scratchpad = ""
        userData.save()
        print("📝 Migrated legacy scratchpad into a note (\(note.wordCount) words)")
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.writeToDisk() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    /// Capture the current value on MainActor, then encode and persist it in order
    /// on a utility queue. The immutable snapshot prevents a background writer
    /// from racing with edits to the published array.
    func writeToDisk() {
        guard let destination = notesURL, let backup = previousNotesURL else { return }
        let snapshot = notes
        Self.persistenceQueue.async {
            Self.persist(snapshot, to: destination, keepingPreviousAt: backup)
        }
    }

    /// Drain pending persistence work. Used only where the caller must guarantee
    /// durability before returning, such as app termination and Clear All Data.
    /// Ordinary editor autosaves must never call this and block the UI.
    func flushPendingWrites() {
        Self.persistenceQueue.sync {}
    }

    private nonisolated static func persist(_ notes: [Note], to notesURL: URL, keepingPreviousAt previousNotesURL: URL) {
        let started = DispatchTime.now().uptimeNanoseconds
        var byteCount = 0
        defer {
            let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            performanceLog.info(
                "notes persistence_ms=\(elapsedMilliseconds, format: .fixed(precision: 1)) count=\(notes.count) bytes=\(byteCount)"
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        // Fractional seconds, not plain `.iso8601`.
        //
        // `.iso8601` formats to whole seconds, so a Date lost up to 1s on every
        // save/load cycle. Notes are ordered by `modified`, and two notes touched
        // within the same second would compare equal after a reload - making the
        // list order arbitrary across launches. A round-trip test caught this.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(NoteDateFormat.fractional.string(from: date))
        }
        guard let data = try? encoder.encode(notes) else {
            print("⚠️ Failed to encode notes; keeping the previous file")
            return
        }
        byteCount = data.count
        // Keep the previous version before overwriting it.
        //
        // Atomic writes stop a *torn* file, and moving an unreadable file aside on load stops the
        // next save overwriting it - but neither helps against a write that succeeds and is wrong:
        // a bug that empties `notes`, or an editor commit that lands stale text over a dictation.
        // Notes are the only thing in Utter that cannot be recreated from anything else, so one
        // generation back is kept beside them. `notes.previous.json` is a plain copy, readable by
        // hand, which is the whole point - recovery must not need the app that broke it.
        //
        // Only replaced when there is something to replace it with, and only when the new data
        // differs, so a run of no-op saves cannot roll the good copy off the end.
        if let existing = try? Data(contentsOf: notesURL), existing != data {
            try? existing.write(to: previousNotesURL, options: .atomic)
        }
        do {
            // Atomic: a crash mid-write must not truncate the only copy of the
            // user's writing.
            try data.write(to: notesURL, options: .atomic)
        } catch {
            print("⚠️ Failed to write notes: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let notesURL, let data = try? Data(contentsOf: notesURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            // Accept both shapes: files written before the fractional-seconds fix
            // carry whole-second stamps and must still load.
            if let date = NoteDateFormat.fractional.date(from: text) { return date }
            if let date = NoteDateFormat.whole.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised date: \(text)"
            )
        }
        guard let decoded = try? decoder.decode([Note].self, from: data) else {
            // Move the unreadable file aside instead of leaving it in place.
            //
            // "Leaving it untouched" was only true until the user typed once: the
            // next mutation scheduled a save that overwrote a possibly-salvageable
            // file with a single new note. Renaming preserves whatever is
            // recoverable and lets the app start clean.
            let salvage = notesURL
                .deletingLastPathComponent()
                .appendingPathComponent("notes-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: notesURL, to: salvage)
            print("⚠️ Notes file unreadable; moved aside to \(salvage.lastPathComponent)")
            return
        }
        notes = decoded.sorted { $0.modified > $1.modified }
        invalidateGroupCache()
        selectedNoteID = notes.first?.id
    }
}
