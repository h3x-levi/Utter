import AppKit
import QuartzCore
import SwiftUI

/// The offer card's geometry.
///
/// A pure type with tests, for the reason `PillMetrics`, `CompanionGeometry` and `Layout.size` are:
/// the card's height is a fixed number the window is *created* with, and getting it wrong is not a
/// cosmetic defect. `hosting.sizingOptions = []` forbids the window growing to fit - deliberately,
/// see the collapse `showMainWindow` documents - and the content is top-aligned, so anything the
/// number does not allow for is laid out below the window's bottom edge, where nothing composites
/// and no mouse event lands.
///
/// It shipped as a hardcoded 96pt against 133.5pt of content: padding 32, an 18pt title row, two
/// 12pt gaps, a caption that wraps to two lines at 31.5pt, and a 28pt button row. The 37pt that did
/// not fit was the entire button row, so the feature could not be used at all - the card appeared
/// and neither button existed. Hence the arithmetic living here, derived from the same tokens the
/// view lays out with, with a test that measures the real strings and the real control.
enum MeetingOfferMetrics {

    /// The card's title when the app holding the call could not be identified.
    ///
    /// Here rather than inline in the view because the height depends on how many lines it wraps to,
    /// and the test that pins the height has to measure the string the user actually sees.
    ///
    /// The title is no longer a constant: `CallSource.offerTitle` names the app when CoreAudio will
    /// say which one it is, so the card can read "You're in a Zoom call". That is why `height` takes
    /// the title as a parameter and *measures* it rather than allowing it one line. A hardcoded
    /// single-line allowance was fine for a fixed 17-character string and is a bug the moment the
    /// string can be "You're in a Microsoft Teams call", which wraps in this width - and the overflow
    /// of a wrapped title is the button row, laid out below the window's bottom edge, which is
    /// exactly the defect this whole type exists because of.
    static let defaultTitle = CallSource.offerTitle(appName: nil)
    /// Says what it will and will not do. The panel appearing on its own is exactly when a user
    /// needs to know that nothing has been recorded yet.
    static let caption = "Nothing is being recorded. Transcribe it into a note?"

    /// Wide enough for the caption to wrap to two lines rather than five.
    static let width: CGFloat = 268

    /// Inset on all four sides - the view's `.padding(Space.x4)`.
    static let padding = Space.x4

    /// Between the title row, the caption and the buttons - the `VStack`'s `spacing`.
    static let rowSpacing = Space.x3

    /// The text column: what the caption wraps against.
    static var contentWidth: CGFloat { width - padding * 2 }

    /// The narrower column the *title* wraps against, because the icon shares its row.
    static var titleWidth: CGFloat { contentWidth - titleIconWidth - Space.x2 }

