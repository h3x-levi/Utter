import Foundation

/// Where a turn's text goes.
enum CaptureDestination: Equatable {
    /// Typed into the frontmost app.
    case app
    case note
    /// A private companion memory: never typed, never in history.
    case memory
}

/// The text stages between transcription and delivery, each injected so a test can see it run.
struct DictationPipeline {
    var polish: (String) async -> String
    var voiceCommand: (String) -> VoiceAction?
    var correct: (String) -> String
    var expandSnippets: (String) -> String
    var formatForApp: (String) -> String
    var detectLanguage: (String) -> String?

    /// The voice command to run instead of delivering, if any. In a note only the routing
    /// commands count: the editing ones are keystrokes for an app the text is not going to, and
    /// `checkVoiceCommand` matches suffixes, so dropping them would delete the user's sentence.
    func command(in text: String, for destination: CaptureDestination) -> VoiceAction? {
        guard destination != .memory, let action = voiceCommand(text) else { return nil }
        return destination == .note && !action.isNoteRouting ? nil : action
    }

    /// Dictionary repair, then snippets, then the frontmost app's formatting, which is only for
    /// text typed into it.
    func prepare(_ text: String, for destination: CaptureDestination) -> String {
        let fixed = expandSnippets(correct(text))
        return destination == .app ? formatForApp(fixed) : fixed
    }
}

extension DictationPipeline {
    static func live(_ userData: UserData = .shared,
                     context: @escaping () -> AppContextType = AppContext.detect) -> DictationPipeline {
        DictationPipeline(
            polish: { text in
                await Signposts.interval("Polish") {
                    await SentencePolish.polish(text, context: {
                        let preceding = await SurroundingContext.capture().trailingFragment
                        let tone = await MainActor.run {
                            userData.perAppToneEnabled ? AppContext.tone(for: context()) : nil
                        }
                        return (preceding, tone)
                    }, deadline: SentencePolish.dictationDeadline)
                }
            },
            voiceCommand: userData.checkVoiceCommand,
            correct: { DictionaryCorrector.correct($0, using: userData.dictionaryWords) },
            expandSnippets: userData.applySnippets,
            formatForApp: { AppContext.adjustFormatting($0, context: context()) },
            detectLanguage: { LanguageDetector.detect($0)?.displayName }
        )
    }
}
