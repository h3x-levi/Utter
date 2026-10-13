import Foundation
import os

/// Dictation through Whistle: the WAV `AudioRecorder` produces in, cased and punctuated English out,
/// with the user's dictionary as keyword biasing. A failed pass falls back to `fallback` when there is one.
struct WhistleProvider: TranscriptionProvider {
    static let sampleRate = 16_000
    static let keywordLimit = 420
    var fallback: TranscriptionProvider?

    func transcribe(audioData: Data) async throws -> String {
        do {
            return try await transcribeWithWhistle(audioData)
        } catch {
            guard let fallback else { throw error }
            Logger(subsystem: "utter.dictation.app", category: "speech").error("Whistle failed, using Whisper: \(error.localizedDescription)")
            return try await fallback.transcribe(audioData: audioData)
        }
    }

    private func transcribeWithWhistle(_ audioData: Data) async throws -> String {
        let samples = try LocalWhisperProvider.pcmSamples(fromWAV: audioData)
        let keywords = await MainActor.run { Self.keywords(from: UserData.shared) }
        let chunks = Self.chunks(of: samples)
        guard chunks.count > 1 else {
            return try await WhistleEngine.transcribe(samples, keywords: keywords, wordTimes: false).text
        }
        var passes: [(chunk: Chunk, words: [WhistleEngine.Word])] = []
        for chunk in chunks {
            let pass = try await WhistleEngine.transcribe(Array(samples[chunk.audio]), keywords: keywords, wordTimes: true)
            passes.append((chunk, pass.words ?? []))
        }
        return Self.stitch(passes)
    }

    static func keywords(from data: UserData) -> String {
        guard data.speechBiasEnabled else { return "" }
        var joined = ""
        for term in SpeechBias.biasTerms(from: data.dictionaryWords) {
            let next = joined.isEmpty ? term : joined + "\n" + term
            guard next.count <= keywordLimit else { break }
            joined = next
        }
        return joined
    }

    // MARK: - Audio longer than one pass

    /// One pass's audio, and the span whose words it contributes to the transcript.
    struct Chunk: Equatable {
        var audio: Range<Int>
        var keep: Range<Int>
    }

    /// `AudioRecorder`'s silence threshold, 500 in Int16 units.
    static let silence: Float = 500 / 32768

    /// Splits audio over 30 s: in the middle of the quietest 300 ms between 20 and 28 s into a chunk when that is
    /// silent, otherwise hard at 28 s with a 2 s overlap whose midpoint is the seam.
    static func chunks(of samples: [Float]) -> [Chunk] {
        let second = sampleRate
        var chunks: [Chunk] = []
        var start = 0, keepFrom = 0
        while samples.count - start > 30 * second {
            if let cut = pause(in: samples, within: start + 20 * second ..< start + 28 * second) {
                chunks.append(Chunk(audio: start..<cut, keep: keepFrom..<cut))
                (start, keepFrom) = (cut, cut)
            } else {
                let end = start + 28 * second, seam = end - second
                chunks.append(Chunk(audio: start..<end, keep: keepFrom..<seam))
                (start, keepFrom) = (end - 2 * second, seam)
            }
        }
        chunks.append(Chunk(audio: start..<samples.count, keep: keepFrom..<samples.count))
        return chunks
    }

    /// The middle of the quietest 300 ms in `range`, if it is below `silence`.
    static func pause(in samples: [Float], within range: Range<Int>) -> Int? {
        let frame = sampleRate / 100, width = 30
        let peaks = stride(from: range.lowerBound, to: range.upperBound, by: frame).map { lower in
            samples[lower..<min(lower + frame, range.upperBound)].reduce(0) { max($0, abs($1)) }
        }
        guard peaks.count >= width else { return nil }
        let loudest = (0...peaks.count - width).map { peaks[$0..<$0 + width].max() ?? 0 }
        guard let quietest = loudest.indices.min(by: { loudest[$0] < loudest[$1] }),
              loudest[quietest] < silence else { return nil }
        return range.lowerBound + (quietest * frame) + (width * frame / 2)
    }

    /// Each chunk's words whose midpoint falls in its `keep` span, dropping a word an overlap repeats at its seam.
    static func stitch(_ passes: [(chunk: Chunk, words: [WhistleEngine.Word])]) -> String {
        func normalised(_ word: String) -> String { word.lowercased().filter { $0.isLetter || $0.isNumber } }
        var transcript: [String] = []
        for (chunk, words) in passes {
            var kept = words.filter { word in
                let middle = (word.start + word.end) / 2 * Double(sampleRate)
                return chunk.keep.contains(chunk.audio.lowerBound + Int(middle))
            }.map { $0.word.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if chunk.keep.lowerBound > chunk.audio.lowerBound, let last = transcript.last, let first = kept.first,
               normalised(last) == normalised(first) {
                kept.removeFirst()
            }
            transcript += kept
        }
        return transcript.joined(separator: " ")
    }
}
