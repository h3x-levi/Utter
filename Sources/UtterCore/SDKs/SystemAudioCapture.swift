import Foundation
import AVFoundation

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

/// Captures what the *other* participants say, by tapping system audio output.
///
/// The microphone tells Utter what the user said; on a call, everyone else is
/// coming out of the speakers. There are two ways to read that, and this picks
/// the better one at runtime:
///
///   * **A CoreAudio process tap** (`ProcessTapCapture`, macOS 14.2+) - captures
///     one process, and asks for permission to "record your system audio" rather
///     than to capture the display. Preferred whenever it works.
///   * **`ScreenCaptureKit`** - the whole output mix minus our own process, gated
///     by Screen Recording. The fallback, and what shipped first: on macOS 13, or
///     if any step of the tap route fails, this is what runs.
///
/// The tap is not an optimisation of the fallback, it is a narrower ask and a
/// narrower capture, and the difference shows up in the transcript: the system mix
/// contains Spotify, notification chimes and anything else making noise, where a
/// tap of the call's own process contains the call.
///
/// The route is chosen by *trying* it, not by testing a version. Every HAL call in
/// the tap path is status-checked and the started tap has to deliver a buffer
/// before the route is committed to - see `ProcessTapCapture.awaitFirstAudio`  - 
/// because a tap that starts and stays silent looks exactly like a quiet meeting
/// until the meeting is over. Anything short of real audio falls back.
///
/// Three properties are deliberate, and hold on both routes:
///
///   * **Audio only.** The stream is configured with a 2×2 pixel video feed
///     because `SCStream` requires *some* video configuration; the frames are
///     discarded and never inspected. Nothing about the screen is read.
///   * **Utter's own output is excluded** - `excludesCurrentProcessAudio` on the
///     ScreenCaptureKit path, and our own process object excluded from the tap on
///     the other - so the app cannot record its own UI sounds and feed them back
///     into a transcript.
///   * **Samples stay in memory.** Converted straight to the same Int16/16 kHz/mono
///     format `AudioRecorder` produces and appended to a buffer, never written to
///     disk - the same invariant the microphone path already holds.
///
/// `permissionState` answers for Screen Recording only, which is what the
/// Permissions card and the onboarding checklist report and still exactly true. It
/// is no longer the same question as "can a meeting be recorded": with a tap
/// available the answer is yes without it. `MeetingSession.prepare` is the one that
/// asks that, so the two callers about to start a capture cannot drift apart.
final class SystemAudioCapture {

    enum PermissionState: Equatable {
        case granted
        case denied
        /// Never asked. Starting a capture is what triggers the system prompt.
        case notDetermined
        /// The OS or SDK can't do this at all.
        case unsupported(String)

        var message: String {
            switch self {
            case .granted:
                return "Utter can hear the meeting."
            case .denied:
                return "Utter needs Screen Recording permission to hear other participants. Turn it on in System Settings › Privacy & Security › Screen Recording, then restart Utter."
            case .notDetermined:
                // Deliberately does not name Screen Recording. Which permission is asked for depends
                // on the route taken at the moment of recording - system audio recording on the tap
                // path, Screen Recording on the fallback - and this string is written before that is
                // known.
                return "macOS will ask permission the first time you record a meeting."
            case .unsupported(let why):
                return why
            }
        }
    }

