import AudioToolbox
import Testing
@testable import UtterKit

@Suite("Call audio evidence")
struct CallAudioEvidenceTests {
    private func source(
        _ id: AudioObjectID,
        bundleID: String?,
        name: String? = nil
    ) -> CallSource {
        CallSource(
            processObject: id,
            pid: pid_t(id),
            bundleID: bundleID,
            appName: name
        )
    }

    @Test("One process using input and output qualifies")
    func oneProcessBothDirections() {
        let unknown = source(1, bundleID: "com.example.calls", name: "Calls")
        let candidate = CallAudioEvidence.candidate(from: [
            CallProcessActivity(source: unknown, runsInput: true, runsOutput: true),
        ])
        #expect(candidate == unknown)
    }

    @Test("Chrome helpers may split input and output")
    func recognizedFamilyMaySplitDirections() {
        let input = source(2, bundleID: "com.google.Chrome.helper.audio")
        let output = source(3, bundleID: "com.google.Chrome.helper.renderer")
        let candidate = CallAudioEvidence.candidate(from: [
            CallProcessActivity(source: input, runsInput: true, runsOutput: false),
            CallProcessActivity(source: output, runsInput: false, runsOutput: true),
        ])
        #expect(candidate == output)
    }

    @Test("Unrelated microphone and playback apps do not qualify")
    func unrelatedProcessesDoNotQualify() {
        let microphone = source(4, bundleID: "com.example.voicememo")
        let playback = source(5, bundleID: "com.spotify.client", name: "Spotify")
        let candidate = CallAudioEvidence.candidate(from: [
            CallProcessActivity(source: microphone, runsInput: true, runsOutput: false),
            CallProcessActivity(source: playback, runsInput: false, runsOutput: true),
        ])
        #expect(candidate == nil)
    }

    @Test("Different recognized app families do not qualify")
    func differentKnownFamiliesDoNotQualify() {
        let input = source(6, bundleID: "com.google.Chrome.helper.audio")
        let output = source(7, bundleID: "com.tinyspeck.slackmacgap.helper")
        let candidate = CallAudioEvidence.candidate(from: [
            CallProcessActivity(source: input, runsInput: true, runsOutput: false),
            CallProcessActivity(source: output, runsInput: false, runsOutput: true),
        ])
        #expect(candidate == nil)
    }
}
