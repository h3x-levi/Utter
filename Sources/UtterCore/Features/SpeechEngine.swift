import Foundation

/// The speech-to-text engine dictation runs on. Whisper small.en is the default; Whistle is the optional
/// "Fast" engine on Apple silicon.
package enum SpeechEngine: String, Codable, CaseIterable {
    case whisper, whistle

    /// The user's choice when it can run on this Mac, otherwise Whisper.
    package static func active(_ data: UserData = .shared) -> SpeechEngine {
        data.speechEngine == .whistle && WhistleEngine.isAvailable ? .whistle : .whisper
    }

    static func provider(whisper: TranscriptionProvider) -> TranscriptionProvider {
        active() == .whistle ? WhistleProvider(fallback: whisper) : whisper
    }

}
