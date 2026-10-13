import AppKit
import UtterCore

/// What the floating robot shows: capture state, reminders, goals and quiet mode, as values.
/// `CompanionWindow` plays `robotState` on the robot and draws `notice` in the bubble.
@MainActor
final class CompanionBehaviour: ObservableObject {
    @Published private(set) var robotState: RobotState = .idle
    @Published private(set) var isQuiet = false
    @Published private(set) var quip: CompanionNotice?
    @Published private(set) var currentReminder: CompanionReminder?
    @Published private(set) var pomodoroCountdown: String?
    @Published var pinnedMessage = ""

    private var turnReachedProcessing = false
    private var quipGeneration = 0

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
            show(.input)
        case .preparing:
            show(.waiting)
        case .processing:
            turnReachedProcessing = true
            show(.waiting)
        case .error(let reason):
            turnReachedProcessing = false
            show(.failure)
            say(CompanionNotice(kind: .failure, line: reason), for: 5)
        case .island:
            turnReachedProcessing = false
            if robotState.persists { show(.idle) }
        case .idle:
            if turnReachedProcessing {
                show(.success)
            } else if robotState.persists {
                show(.idle)
            }
            turnReachedProcessing = false
        case .notice:
            break
        }
    }

    func announce(_ reminder: CompanionReminder, name: String) {
        guard !isQuiet else { return }
        currentReminder = reminder
        show(.send)
        say(CompanionNotice(kind: .reminder, line: reminder.line(name: name)), for: 8)
    }

    func celebrateGoal(_ line: String) {
        guard !isQuiet else { return }
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