    /// Whether the process can currently enumerate shareable content, which is
    /// what Screen Recording actually gates.
    ///
    /// `CGPreflightScreenCaptureAccess` is used rather than attempting a capture:
    /// it answers without side effects, so the UI can show the right explanation
    /// up front instead of discovering the problem mid-recording.
    static func permissionState() -> PermissionState {
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 13.0, *) else {
            return .unsupported("Meeting capture needs macOS 13 or later.")
        }
        return CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        #else
        return .unsupported("This build of Utter was compiled without ScreenCaptureKit.")
        #endif
    }

    /// Ask for Screen Recording access.
    ///
    /// The system shows its prompt at most once per app; afterwards this returns
    /// false immediately and the user has to grant it in System Settings, which is
    /// what `PermissionState.denied` explains.
    @discardableResult
    static func requestPermission() -> Bool {
        #if canImport(ScreenCaptureKit)
        return CGRequestScreenCaptureAccess()
        #else
        return false
        #endif
    }

    // MARK: - Which route

    /// Whether the per-process tap route can be attempted on this system.
    ///
    /// Two checks, and both are needed for different reasons.
    ///
    /// `#available(macOS 14.2, *)` is not a version guess standing in for a capability test - it is
    /// the compiler's requirement: `AudioHardwareCreateProcessTap` is annotated
    /// `API_AVAILABLE(macos(14.2))`, so the symbol cannot be called at all without it. This is the
    /// difference from `CallDetector`, whose property selectors are plain `CF_ENUM` constants with no
    /// annotation and therefore *had* to be probed.
    ///
    /// `AudioObjectHasProperty(kAudioHardwarePropertyTapList)` is the capability test proper: it asks
    /// the HAL on this machine whether it implements tap objects at all, costs one property query, has
    /// no side effects and triggers no prompt. It answered true on macOS 26.6 with an empty tap list.
    ///
    /// Neither of them establishes that a tap will *work* - a permission this cannot preflight, a
    /// composition this HAL will not clock. That is `start`'s job, by trying and falling back.
    ///
    /// Computed once. The answer cannot change within a launch, and `ReadinessMonitor` polls the
    /// permission surface every two seconds.
    static let processTapAvailable: Bool = {
        guard #available(macOS 14.2, *) else { return false }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTapList,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        return AudioObjectHasProperty(AudioObjectID(kAudioObjectSystemObject), &address)
    }()

    /// Which route actually ran, for the log and for a bug report. Not for the UI: both routes produce
    /// the same samples, and the distinction is only interesting when something is wrong.
    enum Route: String {
        case processTap = "process tap"
        case screenCapture = "ScreenCaptureKit"
    }

    private(set) var route: Route?

    // MARK: - Capture

    private var isCapturing = false
    private let bufferQueue = DispatchQueue(label: "utter.dictation.systemaudio")
    private var buffer = CaptureBuffer()

    /// Int16 / 16 kHz / mono PCM captured so far - the same format
    /// `AudioRecorder` yields, so both sides can be mixed without conversion.
    var samples: Data {
        bufferQueue.sync { buffer.data }
    }

    var sampleByteCount: Int { bufferQueue.sync { buffer.data.count } }

    /// Everything captured with its clock.
    var bufferSnapshot: CaptureBuffer { bufferQueue.sync { buffer } }

    private var _meter: Float = 0
    private var _heard = false


    /// Whether anything above a whisper has come through since the capture started. A silent tap
    /// looks identical to a working one until someone speaks, and that is the failure to report.
    var heardSound: Bool { bufferQueue.sync { _heard } }

    /// Loudest sound since the last read, on the same dB scale as `AudioRecorder.inputLevel`.
    var meterLevel: Float {
        bufferQueue.sync {
            defer { _meter = 0 }
            return SampleClock.meter(peak: _meter)
        }
    }

    private func append(_ data: Data, peak: Float, host: UInt64) {
        bufferQueue.sync {
            buffer.append(data, host: host)
            if peak > 0.01 { _heard = true }
            _meter = max(_meter, peak)
        }
    }

    /// Discard the first `count` bytes, which the caller has finished with.
    ///
    /// Without this the buffer only ever grows: at 32 kB/s a three-hour meeting
    /// would hold ~345 MB per stream in memory even though every byte but the last
    /// window has already been transcribed and will never be read again.
    func consume(_ count: Int) {
        bufferQueue.sync { buffer.consume(count) }
    }

    #if canImport(ScreenCaptureKit)
    @available(macOS 13.0, *)
    private var stream: SCStream?
    @available(macOS 13.0, *)
    private var output: AudioStreamOutput?
    #endif

    /// The tap route's capture, while one is running.
    ///
    /// No `@available` on it, and `ProcessTapCapture` carries none on the type either, because a
    /// stored property cannot be potentially unavailable - the alternative was an `AnyObject?` and a
    /// cast at every use. Only `start(processes:)` needs 14.2, and only `startProcessTap` calls it.
    private var processTap: ProcessTapCapture?

    enum CaptureError: LocalizedError {
        case unsupported
        case noDisplay
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .unsupported: return "Meeting capture needs macOS 13 or later."
            case .noDisplay: return "No display available to capture audio from."
            case .permissionDenied: return PermissionState.denied.message
            }
        }
    }

    /// Begin capturing.
    ///
    /// `processes` are the HAL process objects to capture, when the caller knows which ones hold the
    /// call - `CallSource.processObject`. Empty means everything except Utter, which is the only thing
    /// the ScreenCaptureKit route can do and the right behaviour when no call was identified.
    func start(tapping processes: [AudioObjectID] = []) async throws {
        guard !isCapturing else { return }
        reset()

        if #available(macOS 14.2, *), Self.processTapAvailable {
            do {
                try await startProcessTap(processes: processes)
                return
            } catch {
                // Fall through, and say why. This is the only place the two routes meet, so it is the
                // only place that can explain a machine where the tap does not work - and a user's
                // report of "no audio from the others" is otherwise unanswerable.
                print("⚠️ Process tap unavailable, falling back to ScreenCaptureKit: "
                      + "\(error.localizedDescription)")
                // Whatever the tap managed to deliver before it was rejected has to go, or the
                // fallback's first window would begin with a fragment from the other route.
                reset()
            }
        }

        try await startScreenCapture()
    }

    private func reset() {
        bufferQueue.sync {
            buffer = CaptureBuffer()
            _heard = false
            _meter = 0
        }
    }

    /// The preferred route. Throws for the fallback to catch - see `ProcessTapCapture.Failure`.
    @available(macOS 14.2, *)
    private func startProcessTap(processes: [AudioObjectID]) async throws {
        let tap = ProcessTapCapture { [weak self] data, peak, host in
            self?.append(data, peak: peak, host: host)
        }
        try tap.start(processes: processes)

        // Do not commit to this route until it has actually produced a buffer. 1.5s is many hundreds
        // of IO cycles at any device rate, and it is paid once at the start of a meeting - against the
        // alternative of discovering at the end that nothing was recorded.
        // Until a tap has worked once, macOS may be showing its system-audio prompt, and nothing
        // arrives until the user answers it.
        let tapWorkedKey = "processTapDelivered"
        guard await tap.awaitFirstAudio(timeout: UserDefaults.standard.bool(forKey: tapWorkedKey) ? 1.5 : 30) else {
            tap.stop()
            throw ProcessTapCapture.Failure.noAudioDelivered
        }
        UserDefaults.standard.set(true, forKey: tapWorkedKey)

        processTap = tap
        route = .processTap
        isCapturing = true
    }

    private func startScreenCapture() async throws {
        #if canImport(ScreenCaptureKit)
        guard #available(macOS 13.0, *) else { throw CaptureError.unsupported }

        // Enumerating content is itself permission-gated, so a throw here is the
        // authoritative "not allowed" answer regardless of what preflight said.
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
        } catch {
            throw CaptureError.permissionDenied
        }

        guard let display = content.displays.first else { throw CaptureError.noDisplay }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 16_000
        config.channelCount = 1
        // Don't record Utter's own chimes and TTS back into the transcript.
        config.excludesCurrentProcessAudio = true
        // SCStream requires a video configuration even for audio-only use. Keep it
        // as small as the API allows; frames are dropped without being read.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 5

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let handler = AudioStreamOutput { [weak self] data, peak, host in
            self?.append(data, peak: peak, host: host)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(handler, type: .audio,
                                  sampleHandlerQueue: DispatchQueue(label: "utter.dictation.systemaudio.samples"))
        try await stream.startCapture()

        self.stream = stream
        self.output = handler
        route = .screenCapture
        isCapturing = true
        print("🔊 System audio capture started (16kHz mono, own output excluded)")
        #else
        throw CaptureError.unsupported
        #endif
    }

    /// Stop capturing and return everything heard.
    @discardableResult
    func stop() async -> Data {
        if #available(macOS 14.2, *), let processTap {
            processTap.stop()
            self.processTap = nil
        }
        #if canImport(ScreenCaptureKit)
        if #available(macOS 13.0, *), let stream, isCapturing {
            try? await stream.stopCapture()
            self.stream = nil
            self.output = nil
        }
        #endif
        let finished = route
        route = nil
        isCapturing = false
        let captured = samples
        print("🔊 System audio capture stopped (\(captured.count / 32_000)s"
              + "\(finished.map { ", via \($0.rawValue)" } ?? ""))")
        return captured
    }

}

