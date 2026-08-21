import AppKit
import SwiftUI

/// The offer card's geometry.
///
/// A pure type with tests, for the reason `PillMetrics`, `CompanionGeometry` and `Layout.size` are:
/// the card's height is a fixed number the window is *created* with, and getting it wrong is not a
/// cosmetic defect. `hosting.sizingOptions = []` forbids the window growing to fit — deliberately,
/// see the collapse `showMainWindow` documents — and the content is top-aligned, so anything the
/// number does not allow for is laid out below the window's bottom edge, where nothing composites
/// and no mouse event lands.
///
/// It shipped as a hardcoded 96pt against 133.5pt of content: padding 32, an 18pt title row, two
/// 12pt gaps, a caption that wraps to two lines at 31.5pt, and a 28pt button row. The 37pt that did
/// not fit was the entire button row, so the feature could not be used at all — the card appeared
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
    /// string can be "You're in a Microsoft Teams call", which wraps in this width — and the overflow
    /// of a wrapped title is the button row, laid out below the window's bottom edge, which is
    /// exactly the defect this whole type exists because of.
    static let defaultTitle = CallSource.offerTitle(appName: nil)
    /// Says what it will and will not do. The panel appearing on its own is exactly when a user
    /// needs to know that nothing has been recorded yet.
    static let caption = "Nothing is being recorded. Transcribe it into a note?"

    /// Wide enough for the caption to wrap to two lines rather than five.
    static let width: CGFloat = 268

    /// Inset on all four sides — the view's `.padding(Space.x4)`.
    static let padding = Space.x4

    /// Between the title row, the caption and the buttons — the `VStack`'s `spacing`.
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
    /// machine, which is where the number comes from — a large macOS control.
    ///
    /// It is no longer only an *estimate* of what will draw. The card's buttons are
    /// `OfferButtonStyle` rather than a system style, and that style pins its height to this
    /// constant on every render path, so the row the window is sized for is the row that lays out.
    /// A side benefit of the buttons no longer being `.glass`: a system button style's metrics are
    /// the system's to change between releases, and this one's are ours.
    static let buttonRowHeight: CGFloat = 28

    /// Head-room over the derived content height.
    ///
    /// One thing it absorbs now, and it is still not measurable from here: system font metrics are
    /// not ours to promise across releases, and the title and caption are measured with them.
    ///
    /// It also used to cover `.glass` at `.controlSize(.large)` drawing taller than the AppKit
    /// fitting height above, which `buttonRowHeight` explains is no longer a risk. Kept at the same
    /// value regardless — the two text rows are the larger share of the card's height and they are
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
    /// wrapped height incompressible — the card cannot squeeze it, so this is what the window has to
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
        self.cardTitle = title
        super.init(contentRect: NSRect(origin: .zero, size: MeetingOfferMetrics.size(title: title)),
                   styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                   backing: .buffered,
                   defer: false)

        // Matches the pill: floats above ordinary windows, follows the user across Spaces, and
        // never becomes the key window — this must not steal focus from the call.
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
        // Never let the hosting view drive the window's size — the collapse documented in
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
    func positionAbovePill() {
        guard let pill else { return }
        let size = frame.size
        let pillFrame = pill.frame
        let capsuleTop = pillFrame.minY + PillMetrics.capsuleCentreAboveBottom
            + PillMetrics.capsuleHeight / 2
        var origin = NSPoint(x: pillFrame.midX - size.width / 2,
                             y: capsuleTop + Self.gap)

        // Keep it on screen. A pill parked near the top of the display has no room above it, so the
        // card goes below the capsule instead of off the edge.
        if let visible = (pill.screen ?? NSScreen.main)?.visibleFrame {
            if origin.y + size.height > visible.maxY {
                let capsuleBottom = pillFrame.minY + PillMetrics.capsuleCentreAboveBottom
                    - PillMetrics.capsuleHeight / 2
                origin.y = capsuleBottom - Self.gap - size.height
            }
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }
        setFrameOrigin(origin)
    }

    func show() {
        positionAbovePill()
        orderFront(nil)
        refreshShadow()
    }

    /// Give the card a shadow on the render paths where nothing else supplies one.
    ///
    /// Same branch and same reasoning as the pill's `PillElevation`: on macOS 26 the Liquid Glass
    /// material draws its own content-aware shadow — it "increases the opacity of its shadow when it
    /// is over text" and lowers it over a light background — so a second one doubles it. Below 26,
    /// and under Reduce Transparency at any version, there is no material to supply one: the card
    /// becomes an opaque `Surface.raised` rect with a 1pt border, floating over the desktop with
    /// nothing separating it from the wallpaper.
    ///
    /// The *window's* shadow rather than a SwiftUI `.shadow`, which is where this differs from the
    /// pill. The pill's panel is 320x96 around a ~56pt capsule, so a layer shadow has margin to
    /// blur into; this card's content is `.frame(maxWidth: .infinity, maxHeight: .infinity)` and
    /// fills its window exactly, so a layer shadow would be clipped at the window's edge and only
    /// the sliver under the rounded corners would show. `NSWindow.hasShadow` is drawn by the window
    /// server *outside* the frame, which also means it costs the card no height — and the height is
    /// the number `MeetingOfferMetrics` exists to protect.
    ///
    /// `invalidateShadow()` because the shape is derived from the content's alpha and cached: the
    /// card is rounded, and it is resized by `showFailure`.
    ///
    /// Ceiling: the preference is read when the card appears, not observed. Toggling Reduce
    /// Transparency while a card is already on screen leaves the shadow as it was until the next
    /// one, which is a card's lifetime — seconds to the length of a call. Worth an observer only if
    /// that stops being true.
    private func refreshShadow() {
        hasShadow = !GlassSupport.active(
            reduceTransparency: MotionPreference.shared.reduceTransparency
        )
        invalidateShadow()
    }

    /// Say why the capture did not start, on the card the user pressed.
    ///
    /// The card keeps its buttons, so "Transcribe" is the try-again — the same shape as
    /// `NotesView.startMeeting`, which does not return in the `.notDetermined` branch and leaves a
    /// Try again button behind. Resized and repositioned because the message is a whole sentence and
    /// the window cannot grow by itself.
    func showFailure(_ message: String) {
        model.failure = message
        setContentSize(MeetingOfferMetrics.size(title: cardTitle, message: message))
        positionAbovePill()
        // The card just changed shape, and the window shadow is cached from the old one.
        refreshShadow()
    }
}

