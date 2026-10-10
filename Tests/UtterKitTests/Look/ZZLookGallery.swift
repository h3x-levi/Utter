import AppKit
import SwiftUI
import Testing

@testable import UtterKit

/// Renders the Look component sheet and the Home first viewport to `.build/look-snapshots/`.
/// `ImageRenderer` cannot draw AppKit-backed views, so the sidebar here is drawn from Look parts
/// and the real `List` sidebar is rendered separately through an `NSHostingView`.
@Suite("Look gallery", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_LOOK_SNAPSHOTS"] == "1"))
struct ZZLookGallery {
    private static let output = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/look-snapshots", isDirectory: true)

    @MainActor
    @Test func componentSheet() throws {
        for dark in [false, true] { try render(ComponentSheet(), "components", dark: dark) }
    }

    @MainActor
    @Test func homeViewport() throws {
        for dark in [false, true] { try render(HomeViewport(), "home", dark: dark) }
    }

    @MainActor
    @Test func hostedSidebar() throws {
        for dark in [false, true] {
            let host = NSHostingView(rootView: HostedSidebar().environment(\.colorScheme, dark ? .dark : .light))
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 170)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            try save(rep, "sidebar-list", dark: dark)
        }
    }

    @MainActor
    private func render(_ view: some View, _ name: String, dark: Bool) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, dark ? .dark : .light))
        renderer.scale = 2
        var image: CGImage?
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance { image = renderer.cgImage }
        try save(NSBitmapImageRep(cgImage: try #require(image)), name, dark: dark)
    }

    private func save(_ rep: NSBitmapImageRep, _ name: String, dark: Bool) throws {
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: Self.output.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
    }
}

// MARK: - Synthetic content (FRAME.md)

private enum Frame {
    static func time(_ h: Int, _ m: Int, _ s: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: h, minute: m, second: s))!
    }

    static let cues: [(Int, Date, String, Int, String)] = [
        (214, time(9, 31, 4), "Mail", 38, "Thanks Priya, Thursday at two works for me. I’ll bring the draft and we can go through the numbers together."),
        (213, time(9, 20, 47), "Slack", 14, "On it, I’ll push the fix after lunch and ping you when it’s live."),
        (212, time(9, 5, 12), "Notes", 64, "Groceries for the weekend: oat milk, lemons, the good bread from the corner place, and something for Sunday dinner."),
        (211, time(8, 50, 33), "Safari", 9, "best hiking trails near lake tahoe in october"),
    ]

    static let heroText = "Thanks Priya, Thursday at two works for me. I’ll bring the draft and we can"

    /// Stands in for the native sidebar material, which offscreen rendering drops.
    static let sidebar = SwiftUI.Color(nsColor: NSColor(name: nil) {
        $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.15, green: 0.15, blue: 0.16, alpha: 1)
            : NSColor(srgbRed: 0.914, green: 0.914, blue: 0.925, alpha: 1)
    })
}

// MARK: - Home first viewport

