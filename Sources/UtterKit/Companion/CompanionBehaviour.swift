import AppKit
import UtterCore

/// One thing that happened, for the robot to answer with a moment from `companion-moments.json`.
struct CompanionCue: Equatable {
    let id: Int
    let event: String
    let detail: [String: RobotValue]

    static let idleOnly: Set = ["ambient", "near", "poke", "fling"]
    static let noReplay: Set = ["listening", "thinking"]
    static let hold: Set = ["listening", "talking", "quiet"]

    /// Idle-only cues wait for a free robot; a listening or thinking cue counts only when its state just began.
    func mayRoute(state: RobotState, stateChanged: Bool, momentPlaying: Bool) -> Bool {
        if Self.idleOnly.contains(event) { return !momentPlaying && !state.persists }
        return !Self.noReplay.contains(event) || stateChanged
    }
}

/// What the floating robot shows: capture state, reminders, goals and quiet mode, as values.
/// `CompanionWindow` plays `robotState` on the robot, answers `cue` with a moment and draws `notice` in the bubble.
@MainActor
final class CompanionBehaviour: ObservableObject {
    static let loudLevel: Float = 0.08
    static let softLevel: Float = 0.02
    static let talkingMs = 4000.0
    static let quietMs = 2000.0

    @Published private(set) var cue: CompanionCue?
    @Published private(set) var robotState: RobotState = .idle
    @Published private(set) var isQuiet = false
    @Published private(set) var quip: CompanionNotice?
    @Published private(set) var currentReminder: CompanionReminder?
    @Published private(set) var pomodoroCountdown: String?
    @Published var pinnedMessage = ""

    private var turnReachedProcessing = false
    private var quipGeneration = 0
    private var turn: [String: RobotValue] = [:]
    private var heard: Set<String> = []
    private var loudMs = 0.0
    private var softSince: Double?
    private var lastSampleAt: Double?

    var notice: CompanionNotice? {
        let pinned = pinnedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = pinned.isEmpty ? nil : pinned
        if let quip { return CompanionNotice(kind: quip.kind, line: quip.line, detail: detail) }
        if let pomodoroCountdown { return CompanionNotice(kind: .timer, line: pomodoroCountdown, detail: detail) }
        return detail.map { CompanionNotice(kind: .pinned, line: $0) }
    }

    func apply(pillState: PillState) {
        guard !isQuiet else { return }
        switch pillState {
        case .recording, .handsFree, .capturingNote, .capturingMemory:
            turnReachedProcessing = false
            turn = [:]
            heard = []
            loudMs = 0
            softSince = nil
            lastSampleAt = nil
            signal("listening", Self.listening(pillState))
            show(.input)
        case .preparing:
            show(.waiting)
        case .processing:
            turnReachedProcessing = true
            signal("thinking")
            show(.waiting)
        case .error(let reason):
            turnReachedProcessing = false
            endTurn("error")
            show(.failure)
            say(CompanionNotice(kind: .failure, line: reason), for: 5)
        case .island:
            turnReachedProcessing = false
            endTurn("island")
            if robotState.persists { show(.idle) }
        case .idle:
            if turnReachedProcessing {
                endTurn("done")
                show(.success)
            } else if robotState.persists {
                show(.idle)
            }
            turnReachedProcessing = false
        case .notice:
            guard turnReachedProcessing else { break }
            turnReachedProcessing = false
            endTurn("notice")
            show(.success)
        }
    }

    func signal(_ event: String, _ detail: [String: RobotValue] = [:]) {
        cue = CompanionCue(id: (cue?.id ?? 0) + 1, event: event, detail: detail)
    }

    /// Facts the turn's closing cue carries: words delivered, a memory saved, a goal reached.
    func note(_ detail: [String: RobotValue]) {
        turn.merge(detail) { _, new in new }
    }

    /// While listening: `talking` after four loud seconds, `quiet` after two soft ones, each once per turn.
    func hear(_ level: Float, at ms: Double) {
        guard robotState == .input else { return }
        let dt = lastSampleAt.map { min(ms - $0, 100) } ?? 0
        lastSampleAt = ms
        if level > Self.loudLevel {
            loudMs += dt
            softSince = nil
        } else if level > Self.softLevel {
            softSince = softSince ?? ms
        } else {
            softSince = nil
        }
        if loudMs >= Self.talkingMs, heard.insert("talking").inserted { signal("talking") }
        if let softSince, ms - softSince >= Self.quietMs, heard.insert("quiet").inserted { signal("quiet") }
    }

    func announce(_ reminder: CompanionReminder, name: String) {
        guard !isQuiet else { return }
        currentReminder = reminder
        switch reminder {
        case .stretch: signal("reminder", ["kind": .string("stretch")])
        case .water: signal("reminder", ["kind": .string("water")])
        case .pomodoro(let focus): signal("reminder", ["kind": .string("pomodoro"), "focus": .bool(focus)])
        case .message: break
        }
        show(.send)
        say(CompanionNotice(kind: .reminder, line: reminder.line(name: name)), for: 8)
    }

    /// `kind` "dictation" rides on the turn's closing cue; a reminder goal's kind cues `goal` at once.
    func celebrateGoal(_ line: String, kind: String) {
        guard !isQuiet else { return }
        if kind == "dictation" {
            note(["goal": .string(kind)])
        } else {
            signal("goal", ["kind": .string(kind)])
        }
        show(.love)
        say(CompanionNotice(kind: .reminder, line: line), for: 5)
    }

    func respondToCurrentReminder(completed: Bool) -> CompanionReminder? {
        guard let reminder = currentReminder else { return nil }
        currentReminder = nil
        quip = nil
        if completed { show(.success) }
        return reminder
    }

    func setQuietMode(_ on: Bool) {
        guard on != isQuiet else { return }
        isQuiet = on
        robotState = on ? .sleep : .wake
        turnReachedProcessing = false
        guard on else { return }
        currentReminder = nil
        quip = nil
    }

    func setPomodoroCountdown(_ remaining: TimeInterval?) {
        guard let remaining, remaining > 0 else {
            if pomodoroCountdown != nil { pomodoroCountdown = nil }
            return
        }
        let whole = Int(remaining.rounded())
        let text = String(format: "%d:%02d", whole / 60, whole % 60)
        if pomodoroCountdown != text { pomodoroCountdown = text }
    }

    private static func listening(_ state: PillState) -> [String: RobotValue] {
        switch state {
        case .recording: return ["mode": .string("recording"), "destination": .string("app")]
        case .handsFree: return ["mode": .string("handsFree"), "destination": .string("app")]
        case .capturingNote: return ["destination": .string("note")]
        default: return ["destination": .string("memory")]
        }
    }

    private func endTurn(_ event: String) {
        signal(event, turn)
        turn = [:]
    }

    /// Persistent states are not replayed when unchanged; one-shots always replay.
    private func show(_ state: RobotState) {
        guard !isQuiet, !(state == robotState && (state.persists || state == .idle)) else { return }
        robotState = state
    }

    private func say(_ notice: CompanionNotice, for seconds: TimeInterval) {
        quip = notice
        quipGeneration += 1
        let generation = quipGeneration
        if let app = NSApp {
            NSAccessibility.post(element: app, notification: .announcementRequested,
                                 userInfo: [.announcement: notice.accessibilityLabel,
                                            .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.quipGeneration == generation else { return }
            self.quip = nil
        }
    }
}
