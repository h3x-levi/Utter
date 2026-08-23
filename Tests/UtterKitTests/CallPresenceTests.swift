import Testing
import Foundation
@testable import UtterKit

/// The rule that decides whether Utter interrupts you to offer a transcript.
///
/// Worth testing rather than eyeballing, because both kinds of mistake are expensive and neither
/// shows up in a quick manual try: firing on a notification chime makes the app a nuisance, and
/// releasing on a mute tears down a capture in the middle of a meeting.
///
/// **What the inputs mean, and why that changed.** A sample is "some process that is not Utter is
/// running audio input" and "some process that is not Utter is running audio output", read
/// per-process and per-direction (`CallDetector.audioInUseByOtherProcesses`). It used to be one
/// device-wide property read twice, which on AirPods and most headsets is the *same* device object
/// both times — so `(false, true)` and `(true, false)` were combinations the shim could not
/// physically produce, and this suite was proving the state machine against samples that never
/// arrived while saying nothing about the signal. Every combination below is now reachable, and each
/// test says which real situation produces it.
@Suite("Call presence")
struct CallPresenceTests {

    /// Drive a sequence of samples one second apart, returning the state at the end.
    ///
    /// `from` is a plain counter standing in for `ProcessInfo.systemUptime`, which is what the
    /// detector feeds: monotonic, and it does not advance while the machine is asleep.
    private func run(_ samples: [(input: Bool, output: Bool)],
                     selfIsCapturing: Bool = false,
                     from start: TimeInterval = 1_000) -> CallPresence {
        var presence = CallPresence()
        for (i, sample) in samples.enumerated() {
            presence.update(inputByOthers: sample.input,
                            outputByOthers: sample.output,
                            selfIsCapturing: selfIsCapturing,
                            at: start + TimeInterval(i))
        }
        return presence
    }

    private func both(_ seconds: Int) -> [(input: Bool, output: Bool)] {
        Array(repeating: (input: true, output: true), count: seconds)
    }

    /// Hold a confirmed call: samples one second apart from `start`, long enough to qualify.
    ///
    /// Leaves the clock at `afterConfirm(start)`, which the tests carry on from.
    private func confirmedCall(from start: TimeInterval = 1_000) -> CallPresence {
        var presence = CallPresence()
        var t = start
        for _ in 0..<Int(CallPresence.confirmAfter + 2) {
            presence.update(inputByOthers: true, outputByOthers: true,
                            selfIsCapturing: false, at: t)
            t += 1
        }
        #expect(presence.isInCall, "the fixture did not reach a call")
        return presence
    }

    /// The clock `confirmedCall(from:)` leaves off at.
    private func afterConfirm(_ start: TimeInterval = 1_000) -> TimeInterval {
        start + CallPresence.confirmAfter + 2
    }

    @Test("Both directions open, held long enough, is a call")
    func sustainedTwoWayAudioIsACall() {
        #expect(run(both(Int(CallPresence.confirmAfter) + 2)).isInCall)
    }

    @Test("A brief overlap is not a call")
    func briefOverlapIsIgnored() {
        // A chime while dictating, or "Hey Siri" over a video. This is the false positive that
        // would make the feature obnoxious.
        #expect(!run(both(Int(CallPresence.confirmAfter) - 1)).isInCall)
    }

    @Test("The microphone alone is not a call")
    func microphoneAloneIsNotACall() {
        // Another dictation tool, a voice memo, Photo Booth: one process holding an input stream
        // with nothing playing back. Nothing is coming back at you.
        let samples = Array(repeating: (input: true, output: false), count: 60)
        #expect(!run(samples).isInCall)
    }

    @Test("Playback alone is not a call")
    func playbackAloneIsNotACall() {
        // Music, a video, a podcast — by far the most common state of a machine, and the one this
        // must never mistake for a meeting. On AirPods this is also the exact case the old
        // device-wide read got wrong: one shared device object reported "in use" for both
        // directions, so a podcast qualified.
        let samples = Array(repeating: (input: false, output: true), count: 300)
        #expect(!run(samples).isInCall)
    }

    @Test("Unrelated microphone and playback processes are not a call")
    func unrelatedTwoWayAudioIsNotACall() {
        var presence = CallPresence()
        for second in 0...Int(CallPresence.confirmAfter + 2) {
            presence.update(
                inputByOthers: true,
                outputByOthers: true,
                plausibleCall: false,
                selfIsCapturing: false,
                at: TimeInterval(second)
            )
        }
        #expect(!presence.isInCall)
    }