private struct HomeViewport: View {
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            main
        }
        .frame(width: 1060, height: 690)
        .background(Look.Color.ground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label { Text("Utter").font(Look.Font.body.weight(.bold)) } icon: { Image(systemName: "waveform") }
                .foregroundStyle(Look.Color.ink)
                .padding(.leading, Look.Space.x3)
                .padding(.top, 58)
                .padding(.bottom, Look.Space.x5)
            ForEach([("Home", "house"), ("Library", "tray.full"), ("Words", "character.book.closed"), ("Companion", "pawprint")], id: \.0) { item in
                MockSidebarRow(title: item.0, symbol: item.1, isSelected: item.0 == "Home")
            }
            Spacer()
            MockSidebarRow(title: "Settings", symbol: "gearshape", isSelected: false)
            Look.SoundTag("listening", state: .live)
                .padding(.horizontal, Look.Space.x3)
                .padding(.vertical, Look.Space.x3)
        }
        .padding(.horizontal, Look.Space.x2 + 2)
        .frame(width: 200, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Frame.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Look.Color.hairline).frame(width: 0.5) }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Home")
                .font(Look.Font.body.weight(.semibold))
                .foregroundStyle(Look.Color.ink)
                .frame(height: 52)
            Look.CaptionPlate(text: Frame.heroText, liveWord: "go", caret: true)
            HStack(alignment: .firstTextBaseline, spacing: Look.Space.x5) {
                Look.SoundTag("listening", widest: "transcribing")
                Look.SoundTag("writing into Mail")
                Text(verbatim: "0:07").font(Look.Font.mono).foregroundStyle(Look.Color.inkTertiary)
            }
            .padding(.top, Look.Space.x3)
            HStack(alignment: .top, spacing: Look.Space.x4) {
                recent
                ready.frame(width: 296)
            }
            .padding(.top, Look.Space.x7)
        }
        .padding(.horizontal, Look.Space.x7)
        .padding(.bottom, Look.Space.x6)
    }

    private var recent: some View {
        Look.Well {
            HStack(alignment: .firstTextBaseline) {
                Text("Earlier today").font(Look.Font.heading).foregroundStyle(Look.Color.ink)
                Spacer()
                Text("1,284 words this week").font(Look.Font.secondary).foregroundStyle(Look.Color.inkSecondary)
            }
            VStack(alignment: .leading, spacing: Look.Space.x6) {
                ForEach(Frame.cues, id: \.0) { cue in
                    Look.CueRow(number: cue.0, time: cue.1, app: cue.2, words: cue.3, text: cue.4)
                }
            }
            .padding(.top, Look.Space.x4)
            Spacer(minLength: Look.Space.x6)
            Button("Show all in Library") {}.buttonStyle(Look.QuietButtonStyle())
        }
        .frame(maxHeight: .infinity)
    }

    private var ready: some View {
        Look.Well {
            Text("Ready").font(Look.Font.heading).foregroundStyle(Look.Color.ink)
            VStack(alignment: .leading, spacing: Look.Space.x2) {
                Look.ReadinessTag(label: "Microphone on", state: .ready)
                Look.ReadinessTag(label: "Accessibility on", state: .ready)
                Look.ReadinessTag(label: "Small English model loaded", state: .ready)
            }
            .padding(.top, Look.Space.x3)
            Text("Shortcut").font(Look.Font.heading).foregroundStyle(Look.Color.ink).padding(.top, Look.Space.x7)
            HStack(spacing: Look.Space.x3) {
                Look.Keycap("fn")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hold to talk.").foregroundStyle(Look.Color.ink)
                    Text("Double-tap for hands-free.").foregroundStyle(Look.Color.inkSecondary)
                }
                .font(Look.Font.secondary)
            }
            .padding(.top, Look.Space.x3)
            HStack(spacing: Look.Space.x3) {
                CodePixelCatView(style: .gray, mood: .sleepy, pose: .neutral, size: 44, elapsed: 0)
                Text("Charcoal Cat is napping").font(Look.Font.secondary).foregroundStyle(Look.Color.ink)
            }
            .padding(.top, Look.Space.x7)
            Spacer(minLength: Look.Space.x6)
            VStack(alignment: .leading, spacing: 2) {
                Text("Runs on this Mac.").foregroundStyle(Look.Color.ink)
                Text("Your voice never leaves it.").foregroundStyle(Look.Color.inkSecondary)
            }
            .font(Look.Font.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}

/// The offscreen stand-in for a `List` row with `lookSidebarRow`.
private struct MockSidebarRow: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: symbol)
            .font(isSelected ? Look.Font.heading : Look.Font.secondary)
            .foregroundStyle(isSelected ? Look.Color.plateInk : Look.Color.ink)
            .padding(.horizontal, Look.Space.x3)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background { if isSelected { Color.clear.lookPlate() } }
    }
}

