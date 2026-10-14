import Foundation

/// Shared validity rule for recognized text before it is delivered or persisted.
/// Whisper can emit its training placeholder for silent/near-silent audio; that
/// marker is not a transcript and must never be typed into another app or shown
/// as the user's latest capture.
enum TranscriptText {
    private static let noSpeechMarkers: Set<String> = ["[BLANK_AUDIO]"]

    static func isUsable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !noSpeechMarkers.contains(trimmed.uppercased()) && !isAnnotation(trimmed)
    }

    /// Nothing but whisper's captions for sound that is not speech, "[GASP]" or "(music)".
    private static func isAnnotation(_ text: String) -> Bool {
        text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .isEmpty
    }
}
