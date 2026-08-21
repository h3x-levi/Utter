import Foundation

struct TranscriptionEntry: Identifiable {
    let id: UUID
    let text: String
    let timestamp: Date
    let wordCount: Int
    /// Detected display language (e.g. "English", "日本語"). Empty when unknown.
    let language: String

    init(text: String, timestamp: Date = Date(), id: UUID = UUID(), language: String = "") {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.wordCount = text.split(separator: " ").count
        self.language = language
    }
}

/// Groups entries by date for display
struct HistoryGroup: Identifiable {
    let id: String // date string key
    let label: String
    let entries: [TranscriptionEntry]
}

class TranscriptionHistory: ObservableObject {
    static let shared = TranscriptionHistory()

    /// Invalidating from `didSet` rather than at each mutation site: `entries` is
    /// touched from `add`, `delete`, `deleteAll` and `load`, and a future fifth
    /// caller that forgot to clear the cache would serve a stale list with no
    /// visible cause.
    @Published var entries: [TranscriptionEntry] = [] {
        didSet { groupCache = nil }
    }
    @Published var totalWords: Int = 0
    @Published var streakDays: Int = 0

    private let storageDir: URL = AppDirectory.support

    private var historyURL: URL { storageDir.appendingPathComponent("history.json") }
    private var streakURL: URL { storageDir.appendingPathComponent("streak.json") }

    init() {
        load()
        calculateStreak()
    }

    // MARK: - Public API

    func add(text: String, language: String = "") {
        let entry = TranscriptionEntry(text: text, language: language)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            self.totalWords += entry.wordCount
            self.recordToday()
            self.calculateStreak()
            self.saveHistory()
        }
    }

    func delete(entry: TranscriptionEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.id == entry.id }
            self.totalWords = self.entries.reduce(0) { $0 + $1.wordCount }
            self.saveHistory()
        }
    }

    /// Erase all history, including the streak record. Used by
    /// Privacy → Clear All Data, which must leave nothing behind.
    func deleteAll() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.totalWords = 0
            self.streakDays = 0
            self.activeDays = []
            self.saveHistory()
        }
    }

    /// Group entries by date for display
    /// Cached date grouping, rebuilt when `entries` changes or the day rolls over.
    ///
    /// This was a computed property, so a SwiftUI body reading it re-ran a
    /// `Dictionary(grouping:)` plus a sort over every entry on every layout pass —
    /// 300+ entries, many times a second while scrolling. The cache is invalidated
    /// from `entries.didSet`.
    private var groupCache: [HistoryGroup]?

    /// When the cached *labels* stop being true.
    ///
    /// `dateLabel` is relative to now — TODAY, YESTERDAY, a weekday — so entries
    /// alone are not enough to key the cache on. Left to `entries.didSet`, a window
    /// open across midnight kept showing yesterday's dictations under a "TODAY"
    /// heading until the user happened to dictate again, which could be hours. The
    /// uncached computed property had corrected itself on the next layout pass.
    ///
    /// A deadline rather than re-deriving the day on every read: this is compared on
    /// the render path, and one `Date()` and a comparison is what the cache exists to
    /// protect. The expiry itself is only computed when the groups are rebuilt.
    private var groupCacheExpiry: Date?

    var groupedByDate: [HistoryGroup] {
        if let groupCache, let groupCacheExpiry, Date() < groupCacheExpiry {
            return groupCache
        }
        let built = buildGroups()
        groupCache = built
        groupCacheExpiry = Self.nextMidnight(after: Date())
        return built
    }

    /// The next local midnight strictly after `date`.
    ///
    /// Derived by adding a calendar day to the start of `date`'s day rather than
    /// adding 86,400 seconds: on a DST transition a local day is 23 or 25 hours long,
    /// and a fixed-seconds deadline would land an hour either side of midnight —
    /// exactly the case where a "TODAY" label is wrong and nobody would think to
    /// look. Falls back to +24h only if the calendar cannot answer at all.
    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? startOfDay.addingTimeInterval(86_400)
    }

    private func buildGroups() -> [HistoryGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry -> String in
            let comps = cal.dateComponents([.year, .month, .day], from: entry.timestamp)
            return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
        }

        return grouped.map { key, entries in
            let label = dateLabel(for: entries.first?.timestamp ?? Date())
            return HistoryGroup(id: key, label: label, entries: entries)
        }
        .sorted { g1, g2 in
            (g1.entries.first?.timestamp ?? .distantPast) > (g2.entries.first?.timestamp ?? .distantPast)
        }
    }

    private func dateLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }

        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 {
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE" // e.g. "Monday"
            return fmt.string(from: date).uppercased()
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt.string(from: date).uppercased()
    }

    // MARK: - Streak

    private var activeDays: Set<String> {
        get {
            guard let data = try? Data(contentsOf: streakURL),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
            return Set(arr)
        }
        set {
            let arr = Array(newValue).sorted()
            if let data = try? JSONSerialization.data(withJSONObject: arr) {
                // `.atomic` for the same reason as `saveHistory` — a torn write here loses
                // the whole streak rather than a day of it.
                do { try data.write(to: streakURL, options: .atomic) }
                catch { print("⚠️ Could not write streak: \(error.localizedDescription)") }
            }
        }
    }

    private func recordToday() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var days = activeDays
        days.insert(fmt.string(from: Date()))
        activeDays = days
    }

    private func calculateStreak() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let days = activeDays
        guard !days.isEmpty else { streakDays = 0; return }

        var streak = 0
        var date = Date()
        let cal = Calendar.current
        while days.contains(fmt.string(from: date)) {
            streak += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        streakDays = streak
    }

    // MARK: - Persistence

    private func saveHistory() {
        let fmt = ISO8601DateFormatter()
        let data: [[String: String]] = entries.prefix(1000).map {
            ["id": $0.id.uuidString, "text": $0.text, "ts": fmt.string(from: $0.timestamp), "lang": $0.language]
        }
        if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
            // `.atomic`, and not `try?`.
            //
            // Written in place, a crash or power loss mid-write left truncated JSON — and
            // because `load` simply returned on a parse failure, the app started with an
            // empty History and the very next dictation overwrote the file. Every earlier
            // entry was then unrecoverable even though most of the bytes were still on disk.
            // Atomic writes replace the file only once it is complete, so the old one
            // survives any failure; `NoteStore` already does this.
            do { try json.write(to: historyURL, options: .atomic) }
            catch { print("⚠️ Could not write history: \(error.localizedDescription)") }
        }
    }

    private func load() {
        // Nothing on disk yet is the ordinary first-launch case, not a corruption — so it
        // must come before the salvage below, or every first launch renames a missing file.
        guard let data = try? Data(contentsOf: historyURL) else { return }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            // Unreadable: move it aside rather than leaving it to be overwritten by the next
            // save. Same reasoning, and the same shape, as `NoteStore.load`.
            let salvage = historyURL
                .deletingLastPathComponent()
                .appendingPathComponent("history-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: historyURL, to: salvage)
            print("⚠️ History file unreadable; moved aside to \(salvage.lastPathComponent)")
            return
        }
        let fmt = ISO8601DateFormatter()
        for item in arr {
            guard let text = item["text"] else { continue }
            let ts = item["ts"].flatMap { fmt.date(from: $0) } ?? Date()
            let id = item["id"].flatMap { UUID(uuidString: $0) } ?? UUID()
            let lang = item["lang"] ?? ""
            let entry = TranscriptionEntry(text: text, timestamp: ts, id: id, language: lang)
            entries.append(entry)
            totalWords += entry.wordCount
        }
    }
}
