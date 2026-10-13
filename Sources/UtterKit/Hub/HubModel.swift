import AppKit
import ApplicationServices
import UtterCore

/// One dictation, note or meeting on the hub's tape.
struct HubTrack: Identifiable, Equatable {
    enum Kind { case dictation, note, meeting }

    let id: UUID
    let kind: Kind
    let date: Date
    let title: String
    let text: String
    let words: Int
    let seconds: Int
    /// Place in its own day, oldest first.
    var number = 0

    init(_ entry: TranscriptionEntry) {
        id = entry.id
        kind = .dictation
        date = entry.timestamp
        title = entry.text
        text = entry.text
        words = entry.wordCount
        seconds = Self.seconds(entry.duration, words: entry.wordCount)
    }

    init(_ note: Note) {
        let meeting = note.source == .meeting
        id = note.id
        kind = meeting ? .meeting : .note
        date = meeting ? note.created : note.modified
        title = note.displayTitle
        text = note.body
        words = note.wordCount
        seconds = Self.seconds(meeting ? note.modified.timeIntervalSince(note.created) : 0, words: words)
    }

    /// Recorded seconds, or the mock's 144 words a minute when nothing was recorded.
    static func seconds(_ duration: TimeInterval, words: Int) -> Int {
        duration > 0 ? max(1, Int(duration.rounded())) : max(3, Int((Double(words) / 2.4).rounded()))
    }

    var time: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    /// Every track, newest first, numbered within its day.
    static func tape(_ entries: [TranscriptionEntry], _ notes: [Note], calendar: Calendar = .current) -> [HubTrack] {
        var tracks = (entries.map(HubTrack.init) + notes.filter { $0.wordCount > 0 }.map(HubTrack.init))
            .sorted { $0.date < $1.date }
        var day: Date?
        var number = 0
        for index in tracks.indices {
            let start = calendar.startOfDay(for: tracks[index].date)
            number = start == day ? number + 1 : 1
            day = start
            tracks[index].number = number
        }
        return tracks.reversed()
    }

    static func search(_ tracks: [HubTrack], for query: String) -> [HubTrack] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return tracks.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.text.localizedCaseInsensitiveContains(query) }
    }

    static func talkTime(_ tracks: [HubTrack]) -> String {
        let seconds = tracks.reduce(0) { $0 + $1.seconds }
        return "\(seconds / 60) min \(seconds % 60) s"
    }
}

/// A permission or download the app still needs, read from `ReadinessMonitor`.
enum HubNeed: Equatable {
    case microphone, accessibility, model

    static func needs(mic: Bool, ax: Bool, model: Bool) -> [HubNeed] {
        (mic ? [] : [.microphone]) + (ax ? [] : [.accessibility]) + (model ? [] : [.model])
    }

    static func title(_ count: Int) -> String {
        let number = ["One", "Two", "Three"][min(max(count, 1), 3) - 1]
        return "\(number) thing\(count == 1 ? "" : "s") left"
    }

    var message: String {
        switch self {
        case .microphone: "Allow the microphone so Utter can hear you."
        case .accessibility: "Allow Accessibility so Utter can type into other apps."
        case .model: "Get a speech model so Utter can understand you."
        }
    }

    var button: String { self == .model ? "Set up" : "Allow" }
}

@MainActor @Observable
final class HubModel {
    enum Action: Equatable {
        case handsFree, newNote, recordMeeting, openLibrary, settings, whatsNew, reportIssue, quit
        case open(HubTrack), paste(HubTrack), grant(HubNeed)
    }

    var query = "" { didSet { selection = 0 } }
    var selection = 0
    var needs: [HubNeed] = []
    var recording = false
    var handsFree = false
    var hotkey = "Fn"
    var goal: Int? = 500
    /// Words dictated today with no track behind them (Keep history is off).
    var unkeptWords = 0
    var dictationWordsToday: Int { today.filter { $0.kind == .dictation }.reduce(0) { $0 + $1.words } }
    /// The app Return pastes into; empty when it can't be named.
    var targetApp = ""
    /// Shown where the setup line goes, e.g. why a meeting couldn't start.
    var message: String?
    private(set) var tracks: [HubTrack] = []
    private(set) var today: [HubTrack] = []
    private(set) var pasted: Set<UUID> = []
    private(set) var copiedID: UUID?
    /// The newest track, when it arrived while the hub was away or open; it writes itself in.
    private(set) var fresh: UUID?
    /// Bumped on every open so the rows redraw their pen marks.
    private(set) var openCount = 0
    private var sideB = true
    @ObservationIgnored var perform: (Action) -> Void = { _ in }

