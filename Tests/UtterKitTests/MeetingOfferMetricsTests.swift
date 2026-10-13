import Testing
import AppKit
@testable import UtterKit
@testable import UtterCore

/// The offer card's size, which is the window's size.
///
/// Tested for the same reason `Layout.size` and `CompanionGeometry` are: the number is baked into a
/// borderless panel at creation, `hosting.sizingOptions = []` forbids the window growing to fit, and
/// the content is top-aligned - so a number that is too small does not squeeze the card, it lays part
/// of it out below the window's bottom edge, where nothing composites and no click lands.
///
/// It shipped at a hardcoded 96pt against 133.5pt of content. The 37.5pt overflow was the button row,
/// so the card appeared with neither button reachable and the feature could not be used at all. These
/// measure the real strings and a real control rather than re-deriving the metrics' own arithmetic.
@Suite("Meeting offer card")
// On the main actor because these measure real AppKit objects: `NSButton.fittingSize` drives Auto
// Layout, and the layout engine throws `NSInternalInconsistencyException` when it is touched from a
// background thread after the main one has used it. Swift Testing runs cases concurrently off the
// main thread by default, which crashed the whole run rather than failing a case. `PillHitRegionTests`
// is annotated for the same reason.
@MainActor
struct MeetingOfferMetricsTests {

    /// What the card's three rows actually measure, by an independent path: AppKit text measurement
    /// for the two labels and a real `NSButton`'s fitting size for the row of buttons.
    ///
    /// The title is *wrapped* here rather than allowed one line, because it is no longer a constant:
    /// `CallSource.offerTitle` puts the app's name in it, so it is as long as whatever app the user is
    /// in a call in.
    private func measuredContentHeight(title: String = MeetingOfferMetrics.defaultTitle) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = MeetingOfferMetrics.captionLineSpacing
        paragraph.lineBreakMode = .byWordWrapping

