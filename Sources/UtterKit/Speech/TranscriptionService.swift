import Foundation
import os

/// Transcription provider protocol - swap implementations easily
protocol TranscriptionProvider {
    func transcribe(audioData: Data) async throws -> String
}

// MARK: - TranscriptionService (facade)

/// Main transcription service - delegates to the active provider.
/// Change provider in one line to swap between cloud/local/mock.
class TranscriptionService {

    private static let performanceLog = Logger(
        subsystem: "utter.dictation.app",
        category: "speech-performance"
    )

    /// The active provider. Change this to swap implementations.
    private let provider: TranscriptionProvider

    /// The on-device engine, when that's what we're using. Exposed so the UI can
    /// observe model load progress.
    var localProvider: LocalWhisperProvider? { provider as? LocalWhisperProvider }

    init(provider: TranscriptionProvider = LocalWhisperProvider()) {
        self.provider = provider
    }

    func transcribe(audioData: Data) async throws -> String {
        let requestStarted = DispatchTime.now().uptimeNanoseconds
        let raw = try await provider.transcribe(audioData: audioData)
        guard TranscriptText.isUsable(raw) else {
            Self.performanceLog.info("dictation produced no usable speech text")
            return ""
        }
        let formatted = Self.formatText(raw)

        // Gather destination context before polishing. Both degrade to "" / nil, so a
        // failure here costs the hint, not the transcription.
        let preceding = await SurroundingContext.capture().trailingFragment
        let tone = await MainActor.run { () -> String? in
            UserData.shared.perAppToneEnabled
                ? AppContext.tone(for: AppContext.detect())
                : nil
        }

        // Then repunctuate. Whisper guesses punctuation from pauses, so raw output
        // is comma-spliced; `formatText` can only fix mechanical things like
        // capitalisation. `SentencePolish` fails open, returning `formatted`
        // unchanged if the language model is unavailable or its output looks
        // like anything other than a repunctuation.
        let polishStarted = DispatchTime.now().uptimeNanoseconds
        let polished = await SentencePolish.polish(
            formatted, precedingText: preceding, tone: tone
        )
        let polishMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - polishStarted) / 1_000_000
        let totalMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - requestStarted) / 1_000_000
        Self.performanceLog.info(
            "dictation total_ms=\(totalMilliseconds, format: .fixed(precision: 1)) polish_ms=\(polishMilliseconds, format: .fixed(precision: 1)) words=\(polished.split(separator: " ").count)"
        )
        // Never log the transcript itself - a word count is enough to confirm the
        // pipeline produced text without recording what the user said.
        print("✅ Transcribed: \(polished.split(separator: " ").count) words")
        return polished
    }

    /// Transcribe one buffer into **turns** - contiguous speech separated by real
    /// silence - instead of one paragraph.
    ///
    /// Meeting capture uses this where dictation uses `transcribe`, and every
    /// difference is deliberate:
    ///
    ///   * **Turn boundaries come from whisper's timings, not from guesswork.** A
    ///     30-second window of a call routinely contains several separate
    ///     contributions, and gluing them into one paragraph under one label reads as
    ///     a single monologue. `TurnSegmenter` splits only on measured silence.
    ///   * **No surrounding-app context and no per-app tone.** `transcribe` reads the
    ///     frontmost text field to decide whether the first word continues an existing
    ///     sentence, because dictation is typed *into* that field. A meeting
    ///     transcript goes into a note, so that read would be meaningless here - and
    ///     it would be one accessibility-API call per turn rather than per utterance.
    ///   * **Polish runs per turn.** `SentencePolish` repunctuates one speaker's
    ///     run-on speech, which is exactly what a turn is; handing it a window
    ///     spanning several people's contributions gives it a harder problem than it
    ///     was built for. Turns under eight words skip it outright
    ///     (`SentencePolish.minimumWords`), and the whole thing is a no-op unless the
    ///     Mac has macOS 26 with Apple Intelligence on - so this is not the per-turn
    ///     round trip it looks like on most machines.
    ///
    /// Only the on-device whisper provider reports timings. Any other provider gets
    /// one turn spanning the whole buffer with a zero-length time span, which is
    /// honest: it does not know where the pauses were, so it does not claim to.
    func transcribeTurns(audioData: Data) async throws -> [SpeechTurn] {
        guard let local = localProvider else {
            let text = try await provider.transcribe(audioData: audioData)
            guard let turn = await Self.finish(text, start: 0, end: 0) else { return [] }
            return [turn]
        }

        let segments = try await local.transcribeTimed(audioData: audioData)
        var turns: [SpeechTurn] = []
        for turn in TurnSegmenter.turns(from: segments) {
            guard let finished = await Self.finish(turn.text, start: turn.start, end: turn.end)
            else { continue }
            turns.append(finished)
        }
        // Turn and word counts only - never the transcript. Meeting audio is other
        // people's speech, and the reason meeting capture is defensible at all is that
        // nothing but the note itself ever holds it.
        print("✅ Transcribed \(turns.count) turn(s), \(turns.reduce(0) { $0 + $1.text.split(separator: " ").count }) words")
        return turns
    }

    /// Format and repunctuate one turn's text. `nil` when nothing survives, so a turn
    /// whose text was only whitespace never reaches the note.
    private static func finish(
        _ raw: String,
        start: TimeInterval,
        end: TimeInterval
    ) async -> SpeechTurn? {
        let polished = await SentencePolish.polish(formatText(raw))
        let trimmed = polished.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return SpeechTurn(start: start, end: end, text: trimmed)
    }

    /// Warm up the provider so the first dictation isn't delayed by model load.
    /// No-op for providers that have nothing to prepare.
    ///
    /// Main-actor isolated because the active model tier is read from
    /// `ModelStore`, which lives on the main actor.
    @MainActor
    func preload() {
        (provider as? LocalWhisperProvider)?.preload()
    }

    /// Rebuild the speech context ahead of a transcription that is about to need it, for callers
    /// that know one is coming - i.e. the moment recording starts.
    ///
    /// Distinct from `preload` in that it announces nothing: `preload` is the launch-time load,
    /// where "loading" is true and worth showing, while this covers a rebuild after idle eviction,
    /// where the engine was capable throughout. See `LocalWhisperProvider.warmUp` for the measured
    /// numbers. A no-op for providers with nothing to prepare.
    @MainActor
    func warmUp() {
        (provider as? LocalWhisperProvider)?.warmUp()
    }

    /// Smart text formatting.
    /// Spoken-punctuation/list conversion is opt-in (Settings → Behavior) because
    /// words like "period" and "first" are genuinely ambiguous in normal speech.
    static func formatText(_ text: String, spokenPunctuation: Bool = UserData.shared.spokenPunctuationEnabled) -> String {
        guard !text.isEmpty else { return text }
        var result = text

        if spokenPunctuation {
            result = applySpokenFormatting(result)
        }

        // Capitalize "i"
        result = result.replacingOccurrences(of: " i ", with: " I ")
        result = result.replacingOccurrences(of: " i'", with: " I'")
        if result.hasPrefix("i ") { result = "I " + result.dropFirst(2) }

        // Capitalize first character
        if let first = result.first, first.isLetter {
            result = first.uppercased() + result.dropFirst()
        }

        // Capitalize after sentence enders
        var chars = Array(result)
        var i = 0
        while i < chars.count {
            if [".", "!", "?"].contains(chars[i]) {
                var j = i + 1
                while j < chars.count && (chars[j] == " " || chars[j] == "\n") { j += 1 }
                if j < chars.count && chars[j].isLetter {
                    chars[j] = Character(chars[j].uppercased())
                }
                i = j
            } else {
                i += 1
            }
        }
        result = String(chars)

        // Capitalize after list markers
        let listRegex = try? NSRegularExpression(pattern: "\\n(\\d+\\.\\s*)(\\w)")
        if let regex = listRegex {
            let ns = NSMutableString(string: result)
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 3 {
                    let r = match.range(at: 2)
                    ns.replaceCharacters(in: r, with: ns.substring(with: r).uppercased())
                }
            }
            result = ns as String
        }

        // Cleanup
        if result.hasPrefix("\n") { result = String(result.dropFirst()) }
        while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Convert spoken punctuation and list markers into symbols.
    /// All patterns are word-bounded and require the spoken word to stand alone
    /// (followed by whitespace or end of text), so "periods", "comma-separated",
    /// and "colonial" are never touched. Whisper often appends its own "." or ","
    /// after the spoken word, so an optional trailing one is consumed too.
    private static func applySpokenFormatting(_ text: String) -> String {
        var result = text

        // List markers need the dictated comma ("first, buy milk") AND must start a
        // sentence, so "first thing in the morning" and "at first, I was skeptical"
        // pass through untouched. Whisper punctuates, so "First, … Second, …"
        // arrives as sentence starts.
        let sentenceStart = "(?:^|(?<=[.!?:]\\s)|(?<=\\n))"
        let listPatterns: [(String, String)] = [
            ("first,\\s*", "\n1. "), ("number one,?\\s+", "\n1. "),
            ("second,\\s*", "\n2. "), ("number two,?\\s+", "\n2. "),
            ("third,\\s*", "\n3. "), ("number three,?\\s+", "\n3. "),
            ("fourth,\\s*", "\n4. "),
            ("fifth,\\s*", "\n5. "),
        ]
        for (pattern, replacement) in listPatterns {
            result = regexReplace(result, pattern: sentenceStart + pattern, with: replacement)
        }

        let punctuation: [(String, String)] = [
            ("\\s+comma,?(?=\\s)", ","),
            ("\\s+period\\.?(?=\\s|$)", "."),
            ("\\s+full stop\\.?(?=\\s|$)", "."),
            ("\\s+question mark[.?]?(?=\\s|$)", "?"),
            ("\\s+exclamation (?:mark|point)[.!]?(?=\\s|$)", "!"),
            ("\\s+new ?line\\.?(?:\\s+|$)", "\n"),
            ("\\s+colon(?=\\s)", ":"),
            ("\\s+semicolon(?=\\s)", ";"),
        ]
        for (pattern, replacement) in punctuation {
            result = regexReplace(result, pattern: pattern, with: replacement)
        }

        return result
    }

    private static func regexReplace(_ text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case invalidResponse
    case invalidURL
    case apiError(statusCode: Int, message: String)
    case invalidAudio
    case modelMissing(String)
    case modelLoadFailed(String)
    case inferenceFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Could not parse Whisper response"
        case .invalidURL: return "Invalid endpoint URL"
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        case .invalidAudio: return "Could not read the recorded audio"
        case .modelMissing(let name):
            return "Speech model \(name) is missing from the app bundle - reinstall Utter"
        case .modelLoadFailed(let name): return "Could not load speech model \(name)"
        case .inferenceFailed(let code): return "Transcription failed (code \(code))"
        }
    }
}