/// A capture's 16 kHz Int16 mono audio and the clock of its samples, trimmed from the front as it
/// is transcribed. Shared by the mic and the call capture.
struct CaptureBuffer {
    private(set) var data: Data
    private var clock = SampleClock()

    init(data: Data = Data()) { self.data = data }

    mutating func append(_ chunk: Data, host: UInt64) {
        clock.stamp(offset: data.count, host: host)
        data.append(chunk)
    }

    /// `subdata`, not `removeFirst`: that keeps a non-zero `startIndex`, and readers index from 0.
    mutating func consume(_ count: Int) {
        guard count > 0, count <= data.count else { return }
        data = data.subdata(in: (data.startIndex + count)..<data.endIndex)
        clock.consume(count)
    }

    func seconds(at offset: Int) -> TimeInterval? { clock.seconds(at: offset) }
}

/// When each sample of a front-trimmed 16 kHz Int16 mono buffer was captured, on the host clock.
///
/// Both captures stamp every buffer they append, so a turn from the mic and a turn from the call can be
/// placed on one timeline. Offsets are bytes from the buffer's current front, like `consume`.
struct SampleClock {
    private var anchors: [(offset: Int, host: UInt64)] = []

    mutating func stamp(offset: Int, host: UInt64) {
        anchors.append((offset, host))
    }

