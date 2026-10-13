import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// The WAV header meeting capture wraps each window in.
///
/// Every 30-second window of a meeting goes through this on its way to Whisper, and
/// `LocalWhisperProvider.transcribe` parses the header to find the samples. A wrong
/// field does not fail loudly: it yields silence, noise, or half-speed audio, which
/// surfaces as an empty or garbled meeting note with no error anywhere. That is silent
/// data loss of something unrepeatable, so the bytes are checked individually.
///
/// The header is written by hand in `MeetingSession.wav`, so this reads it back the way
/// a decoder would rather than re-deriving it from the same arithmetic.
@Suite("Meeting WAV header")
@MainActor
struct MeetingWAVTests {

    /// `pcm.count` bytes of non-zero, non-constant samples.
    ///
    /// A recognisable pattern rather than zeros, so the payload can be proven to be
    /// present, unmodified, and correctly positioned after the header.
    private static func pcm(bytes: Int) -> Data {
        Data((0..<bytes).map { UInt8(($0 * 7 + 13) % 251) })
    }

    // MARK: Reading the header back

    /// A little-endian integer read from `data` at `offset`, exactly as a decoder does.
    ///
    /// Assembled byte by byte rather than with `withUnsafeBytes`/`load`, so the test
    /// asserts the byte *order* on disk instead of inheriting the host's endianness and
    /// passing on a big-endian machine that would produce a broken file.
    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func ascii(_ data: Data, at offset: Int, length: Int = 4) -> String {
        String(decoding: data[offset..<(offset + length)], as: UTF8.self)
    }

    @Test("Every header field holds the value a decoder expects, in little-endian order")
    func headerFieldByField() throws {
        let payload = Self.pcm(bytes: 640)          // 20 ms at 16 kHz mono Int16
        let wav = try #require(AudioRecorder.wav(fromPCM: payload))

        // Canonical 44-byte header, then the samples.
        #expect(wav.count == 44 + payload.count)

        // --- RIFF chunk descriptor ---
        #expect(ascii(wav, at: 0) == "RIFF")
        // Everything after this field: 36 bytes of remaining header + payload. Getting
        // this wrong makes a strict parser reject the file outright.
        #expect(readUInt32LE(wav, at: 4) == UInt32(36 + payload.count))
        #expect(ascii(wav, at: 8) == "WAVE")

        // --- fmt subchunk ---
        #expect(ascii(wav, at: 12) == "fmt ")       // the trailing space is part of the id
        #expect(readUInt32LE(wav, at: 16) == 16)    // PCM fmt chunks are 16 bytes
        #expect(readUInt16LE(wav, at: 20) == 1)     // 1 == uncompressed PCM
        #expect(readUInt16LE(wav, at: 22) == 1)     // mono
        #expect(readUInt32LE(wav, at: 24) == 16_000)
        // byteRate = rate * channels * bitsPerSample / 8. Wrong here and the audio
        // plays at the wrong speed, which Whisper transcribes as nonsense.
        #expect(readUInt32LE(wav, at: 28) == 16_000 * 1 * 16 / 8)
        #expect(readUInt32LE(wav, at: 28) == 32_000)
        #expect(readUInt16LE(wav, at: 32) == 1 * 16 / 8)   // blockAlign == 2
        #expect(readUInt16LE(wav, at: 34) == 16)           // Int16 samples

        // --- data subchunk ---
        #expect(ascii(wav, at: 36) == "data")
        #expect(readUInt32LE(wav, at: 40) == UInt32(payload.count))

        // The samples themselves, byte-identical and starting at 44.
        #expect(wav[44...] == payload)
    }

    @Test("Multi-byte fields are written little-endian, not big-endian")
    func littleEndianByteOrder() throws {
        // Chosen so every byte of the field differs: 16000 == 0x00003E80, which is
        // `80 3E 00 00` little-endian and `00 00 3E 80` big-endian. A byte-order
        // mistake is invisible to a same-endian round trip but produces a file no
        // decoder can read.
        let wav = try #require(AudioRecorder.wav(fromPCM: Self.pcm(bytes: 8)))

        #expect(Array(wav[24..<28]) == [0x80, 0x3E, 0x00, 0x00])

        // byteRate 32000 == 0x00007D00 -> `00 7D 00 00`.
        #expect(Array(wav[28..<32]) == [0x00, 0x7D, 0x00, 0x00])

        // fmt chunk size 16 -> `10 00 00 00`; a big-endian writer emits `00 00 00 10`.
        #expect(Array(wav[16..<20]) == [0x10, 0x00, 0x00, 0x00])
    }

    // MARK: Sizes track the payload

    @Test("The declared sizes track the payload rather than being fixed")
    func sizesFollowPayload() throws {
        // A short window, a full 30-second window, and an odd length. If either size
        // field were hardcoded, a decoder would read past the end or truncate the
        // audio - dropping the tail of a meeting window silently.
        for bytes in [2, 4_096, 30 * 16_000 * 2, 12_345] {
            let payload = Self.pcm(bytes: bytes)
            let wav = try #require(AudioRecorder.wav(fromPCM: payload))

            #expect(wav.count == 44 + bytes)
            #expect(readUInt32LE(wav, at: 4) == UInt32(36 + bytes))
            #expect(readUInt32LE(wav, at: 40) == UInt32(bytes))
            // The two size fields must stay consistent with each other and with the
            // real length, which is what a parser cross-checks.
            #expect(readUInt32LE(wav, at: 4) == UInt32(wav.count - 8))
            #expect(readUInt32LE(wav, at: 40) == UInt32(wav.count - 44))
        }
    }

    @Test("A non-default rate and channel count reach the header and its derived fields")
    func honoursNonDefaultFormat() throws {
        // The parameters exist, so a caller can pass them; if they were ignored the
        // header would claim 16 kHz mono for stereo 44.1 kHz audio and the transcript
        // would be garbage.
        let payload = Self.pcm(bytes: 400)
        let wav = try #require(AudioRecorder.wav(fromPCM: payload, sampleRate: 44_100, channels: 2))

        #expect(readUInt16LE(wav, at: 22) == 2)
        #expect(readUInt32LE(wav, at: 24) == 44_100)
        // Both derived fields must follow the arguments, not the defaults.
        #expect(readUInt32LE(wav, at: 28) == 44_100 * 2 * 16 / 8)   // 176_400
        #expect(readUInt16LE(wav, at: 32) == 2 * 16 / 8)            // 4
        #expect(readUInt16LE(wav, at: 34) == 16)
        #expect(wav.count == 44 + payload.count)
    }

    // MARK: Nothing in, nothing out

    @Test("Empty PCM yields nil rather than a header describing no audio")
    func emptyInputReturnsNil() {
        // `MeetingSession.transcribe` relies on this: a 44-byte headers-only WAV would
        // be handed to Whisper, which hallucinates a plausible sentence on silence and
        // would write invented text into the user's meeting note.
        #expect(AudioRecorder.wav(fromPCM: Data()) == nil)
        #expect(AudioRecorder.wav(fromPCM: Data(), sampleRate: 44_100, channels: 2) == nil)

        // One byte is not empty, so it is still wrapped - the guard is on emptiness
        // only, and the caller's `minimumBytes` check is what enforces a useful length.
        #expect(AudioRecorder.wav(fromPCM: Data([0x01])) != nil)
    }
}