    @Test("Utter's own recording is never mistaken for a call")
    func selfCaptureIsSuppressed() {
        // A meeting capture takes the far side through ScreenCaptureKit, which is not a HAL client
        // of Utter's, so the detector's pid filter cannot attribute it to us.
        #expect(!run(both(120), selfIsCapturing: true).isInCall)
    }

    @Test("Starting a capture ends a live call, and reports the change")
    func selfCaptureEndsALiveCall() {
        // The mechanism by which starting a meeting from the Notes screen takes the offer card down:
        // the transition is what the owner turns into `onCallEnded`. Never exercised before —
        // `selfCaptureIsSuppressed` passes `true` for every sample, so `isInCall` was false already
        // and the branch's return value was dead.
        var presence = confirmedCall()
        let changed = presence.update(inputByOthers: true, outputByOthers: true,
                                      selfIsCapturing: true, at: afterConfirm())
        #expect(changed, "the caller was never told the call ended, so the card would stay up")
        #expect(!presence.isInCall)
    }

    @Test("The call is picked up again once Utter stops capturing")
    func suppressionLiftsAfterCapture() {
        // Suppression clears the clock, so the call has to be held for `confirmAfter` again rather
        // than firing on the first sample after the capture stops.
        var presence = confirmedCall()
        presence.update(inputByOthers: true, outputByOthers: true,
                        selfIsCapturing: true, at: afterConfirm())
        let t = afterConfirm() + 1
        var changes = 0
        for i in 0...Int(CallPresence.confirmAfter + 1) {
            if presence.update(inputByOthers: true, outputByOthers: true,
                               selfIsCapturing: false, at: t + TimeInterval(i)) {
                changes += 1
            }
        }
        #expect(presence.isInCall)
        #expect(changes == 1, "reported \(changes) transitions coming out of suppression")
    }

    @Test("A mute does not end the call")
    func muteDoesNotEndTheCall() {
        // Some clients close the input device when you mute. Ending here would stop a capture in
        // the middle of a meeting, which is the expensive direction of this mistake.
        var presence = confirmedCall(from: 0)
        var t = afterConfirm(0)

        // Muted for less than the release window: still in the call.
        for _ in 0..<Int(CallPresence.releaseAfter - 2) {
            presence.update(inputByOthers: false, outputByOthers: true,
                            selfIsCapturing: false, at: t)
            t += 1
        }
        #expect(presence.isInCall, "a mute shorter than the release window ended the call")
    }

    @Test("Hanging up ends the call, once the release window has passed")
    func hangingUpEndsTheCall() {
        var presence = confirmedCall(from: 0)
        var t = afterConfirm(0)
        for _ in 0...Int(CallPresence.releaseAfter + 1) {
            presence.update(inputByOthers: false, outputByOthers: false,
                            selfIsCapturing: false, at: t)
            t += 1
        }
        #expect(!presence.isInCall)
    }

    @Test("The transition is reported exactly once")
    func transitionsAreReportedOnce() {
        // The caller shows a panel on the transition, so a second `true` would stack panels.
        var presence = CallPresence()
        var changes = 0
        for i in 0...Int(CallPresence.confirmAfter + 30) {
            if presence.update(inputByOthers: true, outputByOthers: true,
                               selfIsCapturing: false, at: TimeInterval(i)) {
                changes += 1
            }
        }
        #expect(changes == 1, "reported \(changes) transitions for one call")
    }

    // MARK: - Declining

    @Test("Declining silences the call it was declined for")
    func declineIsNotReOffered() {
        // The defect this exists for: decline used to go through `reset()`, which zeroed the clock
        // as well as the flag. The devices had not changed, so the next samples re-qualified and a
        // fresh card appeared `confirmAfter` later — one every five seconds for the rest of the
        // meeting.
        var presence = confirmedCall()
        presence.decline()
        #expect(!presence.isInCall)

        let t = afterConfirm()
        var changes = 0
        for i in 0..<600 {
            if presence.update(inputByOthers: true, outputByOthers: true,
                               selfIsCapturing: false, at: t + TimeInterval(i)) {
                changes += 1
            }
        }
        #expect(changes == 0, "re-offered the declined call \(changes) times")
        #expect(!presence.isInCall)
    }

    @Test("Declining does not silence the next call")
    func declineClearsOnRelease() {
        var presence = confirmedCall()
        presence.decline()
        var t = afterConfirm()

        // Still in the declined call.
        for _ in 0..<30 {
            presence.update(inputByOthers: true, outputByOthers: true, selfIsCapturing: false, at: t)
            t += 1
        }
        // It ends. The release window is what takes the latch off.
        for _ in 0...Int(CallPresence.releaseAfter + 1) {
            presence.update(inputByOthers: false, outputByOthers: false,
                            selfIsCapturing: false, at: t)
            t += 1
        }
        // A new call.
        var changes = 0
        for i in 0...Int(CallPresence.confirmAfter + 1) {
            if presence.update(inputByOthers: true, outputByOthers: true,
                               selfIsCapturing: false, at: t + TimeInterval(i)) {
                changes += 1
            }
        }
        #expect(presence.isInCall, "one decline silenced every later call")
        #expect(changes == 1)
    }

