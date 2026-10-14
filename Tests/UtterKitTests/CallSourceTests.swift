import Testing
import Foundation
@testable import UtterKit
@testable import UtterCore

/// Naming the app a call is happening in.
///
/// `CallSource`'s HAL reads cannot be tested on this machine - they depend on which processes happen
/// to be playing audio right now - but every rule about *what to call* what they find is a function of
/// two strings, and all of it is here. That split is the whole reason the type exists separately from
/// `CallDetector`, the same way `CallPresence` does.
///
/// Two of these guard something more than tidiness. `sanitised` is a trust boundary: the name comes
/// from another application and is written into the user's note as a markdown heading. And
/// `offerTitle` feeds `MeetingOfferMetrics.height`, where a title of an unexpected length lays the
/// card's buttons out below the window's bottom edge.
@Suite("Call source naming")
struct CallSourceTests {

    // MARK: Which name wins

    @Test("An app nobody listed is named from what the system calls it")
    func systemNameForUnlistedApps() {
        // The case the whole design turns on: a conferencing app that did not exist when this shipped
        // still gets named, because the first choice is never the table.
        #expect(CallSource.appName(bundleID: "com.example.NewMeetingApp",
                                   systemName: "New Meeting App") == "New Meeting App")
        #expect(CallSource.appName(bundleID: nil, systemName: "Microsoft Teams") == "Microsoft Teams")
    }

    @Test("A recognised prefix overrides a name the system reports badly")
    func tableCorrectsKnownBadNames() {
        // Both of these were read off this machine's process list. Zoom's own `localizedName` is
        // "zoom.us", while Slack's audio helper has no useful system name.
        #expect(CallSource.appName(bundleID: "us.zoom.xos", systemName: "zoom.us") == "Zoom")
        #expect(CallSource.appName(bundleID: "com.tinyspeck.slackmacgap.helper",
                                   systemName: nil) == "Slack")
        #expect(CallSource.appName(bundleID: "com.microsoft.teams2.helper",
                                   systemName: nil) == "Microsoft Teams")
    }

    @Test("Nothing usable means no name, never a guess from the bundle ID")
    func noNameRatherThanAGuess() {
        #expect(CallSource.appName(bundleID: nil, systemName: nil) == nil)
        // "You're in a com.unknown.helper call" is worse than "You're in a call", so an unrecognised
        // bundle ID with no system name yields nothing at all.
        #expect(CallSource.appName(bundleID: "com.unknown.helper", systemName: nil) == nil)
        #expect(CallSource.appName(bundleID: "", systemName: "") == nil)
    }

    @Test("Safari's WebKit GPU process is deliberately not in the table")
    func webKitGPUIsNotNamed() {
        // Every WebKit host on the machine shares `com.apple.WebKit.GPU` - this machine had two, for
        // Zoom and for Outlook - so mapping that prefix to any one app would confidently name the
        // wrong one. It falls through to the system name, which is at least the truth.
        #expect(CallSource.knownName(bundleID: "com.apple.WebKit.GPU") == nil)
    }

    @Test("Only dedicated calling apps may trigger automatic offers")
    func automaticCallFamilies() {
        #expect(CallSource.knownName(bundleID: "us.zoom.xos") == "Zoom")
        #expect(CallSource.knownName(bundleID: "com.microsoft.teams2.helper")
                == "Microsoft Teams")
        #expect(CallSource.knownName(bundleID: "com.apple.FaceTime")
                == "FaceTime")
        #expect(CallSource.knownName(bundleID: "Cisco-Systems.Spark.helper")
                == "Webex")
        #expect(CallSource.knownName(bundleID: "org.whispersystems.signal-desktop.helper")
                == "Signal")
        #expect(CallSource.knownName(bundleID: "net.whatsapp.WhatsApp")
                == "WhatsApp")
        #expect(CallSource.knownName(bundleID: "com.ringcentral.glip.helper")
                == "RingCentral")
        #expect(CallSource.knownName(bundleID: "org.jitsi.jitsi-meet")
                == "Jitsi Meet")
        #expect(CallSource.knownName(bundleID: "com.google.Chrome.helper") == nil)
        #expect(CallSource.knownName(bundleID: "com.microsoft.Edge.helper") == nil)
        #expect(CallSource.knownName(bundleID: "com.apple.WebKit.GPU") == nil)
    }

    @Test("The supported app table has no duplicate prefixes")
    func supportedPrefixesAreUnique() {
        let prefixes = CallSource.automaticCallApps.map(\.prefix)
        #expect(Set(prefixes).count == prefixes.count)
    }

    // MARK: The trust boundary

    @Test("A name that spans lines is flattened, not left to split the note heading")
    func newlinesAreFlattened() {
        // The name is interpolated into "# <name> meeting - …", the note's first line, which
        // `Note.derivedTitle` turns into its title. A newline in it would end the heading early and
        // leave the rest of the app's chosen string as body text.
        #expect(CallSource.sanitised("Zoom\nMeeting") == "Zoom Meeting")
        #expect(CallSource.sanitised("Zoom\r\n\tMeeting") == "Zoom Meeting")
        #expect(CallSource.sanitised("  Zoom  ") == "Zoom")
        let heading = CallSource.noteHeading(appName: CallSource.appName(bundleID: nil,
                                                                        systemName: "Evil\nApp"),
                                             when: "Aug 17, 2:31 PM")
        #expect(heading.filter { $0 == "\n" }.count == 1, "the heading gained a line: \(heading)")
    }

    @Test("Markdown spans are stripped out of the name")
    func markdownIsStripped() {
        #expect(CallSource.sanitised("`Zoom`") == "Zoom")
        #expect(CallSource.sanitised("**Zoom**") == "Zoom")
    }

    @Test("A name with nothing printable in it is no name")
    func emptyAfterSanitisingIsNil() {
        #expect(CallSource.sanitised("") == nil)
        #expect(CallSource.sanitised("   \n\t ") == nil)
        #expect(CallSource.sanitised("***") == nil)
    }

    @Test("A very long name is capped")
    func longNamesAreCapped() {
        let long = String(repeating: "A", count: 200)
        let capped = CallSource.sanitised(long)
        #expect(capped?.count == CallSource.maximumNameLength)
        // A capped name still has to be a name - an app called nothing but spaces past the cap must
        // not leave a trailing space in "You're in a … call".
        #expect(CallSource.sanitised(String(repeating: "Ab ", count: 40))?.hasSuffix(" ") == false)
    }

    // MARK: Copy

    @Test("The card's title names the app when there is one")
    func offerTitle() {
        #expect(CallSource.offerTitle(appName: "Zoom") == "You\u{2019}re in a Zoom call")
        // A supported app's helper can still lack a usable display name.
        #expect(CallSource.offerTitle(appName: nil) == "You\u{2019}re in a call")
        #expect(MeetingOfferMetrics.defaultTitle == CallSource.offerTitle(appName: nil))
    }

    @Test("The note's heading names the app, and stays a markdown heading either way")
    func noteHeading() {
        #expect(CallSource.noteHeading(appName: "Zoom", when: "Aug 17, 2:31 PM")
                == "# Zoom meeting, Aug 17 at 2:31 PM\n")
        #expect(CallSource.noteHeading(appName: nil, when: "Oct 12, 7:21 PM")
                == "# Meeting, Oct 12 at 7:21 PM\n")
        // And what the user actually sees in the notes list, via the same function the store uses.
        #expect(Note.derivedTitle(from: CallSource.noteHeading(appName: "Zoom", when: "Aug 17"))
                == "Zoom meeting, Aug 17")
    }
}
