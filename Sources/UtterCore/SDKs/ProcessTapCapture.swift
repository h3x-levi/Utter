import AudioToolbox
import CoreAudio
import Foundation

/// Captures what one process is playing, using a CoreAudio process tap.
///
/// This is the preferred way `SystemAudioCapture` hears the other participants on a call, with
/// ScreenCaptureKit as the fallback. Two things make it better rather than merely different:
///
///   * **It asks for the right permission.** A tap is gated by `kTCCServiceAudioCapture` - "'Utter'
///     would like access to record your system audio", read verbatim out of this machine's
///     `TCC.framework` string table - and it needs the `NSAudioCaptureUsageDescription` key, which
///     Apple documents as "A message that tells people why your app is requesting access to capture
///     system audio on macOS" (macOS 14.2+). ScreenCaptureKit is gated by `kTCCServiceScreenCapture`,
///     whose own prompt is "would like to capture the contents of the system display". Those are two
///     separate services with two separate prompts, and only one of them describes what this app
///     does. Granting Screen Recording to a dictation app to let it hear a meeting was always a
///     larger ask than the feature deserved.
///   * **It captures one process, not the machine.** ScreenCaptureKit gives the whole output mix
///     minus our own process, so Spotify, a notification chime and every other sound on the system
///     land in the meeting transcript. A tap built from the call's own process object contains the
///     call and nothing else.
///
/// **A tap cannot be read directly, and that is the one real cost.** `AudioHardwareCreateProcessTap`
/// returns an `AudioObjectID` for a tap object, which is not something an IOProc can be attached to.
/// Apple's own guidance is to put the tap in a HAL aggregate device and read it "as an input in a HAL
/// aggregate device, just like a microphone", which is what `start` does. The aggregate is created
/// with `kAudioAggregateDeviceIsPrivateKey`, whose documented behaviour is that it "is private to the
/// process that created it" and "is not persistent across launches of the process that created it"  - 
/// so it never appears in anyone's output-device menu and a crash cannot leave a phantom audio device
/// behind on the user's machine.
///
/// **Nothing here is muted.** `CATapDescription.muteBehavior` defaults to `CATapUnmuted` and is set
/// to it explicitly anyway: the failure mode of getting this wrong is that the user stops being able
/// to hear the meeting they are in, which is not a failure worth saving a line over.
///
/// **Audio still never reaches the disk.** Samples are converted in the callback, handed to the same
/// in-memory buffer the ScreenCaptureKit path fills, transcribed in windows and dropped.
///
/// The availability annotation is on `start` rather than on the type, deliberately: a
/// potentially-unavailable *type* cannot be a stored property, so annotating the class would force
/// `SystemAudioCapture` to hold this as an `AnyObject?` and cast it back at every use. The only
/// symbols that actually need macOS 14.2 are the two tap calls, and `teardown` guards its own.
final class ProcessTapCapture {

    /// Everything that can go wrong, each carrying the HAL's own status so a report from a user says
    /// which step failed rather than "meeting capture didn't work".
    ///
    /// Every one of these is a *fallback* trigger, not a user-visible error:
    /// `SystemAudioCapture.start` catches them and runs the ScreenCaptureKit path instead, so the
    /// worst case of this whole file being wrong on some machine is the behaviour that shipped before
    /// it existed.
    enum Failure: LocalizedError {
        case tapNotCreated(OSStatus)
        case tapUIDUnreadable
        case tapFormatUnreadable(OSStatus)
        /// Our own HAL process object could not be identified, so a global tap would record Utter.
        case ownProcessUnknown
        case tapFormatNotFloat(UInt32)
        case aggregateNotCreated(OSStatus)
        case ioProcNotCreated(OSStatus)
        case deviceWouldNotStart(OSStatus)
        /// The device started and then delivered nothing. See `awaitFirstAudio`.
        case noAudioDelivered

        var errorDescription: String? {
            switch self {
            case .tapNotCreated(let status):
                return "AudioHardwareCreateProcessTap failed (OSStatus \(status))"
            case .tapUIDUnreadable:
                return "kAudioTapPropertyUID returned nothing, so the tap cannot be put in a device"
            case .ownProcessUnknown:
                return "Utter's own audio process could not be identified"
            case .tapFormatUnreadable(let status):
                return "kAudioTapPropertyFormat failed (OSStatus \(status))"
            case .tapFormatNotFloat(let flags):
                return "the tap's format is not float PCM (format flags \(flags))"
            case .aggregateNotCreated(let status):
                return "AudioHardwareCreateAggregateDevice failed (OSStatus \(status))"
            case .ioProcNotCreated(let status):
                return "AudioDeviceCreateIOProcIDWithBlock failed (OSStatus \(status))"
            case .deviceWouldNotStart(let status):
                return "AudioDeviceStart failed (OSStatus \(status))"
            case .noAudioDelivered:
                return "the tap started but delivered no audio"
            }
        }
    }

