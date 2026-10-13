import Foundation
import os

package struct TranscriptionEntry: Identifiable, Sendable {
    package let id: UUID
    package let text: String
    package let timestamp: Date
    package let wordCount: Int
    /// Detected display language (e.g. "English", "日本語"). Empty when unknown.
    package let language: String

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

package class TranscriptionHistory: ObservableObject {
    private static let live = TranscriptionHistory()
    nonisolated(unsafe) static var preview: TranscriptionHistory?
    package static var shared: TranscriptionHistory { preview ?? live }
    private static let persistenceQueue = DispatchQueue(
        label: "utter.history.persistence",
        qos: .utility
    )
    private static let performanceLog = Logger(
        subsystem: "utter.dictation.app",
        category: "persistence-performance"
    )

    /// Invalidating from `didSet` rather than at each mutation site: `entries` is
    /// touched from `add`, `delete`, `deleteAll` and `load`, and a future fifth
    /// caller that forgot to clear the cache would serve a stale list with no
    /// visible cause.
    @Published package var entries: [TranscriptionEntry] = [] {
        didSet { groupCache = nil }
    }
    @Published package var totalWords: Int = 0
    @Published var streakDays: Int = 0

    /// Average words per saved dictation. Audio duration is not persisted, so
    /// reporting words per minute here would be fabricated precision.
    var averageWordsPerDictation: String {
        guard !entries.isEmpty else { return "\u{2014}" }
        let mean = Double(totalWords) / Double(entries.count)
        return mean.formatted(.number.precision(.fractionLength(0)))
    }

    private let storageDir: URL?

    private var historyURL: URL? { storageDir?.appendingPathComponent("history.json") }
    private var streakURL: URL? { storageDir?.appendingPathComponent("streak.json") }

    init(storageDir: URL? = AppDirectory.support) {
        self.storageDir = storageDir
        load()
        activeDays = Self.readStreak(at: streakURL)
        calculateStreak()
    }

    // MARK: - Public API

    package func add(text: String, language: String = "") {
        guard TranscriptText.isUsable(text) else { return }
        let entry = TranscriptionEntry(text: text, language: language)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            self.totalWords += entry.wordCount
            self.recordToday()
            self.calculateStreak()
            self.saveHistory()
        }
    }

    package func delete(entry: TranscriptionEntry) {
        DispatchQueue.main.async {
            self.entries.removeAll { $0.id == entry.id }
            self.totalWords = self.entries.reduce(0) { $0 + $1.wordCount }
            self.saveHistory()
        }
    }

    /// Erase all history, including the streak record. Used by
    /// Privacy → Clear All Data, which must leave nothing behind.
    package func deleteAll() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.totalWords = 0
            self.streakDays = 0
            self.activeDays = []
            self.saveHistory()
            self.flushPendingWrites()
        }
    }

    /// Group entries by date for display
    /// Cached date grouping, rebuilt when `entries` changes or the day rolls over.
    ///
    /// This was a computed property, so a SwiftUI body reading it re-ran a
    /// `Dictionary(grouping:)` plus a sort over every entry on every layout pass  - 
    /// 300+ entries, many times a second while scrolling. The cache is invalidated
    /// from `entries.didSet`.
    private var groupCache: [HistoryGroup]?

    /// When the cached *labels* stop being true.
    ///
    /// `dateLabel` is relative to now - TODAY, YESTERDAY, a weekday - so entries
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
    /// and a fixed-seconds deadline would land an hour either side of midnight  - 
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

    private var activeDays: Set<String> = [] {
        didSet { saveStreak() }
    }

    private static func readStreak(at url: URL?) -> Set<String> {
        guard let url, let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return [] }
        return Set(arr)
    }

    private func saveStreak() {
        guard let destination = streakURL,
              let data = try? JSONSerialization.data(withJSONObject: activeDays.sorted()) else { return }
        Self.persistenceQueue.async {
            do { try data.write(to: destination, options: .atomic) }
            catch { print("⚠️ Could not write streak: \(error.localizedDescription)") }
        }
    }

    private func recordToday() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        if !activeDays.contains(today) { activeDays.insert(today) }
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
        guard let destination = historyURL else { return }
        let snapshot = Array(entries.prefix(1000))
        Self.persistenceQueue.async {
            let started = DispatchTime.now().uptimeNanoseconds
            let fmt = ISO8601DateFormatter()
            let rows: [[String: String]] = snapshot.map {
                ["id": $0.id.uuidString, "text": $0.text, "ts": fmt.string(from: $0.timestamp), "lang": $0.language]
            }
            guard let json = try? JSONSerialization.data(withJSONObject: rows, options: .prettyPrinted) else {
                print("⚠️ Could not encode transcription history")
                return
            }
            // `.atomic`, and not `try?`: keep the previous generation if a write fails.
            do { try json.write(to: destination, options: .atomic) }
            catch { print("⚠️ Could not write history: \(error.localizedDescription)") }
            let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
            Self.performanceLog.info(
                "history persistence_ms=\(elapsedMilliseconds, format: .fixed(precision: 1)) count=\(snapshot.count) bytes=\(json.count)"
            )
        }
    }

    /// Wait for queued history writes during explicit data clearing or shutdown.
    package func flushPendingWrites() {
        Self.persistenceQueue.sync {}
    }

    private func load() {
        // Nothing on disk yet is the ordinary first-launch case, not a corruption - so it
        // must come before the salvage below, or every first launch renames a missing file.
        guard let historyURL, let data = try? Data(contentsOf: historyURL) else { return }
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
        var discardedNoSpeechMarkers = false
        for item in arr {
            guard let text = item["text"] else { continue }
            guard TranscriptText.isUsable(text) else {
                discardedNoSpeechMarkers = true
                continue
            }
            let ts = item["ts"].flatMap { fmt.date(from: $0) } ?? Date()
            let id = item["id"].flatMap { UUID(uuidString: $0) } ?? UUID()
            let lang = item["lang"] ?? ""
            let entry = TranscriptionEntry(text: text, timestamp: ts, id: id, language: lang)
            entries.append(entry)
            totalWords += entry.wordCount
        }
        if discardedNoSpeechMarkers {
            // Clean up old placeholder rows on the next atomic history write so
            // they cannot reappear after a relaunch.
            saveHistory()
        }
    }
}
