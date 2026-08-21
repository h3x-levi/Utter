import AudioToolbox
import Foundation

/// Which app a call's audio is coming out of, when CoreAudio will say.
///
/// Split from `CallDetector` for the reason `CallPresence` is: the naming rules are pure and can be
/// tested on this machine, while the HAL reads cannot. Everything here is a value and a function of
/// its arguments.
///
/// **This names a call; it never decides there is one.** `kAudioProcessPropertyBundleID` is one
/// extra property read on process objects the detector already enumerates, so it is cheap — but it
/// is not evidence. The most common way to be in a meeting is Google Meet or Teams in a browser tab,
/// which reports the *browser's* bundle ID and is indistinguishable from a YouTube video in another
/// window. So a bundle ID may only ever add a name to a call that
/// `kAudioProcessPropertyIsRunningInput`/`IsRunningOutput` already established, and a call in an app
/// nobody has heard of is detected exactly as before, just called "a call".
///
/// **Where the name comes from, and why not from a table.** A hardcoded pretty-name list goes stale
/// the moment a new conferencing app ships, so the first choice is always the app's own
/// `NSRunningApplication.localizedName` — an app nobody listed still gets named correctly. `renamed`
/// below exists only to override the handful of names the system itself reports unusably, which is a
/// closed set that does not grow with the market:
///
///   * The process doing the audio is often a *helper*, which is not an `NSRunningApplication` at
///     all. Read off this machine: `com.google.Chrome.helper` and
///     `com.tinyspeck.slackmacgap.helper`, whose `localizedName` is either nil or the literally
///     unhelpful "Google Chrome Helper".
///   * Some apps have a bad name of their own. `us.zoom.xos` reports `localizedName` "zoom.us".
///
/// So the rule is: a recognised prefix wins (it is a correction), otherwise the system's own name,
/// otherwise no name at all. Guessing a name out of a bundle ID is not attempted — "You're in a
/// com.google.Chrome.helper call" is worse than "You're in a call".
///
/// **On Zoom's and Teams' virtual audio devices.** Both install one ("ZoomAudioDevice", "Microsoft
/// Teams Audio" — both were enumerated on this machine even with neither app in a meeting). They are
/// *not* used as corroboration and should not be: their presence says the app is installed, not that
/// it is in a call, and the process signal already says the stronger thing per direction and per
/// process. Reading device names would add a second mechanism to answer a question the first one
/// already answers better.
struct CallSource: Equatable {

    /// The HAL process object doing the audio.
    ///
    /// Kept because it is exactly what a Core Audio process tap takes — see `ProcessTapCapture` —
    /// so identifying the call and capturing only the call are the same fact, read once.
    let processObject: AudioObjectID

    let pid: pid_t

    /// The process's bundle ID, or nil if it does not have one or would not answer. Nil is ordinary,
    /// not an error: several processes on this machine report an empty bundle ID.
    let bundleID: String?

    /// What to call it on screen, already sanitised, or nil when nothing usable was found.
    let appName: String?

    /// Whether the bundle ID is one of the few `renamed` knows. Used only to break a tie between
    /// candidate processes and to name one; never to qualify a call.
    var isRecognised: Bool { Self.knownName(bundleID: bundleID) != nil }
}

extension CallSource {

    // MARK: - The one small table

    /// Bundle-ID prefixes whose own reported name is unusable, and what to call them instead.
    ///
    /// Prefixes rather than exact IDs because the audio nearly always comes from a helper process:
    /// Chrome's is `com.google.Chrome.helper`, Edge's `com.microsoft.Edge.helper`. Kept to the cases
    /// actually observed rather than padded out with every conferencing app on the market — an
    /// unlisted app is named from `localizedName`, which is the whole reason this can stay short.
    ///
    /// Not here on purpose: Safari. Its audio comes out of `com.apple.WebKit.GPU`, which is shared
    /// with every other WebKit host on the machine (this machine had two, for Zoom and Outlook), so
    /// mapping that prefix to "Safari" would confidently name the wrong app. Unnamed is better.
    static let renamed: [(prefix: String, name: String)] = [
        ("us.zoom", "Zoom"),                    // localizedName is "zoom.us"
        ("com.google.Chrome", "Chrome"),        // audio is com.google.Chrome.helper
        ("com.microsoft.Edge", "Edge"),         // same helper shape as Chrome
        ("com.tinyspeck.slackmacgap", "Slack"), // localizedName is "Slack Helper"
        ("com.hnc.Discord", "Discord"),         // audio is com.hnc.Discord.helper
    ]