    var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var rows: [HubTrack] { searching ? HubTrack.search(tracks, for: query) : Array(today.prefix(8)) }
    var selected: HubTrack? { rows.indices.contains(selection) ? rows[selection] : nil }
    var heading: String { searching ? "Found" : "Today, side \(sideB ? "B" : "A")" }
    var detail: String {
        searching ? Self.count(rows.count) : "\(Self.count(today.count)) · \(HubTrack.talkTime(today))"
    }
    var segments: [TapeSegment<UUID>] {
        today.reversed().map { TapeSegment(id: $0.id, words: $0.words, label: $0.title) } + TapeSegment.unkept(unkeptWords, id: Self.unkeptID)
    }
    private static let unkeptID = UUID()
    var status: TapeStripe<UUID>.Status { recording ? .recording : needs.isEmpty ? .ready : .setup }

    var stripeLabel: String {
        switch status {
        case .recording: "Recording"
        case .setup: HubNeed.title(needs.count)
        case .ready: "Ready \u{00B7} hold \(hotkey)"
        }
    }

    static func count(_ n: Int) -> String { "\(n) track\(n == 1 ? "" : "s")" }

    func reload(entries: [TranscriptionEntry], notes: [Note], now: Date = .now, calendar: Calendar = .current) {
        let newest = tracks.first?.id
        tracks = HubTrack.tape(entries, notes, calendar: calendar)
        today = tracks.filter { calendar.isDate($0.date, inSameDayAs: now) }
        sideB = calendar.component(.hour, from: now) >= 12
        if newest != nil, let top = today.first, top.id != newest { fresh = top.id }
        selection = min(selection, max(rows.count - 1, 0))
    }

    func opened(entries: [TranscriptionEntry], notes: [Note], lastSeen: Date?, now: Date = .now) {
        query = ""
        message = nil
        openCount += 1
        reload(entries: entries, notes: notes, now: now)
        fresh = nil
        if let lastSeen, let top = today.first, top.date > lastSeen { fresh = top.id }
    }

    func move(_ step: Int) {
        guard !rows.isEmpty else { return }
        selection = min(max(selection + step, 0), rows.count - 1)
    }

    func activateSelected() {
        guard let track = selected else { return }
        perform(track.kind == .meeting ? .open(track) : .paste(track))
    }

    func copySelected() {
        if let selected { copy(selected) }
    }

    func copy(_ track: HubTrack) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(track.text, forType: .string)
        copiedID = track.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            if self?.copiedID == track.id { self?.copiedID = nil }
        }
    }

    func markPasted(_ id: UUID) { pasted.insert(id) }
}

/// Paste again: wait until focus is back in the app the user was in, then type. Copies instead when that can't be confirmed.
@MainActor
struct PasteBack {
    enum Outcome: Equatable { case typed, copied }

    var trusted: () -> Bool = { AXIsProcessTrusted() }
    var hubIsKey: () -> Bool
    var focusedPID: () async -> pid_t? = {
        await AXReader.read {
            var pid: pid_t = 0
            guard let focused = AXReader.focusedElement(), AXUIElementGetPid(focused, &pid) == .success else { return nil }
            return pid
        }
    }
    var type: (String) -> Void = { TextInjector.typeText($0) }
    var copy: (String) -> Void = { text in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    var pause: () async -> Void = { try? await Task.sleep(for: .milliseconds(20)) }
    var attempts = 25

    func run(_ text: String, into pid: pid_t?) async -> Outcome {
        if trusted(), let pid {
            for _ in 0..<attempts {
                await pause()
                if !hubIsKey(), await focusedPID() == pid {
                    type(text)
                    return .typed
                }
            }
        }
        copy(text)
        return .copied
    }
}
