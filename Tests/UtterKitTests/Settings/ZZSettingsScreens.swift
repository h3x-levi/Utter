import AppKit
import Combine
import SwiftUI
import Testing

@testable import UtterKit
@testable import UtterCore

/// Renders Settings (in its real window), Report Issue and What's New to `.build/screen-snapshots/` in both appearances.
@Suite("Settings screens", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct ZZSettingsScreens {
    @MainActor
    @Test func settingsPanes() throws {
        let userData = UserData(storageDir: nil)
        userData.offerToTranscribeCalls = true
        userData.useSurroundingContext = true
        let crash = """
        Utter crash report
        Signal: SIGSEGV
        Version: 1.1.57
        """
        let model = SettingsModel(
            userData: userData, theme: ThemeManager(userData: userData), meeting: MeetingSession(),
            history: TranscriptionHistory(storageDir: nil), notes: NoteStore(storageDir: nil), dataFolders: [],
            crashReports: {
                let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 16, minute: 42))!
                let url = URL(fileURLWithPath: "/tmp/crash-2026-10-09.log")
                return ([CrashLogSummary(url: url, date: date, content: crash)], true)
            },
            levels: Just(0.62).eraseToAnyPublisher(), openIssue: { _, _ in },
            appVersion: "1.1.58", launchAtLogin: true)

        for group in SettingsGroup.allCases {
            model.group = group
            for dark in [false, true] {
                let window = SettingsWindowView.makeWindow(model: model)
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                window.center()
                window.orderFrontRegardless()
                defer { window.orderOut(nil) }
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                let view = try #require(window.contentView?.superview ?? window.contentView)
                try SnapshotCanvas.capture(window, view: view, "settings-\(group.rawValue)", dark: dark)
            }
        }
    }

    @MainActor
    @Test func reportIssue() throws {
        let model = ReportIssueModel(crashLog: "Signal: SIGSEGV\nVersion: 1.1.57", category: .bug,
                                     appVersion: "1.1.58", speechModel: "small", hotkey: "Fn",
                                     macOS: "Version 26.7.1 (Build 25G241)", close: {})
        model.title = "Dictation stops after the Mac wakes up"
        model.details = "After sleep the pill shows listening but no words arrive."
        for dark in [false, true] {
            try render(ReportIssueSheet(model: model), "report-issue", size: CGSize(width: 520, height: 420), dark: dark)
        }
    }

    @MainActor
    @Test func whatsNew() throws {
        for dark in [false, true] {
            try render(WhatsNewView(appVersion: "1.1.58"), "whats-new", size: CGSize(width: 560, height: 620), dark: dark)
        }
    }

    @MainActor
    private func render(_ view: some View, _ name: String, size: CGSize, dark: Bool) throws {
        try SnapshotCanvas.write(view, name, size: size, dark: dark)
    }
}
