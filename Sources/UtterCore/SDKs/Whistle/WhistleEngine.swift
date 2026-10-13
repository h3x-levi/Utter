import CNeedle
import Foundation
import os

/// Cactus's Whistle speech model, through libneedle's C API.
///
/// libneedle holds one process-global model, is not thread-safe and has no unload, so every call runs on `queue`
/// and the model, once loaded, stays for the life of the process.
package enum WhistleEngine {
    static let modelFilename = "whistle.cact"

    /// Apple silicon on macOS 26, which libneedle is built for, with the model bundled. The Intel slice is a stub.
    package static let isAvailable: Bool = {
        #if arch(arm64)
        guard #available(macOS 26, *) else { return false }
        return LocalWhisperProvider.bundledModelURL(named: modelFilename) != nil
        #else
        return false
        #endif
    }()

    struct Word: Decodable, Equatable {
        let word: String
        let start: Double
        let end: Double
    }

    struct Transcript: Decodable {
        let text: String
        let words: [Word]?
        let ttftMs: Double?

        private enum CodingKeys: String, CodingKey {
            case text, words, ttftMs = "ttft_ms"
        }
    }

    private static let queue = DispatchQueue(label: "utter.dictation.whistle", qos: .userInitiated)
    private static let log = Logger(subsystem: "utter.dictation.app", category: "speech-performance")
    private static let outputCapacity: Int32 = 256 * 1024

    /// Confined to `queue`. Kept alive because libneedle does not say whether it copies the bytes it loads.
    nonisolated(unsafe) private static var model: Data?

    /// One English pass over at most 30 s of 16 kHz mono audio.
    static func transcribe(_ samples: [Float], keywords: String, wordTimes: Bool) async throws -> Transcript {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try run(samples, keywords: keywords, wordTimes: wordTimes) })
            }
        }
    }

    private static func run(_ samples: [Float], keywords: String, wordTimes: Bool) throws -> Transcript {
        try load()
        let started = DispatchTime.now().uptimeNanoseconds
        var out = [CChar](repeating: 0, count: Int(outputCapacity))
        let tokens = samples.withUnsafeBufferPointer { pcm in
            needle_transcribe(pcm.baseAddress, Int32(pcm.count), "en", keywords.isEmpty ? nil : keywords,
                              wordTimes ? 1 : 0, &out, outputCapacity)
        }
        guard tokens >= 0 else {
            log.error("whistle transcribe failed: \(String(cString: needle_last_error()), privacy: .public)")
            throw TranscriptionError.inferenceFailed(Int(tokens))
        }
        let json = Data(out.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)))
        let transcript = try JSONDecoder().decode(Transcript.self, from: json)
        let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        log.info(
            "whistle inference_ms=\(milliseconds, format: .fixed(precision: 1)) ttft_ms=\(transcript.ttftMs ?? 0, format: .fixed(precision: 1)) samples=\(samples.count) tokens=\(tokens)"
        )
        return transcript
    }

    private static func load() throws {
        guard model == nil else { return }
        guard isAvailable, let url = LocalWhisperProvider.bundledModelURL(named: modelFilename) else {
            throw TranscriptionError.modelMissing(modelFilename)
        }
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        let status = data.withUnsafeBytes { bytes in
            needle_load(bytes.bindMemory(to: UInt8.self).baseAddress, UInt64(bytes.count))
        }
        guard status >= 0 else {
            log.error("whistle load failed: \(String(cString: needle_last_error()), privacy: .public)")
            throw TranscriptionError.modelLoadFailed(modelFilename)
        }
        model = data
    }
}