    /// The corrected name for a bundle ID, if it is one of the few in `renamed`.
    static func knownName(bundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return renamed.first { bundleID.hasPrefix($0.prefix) }?.name
    }

    // MARK: - Naming

    /// The longest name worth showing.
    ///
    /// The offer card is 268pt wide and the meeting note's heading becomes the note's *title*, so an
    /// app with a paragraph for a name would wrap the card's title into the button row and make the
    /// note unfindable in the list. 32 is comfortably past every real app name observed
    /// ("Microsoft Teams" is 15) and short of anything that could do damage.
    static let maximumNameLength = 32

    /// What to call the app behind a call, or nil if nothing usable is available.
    ///
    /// `systemName` is `NSRunningApplication.localizedName` for the process's pid. Resolved here,
    /// as a function of two strings, so the precedence and the sanitising are testable without a
    /// running process.
    ///
    /// **This is a trust boundary.** Both inputs come from *another* application, and the result is
    /// rendered in Utter's UI and written into the user's note as a markdown heading. A name
    /// containing a newline would split that heading in two and change what `Note.derivedTitle`
    /// picks up; one containing a `#` or backticks would inject markdown. So the name is flattened
    /// to a single line of printable characters and capped, and a name with nothing left after that
    /// is treated as no name.
    static func appName(bundleID: String?, systemName: String?) -> String? {
        // A recognised prefix is a deliberate correction of a name the system reports badly, so it
        // outranks `systemName`. Everything else prefers what the app calls itself.
        let raw = knownName(bundleID: bundleID) ?? systemName
        guard let raw else { return nil }
        return sanitised(raw)
    }

    /// A single line of printable characters, trimmed and capped, or nil if nothing is left.
    static func sanitised(_ name: String) -> String? {
        // Newlines and control characters are collapsed rather than stripped, so "Zoom\nMeeting"
        // becomes "Zoom Meeting" and not "ZoomMeeting".
        let flattened = name.unicodeScalars
            .map { scalar -> Character in
                if scalar.properties.isWhitespace || CharacterSet.controlCharacters.contains(scalar) {
                    return " "
                }
                return Character(scalar)
            }
        // Markdown that would change the shape of the note's heading. Only the characters that are
        // structural at the *start* of a line matter for a heading, but the name is interpolated
        // mid-line, so what has to go is anything that could open a span the rest of the line lands
        // inside: backticks and asterisks.
        let cleaned = String(flattened).filter { $0 != "`" && $0 != "*" }
        let collapsed = cleaned.split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > maximumNameLength else { return collapsed }
        return String(collapsed.prefix(maximumNameLength)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Copy

    /// The offer card's title: "You're in a Zoom call", or "You're in a call" when the app is not
    /// identifiable — which is the ordinary case for a meeting in a browser tab, not a failure.
    static func offerTitle(appName: String?) -> String {
        guard let appName else { return "You\u{2019}re in a call" }
        return "You\u{2019}re in a \(appName) call"
    }

    /// The meeting note's first line, which `Note.derivedTitle` turns into the note's title by
    /// stripping the `#`.
    ///
    /// `when` is passed already formatted rather than a `Date`, so this stays pure and the test does
    /// not depend on the machine's locale or time zone.
    static func noteHeading(appName: String?, when: String) -> String {
        guard let appName else { return "# Meeting \u{2014} \(when)\n" }
        return "# \(appName) meeting \u{2014} \(when)\n"
    }
}
