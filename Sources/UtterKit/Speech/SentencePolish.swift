import Foundation

/// Repunctuates a raw transcript into grammatical sentences.
///
/// Whisper predicts punctuation from *prosody* - pitch, intonation, pause length  - 
/// not from grammar. A 400ms breath in the middle of a clause and a 400ms breath
/// at the end of a thought are acoustically identical to it, so it emits a comma
/// for both. That is why dictating naturally produces long comma-spliced runs:
///
///     "it seems that it's having some issues with understanding accents Or
///      pronunciations Different dialects."
///
/// No amount of string manipulation fixes that, because deciding whether a pause
/// was a clause boundary or a sentence boundary requires understanding the
/// sentence. So this hands the transcript to Apple's on-device language model and
/// asks for punctuation only.
///
/// Two properties are deliberate:
///
///   * **It is a rewrite of punctuation, not of content.** The instructions forbid
///     changing words, because a dictation tool that quietly rephrases you is
///     worse than one that punctuates badly. The result is also length-checked
///     against the input, and discarded if the model rewrote too much.
///   * **It fails open.** If the model is unavailable, slow, or returns something
///     suspicious, the original transcript is used. Dictation never blocks on it.
enum SentencePolish {

    /// Upper bound on how much the text may change before the result is rejected.
    ///
    /// Punctuation edits move the character count by a few percent. A model that
    /// summarised, expanded, or answered the text instead of punctuating it will
    /// blow past this, and that output must never reach the user's document.
    private static let maxLengthDrift = 0.25

    /// Below this, there is nothing to fix: a handful of words has no clause
    /// structure to get wrong, and the round trip would only add latency.
    static let minimumWords = 4

    /// How long a dictation waits for polish after transcription ends before it is delivered
    /// unpolished.
    static let dictationDeadline: Duration = .milliseconds(900)

    static var isAvailable: Bool {
        UserData.shared.sentencePolishEnabled && LocalAIEngine.availability.isReady
    }

    /// Load the on-device model at key-down, so the polish after the turn starts warm.
    static func prewarm() {
        guard isAvailable else { return }
        LocalAIEngine.prewarm(instructions: instructions(precedingText: "", tone: nil))
    }

    /// Punctuate `text`, or return it unchanged.
    ///
    /// `context` supplies the fragment the dictation continues (it decides whether the first word
    /// is capitalised) and register guidance for the destination app. It is read inside the
    /// deadline, and only when the text will be polished. Past `deadline`, or on any failure, the
    /// original is returned and the model call is cancelled.
    static func polish(
        _ text: String,
        context: @escaping () async -> (precedingText: String, tone: String?) = { ("", nil) },
        deadline: Duration? = nil,
        isAvailable: Bool = SentencePolish.isAvailable,
        rewrite: @escaping (_ instructions: String, _ prompt: String) async throws -> String = LocalAIEngine.rewrite
    ) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailable, trimmed.split(whereSeparator: \.isWhitespace).count >= minimumWords else { return text }

        let attempt: () async -> String = {
            let (precedingText, tone) = await context()
            guard let result = try? await rewrite(instructions(precedingText: precedingText, tone: tone), trimmed)
            else { return text }
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return isPlausible(cleaned, original: trimmed) ? cleaned : text
        }
        guard let deadline else { return await attempt() }
        return await first(of: attempt, orAfter: deadline, fallback: text)
    }

    /// `work`'s result, or `fallback` once `deadline` passes. Does not wait for a cancelled `work`
    /// to wind down, so a model that ignores cancellation cannot hold the turn.
    static func first(of work: @escaping () async -> String, orAfter deadline: Duration,
                      fallback: String) async -> String {
        let results = AsyncStream<String> { continuation in
            let task = Task { continuation.yield(await work()); continuation.finish() }
            let timer = Task {
                try? await Task.sleep(for: deadline)
                continuation.yield(fallback)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
                timer.cancel()
            }
        }
        for await result in results { return result }
        return fallback
    }

    /// Reject output that looks like the model did something other than punctuate.
    ///
    /// Checked rather than trusted, because the failure mode is silently replacing
    /// the user's words in whatever app they were typing into.
    private static func isPlausible(_ candidate: String, original: String) -> Bool {
        guard !candidate.isEmpty else { return false }

        // Length drift: punctuation changes are small.
        let drift = abs(Double(candidate.count - original.count)) / Double(max(original.count, 1))
        guard drift <= maxLengthDrift else { return false }

        // The words themselves must survive. Compare lowercased, stripped of
        // punctuation, so only genuine word substitutions register.
        func words(_ s: String) -> [String] {
            s.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        }
        let before = words(original), after = words(candidate)
        guard !before.isEmpty else { return false }

        // Allow small edits (a dropped filler, a merged contraction) but not a
        // rewrite: at least 85% of the original words must still be present, in
        // order.
        var matched = 0, cursor = 0
        for word in before {
            if let idx = after[cursor...].firstIndex(of: word) {
                matched += 1
                cursor = idx + 1
            }
        }
        return Double(matched) / Double(before.count) >= 0.85
    }

    /// Assemble the instruction set for one call, with optional context.
    private static func instructions(precedingText: String, tone: String?) -> String {
        var result = baseInstructions

        // Both additions are appended rather than woven into the base text so the
        // worked example stays adjacent to the rules it demonstrates.
        if let tone {
            result += "\n\n" + tone
        }

        if !precedingText.isEmpty {
            // Capped: this is a hint about a sentence boundary, not material to
            // transform. A long tail would invite the model to edit it too.
            let hint = precedingText.count > 200
                ? String(precedingText.suffix(200))
                : precedingText
            result += """


                The text you are given continues immediately after this unfinished \
                text: "\(hint)"
                Use it only to decide whether the first word starts a new sentence \
                or continues that one. Never repeat, quote, or transform it.
                """
        }

        return result
    }

    /// The instruction set.
    ///
    /// Narrow on purpose. Every added capability is a chance for the model to
    /// "improve" the user's wording, which is not what a dictation tool is for.
    private static var baseInstructions: String {
        // Framed as a transformation function, with a worked example.
        //
        // The obvious phrasing ("you fix punctuation… reply with the corrected
        // text") failed in testing: the model answered the *content* instead  - 
        // "I'm sorry to hear that the speech recognition system is having
        // difficulty…" followed by an explanation, then the corrected text buried
        // at the end. Measured 188% length drift, which the plausibility check
        // rejected, so the user would simply have seen no improvement.
        //
        // Denying it a persona ("not an assistant"), naming the preambles to
        // avoid, and showing one input/output pair is what made it behave.
        """
        Repunctuate dictated text. Output only the result.

        You are a text transformation function, not an assistant. You never         explain, comment, apologise, or answer the content. You never write         "Here is" or "I'll" or any preamble. Your entire reply is the         transformed text.

        Transformation: the input came from a speech recogniser that guesses         punctuation from pauses. Fix only punctuation and capitalisation. Split         run-on sentences. Turn commas that should be full stops into full stops.         Delete commas that were only breaths. Capitalise sentence starts and         lowercase words wrongly capitalised mid-sentence. Join fragments that         belong to the preceding sentence.

        Never change, add, or remove a word. Never change tone or formality.

        Example input:
        i went to the store, it was closed, so i came back Later that evening
        Example output:
        I went to the store. It was closed, so I came back later that evening.
        """
    }
}
