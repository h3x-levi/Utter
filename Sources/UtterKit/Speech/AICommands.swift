import Cocoa

/// AI-powered voice commands, run entirely on-device via LocalAIEngine.
/// Works on: last transcription, selected text in any app, or clipboard content.
struct AICommands {

    /// Check if transcribed text is an AI command. `selectedText` is read only once a command matches.
    static func process(_ text: String, selectedText: () async -> String) async -> AICommandResult? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = lower.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))

        // 1) User-defined commands win over built-ins so users can override defaults
        for command in UserData.shared.customAICommands {
            if command.matches(cleaned) {
                return await runCustom(command, selectedText: await selectedText())
            }
        }

        // Style commands: "make it professional/concise/casual/formal"
        let stylePatterns: [(String, String)] = [
            ("make it professional", "Professional"),
            ("make this professional", "Professional"),
            ("make it concise", "Concise"),
            ("make this concise", "Concise"),
            ("make it casual", "Casual"),
            ("make this casual", "Casual"),
            ("make it formal", "Formal"),
            ("make this formal", "Formal"),
            ("rewrite professional", "Professional"),
            ("rewrite concise", "Concise"),
            ("rewrite casual", "Casual"),
            ("rewrite formal", "Formal"),
        ]
        for (phrase, style) in stylePatterns {
            if cleaned == phrase || cleaned.hasSuffix(phrase) {
                return await applyStyle(style, selectedText: await selectedText())
            }
        }

        // Translate: "translate to [language]"
        if cleaned.hasPrefix("translate to ") || cleaned.hasPrefix("translate this to ") {
            let lang = cleaned
                .replacingOccurrences(of: "translate this to ", with: "")
                .replacingOccurrences(of: "translate to ", with: "")
                .trimmingCharacters(in: .whitespaces)
            return await translateText(to: lang, selectedText: await selectedText())
        }

        // Fix grammar
        if cleaned == "fix this" || cleaned == "fix grammar" || cleaned == "fix that" {
            return await fixGrammar(selectedText: await selectedText())
        }

        // Reply
        if cleaned == "reply to this" || cleaned.hasPrefix("reply to this") {
            return await generateReply(selectedText: await selectedText())
        }

        // Summarize
        if cleaned == "summarize this" || cleaned == "summarize" {
            return await summarize(selectedText: await selectedText())
        }

        // Fixed-intent edits on what was just produced. These are the phrases
        // people reach for immediately after seeing a result, so they get exact
        // matching rather than going through the open-ended path below - an exact
        // match is predictable and skips a round trip.
        let editPatterns: [(phrases: [String], instruction: String)] = [
            (["make it shorter", "make this shorter", "shorten it", "shorten this", "make it brief"],
             "Shorten the text. Remove filler and redundancy. Keep every fact and the original tone."),
            (["make it longer", "make this longer", "expand it", "expand this", "add more detail"],
             "Expand the text with more detail, staying strictly on the same subject. Invent no new facts."),
            (["make it polite", "make this polite", "make it friendlier", "soften it"],
             "Rephrase the text to sound warmer and more polite. Keep the same request and meaning."),
            (["make it direct", "make this direct", "make it firmer", "be more direct"],
             "Rephrase the text to be more direct and assertive. Remove hedging. Keep the same meaning."),
            (["fix the punctuation", "fix punctuation", "punctuate this"],
             "Fix only punctuation and capitalisation. Change no words."),
            (["remove the last sentence", "delete the last sentence", "drop the last sentence"],
             "Return the text with its final sentence removed. Change nothing else."),
        ]
        for (phrases, instruction) in editPatterns where phrases.contains(cleaned) {
            return await edit(instruction: instruction, selectedText: await selectedText())
        }

        // Open-ended edits: "change that to past tense", "make that a question".
        //
        // Gated behind an explicit lead-in ("change that to…", "rewrite that as…")
        // rather than matched loosely. Anything looser would swallow ordinary
        // dictation - a sentence that merely begins "make sure you…" must be typed,
        // not treated as a command - and misfiring here silently replaces the
        // user's text instead of just adding a wrong word.
        let openLeadIns = [
            "change that to ", "change this to ", "rewrite that as ",
            "rewrite this as ", "turn that into ", "turn this into ",
        ]
        for leadIn in openLeadIns where cleaned.hasPrefix(leadIn) {
            let request = String(cleaned.dropFirst(leadIn.count)).trimmingCharacters(in: .whitespaces)
            guard request.count >= 3 else { break }
            return await edit(
                instruction: "Apply this change to the text: \(request). Change nothing else.",
                selectedText: await selectedText()
            )
        }

        return nil
    }

    // MARK: - Edit the previous result

    /// Apply a one-off instruction to the selection or the last dictation.
    ///
    /// Shares `applyStyle`'s shape but takes the instruction as a parameter, since
    /// these come from the user's phrasing rather than a fixed table.
    private static func edit(instruction: String, selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(
                text: nil,
                error: "Nothing to edit - select text or dictate first",
                replacesSelection: false
            )
        }

        print("✏️ Voice edit")
        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "You are a text editor. Return only the edited text, with no explanation, quotes, or preamble.",
                prompt: "\(instruction) Return ONLY the edited text.\n\nText: \(sourceText)"
            )
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                return AICommandResult(text: nil, error: "Edit produced nothing", replacesSelection: false)
            }
            return AICommandResult(text: cleaned, error: nil, replacesSelection: true)
        } catch {
            return AICommandResult(
                text: nil,
                error: "Edit failed: \(error.localizedDescription)",
                replacesSelection: false
            )
        }
    }

    // MARK: - Custom user-defined commands

    private static func runCustom(_ command: CustomAICommand, selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(
                text: nil,
                error: "Nothing to transform - select text or dictate first",
                replacesSelection: false
            )
        }

        print("🛠️ Custom command: \(command.trigger)")
        let userPrompt = command.buildUserPrompt(source: sourceText)

        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: command.systemPrompt.isEmpty
                    ? "You are a text editor. Return only the transformed text."
                    : command.systemPrompt,
                prompt: userPrompt
            )
            return AICommandResult(
                text: result.trimmingCharacters(in: .whitespacesAndNewlines),
                error: nil,
                replacesSelection: command.replacesSelection
            )
        } catch {
            print("❌ Custom command error: \(error)")
            return AICommandResult(
                text: nil,
                error: "Command failed: \(error.localizedDescription)",
                replacesSelection: false
            )
        }
    }

    // MARK: - Style (works on selected text OR last transcription)

    private static func applyStyle(_ style: String, selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(text: nil, error: "Nothing to restyle - select text or dictate first", replacesSelection: false)
        }

        let prompts: [String: String] = [
            "Professional": "Rewrite this text in a professional, business-appropriate tone. Fix grammar. Keep the same meaning.",
            "Concise": "Rewrite this text to be shorter and more concise. Remove filler words and unnecessary phrases. Keep the core meaning.",
            "Casual": "Rewrite this text in a casual, friendly, conversational tone. Keep the same meaning.",
            "Formal": "Rewrite this text in a formal, academic tone. Use proper grammar, no contractions. Keep the same meaning.",
        ]

        let instruction = prompts[style] ?? "Rewrite this text."
        print("✨ Applying style: \(style)...")

        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "You are a text editor. Return only the rewritten text with no explanations, no quotes, and no prefixes like 'Here is'.",
                prompt: "\(instruction) Return ONLY the rewritten text.\n\nText: \(sourceText)"
            )
            return AICommandResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), error: nil, replacesSelection: true)
        } catch {
            print("❌ Style error: \(error)")
            return AICommandResult(text: nil, error: "Style failed: \(error.localizedDescription)", replacesSelection: false)
        }
    }

    // MARK: - Translate

    private static func translateText(to language: String, selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(text: nil, error: "Nothing to translate", replacesSelection: false)
        }

        print("🌍 Translating to \(language)...")
        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "You are a translator. Return only the translated text.",
                prompt: "Translate to \(language). Return ONLY the translated text.\n\nText: \(sourceText)"
            )
            return AICommandResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), error: nil, replacesSelection: true)
        } catch {
            return AICommandResult(text: nil, error: "Translation failed: \(error.localizedDescription)", replacesSelection: false)
        }
    }

    // MARK: - Fix Grammar

    private static func fixGrammar(selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(text: nil, error: "Nothing to fix", replacesSelection: false)
        }

        print("✏️ Fixing grammar...")
        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "You are a grammar editor. Return only the corrected text.",
                prompt: "Fix grammar, spelling, and punctuation. Keep the same meaning and tone. Return ONLY the corrected text.\n\nText: \(sourceText)"
            )
            return AICommandResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), error: nil, replacesSelection: true)
        } catch {
            return AICommandResult(text: nil, error: "Fix failed: \(error.localizedDescription)", replacesSelection: false)
        }
    }

    // MARK: - Reply

    private static func generateReply(selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(text: nil, error: "Copy or select the message to reply to", replacesSelection: false)
        }

        print("💬 Generating reply...")
        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "Write short, professional replies. Be concise and direct. No greetings or sign-offs unless the original has them.",
                prompt: "Write a brief, professional reply. Return ONLY the reply.\n\nMessage: \(sourceText)"
            )
            // Reply doesn't replace - it pastes after
            return AICommandResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), error: nil, replacesSelection: false)
        } catch {
            return AICommandResult(text: nil, error: "Reply failed: \(error.localizedDescription)", replacesSelection: false)
        }
    }

    // MARK: - Summarize

    private static func summarize(selectedText: String) async -> AICommandResult? {
        let sourceText = !selectedText.isEmpty ? selectedText : UserData.shared.lastTranscription
        guard !sourceText.isEmpty else {
            return AICommandResult(text: nil, error: "Nothing to summarize", replacesSelection: false)
        }

        print("📋 Summarizing...")
        do {
            let result = try await LocalAIEngine.rewrite(
                instructions: "You write concise summaries. Return only the summary text.",
                prompt: "Summarize this text in 1-3 sentences. Return ONLY the summary.\n\nText: \(sourceText)"
            )
            return AICommandResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), error: nil, replacesSelection: true)
        } catch {
            return AICommandResult(text: nil, error: "Summary failed: \(error.localizedDescription)", replacesSelection: false)
        }
    }

}

struct AICommandResult {
    let text: String?
    let error: String?
    let replacesSelection: Bool
}
