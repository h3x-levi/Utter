import AppKit
import SwiftUI
import Testing

@testable import UtterKit
@testable import UtterCore

/// Renders each onboarding step, light and dark, to `.build/screen-snapshots/`, in the real setup
/// window so the capture carries its titlebar and glass.
@Suite("Onboarding snapshots", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZOnboardingSnapshots {
    @Test func steps() throws {
        for dark in [false, true] {
            try render("welcome", dark: dark) { $0.demoFrame = 6 }
            try render("welcome-rest", dark: dark) { _ in }
            try render("welcome-command", dark: dark, hotkey: "rightCommand") { $0.demoFrame = 6 }
            try render("permissions", dark: dark) { $0.micGranted = true }
            try render("permissions-start", dark: dark) { _ in }
            try render("try", dark: dark) {
                $0.micGranted = true
                $0.axGranted = true
            }
            try render("try-success", dark: dark) {
                $0.micGranted = true
                $0.axGranted = true
                $0.typed = "Thanks Priya, Thursday at two works for me. I\u{2019}ll bring the draft."
            }
        }
    }

    @Test func livingMark() throws {
        for dark in [false, true] {
            let sheet = VStack(spacing: 24) {
                ForEach([240.0, 96.0, 24.0], id: \.self) { height in
                    HStack(spacing: 32) {
                        ForEach([LivingMark.Phase.rest, .listening, .thinking, .smile, .flat], id: \.self) { phase in
                            LivingMark(phase: phase, level: 0.6, tint: Look.Color.tint).frame(height: height)
                        }
                    }
                }
            }
            .padding(32)
            .background(.background)
            try SnapshotCanvas.write(sheet, "living-mark", size: CGSize(width: 1060, height: 520), dark: dark, settle: 0.8)
        }
    }

    private func render(_ name: String, dark: Bool, hotkey: String = "fn",
                        _ setUp: (OnboardingViewModel) -> Void) throws {
        let step = name.hasPrefix("welcome") ? 0 : name.hasPrefix("permissions") ? 1 : 2
        let userData = UserData(storageDir: nil)
        userData.hotkeyName = hotkey
        let model = OnboardingViewModel(stepOverride: step, userData: userData)
        setUp(model)
        let window = OnboardingView.makeWindow(OnboardingView(model: model, onFinish: { _ in }))
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.center()
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let view = try #require(window.contentView?.superview ?? window.contentView)
        try SnapshotCanvas.capture(window, view: view, "onboarding-\(name)", dark: dark)
    }
}