    /// How much of the title row the leading symbol takes.
    ///
    /// Measured from the real symbol at the size the view draws it, rather than guessed: a
    /// two-person glyph is much wider than a square one, and the difference comes straight off the
    /// width the title has to wrap in. Falls back to a number only if the symbol is missing, which
    /// would mean the view is not drawing an icon either.
    static var titleIconWidth: CGFloat {
        let symbol = NSImage(systemSymbolName: "person.wave.2.fill", accessibilityDescription: nil)
        let configured = symbol?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        )
        return configured?.size.width ?? 20
    }

    /// Height of the button row.
    ///
    /// `NSButton(bezelStyle: .rounded, controlSize: .large).fittingSize` measured (92, 28) on this
    /// machine, which is where the number comes from - a large macOS control.
    ///
    /// The card uses large native macOS buttons, whose measured height is 28pt.
    static let buttonRowHeight: CGFloat = 28

    /// Head-room over the derived content height.
    ///
    /// One thing it absorbs now, and it is still not measurable from here: system font metrics are
    /// not ours to promise across releases, and the title and caption are measured with them.
    ///
    /// It also used to cover `.glass` at `.controlSize(.large)` drawing taller than the AppKit
    /// fitting height above, which `buttonRowHeight` explains is no longer a risk. Kept at the same
    /// value regardless - the two text rows are the larger share of the card's height and they are
    /// the part still measured against the system. `PillMetrics.noteBoxHeight` carries slack for the
    /// same reason.
    static let slack = Space.x2

    /// AppKit spellings of the two `Typo` faces the card uses, because a SwiftUI `Font` cannot be
    /// measured. Not private: the test measures the same faces rather than re-deriving them and
    /// agreeing with a bug.
    static let titleFont = NSFont.systemFont(ofSize: 15, weight: .medium)   // Typo.bodyEmphasis
    static let captionFont = NSFont.systemFont(ofSize: 12)                  // Typo.caption

    /// The window size, with an optional failure message on the card.
    static func size(title: String = defaultTitle, message: String? = nil) -> NSSize {
        NSSize(width: width, height: height(title: title, message: message))
    }

    /// The height the content needs, and therefore the window's.
    ///
    /// `title` and `message` are both measured rather than allowed a fixed number of lines: the
    /// title now carries an app name of a length no one here knows in advance, and `message` is the
    /// "why the capture could not start" line, which is a whole sentence.
    static func height(title: String = defaultTitle, message: String? = nil) -> CGFloat {
        var total = padding * 2
            + titleHeight(title)
            + rowSpacing
            + captionHeight(caption)
            + rowSpacing
            + buttonRowHeight
            + slack
        if let message, !message.isEmpty {
            total += rowSpacing + captionHeight(message)
        }
        return ceil(total)
    }

    /// One line of `font`, including its leading.
    static func lineHeight(_ font: NSFont) -> CGFloat {
        NSLayoutManager().defaultLineHeight(for: font)
    }

    /// How tall the title is beside its icon, wrapped.
    ///
    /// At least one line even for an empty string, so a card with no title still has a title row.
    static func titleHeight(_ text: String) -> CGFloat {
        max(lineHeight(titleFont), wrappedHeight(text, font: titleFont, width: titleWidth))
    }

    /// How tall `text` is in the card's text column, in the caption face, wrapped.
    ///
    /// The caption is `.fixedSize(horizontal: false, vertical: true)` in the view, which makes its
    /// wrapped height incompressible - the card cannot squeeze it, so this is what the window has to
    /// find room for.
    static func captionHeight(_ text: String) -> CGFloat {
        wrappedHeight(text, font: captionFont, width: contentWidth)
    }

    /// Wrapped height of `text` in `font` inside a `width`-wide column.
    private static func wrappedHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = Typo.caption.lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let attributed = NSAttributedString(string: text,
                                            attributes: [.font: font,
                                                         .paragraphStyle: paragraph])
        return attributed.boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).height
    }
}

/// The card that appears above the pill when Utter notices you are in a call.
///
/// A separate panel rather than another `PillState`, deliberately. The pill's state machine already
/// carries eight states, a shape morph and a window whose size is load-bearing, and every recent
/// bug in this app has come from adding one more thing to it. This has nothing to do with dictation
/// and no reason to share that machinery.
///
/// **It offers; it never starts.** Recording other people has legal weight that varies by
/// jurisdiction, so the one thing this must not do is begin capturing because it appeared under the
/// pointer. Nothing is recorded until the button is pressed, and the panel takes no keyboard focus
/// so it cannot swallow a Return meant for something else.
///
/// **It is also where a failed start is reported.** Pressing Transcribe without Screen Recording
/// permission used to dismiss the card, ask for the permission and put a 2.5-second pill notice up;
/// the offer for that call never came back, because it only fires on a transition, so the answer to
/// "then try again" was that there was nothing left to try. The card now stays until a capture is
/// actually running and carries the reason itself, which is the only surface here big enough for a
/// sentence.
@MainActor
final class MeetingOfferPanel: NSPanel {

    /// Clearance between the pill's top edge and the card's bottom edge.
    private static let gap: CGFloat = 10

    private weak var pill: PillWindow?
    private let pillWasVisible: Bool

    /// Why the capture could not start, once that has happened.
    private let model = MeetingOfferModel()

    /// Kept because `showFailure` has to re-measure the card, and the card's height depends on the
    /// title as well as the message now.
    ///
    /// Not `title`: `NSWindow` already has one, and the two are ambiguous at every use site inside
    /// this class rather than shadowing cleanly.
    private let cardTitle: String

