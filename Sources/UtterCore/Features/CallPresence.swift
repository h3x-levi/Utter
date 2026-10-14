import Foundation

/// Decides whether the machine is in a call, from what CoreAudio will say about the processes
/// currently doing audio IO.
///
/// Split out from the CoreAudio plumbing because the plumbing cannot be tested on this machine and
/// this can: everything that decides *whether to interrupt the user* lives here, as a value type
/// fed timestamps, and `CallDetector` is the thin shim that reads the properties.
///
/// **Why app identity and audio state.** Merely seeing Zoom or Teams in
/// `NSWorkspace.runningApplications` says only that the app is open. The detector instead requires
/// a supported calling app to be actively using both input and output. Browsers are excluded because
/// their process-level audio cannot distinguish a meeting from YouTube.
///
/// **Why both directions.** Input alone lights up for a voice memo, a Siri query, or another
/// dictation tool. A call is the only ordinary thing that has a microphone open *and* audio coming
/// out at the same time, sustained. Requiring both is what makes this quiet enough to act on.
///
/// **Why "by others", and why that word is load-bearing.** The first version of the shim read
/// `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device and again on the
/// default output device. That property is documented as device-wide - "the AudioDevice is running
/// in at least one process on the system" - with no direction in it, and on AirPods, most USB and
/// Bluetooth headsets, and any aggregate device the default input and the default output are the
/// *same* `AudioObjectID`. So both reads returned one value, `input && output` degenerated to "this
/// device is in use by something", and a podcast on AirPods was a call. The two facts now come from
/// `kAudioProcessPropertyIsRunningInput` / `IsRunningOutput` on per-process objects, with Utter's
/// own process excluded by pid, so they are genuinely independent and genuinely somebody else's.
struct CallPresence: Equatable {

    /// How long both directions must stay open before this is called a call.
    ///
    /// Long enough to sit out the things that briefly do look like one: a notification chime while
    /// dictating, "Hey Siri", a video autoplaying in a tab you already had open. Short enough that
    /// the offer still arrives while the meeting is worth transcribing rather than half over.
    static let confirmAfter: TimeInterval = 5

    /// How long both must stay closed before the call is considered over.
    ///
    /// Asymmetric on purpose, and longer than `confirmAfter`: people mute themselves for minutes at
    /// a time, and a mute closes the input device on some clients. Ending a call on the first
    /// silence would tear down a capture mid-meeting, which is much worse than noticing late.
    static let releaseAfter: TimeInterval = 20

    /// Whether a call is currently believed to be in progress.
    private(set) var isInCall = false

    /// When the current run of "both open" or "both closed" began.
    ///
    /// On the caller's clock, which must be monotonic - `CallDetector` feeds
    /// `ProcessInfo.systemUptime`. `update` defends against a clock that moves backwards anyway,
    /// because a value type should not be wrong about its caller.
    private var since: TimeInterval?

    /// What the last sample looked like, so a change restarts the clock.
    private var lastQualified = false

    /// The user has said no to the call that is happening now.
    ///
    /// This is a latch and not a reset, and the difference was a real defect: declining used to
    /// call `reset()`, which zeroed `since` and `lastQualified` as well. The devices had not
    /// changed, so the very next sample started a fresh run of "both open", `confirmAfter` later the
    /// transition fired again and an identical card appeared - one every five seconds, so roughly
    /// 540 of them over a 45-minute meeting. Cleared only when the release condition is actually
    /// met, so one "not now" covers this call and nothing beyond it.
    private var declined = false

    /// Feed a sample. Returns true when `isInCall` changed, so the caller can act once per
    /// transition rather than on every sample.
    ///
    /// `qualified` is "one supported calling app has both the microphone and the speakers open"
    /// (`CallAudioEvidence`). `selfIsCapturing` suppresses the whole thing while Utter is recording;
    /// see `CallDetector.selfIsCapturing`.
    @discardableResult
    mutating func update(qualified: Bool,
                         selfIsCapturing: Bool,
                         at now: TimeInterval) -> Bool {
        // Our own capture makes the surrounding audio state meaningless. Reset rather than hold a
        // stale run, so the clock starts fresh when we let go of the microphone.
        if selfIsCapturing {
            since = nil
            lastQualified = false
            let changed = isInCall
            isInCall = false
            return changed
        }

        if qualified != lastQualified {
            lastQualified = qualified
            since = now
        }
        guard let since else {
            self.since = now
            return false
        }

        let held = now - since
        // A negative interval means the caller's clock is not the monotonic one this expects.
        // Trusting it is the worse failure of the two: a backwards step stalls the release
        // arithmetic, so `isInCall` sticks true and a capture keeps running after the call, and a
        // forwards jump makes `held` enormous and skips the confirm window whose entire job is to
        // sit out a chime. Restart the run instead and lose one sample.
        if held < 0 {
            self.since = now
            return false
        }

        let wasInCall = isInCall
        if qualified, !isInCall, !declined, held >= Self.confirmAfter {
            isInCall = true
        } else if !qualified, held >= Self.releaseAfter {
            isInCall = false
            // The same run of "both closed" that ends a call is what clears a decline: the call the
            // user said no to is over, so the next one may ask. Reached whether or not `isInCall`
            // was true, because after a decline it is already false and the latch still has to
            // come off.
            declined = false
        }
        return isInCall != wasInCall
    }

    /// The user said no to *this* call.
    ///
    /// Clears `isInCall` so no capture is running and no card is owed, and latches `declined` so
    /// the unchanged device state cannot re-qualify. `since` and `lastQualified` are deliberately
    /// left alone: they are what the release window is measured from, and the release is what
    /// eventually lets the *next* call ask.
    mutating func decline() {
        declined = true
        isInCall = false
    }

    /// Forget everything - for `CallDetector.stop()`, which is the only caller.
    ///
    /// Not for declining. That used to come through here, and zeroing the clock was exactly the
    /// bug `declined` documents.
    mutating func reset() {
        self = CallPresence()
    }
}
