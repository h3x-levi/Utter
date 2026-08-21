import Foundation
import NaturalLanguage

/// Detects the language of transcribed text on-device using Apple's NaturalLanguage
/// framework (no network, no cost).
///
/// The bundled Whisper model is English-only, so this detects the language of the
/// *result* purely to tag history entries and show the user what was recognized. It
/// does not change how audio is transcribed.
enum LanguageDetector {

    /// A detected language: the Whisper/BCP-47 style code plus a human-readable name.
    struct Result {
        /// Lowercased English language name matching UserData.supportedLanguages,
        /// e.g. "english", "spanish", "japanese". Empty when detection is uncertain.
        let name: String
        /// Localized display name for the UI, e.g. "English", "日本語".
        let displayName: String
    }

    /// Detect the dominant language of `text`. Returns nil for empty/too-short input
    /// or when the recognizer has no confident guess.
    static func detect(_ text: String) -> Result? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Very short strings (a word or two) are unreliable to classify.
        guard trimmed.count >= 4 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let language = recognizer.dominantLanguage else { return nil }

        // Require a minimum confidence so we don't mis-tag ambiguous short phrases.
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        if let top = hypotheses[language], top < 0.50 { return nil }

        let code = language.rawValue // e.g. "en", "es", "ja"
        let english = englishName(forCode: code)
        let display = Locale(identifier: "en_US")
            .localizedString(forLanguageCode: code)?.lowercased() ?? english

        return Result(
            name: english.isEmpty ? display : english,
            displayName: nativeDisplayName(forCode: code)
        )
    }

    /// Map a language code to the lowercased English name used by
    /// UserData.supportedLanguages, so a detected language can line up with the
    /// app's own language list. Falls back to the system's English name.
    private static func englishName(forCode code: String) -> String {
        let mapping: [String: String] = [
            "en": "english", "hi": "hindi", "es": "spanish", "fr": "french",
            "de": "german", "ja": "japanese", "zh": "chinese", "ko": "korean",
            "pt": "portuguese", "it": "italian", "nl": "dutch", "ru": "russian",
            "ar": "arabic", "tr": "turkish", "pl": "polish", "sv": "swedish",
            "ta": "tamil", "te": "telugu", "bn": "bengali", "mr": "marathi",
        ]
        if let name = mapping[code] { return name }
        return Locale(identifier: "en_US")
            .localizedString(forLanguageCode: code)?.lowercased() ?? ""
    }

    /// The language's name in its own locale (e.g. "日本語", "Español") for display.
    private static func nativeDisplayName(forCode code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized
            ?? Locale(identifier: "en_US").localizedString(forLanguageCode: code)?.capitalized
            ?? code.uppercased()
    }
}
