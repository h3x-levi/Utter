import AppKit
import SwiftUI
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Menu-bar hub")
@MainActor
struct HubTests {
    private static func at(_ hour: Int, _ minute: Int, daysAgo: Int = 0) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private static let evening = at(21, 41)

    private func model(_ entries: [TranscriptionEntry], _ notes: [Note] = []) -> HubModel {
        let model = HubModel()
        model.reload(entries: entries, notes: notes, now: Self.evening)
        return model
    }

    @Test("Today's tracks are newest first, numbered in the day's order, and yesterday stays off the tape")
    func todayAndNumbering() {
        let model = model([
            TranscriptionEntry(text: "Old news from yesterday", timestamp: Self.at(10, 0, daysAgo: 1)),
            TranscriptionEntry(text: "Morning all", timestamp: Self.at(8, 12)),
            TranscriptionEntry(text: "Lunch at the usual place?", timestamp: Self.at(13, 2)),
        ], [
            Note(body: "Book idea\nA story told only through voicemails.", created: Self.at(19, 55), modified: Self.at(19, 55)),
            Note(title: "Design sync", body: "**You:** Let's start with the pill.", created: Self.at(11, 0),
                 modified: Self.at(11, 32), source: .meeting),
            Note(body: "", created: Self.at(20, 0), modified: Self.at(20, 0)),
        ])

        #expect(model.today.map(\.title) == ["Book idea", "Lunch at the usual place?", "Design sync", "Morning all"])
        #expect(model.today.map(\.number) == [4, 3, 2, 1])
        #expect(model.today.map(\.kind) == [.note, .dictation, .meeting, .dictation])
        #expect(model.tracks.last?.title == "Old news from yesterday")
        #expect(model.tracks.last?.number == 1)
        #expect(model.segments.map(\.label) == ["Morning all", "Design sync", "Lunch at the usual place?", "Book idea"])
        #expect(model.heading == "Today, side B")
        #expect(model.rows == model.today)
    }

    @Test("The list shows the eight latest; the count covers the whole day")
    func eightLatest() {
        let model = model((0..<10).map { TranscriptionEntry(text: "Track \($0)", timestamp: Self.at(9 + $0, 0)) })

        #expect(model.rows.count == 8)
        #expect(model.rows.first?.title == "Track 9")
        #expect(model.rows.first?.number == 10)
        #expect(model.detail == "10 tracks \u{00B7} 0 min 30 s")
        model.move(20)
        #expect(model.selection == 7)
        model.move(-30)
        #expect(model.selection == 0)
    }

    @Test("Search looks through every day, note bodies and meetings, ignoring case")
    func search() {
        let model = model([
            TranscriptionEntry(text: "Pick up MILK on the way home", timestamp: Self.at(10, 0, daysAgo: 3)),
            TranscriptionEntry(text: "Morning all", timestamp: Self.at(8, 12)),
        ], [
            Note(body: "Book idea\nA story told only through voicemails.", created: Self.at(19, 55), modified: Self.at(19, 55)),
            Note(title: "Design sync", body: "**Others:** Could we keep one colour per state?", created: Self.at(11, 0),
                 modified: Self.at(11, 32), source: .meeting),
        ])

        model.query = "milk"
        #expect(model.rows.map(\.title) == ["Pick up MILK on the way home"])
        #expect(model.heading == "Found")
        #expect(model.detail == "1 track")
        model.query = "voicemail"
        #expect(model.rows.map(\.title) == ["Book idea"])
        model.query = " colour "
        #expect(model.rows.map(\.kind) == [.meeting])
        model.query = "nothing like this"
        #expect(model.rows.isEmpty)
        model.query = ""
        #expect(model.rows.count == 3)
    }

    @Test("Running and talk time use recorded seconds and estimate the rest from words")
    func talkTime() {
        let model = model([
            TranscriptionEntry(text: "Hi Sam, the slides look great. One small thing: can we swap slides four and five before Thursday?",
                               timestamp: Self.at(21, 31)),
            TranscriptionEntry(text: "Running late", timestamp: Self.at(21, 2), duration: 3.25),
        ], [
            Note(title: "Design sync", body: "**You:** Short.", created: Self.at(11, 0), modified: Self.at(11, 32), source: .meeting),
        ])

        #expect(model.today.map(\.time) == ["0:08", "0:03", "32:00"])
        #expect(HubTrack.talkTime(model.today) == "32 min 11 s")
    }

    @Test("Status comes from recording first, then the readiness needs")
    func status() {
        let model = HubModel()
        #expect(model.stripeLabel == "Ready \u{00B7} hold Fn")
        model.needs = HubNeed.needs(mic: true, ax: false, model: true)
        #expect(model.needs == [.accessibility])
        #expect(model.status == .setup)
        #expect(model.stripeLabel == "One thing left")
        model.needs = HubNeed.needs(mic: false, ax: false, model: true)
        #expect(model.stripeLabel == "Two things left")
        model.recording = true
        #expect(model.status == .recording)
        #expect(model.stripeLabel == "Recording")
    }

    @Test("Return pastes a dictation and opens a meeting")
    func returnKey() {
        let model = model([TranscriptionEntry(text: "Morning all", timestamp: Self.at(8, 12))],
                          [Note(title: "Design sync", body: "**You:** Hi.", created: Self.at(11, 0), modified: Self.at(11, 32), source: .meeting)])
        var actions: [HubModel.Action] = []
        model.perform = { actions.append($0) }
        model.activateSelected()
        model.move(1)
        model.activateSelected()
        #expect(actions == [.open(model.rows[0]), .paste(model.rows[1])])
    }

