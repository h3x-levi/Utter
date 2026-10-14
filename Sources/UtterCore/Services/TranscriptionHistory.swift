import Foundation
import os

package struct TranscriptionEntry: Identifiable, Sendable {
    package let id: UUID
    package let text: String
    package let timestamp: Date
    package let wordCount: Int
    /// Detected display language (e.g. "English", "日本語"). Empty when unknown.
    package let language: String
    /// Display name of the app the text was delivered to. Empty when unknown.
    package let app: String
    /// Seconds of recorded speech. 0 when unknown.
    package let duration: TimeInterval

    init(text: String, timestamp: Date = Date(), id: UUID = UUID(), language: String = "",
         app: String = "", duration: TimeInterval = 0) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.wordCount = text.split(separator: " ").count
        self.language = language
        self.app = app
        self.duration = duration
    }
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
    @Published package var entries: [TranscriptionEntry] = []
    @Published package var totalWords: Int = 0

    /// Average words per saved dictation. Entries saved before durations were
    /// recorded have none, so words per minute here would be fabricated precision.

    private let storageDir: URL?

    private var historyURL: URL? { storageDir?.appendingPathComponent("history.json") }

    init(storageDir: URL? = AppDirectory.support) {
        self.storageDir = storageDir
        load()
        // The streak is no longer kept; drop the file older builds wrote.
        if let storageDir { try? FileManager.default.removeItem(at: storageDir.appendingPathComponent("streak.json")) }
    }

    // MARK: - Public API

    package func add(text: String, language: String = "", app: String = "", duration: TimeInterval = 0) {
        guard TranscriptText.isUsable(text) else { return }
        let entry = TranscriptionEntry(text: text, language: language, app: app, duration: duration)
        DispatchQueue.main.async {
            self.entries.insert(entry, at: 0)
            self.totalWords += entry.wordCount
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

    /// Erase all history. Used by
    /// Privacy → Clear All Data, which must leave nothing behind.
    package func deleteAll() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.totalWords = 0
            self.saveHistory()
            self.flushPendingWrites()
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        guard let destination = historyURL else { return }
        let snapshot = Array(entries.prefix(1000))
        Self.persistenceQueue.async {
            let started = DispatchTime.now().uptimeNanoseconds
            let fmt = ISO8601DateFormatter()
            // Strings, not numbers: older builds read rows as [String: String] and move anything else aside.
            let rows: [[String: String]] = snapshot.map { entry in
                var row = ["id": entry.id.uuidString, "text": entry.text,
                           "ts": fmt.string(from: entry.timestamp), "lang": entry.language]
                if !entry.app.isEmpty { row["app"] = entry.app }
                if entry.duration > 0 { row["dur"] = String(entry.duration) }
                return row
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
            let duration = item["dur"].flatMap(Double.init) ?? 0
            let entry = TranscriptionEntry(text: text, timestamp: ts, id: id, language: lang,
                                           app: item["app"] ?? "", duration: duration)
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
