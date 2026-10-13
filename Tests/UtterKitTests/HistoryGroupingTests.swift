import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// The date grouping behind the History list, and the cache in front of it.
///
/// `groupedByDate` used to be a plain computed property, so a SwiftUI body reading it
/// re-ran `Dictionary(grouping:)` plus a sort over every entry on every layout pass.
/// Caching it fixed the scroll stutter and introduced the classic hazard of any cache:
/// a key that does not cover everything the value depends on. Two things it depends on:
///
///   * **`entries`** - covered by `entries.didSet`.
///   * **the current date**, because `dateLabel` returns TODAY / YESTERDAY / a weekday.
///     Not covered at first, so a window left open across midnight kept yesterday's
///     dictations under a "TODAY" heading until the next mutation. That is what
///     `nextMidnight(after:)` and the expiry check exist for.
///
/// These use an in-memory `TranscriptionHistory(storageDir: nil)`, so they never touch
/// the real `history.json` or `streak.json`.
@Suite("History date grouping")
struct HistoryGroupingTests {

    // MARK: Cache invalidation on mutation

    @Test("Replacing entries rebuilds the groups rather than serving the previous ones")
    func mutatingEntriesInvalidatesTheCache() {
        // Proves `entries.didSet` actually fires through the `@Published` wrapper. If it
        // did not, the first read would be frozen in for the life of the process and the
        // History list would stop showing new dictations entirely.
        let history = TranscriptionHistory(storageDir: nil)
        let today = Date()

        history.entries = [TranscriptionEntry(text: "first", timestamp: today)]
        #expect(history.groupedByDate.count == 1)
        #expect(history.groupedByDate.first?.entries.count == 1)

        // A second day, so the group *count* changes and not merely the contents  - 
        // a stale cache would still report one group.
        let threeDaysAgo = today.addingTimeInterval(-3 * 86_400)
        history.entries = [
            TranscriptionEntry(text: "first", timestamp: today),
            TranscriptionEntry(text: "older", timestamp: threeDaysAgo),
        ]
        #expect(history.groupedByDate.count == 2)
    }

    @Test("In-place mutation invalidates too, not just whole-array assignment")
    func inPlaceMutationInvalidatesTheCache() {
        // `delete(entry:)` and `load()` mutate through `removeAll`/`append` rather than
        // assigning a new array. Those go through the same setter, but only because
        // Swift's exclusive-access rules turn them into get-modify-set - worth pinning,
        // since a future switch to a non-`@Published` storage could silently break it.
        let history = TranscriptionHistory(storageDir: nil)
        let now = Date()
        history.entries = [TranscriptionEntry(text: "keep", timestamp: now)]
        #expect(history.groupedByDate.first?.entries.count == 1)

        history.entries.append(TranscriptionEntry(text: "also today", timestamp: now))
        #expect(history.groupedByDate.count == 1)
        #expect(history.groupedByDate.first?.entries.count == 2)

        history.entries.removeAll()
        #expect(history.groupedByDate.isEmpty)
    }

    @Test("Entries from the same day land in one group, different days in separate ones")
    func groupsByCalendarDay() {
        let history = TranscriptionHistory(storageDir: nil)
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

        history.entries = [
            TranscriptionEntry(text: "noon", timestamp: noon),
            // Same calendar day, eight hours earlier - one group, not two.
            TranscriptionEntry(text: "morning", timestamp: noon.addingTimeInterval(-8 * 3_600)),
            TranscriptionEntry(text: "last week", timestamp: noon.addingTimeInterval(-9 * 86_400)),
        ]

        let groups = history.groupedByDate
        #expect(groups.count == 2)
        #expect(groups.first?.entries.count == 2)   // newest group leads
        #expect(groups.last?.entries.count == 1)
        #expect(groups.first?.label == "TODAY")
    }

    // MARK: The cache's date key