    @Test("The panel takes typing without activating Utter")
    func panel() {
        let panel = HubPanel()
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(!panel.becomesKeyOnlyIfNeeded)
        #expect(!panel.hidesOnDeactivate)
    }

    @Test("The search field is a real text field the panel can make first responder")
    func searchFieldIsFocusable() {
        let host = NSHostingView(rootView: HubView(model: HubModel()))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: HubView.width, height: 520), styleMask: [.borderless],
                              backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let field = HubController.textField(in: host)
        #expect(field != nil)
        #expect(field.map { window.makeFirstResponder($0) } == true)
    }

    // MARK: Paste again

    private final class Log {
        var typed: [String] = []
        var copied: [String] = []
        var polls = 0
    }

    private func pasteBack(_ log: Log, trusted: Bool = true, hubKeyFor keyPolls: Int = 0,
                           focus: @escaping (Int) -> pid_t?) -> PasteBack {
        PasteBack(trusted: { trusted },
                  hubIsKey: { log.polls < keyPolls },
                  focusedPID: { log.polls += 1; return focus(log.polls) },
                  type: { log.typed.append($0) },
                  copy: { log.copied.append($0) },
                  pause: {})
    }

    @Test("Paste again types only once focus is back in the app the user was in")
    func pasteAfterFocusReturns() async {
        let log = Log()
        let outcome = await pasteBack(log) { $0 < 3 ? 1 : 42 }.run("Hello", into: 42)
        #expect(outcome == .typed)
        #expect(log.typed == ["Hello"])
        #expect(log.copied.isEmpty)
        #expect(log.polls == 3)
    }

    @Test("Paste again waits for the hub to give up key focus")
    func pasteWaitsForHub() async {
        let log = Log()
        var keyChecks = 0
        var back = pasteBack(log) { _ in 42 }
        back.hubIsKey = { keyChecks += 1; return keyChecks <= 2 }
        let outcome = await back.run("Hello", into: 42)
        #expect(outcome == .typed)
        #expect(keyChecks == 3)
        #expect(log.polls == 1)
    }

    @Test("Paste again copies instead when focus never comes back")
    func pasteCopiesWhenFocusIsElsewhere() async {
        let log = Log()
        let outcome = await pasteBack(log) { _ in 7 }.run("Hello", into: 42)
        #expect(outcome == .copied)
        #expect(log.typed.isEmpty)
        #expect(log.copied == ["Hello"])
        #expect(log.polls == 25)
    }

    @Test("Paste again copies without Accessibility or a known app, and never types")
    func pasteCopiesWithoutPermission() async {
        let log = Log()
        #expect(await pasteBack(log, trusted: false) { _ in 42 }.run("Hello", into: 42) == .copied)
        #expect(await pasteBack(log) { _ in 42 }.run("Hello", into: nil) == .copied)
        #expect(log.typed.isEmpty)
        #expect(log.polls == 0)
        #expect(log.copied == ["Hello", "Hello"])
    }
}

/// Renders the hub to `.build/screen-snapshots/hub-{ready,setup,rec}-{light,dark}.png` with the mock's sample day.
@Suite("Hub snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
@MainActor
struct ZZHubSnapshots {
    private static func at(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    private static func sample(_ state: String) -> HubModel {
        let dictations: [(Int, Int, String)] = [
            (21, 31, "Hi Sam, the slides look great. One small thing: can we swap slides four and five before Thursday?"),
            (21, 2, "Thanks everyone, great work today. Talk tomorrow."),
            (18, 20, "train times from Edinburgh to Glasgow Saturday morning"),
            (16, 48, "Can you pick up milk and something for dinner on the way home?"),
            (15, 12, "Shipped the fix for the login loop. Can someone double check it on the staging build?"),
            (13, 2, "Dear Ms Okafor, thank you for the quick reply. Tuesday works well for us, and I\u{2019}ll bring the revised plan."),
            (12, 15, "Lunch at the usual place? I can book for four."),
            (10, 5, "Running ten minutes late, save me a seat."),
            (8, 12, "Morning all. I\u{2019}m in at nine thirty, starting with the review."),
        ]
        let notes = [
            Note(body: "Book idea\nA story told only through voicemails.", created: at(19, 55), modified: at(19, 55), source: .dictated),
            Note(body: "Ideas for the review\nStart with what changed, then the numbers, then questions.", created: at(9, 20),
                 modified: at(9, 20), source: .dictated),
            Note(title: "Design sync", body: """
                **You:** Let\u{2019}s start with the pill. The new version is closer, but the colours still feel loud.
                **Others:** Agreed. Could we keep one colour per state and drop the rest?
                **You:** Yes. Listening, hands-free, thinking, typed and error. Nothing else.
                **Others:** And the error should stay small until someone looks at it.
                """, created: at(11, 0), modified: at(11, 32), source: .meeting),
        ]
        let model = HubModel()
        model.reload(entries: dictations.map { TranscriptionEntry(text: $2, timestamp: at($0, $1)) }, notes: notes, now: at(21, 41))
        model.targetApp = "Mail"
        if state == "setup" { model.needs = [.accessibility] }
        if state == "rec" { model.recording = true; model.handsFree = true }
        return model
    }

    @Test func states() throws {
        for state in ["ready", "setup", "rec"] {
            for dark in [false, true] {
                let host = NSHostingView(rootView: HubView(model: Self.sample(state)))
                host.frame = CGRect(origin: .zero, size: host.fittingSize)
                try SnapshotCanvas.write(host, "hub-\(state)", dark: dark, settle: 1.0)
            }
        }
    }
}
