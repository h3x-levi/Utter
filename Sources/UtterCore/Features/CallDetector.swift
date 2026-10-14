import AppKit
import AudioToolbox
import Foundation

/// Notices when you are in a call, by asking CoreAudio which *processes* are running audio input
/// and output right now. The decision itself is `CallPresence`; this is the plumbing that feeds it.
///
/// Deliberately thin. Everything that could be wrong in a way you would only find out by being
/// annoyed by it - how long to wait, what counts, what to ignore - is in `CallPresence`, where it is
/// a value type with tests. What is left here cannot be tested on this machine and is kept small
/// enough to read: list the process objects, ask each one whether it is running input or output,
/// exclude Utter's own pid, and hand two booleans to the decision.
///
/// **Per process, not per device, and that is the whole design.** The first version read
/// `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device and again on the
/// default output device. `AudioHardware.h` describes that property as "a UInt32 where 1 means that
/// the AudioDevice is running in at least one process on the system" - device-wide, with no
/// direction in it. On AirPods, on most USB and Bluetooth headsets, and on any aggregate device the
/// default input and the default output are the *same* `AudioObjectID`, so the two reads returned
/// the same number and "input and output are both open" collapsed into "this device is in use".
/// Playing a podcast on AirPods was therefore a call. `kAudioProcessPropertyIsRunningInput` and
/// `IsRunningOutput` are per process *and* per direction, so the two facts are independent, and
/// `kAudioProcessPropertyPID` lets Utter leave itself out of them structurally rather than by
/// remembering to.
///
/// **On permissions.** Everything here is a property read: no stream is opened, no sample buffer is
/// requested, and no capture API is called, so there is nothing for `AVCaptureDevice`
/// authorization - which gates *capture* - to be consulted about. What is **not** established is
/// the recording-indicator half of it: I could not find an authoritative statement that these reads
/// never light the orange dot, so treat that as unverified rather than as settled. If a future macOS
/// does put per-process audio activity behind a permission, the capability probe below is what
/// switches the feature off instead of leaving it quietly wrong.
@MainActor
package final class CallDetector {
    package init() {}

    /// Set by the owner whenever Utter itself is capturing. See `applyCallWatch`.
    ///
    /// This is no longer how the app avoids detecting its own microphone tap - the pid filter does
    /// that, for every stream Utter opens, without anything having to be wired up. It stays for the
    /// two jobs a pid cannot do:
    ///
    ///   * A running meeting capture takes the other participants' audio through
    ///     `ScreenCaptureKit`, which is not a HAL client of Utter's, so the pid filter says nothing
    ///     about it.
    ///   * It is what withdraws a live offer card the moment a capture starts by *any* route,
    ///     including the Record button on the Notes screen - `update` reports the change, so the
    ///     owner gets `onCallEnded` and takes the card down.
    package var selfIsCapturing: () -> Bool = { false }

    /// Called once each time a call starts. The offer to transcribe hangs off this.
    package var onCallStarted: (() -> Void)?

    /// Called once each time a call ends, so a pending offer can be withdrawn rather than left
    /// on screen for a meeting that is over.
    package var onCallEnded: (() -> Void)?

    private var presence = CallPresence()

    /// Which supported calling app the current call is coming from. Nil when there is no qualified
    /// call or the detector is not watching.
    ///
    /// Captured once, at the transition, and then left alone for the life of the call. A mute closes
    /// the meeting client's input stream on some clients, which would make the same call stop looking
    /// like the best candidate halfway through and rename the card under the user.
    package private(set) var currentCall: CallSource?

    /// The sampling clock.
    ///
    /// This is the only mechanism now, where it used to be a backstop behind property listeners on
    /// the two default devices. Those listeners went with the device-wide property they were
    /// watching: there is no notification for "some process opened an input stream" - the nearest
    /// thing, `kAudioHardwarePropertyProcessObjectList`, fires when a process object appears or
    /// disappears rather than when one starts or stops a direction. Nothing is lost by polling
    /// instead: the decision debounces for `CallPresence.confirmAfter` (5s) before it acts, so a 2s
    /// sample is already finer than the answer is.
    ///
    /// Removing them also removed a defect of their own. The old code registered per-device
    /// listeners in a `for input in [true, false]` loop, which on shared-device hardware - the same
    /// case that broke the signal - added two listeners for the same device and the same address,
    /// because each iteration built a fresh block. Both were removed symmetrically so nothing
    /// leaked, but every notification did the work twice.
    private var poll: Timer?

    /// Whether the detector is running at all - the feature is opt-in.
    package private(set) var isWatching = false

    /// Set once if this system will not answer the per-process queries, so the log says it once.
    private var loggedUnavailable = false

    package func start() {
        guard !isWatching else { return }
        isWatching = true
        // The block invalidates the timer itself when the detector is gone, rather than `deinit`
        // doing it. `Timer.invalidate()` has to be sent from the thread that scheduled the timer and
        // `deinit` runs wherever the last release happens; the capture is weak, so the runloop keeps
        // the timer alive after the detector is freed and this is the only place guaranteed to be on
        // the right thread. Academic in this app - the detector is an app-lifetime property of
        // `AppDelegate` - which is the reason to spend one line rather than a comment on it.
        poll = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in self.sample() }
        }
        sample()
    }

    package func stop() {
        guard isWatching else { return }
        isWatching = false
        poll?.invalidate()
        poll = nil
        presence.reset()
        currentCall = nil
        // `isSampling` is deliberately **not** cleared here.
        //
        // It was, on the reasoning that a restart should not be blocked by a walk still in flight  - 
        // but that defeated the guard it was meant to complement. The `isWatching` check inside the
        // hop is evaluated when the walk *lands*, and after a stop/start it is true again: so
        // clearing the flag let a pre-stop reading be fed to a freshly reset `CallPresence`, and let
        // the next tick launch a second concurrent walk that could land out of order - exactly the
        // "two walks landing out of order could confirm a call from the older of them" this exists to
        // prevent.
        //
        // It cannot wedge: the detached task clears it unconditionally on the main actor whenever
        // `self` is still alive, and if `self` is gone the flag is unreachable anyway.
    }

    /// The user declined the offer. Forget the current call without ending the watch, so the next
    /// call is still noticed - and, unlike a reset, the *same* call cannot ask again.
    package func dismissCurrentCall() {
        presence.decline()
        currentCall = nil
    }

    // MARK: - Sampling

    /// Take one sample: walk CoreAudio off the main thread, decide on it.
    ///
    /// The walk is the expensive half and it does not belong on the main thread. Measured on an
    /// M4 with 29 CoreAudio process objects, `audioInUseByOtherProcesses` is **4.70ms** and 87 HAL
    /// property reads - 56% of a 120Hz frame budget, every two seconds, which is a dropped frame
    /// on a schedule. It is `static` and reads no instance state, so nothing about it
    /// needs the main actor; only the decision that follows does, because `selfIsCapturing` is a
    /// closure owned by the main-actor owner and the callbacks drive UI.
    ///
    /// The interval stays at two seconds. Widening it was the other available saving and it is the
    /// wrong one now: off the main thread the cost is no longer on the critical path, while a
    /// coarser sample would add real latency to noticing a call - `CallPresence.confirmAfter`
    /// needs samples to *hold* for five seconds, so the sample period is the granularity of that
    /// answer.
    private func sample() {
        // Skip a tick rather than stack samples if the HAL is ever slow enough to overlap. The
        // decision is a state machine fed in order; two walks landing out of order could confirm a
        // call from the older of them.
        guard !isSampling else { return }
        isSampling = true
        Task.detached(priority: .utility) { [weak self] in
            let io = Self.audioInUseByOtherProcesses()
            // Unwrapped before the hop, not inside it: referencing the captured `weak var` from
            // the nested concurrently-executing closure is an error in the Swift 6 language mode.
            guard let self else { return }
            await MainActor.run {
                self.isSampling = false
                // `stop()` may have run while the walk was in flight; a sample that arrives after
                // the watch ended must not restart a presence machine that was just reset.
                guard self.isWatching else { return }
                self.decide(io)
            }
        }
    }

    /// Whether a sample's CoreAudio walk is in flight.
    private var isSampling = false

    /// The main-actor half of a sample: everything that reads owner state or drives UI.
    private func decide(_ io: CallSource??) {
        guard let io else {
            reportUnavailable()
            return
        }
        // `systemUptime` rather than a wall clock. `Date` moves when NTP or the user moves it, and
        // it accrues across sleep: `since` survives a sleep untouched (it is only reset when the
        // sample changes), so on wake `held` was hours and the confirm window - the debounce whose
        // whole purpose is to sit out a chime - was skipped outright. `systemUptime` is monotonic
        // and does not advance while the machine is asleep, which is exactly the interval that
        // should not count towards "held open for five seconds".
        let changed = presence.update(qualified: io != nil,
                                      selfIsCapturing: selfIsCapturing(),
                                      at: ProcessInfo.processInfo.systemUptime)
        guard changed else { return }
        if presence.isInCall {
            // Taken from the sample that confirmed the call, and then frozen - see `currentCall`.
            currentCall = io
            // The app's name is logged; nothing about what is being said is, and no capture has
            // started at this point.
            print("📞 Call detected\(io?.appName.map { " (\($0))" } ?? "")")
            onCallStarted?()
        } else {
            currentCall = nil
            print("📞 Call ended")
            onCallEnded?()
        }
    }

    /// This system cannot answer the query, so the feature does not run.
    ///
    /// The honest behaviour, and the reason there is no fallback to the device-wide property: that
    /// property cannot tell input from output on the hardware most people are on, so falling back to
    /// it would mean claiming a call from half the evidence - offering to record other people
    /// because a podcast is playing. The feature is opt-in and off by default, so not offering costs
    /// a user who switched it on nothing they had before.
    ///
    /// Stops the watch rather than polling a HAL that will not answer. `applyCallWatch` restarts the
    /// detector when the preference changes, so this probes again then and self-heals if the answer
    /// ever changes; the log stays once per launch.
    private func reportUnavailable() {
        if !loggedUnavailable {
            loggedUnavailable = true
            print("📞 Call detection unavailable: this system does not report per-process audio "
                  + "activity (needs kAudioHardwarePropertyProcessObjectList). Not offering to "
                  + "transcribe calls.")
        }
        stop()
    }

    // MARK: - CoreAudio

    /// The supported calling app that has both the microphone and the speakers open, if any,
    /// and which process looks most like the one holding the call. `nil` means the HAL declined the
    /// query, which is how this reports "not available here" - see `reportUnavailable`.
    ///
    /// The constants carry no `API_AVAILABLE` annotation (they are plain `CF_ENUM`), so they compile
    /// against any deployment target and the only way to know whether the HAL implements them is to
    /// ask. Hence a probe rather than an `#available` guess at a version floor: a non-`noErr` status
    /// or an empty list is "unavailable", and so is a list where nothing answers either direction.
    ///
    /// `source` is strictly a *name* for a call the two booleans already established, and it is
    /// allowed to be nil while they are both true - see `CallSource`. It costs one extra property
    /// read per process on a list that is being walked anyway.
    nonisolated static func audioInUseByOtherProcesses()
        -> CallSource?? {
        guard let processes = processObjects(), !processes.isEmpty else { return nil }

        let own = ProcessInfo.processInfo.processIdentifier
        // Keep every active process because Electron calling apps may split microphone and output
        // across helpers. `CallAudioEvidence` joins only helpers from the same supported app family.
        var activities: [CallProcessActivity] = []
        // Whether anything at all answered. A machine where the only process doing audio IO is
        // Utter itself is entirely ordinary - nothing playing, a dictation running - so "no other
        // process reported anything" must not be read as "this API does not work". The probe is
        // therefore whether the *properties* answer, taken across every process including our own,
        // while only other processes contribute to the two flags.
        var answered = false

        for process in processes {
            // Ours, or a process whose pid cannot be read at all: neither counts towards the flags.
            // An unattributable stream has to be treated as possibly ours, because mistaking Utter's
            // own microphone for someone else's is the failure that makes the app offer to
            // transcribe the recording it is already making.
            //
            // Utter is excluded from the *output* side too, not only the input side. The app plays
            // its own start and stop chimes, and counting those would pair Utter's output with some
            // other app's microphone - another dictation tool, a voice memo - and call it a meeting.
            // Nothing real is lost: on a call the remote side comes out of the meeting client.
            let pid = Self.pid(of: process)
            let somebodyElse = pid != nil && pid != own

            var runsInput = false
            var runsOutput = false
            if let running = isRunning(process, kAudioProcessPropertyIsRunningInput) {
                answered = true
                runsInput = running
            }
            if let running = isRunning(process, kAudioProcessPropertyIsRunningOutput) {
                answered = true
                runsOutput = running
            }

            // Only build a source for a process that could be the call, so the bundle ID of every
            // idle daemon on the machine is never read.
            guard somebodyElse, let pid, runsInput || runsOutput else { continue }
            let candidate = source(process: process, pid: pid)
            activities.append(
                CallProcessActivity(source: candidate, runsInput: runsInput, runsOutput: runsOutput)
            )
        }

        guard answered else { return nil }
        let chosen = CallAudioEvidence.candidate(from: activities)
        return .some(chosen)
    }

    /// Whether an app other than Utter is playing sound, for pausing music while dictating.
    nonisolated static func otherAppIsPlaying() -> Bool {
        let own = ProcessInfo.processInfo.processIdentifier
        return (processObjects() ?? []).contains {
            pid(of: $0).map { $0 != own } == true && isRunning($0, kAudioProcessPropertyIsRunningOutput) == true
        }
    }

    /// Whether `process` has any audio input or output running; false once it has gone.
    nonisolated static func isDoingAudio(_ process: AudioObjectID) -> Bool {
        isRunning(process, kAudioProcessPropertyIsRunningInput) == true
            || isRunning(process, kAudioProcessPropertyIsRunningOutput) == true
    }

    /// Whether the call is still on: its process is doing audio, or failing that any process of
    /// the same app, because Electron clients can move audio to another helper mid-call.
    nonisolated static func callIsAlive(_ call: CallSource) -> Bool {
        if isDoingAudio(call.processObject) { return true }
        guard let family = CallSource.knownName(bundleID: call.bundleID),
              let processes = processObjects() else { return false }
        return processes.contains {
            CallSource.knownName(bundleID: bundleID(of: $0)) == family && isDoingAudio($0)
        }
    }

    /// The mic the call app records from: its own process's, or another helper's of the same app,
    /// since Electron clients put input and output in different helpers.
    nonisolated static func microphone(of call: CallSource) -> AudioDeviceID? {
        if let device = AudioInputs.device(usedBy: call.processObject) { return device }
        guard let family = CallSource.knownName(bundleID: call.bundleID),
              let processes = processObjects() else { return nil }
        return processes.lazy
            .filter { CallSource.knownName(bundleID: bundleID(of: $0)) == family }
            .compactMap(AudioInputs.device(usedBy:))
            .first
    }

    /// Everything known about one candidate process.
    private nonisolated static func source(process: AudioObjectID, pid: pid_t) -> CallSource {
        let bundleID = Self.bundleID(of: process)
        // `NSRunningApplication` rather than a name table wherever it answers, so an app nobody
        // listed is still named correctly. It returns nil for the helper processes that do most of
        // the audio on this machine, which is what `CallSource.renamed` covers.
        let systemName = NSRunningApplication(processIdentifier: pid)?.localizedName
        return CallSource(processObject: process,
                          pid: pid,
                          bundleID: bundleID,
                          appName: CallSource.appName(bundleID: bundleID, systemName: systemName))
    }

    /// The system's process objects, or `nil` if it does not have any.
    private nonisolated static func processObjects() -> [AudioObjectID]? {
        let list = AudioInputs.objects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
        return list.isEmpty ? nil : list
    }

    private nonisolated static func isRunning(_ process: AudioObjectID,
                                              _ selector: AudioObjectPropertySelector) -> Bool? {
        AudioInputs.uint32(process, selector).map { $0 != 0 }
    }

    private nonisolated static func bundleID(of process: AudioObjectID) -> String? {
        AudioInputs.string(process, kAudioProcessPropertyBundleID)
    }

    private nonisolated static func pid(of process: AudioObjectID) -> pid_t? {
        AudioInputs.uint32(process, kAudioProcessPropertyPID).map { pid_t(bitPattern: $0) }
    }
}

struct CallProcessActivity: Equatable {
    let source: CallSource
    let runsInput: Bool
    let runsOutput: Bool
}

enum CallAudioEvidence {
    /// A call requires both directions to belong to one supported calling application.
    ///
    /// Native clients may hold both directions in one process; Electron clients may split them
    /// across helpers. Browsers and unknown apps never qualify because their audio cannot distinguish
    /// a meeting from ordinary playback.
    static func candidate(from activities: [CallProcessActivity]) -> CallSource? {
        let inputs = activities.filter(\.runsInput)
        let outputs = activities.filter(\.runsOutput)
        for input in inputs {
            guard let family = CallSource.knownName(bundleID: input.source.bundleID) else {
                continue
            }
            if let output = outputs.first(where: {
                CallSource.knownName(bundleID: $0.source.bundleID) == family
            }) {
                return output.source
            }
        }
        return nil
    }
}
