import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

@Suite("History track fields")
struct HistoryTrackTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-history-track-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("A row without app or dur loads with empty app and zero duration")
    func oldRowsLoadWithDefaults() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = #"[{"id": "5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F", "text": "Hello there", "ts": "2023-11-14T22:13:20Z", "lang": "English"}]"#
        try Data(old.utf8).write(to: directory.appendingPathComponent("history.json"))

        let entry = try #require(TranscriptionHistory(storageDir: directory).entries.first)

        #expect(entry.text == "Hello there")
        #expect(entry.language == "English")
        #expect(entry.app == "")
        #expect(entry.duration == 0)
    }

    @Test("App and duration survive a save and reload, alongside every existing key")
    @MainActor
    func appAndDurationRoundTrip() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let history = TranscriptionHistory(storageDir: directory)
        history.add(text: "Running five minutes late", language: "English", app: "Mail", duration: 3.25)
        await MainActor.run {}
        history.flushPendingWrites()

        let file = directory.appendingPathComponent("history.json")
        let rows = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: String]])
        #expect(Set(rows[0].keys) == ["id", "text", "ts", "lang", "app", "dur"])

        let reloaded = try #require(TranscriptionHistory(storageDir: directory).entries.first)
        #expect(reloaded.id == history.entries[0].id)
        #expect(reloaded.text == "Running five minutes late")
        #expect(reloaded.language == "English")
        #expect(reloaded.app == "Mail")
        #expect(reloaded.duration == 3.25)
    }
}
