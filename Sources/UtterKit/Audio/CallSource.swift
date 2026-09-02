import AudioToolbox
import Foundation

/// Which app a call's audio is coming out of, when CoreAudio will say.
///
/// Split from `CallDetector` for the reason `CallPresence` is: the naming rules are pure and can be
/// tested on this machine, while the HAL reads cannot. Everything here is a value and a function of
/// its arguments.
///
/// Automatic offers are deliberately limited to dedicated calling apps. A browser reports the same
/// bundle ID for Meet and YouTube, so its audio activity cannot safely distinguish a call from media
/// playback. `automaticCallFamily` is therefore the allowlist used by the detector; browser meetings
/// remain available through the explicit "Record a meeting" action in Notes.
///
/// **Where the name comes from.** Supported apps are identified by bundle family because helper
/// processes often have no `NSRunningApplication.localizedName` at all. The same table supplies the
/// stable display name, while an unlisted process still falls back to the name macOS reports:
///
///   * The process doing the audio is often a *helper*, which is not an `NSRunningApplication` at
///     all. Read off this machine: `com.tinyspeck.slackmacgap.helper`, whose `localizedName` is nil
///     or the literally unhelpful "Slack Helper".
///   * Some apps have a bad name of their own. `us.zoom.xos` reports `localizedName` "zoom.us".
///
/// So the rule is: a supported prefix wins, otherwise the system's own name, otherwise no name at
/// all. Browsers are intentionally absent.
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

}

extension CallSource {

    // MARK: - Supported calling apps

    /// Dedicated app bundle families allowed to trigger an automatic offer.
    ///
    /// These are bundle-family prefixes because Electron clients often put input and output in
    /// separate helpers. Browsers are intentionally absent: no local audio signal can tell a Meet
    /// tab from YouTube without inspecting private browser state.
    static let automaticCallApps: [(prefix: String, name: String)] = [
        ("us.zoom", "Zoom"),
        ("com.microsoft.teams", "Microsoft Teams"),
        ("com.apple.FaceTime", "FaceTime"),
        ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.hnc.Discord", "Discord"),
        ("Cisco-Systems.Spark", "Webex"),
        ("com.cisco.webex", "Webex"),
        ("com.skype.skype", "Skype"),
        ("net.whatsapp.WhatsApp", "WhatsApp"),
        ("org.whispersystems.signal-desktop", "Signal"),
        ("ru.keepcoder.Telegram", "Telegram"),
        ("com.viber.osx", "Viber"),
        ("com.ringcentral.glip", "RingCentral"),
        ("com.logmein.GoToMeeting", "GoTo Meeting"),
        ("com.goto.GoTo", "GoTo"),
        ("com.amazon.Amazon-Chime", "Amazon Chime"),
        ("com.amazon.Chime", "Amazon Chime"),
        ("org.jitsi.jitsi-meet", "Jitsi Meet"),
        ("jp.naver.line.mac", "LINE"),
        ("com.tencent.xinWeChat", "WeChat"),
        ("com.kakao.KakaoTalkMac", "KakaoTalk"),
    ]

    /// The stable display name for a supported calling app.
    static func knownName(bundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return automaticCallApps.first { bundleID.hasPrefix($0.prefix) }?.name
    }

    static func automaticCallFamily(bundleID: String?) -> String? {
        knownName(bundleID: bundleID)
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
        // A supported prefix provides a stable name even for helper processes; everything else
        // prefers what the app calls itself.
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

    /// The offer card's title: "You're in a Zoom call", or "You're in a call" when a supported
    /// app's helper process has no usable name.
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
