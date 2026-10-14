import AppKit
import ApplicationServices
import UtterCore

/// One track on the hub's tape: a Library item plus its number within its day.
struct HubTrack: Identifiable, Equatable {
    let item: LibraryItem
    /// Place in its own day, oldest first.
    var number = 0

    init(_ item: LibraryItem) { self.item = item }

    var id: UUID { item.uuid }
    var kind: LibraryItem.Kind { item.kind }
    var date: Date { item.date }
    var title: String { item.title }
    var text: String { item.body }
    var words: Int { item.words }
    var seconds: Int { max(1, Int(item.talkTime.rounded())) }

    var time: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    /// Every track, newest first, numbered within its day.
    static func tape(_ entries: [TranscriptionEntry], _ notes: [Note], calendar: Calendar = .current) -> [HubTrack] {
        var tracks = (entries.map(LibraryItem.init) + notes.filter { $0.wordCount > 0 }.map(LibraryItem.init))
            .map(HubTrack.init)
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

@MainActor @Observable
final class HubModel {
    enum Action: Equatable {
        case handsFree, newNote, recordMeeting, openLibrary, settings, whatsNew, reportIssue, quit
        case open(HubTrack), paste(HubTrack), grant(SetupNeeds.Need)
    }

    var query = "" { didSet { selection = 0 } }
    var selection = 0
    var needs: [SetupNeeds.Need] = []
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
    var segments: [TapeSegment<String>] { TapeSegment.today(today.reversed().map(\.item), unkept: unkeptWords) }
    var status: TapeStripe<String>.Status { recording ? .recording : needs.isEmpty ? .ready : .setup }

    var stripeLabel: String {
        switch status {
        case .recording: "Recording"
        case .setup: SetupNeeds.cardTitle(needs.count)
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
