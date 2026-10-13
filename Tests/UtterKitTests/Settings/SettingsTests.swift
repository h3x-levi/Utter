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

    @Test("What's New lists only user-facing notes")
    func whatsNewIsUserFacing() {
        let releases = WhatsNewView.releases
        let lines = releases.flatMap(\.highlights)
        #expect(!lines.contains { $0.hasPrefix("Internal build") || $0.contains("\u{2014}") })
        #expect(releases.allSatisfy { !$0.highlights.isEmpty && Set($0.highlights).count == $0.highlights.count })
        #expect(Set(releases.map(\.id)).count == releases.count)
    }
}
