import AppKit
import SwiftUI
import Testing
@testable import UtterKit

/// Deterministic marketing captures from the production views.
///
/// This is intentionally test-only: it exercises the same `PillWindow` and
/// `CodePixelCatView` shipped by the app without adding screenshot switches to
/// the production executable.
@Suite("Product shot preview", .serialized)
@MainActor
struct ZZProductShotPreview {
    private var outputDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("ProductHuntAssets/raw", isDirectory: true)
    }

    @Test("Render pill states and code-drawn cats")
    func renderProductShots() throws {
        guard ProcessInfo.processInfo.environment["UTTER_RENDER_PRODUCT_SHOTS"] == "1" else {
            return
        }
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        NSApplication.shared.setActivationPolicy(.accessory)

        let previousAppendSetting = UserData.shared.captureAppendsToOpenNote
        let previousReduceMotion = MotionPreference.shared.reduceMotion
        UserData.shared.captureAppendsToOpenNote = false
        MotionPreference.shared.reduceMotion = true
        defer {
            UserData.shared.captureAppendsToOpenNote = previousAppendSetting
            MotionPreference.shared.reduceMotion = previousReduceMotion
        }

        let pill = PillWindow(onLongPress: {}, onStartHandsFree: {})
        if let screen = NSScreen.main {
            pill.setFrameOrigin(NSPoint(
                x: screen.visibleFrame.midX - pill.frame.width / 2,
                y: screen.visibleFrame.midY - pill.frame.height / 2
            ))
        }
        pill.orderFrontRegardless()

        let states: [(String, PillState, Int, Float, String, Bool)] = [
            ("pill-idle", .idle, 0, 0, "", false),
            ("pill-recording", .recording, 12, 0.72, "", false),
            ("pill-hands-free", .handsFree, 38, 0.48, "", true),
            ("pill-processing", .processing(.transcribing), 0, 0, "", false),
            ("pill-error", .error("No speech detected"), 0, 0, "", false),
            (
                "pill-note",
                .capturingNote,
                24,
                0.58,
                "Capture ideas as quickly as you can say them.",
                false
            ),
        ]

        for (name, state, elapsed, level, preview, pointerInside) in states {
            pill.stateModel.elapsed = elapsed
            pill.stateModel.level = level
            pill.stateModel.previewText = preview
            pill.stateModel.pointerInsidePill = pointerInside
            pill.stateModel.companionBehaviour = nil
            pill.stateModel.noteCardSettled = state == .capturingNote
            pill.stateModel.state = state
            settleLayout()
            try capture(window: pill, name: name)
            if name == "pill-note" {
                try validateNoteCard()
            }
        }

        pill.stateModel.state = .idle
        pill.stateModel.pointerInsidePill = false
        pill.orderFrontRegardless()
        settleLayout()

        let offer = MeetingOfferPanel(
            pill: pill,
            title: "You’re in a Zoom call",
            onAccept: {},
            onDecline: {}
        )
        offer.show()
        settleLayout()
        try capture(window: offer, name: "transcribe-offer")
        offer.orderOut(nil)
        pill.orderOut(nil)

        try captureSettingsWindows()

        try render(
            CodePixelCatView(
                style: .gray,
                mood: .resting,
                pose: .neutral,
                size: 512,
                elapsed: 0
            ),
            name: "pixel-cat-gray"
        )
        try render(
            CodePixelCatView(
                style: .orange,
                mood: .delighted,
                pose: .neutral,
                size: 512,
                elapsed: 0
            ),
            name: "pixel-cat-orange"
        )
        try render(CatPoseStrip(), name: "pixel-cat-poses")
    }

    private func captureSettingsWindows() throws {
        let previousGroup = SettingsSelection.shared.group
        defer { SettingsSelection.shared.group = previousGroup }

        let sidebar = NSHostingController(rootView: SettingsSidebar())
        sidebar.sizingOptions = []
        let detail = NSHostingController(rootView: SettingsDetail())
        detail.sizingOptions = []

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
        sidebarItem.minimumThickness = 170
        sidebarItem.maximumThickness = 230
        sidebarItem.preferredThicknessFraction = 0.2
        let detailItem = NSSplitViewItem(viewController: detail)
        detailItem.minimumThickness = 720

        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(detailItem)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_100, height: 760),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Utter Settings"
        window.contentViewController = split
        let captureSize = NSSize(width: 1_100, height: 760)
        window.contentMinSize = captureSize
        window.setContentSize(captureSize)
        window.center()
        window.orderFrontRegardless()
        // Reassert after the hosting controllers have completed their first layout.
        // This mirrors the production window's collapse guard.
        for _ in 0..<3 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.12))
            window.setContentSize(captureSize)
        }

        for (name, group) in [
            ("settings-general", SettingsGroup.general),
            ("settings-speech", SettingsGroup.speech),
        ] {
            SettingsSelection.shared.group = group
            settleLayout()
            try capture(window: window, name: name)
        }
        window.orderOut(nil)
    }

    private func settleLayout() {
        NSApp.updateWindows()
        RunLoop.main.run(until: Date().addingTimeInterval(0.55))
        NSApp.updateWindows()
    }

    private func capture(window: NSWindow, name: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [
            "-x",
            "-l",
            String(window.windowNumber),
            outputDirectory.appendingPathComponent("\(name).png").path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ProductShotError.captureFailed(name)
        }
    }

    private func render(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else {
            throw ProductShotError.renderFailed(name)
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw ProductShotError.renderFailed(name)
        }
        try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    private func validateNoteCard() throws {
        let url = outputDirectory.appendingPathComponent("pill-note.png")
        guard let image = NSImage(contentsOf: url),
              let data = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            throw ProductShotError.renderFailed("pill-note")
        }

        var brightInteriorPixels = 0
        let inset = 28
        for y in inset..<(bitmap.pixelsHigh - inset) {
            for x in inset..<(bitmap.pixelsWide - inset) {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.5 else {
                    continue
                }
                let brightness = max(
                    color.redComponent,
                    color.greenComponent,
                    color.blueComponent
                )
                if brightness > 0.58 {
                    brightInteriorPixels += 1
                }
            }
        }
        guard brightInteriorPixels > 500 else {
            throw ProductShotError.emptyNoteCard
        }
    }
}

private enum ProductShotError: Error {
    case captureFailed(String)
    case renderFailed(String)
    case emptyNoteCard
}

private struct CatPoseStrip: View {
    private let poses: [(String, CompanionMood, CompanionPose)] = [
        ("Ready", .resting, .neutral),
        ("Listening", .alert, .neutral),
        ("Typing", .kneading, .neutral),
        ("Celebrating", .delighted, .neutral),
    ]

    var body: some View {
        HStack(spacing: 36) {
            ForEach(Array(poses.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 14) {
                    CodePixelCatView(
                        style: index.isMultiple(of: 2) ? .gray : .orange,
                        mood: item.1,
                        pose: item.2,
                        size: 256,
                        elapsed: Double(index) * 0.17
                    )
                    Text(item.0)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(
                    Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
            }
        }
        .padding(44)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.06, blue: 0.11),
                    Color(red: 0.16, green: 0.10, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
