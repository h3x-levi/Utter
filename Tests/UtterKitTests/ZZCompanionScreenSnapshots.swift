import AppKit
import SwiftUI
import Testing

@testable import UtterKit
@testable import UtterCore

/// Renders the Companion tab of Settings and the floating robot's bubbles to `.build/screen-snapshots/` in both appearances.
@Suite("Companion screens", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct ZZCompanionScreenSnapshots {
    /// A companion with a name, a pinned note, reminders, two waiting memories, one done, and a morning on the tape.
    @MainActor
    static func seededCompanion(_ userData: UserData) -> CompanionSettingsModel {
        userData.companionEnabled = true
        userData.companionUserName = "Alex"
        userData.companionPinnedMessage = "Ship the release notes"
        userData.companionStretchMinutes = 45
        userData.companionWaterMinutes = 20
        userData.companionPomodoroFocusMinutes = 25
        userData.companionPomodoroBreakMinutes = 5
        var progress = CompanionProgress.today()
        progress.hydration = 2
        progress.stretches = 1
        userData.companionProgress = progress
        let now = Date()
        let memories = CompanionMemoryStore(storageDir: nil, seed: [
            CompanionMemory(text: "Call Sam about the venue", createdAt: now, remindAt: now.addingTimeInterval(5_400), source: .spoken),
            CompanionMemory(text: "The wifi password is on the fridge", createdAt: now, source: .spoken),
            CompanionMemory(text: "Book the dentist", createdAt: now.addingTimeInterval(-86_400), source: .typed,
                            completedAt: now.addingTimeInterval(-3_600)),
        ])
        let history = TranscriptionHistory(storageDir: nil)
        let start = Calendar.current.startOfDay(for: now)
        history.entries = [11, 13, 8, 64, 10, 20, 16, 13, 8, 8, 7, 18].enumerated().reversed().map { index, words in
            TranscriptionEntry(text: Array(repeating: "word", count: words).joined(separator: " "),
                               timestamp: start.addingTimeInterval(Double(index + 1) * 60))
        }
        return CompanionSettingsModel(userData: userData, memories: memories,
                                      notifications: CompanionNotificationScheduler(center: nil),
                                      selection: CompanionSectionSelection(), history: history)
    }

    /// The whole Companion tab at full height, so every row is in one picture.
    @MainActor
    @Test func companionTab() throws {
        for dark in [false, true] {
            try render(tab(Self.seededCompanion(UserData(storageDir: nil))), "companion", size: CGSize(width: 760, height: 1_640), dark: dark)
        }
        let empty = CompanionSettingsModel(userData: UserData(storageDir: nil), memories: CompanionMemoryStore(storageDir: nil),
                                           notifications: CompanionNotificationScheduler(center: nil),
                                           selection: CompanionSectionSelection(), history: TranscriptionHistory(storageDir: nil))
        try render(tab(empty), "companion-empty", size: CGSize(width: 760, height: 1_300), dark: false)
    }

    @MainActor
    private func tab(_ companion: CompanionSettingsModel) -> some View {
        let userData = companion.userData
        let model = SettingsModel(userData: userData, theme: ThemeManager(userData: userData), meeting: MeetingSession(),
                                  history: companion.history, notes: NoteStore(storageDir: nil), dataFolders: [],
                                  crashReports: { ([], false) }, openIssue: { _, _ in }, launchAtLogin: false)
        model.companion = companion
        model.group = .companion
        return SettingsWindowView(model: model)
    }

    @MainActor
    @Test func floatingBubbles() throws {
        let notices = [
            CompanionNotice(kind: .reminder, line: "Water break, Alex"),
            CompanionNotice(kind: .failure, line: "Couldn\u{2019}t start the microphone. Check Privacy & Security."),
            CompanionNotice(kind: .timer, line: "24:59", detail: "Ship the release notes"),
            CompanionNotice(kind: .pinned, line: "Ship the release notes"),
        ]
        let sheet = VStack(spacing: 18) {
            ForEach(notices, id: \.line) { notice in
                VStack(spacing: 4) {
                    CompanionBubbleView(notice: notice).frame(maxWidth: CompanionGeometry.bubbleWidth)
                    RobotPreview().frame(width: CompanionGeometry(.medium).robotSide, height: CompanionGeometry(.medium).robotSide)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        for dark in [false, true] {
            let backdrop = dark ? Color(red: 0.13, green: 0.16, blue: 0.22) : Color(red: 0.80, green: 0.86, blue: 0.93)
            try render(sheet.background(backdrop), "companion-floating", size: CGSize(width: 300, height: 560), dark: dark)
        }
    }

    @MainActor
    private func render(_ view: some View, _ name: String, size: CGSize, dark: Bool) throws {
        try SnapshotCanvas.write(view, name, size: size, dark: dark)
    }
}