    @Test("The expiry is the next local midnight, strictly after the given moment")
    func nextMidnightIsTheFollowingLocalMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // Mid-afternoon.
        let afternoon = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14T22:13:20Z
        let next = TranscriptionHistory.nextMidnight(after: afternoon, calendar: cal)
        #expect(next > afternoon)
        #expect(cal.dateComponents([.year, .month, .day], from: next)
                == DateComponents(year: 2023, month: 11, day: 15))
        #expect(cal.component(.hour, from: next) == 0)
        #expect(cal.component(.minute, from: next) == 0)
        #expect(cal.component(.second, from: next) == 0)
    }

    @Test("Midnight itself expires at the *following* midnight, not immediately")
    func midnightDoesNotExpireInstantly() {
        // The boundary case. If `nextMidnight` returned the start of the same day, the
        // cache would be born already expired at 00:00:00 and rebuild on every single
        // read for that instant - reintroducing the stutter the cache exists to remove.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let midnight = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

        let next = TranscriptionHistory.nextMidnight(after: midnight, calendar: cal)
        #expect(next > midnight)
        #expect(next.timeIntervalSince(midnight) == 86_400)   // no DST in UTC
    }

    @Test("A short DST day expires after 23 hours, not a fixed 86,400 seconds")
    func springForwardDayIsTwentyThreeHours() {
        // Why the expiry is derived from the calendar instead of `+86_400`. On
        // 2023-03-12 in Los Angeles the clocks go forward at 02:00, so that local day is
        // 23 hours long. A fixed-seconds deadline would keep the cache - and its "TODAY"
        // labels - alive for an hour into the next day, which is precisely the window
        // where the label is wrong.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let springForward = cal.date(from: DateComponents(
            year: 2023, month: 3, day: 12, hour: 10))!
        let next = TranscriptionHistory.nextMidnight(after: springForward, calendar: cal)

        #expect(next.timeIntervalSince(cal.startOfDay(for: springForward)) == 23 * 3_600)
        #expect(cal.dateComponents([.year, .month, .day], from: next)
                == DateComponents(year: 2023, month: 3, day: 13))
        #expect(cal.component(.hour, from: next) == 0)
    }

    @Test("A long DST day expires after 25 hours, so the cache is not cut short")
    func fallBackDayIsTwentyFiveHours() {
        // The mirror image: 2023-11-05 in Los Angeles is 25 hours long. `+86_400` would
        // expire the cache an hour *early* - harmless for correctness but it would
        // rebuild the groups for no reason, which is the cost the cache exists to avoid.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let fallBack = cal.date(from: DateComponents(
            year: 2023, month: 11, day: 5, hour: 10))!
        let next = TranscriptionHistory.nextMidnight(after: fallBack, calendar: cal)

        #expect(next.timeIntervalSince(cal.startOfDay(for: fallBack)) == 25 * 3_600)
        #expect(cal.component(.hour, from: next) == 0)
    }

    @Test("A cache built now is treated as valid now")
    func aFreshCacheIsNotAlreadyExpired() {
        // The invariant the `groupedByDate` guard relies on: whatever time of day it is,
        // the expiry it stores is in the future. Checked against the real
        // `Calendar.current`, which is the one the store actually uses.
        let now = Date()
        #expect(TranscriptionHistory.nextMidnight(after: now) > now)
    }
}

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

    private func dayString(daysAgo: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }

    @Test("The streak is read once at launch and kept in memory, not re-read on each dictation")
    @MainActor
    func streakIsCached() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let streakFile = directory.appendingPathComponent("streak.json")
        let stored = [dayString(daysAgo: 2), dayString(daysAgo: 1)]
        try JSONSerialization.data(withJSONObject: stored).write(to: streakFile)

        let history = TranscriptionHistory(storageDir: directory)
        #expect(history.streakDays == 0)
        try FileManager.default.removeItem(at: streakFile)

        history.add(text: "counts for today")
        await MainActor.run {}
        history.flushPendingWrites()

        #expect(history.streakDays == 3)
        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: streakFile)) as? [String]
        #expect(written == (stored + [dayString(daysAgo: 0)]).sorted())
    }

    @Test("Opening the history writes no streak file until a day is recorded")
    func launchDoesNotWriteStreak() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let history = TranscriptionHistory(storageDir: directory)
        history.flushPendingWrites()

        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
