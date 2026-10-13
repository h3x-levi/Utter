import Combine
import Foundation
import Testing

@testable import UtterKit
@testable import UtterCore

@Suite("Settings")
struct SettingsTests {
    private static let scratch = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/settings-tests", isDirectory: true)

    private func folder() throws -> URL {
        let url = Self.scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Stored theme ids map to System, Light or Dark", arguments: [
        ("paper", "light"), ("linen", "light"),
        ("graphite", "dark"), ("violet", "dark"), ("pine", "dark"), ("ember", "dark"),
        ("system", "system"), ("light", "light"), ("dark", "dark"), ("midnight", "system"),
    ])
    func storedThemeMigrates(stored: String, expected: String) {
        #expect(AppTheme.find(stored).id == expected)
    }

    @Test("A settings file saved with Ember opens in Dark")
    func emberLoadsAsDark() throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"appTheme": "ember"}"#.utf8).write(to: directory.appendingPathComponent("userdata.json"))

        #expect(ThemeManager(userData: UserData(storageDir: directory)).current == .dark)
    }

    @MainActor
    @Test("Reset drops a queued settings write before it deletes the folder")
    func resetDiscardsPendingSave() async throws {
        let directory = try folder()
        defer { try? FileManager.default.removeItem(at: directory) }
        let userData = UserData(storageDir: directory, debounce: 0.05)
        let model = SettingsModel(userData: userData, theme: ThemeManager(userData: userData),
                                  meeting: MeetingSession(), history: TranscriptionHistory(storageDir: nil),
                                  notes: NoteStore(storageDir: nil), dataFolders: [directory],
                                  crashReports: { ([], false) }, levels: Empty().eraseToAnyPublisher(),
                                  openIssue: { _, _ in }, launchAtLogin: false)
        userData.alwaysShowPill = false
        userData.save()

        model.reset()
        try await Task.sleep(for: .milliseconds(250))

        #expect(FileManager.default.fileExists(atPath: directory.path), "later saves need the folder back")
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("userdata.json").path))
        #expect(model.resetDone)
    }

    @MainActor
    @Test("The issue link keeps & = + # in what was typed, and the crash log loses the home folder")
    func issueLink() throws {
        let model = ReportIssueModel(crashLog: "Signal: SIGABRT\nPath: /Users/alex/Library/Utter", category: .bug,
                                     appVersion: "1.1.58", speechModel: "small", hotkey: "Fn",
                                     macOS: "Version 26.7", home: "/Users/alex", close: {})
        model.title = "Fn & Space = nothing + #2"

        let url = try #require(model.issueURL)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "title" }?.value == "[Bug]: Fn & Space = nothing + #2")
        #expect(items.first { $0.name == "body" }?.value == model.report)
        #expect(!model.report.contains("/Users/alex"))
        #expect(model.report.contains("~/Library/Utter"))
    }

    @MainActor
    @Test("Tape length Off leaves no goal, and words dictated with Keep history off still count")
    func tapeGoalAndUnkeptWords() {
        let userData = UserData(storageDir: nil)
        #expect(userData.tapeGoal == 500)
        userData.companionDictationGoal = 0
        #expect(userData.tapeGoal == nil)

        userData.recordCompanionDictation(words: 12)
        #expect(userData.unkeptWordsToday(onTape: 0) == 0, "history keeps them, so they're tracks already")
        userData.keepHistory = false
        #expect(userData.unkeptWordsToday(onTape: 5) == 7)
        #expect(TapeSegment.unkept(7, id: 1).map(\.words) == [7])
        #expect(TapeSegment<Int>.unkept(0, id: 1).isEmpty)
    }

    @MainActor
    @Test("The daily tape counts today's tracks like the hub, oldest first, and opens on the Companion tab")
    func dailyTape() {
        let history = TranscriptionHistory(storageDir: nil)
        let start = Calendar.current.startOfDay(for: Date())
        let older = TranscriptionEntry(text: "one two three", timestamp: start.addingTimeInterval(1))
        let newer = TranscriptionEntry(text: "four five", timestamp: start.addingTimeInterval(3))
        let yesterday = TranscriptionEntry(text: "not on today's tape", timestamp: start.addingTimeInterval(-3_600))
        history.entries = [newer, older, yesterday]
        let note = Note(body: "Pack bags", modified: start.addingTimeInterval(2))
        let notes = NoteStore(storageDir: nil, seed: [note, Note(body: "", modified: start.addingTimeInterval(4))])
        let selection = CompanionSectionSelection()
        let companion = CompanionSettingsModel(userData: UserData(storageDir: nil), memories: CompanionMemoryStore(storageDir: nil),
                                               notifications: CompanionNotificationScheduler(center: nil),
                                               selection: selection, history: history, notes: notes)

        #expect(companion.todayTape.map(\.id) == [older.id, note.id, newer.id], "an empty note isn't a track")
        #expect(companion.wordsToday == 7)
        let hub = HubModel()
        hub.reload(entries: history.entries, notes: notes.notes)
        #expect(companion.todayTape.map(\.id) == hub.segments.map(\.id), "Settings and the hub show the same tape")

        let model = SettingsModel(userData: companion.userData, theme: ThemeManager(userData: companion.userData),
                                  meeting: MeetingSession(), history: history, notes: NoteStore(storageDir: nil),
                                  dataFolders: [], crashReports: { ([], false) }, openIssue: { _, _ in }, launchAtLogin: false)
        model.companion = companion
        model.showCompanion(.remember)
        #expect(model.group == .companion)
        #expect(selection.section == .remember)
    }

    @Test("What's New lists only user-facing notes")
    func whatsNewIsUserFacing() {
        let releases = WhatsNewView.releases
        let lines = releases.flatMap(\.highlights)
        #expect(!lines.contains { $0.hasPrefix("Internal build") || $0.contains("\u{2014}") })
        #expect(releases.allSatisfy { !$0.highlights.isEmpty && Set($0.highlights).count == $0.highlights.count })
        #expect(Set(releases.map(\.id)).count == releases.count)
    }
}
