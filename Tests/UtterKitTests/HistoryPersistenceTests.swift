import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// How history.json loads and saves, against a temporary folder, never the real one.
@Suite("History persistence")
struct HistoryPersistenceTests {

    private static let goldenFile = """
    [
      {"id": "5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F", "text": "Hello there world",
       "ts": "2023-11-14T22:13:20Z", "lang": "English"},
      {"id": "6C4E9D3F-2A5B-4C7D-8E9F-1B2C3D4E5F60", "text": "[BLANK_AUDIO]",
       "ts": "2023-11-14T22:14:20Z", "lang": ""},
      {"text": "No id or timestamp"}
    ]
    """

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-history-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("A golden history.json loads, drops no-speech rows, and keeps the row shape on rewrite")
    func goldenFileLoads() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("history.json")
        try Data(Self.goldenFile.utf8).write(to: file)

        let history = TranscriptionHistory(storageDir: directory)
        history.flushPendingWrites()

        #expect(history.entries.count == 2)
        #expect(history.entries[0].id == UUID(uuidString: "5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F"))
        #expect(history.entries[0].text == "Hello there world")
        #expect(history.entries[0].timestamp.timeIntervalSince1970 == 1_700_000_000)
        #expect(history.entries[0].language == "English")
        #expect(history.totalWords == 3 + 4)

        let rewritten = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        let rows = try #require(rewritten as? [[String: String]])
        #expect(rows.count == 2)
        #expect(Set(rows[0].keys) == ["id", "text", "ts", "lang"])
    }

    @Test("An unreadable history.json is moved aside, not overwritten")
    func corruptFileIsSalvaged() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{not json".utf8).write(to: directory.appendingPathComponent("history.json"))

        _ = TranscriptionHistory(storageDir: directory)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names.contains { $0.hasPrefix("history-unreadable-") })
        #expect(!names.contains("history.json"))
    }

    @Test("A streak.json left by an older build is removed at launch")
    func oldStreakFileIsRemoved() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let streak = directory.appendingPathComponent("streak.json")
        try Data("[\"2026-10-13\"]".utf8).write(to: streak)
        _ = TranscriptionHistory(storageDir: directory)
        #expect(!FileManager.default.fileExists(atPath: streak.path))
    }
}
