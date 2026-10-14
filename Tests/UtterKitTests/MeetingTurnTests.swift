import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// Turn segmentation, speaker labelling, and the one persistence hazard they introduce.
///
/// Meeting capture used to append one paragraph per 30-second window per audio source,
/// which glued several people's contributions into a single labelled block. Turns split
/// that on silence whisper actually measured. Three things in that sentence can break
/// quietly, and all three are pinned here:
///
///   * **The unit of whisper's timestamps.** `whisper.h` does not document it - the
///     header says only "Get the start and end time of the specified segment" - so
///     `LocalWhisperProvider.secondsPerTick` encodes an upstream convention. Nothing
///     would crash if a future whisper release changed it; transcripts would just
///     silently stop splitting, or split on every segment.
///   * **The gap rule itself**, including what happens on the malformed timings whisper
///     genuinely emits on repetition loops.
///   * **`Note.speakers` being optional.** A non-optional property with a default value
///     still fails to decode when the key is *absent*, and `NoteStore.load` responds to
///     an undecodable file by moving the user's whole notes file aside. So a note
///     written before this feature existed must still load.
///
/// Deliberately no test drives `MeetingSession` end to end: it needs a live microphone,
/// a ScreenCaptureKit stream and a loaded 190 MB whisper model. What is testable is the
/// pure logic between them, which is where the bugs would live.
@Suite("Meeting turns and speaker labels")
struct MeetingTurnTests {

    // MARK: - Helpers

    /// A segment with whisper's own leading space, the way real output arrives.
    private func segment(_ start: TimeInterval, _ end: TimeInterval, _ text: String) -> TimedSegment {
        TimedSegment(start: start, end: end, text: text)
    }

    // MARK: - The timestamp unit

    @Test("whisper's segment timestamps are read as hundredths of a second")
    func timestampUnit() {
        // The contract `TurnSegmenter` is calibrated against. whisper.cpp's own
        // `to_timestamp` multiplies these by 10 to reach milliseconds, so one tick is
        // 10 ms and 100 ticks is a second.
        #expect(LocalWhisperProvider.secondsPerTick == 0.01)
        #expect(LocalWhisperProvider.seconds(fromTicks: 0) == 0)
        #expect(LocalWhisperProvider.seconds(fromTicks: 100) == 1.0)
        #expect(LocalWhisperProvider.seconds(fromTicks: 3_000) == 30.0)
        // A 30-second window is whisper's own decode length and meeting capture's
        // window size, so this is the largest value the meeting path should ever see.
        #expect(LocalWhisperProvider.seconds(fromTicks: 250) == 2.5)
    }

    @Test("Misreading the unit as milliseconds degrades to one turn, rather than to nonsense")
    func wrongUnitFailsSafe() {
        // The claim documented on `secondsPerTick`: too small a conversion factor makes
        // every gap look tiny, so the segmenter emits one turn per window - which is
        // exactly the single-blob behaviour turns replaced. A silent regression to the
        // old output beats fabricated turn boundaries, and this pins which direction the
        // failure goes.
        let ticks: [(Int64, Int64, String)] = [(0, 200, " Morning."), (900, 1_100, " Shall we start?")]
        let asMilliseconds = ticks.map {
            segment(TimeInterval($0.0) * 0.001, TimeInterval($0.1) * 0.001, $0.2)
        }
        #expect(TurnSegmenter.turns(from: asMilliseconds).count == 1)

        // The same audio read correctly: a 7-second silence between two remarks.
        let asCentiseconds = ticks.map {
            segment(LocalWhisperProvider.seconds(fromTicks: $0.0),
                    LocalWhisperProvider.seconds(fromTicks: $0.1),
                    $0.2)
        }
        #expect(TurnSegmenter.turns(from: asCentiseconds).count == 2)
    }

    // MARK: - Gap detection

    @Test("Abutting segments are one turn, not one turn each")
    func abuttingSegmentsMerge() {
        // whisper cuts a window into segments wherever its decoder emitted a timestamp
        // token, usually per sentence. Those cuts are not pauses, so treating every
        // segment as a turn would put a speaker label on every sentence.
        let turns = TurnSegmenter.turns(from: [
            segment(0, 2.5, " We should ship it."),
            segment(2.5, 5.0, " The tests are green."),
            segment(5.0, 7.5, " I'll cut the build."),
        ])

        #expect(turns.count == 1)
        #expect(turns.first?.text == "We should ship it. The tests are green. I'll cut the build.")
        #expect(turns.first?.start == 0)
        #expect(turns.first?.end == 7.5)
    }

