import AppKit
import SwiftUI
import Testing

@testable import UtterKit

/// Renders each onboarding step, light and dark, to `.build/screen-snapshots/`. Hosted in an
/// `NSHostingView` because `ImageRenderer` cannot draw the system text field.
@Suite("Onboarding snapshots", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZOnboardingSnapshots {
    private static let output = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/screen-snapshots", isDirectory: true)

    @Test func steps() throws {
        for dark in [false, true] {
            try render("welcome", dark: dark) { $0.demoFrame = 6 }
            try render("welcome-rest", dark: dark) { _ in }
            try render("welcome-narrow", dark: dark, hotkey: "rightCommand", narrow: true) { $0.demoFrame = 6 }
            try render("permissions-narrow", dark: dark, hotkey: "rightCommand", narrow: true) { _ in }
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

    private func render(_ name: String, dark: Bool, hotkey: String = "fn", narrow: Bool = false,
                        _ setUp: (OnboardingViewModel) -> Void) throws {
        let step = name.hasPrefix("welcome") ? 0 : name.hasPrefix("permissions") ? 1 : 2
        let userData = UserData(storageDir: nil)
        userData.hotkeyName = hotkey
        let model = OnboardingViewModel(stepOverride: step, userData: userData)
        setUp(model)
        let host = NSHostingView(rootView: OnboardingView(model: model, onFinish: { _ in }))
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = narrow
            ? CGRect(x: 0, y: 0, width: Layout.onboardingMinWidth, height: Layout.onboardingMinHeight)
            : CGRect(x: 0, y: 0, width: Layout.onboardingIdealWidth, height: Layout.onboardingIdealHeight)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = host.appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: Self.output.appendingPathComponent("onboarding-\(name)-\(dark ? "dark" : "light").png"))
    }
}
