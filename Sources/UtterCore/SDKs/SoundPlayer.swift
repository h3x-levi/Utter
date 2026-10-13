import Cocoa

/// Plays custom UI sounds for recording feedback.
package struct SoundPlayer {

    /// Playback level for the bundled assets.
    ///
    /// Softness is a property of the assets themselves - long raised-cosine
    /// attacks, low fundamentals, exponential tails (see
    /// `scripts/generate_sounds.py`) - not of this number. Turning a sharp sound
    /// down only makes it faint; it stays sharp. The assets are peak-normalised
    /// to −7.5 dBFS, which lands this at roughly −27 dBFS RMS: audible over
    /// typing and room noise without asking for attention.
    private static let volume: Float = 0.45

    /// The queue every sound is loaded and started on.
    ///
    /// **Playback used to happen inline on the main thread, and it was the app's worst
    /// run-loop stall.** `NSSound.play()` starts a CoreAudio device synchronously: profiled on
    /// an M4, one `play` cost ~49ms of main-thread wall time with ~31ms of it hard-blocked in
    /// `HALB_IOThread::StartAndWaitForState` -> `_pthread_cond_wait`, waiting for the audio I/O
    /// thread to reach state. The companion answers keystrokes, so during a typing burst this
    /// fired as often as every 360ms - a repeated stall at exactly the moment the user is
    /// typing and most likely to notice one.
    ///
    /// Serial rather than concurrent because it also confines `cache`: the sounds are only ever
    /// touched here, so a dictionary of shared `NSSound`s needs no lock. Nothing else about the
    /// class is thread-confined - the preference gates stay on the caller's thread, where
    /// `UserData` is safe to read.
    private static let queue = DispatchQueue(label: "utter.dictation.sounds", qos: .userInitiated)

    /// Loaded sounds, keyed by name. Confined to `queue`.
    ///
    /// Rebuilding an `NSSound` per play also rebuilt an `AVAudioPlayer`, an `AudioQueue` and two
    /// `AudioConverter`s, then tore them all down - measured at 33 AudioQueue create/destroy
    /// cycles and 66 converters in three minutes of ordinary typing, which was additionally
    /// responsible for about 99% of the process's system-log traffic. Holding the objects makes a
    /// repeat play a `play()` on an instrument that is already built.
    private static var cache: [String: NSSound] = [:]

    /// Where the bundled `.wav` assets might be, resolved once.
    ///
    /// This was three `URL`s rebuilt from `ProcessInfo.arguments[0]` on every single play. The
    /// answer cannot change while the process is alive, so it is computed once.
    private static let searchRoots: [URL] = {
        let binaryURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        return [
            // Inside .app bundle: Contents/Resources/Sounds/
            binaryURL.deletingLastPathComponent() // MacOS/
                .deletingLastPathComponent() // Contents/
                .appendingPathComponent("Resources/Sounds"),
            // Dev: running from .build/release/ - Sounds/ is at project root
            binaryURL.deletingLastPathComponent() // release/
                .deletingLastPathComponent() // .build/
                .deletingLastPathComponent() // project root
                .appendingPathComponent("Sounds"),
            // Dev: running from project root directly
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sounds"),
        ]
    }()

    private static func play(_ name: String) {
        // A single gate for every cue. Checked here rather than at the call
        // sites so a new sound can't be added that ignores the preference.
        guard UserData.shared.soundsEnabled else { return }
        queue.async { emit(name) }
    }

    /// Load-if-needed and start one sound. **Runs on `queue` only.**
    private static func emit(_ name: String) {
        if let sound = cache[name] {
            // A shared instance cannot play two overlapping copies of itself, so a retrigger
            // restarts it. That is a real change from constructing a new `NSSound` per play,
            // which let copies stack - and it is the better behaviour: the cues mark state
            // transitions, where hearing the newest one is the point.
            if sound.isPlaying { sound.stop() }
            // `stop()` returns before the device has finished tearing down, so a `play()` issued
            // straight after can be refused. The result was discarded, which turned a refusal into
            // permanent silence for that cue - the instrument stays cached and every later play
            // hits the same dead object. Dropping it from the cache costs one rebuild next time.
            if !sound.play() { cache[name] = nil }
            return
        }

        for root in searchRoots {
            let url = root.appendingPathComponent("\(name).wav")
            if let sound = NSSound(contentsOf: url, byReference: true) {
                sound.volume = Self.volume
                cache[name] = sound
                sound.play()
                return
            }
        }

        // Fallback to system sounds. These are the OS's own alert tones, which
        // are considerably brighter and more percussive than Utter's assets, so
        // they play quieter - matching the *number* would not match the
        // loudness.
        let fallbacks = ["start": "Tink", "stop": "Pop", "done": "Morse", "error": "Basso"]
        if let sysName = fallbacks[name], let sound = NSSound(named: NSSound.Name(sysName)) {
            sound.volume = Self.volume * 0.6
            // Cached under the requested name, so a missing asset costs one failed lookup per
            // launch rather than one per play.
            cache[name] = sound
            sound.play()
        }
    }

    /// Pre-warms the core audio cues into memory asynchronously to eliminate disk I/O latency
    /// on the first dictation attempt.
    package static func preload() {
        queue.async {
            for name in ["start", "stop", "done", "error"] {
                guard cache[name] == nil else { continue }
                for root in searchRoots {
                    let url = root.appendingPathComponent("\(name).wav")
                    if let sound = NSSound(contentsOf: url, byReference: true) {
                        sound.volume = Self.volume
                        cache[name] = sound
                        break
                    }
                }
            }
        }
    }

    package static func playStart() { play("start") }
    package static func playStop() { play("stop") }
    package static func playDone() { play("done") }
    package static func playError() { play("error") }

    /// A reminder takes the soft done cue, off with either the dictation or the companion sounds.
    package static func playReminder() {
        guard UserData.shared.companionSounds else { return }
        play("done")
    }
}
