import AppKit
import SwiftUI
import Testing
@testable import UtterKit
@testable import UtterCore

/// The one place that turns a view into a PNG under `.build/screen-snapshots/`, found by walking up to
/// `Package.swift` so moving a test file cannot misplace the output.
enum SnapshotCanvas {
    static let root: URL = {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/", !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            url.deleteLastPathComponent()
        }
        return url
    }()

    static func directory(_ name: String = "screen-snapshots") throws -> URL {
        let url = root.appendingPathComponent(".build/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func file(_ name: String, dark: Bool) throws -> URL {
        try directory().appendingPathComponent("\(name)-\(dark ? "dark" : "light").png")
    }

    @MainActor
    static func write(_ view: some View, _ name: String, size: CGSize, dark: Bool, settle: TimeInterval = 0.4) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        try write(host, name, dark: dark, settle: settle)
    }

    @MainActor
    static func write(_ host: NSView, _ name: String, dark: Bool, settle: TimeInterval = 0.4) throws {
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        if host.frame.isEmpty { host.frame = CGRect(origin: .zero, size: host.fittingSize) }
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = host.appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(settle))
        try cache(host, to: file(name, dark: dark))
    }

    /// Centres the window on the sharpest display, so captures come out at 2x when a Retina screen is attached.
    @MainActor
    static func center(_ window: NSWindow) {
        guard let screen = NSScreen.screens.max(by: { $0.backingScaleFactor < $1.backingScaleFactor }) else { return window.center() }
        let frame = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: frame.midX - window.frame.width / 2, y: frame.midY - window.frame.height / 2))
    }

    /// The window server's capture includes glass, which offscreen drawing drops; `view` is the fallback.
    @MainActor
    static func capture(_ window: NSWindow, view: NSView, _ name: String, dark: Bool) throws {
        let file = try file(name, dark: dark)
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l\(window.windowNumber)", file.path]
        try capture.run()
        capture.waitUntilExit()
        guard capture.terminationStatus != 0 else { return }
        try cache(view, to: file)
    }

    @MainActor
    private static func cache(_ view: NSView, to file: URL) throws {
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        try #require(rep.representation(using: .png, properties: [:])).write(to: file)
    }
}

