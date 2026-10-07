import Testing
import Foundation
@testable import UtterKit

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
