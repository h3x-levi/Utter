import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// The conversion both meeting-capture routes share.
///
/// Worth a test rather than trusted because it is now the single implementation for two callers  - 
/// ScreenCaptureKit's `CMSampleBuffer` and the process tap's `AudioBufferList` - so a defect here is a
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
        // one channel's worth of frames - dividing by the channel count here would drop half of it,
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
        // exactly when it does not. Without the clamp, `Int16(1.5 * 32767)` traps in Swift - and the
        // C version of the same bug wraps to a large negative value, which is a click at full scale in
        // the middle of a transcript.
        let (out, peak) = convert([1.5, -2.0, 40.0], channels: 1, interleaved: true)
        #expect(out == [32_767, -32_767, 32_767])
        // The peak is the *measured* level, not the clamped one: it exists to answer "is this tap
        // hearing anything", and reporting 1.0 for a signal that was 40 would hide clipping.
        #expect(peak == 40.0)
    }

    // MARK: Resampling

    private func tone(_ hz: Double, rate: Double, seconds: Double) -> Data {
        var data = Data()
        for i in 0..<Int(rate * seconds) {
            var sample = Int16(sin(2 * .pi * hz * Double(i) / rate) * 16_000)
            withUnsafeBytes(of: &sample) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func rms(_ data: Data) -> Double {
        let values = samples(data).map(Double.init)
        return values.isEmpty ? 0 : (values.map { $0 * $0 }.reduce(0, +) / Double(values.count)).squareRoot()
    }

    /// Feeds the stream in 10 ms buffers, the way a tap delivers it.
    private func resample(_ data: Data, from rate: Double) -> Data {
        let resampler = SystemAudioPCM.Resampler()
        let chunk = Int(rate / 100) * 2
        var out = Data()
        var offset = 0
        while offset < data.count {
            out += resampler.sixteenK(data.subdata(in: offset..<min(offset + chunk, data.count)), from: rate)
            offset += chunk
        }
        return out
    }

    @Test("48 kHz speech-band audio comes out at 16 kHz with its level kept")
    func resampleKeepsSpeech() {
        let input = tone(440, rate: 48_000, seconds: 1)
        let out = resample(input, from: 48_000)
        #expect(abs(out.count / 2 - 16_000) < 400, "\(out.count / 2) samples")
        #expect(abs(rms(out) - rms(input)) / rms(input) < 0.1)
    }

    @Test("Sound above 8 kHz is filtered out, not folded down into the speech band")
    func resampleDoesNotAlias() {
        // Taking every third sample would turn a 10 kHz tone into a full-level 6 kHz one.
        let input = tone(10_000, rate: 48_000, seconds: 1)
        #expect(rms(resample(input, from: 48_000)) < rms(input) * 0.1)
    }

    @Test("16 kHz passes through untouched, and nothing in is nothing out")
    func resampleDegenerate() {
        let input = tone(440, rate: 16_000, seconds: 0.1)
        #expect(SystemAudioPCM.Resampler().sixteenK(input, from: 16_000) == input)
        #expect(SystemAudioPCM.Resampler().sixteenK(Data(), from: 48_000).isEmpty)
    }

    @Test("Each buffer's stamp places its samples on the host clock, across a trim")
    func sampleClockFollowsTheFront() throws {
        var clock = SampleClock()
        let start = SampleClock.seconds(1_000_000_000)
        let tick = 1_000_000_000 / SampleClock.seconds(1_000_000_000)  // host units per second
        clock.stamp(offset: 0, host: 1_000_000_000)
        // A second buffer that arrived 0.5 s late: its stamp, not the byte count, decides its time.
        clock.stamp(offset: 32_000, host: 1_000_000_000 + UInt64(1.5 * tick))
        #expect(abs(try #require(clock.seconds(at: 16_000)) - (start + 0.5)) < 0.001)
        #expect(abs(try #require(clock.seconds(at: 48_000)) - (start + 2.0)) < 0.001)
        clock.consume(40_000)
        #expect(abs(try #require(clock.seconds(at: 8_000)) - (start + 2.0)) < 0.001)
        #expect(SampleClock().seconds(at: 0) == nil)
    }
}