/// Renders Library to `.build/screen-snapshots/`, with the mock's sample day.
@Suite("Main window screens", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZMainWindowScreens {
    private func today(_ hour: Int, _ minute: Int, days: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    @Test func library() throws {
        let model = window()
        let okafor = try #require(model.library.allItems.first { $0.title.hasPrefix("Dear Ms Okafor") })
        model.library.selectedID = okafor.id
        for dark in [false, true] { try render(model, "library", dark: dark) }

        model.library.search = "the"
        try render(model, "library-search", dark: false)
        model.library.search = ""

        let meeting = try #require(model.library.allItems.first { $0.kind == .meeting })
        model.library.selectedID = meeting.id
        try render(model, "library-meeting", dark: true)

        model.selection.libraryFilter = .notes
        model.library.selectedID = try #require(model.library.allItems.first { $0.kind == .note }).id
        try render(model, "library-notes", dark: false)

        model.selection.libraryFilter = .all
        model.library.selectedID = okafor.id
        try render(model, "library-narrow", dark: false, size: NSSize(width: Layout.windowMinWidth, height: Layout.windowMinHeight))

        let empty = window(entries: [], notes: [])
        empty.selection.libraryFilter = .meetings
        try render(empty, "library-empty", dark: false)

        let firstRun = window(entries: [], notes: [], ready: false)
        try render(firstRun, "library-setup", dark: false)
    }

    @Test func meetingBanner() throws {
        let hint = MeetingNote.hint(heardOthers: true, onSpeakers: true)
        let banner = VStack(spacing: 12) {
            MeetingNote.recording(elapsed: 184, hint: hint, levels: { (0.7, 0.4) }, pause: {}, stop: {})
            MeetingNote.paused(elapsed: 184, problem: nil, resume: {}, stop: {})
        }
        .padding(18).frame(width: 460).background(Mixtape.paper)
        for dark in [false, true] {
            try SnapshotCanvas.write(banner, "meeting-banner-speakers", size: CGSize(width: 460, height: 260), dark: dark)
        }
    }

    // MARK: Content

    private var sampleEntries: [TranscriptionEntry] {
        [
            ("Hi Sam, the slides look great. One small thing: can we swap slides four and five before Thursday?", "Mail", today(21, 31)),
            ("Thanks everyone, great work today. Talk tomorrow.", "Slack", today(21, 2)),
            ("train times from Edinburgh to Glasgow Saturday morning", "Safari", today(18, 20)),
            ("Can you pick up milk and something for dinner on the way home?", "Messages", today(16, 48)),
            ("Shipped the fix for the login loop. Can someone double check it on the staging build?", "Slack", today(15, 12)),
            ("Dear Ms Okafor, thank you for the quick reply. Tuesday works well for us, and I\u{2019}ll bring the revised plan.", "Mail", today(13, 2)),
            ("Lunch at the usual place? I can book for four.", "Slack", today(12, 15)),
            ("Running ten minutes late, save me a seat.", "Messages", today(10, 5)),
            ("Morning all. I\u{2019}m in at nine thirty, starting with the review.", "Slack", today(8, 12)),
            ("Send Ms Okafor the revised plan before Tuesday.", "Mail", today(17, 40, days: 1)),
            ("Book the dentist for the week after next, mornings only.", "", today(9, 15, days: 1)),
        ].map { TranscriptionEntry(text: $0.0, timestamp: $0.2, app: $0.1, duration: $0.0.hasPrefix("Dear") ? 8 : 0) }
    }

    private var sampleNotes: [Note] {
        [
            Note(title: "Design sync", body: """
            **You:** Let's start with the pill. The new version is closer, but the colours still feel loud.

            **Others:** Agreed. Could we keep one colour per state and drop the rest?

            **You:** Yes. Listening, hands-free, thinking, typed and error. Nothing else.

            **Others:** And the error should stay small until someone looks at it.
            """, created: today(11, 0), modified: today(11, 32), source: .meeting, titleIsCustom: true),
            Note(title: "Book idea", body: "Book idea\nA story told only through voicemails.", modified: today(19, 55), titleIsCustom: true),
            Note(title: "Ideas for the review", body: "Ideas for the review\nStart with what changed, then the numbers, then questions.",
                 modified: today(9, 20), titleIsCustom: true),
        ]
    }

    private func window(entries: [TranscriptionEntry]? = nil, notes: [Note]? = nil, ready: Bool = true) -> MainWindowModel {
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = entries ?? sampleEntries
        let model = MainWindowModel(selection: SidebarSelection(arguments: []), status: CaptureStatus(),
                                    userData: UserData(storageDir: nil), history: history,
                                    notes: NoteStore(storageDir: nil, seed: notes ?? sampleNotes), meeting: MeetingSession())
        model.setup.readiness = .init(mic: ready, ax: ready, modelPresent: true, modelLoad: .ready)
        model.words.refreshSuggestions()
        return model
    }

    // MARK: Rendering

    private func render(_ model: MainWindowModel, _ name: String, dark: Bool,
                        size: NSSize = NSSize(width: 1_180, height: 780)) throws {
        let hosting = NSHostingController(rootView: MainWindowView(model: model))
        hosting.sizingOptions = []
        hosting.sceneBridgingOptions = .all
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.toolbarStyle = .unified
        window.contentViewController = hosting
        window.setContentSize(size)
        SnapshotCanvas.center(window)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        let fitted = hosting.sizeThatFits(in: size)
        #expect(fitted.width <= size.width + 1, "\(name): the columns need \(fitted.width) pt in a \(size.width) pt window")
        #expect(window.titleVisibility == .hidden && window.titlebarAppearsTransparent, "\(name): the title bar should be clear")

        let view = try #require(window.contentView?.superview ?? window.contentView)
        try SnapshotCanvas.capture(window, view: view, name, dark: dark)
    }
}