    @Test("A capture during a declined call does not unlock the offer")
    func declineSurvivesSuppression() {
        // Dictating mid-call runs the suppression branch, which clears the clock. If that also
        // cleared the decline, the card would come back a few seconds after the user stopped
        // dictating — in the call they had already said no to.
        var presence = confirmedCall()
        presence.decline()
        presence.update(inputByOthers: true, outputByOthers: true,
                        selfIsCapturing: true, at: afterConfirm())
        let t = afterConfirm() + 1

        var changes = 0
        for i in 0..<60 {
            if presence.update(inputByOthers: true, outputByOthers: true,
                               selfIsCapturing: false, at: t + TimeInterval(i)) {
                changes += 1
            }
        }
        #expect(changes == 0)
        #expect(!presence.isInCall)
    }

    @Test("A reset does ask again — it is for stopping the watch")
    func resetForgetsTheDecline() {
        // `reset()` is `stop()`'s, and switching the feature off and on again is a fair request to
        // be asked afresh. The distinction between this and `decline()` is the whole of the fix.
        var presence = confirmedCall()
        presence.decline()
        presence.reset()
        let t = afterConfirm()

        for i in 0...Int(CallPresence.confirmAfter + 1) {
            presence.update(inputByOthers: true, outputByOthers: true,
                            selfIsCapturing: false, at: t + TimeInterval(i))
        }
        #expect(presence.isInCall)
    }

    // MARK: - The clock

    @Test("Release is slower than confirmation, deliberately")
    func windowsAreAsymmetric() {
        // If these ever invert, a mute becomes a hang-up. The asymmetry is the design, so it is
        // pinned rather than left to whoever next tunes the numbers.
        #expect(CallPresence.releaseAfter > CallPresence.confirmAfter)
    }

    @Test("A clock that jumps forward does not skip the confirm window")
    func aForwardJumpStillDebounces() {
        // What sleep/wake did on the old wall clock: `since` is only reset when the sample
        // *changes*, so an hour of sleep made `held` an hour and the very first sample after wake
        // qualified — the debounce whose entire purpose is to sit out a chime never ran. Fed
        // `systemUptime` this cannot happen, because sleep does not advance it; the value type is
        // pinned anyway, since it is the thing that would be wrong.
        var presence = CallPresence()
        presence.update(inputByOthers: true, outputByOthers: true, selfIsCapturing: false, at: 100)
        // One sample, one hour later, nothing else changed.
        presence.update(inputByOthers: true, outputByOthers: true, selfIsCapturing: false, at: 3_700)
        #expect(presence.isInCall, "a genuine hour of two-way audio is a call")

        // And the same jump must not confirm a call from a *single* sample when the run began at
        // the jump itself.
        var fresh = CallPresence()
        fresh.update(inputByOthers: false, outputByOthers: false, selfIsCapturing: false, at: 100)
        fresh.update(inputByOthers: true, outputByOthers: true, selfIsCapturing: false, at: 3_700)
        #expect(!fresh.isInCall, "confirmed a call from one sample by inheriting an old clock")
    }

    @Test("A clock that steps backwards restarts the run rather than sticking")
    func aBackwardStepDoesNotStickTheCall() {
        // A backwards step (NTP, or a user setting the clock) made `held` negative, and a negative
        // interval never reaches `releaseAfter` — so `isInCall` stuck true and a capture kept
        // running after the call. The run restarts instead, at the cost of one sample.
        var presence = confirmedCall()
        let t = afterConfirm()

        // Hang up, then the clock goes back an hour mid-release.
        presence.update(inputByOthers: false, outputByOthers: false, selfIsCapturing: false, at: t)
        presence.update(inputByOthers: false, outputByOthers: false,
                        selfIsCapturing: false, at: t - 3_600)
        #expect(presence.isInCall, "nothing has been held long enough yet either way")

        // From the stepped-back clock, the release window still completes.
        var now = t - 3_600
        for _ in 0...Int(CallPresence.releaseAfter + 1) {
            presence.update(inputByOthers: false, outputByOthers: false,
                            selfIsCapturing: false, at: now)
            now += 1
        }
        #expect(!presence.isInCall, "the call stuck after a backwards clock step")
    }
}
