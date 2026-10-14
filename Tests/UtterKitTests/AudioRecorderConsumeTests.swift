import AVFoundation
import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// `AudioRecorder.consume` front-trims the rolling capture buffer during a meeting, and the
/// bytes it leaves behind are read back with 0-based offsets by `MeetingSession.transcribeWindows`
/// (`data.subdata(in: cursor..<cursor + take)`, cursor starting at 0).
///
/// The trap this guards against is a Foundation gotcha: `Data.removeFirst` advances the value's
/// `startIndex` instead of rebasing it to 0, so after one consume the buffer's indices no longer
/// start at 0 and that 0-based `subdata` reads below `startIndex` and traps (SIGTRAP - this shipped
/// as a crash in a meeting past ~60s, the point at which the second 30s window is drained). The fix
/// is `subdata`, which returns a fresh zero-based tail. These tests pin the invariant every reader
/// depends on: after `consume`, the buffer starts at 0 and is safe to slice from 0.
///
/// `SystemAudioCapture.consume` is the identical idiom on the "Others" stream; it shares the fix and
/// the reasoning, and cannot be seeded without a live system-audio tap, so this suite stands in for
/// both.
@Suite("AudioRecorder buffer consumption")
struct AudioRecorderConsumeTests {

    private func buffer(_ count: Int) -> Data {
        Data((0..<count).map { UInt8($0 & 0xFF) })
    }

    @Test("A consumed buffer stays zero-based and slices from 0 without trapping")
    func consumeLeavesZeroBasedBuffer() {
        let recorder = AudioRecorder()
        recorder.audioData = buffer(100)

        recorder.consume(30)

        let remaining = recorder.audioData
        #expect(remaining.startIndex == 0)
        #expect(remaining.count == 70)
        // The exact MeetingSession read: 0-based offsets. Trapped before the fix.
        let chunk = remaining.subdata(in: 0..<30)
        #expect(chunk.count == 30)
        // The tail was kept, not the head: byte 0 of the remainder is old byte 30.
        #expect(chunk.first == 30)
    }

    @Test("Repeated consumes keep the buffer zero-based rather than accumulating an offset")
    func repeatedConsumeStaysZeroBased() {
        let recorder = AudioRecorder()
        recorder.audioData = buffer(100)

        recorder.consume(30)
        recorder.consume(30)

        let remaining = recorder.audioData
        #expect(remaining.startIndex == 0)
        #expect(remaining.count == 40)
        // This is the read that crashed in production: a second window drained after a
        // previous window was already consumed.
        #expect(remaining.subdata(in: 0..<40).first == 60)
    }

    @Test("consume ignores out-of-range and non-positive counts")
    func consumeGuardsBounds() {
        let recorder = AudioRecorder()
        recorder.audioData = buffer(10)

        recorder.consume(0)
        recorder.consume(-5)
        recorder.consume(11)
        #expect(recorder.audioData.count == 10)

        // Consuming everything is allowed and leaves an empty, zero-based buffer.
        recorder.consume(10)
        #expect(recorder.audioData.isEmpty)
        #expect(recorder.audioData.startIndex == 0)
    }
}

@Suite("AudioRecorder resampling")
struct AudioRecorderConverterTests {

    /// Each tap buffer must reach the resampler exactly once. A repeat, or the skip that follows
    /// one, is a phase jump in a pure tone fed through tap-sized chunks.
    @Test("A tap buffer is resampled once, with no repeated stretch")
    func inputBlockDoesNotDuplicate() throws {
        let rate = 48_000.0, tone = 440.0, chunk = 4096, chunks = 20
        let input = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate,
                                               channels: 1, interleaved: false))
        let output = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                                channels: 1, interleaved: true))
        let converter = try #require(AVAudioConverter(from: input, to: output))

        var samples: [Int16] = []
        for index in 0..<chunks {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: input, frameCapacity: AVAudioFrameCount(chunk)))
            buffer.frameLength = AVAudioFrameCount(chunk)
            let channel = try #require(buffer.floatChannelData)[0]
            for frame in 0..<chunk {
                let t = Double(index * chunk + frame) / rate
                channel[frame] = Float(0.5 * sin(2 * .pi * tone * t))
            }
            let converted = try #require(AudioRecorder.convert(buffer, with: converter))
            let pcm = try #require(converted.int16ChannelData)[0]
            samples += (0..<Int(converted.frameLength)).map { pcm[$0] }
        }

        let expected = chunks * chunk / 3
        #expect(abs(samples.count - expected) <= chunks)

        // A pure tone obeys x[n+1] = 2cos(w)x[n] - x[n-1]; a repeated stretch is a phase jump.
        let k = 2 * cos(2 * Double.pi * tone / 16_000)
        let x = samples.map(Double.init)
        var worst = 0.0
        for n in 200..<(x.count - 1) {
            worst = max(worst, abs(x[n + 1] - k * x[n] + x[n - 1]))
        }
        #expect(worst < 64, "largest continuity residual \(worst)")
    }

    @Test("The microphone list names every device once")
    func microphonesHaveNamesAndUniqueIDs() {
        let mics = AudioInputs.all()
        #expect(mics.allSatisfy { !$0.name.isEmpty })
        #expect(Set(mics.map(\.id)).count == mics.count)
    }
}