    init(pill: PillWindow,
         title: String = MeetingOfferMetrics.defaultTitle,
         onAccept: @escaping () -> Void,
         onDecline: @escaping () -> Void) {
        self.pill = pill
        self.pillWasVisible = pill.isVisible
        self.cardTitle = title
        super.init(contentRect: NSRect(origin: .zero, size: MeetingOfferMetrics.size(title: title)),
                   styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                   backing: .buffered,
                   defer: false)

        // Matches the pill: floats above ordinary windows, follows the user across Spaces, and
        // never becomes the key window - this must not steal focus from the call.
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        // Decided in `refreshShadow`, not here: it depends on which of `ChromeGlass`'s four render
        // paths draws, and one of them is a live accessibility preference.
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let hosting = NSHostingView(rootView: ThemedRoot {
            MeetingOfferView(title: title, model: model, onAccept: onAccept, onDecline: onDecline)
        })
        // Never let the hosting view drive the window's size - the collapse documented in
        // `showMainWindow`. Which is exactly why `MeetingOfferMetrics` exists: with the window's
        // height fixed here, the content has to be known to fit it.
        if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        contentView = hosting
    }

    /// Centre the card over the pill's capsule, above it.
    ///
    /// Positioned from the capsule rather than the pill's window frame: the panel is a fixed
    /// `PillMetrics.windowHeight` with the capsule bottom-anchored inside it, so the window's top
    /// edge is 96pt of empty space above the pill. Anchoring to that would leave the card floating
    /// clear of nothing. Same reason `CompanionWindow.placeBesidePill` reads the capsule's eye line.
    ///
    /// Reads its own `frame.size` rather than a static, because a failure message makes the card
    /// taller and it grows upwards from the same anchor.
    private func positionedFrame(size: NSSize? = nil) -> NSRect {
        let size = size ?? frame.size
        guard let pill else { return NSRect(origin: frame.origin, size: size) }
        let pillFrame = pill.frame
        let capsuleTop = pillFrame.minY + PillMetrics.capsuleCentreAboveBottom
            + PillMetrics.capsuleHeight / 2
        var origin = NSPoint(x: pillFrame.midX - size.width / 2,
                             y: capsuleTop + Self.gap)

        if let visible = (pill.screen ?? NSScreen.main)?.visibleFrame {
            if origin.y + size.height > visible.maxY {
                let capsuleBottom = pillFrame.minY + PillMetrics.capsuleCentreAboveBottom
                    - PillMetrics.capsuleHeight / 2
                origin.y = capsuleBottom - Self.gap - size.height
            }
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }
        return NSRect(origin: origin, size: size)
    }

    func positionAbovePill() {
        guard pill != nil else { return }
        setFrame(positionedFrame(), display: false)
    }

    func show() {
        let destination = positionedFrame()
        guard let pill, let source = pill.drawnShellScreenRect else {
            setFrame(destination, display: false)
            model.contentVisible = true
            orderFront(nil)
            refreshShadow()
            return
        }

        if !pill.isVisible { pill.orderFront(nil) }
        setFrame(source, display: false)
        model.contentVisible = false
        orderFront(nil)
        pill.alphaValue = 0
        refreshShadow()

        if MotionPreference.shared.reduceMotion {
            setFrame(destination, display: true)
            withAnimation(.easeOut(duration: 0.16)) { model.contentVisible = true }
            return
        }

        withAnimation(.easeOut(duration: 0.16)) { model.contentVisible = true }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.23, 1, 0.32, 1
            )
            animator().setFrame(destination, display: true)
        }
    }

    func dismiss(completion: @escaping () -> Void) {
        guard let pill else {
            orderOut(nil)
            completion()
            return
        }

        let finish = {
            pill.alphaValue = 1
            if !self.pillWasVisible { pill.orderOut(nil) }
            self.orderOut(nil)
            completion()
        }
        withAnimation(.easeOut(duration: 0.12)) { model.contentVisible = false }

        guard !MotionPreference.shared.reduceMotion,
              let destination = pill.drawnShellScreenRect else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.23, 1, 0.32, 1
            )
            animator().setFrame(destination, display: true)
        } completionHandler: {
            finish()
        }
    }

    /// Give the card a shadow on the render paths where nothing else supplies one.
    ///
    /// Same branch and same reasoning as the pill's `PillElevation`: on macOS 26 the Liquid Glass
    /// material draws its own content-aware shadow - it "increases the opacity of its shadow when it
    /// is over text" and lowers it over a light background - so a second one doubles it. Below 26,
    /// and under Reduce Transparency at any version, there is no material to supply one: the card
    /// becomes an opaque `Surface.raised` rect with a 1pt border, floating over the desktop with
    /// nothing separating it from the wallpaper.
    ///
    /// The *window's* shadow rather than a SwiftUI `.shadow`, which is where this differs from the
    /// pill. The pill's panel is 320x96 around a ~56pt capsule, so a layer shadow has margin to
    /// blur into; this card's content is `.frame(maxWidth: .infinity, maxHeight: .infinity)` and
    /// fills its window exactly, so a layer shadow would be clipped at the window's edge and only
    /// the sliver under the rounded corners would show. `NSWindow.hasShadow` is drawn by the window
    /// server *outside* the frame, which also means it costs the card no height - and the height is
    /// the number `MeetingOfferMetrics` exists to protect.
    ///
    /// `invalidateShadow()` because the shape is derived from the content's alpha and cached: the
    /// card is rounded, and it is resized by `showFailure`.
    ///
    /// Ceiling: the preference is read when the card appears, not observed. Toggling Reduce
    /// Transparency while a card is already on screen leaves the shadow as it was until the next
    /// one, which is a card's lifetime - seconds to the length of a call. Worth an observer only if
    /// that stops being true.
    private func refreshShadow() {
        hasShadow = !GlassSupport.active(
            reduceTransparency: MotionPreference.shared.reduceTransparency
        )
        invalidateShadow()
    }

    /// Say why the capture did not start, on the card the user pressed.
    ///
    /// The card keeps its buttons, so "Transcribe" is the try-again - the same shape as
    /// `NotesView.startMeeting`, which does not return in the `.notDetermined` branch and leaves a
    /// Try again button behind. Resized and repositioned because the message is a whole sentence and
    /// the window cannot grow by itself.
    func showFailure(_ message: String) {
        model.failure = message
        setFrame(
            positionedFrame(size: MeetingOfferMetrics.size(title: cardTitle, message: message)),
            display: true
        )
        // The card just changed shape, and the window shadow is cached from the old one.
        refreshShadow()
    }
}

