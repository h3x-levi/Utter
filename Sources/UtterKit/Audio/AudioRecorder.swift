import AVFoundation
import Foundation

class AudioRecorder: ObservableObject {
    private var audioEngine: AVAudioEngine?
    /// Whether a capture is live. Readable so callers can verify a start actually
    /// took effect before committing state that depends on it.
    private(set) var isRecording = false

    /// Smoothed input level, 0...1, published for the pill's level meter.
    ///
    /// The pill used to animate a hardcoded array of bar heights, which looked
    /// like a meter but showed nothing. This is the real signal.
    @Published private(set) var inputLevel: Float = 0

    private var smoothedLevel: Float = 0
    private var lastLevelPublish = Date.distantPast

    // Thread-safe audio buffer
    private let bufferQueue = DispatchQueue(label: "utter.dictation.audiobuffer")
    private var _audioData = Data()
    /// The raw capture buffer, behind the same serialization the tap and snapshot use.
    /// Internal rather than private so `AudioRecorderConsumeTests` can seed it without a
    /// live microphone — the crash it guards (`consume` front-trimming into a non-zero
    /// `startIndex`) is otherwise only reachable after real audio has been recorded.
    var audioData: Data {
        get { bufferQueue.sync { _audioData } }
        set { bufferQueue.sync { _audioData = newValue } }
    }

    // VAD: Voice Activity Detection
    private var silenceStart: Date?
    private var hasDetectedVoice = false

    /// Whether voice has *ever* been heard this session. Genuinely one-way.
    ///
    /// `hasDetectedVoice` is VAD working state and gets cleared every time the
    /// silence timeout fires, so it could not gate `audioSnapshot`: in a meeting
    /// (no VAD callback, long stretches where the user just listens) the flag was
    /// false on most ticks, the snapshot came back empty, and the mic buffer was
    /// never drained or compacted — losing up to a window of the user's audio at
    /// stop() and growing without bound in the meantime.
    private var everDetectedVoice = false
    private var vadCallback: (() -> Void)?
    /// `UInt16` to match `peakAmplitude`, which reports a magnitude — see the trap
    /// documented there.
    private let silenceThreshold: UInt16 = 500
    private let silenceTimeout: TimeInterval = 3.0 // Auto-send after 3s of silence (was 1.2s — too aggressive for paragraphs)

    /// Begin capturing. Returns false when capture could not start.
    ///
    /// Previously `Void` with five silent failure exits, which let callers set up
    /// state for a recording that never began: `toggleHandsFree` would flip
    /// `isHandsFree` and `suppressReleaseStop` on, the pill would show a running
    /// timer, and — because no VAD callback was installed — nothing could ever end
    /// the turn. Push-to-talk stayed dead until the user guessed to press the
    /// chord again. Callers must now check the result.
    @discardableResult
    func startRecording(onVoiceStopped: (() -> Void)? = nil) -> Bool {
        // Already capturing: refuse rather than no-op silently. A second caller
        // (dictation starting while a meeting records) would otherwise believe it
        // owns the tap, and its `stopRecording` would steal the first session's
        // audio and tear the engine down underneath it.
        guard !isRecording else { return false }

        audioData = Data()
        // Under the queue: the tap reads all of these from the render thread.
        // `silenceStart` belongs in here too — it sat outside, contradicting this
        // comment, and it is written by `checkVoiceActivity` under the queue and by
        // `installVoiceStoppedCallback` under the queue.
        bufferQueue.sync {
            silenceStart = nil
            hasDetectedVoice = false
            everDetectedVoice = false
            vadCallback = onVoiceStopped
        }
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else { return false }

        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else { return false }

        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else { return false }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let ratio = 16000.0 / nativeFormat.sampleRate
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard outputFrameCapacity > 0 else { return }

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .error { return }

            if let channelData = outputBuffer.int16ChannelData {
                let frameLength = Int(outputBuffer.frameLength)
                let data = Data(bytes: channelData[0], count: frameLength * 2)
                // One `sync` for the append *and* the VAD/level work.
                //
                // These two calls used to sit outside the queue, which left
                // `hasDetectedVoice`, `silenceStart`, `smoothedLevel` and — worst —
                // `vadCallback` being written from the audio render thread while
                // `audioSnapshot()` read them inside the queue and `stopRecording()`
                // set `vadCallback = nil` from main. An unsynchronised read/write of
                // a refcounted closure is a crash, not a stale value.
                //
                // The work is a fixed-size scan of one buffer, so holding the serial
                // queue for it does not risk a render-thread overrun.
                self.bufferQueue.sync {
                    self._audioData.append(data)
                    self.checkVoiceActivity(channelData: channelData[0], frameLength: frameLength)
                    self.publishLevel(channelData: channelData[0], frameLength: frameLength)
                }
            }
        }

