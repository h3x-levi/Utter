import Foundation

/// A user-defined voice command that routes to the on-device model with custom prompts.
///
/// Stored in UserData and matched in AICommands.process(_:selectedText:) before
/// the built-in commands. Users author these from the AI Commands settings view.
package struct CustomAICommand: Identifiable, Codable, Equatable {
    /// Stable id used for list updates and deletion.
    package var id: UUID

    /// The phrase the user speaks (case-insensitive). Examples: "make it a commit", "tweet this".
    package var trigger: String

    /// Instruction to Claude on how it should behave. Example: "You are a translator. Return only the translation."
    package var systemPrompt: String

    /// Wraps the source text. Use {{text}} as the placeholder for the user's selection / last transcription.
    /// If empty, the source text is sent as-is.
    package var userPromptTemplate: String

    /// When true the AI output replaces the selected text (or undoes the last transcription and pastes).
    /// When false the output is appended after the cursor (like the built-in "reply to this").
    package var replacesSelection: Bool

    package init(
        id: UUID = UUID(),
        trigger: String,
        systemPrompt: String,
        userPromptTemplate: String = "",
        replacesSelection: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.systemPrompt = systemPrompt
        self.userPromptTemplate = userPromptTemplate
        self.replacesSelection = replacesSelection
    }

    /// Build the final user prompt by substituting {{text}} with the source.
    /// Falls back to the source text when no template is provided.
    package func buildUserPrompt(source: String) -> String {
        let template = userPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else {
            return source
        }
        if template.contains("{{text}}") {
            return template.replacingOccurrences(of: "{{text}}", with: source)
        }
        // No placeholder: append the source so the user's instruction still sees the text
        return "\(template)\n\n\(source)"
    }

    /// Match logic kept identical to built-in command matching for consistency.
    /// Compares against a lowercased, punctuation-trimmed version of the spoken phrase.
    func matches(_ cleanedSpoken: String) -> Bool {
        let triggerNormalized = trigger
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
        guard !triggerNormalized.isEmpty else { return false }
        return cleanedSpoken == triggerNormalized || cleanedSpoken.hasSuffix(triggerNormalized)
    }
}
