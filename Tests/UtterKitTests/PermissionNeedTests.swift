import Testing
@testable import UtterKit

/// Which of the three treatments a permission row gets.
///
/// `PermRow` cannot be rendered on this machine, so what is pinned here is the rule it
/// is built out of — and it is a rule that fails silently in both directions. Too eager
/// and a fresh install shows a warning and a call to action for a permission the user
/// may never need, which is the bug this replaced. Too relaxed and Screen Recording
/// reads as optional at the moment meeting capture actually needs it, which produces a
/// meeting transcript containing one side of the conversation and no hint why.
@Suite("Permission need")
struct PermissionNeedTests {

    // MARK: The core permissions

    @Test("Dictation's own permissions are required the moment they are missing")
    func corePermissionsAreRequiredWhenMissing() {
        // Accessibility and the microphone are what dictation *is*. There is no
        // "optional until used" state for them and this must not acquire one.
        #expect(PermissionNeed.core(granted: false) == .required)
        #expect(PermissionNeed.core(granted: true) == .granted)
    }

    // MARK: Screen Recording

    @Test("Nothing switched on: optional, with a reason, never a warning")
    func optionalOnADefaultInstall() {
        // The default state of a fresh install: `offerToTranscribeCalls` starts false
        // and no capture has been attempted. This is the case that was showing a
        // warning dot and a Grant button for a feature the user had not asked for.
        let need = PermissionNeed.screenRecording(granted: false,
                                                  offersToTranscribeCalls: false,
                                                  meetingCaptureUnderway: false)
        #expect(need == .optional(reason: PermissionNeed.meetingsOnly))
        // The optional state is the only one that carries a supporting line, and it
        // must carry one — it is what tells a sighted user this is not a problem, and
        // the row would otherwise be distinguishable from `.required` by the dot's
        // colour alone.
        #expect(need.reason != nil)
    }

    @Test("The call-transcription preference makes it required")
    func preferenceOnMakesItRequired() {
        // With the switch on, `CallDetector` runs and will offer to record the next
        // call; accepting without this permission records only the user. So the
        // warning is honest from the moment the switch moves, before any capture.
        #expect(PermissionNeed.screenRecording(granted: false,
                                               offersToTranscribeCalls: true,
                                               meetingCaptureUnderway: false) == .required)
    }

    @Test("A capture in flight or just failed makes it required, preference or not")
    func captureUnderwayMakesItRequired() {
        // The Notes screen's Record button starts a capture with the preference off,
        // and `MeetingSession.state` stays non-`.idle` after a failed start until the
        // next attempt. That is the moment a user opens Settings to find out why, so
        // it is the moment the row has to stop calling itself optional.
        #expect(PermissionNeed.screenRecording(granted: false,
                                               offersToTranscribeCalls: false,
                                               meetingCaptureUnderway: true) == .required)
    }

    @Test("Granted outranks every reason it might be needed")
    func grantedWinsOverNeed() {
        // Order matters inside the rule: a granted permission must never render a
        // warning, however loudly the other two signals say it is needed. Checked
        // across all four combinations rather than the one that happens to be live,
        // because getting this backwards would put a permanent amber dot on the row
        // of the users who had already done what was asked of them.
        for preference in [true, false] {
            for underway in [true, false] {
                #expect(PermissionNeed.screenRecording(granted: true,
                                                       offersToTranscribeCalls: preference,
                                                       meetingCaptureUnderway: underway) == .granted)
            }
        }
    }

    // MARK: What VoiceOver hears

    @Test("Every state announces itself differently in words")
    func eachStateIsSpokenDistinctly() {
        // The requirement this exists for: the three states must not be told apart
        // only by the dot. VoiceOver never sees the dot, so if two of these strings
        // matched, two states would be indistinguishable to a screen reader — and
        // `optional` vs `required` is the pair that matters, since one is "you have
        // nothing to do" and the other is "this feature will not work".
        let spoken = [
            PermissionNeed.granted.spoken,
            PermissionNeed.required.spoken,
            PermissionNeed.optional(reason: PermissionNeed.meetingsOnly).spoken,
        ]
        #expect(Set(spoken).count == spoken.count)
        // The reason is spoken, not just drawn — it is hidden from VoiceOver as its own
        // element precisely because it is folded in here, so losing it would lose it
        // outright.
        #expect(PermissionNeed.optional(reason: PermissionNeed.meetingsOnly).spoken
                    .contains(PermissionNeed.meetingsOnly))
    }

    @Test("Only the optional state draws a supporting line")
    func onlyOptionalHasAReason() {
        // Keeps the two required rows byte-identical to what they rendered before:
        // a nil reason is what makes the row collapse back to a single line.
        #expect(PermissionNeed.granted.reason == nil)
        #expect(PermissionNeed.required.reason == nil)
    }
}
