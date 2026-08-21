import Testing
@testable import UtterKit

/// The peak-amplitude scan the microphone tap runs on every buffer.
///
/// One input crashed the app: a sample of exactly `Int16.min`. The scan used `abs`, and
/// `abs(Int16.min)` has no representable result in `Int16`, so Swift trapped on overflow —
/// on the audio render thread, where a trap is an immediate SIGTRAP with no recovery. It was
/// reported from a real session as a `SIGTRAP` in `checkVoiceActivity`.
///
/// -32768 is full-scale negative, which loud speech and any clipping conversion produce, so
/// this was reachable simply by talking loudly. These cases exist so the `abs` cannot return.
@Suite("Audio amplitude")
struct AudioAmplitudeTests {

    private func peak(_ samples: [Int16]) -> UInt16 {
        samples.withUnsafeBufferPointer {
            AudioRecorder.peakAmplitude($0.baseAddress!, count: $0.count)
        }
    }

    @Test("The minimum sample does not trap, and reports its true magnitude")
    func minimumSampleIsSurvivable() {
        // The crash, as a value. 32768 is not representable in Int16 at all, which is the
        // whole point: the result has to come back in a wider unsigned type.
        #expect(peak([Int16.min]) == 32_768)
        #expect(peak([0, Int16.min, 0]) == 32_768)
        // Full-scale negative is louder than full-scale positive by one, and must win.
        #expect(peak([Int16.max, Int16.min]) == 32_768)
    }

    @Test("Ordinary chunks report the loudest sample either side of zero")
    func peakIsTheLoudestSample() {
        #expect(peak([0, 0, 0]) == 0)
        #expect(peak([100, -900, 300]) == 900)
        #expect(peak([-100, 900, -300]) == 900)
        #expect(peak([Int16.max]) == 32_767)
    }

    @Test("An empty chunk is silence, not a crash")
    func emptyChunkIsSilent() {
        // `frameLength` comes from the converter's output buffer, and a conversion that
        // produced no frames must not index anything.
        #expect(peak([]) == 0)
    }

    @Test("The silence threshold still discriminates speech from a quiet room")
    func thresholdStillSeparatesVoiceFromSilence() {
        // The comparison moved from Int16 to UInt16 when the trap was fixed; 500 has to keep
        // meaning what it meant. Room tone sits well under it, speech well over.
        let threshold: UInt16 = 500
        #expect(peak([12, -30, 8]) < threshold)          // a quiet room
        #expect(peak([4_000, -6_500, 900]) > threshold)  // someone talking
        // And a full-scale sample reads as voice rather than wrapping to something quiet,
        // which is what the trap was hiding.
        #expect(peak([Int16.min]) > threshold)
    }
}
