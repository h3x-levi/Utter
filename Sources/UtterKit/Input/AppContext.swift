import Cocoa

/// Detects the currently focused app and determines formatting context.
enum AppContextType: String {
    case code       // VS Code, Xcode, Terminal, iTerm
    case chat       // Slack, Messages, Discord, Teams
    case email      // Mail, Outlook, Gmail (browser)
    case document   // Pages, Word, Google Docs, Notes
    case browser    // Safari, Chrome, Firefox
    case general    // Everything else
}

struct AppContext {

    /// Detect the type of the currently focused application
    static func detect() -> AppContextType {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .general }
        let bundleId = app.bundleIdentifier ?? ""

        // Code editors & terminals
        let codeApps = [
            "com.microsoft.VSCode", "com.apple.dt.Xcode",
            "com.apple.Terminal", "com.googlecode.iterm2",
            "com.sublimetext", "dev.zed.Zed",
            "com.jetbrains", "com.cursor", "com.todesktop.230313mzl4w4u92",
        ]
        if codeApps.contains(where: { bundleId.contains($0) }) { return .code }

        // Chat apps
        let chatApps = [
            "com.tinyspeck.slackmacgap", "com.apple.MobileSMS",
            "com.hnc.Discord", "com.microsoft.teams",
            "com.facebook.archon", "ru.keepcoder.Telegram",
            "net.whatsapp.WhatsApp",
        ]
        if chatApps.contains(where: { bundleId.contains($0) }) { return .chat }

        // Email
        let emailApps = [
            "com.apple.mail", "com.microsoft.Outlook",
            "com.readdle.smartemail", "com.google.Gmail",
        ]
        if emailApps.contains(where: { bundleId.contains($0) }) { return .email }

        // Document editors
        let docApps = [
            "com.apple.iWork.Pages", "com.microsoft.Word",
            "com.apple.Notes", "com.notion",
            "md.obsidian", "com.google.Docs",
        ]
        if docApps.contains(where: { bundleId.contains($0) }) { return .document }

        // Browsers
        let browserApps = [
            "com.apple.Safari", "com.google.Chrome",
            "org.mozilla.firefox", "com.brave.Browser",
            "com.microsoft.edgemac",
        ]
        if browserApps.contains(where: { bundleId.contains($0) }) { return .browser }

        return .general
    }

    /// How text should read in this context, as an instruction fragment for the
    /// on-device model. `nil` where no tone guidance is warranted.
    ///
    /// This only ever adjusts *register* - contractions, sentence length, greetings.
    /// It must never license rewording, because the same objection applies as in
    /// `SentencePolish`: a dictation tool that quietly rephrases you is worse than
    /// one that punctuates badly. The plausibility check there is what enforces it.
    static func tone(for context: AppContextType) -> String? {
        switch context {
        case .email:
            // Mail is the one place where an unpunctuated run genuinely costs the
            // user something, so it gets the strongest guidance.
            return "This text is going into an email. Prefer complete sentences and standard punctuation."
        case .chat:
            return "This text is going into a chat message. Keep it short; contractions are fine; a trailing full stop is optional."
        case .document:
            return "This text is going into a document. Use full sentences and complete punctuation."
        case .code:
            // Deliberately none: prose conventions actively harm identifiers,
            // paths, and command lines.
            return nil
        case .browser, .general:
            // Could be anything - guessing would be worse than staying neutral.
            return nil
        }
    }

    /// Apply context-specific formatting adjustments
    static func adjustFormatting(_ text: String, context: AppContextType) -> String {
        var result = text

        switch context {
        case .code:
            // Don't auto-capitalize, preserve casing, no trailing period
            if result.last == "." && !result.hasSuffix("...") {
                result = String(result.dropLast())
            }
            // Don't capitalize first letter for code contexts
            // (user might be dictating a variable name)
            print("📝 Context: code - minimal formatting")

        case .chat:
            // Casual: no trailing period for short messages
            let wordCount = result.split(separator: " ").count
            if wordCount < 10 && result.last == "." {
                result = String(result.dropLast())
            }
            print("📝 Context: chat - casual formatting")

        case .email:
            // Professional: ensure proper ending punctuation
            if let last = result.last, ![".", "!", "?"].contains(last) {
                result += "."
            }
            print("📝 Context: email - professional formatting")

        case .document:
            // Full formatting, ensure proper punctuation
            if let last = result.last, ![".", "!", "?", ":", ";"].contains(last) {
                result += "."
            }
            print("📝 Context: document - full formatting")

        case .browser:
            // Could be anything - use default formatting
            print("📝 Context: browser - default formatting")

        case .general:
            print("📝 Context: general - default formatting")
        }

        return result
    }
}
