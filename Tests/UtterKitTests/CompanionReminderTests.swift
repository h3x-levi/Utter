import Foundation
import Testing

@testable import UtterKit
@testable import UtterCore

/// The reminder clocks.
///
/// Driven by passing `Date`s in rather than by waiting, so a 45-minute interval is verified
/// instantly. That is also the point of the design: these run on the **wall clock**, not on
/// the behaviour engine's own clock, because the engine's ticker stops after 90 seconds of
/// rest and every reminder here exists for a user who has gone still.
/// `.serialized` because this suite flakes under the test runner's parallel execution, and the
/// flake is in the runner rather than in what is being tested. Measured, before reaching for the
/// trait:
///
///   * **The value is bit-exact.** 20,000 fresh schedulers, same inputs, produced one distinct
///     `pomodoroRemaining` bit pattern, equal to `TimeInterval(24 * 60)`. There is nothing for a
///     race to perturb: `ReminderScheduler` is a struct over constants, with no global or static
///     state, and every input here is a literal.
///   * **`swift test --sanitize=thread` reports no data race** - and the test still fails under it.
///   * **It is parallelism, not timing.** 12 failures in 25 runs at the default parallelism;
///     **0 in 25** with `--no-parallel`.
///   * The reported failure never moves: always `countdown`, always the same line, always
///     `(remaining -> 1440.0) == (24 * 60 -> 1440)` - two values that print equal and compare
///     unequal, which is not a shape any arithmetic here can produce.
///
/// So the fault is in `swift-testing` 0.99.0's parallel expectation handling on this toolchain
/// (Swift 6.3.3). That version is pinned on purpose - see the note in `Package.swift`: the
/// Command Line Tools ship neither `XCTest` nor a built-in `Testing` module, so it has to come
/// from the package, and the pin exists because an open range silently moved 0.10.0 -> 0.99.0
/// once already. **When that dependency is dropped for the toolchain's own `Testing` (which
/// needs full Xcode), remove this trait and re-run the 25x check above** - if the flake is gone,
/// this was never ours.
///
/// Serialising costs ~0.008s across 11 tests. Leaving it would cost more than that: a suite that
/// fails half the time makes every "all tests pass" claim about this repo worth less, which is
/// exactly how a real regression gets waved through.
@Suite("Companion reminders", .serialized)
struct CompanionReminderTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func scheduler(stretch: Int? = nil, water: Int? = nil,
                           focus: Int? = nil, rest: Int? = nil) -> ReminderScheduler {
        var scheduler = ReminderScheduler()
        scheduler.stretchEvery = stretch.map { TimeInterval($0) * 60 }
        scheduler.waterEvery = water.map { TimeInterval($0) * 60 }
        scheduler.pomodoroFocus = focus.map { TimeInterval($0) * 60 }
        scheduler.pomodoroBreak = rest.map { TimeInterval($0) * 60 }
        scheduler.begin(at: start)
        return scheduler
    }

    // MARK: Intervals

    @Test("Nothing is due before the interval has passed")
    func nothingEarly() {
        var scheduler = self.scheduler(stretch: 45)
        #expect(scheduler.due(at: start.addingTimeInterval(44 * 60)) == nil)
    }

    @Test("A stretch reminder comes due, then not again until the next interval")
    func stretchRepeats() {
        var scheduler = self.scheduler(stretch: 45)
        #expect(scheduler.due(at: start.addingTimeInterval(45 * 60)) == .stretch)
        // Immediately after, nothing - the interval restarts from when it fired, so a
        // reminder cannot fire twice for the same interval.
        #expect(scheduler.due(at: start.addingTimeInterval(45 * 60 + 1)) == nil)
        #expect(scheduler.due(at: start.addingTimeInterval(90 * 60)) == .stretch)
    }

    @Test("An interval of zero minutes means off")
    func zeroIsOff() {
        var scheduler = ReminderScheduler()
        scheduler.begin(at: start)
        // Nothing configured at all.
        #expect(scheduler.due(at: start.addingTimeInterval(10 * 60 * 60)) == nil)
    }

    @Test("Two reminders due at once are delivered one at a time")
    func oneAtATime() {
        var scheduler = self.scheduler(stretch: 30, water: 30)
        let later = start.addingTimeInterval(30 * 60)
        let first = scheduler.due(at: later)
        let second = scheduler.due(at: later)
        #expect(first != nil)
        #expect(second != nil)
        #expect(first != second, "both reminders fired as the same one")
        // And now they are both spent.
        #expect(scheduler.due(at: later) == nil)
    }

    // MARK: Pomodoro

    @Test("A pomodoro alternates focus and break")
    func pomodoroAlternates() {
        var scheduler = self.scheduler(focus: 25, rest: 5)

        // End of the first focus block: it reports the block that *finished*.
        #expect(scheduler.due(at: start.addingTimeInterval(25 * 60)) == .pomodoro(focus: true))
        // Five minutes later the break ends.
        #expect(scheduler.due(at: start.addingTimeInterval(30 * 60)) == .pomodoro(focus: false))
        // Then another focus block.
        #expect(scheduler.due(at: start.addingTimeInterval(55 * 60)) == .pomodoro(focus: true))
    }

    @Test("The countdown counts down, and is nil when the timer is off")
    func countdown() {
        var scheduler = self.scheduler(focus: 25, rest: 5)
        let remaining = scheduler.pomodoroRemaining(at: start.addingTimeInterval(60))
        #expect(remaining == 24 * 60)

        let progress = scheduler.pomodoroProgress(at: start.addingTimeInterval(60))
        #expect(progress?.focus == true)
        #expect((progress?.fraction ?? 0) > 0)

        var off = self.scheduler(stretch: 45)
        #expect(off.pomodoroRemaining(at: start) == nil)
        #expect(off.pomodoroProgress(at: start) == nil)
        _ = off.due(at: start)
    }

    @Test("The countdown never runs past the end of its block")
    func countdownClamps() {
        let scheduler = self.scheduler(focus: 25, rest: 5)
        // Long past the block, with nothing having drained `due` to roll it over.
        #expect(scheduler.pomodoroRemaining(at: start.addingTimeInterval(60 * 60)) == 0)
        #expect(scheduler.pomodoroProgress(at: start.addingTimeInterval(60 * 60))?.fraction == 1)
    }

    // MARK: A one-off message

    @Test("A timed message fires once, at its time, and never again")
    func messageFiresOnce() {
        var scheduler = ReminderScheduler()
        scheduler.begin(at: start)
        scheduler.messageAt = start.addingTimeInterval(600)
        scheduler.messageText = "call the vet"

        #expect(scheduler.due(at: start.addingTimeInterval(599)) == nil)
        #expect(scheduler.due(at: start.addingTimeInterval(600)) == .message("call the vet"))
        #expect(scheduler.due(at: start.addingTimeInterval(601)) == nil)
        #expect(scheduler.due(at: start.addingTimeInterval(6000)) == nil)
    }

    @Test("A message with no text never fires")
    func emptyMessageIsIgnored() {
        var scheduler = ReminderScheduler()
        scheduler.begin(at: start)
        scheduler.messageAt = start
        scheduler.messageText = ""
        #expect(scheduler.due(at: start.addingTimeInterval(60)) == nil)
    }

    @Test("A message whose time already passed still fires, rather than being skipped")
    func lateMessageStillFires() {
        // The companion may not have been running at the moment the message was due. A
        // reminder that silently evaporates because the app was closed is worse than one
        // that arrives late.
        var scheduler = ReminderScheduler()
        scheduler.begin(at: start)
        scheduler.messageAt = start.addingTimeInterval(-3600)
        scheduler.messageText = "stand up"
        #expect(scheduler.due(at: start) == .message("stand up"))
    }

    // MARK: The words

    @Test("Reminders use the user's name when there is one")
    func linesUseName() {
        #expect(CompanionReminder.stretch.line(name: "Sam").contains("Sam"))
        #expect(CompanionReminder.stretch.line(name: "") == "Stretch time")
        // A pomodoro says which way round it is, or the message is meaningless.
        #expect(CompanionReminder.pomodoro(focus: true).line(name: "")
                != CompanionReminder.pomodoro(focus: false).line(name: ""))
        // A user's own message is passed through untouched - no name appended, because
        // they wrote the whole sentence.
        #expect(CompanionReminder.message("feed me").line(name: "Sam") == "feed me")
    }
}