    /// Called with 16 kHz mono Int16 PCM and the peak of that buffer, on `queue`.
    private let onSamples: (Data, Float) -> Void

    /// Where the IO block runs.
    ///
    /// `AudioDeviceCreateIOProcIDWithBlock` documents `inDispatchQueue` as "the dispatch queue on
    /// which the IOBlock will be dispatched … If this value is NULL, then the IOBlock will be
    /// directly invoked" - directly meaning on CoreAudio's real-time IO thread, where allocating a
    /// `Data` and taking a lock are both the wrong thing to do. Handing it a serial queue moves the
    /// conversion off that thread, which is what makes the straightforward implementation correct
    /// instead of a ring buffer.
    private let queue = DispatchQueue(label: "utter.dictation.processtap", qos: .userInitiated)

    private var tap = AudioObjectID(kAudioObjectUnknown)
    private var aggregate = AudioObjectID(kAudioObjectUnknown)
    private var ioProc: AudioDeviceIOProcID?
    private var isRunning = false

    /// The tap's format, read once at start. Guarded by `queue` because the IO block reads it.
    private var format = AudioStreamBasicDescription()

    /// Whether the IO block has ever run with frames in it. Guarded by `queue`.
    private var delivered = false

    init(onSamples: @escaping (Data, Float) -> Void) {
        self.onSamples = onSamples
    }

    deinit {
        // Not a substitute for `stop()` - this object is owned by `SystemAudioCapture`, which stops
        // it explicitly. It is here because a tap and an aggregate device are *system* objects: if
        // this is ever released without a stop, the HAL keeps both alive with an IOProc pointing at a
        // freed block.
        teardown()
    }

    // MARK: - Lifecycle

    /// Build the tap, wrap it in a private aggregate device, and start reading.
    ///
    /// `processes` are HAL process objects - `CallSource.processObject`, which the detector has
    /// already read. Empty means "everything except Utter", which is what the ScreenCaptureKit path
    /// has always captured and is the right behaviour for a meeting recorded from the Notes screen
    /// with no call detected.
    @available(macOS 14.2, *)
    func start(processes: [AudioObjectID]) throws {
        guard !isRunning else { return }
        queue.sync { delivered = false }

        // A tap of specific processes when the call was identified, otherwise everything but our own
        // process. Excluding ourselves is not optional: Utter plays start and stop chimes and speaks,
        // and recording that back into the transcript is the defect `excludesCurrentProcessAudio`
        // exists for on the other path.
        //
        // Mono because the transcriber wants mono and mixing down in the HAL is free, where doing it
        // per buffer in Swift is not.
        let description: CATapDescription
        if processes.isEmpty {
            // Fails the whole route rather than tapping everything including ourselves. The
            // ScreenCaptureKit fallback excludes our own process structurally
            // (`excludesCurrentProcessAudio`), so "cannot exclude Utter" is a reason to use it, not a
            // reason to record Utter's chimes and speech into someone's meeting notes.
            let own = Self.ownProcessObjects()
            guard !own.isEmpty else { throw Failure.ownProcessUnknown }
            description = CATapDescription(monoGlobalTapButExcludeProcesses: own)
        } else {
            description = CATapDescription(monoMixdownOfProcesses: processes)
        }
        description.name = "Utter meeting capture"
        // Visible only inside this process, so the tap does not show up as something other apps can
        // read, and nothing outside Utter can attach to a meeting.
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var status = AudioHardwareCreateProcessTap(description, &tap)
        guard status == noErr, tap != AudioObjectID(kAudioObjectUnknown) else {
            tap = AudioObjectID(kAudioObjectUnknown)
            throw Failure.tapNotCreated(status)
        }

        // Undo everything on any later failure, so a half-built capture cannot leave a tap or an
        // aggregate device alive in the HAL.
        var started = false
        defer { if !started { teardown() } }

        guard let uid = Self.string(tap, kAudioTapPropertyUID) else {
            throw Failure.tapUIDUnreadable
        }

        // "An AudioStreamBasicDescription that describes the current data format for the tap. This is
        // the format of that data that will be accessible in any aggregate device that contains the
        // tap." - AudioHardware.h. Read once: a device change mid-meeting could in principle change
        // it, and the cost of not noticing is a window of wrong-rate audio rather than a crash, which
        // is not worth a property listener for a feature that runs for the length of one meeting.
        var asbd = AudioStreamBasicDescription()
        var asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var asbdAddress = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                                    mScope: kAudioObjectPropertyScopeGlobal,
                                                    mElement: kAudioObjectPropertyElementMain)
        status = AudioObjectGetPropertyData(tap, &asbdAddress, 0, nil, &asbdSize, &asbd)
        guard status == noErr else { throw Failure.tapFormatUnreadable(status) }
        // Refuse rather than reinterpret. Emitting Int16 read out of a buffer that turned out to hold
        // something else would be full-scale noise in a transcript, and the fallback path is right
        // there.
        guard asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 else {
            throw Failure.tapFormatNotFloat(asbd.mFormatFlags)
        }
        queue.sync { format = asbd }