private struct HostedSidebar: View {
    var body: some View {
        List(selection: .constant("Home")) {
            ForEach([("Home", "house"), ("Library", "tray.full"), ("Words", "character.book.closed"), ("Companion", "pawprint")], id: \.0) { item in
                Label(item.0, systemImage: item.1)
                    .lookSidebarRow(isSelected: item.0 == "Home")
                    .tag(item.0)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Frame.sidebar)
    }
}

// MARK: - Component sheet

private struct ComponentSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Look.Space.x6) {
            section("Caption plate, hero, streaming") {
                Look.CaptionPlate(text: Frame.heroText, liveWord: "go", caret: true)
            }
            section("Caption plate, hero, idle") {
                Look.CaptionPlate(text: "Hold fn and talk.")
            }
            section("Caption plate, pill, with live dot and time; rolled up past two lines") {
                HStack(spacing: Look.Space.x6) {
                    pill(text: "I’ll bring the draft and we can go", live: "through")
                    pill(text: Frame.heroText + " go through the numbers together on", live: "Thursday")
                }
            }
            section("Sound tags") {
                HStack(spacing: Look.Space.x5) {
                    Look.SoundTag("listening")
                    Look.SoundTag("ready", widest: "transcribing")
                    Look.SoundTag("typed", state: .ok)
                    Look.SoundTag("no text box", state: .warn)
                    Look.SoundTag("listening", state: .live)
                }
            }
            section("Readiness") {
                HStack(alignment: .top, spacing: Look.Space.x4) {
                    Look.Well(spacing: Look.Space.x2) {
                        Look.ReadinessTag(label: "Microphone on", state: .ready)
                        Look.ReadinessTag(label: "Loading small English model", state: .working)
                        Look.ReadinessTag(label: "Accessibility off", state: .missing) {}
                        Look.ReadinessTag(label: "Speech model missing", state: .missing, actionTitle: "Download") {}
                    }
                    Look.Well {
                        Look.EmptyCue(message: "Nothing dictated yet. Hold fn and talk.", actionTitle: "Try it now") {}
                    }
                }
            }
            section("Cue rows") {
                Look.Well(spacing: Look.Space.x6) {
                    ForEach(Frame.cues.prefix(2), id: \.0) { cue in
                        Look.CueRow(number: cue.0, time: cue.1, app: cue.2, words: cue.3, text: cue.4)
                    }
                    Look.CueRow(number: 12045, time: Frame.time(23, 59, 59), app: "Visual Studio Code", words: 1, text: "Yes.")
                }
            }
            section("Keycaps, buttons, live dot, sidebar rows") {
                HStack(alignment: .center, spacing: Look.Space.x5) {
                    Look.Keycap("fn")
                    Look.Keycap("right ⌥")
                    HStack(spacing: Look.Space.x2) {
                        Button("Copy") {}.buttonStyle(Look.PlateButtonStyle())
                        Button("Copy") {}.buttonStyle(Look.PlateButtonStyle()).disabled(true)
                    }
                    .padding(Look.Space.x3)
                    .lookPlate()
                    Button("Show all in Library") {}.buttonStyle(Look.QuietButtonStyle())
                    Button("Show all in Library") {}.buttonStyle(Look.QuietButtonStyle()).disabled(true)
                    Look.LiveDot()
                    VStack(spacing: 2) {
                        MockSidebarRow(title: "Home", symbol: "house", isSelected: true)
                        MockSidebarRow(title: "Library", symbol: "tray.full", isSelected: false)
                    }
                    .frame(width: 180)
                    .padding(Look.Space.x2)
                    .background(Frame.sidebar)
                }
            }
        }
        .padding(Look.Space.x8)
        .frame(width: 1100, alignment: .leading)
        .background(Look.Color.ground)
    }

    private func pill(text: String, live: String) -> some View {
        Look.CaptionPlate(text: text, liveWord: live, size: .pill) {
            HStack(spacing: 7) {
                Look.LiveDot()
                Text(verbatim: "0:07").font(Look.Font.mono).foregroundStyle(Look.Color.plateInkSecondary)
            }
        }
        .frame(width: 500)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Look.Space.x2) {
            Text(title).font(Look.Font.secondary).foregroundStyle(Look.Color.inkSecondary)
            content()
        }
    }
}
