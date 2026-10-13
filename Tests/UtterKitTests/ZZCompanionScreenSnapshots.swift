import AppKit
import SwiftUI
import Testing

@testable import UtterKit
@testable import UtterCore

/// Renders the Companion section and the floating robot's bubbles to `.build/screen-snapshots/` in both appearances.
@Suite("Companion screens", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct ZZCompanionScreenSnapshots {
    @MainActor
    @Test func companionScreen() throws {
        let userData = UserData(storageDir: nil)
        userData.companionEnabled = true
        userData.companionUserName = "Alex"
        userData.companionPinnedMessage = "Ship the release notes"
        userData.companionWaterMinutes = 60
        userData.companionPomodoroFocusMinutes = 25
        var progress = CompanionProgress.today()
        progress.dictationWords = 320
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
        let model = CompanionScreenModel(userData: userData, memories: memories,
                                         notifications: CompanionNotificationScheduler(center: nil),
                                         selection: CompanionSectionSelection())
        for dark in [false, true] {
            try render(CompanionScreen(model: model).background(MoonlightGround()), "companion", size: CGSize(width: 944, height: 1_420), dark: dark)
        }
        let empty = CompanionScreenModel(userData: UserData(storageDir: nil), memories: CompanionMemoryStore(storageDir: nil),
                                         notifications: CompanionNotificationScheduler(center: nil),
                                         selection: CompanionSectionSelection())
        try render(CompanionScreen(model: empty).background(MoonlightGround()), "companion-empty", size: CGSize(width: 700, height: 1_780), dark: false)
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
