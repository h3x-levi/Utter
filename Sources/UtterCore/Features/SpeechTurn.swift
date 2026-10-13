import Foundation

/// One timed piece of transcript, exactly as whisper produced it.
///
/// `start` and `end` are seconds from the beginning of the audio buffer that was
/// handed to whisper - **not** from the beginning of the meeting. Meeting capture
/// transcribes in rolling 30-second windows, so each window's timings begin again
/// at zero. Nothing here stitches them onto a meeting-wide clock; `MeetingSession`
/// explains why that would be a claim the app cannot back.
struct TimedSegment: Equatable {
    let start: TimeInterval
    let end: TimeInterval

    /// The segment's text, deliberately **untrimmed**.
    ///
    /// whisper emits a leading space on most segments and joining them is a plain
    /// concatenation, so trimming here would glue the last word of one segment to
    /// the first word of the next.
    let text: String
}

/// Contiguous speech from one audio source, bounded by silence at both ends.
///
/// A turn is a *timing* fact and nothing more: whisper reported speech, then a gap
/// long enough to be a real pause, then speech again. It says nothing about who was
/// talking. Two turns in a row on the same source may be one person drawing breath
/// or two people taking it in turns, and there is no way to tell from the timings  - 
/// which is why `MeetingSession` labels every turn from a source identically rather
/// than numbering them.
struct SpeechTurn: Equatable {
    let start: TimeInterval
    let end: TimeInterval
    /// Trimmed and ready to render.
    let text: String
}

/// Groups whisper's segments into turns at real silences.
///
/// whisper segments a 30-second window on its own terms - usually one segment per
/// sentence-ish run, cut wherever its decoder emitted a timestamp token. Those cuts
/// are not pauses: consecutive segments normally abut, because whisper is splitting
/// continuous speech. A *gap* between one segment's end and the next one's start is
/// different - it is measured silence, and that is the only thing here that a turn
/// boundary is drawn from.
enum TurnSegmenter {

    /// How much silence separates two turns.
    ///
    /// 1.2 s sits above the pauses inside a sentence and below the pause somebody
    /// leaves before replying. Whisper's own punctuation model already works at the
    /// few-hundred-millisecond scale (see `SentencePolish`, which exists precisely
    /// because a 400 ms breath is indistinguishable from a clause end), so anything
    /// near that would split mid-thought.
    static let silenceGap: TimeInterval = 1.2

    /// Group `segments` into turns, splitting wherever at least `gap` seconds passed
    /// without a word being said.
    ///
    /// Measured from the end of the last segment that **carried text** to the start of
    /// the next one that does - not from the end of the previous segment. The
    /// difference is not academic, and a test caught it: whisper sometimes covers a
    /// silence with a text-free segment of its own, and then there is no gap *between*
    /// segments at all because the silence is inside one. Timing the gap between
    /// segment boundaries merged an eight-second pause into a single turn; timing it
    /// between words handles both shapes with one comparison.
    ///
    /// That also makes the two things whisper genuinely gets wrong on real audio
    /// harmless:
    ///
    ///   * **Empty segments** need no special case. They contribute no words, so they
    ///     neither open a turn nor move the clock the next gap is measured from.
    ///   * **Non-monotonic timings.** On a repetition loop whisper can emit `t1`
    ///     before `t0`, or a segment starting before its predecessor ended. A negative
    ///     gap simply fails the split test, and both the last-word clock and each
    ///     turn's `end` are running maxima, so neither can go backwards.
    static func turns(
        from segments: [TimedSegment],
        separatedBy gap: TimeInterval = silenceGap
    ) -> [SpeechTurn] {
        var turns: [SpeechTurn] = []

        // The open turn. `text` being empty is what "no turn open" means.
        var start: TimeInterval = 0
        var end: TimeInterval = 0
        var text = ""

        /// End of the last segment that carried words. `nil` before the first one, so
        /// leading silence never counts as a gap.
        var lastWordEnd: TimeInterval?

        func closeTurn() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                turns.append(SpeechTurn(start: start, end: end, text: trimmed))
            }
            text = ""
        }

        for segment in segments {
            guard !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            if let lastWordEnd, segment.start - lastWordEnd >= gap {
                closeTurn()
            }

            if text.isEmpty {
                start = segment.start
                end = segment.end
            } else {
                end = max(end, segment.end)
            }
            text += segment.text
            lastWordEnd = max(lastWordEnd ?? segment.end, segment.end)
        }
        closeTurn()

        return turns
    }
}