    @Test("A silence longer than the threshold splits the turn")
    func silenceSplitsTurns() {
        let turns = TurnSegmenter.turns(from: [
            segment(0, 2.0, " Does anyone object?"),
            // 3 seconds of nothing: somebody was deciding whether to answer.
            segment(5.0, 6.5, " Not from me."),
        ])

        #expect(turns.count == 2)
        #expect(turns.map(\.text) == ["Does anyone object?", "Not from me."])
        #expect(turns[0].start == 0)
        #expect(turns[0].end == 2.0)
        #expect(turns[1].start == 5.0)
        #expect(turns[1].end == 6.5)
    }

    @Test("The threshold is inclusive, and a gap just under it does not split")
    func thresholdBoundary() {
        // Pins the comparison as `>=`, so the documented 1.2 s is the value that splits
        // rather than the largest value that does not.
        let exactly = TurnSegmenter.turns(from: [
            segment(0, 1.0, " One."),
            segment(1.0 + TurnSegmenter.silenceGap, 3.0, " Two."),
        ])
        #expect(exactly.count == 2)

        let justUnder = TurnSegmenter.turns(from: [
            segment(0, 1.0, " One."),
            segment(1.0 + TurnSegmenter.silenceGap - 0.01, 3.0, " Two."),
        ])
        #expect(justUnder.count == 1)
    }

    @Test("A caller-supplied gap overrides the default")
    func customGap() {
        let segments = [segment(0, 1.0, " One."), segment(2.0, 3.0, " Two.")]
        #expect(TurnSegmenter.turns(from: segments, separatedBy: 0.5).count == 2)
        #expect(TurnSegmenter.turns(from: segments, separatedBy: 5.0).count == 1)
    }

    // MARK: - Malformed whisper output

    @Test("A silence whisper covered with a text-free segment still splits the turn")
    func silenceInsideAnEmptySegmentStillSplits() {
        // This test found a real bug in the first version of `TurnSegmenter`, which
        // timed gaps between consecutive segment *boundaries*. whisper sometimes covers
        // a silence with a text-free segment of its own, and then consecutive segments
        // abut perfectly - there is no gap between them, because the silence is inside
        // one. Eight seconds of nothing merged into a single turn. Timing from the last
        // *word* instead is what makes both shapes work.
        let turns = TurnSegmenter.turns(from: [
            segment(0, 1.0, " Right, that's agreed."),
            segment(1.0, 9.0, "  "),
            segment(9.0, 10.5, " Next item."),
        ])

        #expect(turns.count == 2)
        #expect(turns.map(\.text) == ["Right, that's agreed.", "Next item."])
        // Not 1.0: the silence must not be attributed to the speaker who broke it.
        #expect(turns[1].start == 9.0)
    }

    @Test("Whitespace-only output produces no turns at all")
    func whitespaceOnlyIsNotATurn() {
        // Feeds straight into `MeetingSession`'s silence handling: a window that
        // produced nothing must be consumed as silence, not appended as an empty
        // labelled paragraph.
        #expect(TurnSegmenter.turns(from: []).isEmpty)
        #expect(TurnSegmenter.turns(from: [segment(0, 30, "")]).isEmpty)
        #expect(TurnSegmenter.turns(from: [segment(0, 30, "   \n  ")]).isEmpty)
    }

    @Test("Non-monotonic timings neither crash nor produce a backwards turn")
    func nonMonotonicTimings() {
        // Real whisper behaviour on a repetition loop: a segment that ends before it
        // starts, and one that starts before its predecessor finished. Turn ends are a
        // running maximum precisely so a turn's span cannot go backwards.
        let turns = TurnSegmenter.turns(from: [
            segment(0, 5.0, " The deploy is stuck."),
            segment(4.0, 2.0, " The deploy is stuck."),
            segment(4.5, 6.0, " Rolling back now."),
        ])

        #expect(turns.count == 1)
        let turn = turns[0]
        #expect(turn.end >= turn.start)
        #expect(turn.end == 6.0)
    }

    // MARK: - Reassembling whisper's text

