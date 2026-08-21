import Testing
import Foundation
@testable import UtterKit

/// The conversion both meeting-capture routes share.
///
/// Worth a test rather than trusted because it is now the single implementation for two callers —
/// ScreenCaptureKit's `CMSampleBuffer` and the process tap's `AudioBufferList` — so a defect here is a
/// defect in every recorded meeting, and because the two things it does wrong most easily are silent:
/// a downmix that reads past the end of a deinterleaved buffer, and a clamp that lets a hot sample
/// wrap to the opposite sign and click.
///
/// Neither route can be tested itself: one needs a Screen Recording grant and a display, the other a
/// system audio grant and a process making noise. This is the part that does not.
@Suite("System audio PCM conversion")
struct SystemAudioPCMTests {

    /// Int16 samples out of the `Data` the conversion produces.
    private func samples(_ data: Data) -> [Int16] {
        data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    }

    private func convert(_ floats: [Float32],
                        channels: Int,
                        interleaved: Bool) -> ([Int16], Float) {
        let (data, peak) = floats.withUnsafeBufferPointer { buffer in
            SystemAudioPCM.monoInt16(floats: buffer.baseAddress!,
                                     count: buffer.count,
                                     channels: channels,
                                     interleaved: interleaved)
        }
        return (samples(data), peak)
    }

    // MARK: Downmix

    @Test("Interleaved stereo is averaged into one mono sample per frame")
    func interleavedStereoIsAveraged() {
        // Two frames: (1.0, 0.0) and (-1.0, -1.0). The averages are 0.5 and -1.0.
        let (out, peak) = convert([1.0, 0.0, -1.0, -1.0], channels: 2, interleaved: true)
        #expect(out.count == 2)
        #expect(out[0] == Int16((0.5 as Float) * 32_767))
        #expect(out[1] == -32_767)
        #expect(peak == 1.0)
    }

    @Test("A deinterleaved buffer is channel 0 only, and never reads past it")
    func deinterleavedTakesTheFirstChannel() {
        // CoreAudio's native layout puts each channel in its own buffer, so the buffer handed over is
        // one channel's worth of frames — dividing by the channel count here would drop half of it,
        // and multiplying the index by it would read off the end.
        let (out, _) = convert([0.25, 0.5, 0.75, 1.0], channels: 2, interleaved: false)
        #expect(out.count == 4)
        #expect(out[3] == 32_767)
    }

    @Test("Mono interleaved is a straight pass-through")
    func monoIsUnchanged() {
        let (out, peak) = convert([0, 0.5, -0.5], channels: 1, interleaved: true)
        #expect(out.count == 3)
        #expect(out[0] == 0)
        #expect(peak == 0.5)
    }

    @Test("An empty or partial buffer produces nothing rather than crashing")
    func degenerateBuffers() {
        #expect(convert([], channels: 2, interleaved: true).0.isEmpty)
        // One float of a stereo frame is no whole frames.
        #expect(convert([0.5], channels: 2, interleaved: true).0.isEmpty)
        // A nonsense channel count is floored at 1 rather than dividing by zero.
        #expect(convert([0.5], channels: 0, interleaved: true).0.count == 1)
    }

    // MARK: Clamping

    @Test("Samples outside -1...1 clamp instead of wrapping sign")
    func hotSamplesClamp() {
        // Float PCM is not promised to stay inside the range and a mixdown of several loud sources is
        // exactly when it does not. Without the clamp, `Int16(1.5 * 32767)` traps in Swift — and the
        // C version of the same bug wraps to a large negative value, which is a click at full scale in
        // the middle of a transcript.
        let (out, peak) = convert([1.5, -2.0, 40.0], channels: 1, interleaved: true)
        #expect(out == [32_767, -32_767, 32_767])
        // The peak is the *measured* level, not the clamped one: it exists to answer "is this tap
        // hearing anything", and reporting 1.0 for a signal that was 40 would hide clipping.
        #expect(peak == 40.0)
    }

    // MARK: Resampling

    @Test("48 kHz becomes 16 kHz by taking a third of the samples")
    func resampleFromFortyEight() {
        var input = Data()
        for i in 0..<300 {
            var sample = Int16(i)
            withUnsafeBytes(of: &sample) { input.append(contentsOf: $0) }
        }
        let out = samples(SystemAudioPCM.resampleToSixteenK(input, from: 48_000))
        #expect(out.count == 100)
        // Nearest neighbour, so every third source sample: 0, 3, 6…
        #expect(out[0] == 0)
        #expect(out[1] == 3)
        #expect(out[99] == 297)
    }

    @Test("Upsampling from 8 kHz repeats rather than dropping the buffer")
    func resampleFromEight() {
        var input = Data()
        for i in 0..<10 {
            var sample = Int16(i)
            withUnsafeBytes(of: &sample) { input.append(contentsOf: $0) }
        }
        let out = samples(SystemAudioPCM.resampleToSixteenK(input, from: 8_000))
        #expect(out.count == 20)
        #expect(out[0] == 0)
        #expect(out[1] == 0)
        #expect(out[2] == 1)
        // The last index must not run off the end of the source.
        #expect(out[19] == 9)
    }

    @Test("Nothing in, nothing out")
    func resampleDegenerate() {
        #expect(SystemAudioPCM.resampleToSixteenK(Data(), from: 48_000).isEmpty)
        // A rate so high that a short buffer resamples to zero samples returns empty rather than a
        // negative count.
        var one = Data()
        var sample: Int16 = 1
        withUnsafeBytes(of: &sample) { one.append(contentsOf: $0) }
        #expect(SystemAudioPCM.resampleToSixteenK(one, from: 1_000_000).isEmpty)
    }
}
