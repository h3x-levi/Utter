import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device text rewriting via Apple's system language model.
///
/// This replaces the previous Bedrock/Claude path. Nothing leaves the machine
/// and there is no cloud account behind it, which also means the capability is
/// not guaranteed to exist: the model requires macOS 26 with Apple Intelligence
/// switched on. Rather than silently degrading, `availability` reports exactly
/// why it can't run so the UI can tell the user what to do about it.
enum LocalAIEngine {

    enum Availability: Equatable {
        case ready
        /// macOS is too old for the on-device model.
        case unsupportedOS
        /// The Mac supports it but the user hasn't enabled Apple Intelligence.
        case appleIntelligenceOff
        /// Model files are still downloading, or the device is ineligible.
        case modelNotReady(String)

        /// Short sentence suitable for surfacing directly in the UI.
        var message: String {
            switch self {
            case .ready:
                return "On-device AI is ready."
            case .unsupportedOS:
                return "AI commands need macOS 26 or later. Dictation works without them."
            case .appleIntelligenceOff:
                return "Turn on Apple Intelligence in System Settings to use AI commands."
            case .modelNotReady(let detail):
                return "The on-device model isn't ready yet - \(detail)"
            }
        }

        var isReady: Bool { self == .ready }
    }

    /// Whether on-device rewriting can run right now. Cheap to call; the UI
    /// polls this to decide what to show.
    static var availability: Availability {
        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceOff
        case .unavailable(.modelNotReady):
            return .modelNotReady("it's still downloading. Try again shortly.")
        case .unavailable(let reason):
            return .modelNotReady("this Mac reported: \(reason).")
        }
        #else
        return .unsupportedOS
        #endif
    }

    /// Run a single rewrite. `instructions` sets the model's role; `prompt`
    /// carries the task plus the user's text.
    ///
    /// Throws `AIEngineError.unavailable` when the model can't run, so callers
    /// surface the real reason instead of a generic failure.
    static func rewrite(instructions: String, prompt: String) async throws -> String {
        let state = availability
        guard state.isReady else { throw AIEngineError.unavailable(state) }

        #if canImport(FoundationModels)
        guard #available(macOS 26, *) else { throw AIEngineError.unavailable(.unsupportedOS) }
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AIEngineError.emptyResponse }
        return Self.stripWrapping(text)
        #else
        throw AIEngineError.unavailable(.unsupportedOS)
        #endif
    }

    /// Small models sometimes wrap the answer in quotes or lead with a preamble
    /// despite being told not to. Strip the common shapes so pasted text is clean.
    private static func stripWrapping(_ text: String) -> String {
        var result = text

        // Drop a leading "Here is the ...:" style preamble followed by a newline.
        if let newline = result.firstIndex(of: "\n") {
            let firstLine = result[result.startIndex..<newline]
                .trimmingCharacters(in: .whitespaces)
            let lowered = firstLine.lowercased()
            let isPreamble = firstLine.hasSuffix(":")
                && firstLine.count < 60
                && (lowered.hasPrefix("here") || lowered.hasPrefix("sure")
                    || lowered.hasPrefix("rewritten") || lowered.hasPrefix("translation")
                    || lowered.hasPrefix("summary"))
            if isPreamble {
                result = String(result[result.index(after: newline)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Unwrap a fully-quoted response, but only when the quotes are balanced
        // at both ends - the text itself may legitimately contain quotes.
        for (open, close) in [("\"", "\""), ("“", "”"), ("'", "'")] {
            if result.hasPrefix(open), result.hasSuffix(close), result.count > 2 {
                let inner = String(result.dropFirst().dropLast())
                if !inner.contains(close) {
                    result = inner
                    break
                }
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIEngineError: LocalizedError {
    case unavailable(LocalAIEngine.Availability)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unavailable(let state): return state.message
        case .emptyResponse: return "The on-device model returned nothing."
        }
    }
}