    /// Follow the buffer's front, keeping the anchor that still covers the new first byte.
    mutating func consume(_ count: Int) {
        let keep = anchors.lastIndex { $0.offset <= count } ?? 0
        anchors = anchors.dropFirst(keep).map { ($0.offset - count, $0.host) }
    }

    func seconds(at offset: Int) -> TimeInterval? {
        guard let anchor = anchors.last(where: { $0.offset <= offset }) ?? anchors.first else { return nil }
        return Self.seconds(anchor.host) + Double(offset - anchor.offset) / 32_000
    }

    static func seconds(_ host: UInt64) -> TimeInterval {
        Double(host) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    }

    static var now: TimeInterval { seconds(mach_absolute_time()) }

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// A 0...1 peak as a meter reading: -50 dBFS is empty, -5 dBFS is full.
    static func meter(peak: Float) -> Float {
        let db = 20 * log10(max(peak, 1 / 32_768))
        return min(max((db + 50) / 45, 0), 1)
    }
}

/// Turning a buffer of system audio into Utter's Int16 / 16 kHz / mono contract.
///
/// Shared by both capture routes rather than written twice. They arrive at the same problem from
/// different APIs - a `CMSampleBuffer` from ScreenCaptureKit, an `AudioBufferList` from a HAL IOProc
/// - but both hand over float PCM in a layout described by an `AudioStreamBasicDescription`, and the
/// downmix and the resample are the part that is easy to get subtly wrong. Two copies of it would be
/// two places for a clipping bug or an off-by-one resample to live, and only one of them would ever
/// get tested.
///
/// Pure functions over a pointer and a count, so `SystemAudioPCMTests` can call them with an array and
/// check the arithmetic without a capture, a device or a permission.
enum SystemAudioPCM {