    @Test("Segments are concatenated without inserting or doubling spaces")
    func joiningPreservesWhispersOwnSpacing() {
        // whisper puts the space at the *start* of each segment. Joining on " " would
        // double them; joining trimmed segments would run words together. This is the
        // behaviour the dictation path had before turns existed, and it must not change
        // - `transcribe` is now a join over the timed path.
        let segments = [segment(0, 1, " Ship"), segment(1, 2, " it"), segment(2, 3, " today.")]
        #expect(LocalWhisperProvider.joined(segments) == "Ship it today.")
        #expect(LocalWhisperProvider.joined([]) == "")
        // Leading and trailing whitespace is trimmed, interior spacing is not touched.
        #expect(LocalWhisperProvider.joined([segment(0, 1, "  Hello  ")]) == "Hello")
    }

    @Test("A turn's text is trimmed but keeps the spacing between its segments")
    func turnTextIsTrimmedNotCollapsed() {
        let turns = TurnSegmenter.turns(from: [
            segment(0, 1, " Two"), segment(1, 2, " words"),
        ])
        #expect(turns.first?.text == "Two words")
    }

    // MARK: - Speaker labels

    @Test("The role subscript reads and writes the matching field")
    func speakerSubscript() {
        var speakers = MeetingSpeakers.default
        #expect(speakers[.you] == "You")
        #expect(speakers[.others] == "Others")

        speakers[.others] = "Ana"
        #expect(speakers.others == "Ana")
        // Writing one role must not disturb the other.
        #expect(speakers.you == "You")
    }

    @Test("Relabelling rewrites turn headings and leaves the speech alone")
    func relabelIsLineAnchored() {
        // The reason this is anchored rather than a global replace: "**Others:**" can
        // occur inside what somebody said. Rewriting that would be editing the user's
        // transcript rather than relabelling it.
        let body = """
        # Meeting - Aug 17, 2:15 PM

        **Others:** Morning, shall we start?

        **You:** Yes. The heading we write is **Others:** for the call audio.
        """

        let renamed = MeetingTranscript.relabel(body, from: "Others", to: "Ana")

        #expect(renamed.contains("**Ana:** Morning, shall we start?"))
        // Mid-line occurrence survives untouched.
        #expect(renamed.contains("we write is **Others:** for the call audio"))
        #expect(renamed.contains("**You:** Yes."))
    }

    @Test("Relabelling finds headings after CRLF as well as LF")
    func relabelHandlesWindowsLineEndings() {
        // The trap documented on `Note.derivedTitle`: Swift treats CRLF as one grapheme
        // cluster, so `split(separator: "\n")` never matches it. A body with pasted
        // Windows line endings would have had every heading but the first missed. ICU's
        // multiline `^` matches all three conventions, and - unlike splitting and
        // rejoining - it leaves the user's own line endings as they were.
        let body = "**You:** first\r\n\r\n**You:** second\r\n"
        let renamed = MeetingTranscript.relabel(body, from: "You", to: "Sam")

        #expect(renamed == "**Sam:** first\r\n\r\n**Sam:** second\r\n")
        #expect(!renamed.contains("**You:**"))
    }

    @Test("Names containing regex or template metacharacters are treated as text")
    func relabelEscapesMetacharacters() {
        // Both directions have to be escaped. An unescaped *pattern* would make
        // "C++ (Ana)" match nothing at best; an unescaped *template* would let "$1" in
        // the new name expand to a capture group.
        let awkward = MeetingTranscript.relabel(
            "**C++ (Ana):** it compiles\n", from: "C++ (Ana)", to: "Ana"
        )
        #expect(awkward == "**Ana:** it compiles\n")

        let templateish = MeetingTranscript.relabel(
            "**You:** hello\n", from: "You", to: "$1 \\2"
        )
        #expect(templateish == "**$1 \\2:** hello\n")
    }

    @Test("Relabelling is a no-op when there is nothing to rename")
    func relabelNoOps() {
        let body = "**You:** hello\n"
        #expect(MeetingTranscript.relabel(body, from: "You", to: "You") == body)
        #expect(MeetingTranscript.relabel(body, from: "Others", to: "Ana") == body)
        #expect(MeetingTranscript.relabel(body, from: "", to: "Ana") == body)
    }

    @Test("A turn renders as a bold heading followed by the text")
    func turnLineShape() {
        // Pinned because `relabel` has to be able to find what `line` wrote, and
        // `Note.derivedTitle` has to survive a body that starts with one.
        #expect(MeetingTranscript.line("You", "hello") == "**You:** hello")
        #expect(MeetingTranscript.heading("Ana") == "**Ana:**")
    }

