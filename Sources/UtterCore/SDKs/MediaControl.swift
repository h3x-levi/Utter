import Cocoa

/// Pauses and resumes other apps' audio around a dictation turn.
///
/// macOS has no `AVAudioSession`, so an app cannot declare "I need the audio
/// focus" the way it can on iOS. What it *can* do is send the same system-defined
/// event the play/pause key on the keyboard sends, which every media app already
/// listens for - Music, Spotify, browsers, VLC. That is deliberately the same
/// mechanism the hardware key uses rather than a private framework: MediaRemote
/// would give finer control but it is unsupported API.
///
/// The consequence of using a *toggle* is that this type has to track whether it
/// was the one that paused playback, so it never resumes audio the user had
/// already stopped themselves.
package enum MediaControl {
    /// The output probe is CoreAudio IPC, so it stays off main; serial, so a resume never overtakes its pause.
    private static let queue = DispatchQueue(label: "utter.media-control", qos: .userInitiated)
    /// True when `pauseIfPlaying()` sent a pause that has not yet been undone. Confined to `queue`.
    private nonisolated(unsafe) static var didPause = false

    /// Pause other audio, if the preference is on and another app is playing some.
    ///
    /// The key is a toggle, so with nothing playing it would start the last player. The only
    /// signal available is CoreAudio's per-process "running output"; where the system will not
    /// answer, nothing is sent.
    package static func pauseIfPlaying() {
        guard UserData.shared.muteMusicWhileDictating else { return }
        queue.async {
            guard !didPause, CallDetector.audioInUseByOtherProcesses()?.output == true else { return }
            didPause = true
            DispatchQueue.main.async(execute: sendPlayPause)
        }
    }

    /// Resume audio, but only if this type paused it.
    package static func resumeIfPaused() {
        queue.async {
            guard didPause else { return }
            didPause = false
            DispatchQueue.main.async(execute: sendPlayPause)
        }
    }

    /// Emit NX_KEYTYPE_PLAY down then up.
    ///
    /// The magic numbers are the documented layout of an `NSSystemDefined`
    /// event's `data1`: the key code in the high 16 bits, the state in bits 8-15.
    /// `0xA` is `NX_KEYTYPE_PLAY`.
    private static func sendPlayPause() {
        let playKey: Int32 = 0x0A
        for isDown in [true, false] {
            let data1 = Int((playKey << 16) | ((isDown ? 0x0A : 0x0B) << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: 0xA00),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,               // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                data1: data1,
                data2: -1
            ), let cgEvent = event.cgEvent else { continue }
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}