    /// Interleaved or non-interleaved float frames → mono Int16, and the peak of the buffer.
    ///
    /// Interleaved input is averaged across channels; a non-interleaved stream gives channel 0 only,
    /// which is correct for speech - the other buffers of a deinterleaved list are the other channels,
    /// and mixing them would need all of them, where taking the first needs none.
    static func monoInt16(floats: UnsafePointer<Float32>,
                          count: Int,
                          channels: Int,
                          interleaved: Bool) -> (Data, Float) {
        let channels = max(1, channels)
        let frames = interleaved ? count / channels : count
        guard frames > 0 else { return (Data(), 0) }

        var pcm = Data(capacity: frames * 2)
        var peak: Float = 0
        for frame in 0..<frames {
            var value: Float = 0
            if interleaved {
                for channel in 0..<channels {
                    value += floats[frame * channels + channel]
                }
                value /= Float(channels)
            } else {
                value = floats[frame]
            }
            peak = max(peak, abs(value))
            // Clamp before scaling: a value outside -1...1 would wrap to the opposite sign as Int16
            // and produce a loud click. Float PCM is not promised to stay inside the range, and a
            // mixdown of several loud sources is exactly when it does not.
            let clamped = max(-1, min(1, value))
            var sample = Int16(clamped * 32_767)
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        return (pcm, peak)
    }

    /// Int16 mono at any rate to 16 kHz through AVAudioConverter, which low-passes first, so sound
    /// above 8 kHz is removed rather than folded down into the speech band. One per stream: the
    /// converter carries its filter state from one buffer to the next.
    final class Resampler {
        private var converter: AVAudioConverter?

        func sixteenK(_ pcm: Data, from rate: Double) -> Data {
            let frames = pcm.count / 2
            guard rate > 0, abs(rate - 16_000) > 1 else { return pcm }
            guard frames > 0 else { return Data() }
            if converter?.inputFormat.sampleRate != rate {
                guard let input = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: rate, channels: 1, interleaved: true),
                      let output = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)
                else { return Data() }
                converter = AVAudioConverter(from: input, to: output)
            }
            guard let converter,
                  let buffer = AVAudioPCMBuffer(pcmFormat: converter.inputFormat, frameCapacity: AVAudioFrameCount(frames)),
                  let channel = buffer.int16ChannelData else { return Data() }
            buffer.frameLength = AVAudioFrameCount(frames)
            pcm.withUnsafeBytes { channel[0].update(from: $0.bindMemory(to: Int16.self).baseAddress!, count: frames) }
            guard let out = AudioRecorder.convert(buffer, with: converter), let samples = out.int16ChannelData else { return Data() }
            return Data(bytes: samples[0], count: Int(out.frameLength) * 2)
        }
    }
}

#if canImport(ScreenCaptureKit)
/// Converts each `CMSampleBuffer` of system audio to Int16/16 kHz/mono.
///
/// ScreenCaptureKit delivers float PCM regardless of the requested `sampleRate`,
/// so the conversion is explicit rather than assumed.
@available(macOS 13.0, *)
private final class AudioStreamOutput: NSObject, SCStreamOutput {
    private let onSamples: (Data, Float, UInt64) -> Void
    private let resampler = SystemAudioPCM.Resampler()

    init(onSamples: @escaping (Data, Float, UInt64) -> Void) {
        self.onSamples = onSamples
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        // Pull the audio out via the format description so channel count and
        // sample rate come from the buffer rather than from what we asked for.
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee
        else { return }

        var blockBuffer: CMBlockBuffer?

        // Room for two buffers, not one.
        //
        // `MemoryLayout<AudioBufferList>.size` is 24 bytes on arm64 - exactly one
        // `AudioBuffer` slot. Non-interleaved (deinterleaved) audio is CoreAudio's
        // native layout and uses one buffer *per channel*, so if ScreenCaptureKit
        // ever ignores our `channelCount = 1` request the call cannot describe the
        // list, returns a buffer-too-small error, and every packet is dropped  - 
        // silently, leaving "no audio from other participants" for a whole meeting
        // with nothing to diagnose. The code already defends against SCK ignoring
        // `sampleRate`; this closes the matching gap for `channelCount`.
        let listSize = AudioBufferList.sizeInBytes(maximumBuffers: 2)
        let listPointer = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(listPointer.unsafeMutablePointer) }

        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: listPointer.unsafeMutablePointer,
            bufferListSize: listSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else {
            // Log it: a silent tap was previously indistinguishable from a quiet
            // meeting, which is the hardest kind of bug to report.
            print("⚠️ System audio packet dropped (OSStatus \(status))")
            return
        }
        defer { blockBuffer = nil }

        let buffers = listPointer
        guard let first = buffers.first, let raw = first.mData else { return }

        let channels = max(1, Int(asbd.mChannelsPerFrame))
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        guard isFloat else { return }

        let floatCount = Int(first.mDataByteSize) / MemoryLayout<Float32>.size
        guard floatCount > 0 else { return }
        let floats = raw.bindMemory(to: Float32.self, capacity: floatCount)

        // Downmix, convert and resample if ScreenCaptureKit ignored the requested
        // rate. Shared with the process-tap route - see `SystemAudioPCM`.
        let interleaved = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        var (pcm, peak) = SystemAudioPCM.monoInt16(floats: floats,
                                                   count: floatCount,
                                                   channels: channels,
                                                   interleaved: interleaved)
        pcm = resampler.sixteenK(pcm, from: asbd.mSampleRate)

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        onSamples(pcm, peak, pts.isValid ? CMClockConvertHostTimeToSystemUnits(pts) : mach_absolute_time())
    }
}
#endif
