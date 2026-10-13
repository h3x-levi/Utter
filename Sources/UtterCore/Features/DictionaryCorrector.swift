import Foundation

/// Corrects transcription output against the user's custom dictionary.
///
/// This is the *second* of two passes. `SpeechBias` now also conditions Whisper
/// with an `initial_prompt` before decoding, which this file previously argued
/// against - the objection was to an unbounded raw word list, and it still stands
/// for that; see `SpeechBias` for the budget and phrasing that make biasing safe.
///
/// Both passes are kept because they fail in opposite directions. Biasing prevents
/// an unfamiliar name from being split into common words in the first place, but
/// cannot help a term the user never added. This pass repairs a near-miss whatever
/// its cause, but only while the word is still recognisable as one - once
/// "Kubernetes" has become "cooper netties", the token boundaries are gone and edit
/// distance can no longer find it.
///
/// Each token in the result is compared to every dictionary word by
/// case-insensitive Levenshtein distance, and a token that is a close-but-not-exact
/// match is replaced with the canonical spelling.
///
/// The matcher is deliberately conservative - it only fires on small edit distances
/// scaled to word length - so ordinary words are never rewritten into jargon.
enum DictionaryCorrector {

    /// Apply dictionary corrections to `text` using the given canonical words.
    /// Returns `text` unchanged when there are no dictionary words.
    static func correct(_ text: String, using words: [String]) -> String {
        let canonical = words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !canonical.isEmpty, !text.isEmpty else { return text }

        // Map lowercased → canonical so an exact case-insensitive match can be
        // rewritten to the dictionary's intended spelling/casing (e.g. "kubernetes"
        // → "Kubernetes", "macos" → "macOS"). Enforcing casing is a primary reason to
        // add a term to the dictionary. Later entries win on collision.
        var canonicalByLower: [String: String] = [:]
        for word in canonical { canonicalByLower[word.lowercased()] = word }

        // Walk the string token by token, preserving all non-letter runs
        // (spaces, punctuation, newlines) exactly as they appear.
        var result = ""
        var wordBuffer = ""

        func flushWord() {
            guard !wordBuffer.isEmpty else { return }
            result += bestReplacement(
                for: wordBuffer,
                canonical: canonical,
                canonicalByLower: canonicalByLower
            )
            wordBuffer = ""
        }

        for ch in text {
            if ch.isLetter || ch == "'" {
                wordBuffer.append(ch)
            } else {
                flushWord()
                result.append(ch)
            }
        }
        flushWord()
        return result
    }

    /// Decide the replacement for a single transcribed word.
    /// Returns the original token unless a dictionary word is a confident near-match.
    private static func bestReplacement(
        for token: String,
        canonical: [String],
        canonicalByLower: [String: String]
    ) -> String {
        let lower = token.lowercased()

        // Exact case-insensitive match → enforce the dictionary's canonical spelling
        // (so "kubernetes"/"KUBERNETES" both become "Kubernetes"). If the token already
        // equals the canonical form, this is a no-op.
        if let canonicalForm = canonicalByLower[lower] { return canonicalForm }

        // Fuzzy matching is only safe for long, distinctive tokens. Short words
        // (≤5 chars) are within one edit of countless common words - e.g. a dictionary
        // name "Jon" would rewrite "job"/"son", "Ana" would rewrite "and". So short
        // tokens get ONLY the exact-casing correction above; we never fuzzy-match them.
        guard token.count >= minFuzzyLength else { return token }

        var bestWord: String?
        var bestDistance = Int.max

        for word in canonical {
            let wl = word.lowercased()
            // Only fuzzy-match against dictionary words that are themselves long enough
            // to be distinctive, and of comparable length to the token.
            guard wl.count >= minFuzzyLength else { continue }
            if abs(wl.count - lower.count) > maxDistance(forLength: max(wl.count, lower.count)) {
                continue
            }
            let d = levenshtein(lower, wl)
            if d < bestDistance {
                bestDistance = d
                bestWord = word
            }
        }

        guard let match = bestWord else { return token }

        // Confidence gate: the edit distance must be within the length-scaled budget,
        // and must be a real improvement (distance > 0 handled above via exact check).
        let budget = maxDistance(forLength: max(match.count, token.count))
        guard bestDistance <= budget else { return token }

        // Preserve the original token's leading capitalization so a corrected word at
        // the start of a sentence still reads naturally.
        return matchCase(of: token, to: match)
    }

    /// Minimum token length eligible for fuzzy (edit-distance) matching. Below this,
    /// only exact case-insensitive correction is applied, because short words collide
    /// with too many common English words at edit distance 1.
    private static let minFuzzyLength = 6

    /// Allowed edit distance scales with word length so long, distinctive names get
    /// more tolerance than short words. 6-9 chars → 2, 10+ → 3. (Shorter tokens never
    /// reach fuzzy matching; see minFuzzyLength.)
    private static func maxDistance(forLength length: Int) -> Int {
        switch length {
        case 0...5: return 1
        case 6...9: return 2
        default: return 3
        }
    }

    /// Apply the capitalization pattern of `source` to `target`.
    /// Only mirrors the common cases (all-lower, Titlecase, ALL-CAPS); otherwise
    /// returns the canonical spelling verbatim so intentional casing (e.g. "Kubernetes")
    /// is preserved.
    private static func matchCase(of source: String, to target: String) -> String {
        if source == source.uppercased() && source.count > 1 {
            return target.uppercased()
        }
        if let first = source.first, first.isUppercase {
            return target.prefix(1).uppercased() + target.dropFirst()
        }
        return target
    }

    /// Standard iterative Levenshtein edit distance (two-row variant).
    private static func levenshtein(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let aChars = Array(a), bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }

        var previous = Array(0...bChars.count)
        var current = [Int](repeating: 0, count: bChars.count + 1)

        for i in 1...aChars.count {
            current[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,        // deletion
                    current[j - 1] + 1,     // insertion
                    previous[j - 1] + cost  // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[bChars.count]
    }
}
