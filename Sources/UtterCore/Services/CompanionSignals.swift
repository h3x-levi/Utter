import Foundation

/// What the robot is reminding you about.
package enum CompanionReminder: Equatable {
    case stretch
    case water
    /// A pomodoro interval ended. `focus` is true when it was a work block, so the message
    /// can say which way round it is.
    case pomodoro(focus: Bool)
    /// A time the user set, with their own words.
    case message(String)

    package func line(name: String) -> String {
        let you = name.isEmpty ? "" : ", \(name)"
        switch self {
        case .stretch: return "Stretch time\(you)"
        case .water: return "Water break\(you)"
        case .pomodoro(let focus): return focus ? "Break time\(you)" : "Back to focus\(you)"
        case .message(let text): return text
        }
    }

    var memoryKey: String {
        switch self {
        case .stretch: return "stretch"
        case .water: return "water"
        case .pomodoro(let focus): return focus ? "focus" : "break"
        case .message: return "message"
        }
    }
}

/// Decides when the robot should speak up, against the wall clock: every reminder is for a user who has gone still.
package struct ReminderScheduler: Equatable {
    package init() {}

    /// Minutes between stretch reminders, or nil for off.
    package var stretchEvery: TimeInterval?
    /// Minutes between water reminders, or nil for off.
    package var waterEvery: TimeInterval?

    /// Pomodoro block lengths. Nil for off.
    package var pomodoroFocus: TimeInterval?
    package var pomodoroBreak: TimeInterval?

    /// A one-off message and when to say it.
    var messageAt: Date?
    var messageText: String = ""

    private var lastStretch: Date?
    private var lastWater: Date?
    private var pomodoroStartedAt: Date?
    private var pomodoroInFocus = true
    private var messageDelivered = false

    /// Start the clocks. Called when the companion appears, so an interval is measured from
    /// when the robot came on screen rather than from the epoch.
    package mutating func begin(at now: Date) {
        lastStretch = now
        lastWater = now
        if pomodoroStartedAt == nil { pomodoroStartedAt = now }
    }

    /// The reminder due now, if any. At most one per call, so two coinciding reminders are
    /// spoken one after the other rather than overwriting each other in the same bubble.
    ///
    /// Order is by how time-critical each is: a pomodoro block boundary is a specific
    /// moment, a one-off message is a specific moment, and the recurring health nudges can
    /// wait a second.
    package mutating func due(at now: Date) -> CompanionReminder? {
        if let focus = pomodoroFocus, let rest = pomodoroBreak, let started = pomodoroStartedAt {
            let length = pomodoroInFocus ? focus : rest
            if now.timeIntervalSince(started) >= length {
                let finished = pomodoroInFocus
                pomodoroInFocus.toggle()
                pomodoroStartedAt = now
                return .pomodoro(focus: finished)
            }
        }

        if let at = messageAt, !messageDelivered, now >= at, !messageText.isEmpty {
            messageDelivered = true
            return .message(messageText)
        }

        if let every = stretchEvery, let last = lastStretch,
           now.timeIntervalSince(last) >= every {
            lastStretch = now
            return .stretch
        }

        if let every = waterEvery, let last = lastWater, now.timeIntervalSince(last) >= every {
            lastWater = now
            return .water
        }

        return nil
    }

    /// How far through the current pomodoro block, 0...1, and whether it is a focus block.
    /// Nil when pomodoro is off - the timer should not be drawn at all rather than drawn empty.
    func pomodoroProgress(at now: Date) -> (fraction: Double, focus: Bool)? {
        guard let focus = pomodoroFocus, let rest = pomodoroBreak,
              let started = pomodoroStartedAt
        else { return nil }
        let length = pomodoroInFocus ? focus : rest
        guard length > 0 else { return nil }
        let done = now.timeIntervalSince(started) / length
        return (min(1, max(0, done)), pomodoroInFocus)
    }

    /// Seconds left in the current block, for the numeric readout.
    package func pomodoroRemaining(at now: Date) -> TimeInterval? {
        guard let focus = pomodoroFocus, let rest = pomodoroBreak,
              let started = pomodoroStartedAt
        else { return nil }
        let length = pomodoroInFocus ? focus : rest
        return max(0, length - now.timeIntervalSince(started))
    }
}