        func wrapped(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
            NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph])
                .boundingRect(with: NSSize(width: width, height: .greatestFiniteMagnitude),
                              options: [.usesLineFragmentOrigin, .usesFontLeading])
                .height
        }

        let titleFont = NSFont.systemFont(ofSize: 15, weight: .medium)
        let titleHeight = max(NSLayoutManager().defaultLineHeight(for: titleFont),
                              wrapped(title, font: titleFont, width: MeetingOfferMetrics.titleWidth))
        let caption = wrapped(MeetingOfferMetrics.caption,
                              font: NSFont.systemFont(ofSize: 12),
                              width: MeetingOfferMetrics.contentWidth)

        let button = NSButton(title: "Transcribe", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large

        return MeetingOfferMetrics.padding * 2
            + titleHeight
            + MeetingOfferMetrics.rowSpacing * 2
            + caption
            + button.fittingSize.height
    }

    @Test("The card is tall enough for everything in it")
    func contentFitsTheWindow() {
        let needed = measuredContentHeight()
        #expect(MeetingOfferMetrics.height() >= needed,
                "\(MeetingOfferMetrics.height())pt of card for \(needed)pt of content: the overflow lands below the window, where it cannot be clicked")
    }

    @Test("A title carrying a long app name grows the card instead of overflowing it")
    func aLongAppNameGrowsTheCard() {
        // The defect this parameter exists for. "You're in a Microsoft Teams call" does not fit the
        // title column beside the icon, so it wraps to two lines - and a card sized for one line puts
        // the extra line's worth of content below the window's bottom edge, taking the button row with
        // it. Which is exactly how this feature shipped unusable the first time.
        let long = CallSource.offerTitle(appName: "Microsoft Teams")
        #expect(MeetingOfferMetrics.titleHeight(long)
                > MeetingOfferMetrics.lineHeight(MeetingOfferMetrics.titleFont),
                "\"\(long)\" now fits one line in a \(MeetingOfferMetrics.titleWidth)pt column, so this case is stale")
        #expect(MeetingOfferMetrics.height(title: long) > MeetingOfferMetrics.height())
        #expect(MeetingOfferMetrics.height(title: long) >= measuredContentHeight(title: long))
        #expect(MeetingOfferMetrics.size(title: long).width == MeetingOfferMetrics.width)
    }

    @Test("The longest name a call source can carry still fits the card")
    func theLongestPossibleTitleFits() {
        // `CallSource.maximumNameLength` is the cap on a name taken from another application, so this
        // is the widest title that can ever reach the card. Measured in the widest characters the cap
        // allows, because a cap in characters is not a cap in points.
        let widest = CallSource.offerTitle(appName: String(repeating: "W",
                                                          count: CallSource.maximumNameLength))
        #expect(MeetingOfferMetrics.height(title: widest) >= measuredContentHeight(title: widest))
    }

    @Test("The title has a column of its own, narrower than the caption's")
    func theTitleColumnAllowsForItsIcon() {
        // The title shares its row with a 13pt symbol, so it wraps against less width than the caption
        // does. Measuring it against `contentWidth` would under-count a title that is close to the
        // edge, which is the case that matters.
        #expect(MeetingOfferMetrics.titleWidth < MeetingOfferMetrics.contentWidth)
        #expect(MeetingOfferMetrics.titleIconWidth > 0)
    }

    @Test("The card never goes back below what the content was measured at")
    func theCardClearsTheMeasuredRequirement() {
        // 133.5pt, measured on macOS 26.6: 32 padding + 18 title + 24 spacing + 31.5 caption + 28
        // buttons. A plain number rather than the expression above, so that shrinking a token or
        // trimming the copy cannot quietly take the card back under the size it was broken at. The
        // derived-vs-measured comparison is `contentFitsTheWindow`'s job, and it is the one that
        // holds if a future release moves the font metrics.
        #expect(MeetingOfferMetrics.height() >= 133.5)
    }

    @Test("The caption wraps, and the card allows for that")
    func theCaptionWrapsToMoreThanOneLine() {
        // The specific thing the 96pt guess got wrong. The caption is a whole sentence in a 236pt
        // column and it is `.fixedSize(vertical: true)` in the view, so its wrapped height is
        // incompressible - the card cannot shrink it to fit.
        let single = NSAttributedString(
            string: MeetingOfferMetrics.caption,
            attributes: [.font: MeetingOfferMetrics.captionFont]
        ).size().width
        #expect(single > MeetingOfferMetrics.contentWidth,
                "the caption now fits one line, so the two-line allowance is stale")

        let oneLine = MeetingOfferMetrics.lineHeight(MeetingOfferMetrics.captionFont)
        #expect(MeetingOfferMetrics.captionHeight(MeetingOfferMetrics.caption) > oneLine)
    }

    @Test("There is head-room over the derived height")
    func slackIsReal() {
        // Budgeted for the thing a test on this machine cannot measure: font metrics are not ours to
        // promise across releases, and the title and caption are measured with them.
        //
        // It used to also cover SwiftUI's `.glass` button style at `.controlSize(.large)` drawing
        // taller than the AppKit fitting height below. The card's buttons are `OfferButtonStyle` now,
        // which pins its height to `buttonRowHeight`, so the button row is no longer the system's to
        // change - see `theButtonRowHeightHoldsALargeControl`.
        #expect(MeetingOfferMetrics.slack > 0)
        #expect(MeetingOfferMetrics.height() > measuredContentHeight())
    }

    @Test("The pinned button row is tall enough for a large control")
    func theButtonRowHeightHoldsALargeControl() {
        // `buttonRowHeight` stopped being an estimate of what the system would draw and became what
        // the card *imposes*: `OfferButtonStyle` frames its buttons to exactly this height, on every
        // render path, so that the row the window is sized for is the row that lays out.
        //
        // Which moves the risk. It is no longer "the system draws taller than we allowed" - the
        // metrics catch that - it is "we pinned the row shorter than its own label needs", and the
        // symptom is clipped or crushed button text rather than an overflowing window, so none of the
        // height assertions above would see it. A real large-bezel `NSButton` is the independent
        // floor: it is where the 28 came from, and it is what a macOS control of this class measures.
        let button = NSButton(title: "Transcribe", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large
        #expect(MeetingOfferMetrics.buttonRowHeight >= button.fittingSize.height,
                "a \(MeetingOfferMetrics.buttonRowHeight)pt row for a \(button.fittingSize.height)pt control: the label is being squeezed, not the window")
    }

    @Test("A failure message makes the card taller, by what the message measures")
    func aFailureMessageGrowsTheCard() {
        // The card carries the reason a capture could not start - the Screen Recording sentence,
        // which wraps to several lines - and the window has to grow with it or the message pushes
        // the buttons out of the window all over again.
        let message = SystemAudioCapture.PermissionState.denied.message
        let grew = MeetingOfferMetrics.height(message: message) - MeetingOfferMetrics.height()
        let owed = MeetingOfferMetrics.rowSpacing + MeetingOfferMetrics.captionHeight(message)
        // Within a point of what the message needs: both heights are rounded up, so they can differ
        // from the raw arithmetic by that much and no more.
        #expect(abs(grew - owed) <= 1, "the card grew \(grew)pt for a \(owed)pt message")
        #expect(MeetingOfferMetrics.size(message: message).width == MeetingOfferMetrics.width)
    }

    @Test("An empty message is not a message")
    func anEmptyMessageDoesNotGrowTheCard() {
        #expect(MeetingOfferMetrics.height(message: "") == MeetingOfferMetrics.height())
    }
}
