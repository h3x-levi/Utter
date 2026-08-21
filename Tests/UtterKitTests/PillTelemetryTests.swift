import Testing
import Foundation
import Combine
@testable import UtterKit

/// The two pieces of throttling that keep the pill cheap while it is recording.
///
/// Both exist because something was measured doing far more work than the thing it displayed
/// needed, and both are the kind of defect that is invisible in the UI and only shows up as the
/// app feeling slow — so a test is the only place they can be held.
@Suite("Pill telemetry throttling")
struct PillTelemetryTests {

    // MARK: The elapsed-seconds guard

    @Test("Re-assigning the same elapsed second does not republish")
    func elapsedCoalescesRepeats() {
        // The recording timer assigns `elapsed` ten times a second so the displayed second is
        // never late, but `@Published` sends `objectWillChange` on every assignment regardless of
        // whether the value moved. That invalidated the whole pill — glass, both strokes, the
        // shell shape, the level meter — 10x/s to redraw a number that changes 1x/s.
        let model = PillStateModel()
        var sends = 0
        let subscription = model.objectWillChange.sink { _ in sends += 1 }
        defer { subscription.cancel() }

        model.elapsed = 7
        model.elapsed = 7
        model.elapsed = 7
        #expect(sends == 1, "three assignments of the same second must publish once")

        model.elapsed = 8
        #expect(sends == 2, "a real change must still publish")
        #expect(model.elapsed == 8)
    }

    @Test("The guard does not break the value or its formatting")
    func elapsedStillReadsBack() {
        let model = PillStateModel()
        model.elapsed = 0
        #expect(model.elapsedText == "0:00")
        model.elapsed = 7
        #expect(model.elapsedText == "0:07")
        model.elapsed = 75
        #expect(model.elapsedText == "1:15")
    }

    // MARK: The 30 Hz microphone level

    @Test("A microphone level does not republish the pill model")
    func levelDoesNotInvalidateTheWholePill() {
        // The level is the only quantity in the pill that moves at 30 Hz, and `LevelMeter` is the
        // only view that draws it — but `@Published` invalidates every view observing the
        // *object*, not the property. While it was a stored `@Published` on this model, one second
        // of recording re-ran `PillContainerView.body`, `PillContent.body`, the shell's
        // `GeometryReader` (glass, both strokes, the shadow) and the accessibility strings 30 times
        // each. Measured offscreen; the counts are in `PillLevelSignal`.
        //
        // This is the test that catches it coming back: re-adding `@Published var level` to
        // `PillStateModel` makes these sends non-zero again, and nothing else would notice.
        let model = PillStateModel()
        var modelSends = 0
        var signalSends = 0
        let onModel = model.objectWillChange.sink { _ in modelSends += 1 }
        let onSignal = model.levels.objectWillChange.sink { _ in signalSends += 1 }
        defer { onModel.cancel(); onSignal.cancel() }

        for i in 1...30 { model.level = Float(i) / 30 }

        #expect(modelSends == 0, "a mic publish must not invalidate the pill's glass and strokes")
        #expect(signalSends == 30, "the meter must still see every publish — it is a real signal")
    }

    @Test("The level still reads and writes through the model")
    func levelRoundTripsThroughTheModel() {
        // `stateModel.level` stays the API: `AppDelegate`'s `$inputLevel` sink writes it, its reset
        // writes 0, the companion's `levelSource` reads it and `PillDemoView` scripts it. A
        // pass-through that dropped writes would leave the meter flat with nothing else wrong.
        let model = PillStateModel()
        #expect(model.level == 0)
        model.level = 0.42
        #expect(model.level == 0.42)
        #expect(model.levels.value == 0.42)
        model.level = 0
        #expect(model.levels.value == 0)
    }

    // MARK: The live-preview audio window

    @Test("A buffer shorter than the cap is returned whole")
    func tailKeepsShortBuffer() {
        let data = Data(repeating: 9, count: 100)
        #expect(AudioRecorder.tail(of: data, lastBytes: 500).count == 100)
        // Exactly at the cap is still the whole buffer, not a copy of 99 bytes.
        #expect(AudioRecorder.tail(of: data, lastBytes: 100).count == 100)
    }

    @Test("A long buffer keeps its NEWEST bytes, which is the whole point")
    func tailKeepsTheNewestAudio() {
        // 0,1,2,...,199 — so the value of a byte identifies its position.
        let data = Data((0..<200).map { UInt8($0 % 256) })
        let tail = AudioRecorder.tail(of: data, lastBytes: 50)

        #expect(tail.count == 50)
        // The last 50 bytes are values 150...199. Taking the *head* instead would be the
        // regression that matters: the preview would freeze on the first words spoken and never
        // show the ones just said.
        #expect(tail.first == 150)
        #expect(tail.last == 199)
        // And the result is zero-based, so callers may index it from 0.
        #expect(tail.startIndex == 0)
    }

    @Test("A front-trimmed buffer still yields its true tail")
    func tailSurvivesAConsumedBuffer() {
        // `consume` rebases, but the indices are read from `endIndex` rather than from `count` so
        // that this holds even if a caller hands over a slice that is not zero-based.
        var data = Data((0..<200).map { UInt8($0 % 256) })
        data = data.subdata(in: 100..<200)   // values 100...199
        let tail = AudioRecorder.tail(of: data, lastBytes: 10)
        #expect(tail.count == 10)
        #expect(tail.first == 190)
        #expect(tail.last == 199)
    }

    @Test("Degenerate caps are refused rather than trapping")
    func tailGuardsDegenerateCaps() {
        let data = Data(repeating: 1, count: 10)
        #expect(AudioRecorder.tail(of: data, lastBytes: 0).isEmpty)
        #expect(AudioRecorder.tail(of: data, lastBytes: -5).isEmpty)
        #expect(AudioRecorder.tail(of: Data(), lastBytes: 100).isEmpty)
    }

    @Test("The preview window is ten seconds of this recorder's own format")
    func previewWindowMatchesTheDocumentedSeconds() {
        // 16 kHz, mono, 16-bit = 32,000 bytes per second. The constant is derived rather than
        // written down twice, and `LocalWhisperProvider.previewTranscribe` documents the bound as
        // living here — so this pins the relationship that comment relies on.
        #expect(AudioRecorder.previewSeconds == 10)
        #expect(AudioRecorder.previewWindowBytes == 10 * 16_000 * 2)
    }
}