/// The card's mutable content. Only the failure line changes after the panel is built.
@MainActor
private final class MeetingOfferModel: ObservableObject {
    @Published var failure: String?
    @Published var contentVisible = false
}

/// The offer's contents.
private struct MeetingOfferView: View {
    let title: String
    @ObservedObject var model: MeetingOfferModel
    let onAccept: () -> Void
    let onDecline: () -> Void

    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            VStack(alignment: .leading, spacing: MeetingOfferMetrics.rowSpacing) {
                HStack(spacing: Space.x2) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                // Incompressible, like the caption below, so what it wraps to is what
                // `MeetingOfferMetrics.titleHeight` measured. Left free to truncate, an app with a
                // long name would draw one line where the window allowed two - harmless - but a
                // future width change would silently put the difference the other way round.
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(MeetingOfferMetrics.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let failure = model.failure {
                    Text(failure)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Space.x2) {
                    Button(action: onAccept) {
                        Label("Transcribe", systemImage: "record.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Not now", action: onDecline)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding(MeetingOfferMetrics.padding)
            .opacity(model.contentVisible ? 1 : 0)
            .scaleEffect(model.contentVisible ? 1 : 0.97, anchor: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 0.5)
        }

        // No rim overlay on the card, and no outer contrast ring.
        //
        // There was a `strokeBorder(Line.hairline)` here, and it was redundant on every path that
        // wanted a border and wrong on the one that does not. `ChromeGlass` already strokes the
        // three fallbacks itself - `Line.strong` in its Reduce Transparency branch, `rimGradient` at
        // 0.8pt in its pre-26 branch - so this card drew *two* borders on all three. On macOS 26 it
        // drew the one thing the material asks not to have: glass "draws its own highlight layer,
        // whose lights move in space, causing light to travel around the material, defining its
        // silhouette", and `ChromeGlass.glass` records that a static stroke on top fights that.
        //
        // The pill overrides that and carries an outer contrast ring anyway (`PillContent.shell`),
        // on the finding that its edge dissolved against busy wallpaper. That finding does not
        // transfer on its face: the pill is a ~28pt capsule whose *only* content is its edge, while
        // this is a 268pt sheet holding a title, a caption and two filled buttons, anchored 10pt
        // above the pill - the content is the object cue here, not the outline. So there is no ring,
        // and that is a judgement, not a measurement: nobody has yet looked at this card over a busy
        // light wallpaper on macOS 26. If its silhouette does dissolve there, the fix is the pill's  - 
        // one `shape.strokeBorder(contrast, lineWidth: 1)` at this exact point - and not the hairline
        // that was removed, which was tuned as a rim on an opaque surface.
    }
}