    @Test("The call heard back through the speakers is not the user's turn")
    func echoIsDropped() {
        let others = "Morning everyone. Let's start with the launch dates, Priya can you share your screen? Thanks."
        // Speaker bleed, transcribed a little differently from the clean stream.
        #expect(MeetingTranscript.isEcho("Let's start with the launch date. Priya, can you share your screen.", of: others))
        #expect(MeetingTranscript.isEcho("Thanks.", of: others))
        // A real reply shares common words, not word pairs.
        #expect(!MeetingTranscript.isEcho("Sure, I can share the screen with everyone.", of: others))
        #expect(!MeetingTranscript.isEcho("Yes.", of: others))
        #expect(!MeetingTranscript.isEcho("Anything at all", of: ""))
        #expect(!MeetingTranscript.isEcho("", of: others))
    }

    @Test("Turns from both streams come out in the order they were said, once both are past them")
    func turnsInterleaveByTime() {
        var pending: [(at: TimeInterval, turn: String)] = [(12, "You: second"), (3, "Others: first"), (31, "Others: later")]
        let ready = MeetingTranscript.release(&pending, before: 30)
        #expect(ready.map(\.turn) == ["Others: first", "You: second"])
        #expect(pending.map(\.turn) == ["Others: later"])
        #expect(MeetingTranscript.release(&pending, before: .infinity).map(\.turn) == ["Others: later"])
        #expect(pending.isEmpty)
    }

    @Test("Whisper's captions for non-speech never become a turn")
    func nonSpeechCaptionsAreNotTurns() {
        for caption in ["[BLANK_AUDIO]", "[GASP]", "(music)", "[The following transcript may mention a woman.]"] {
            #expect(!TranscriptText.isUsable(caption), "\(caption)")
        }
        #expect(TranscriptText.isUsable("We are back [laughs] for the last item."))
        #expect(TranscriptText.isUsable("[Music] Welcome back everyone [Music]"))
        #expect(!TranscriptText.isUsable("[Music] (applause) [Music]"))
        #expect(TranscriptText.isUsable("Let's go."))
    }

    // MARK: - Persistence

    /// Matches `NoteStore.writeToDisk()`.
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(NoteDateFormat.fractional.string(from: date))
        }
        return encoder
    }

    /// Matches `NoteStore.load()`.
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = NoteDateFormat.fractional.date(from: text) { return date }
            if let date = NoteDateFormat.whole.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Unrecognised date: \(text)"
            )
        }
        return decoder
    }

    @Test("Speaker labels survive a round trip through notes.json")
    func speakersRoundTrip() throws {
        let note = Note(
            body: "**Ana:** hello",
            source: .meeting,
            speakers: MeetingSpeakers(you: "Sam", others: "Ana")
        )
        let decoded = try decoder().decode(Note.self, from: try encoder().encode(note))

        #expect(decoded.speakers == MeetingSpeakers(you: "Sam", others: "Ana"))
        #expect(decoded.speakerLabels.others == "Ana")
    }

    @Test("A note written before speaker labels existed still decodes")
    func legacyNotesWithoutSpeakersStillLoad() throws {
        // The hazard that made `Note.speakers` optional. A non-optional property with a
        // default initialiser value still fails to decode when the key is *missing*  - 
        // and `NoteStore.load` treats one undecodable record as an undecodable file, so
        // it would have moved every note the user owns aside on first launch after
        // upgrading. Verified against a record with no `speakers` key at all.
        let legacy = Data("""
        [{
          "id": "1B7C6A1E-0000-4000-8000-000000000001",
          "title": "Meeting - Aug 11, 2:15 PM",
          "body": "**You:** we shipped it",
          "created": "2026-08-11T14:15:00.000Z",
          "modified": "2026-08-11T14:15:00.000Z",
          "tags": [],
          "source": "meeting",
          "titleIsCustom": false
        }]
        """.utf8)

        let notes = try decoder().decode([Note].self, from: legacy)
        #expect(notes.count == 1)
        #expect(notes[0].speakers == nil)
        // And it reads as the defaults rather than as empty labels, so an old meeting
        // note's rename fields are populated instead of blank.
        #expect(notes[0].speakerLabels == MeetingSpeakers.default)
    }

    @Test("Notes with no speaker labels do not carry the key on disk")
    func absentSpeakersAreNotEncoded() throws {
        // Every dictated and typed note in the file would otherwise grow a
        // `"speakers": null` line. `notes.json` doubles as the recovery copy
        // (`notes.previous.json`, kept readable by hand on purpose), so noise in it has
        // a cost beyond size.
        let json = String(
            data: try encoder().encode(Note(body: "typed", source: .typed)), encoding: .utf8
        )
        #expect(json?.contains("speakers") == false)
    }
}