        do {
            try audioEngine.start()
            isRecording = true
            print("🎙️ Recording started")
            return true
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            self.audioEngine = nil
            return false
        }
    }

    /// A snapshot of the audio captured so far, as headerless 16 kHz mono PCM.
    ///
    /// Safe to call while recording: the read goes through `bufferQueue`, the same
    /// serialization the tap uses to append, so it can never observe a half-written
    /// chunk. Returns a copy, so the caller can transcribe it while capture
    /// continues.
    ///
    /// Empty until voice has actually been detected — previewing pure silence would
    /// spend a whole inference pass to render whisper's blank-audio hallucinations.
    ///
    /// `lastBytes` caps the result to the most recent N bytes, and the live preview is why it
    /// exists. The preview loop re-transcribes the snapshot every 700ms, so an uncapped read made
    /// pass *k* transcribe roughly 0.7·k seconds of audio — the total work over an N-second
    /// utterance is O(N²), and by 30s a single pass was ~2.7s of inference on the large model,
    /// which is longer than the interval between passes. Passes then run back to back on the
    /// serial whisper queue and delay the *final* transcription that actually gets typed.
    /// `LocalWhisperProvider` already documented this bound as existing; it did not.
    ///
    /// Capping also avoids a copy on the audio render thread, **on the capped path only**. Handing
    /// back `_audioData` itself leaves a second reference alive, so the tap's next `append` has to
    /// copy the whole buffer — inside the lock, on the render thread. `subdata` returns a fresh
    /// buffer and leaves `_audioData` uniquely referenced, so the append stays in place. Meeting
    /// capture reads uncapped 30-second windows and still pays that copy; only the preview, which
    /// reads every 700ms, is spared it.
    ///
    /// Default is uncapped: meeting capture reads whole 30-second windows and must not be
    /// silently shortened.
    ///
    /// See `previewSeconds` for the window the live preview passes.
    func audioSnapshot(lastBytes cap: Int = .max) -> Data {
        bufferQueue.sync {
            guard everDetectedVoice else { return Data() }
            return Self.tail(of: _audioData, lastBytes: cap)
        }
    }

    /// The last `cap` bytes of `data`, or all of it when it is already shorter.
    ///
    /// Split out from `audioSnapshot` so it can be tested without a microphone: the snapshot
    /// itself is gated on `everDetectedVoice` and on the capture queue, neither of which a test
    /// can reach, and an off-by-one here silently drops the newest audio — the half that matters.
    /// Indices are taken from `endIndex`, not from the count, because a `Data` that has been
    /// front-trimmed is not necessarily zero-based (see `consume`).
    nonisolated static func tail(of data: Data, lastBytes cap: Int) -> Data {
        guard cap > 0 else { return Data() }
        guard cap < data.count else { return data }
        return data.subdata(in: (data.endIndex - cap)..<data.endIndex)
    }

    /// How much of the audio tail the live preview re-transcribes each pass.
    ///
    /// The number `LocalWhisperProvider.previewTranscribe` already claimed bounded it. Ten
    /// seconds because that is roughly what the preview can actually *show* — the note card
    /// draws three head-truncated lines (~126 characters at its width) and the capsule draws
    /// one, so a longer window would be inference spent on words no surface displays. It also
    /// keeps a pass near the 700ms interval between passes on the large model rather than an
    /// order of magnitude over it, which is what let previews crowd out the final transcript.
    ///
    /// Whisper's own decode window is 30s, so a 10s window is well inside the range the model
    /// is built for; the preview is deliberately unbiased and unpolished anyway (see
    /// `previewTranscribe`), and it is never the text that gets typed.
    static let previewSeconds = 10

    /// `previewSeconds` as bytes of 16 kHz mono 16-bit PCM — the format this recorder yields.
    static var previewWindowBytes: Int { previewSeconds * 16_000 * 2 }

    /// Discard the first `count` bytes of captured audio.
    ///
    /// For long sessions (meeting capture) where the consumer transcribes in
    /// rolling windows: without it the buffer grows for the whole meeting even
    /// though the early audio has already been used. Not used by ordinary
    /// dictation, which needs the whole utterance at the end.
    func consume(_ count: Int) {
        bufferQueue.sync {
            guard count > 0, count <= _audioData.count else { return }
            // `removeFirst` advances the Data's `startIndex` instead of rebasing it to 0, so
            // every later reader that indexes from 0 — `MeetingSession`'s `subdata(in:)` — traps
            // once anything has been consumed (SIGTRAP, verified). `subdata` returns a fresh
            // zero-based copy of the remaining tail, which also actually releases the trimmed
            // bytes rather than sliding a cursor over a buffer that never shrinks — the
            // bounded-memory point of consuming at all.
            _audioData = _audioData.subdata(in: (_audioData.startIndex + count)..<_audioData.endIndex)
        }
    }

    /// Install or replace the VAD silence callback after recording has started.
    /// Used for hands-free mode where the user toggles VAD on mid-recording.
    /// Resets silence tracking so the callback only fires after a NEW silence period.
    func installVoiceStoppedCallback(_ callback: @escaping () -> Void) {
        bufferQueue.sync {
            self.vadCallback = callback
            self.silenceStart = nil
            // Force hasDetectedVoice = true so the next quiet period triggers the
            // timeout. `everDetectedVoice` is deliberately NOT set here: this is a
            // synthetic nudge for hands-free VAD, not evidence that the user spoke.
            self.hasDetectedVoice = true
        }
    }

    /// Compute a display level for the pill meter.
    ///
    /// RMS rather than peak — peak spikes on transients and reads as strobing.
    /// The dB mapping matters: raw linear amplitude barely moves at speech
    /// level, so a linear meter looks broken.
    private func publishLevel(channelData: UnsafePointer<Int16>, frameLength: Int) {
        guard frameLength > 0 else { return }
        var sum: Double = 0
        for i in 0..<frameLength {
            let sample = Double(channelData[i])
            sum += sample * sample
        }
        let rms = (sum / Double(frameLength)).squareRoot()
        let db = 20 * log10(max(rms, 1) / 32_768)          // ≈ -90...0
        let normalized = Float((db + 50) / 45)             // -50 dBFS -> 0
        let target = min(max(normalized, 0), 1)

        // Fast attack so it feels responsive, slow release so it doesn't strobe.
        let coefficient: Float = target > smoothedLevel ? 0.55 : 0.12
        smoothedLevel += (target - smoothedLevel) * coefficient

        // Coalesce to ~30 Hz: the tap fires far more often, and pushing every
        // buffer through @Published thrashes SwiftUI.
        let now = Date()
        guard now.timeIntervalSince(lastLevelPublish) >= 1.0 / 30.0 else { return }
        lastLevelPublish = now
        let value = smoothedLevel
        DispatchQueue.main.async { [weak self] in self?.inputLevel = value }
    }

    /// The loudest sample in a chunk, as a distance from silence.
    ///
    /// `UInt16`, and `magnitude` rather than `abs`, because **`abs(Int16.min)` traps.**
    /// `Int16.min` is -32768 and `Int16.max` is 32767, so the absolute value of the minimum
    /// has no representable result and Swift traps on overflow rather than wrapping.
    ///
    /// -32768 is not a pathological input, it is full-scale negative: any loud passage, and
    /// any conversion that clips, produces it. This ran on the audio render thread inside the
    /// tap, so hitting it was an instant SIGTRAP with no possibility of recovery — Utter died
    /// mid-sentence whenever someone spoke loudly enough. `magnitude` returns `UInt16`, where
    /// 32768 fits, and cannot trap for any input.
    ///
    /// Static and pure so the boundary is testable without an audio engine; the trap was only
    /// ever reachable with one specific sample value, which is exactly the kind of bug that
    /// comes back.
    static func peakAmplitude(_ samples: UnsafePointer<Int16>, count: Int) -> UInt16 {
        var peak: UInt16 = 0
        for i in 0..<count {
            let amplitude = samples[i].magnitude
            if amplitude > peak { peak = amplitude }
        }
        return peak
    }

    /// VAD: detect voice vs silence
    private func checkVoiceActivity(channelData: UnsafePointer<Int16>, frameLength: Int) {
        let peak = Self.peakAmplitude(channelData, count: frameLength)
        let isVoice = peak > silenceThreshold

        if isVoice {
            hasDetectedVoice = true
            everDetectedVoice = true
            silenceStart = nil
        } else if hasDetectedVoice {
            // Voice was detected before, now it's silent
            if silenceStart == nil {
                silenceStart = Date()
            } else if let start = silenceStart {
                let silenceDuration = Date().timeIntervalSince(start)
                if silenceDuration >= silenceTimeout {
                    // User stopped talking — auto-trigger
                    print("🔇 VAD: silence detected for \(String(format: "%.1f", silenceDuration))s — auto-sending")
                    DispatchQueue.main.async { [weak self] in
                        self?.vadCallback?()
                    }
                    silenceStart = nil
                    hasDetectedVoice = false
                }
            }
        }
    }

    func stopRecording(completion: @escaping (Data?) -> Void) {
        guard isRecording, let audioEngine = audioEngine else {
            completion(nil)
            return
        }

        let stopStart = Date()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        self.audioEngine = nil
        // Clearing the callback is the write that most needed protecting: the tap
        // does `if vadCallback != nil { ... vadCallback?() }`, so tearing it down
        // from main mid-check was an unsynchronised release of a live closure.
        bufferQueue.sync {
            vadCallback = nil
            smoothedLevel = 0
        }
        DispatchQueue.main.async { [weak self] in
            self?.inputLevel = 0
        }

        let capturedData = audioData
        let stopTime = Date().timeIntervalSince(stopStart)
        let durationSec = Double(capturedData.count) / (16000.0 * 2.0)
        print("⏱️ [0] Stop engine: \(String(format: "%.0f", stopTime * 1000))ms")
        print("⏱️ [0] Audio: \(String(format: "%.1f", durationSec))s, \(capturedData.count) bytes raw")

        guard capturedData.count > 0 else {
            completion(nil)
            return
        }

        let trimStart = Date()
        let trimmed = trimSilence(from: capturedData)
        let trimTime = Date().timeIntervalSince(trimStart)
        let reduction = capturedData.count > 0 ? (capturedData.count - trimmed.count) * 100 / capturedData.count : 0
        print("⏱️ [0] Trim silence: \(String(format: "%.0f", trimTime * 1000))ms (\(reduction)% reduced)")

        guard trimmed.count > 640 else {
            completion(nil)
            return
        }

        let wavStart = Date()
        guard let wavData = Self.wav(fromPCM: trimmed) else {
            completion(nil)
            return
        }
        let wavTime = Date().timeIntervalSince(wavStart)
        print("⏱️ [0] WAV encode: \(String(format: "%.0f", wavTime * 1000))ms (\(wavData.count) bytes)")
        completion(wavData)
    }

    /// Trim leading and trailing silence from 16-bit PCM audio.
    /// `threshold` is a magnitude, for the same reason as `peakAmplitude` — comparing against
    /// `abs(samples[i])` here would trap on a full-scale negative sample just as the VAD did.
    private func trimSilence(from pcmData: Data, threshold: UInt16 = 500) -> Data {
        let sampleCount = pcmData.count / 2
        guard sampleCount > 0 else { return pcmData }

        var samples = [Int16](repeating: 0, count: sampleCount)
        // `&samples` would yield a pointer that is only valid for the duration of
        // the call expression itself; scope it properly instead.
        samples.withUnsafeMutableBufferPointer { buffer in
            _ = pcmData.copyBytes(to: buffer)
        }

        // Find first non-silent sample (keep 100ms lead-in = 1600 samples)
        var start = 0
        for i in 0..<samples.count {
            if samples[i].magnitude > threshold {
                start = max(0, i - 1600)
                break
            }
        }

        // Find last non-silent sample (keep 200ms tail = 3200 samples)
        var end = samples.count - 1
        for i in stride(from: samples.count - 1, through: 0, by: -1) {
            if samples[i].magnitude > threshold {
                end = min(samples.count - 1, i + 3200)
                break
            }
        }

        guard end > start else { return pcmData }

        let startByte = start * 2
        let endByte = min((end + 1) * 2, pcmData.count)
        return pcmData.subdata(in: startByte..<endByte)
    }

    /// Wrap Int16/mono PCM in a WAV header.
    ///
    /// One writer for the whole audio layer. `MeetingSession` had a byte-identical copy
    /// of this — its comment reasoned that duplicating 30 lines beat widening this
    /// type's surface for a second caller, which was the wrong trade: two hand-written
    /// container writers can drift, and only one of them was under test.
    ///
    /// `nil` for empty input rather than a header describing no audio, so a caller
    /// cannot hand whisper a file with zero samples and read the silence as a failure
    /// to transcribe.
    nonisolated static func wav(fromPCM pcm: Data, sampleRate: Int = 16_000, channels: Int = 1) -> Data? {
        guard !pcm.isEmpty else { return nil }
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8

        var wav = Data()
        func append32(_ value: Int) {
            var le = UInt32(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &le) { wav.append(contentsOf: $0) }
        }
        func append16(_ value: Int) {
            var le = UInt16(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &le) { wav.append(contentsOf: $0) }
        }

        wav.append(contentsOf: Array("RIFF".utf8))
        append32(36 + pcm.count)
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        append32(16)
        append16(1)              // PCM
        append16(channels)
        append32(sampleRate)
        append32(byteRate)
        append16(blockAlign)
        append16(bitsPerSample)
        wav.append(contentsOf: Array("data".utf8))
        append32(pcm.count)
        wav.append(pcm)
        return wav
    }
}
