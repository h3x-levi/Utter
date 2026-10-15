import Foundation

/// Builds the `initial_prompt` string that conditions Whisper before decoding.
///
/// Whisper is an autoregressive model: it predicts each token given the audio *and*
/// the text so far. `initial_prompt` seeds that text, so words appearing in it
/// become cheaper for the decoder to produce. This is the only supported way to
/// bias recognition toward vocabulary the model would otherwise mis-hear - proper
/// nouns, product names, internal jargon.
///
/// It is better than fixing the output afterwards, because `DictionaryCorrector`
/// can only repair a word that still looks or sounds like the original. Once Whisper
/// turns an unfamiliar name into unrelated words, nothing can find it. Biasing
/// prevents that split from happening.
///
/// ## Why this is deliberately conservative
///
/// A prompt is not a free win. Whisper treats it as *preceding transcript*, so a
/// badly built one causes real regressions:
///
///   * **Echoing.** On near-silent audio the decoder can simply continue the
///     prompt, emitting the word list as if it had been spoken.
///   * **Style transfer.** The prompt's register bleeds into the output - a prompt
///     written as a bare comma-list encourages comma-spliced transcripts, which
///     is exactly the punctuation problem `SentencePolish` exists to fix.
///   * **Crowding.** The prompt shares a fixed token budget with the decoding
///     context. An overlong one costs accuracy everywhere to help a few words.
///
/// So: a natural-language sentence rather than a raw list, a hard character
/// budget, and only terms the user explicitly added. `DictionaryCorrector` still
/// runs afterwards as a backstop - the two are complementary, not redundant.
enum SpeechBias {

    /// Character ceiling for the whole prompt.
    ///
    /// Whisper reserves `n_text_ctx / 2` tokens for the prompt - 224 on the models
    /// Utter ships. At roughly 4 characters per English token that is ~900
    /// characters, but the budget is shared with the audio's own decoding context,
    /// and an over-long prompt is the documented cause of the crowding regression
    /// above. 420 keeps well clear while still fitting a useful vocabulary.
    private static let maxCharacters = 420

    /// Terms shorter than this are skipped.
    ///
    /// Whisper already gets common short words right, so biasing them spends
    /// budget for nothing - and a short entry is the most likely to distort a
    /// homophone the user *did* say ("Ana" pulling in "and").
    private static let minTermLength = 3

    /// Build the prompt for the next utterance. Empty when there is nothing
    /// useful to say, which correctly disables biasing.
    @MainActor
    static func current() async -> String {
        let data = UserData.shared
        guard data.speechBiasEnabled else { return "" }

        // Dictionary words first: the user chose them, so they get budget priority
        // over anything inferred from the document.
        var terms = biasTerms(from: data.dictionaryWords)

        // Then proper nouns already on screen. These cover the case the dictionary
        // cannot - a colleague's name or project that the user never thought to add,
        // but which is sitting three lines above the cursor.
        let context = await SurroundingContext.capture()
        if !context.isEmpty {
            let known = Set(terms.map { $0.lowercased() })
            for noun in biasTerms(from: context.properNouns)
            where !known.contains(noun.lowercased()) {
                terms.append(noun)
            }
        }

        guard !terms.isEmpty else { return "" }
        return prompt(terms: terms)
    }

    /// Select and order the terms worth spending prompt budget on.
    static func biasTerms(from words: [String]) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []

        for word in words {
            let term = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard term.count >= minTermLength else { continue }
            // Case-insensitive dedupe: the prompt carries the user's canonical
            // spelling, so two casings of one word would waste budget.
            let key = term.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            terms.append(term)
        }

        return terms
    }

    /// Compose the prompt sentence, truncated to the character budget.
    ///
    /// Phrased as prose, and ended with a full stop, for two reasons the bare list
    /// gets wrong: the sentence frame makes the terms read as *mentioned*
    /// vocabulary rather than a transcript to continue, and the terminal full stop
    /// means the decoder starts a fresh sentence instead of extending a comma run.
    static func prompt(terms: [String]) -> String {
        let opening = "The following transcript may mention "
        let closing = "."

        var included: [String] = []
        var length = opening.count + closing.count

        for term in terms {
            // ", " between entries, except before the first.
            let cost = term.count + (included.isEmpty ? 0 : 2)
            guard length + cost <= maxCharacters else { break }
            included.append(term)
            length += cost
        }

        guard !included.isEmpty else { return "" }
        return opening + included.joined(separator: ", ") + closing
    }
}