        // A tap-only aggregate: no sub-device list, so the device has input streams and no output
        // streams at all. Including the default output device as a sub-device is the other documented
        // shape, and it is the worse one here - it would give the aggregate output streams that this
        // IOProc is then responsible for filling every cycle, and an unfilled output buffer is noise
        // out of the user's speakers during their meeting. `kAudioAggregateDeviceTapAutoStartKey`
        // exists precisely for tap-driven aggregates, which is what says this composition is a
        // supported one; it is not set here, because waiting for the first tapped audio before
        // starting would make "did the capture start" un-answerable.
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Utter Meeting Capture",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            // 1, not `true`. The header specifies "a CFNumber where a value of 0 means that the
            // AudioAggregateDevice is to be published to the entire system and a value of 1 means
            // that [it] is private to the process that created it" - a Swift `Bool` bridges to a
            // CFBoolean, which is a different type, and "if this key is not present, it implies that
            // the AudioAggregateDevice is published to the entire system". So getting the type wrong
            // fails in the direction of a permanent, system-visible audio device appearing in the
            // user's Sound settings.
            kAudioAggregateDeviceIsPrivateKey: 1,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: uid]],
        ]
        status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &aggregate)
        guard status == noErr, aggregate != AudioObjectID(kAudioObjectUnknown) else {
            aggregate = AudioObjectID(kAudioObjectUnknown)
            throw Failure.aggregateNotCreated(status)
        }

        status = AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregate, queue) {
            [weak self] _, input, _, output, _ in
            self?.receive(input: input, output: output)
        }
        guard status == noErr, ioProc != nil else { throw Failure.ioProcNotCreated(status) }

        // This is the call the system audio recording prompt is documented to appear on: "The first
        // time you start recording from an aggregate device that contains a tap, the system prompts
        // you to grant the app system audio recording permission." What a *denial* does to this status
        // is not something the documentation says and not something that can be established without
        // running it, so `awaitFirstAudio` is the check that does not depend on knowing.
        status = AudioDeviceStart(aggregate, ioProc)
        guard status == noErr else { throw Failure.deviceWouldNotStart(status) }

        started = true
        isRunning = true
        print("🎯 Process tap started (\(processes.isEmpty ? "everything but Utter" : "\(processes.count) process(es)"), "
              + "\(Int(asbd.mSampleRate))Hz, \(asbd.mChannelsPerFrame)ch)")
    }

    /// Whether the tap has actually produced audio yet, given `timeout` to do it in.
    ///
    /// The real capability check, and the reason this file can be wrong without hurting anyone. Every
    /// HAL call above can return `noErr` and still leave a stream that never fires - a composition
    /// the HAL accepts but cannot clock, a permission answered somewhere this code cannot see - and a
    /// tap that starts and stays silent is indistinguishable from a quiet meeting until the meeting is
    /// over and the note has half a conversation in it. `SystemAudioCapture` waits on this before it
    /// commits to the tap and falls back to ScreenCaptureKit if it comes back false.
    ///
    /// "Produced audio" means the IO block ran with frames in it, not that anything was loud: a
    /// working tap on a silent meeting delivers zeroes, and that is a success.
    func awaitFirstAudio(timeout: TimeInterval) async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while ProcessInfo.processInfo.systemUptime < deadline {
            if queue.sync(execute: { delivered }) { return true }
            // 50ms: an aggregate device's IO cycle is a few milliseconds, so this is already many
            // cycles of slack, and it costs nothing on the ordinary path where the first poll wins.
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return queue.sync { delivered }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        teardown()
        print("🎯 Process tap stopped")
    }

    /// Give every system object back, in the order that leaves nothing referencing something freed.
    ///
    /// Written to be safe to call twice and safe to call on a half-built capture: each step is
    /// guarded by its own handle and clears it, so `start`'s unwind, `stop` and `deinit` can all go
    /// through here.
    private func teardown() {
        if let ioProc {
            if aggregate != AudioObjectID(kAudioObjectUnknown) {
                AudioDeviceStop(aggregate, ioProc)
                AudioDeviceDestroyIOProcID(aggregate, ioProc)
            }
            self.ioProc = nil
        }
        if aggregate != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(aggregate)
            aggregate = AudioObjectID(kAudioObjectUnknown)
        }
        if tap != AudioObjectID(kAudioObjectUnknown) {
            // Guarded rather than annotated because `deinit` cannot carry availability. Unreachable
            // below 14.2 in any case: nothing but `start` sets this handle, and `start` needs 14.2.
            if #available(macOS 14.2, *) { AudioHardwareDestroyProcessTap(tap) }
            tap = AudioObjectID(kAudioObjectUnknown)
        }
    }

    // MARK: - The callback

    /// One IO cycle. On `queue`, not on the real-time thread - see `queue`.
    private func receive(input: UnsafePointer<AudioBufferList>,
                         output: UnsafeMutablePointer<AudioBufferList>) {
        // The aggregate is built with no output sub-device so there should be no output buffers to
        // fill, but an IOProc that leaves an output buffer untouched plays whatever was in that
        // memory, and the cost of being wrong about that is noise in the user's ears during a
        // meeting. Zeroing is a handful of instructions per cycle.
        let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
        for buffer in outputBuffers {
            if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
        }

        // `mBuffers` *is* the first element of the list's flexible array member, so buffer 0 needs no
        // pointer walking and no cast away from the const the HAL handed us. Buffer 0 is all this
        // wants: the tap is a mono mixdown, and a deinterleaved list's later buffers are the other
        // channels, which `SystemAudioPCM` deliberately does not mix.
        let list = input.pointee
        guard list.mNumberBuffers > 0 else { return }
        let first = list.mBuffers
        guard let raw = first.mData, first.mDataByteSize > 0 else { return }

        let floatCount = Int(first.mDataByteSize) / MemoryLayout<Float32>.size
        guard floatCount > 0 else { return }
        delivered = true

        let asbd = format
        let channels = max(1, Int(asbd.mChannelsPerFrame))
        let interleaved = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
        let floats = raw.bindMemory(to: Float32.self, capacity: floatCount)

        var (pcm, peak) = SystemAudioPCM.monoInt16(floats: floats,
                                                   count: floatCount,
                                                   channels: channels,
                                                   interleaved: interleaved)
        if abs(asbd.mSampleRate - 16_000) > 1, asbd.mSampleRate > 0 {
            pcm = SystemAudioPCM.resampleToSixteenK(pcm, from: asbd.mSampleRate)
        }
        guard !pcm.isEmpty else { return }
        onSamples(pcm, peak)
    }

    // MARK: - HAL reads

    /// Our own HAL process objects, to exclude from a global tap.
    ///
    /// Plural because there is no promise the HAL gives a process exactly one object, and an empty
    /// array is a survivable answer: it would mean a global tap that also hears Utter's own chimes,
    /// which is worse than the alternative but not worth failing a meeting over. The tap of a *known*
    /// process - the normal case when a call was detected - never comes through here.
    private static func ownProcessObjects() -> [AudioObjectID] {
        var pid = ProcessInfo.processInfo.processIdentifier
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                UInt32(MemoryLayout<pid_t>.size),
                                                &pid,
                                                &size,
                                                &object)
        // "Note that an error is not returned if the PID doesn't refer to any Process. Rather, this
        // property will return kAudioObjectUnknown" - AudioHardware.h. So the object has to be
        // checked as well as the status.
        guard status == noErr, object != AudioObjectID(kAudioObjectUnknown) else { return [] }
        return [object]
    }

    /// A CFString property, as a Swift string.
    ///
    /// The +1 the HAL hands back is balanced by ARC releasing the `CFString?` variable it was written
    /// into; there is deliberately no `CFRelease` here. Same reasoning as `CallDetector.bundleID`.
    private static func string(_ object: AudioObjectID,
                              _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        let string = value as String
        return string.isEmpty ? nil : string
    }
}