/// The card's mutable content. Only the failure line changes after the panel is built.
@MainActor
private final class MeetingOfferModel: ObservableObject {
    @Published var failure: String?
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
        VStack(alignment: .leading, spacing: MeetingOfferMetrics.rowSpacing) {
            HStack(spacing: Space.x2) {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Tint.accent)
                // Incompressible, like the caption below, so what it wraps to is what
                // `MeetingOfferMetrics.titleHeight` measured. Left free to truncate, an app with a
                // long name would draw one line where the window allowed two — harmless — but a
                // future width change would silently put the difference the other way round.
                Text(title)
                    .typo(.bodyEmphasis)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(MeetingOfferMetrics.caption)
                .typo(.caption, ink: Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Above the buttons, so the try-again stays at the bottom edge where it was.
            if let failure = model.failure {
                Text(failure)
                    .typo(.caption, ink: Tint.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Not `GlassButton`. This card body is real Liquid Glass, and the app's standard button
            // resolves to `.buttonStyle(.glass)` on macOS 26 (`GlassButtonLook`, in GlassControls),
            // which put glass on glass — the one place in the app that did. See `OfferButtonStyle`.
            //
            // Symbol references rather than `file:line` for the design system, here and below: those
            // files are being edited alongside this one and every line number in them has already
            // moved once.
            HStack(spacing: Space.x2) {
                Button(action: onAccept) {
                    Label {
                        Text("Transcribe")
                    } icon: {
                        // Accent on the glyph, never on the label — `OfferButtonStyle` says why.
                        Image(systemName: "record.circle").foregroundStyle(Tint.accent)
                    }
                }
                .buttonStyle(OfferButtonStyle(emphasis: true, isDark: colorScheme == .dark))

                Button("Not now", action: onDecline)
                    .buttonStyle(OfferButtonStyle(emphasis: false, isDark: colorScheme == .dark))
            }
        }
        .padding(MeetingOfferMetrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassSurface(.chrome,
                      in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous),
                      reduceTransparency: motion.reduceTransparency,
                      isDark: colorScheme == .dark,
                      tint: nil)

        // No rim overlay on the card, and no outer contrast ring.
        //
        // There was a `strokeBorder(Line.hairline)` here, and it was redundant on every path that
        // wanted a border and wrong on the one that does not. `ChromeGlass` already strokes the
        // three fallbacks itself — `Line.strong` in its Reduce Transparency branch, `rimGradient` at
        // 0.8pt in its pre-26 branch — so this card drew *two* borders on all three. On macOS 26 it
        // drew the one thing the material asks not to have: glass "draws its own highlight layer,
        // whose lights move in space, causing light to travel around the material, defining its
        // silhouette", and `ChromeGlass.glass` records that a static stroke on top fights that.
        //
        // The pill overrides that and carries an outer contrast ring anyway (`PillContent.shell`),
        // on the finding that its edge dissolved against busy wallpaper. That finding does not
        // transfer on its face: the pill is a ~28pt capsule whose *only* content is its edge, while
        // this is a 268pt sheet holding a title, a caption and two filled buttons, anchored 10pt
        // above the pill — the content is the object cue here, not the outline. So there is no ring,
        // and that is a judgement, not a measurement: nobody has yet looked at this card over a busy
        // light wallpaper on macOS 26. If its silhouette does dissolve there, the fix is the pill's —
        // one `shape.strokeBorder(contrast, lineWidth: 1)` at this exact point — and not the hairline
        // that was removed, which was tuned as a rim on an opaque surface.
    }
}

/// The card's buttons: vibrant fills, because they sit on glass.
///
/// The prohibition, quoted in full in `SidebarRow.rowBackground` where the same call was made for
/// the selected sidebar row: "avoid applying the material to both layers. Instead, use fills,
/// transparency, and vibrancy for the top elements." `GlassButton` is `.buttonStyle(.glass)` on
/// macOS 26, so the card was a sheet of glass carrying two more.
///
/// Two decisions taken from places in this app that already measured them, rather than made fresh:
///
///   * The lift is a wash toward **white in both appearances**, which is `rowBackground`'s finding:
///     `Color.primary.opacity()` inverts per appearance and painted a near-black pill on a light
///     surface, so a raised element needs one direction, not a semantic colour. The same 0.10 dark /
///     0.75 light pair is used for that lift in three screens now.
///   * Emphasis is an accent **rim and glyph**, never the label. `GlassChip` measured accent text on
///     an accent surface at 1.18:1 against a 4.5:1 floor, because the accent then sets the label and
///     the thing behind it at once.
///
/// What the *opacities* below are, stated plainly: derived, not measured. `fill(pressed:)` runs
/// 0.12/0.55 at rest and 0.20/0.75 pressed. Light-mode rest is deliberately under the 0.75 the
/// selected row uses — two buttons at selection strength on a small card would read as two
/// selections rather than as controls — and press goes to it, so pressing lands where a selection
/// does. Dark rest is a hair over that row's 0.10, because that value was measured against a
/// translucent sidebar whereas these sit on glass over arbitrary wallpaper. Nobody has looked at
/// either pair on screen; they are one plausible step off a measured one and are the first thing to
/// re-tune if the buttons read as too faint or too heavy.
///
/// One treatment on all four render paths, not a branch. There is no glass to avoid below macOS 26
/// or under Reduce Transparency — a fill is simply correct there too — and a card whose buttons
/// changed shape with the material would be two designs to keep honest instead of one.
///
/// The height is `MeetingOfferMetrics.buttonRowHeight`, pinned rather than intrinsic. The window is
/// created at a fixed size with `sizingOptions = []` and the content is top-aligned, so a button row
/// taller than the metric allowed for lays out below the window's bottom edge where no click lands.
/// That is how this card shipped unusable once, and it is why the metric no longer depends on what a
/// system button style decides to draw.
///
/// Width stays intrinsic, and it fits: measured at 13pt, "Transcribe" + the 15pt `record.circle` +
/// this padding is 106.9pt and "Not now" is 74.3pt, so the row is **189.1pt of the card's 236pt
/// column** — 47pt spare. `.lineLimit(1)` below is therefore a guard against a future copy change,
/// not something either of these labels reaches.
private struct OfferButtonStyle: ButtonStyle {
    /// The call to action, and there is exactly one — the HIG limits prominence to "one or two per
    /// view", and a card offering to record other people should make plain which button starts it.
    let emphasis: Bool
    let isDark: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = Radius.rect(Radius.control)
        return configuration.label
            .typo(.callout, ink: Ink.primary)
            .lineLimit(1)
            .padding(.horizontal, Space.x3)
            .frame(height: MeetingOfferMetrics.buttonRowHeight)
            .background(shape.fill(Color.white.opacity(fill(pressed: configuration.isPressed))))
            .overlay(
                shape.strokeBorder(emphasis ? Tint.accent.opacity(0.55) : Line.hairline,
                                   lineWidth: Line.width)
            )
            // The whole fill is the target, not just the glyphs — a card whose buttons were once
            // off-window entirely has no business having a hit region smaller than it looks.
            .contentShape(shape)
            // `.glass`'s `.interactive()` supplied a press response for free and this has to replace
            // it, or the button reads as dead on click. `Motion.hoverIn` is the token the rest of
            // the app changes a fill with.
            .animation(Motion.hoverIn, value: configuration.isPressed)
    }

    private func fill(pressed: Bool) -> Double {
        if pressed { return isDark ? 0.20 : 0.75 }
        return isDark ? 0.12 : 0.55
    }
}
