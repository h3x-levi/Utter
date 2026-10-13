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

/// Renders Home and Library to `.build/screen-snapshots/` in both appearances.
@Suite("Main window screens", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZMainWindowScreens {
    private let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    @Test func home() throws {
        let busier = ["On my way", "Can you pick up milk and something for dinner on the way home?",
                      "train times from Edinburgh to Glasgow Saturday morning", "Thanks everyone, great work today. Talk tomorrow.",
                      "Return early if the list is empty.", "Remind me to call the bank about the card before Friday."]
            .enumerated().map { TranscriptionEntry(text: $1, timestamp: noon.addingTimeInterval(Double(-14_000 - 2_500 * $0))) }
        let model = window(entries: sampleEntries + busier)
        model.home.readiness = .init(mic: true, ax: true, modelPresent: true, modelLoad: .ready)
        for dark in [false, true] { try render(model, "home", dark: dark) }

        let firstRun = window(entries: [])
        firstRun.home.readiness = .init(mic: false, ax: false, modelPresent: true, modelLoad: .ready)
        try render(firstRun, "home-setup", dark: false)
    }

    @Test func library() throws {
        let notes = sampleNotes
        let model = window(entries: sampleEntries, notes: notes)
        model.selection.item = .library
        model.selection.libraryItemID = LibraryItem.noteID(notes[0].id)
        for dark in [false, true] { try render(model, "library", dark: dark) }
        try render(model, "library-narrow", dark: false, size: NSSize(width: Layout.windowMinWidth, height: Layout.windowMinHeight))

        let empty = window(entries: [])
        empty.selection.item = .library
        empty.selection.libraryFilter = .meetings
        try render(empty, "library-empty", dark: false)
    }

    // MARK: Content

    private var sampleEntries: [TranscriptionEntry] {
        [
            ("Running five minutes late, start without me and I'll catch up.", -1_200),
            ("Shipped the fix for the login loop. Can someone double check it on the staging build before Thursday?", -2_400),
            ("Lunch at the usual place? I can book for four.", -5_000),
            ("Dear Ms Okafor, thank you for the quick reply. Tuesday works well for us, and I'll bring the revised plan.", -9_000),
            ("best ramen near Union Square open late", -12_000),
            ("Book the dentist for the week after next, mornings only.", -90_000),
        ].map { TranscriptionEntry(text: $0.0, timestamp: noon.addingTimeInterval($0.1)) }
    }

    private var sampleNotes: [Note] {
        [
            Note(title: "Design sync", body: """
            **You:** Let's start with the pill. The new version is closer, but the colours still feel loud.

            **Others:** Agreed. Could we keep one colour per state and drop the rest?

            **You:** Yes. Listening, hands-free, thinking, typed and error. Nothing else.
            """, created: noon.addingTimeInterval(-4_920), modified: noon.addingTimeInterval(-3_000),
                 source: .meeting, titleIsCustom: true),
            Note(body: "Ideas for the review\nStart with what changed, then the numbers, then questions.",
                 modified: noon.addingTimeInterval(-7_000)),
        ]
    }

    private func window(entries: [TranscriptionEntry], notes: [Note] = []) -> MainWindowModel {
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = entries
        return MainWindowModel(selection: SidebarSelection(arguments: []), status: CaptureStatus(),
                               userData: UserData(storageDir: nil), history: history,
                               notes: NoteStore(storageDir: nil, seed: notes), meeting: MeetingSession())
    }

    // MARK: Rendering

    private static func splitViews(in view: NSView?) -> [NSSplitView] {
        guard let view else { return [] }
        return [view as? NSSplitView].compactMap { $0 } + view.subviews.flatMap { splitViews(in: $0) }
    }

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
        window.center()
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))

        let columns = Self.splitViews(in: window.contentView).flatMap(\.arrangedSubviews).filter { !$0.isHidden }
        #expect(!columns.isEmpty)
        for column in columns {
            let frame = column.convert(column.bounds, to: nil)
            #expect(frame.minX >= -1 && frame.maxX <= size.width + 1, "\(name): a column spills out of the window at \(frame)")
        }

        let view = try #require(window.contentView?.superview ?? window.contentView)
        try SnapshotCanvas.capture(window, view: view, name, dark: dark)
    }

    @Test func hero() throws {
        let said = sampleEntries.map(\.text) + ["Yes", "Can you pick up milk and something for dinner on the way home?",
                                                "train times from Edinburgh to Glasgow Saturday morning", "Thanks everyone, great work today. Talk tomorrow.",
                                                "On my way", "Return early if the list is empty."]
        var items = said.enumerated().map { LibraryItem(TranscriptionEntry(text: $1, timestamp: noon.addingTimeInterval(Double(-500 * $0)))) }
        items.insert(LibraryItem(Note(body: "Book idea: a story told only through voicemails.", modified: noon.addingTimeInterval(-1_700))), at: 3)
        items.insert(LibraryItem(sampleNotes[0]), at: 7)
        for dark in [false, true] {
            let sheet = VStack(alignment: .leading, spacing: 28) {
                HomeHero(today: items, open: { _ in })
                HomeHero(today: items, open: { _ in }, hovered: items[4].id)
                HomeHero(today: [], open: { _ in })
            }
            .padding(.vertical, 28)
            .frame(width: 900)
            .background(.background)
            try SnapshotCanvas.write(NSHostingView(rootView: sheet), "home-hero", dark: dark, settle: 0.6)
        }
    }
}
