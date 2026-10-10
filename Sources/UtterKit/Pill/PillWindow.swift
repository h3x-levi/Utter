import SwiftUI
import Cocoa
import Carbon.HIToolbox

enum PillState: Equatable {
    /// The speech model is still loading. Distinct from `idle` because holding
    /// the hotkey now would queue behind the load rather than record - telling
    /// the user "Hold Fn to dictate" here would be a lie.
    case preparing
    case idle
    case recording
    case handsFree
    /// Hands-free, but the transcript is going into a Utter note rather than
    /// being typed into the frontmost app. A separate state because the
    /// *destination* is the one thing the user cannot otherwise see - the
    /// recording itself looks identical either way.
    case capturingNote
    /// Hands-free speech whose destination is the private companion memory store.
    case capturingMemory
    /// The pipeline has three distinct phases; naming the current one is real
    /// feedback, where the old wiggling pencil carried no information.
    case processing(Phase)
    case error(String)
    /// A neutral, transient confirmation - "New note, keep talking". Distinct from
    /// `.error` because that one carries a warning glyph and a danger tint, which
    /// would tell the user something had gone wrong when nothing had.
    case notice(String)
    /// A transcript that was not typed because the user moved to an app with nothing to type
    /// into, offered for copying until it is copied, closed or replaced by a new turn.
    case island(String)

    enum Phase: String {
        case transcribing = "Transcribing"
        case rewriting = "Rewriting"
        case typing = "Typing"
    }

    var isRecordingLike: Bool {
        self == .recording || self == .handsFree
            || self == .capturingNote || self == .capturingMemory
    }

    /// Hands-free variants keep recording until explicitly stopped, rather than ending when
    /// a held hotkey is released.
    var isHandsFreeLike: Bool {
        self == .handsFree || self == .capturingNote || self == .capturingMemory
    }

    var isIsland: Bool {
        if case .island = self { return true }
        return false
    }
}

/// The microphone level, on a publisher of its own.
///
/// **Split off `PillStateModel` because it is the only quantity in the pill that moves at 30 Hz,
/// and the level meter is the only thing that draws it.** `@Published` invalidates every view
/// observing the *object*, not the property, so while `level` lived on the model a mic publish
/// re-ran the whole pill - and the pill is what is on screen for the entire length of every
/// dictation.
///
/// Measured offscreen (an `NSHostingView` in a panel that was never ordered front, driven with
/// 30 publishes = one second of recording), body evaluations per second:
///
///     level on the model      container 30, content 30, shell GeometryReader 30, a11y value 30
///     level on this object    container  0, content  0, shell GeometryReader  0, a11y value  0
///
/// The meter's own 59 runs are identical either way, so nothing about what is drawn changes. What
/// the 30 dropped runs of the shell reader were rebuilding is `PillShellShape`, `glassSurface`,
/// both `strokeBorder`s and `PillElevation`; what the 30 dropped `accessibilityValue`s were doing
/// in `.capturingNote` is an O(notes) store lookup plus two chord strings (measured 3.3 us at 200
/// notes, 13 us of lookup alone at 1000) to produce a string no assistive technology had asked
/// for.
///
/// The level is still a **real RMS measurement** and still arrives at the recorder's own rate;
/// this changes who is woken by it, not where it comes from.
///
/// `PillStateModel.level` stays as the read/write API, so nothing outside the pill had to know:
/// `AppDelegate`'s `$inputLevel` sink, its reset to 0, and the companion's `levelSource` pull all
/// still assign and read `stateModel.level`.
final class PillLevelSignal: ObservableObject {
    @Published var value: Float = 0
}

/// Observable state for the pill, owned by AppDelegate.
final class PillStateModel: ObservableObject {
    @Published var state: PillState = .preparing

    /// Real microphone level, 0...1, forwarded from AudioRecorder - held on its own publisher.
    ///
    /// A pass-through rather than a stored `@Published`, so the 30 Hz write reaches only
    /// `LevelMeter` and not the glass, the strokes, the shell shape and the accessibility
    /// strings. See `PillLevelSignal` for the measurements.
    ///
    /// **The cost of that, stated so it is not discovered the hard way: reading `level` inside a
    /// SwiftUI `body` no longer subscribes to it.** A view that observes this model and draws
    /// `model.level` will render the value it happened to see and never update - it has to observe
    /// `model.levels` instead, as `LevelMeter` does. Reads from outside a body (the companion's
    /// `levelSource`) are unaffected, because they are pulls.
    let levels = PillLevelSignal()

    var level: Float {
        get { levels.value }
        set { levels.value = newValue }
    }
    /// Seconds elapsed in the current recording.
    ///
    /// Backed by a private `@Published` with an equality guard in front of it, because
    /// `@Published` has no equality check of its own: it sends `objectWillChange` on *every*
    /// assignment, and the recording timer assigns this **ten times a second** so the displayed
    /// second is never late. That invalidated `PillContent` - glass, both strokes, the shell shape
    /// and the level meter - 10x/s to redraw a number that changes 1x/s, and it did it during
    /// recording, which is exactly when the pill is also animating.
    ///
    /// The guard sits here rather than at the timer because four places assign this (the timer, the
    /// reset, the demo gallery, a test) and a guard at one of them is a guard the next writer does
    /// not inherit. The property's public shape is unchanged, so no call site had to know.
    var elapsed: Int {
        get { elapsedSeconds }
        set {
            guard newValue != elapsedSeconds else { return }
            elapsedSeconds = newValue
        }
    }

    @Published private var elapsedSeconds: Int = 0

    /// Rough live transcript of what has been said so far, or empty.
    ///
    /// Preview only - never typed anywhere. It comes from a fast, unbiased,
    /// unpolished pass over partial audio, so it lags and will disagree with the
    /// final text. Its job is to prove the app is hearing you.
    @Published var previewText: String = ""

    /// The width the capsule's *content* asks for, in points.
    ///
    /// The pill's *window* is a fixed 320pt wide and the capsule is centred inside
    /// it - 56pt at rest, wider once a level meter, timer or live transcript
    /// appears, and wider still while note capture has it expanded into a box. So
    /// the window frame says nothing about where the visible pill ends, in exactly
    /// the way `PillMetrics.verticalInset` documents for the vertical axis.
    ///
    /// Anything that needs to sit *next to* the pill (the desktop companion) has to
    /// know the real edge, so the capsule reports its measured width here rather
    /// than having callers guess. Measured, never assumed: the width changes with
    /// the content and a hardcoded value would drift the moment a state was
    /// restyled.
    ///
    /// **Read it through `PillMetrics.shellWidth(for:measured:)`, not directly.** This is the
    /// content's ideal width, measured by `PillContent.idealWidthProbe` inside a `.fixedSize`
    /// boundary; the *drawn* width is that expression, which prefers a per-state constant
    /// wherever one exists so the morph has a number to interpolate towards. The two agree in
    /// every settled state and differ in two places that matter: for one layout pass after the
    /// content changes, and for the length of a removal transition, during which the outgoing
    /// state's content is still in the layout and the ideal briefly exceeds the card.
    @Published var capsuleWidth: CGFloat = PillMetrics.minimumCapsuleWidth

    /// Whether the hands-free button is on screen beside the capsule.
    ///
    /// Published because the button is drawn *outside* the pill, so the window's hit region
    /// has to grow to cover it - and `ShapedHostingView` nils every click outside that
    /// region, which would make a visible button unclickable. View state, reported upward,
    /// exactly like `capsuleWidth`.
    /// Whether the pointer is over the pill or over the control beside it.
    ///
    /// The raw input, deliberately - not "is the button showing". `PillHoverControl` turns
    /// this into the reveal decision, and `PillWindow.drawnShellRect` and `PillContainerView`
    /// both ask it rather than each keeping an answer. Two answers is what made the stop
    /// button unclickable; see `drawnShellRect`.
    @Published var pointerInsidePill: Bool = false

    /// The companion's live behaviour engine, or `nil` while the companion is switched off.
    ///
    /// The note card draws the character itself while it is open, and the desktop panel
    /// steps aside for the duration (`CompanionWindow.applyCardHandover`) - so there is
    /// only ever one character on screen and a collision between the two is impossible
    /// rather than avoided. This is the seam that makes that a *handover* rather than a
    /// teleport: it is the very instance the panel renders from, so mood, pose and frame
    /// timing carry straight across. A character mid-`delighted` when the card opens is
    /// still mid-`delighted` inside it, and the ticker never stops.
    ///
    /// `nil` is also the whole of "no character in the card": with the companion off the
    /// card is laid out exactly as it was before this existed.
    ///
    /// Set by `AppDelegate.applyCompanionVisibility`, which is the one place that knows
    /// whether the companion is on and owns the window that holds the engine.
    @Published var companionBehaviour: CompanionBehaviour?

    /// Whether the note card's companion column is in the view tree.
    ///
    /// Deliberately *not* the same question as `companionBehaviour != nil`. The card's character
    /// is the one expensive thing in it - a first `Image(nsImage:)` draw of an APNG frame plus a
    /// subscription to the companion's **30 Hz** behaviour ticker - and building it on the
    /// morph's first frame is what made opening look hurried while closing looked right.
    ///
    /// The asymmetry is structural, not a matter of taste in curves. Opening constructs
    /// `NoteCaptureBox`: three new `@ObservedObject` subscriptions, that first image decode, and
    /// then ~5 more `body` re-runs inside the animating window as the 30 Hz ticker fires. Closing
    /// constructs nothing - the removal snapshot re-lays-out behind the clip, where it cannot be
    /// seen. A time-based spring skips the frames it loses rather than stretching them, so the
    /// direction that costs frames was the direction whose curve could not absorb them
    /// (`Motion.morphExpand` has the measurements).
    ///
    /// So the character steps in once the shell has arrived, and the morph itself carries no
    /// construction at all. The gap is deliberate and visible: `CompanionWindow.applyCardHandover`
    /// orders the desktop panel out the moment the state publishes, so for the length of the morph
    /// the character is on neither surface. That reads as the handover it is, and the card is
    /// growing over the ground the character was standing on.
    @Published var noteCardSettled = false

    /// `elapsed` as m:ss.
    ///
    /// On the model rather than inside a view because two of them draw it now - the
    /// capsule's timer and the note box's header - and a second copy of the format
    /// would be free to disagree about, say, whether the first minute reads "0:07".
    var elapsedText: String {
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return minutes > 0
            ? String(format: "%d:%02d", minutes, seconds)
            : String(format: "0:%02d", seconds)
    }
}

class PillWindow: NSPanel {
    let stateModel = PillStateModel()
    private var onLongPress: (() -> Void)?
    /// The pointer route into hands-free dictation - see `PillHoverControl`.
    ///
    /// Deliberately the *same* callback the ⌃⌥Space chord fires (`CaptureSession
    /// .toggle(.handsFree)`) rather than a second path into the recorder: a pointer route with
    /// its own entry point would be free to drift out of step with the chord's handling of
    /// upgrade, refusal-while-processing and rollback.
    private var onStartHandsFree: (() -> Void)?
    /// The island's copy, close and Escape all end it here.
    var onCloseIsland: (() -> Void)?
    private var escapeMonitor: Any?
    private let positionKey = "pillWindowPosition"

    /// Only the island takes keys (⌘C, Escape), and only once the user clicks it.
    override var canBecomeKey: Bool { stateModel.state.isIsland }

    /// `onStartHandsFree` defaults to nothing so the pill still builds without it; with no
    /// handler the hover control is not offered at all rather than drawn and inert.
    convenience init(onLongPress: @escaping () -> Void,
                     onStartHandsFree: @escaping () -> Void = {}) {
        self.init()
        self.onLongPress = onLongPress
        self.onStartHandsFree = onStartHandsFree
    }

    override init(
        contentRect: NSRect = NSRect(x: 0, y: 0,
                                     width: PillMetrics.windowWidth,
                                     height: PillMetrics.windowHeight),
        styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless],
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: PillMetrics.windowWidth,
                                height: PillMetrics.windowHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        // Fixed in place, twice asked for: "the pill overall should not be moveable
        // anymore". This flag was the whole reason a drag on the capsule moved the window,
        // and removing the 40pt edge-snapping earlier only stopped it *jumping* - it stayed
        // draggable, which read as the pill wandering whenever it was touched. First-launch
        // placement (`positionAtBottomCenter`) and the right-click "Reset Position" item
        // still put it somewhere sensible; nothing else moves it now.
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = ShapedHostingView(rootView: PillContainerView(
            stateModel: stateModel,
            onLongPress: { [weak self] in self?.onLongPress?() },
            onStartHandsFree: { [weak self] in self?.onStartHandsFree?() },
            onCloseIsland: { [weak self] in self?.onCloseIsland?() }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        // Never let the SwiftUI content size this window. This is the whole of the
        // "note pop-up is broken - sometimes smaller, sometimes bigger, sometimes it
        // goes down and comes back up" report, and it is the same collapse `showMainWindow`
        // and `showOnboarding` (App.swift) already guard against.
        //
        // `NSHostingView.sizingOptions` defaults to `.standardBounds`, which includes
        // `.intrinsicContentSize` - so the hosting view publishes Auto Layout constraints for
        // its SwiftUI content's *ideal* size, and as this window's `contentView` those
        // constraints drive the window's dimensions instead of the reverse (Apple's docs, and
        // the two working windows above, both say so). The pill's ideal size is the shell size:
        // ~56×28 at rest, 292×124 as a note card, and - since the prior change made both axes
        // an animatable `ShellSize` - every value in between, republished at 60-120 Hz through
        // the whole morph, and again on every 30 Hz companion tick and every live-transcript
        // word while the card is open. The window followed all of it, which is exactly the
        // non-deterministic grow/shrink and vertical slide the user sees. It is intermittent
        // for the reason `showMainWindow` documents: the size arrives through the content-view
        // relationship as a race, not as a resize request.
        //
        // `[]` creates no constraints at all, so the window stays the fixed
        // `windowWidth × windowHeight` it was built at, the content is laid out *into* that
        // fixed frame (bottom-anchored by `PillContainerView`), and the shell morph animates
        // entirely inside it without ever touching the window frame. `PillMetrics.windowHeight`
        // is the constant that makes that safe; this is the line that makes it true.
        if #available(macOS 13.0, *) { hostingView.sizingOptions = [] }
        hostingView.autoresizingMask = [.width, .height]
        // Only the capsule - or the note card, when it has grown into one - takes the
        // mouse. The rest of the panel is transparent to it, so a click beside the
        // pill reaches the desktop instead of vanishing into a dead zone.
        hostingView.interactiveRect = { [weak self] in self?.drawnShellRect ?? .zero }
        contentView = hostingView

        restorePosition()
    }

    /// Where the pill is actually drawn inside its panel, in content-view coordinates.
    ///
    /// The shell is bottom-anchored with `verticalInset` of clearance and centred
    /// horizontally, which is what `PillContainerView` lays out - so this has to be read
    /// from the same two facts: the live capsule width the content publishes, and the
    /// shell height for the current state.
    var drawnShellRect: NSRect {
        guard let content = contentView else { return .zero }
        let height = PillMetrics.shellHeight(for: stateModel.state)
        // The same expression `PillContent` hands to `ShellSize`, so the region that can be
        // clicked is the box that was drawn. Reading `capsuleWidth` raw was correct only while
        // it *was* the drawn width; it is now the content's ideal, which for `.capturingNote`
        // transiently exceeds the card while the outgoing state's content is still in the
        // layout for its removal transition.
        let width = min(PillMetrics.shellWidth(for: stateModel.state,
                                               measured: stateModel.capsuleWidth),
                        content.bounds.width)
        // Bottom-anchored, in the hosting view's flipped (top-left, y-down) space  - 
        // measured: `NSHostingView.isFlipped` is true, and `ShapedHostingView.hitTest`
        // converts the click into it. The shell is drawn against the *bottom* edge with
        // `verticalInset` of clearance (see `PillContainerView`), so the hit rect has to
        // start `verticalInset + height` up from the bottom, not `verticalInset` down from
        // the top. Those coincided only while the window was symmetric (height ==
        // shell + 2·inset), which it now never is except during note capture: the panel is a
        // fixed `PillMetrics.windowHeight` while the capsule is 28pt tall, so a top-anchored
        // y would put the hit region 96pt above the visible pill in every resting state.
        var rect = NSRect(x: (content.bounds.width - width) / 2,
                          y: content.bounds.height - PillMetrics.verticalInset - height,
                          width: width,
                          height: height)
        // Reach over the hands-free bead when it is showing.
        //
        // It is drawn outside the capsule, and `ShapedHostingView.hitTest` nils everything
        // outside this rect - so without the extension the bead would be plainly visible
        // and completely unclickable. Only extended while it is actually on screen, so the
        // resting pill keeps the tight hit region that stopped the dead zone swallowing
        // clicks meant for the desktop.
        //
        // Asks `PillHoverControl` the same question the view asks, rather than reading a
        // flag the view mirrored into the model. A mirror was what broke it: the flag was
        // written from the pointer alone (`pointer && isOffered`), while the button is drawn
        // from `isRevealed` - which is true in `.handsFree` *without* any pointer, because
        // stopping a latched session is a persistent control. Latching hands-free from the
        // chord with the pointer elsewhere therefore drew a stop button the window refused
        // every click for: the one control that ends the recording, visible and inert, with
        // no way to recover because reaching it delivered no hover either.
        if PillHoverControl.isRevealed(in: stateModel.state,
                                       pointerInsidePill: stateModel.pointerInsidePill) {
            // `shellWidth`, not `+ handsFreeButtonReach`: the bead's resting position is clamped
            // to the panel's edge, so past a ~256pt capsule the naive sum claims up to 10.5pt of
            // region that nothing is drawn in - points the window would take clicks for and the
            // desktop would not.
            //
            // The `+ 1` is the half-open rect. `NSRect.contains` excludes `maxX`, and the two
            // land exactly on each other at rest: the idle rect is x 132 w 88, and the bead's
            // right edge is 220 = 132 + 88. Without it the outermost column of the one control
            // that stops a latched recording takes no click.
            rect.size.width = PillMetrics.shellWidthWithBead(capsuleWidth: width) + 1
        }
        // Never past the panel. The button's own position is clamped to the panel edge, so a
        // region that ran beyond it would claim points the window does not own.
        return rect.intersection(NSRect(origin: .zero, size: content.bounds.size))
    }

    /// The pill's visible shell in global screen coordinates.
    var drawnShellScreenRect: NSRect? {
        guard let contentView else { return nil }
        let windowRect = contentView.convert(drawnShellRect, to: nil)
        return convertToScreen(windowRect)
    }

    /// Applied at once on the main thread, so the first frame of a key-down is not queued behind
    /// the rest of that turn's work. Off main it hops.
    func setState(_ state: PillState) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.setState(state) }
            return
        }
        apply(state)
        // Returning to rest is the moment to honour "don't show the pill at all times".
        if state == .idle, !UserData.shared.alwaysShowPill, isVisible {
            orderOut(nil)
        }
    }

    /// Both shell axes come from `ShellSize`'s one `AnimatablePair`, so they change together.
    private func apply(_ target: PillState) {
        let leavingIsland = stateModel.state.isIsland && !target.isIsland
        let height = target.isIsland ? PillMetrics.islandWindowHeight : PillMetrics.windowHeight
        // Grow before the island draws and shrink after it has gone, so it is never clipped.
        if height > frame.height { setWindowHeight(height) }
        // Instant rather than animated: glass fills its bounds, so a resizing shell cross-fades
        // into a doubled pill.
        stateModel.state = target
        if height < frame.height { setWindowHeight(height) }
        if target.isRecordingLike { Signposts.endKeyDownToPill() }
        watchEscape(target.isIsland)
        // Give the keyboard back to the app the user was in.
        if leavingIsland, isKeyWindow {
            orderOut(nil)
            orderFront(nil)
        }

        // Staged by one runloop turn during expansion: allows the shell frame to render
        // its first frame smoothly before the heavy companion APNG decoder and 30Hz ticker
        // are mounted inside NoteCaptureBox.
        if PillMetrics.isExpanded(target) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, PillMetrics.isExpanded(self.stateModel.state) else { return }
                self.stateModel.noteCardSettled = true
            }
        } else {
            stateModel.noteCardSettled = false
        }
    }

    /// Keeps the bottom edge, where the shell is anchored, in place.
    private func setWindowHeight(_ height: CGFloat) {
        setFrame(NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: height), display: true)
    }

    /// Escape closes the island from any app. A global monitor sees the key without taking it.
    private func watchEscape(_ on: Bool) {
        if on, escapeMonitor == nil {
            escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == UInt16(kVK_Escape) { self?.onCloseIsland?() }
            }
        } else if !on, let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    var currentState: PillState { stateModel.state }

    // MARK: - Position

    // `savePosition` used to live here, writing the dropped origin as a fraction of the
    // visible frame. It went with the drag: nothing can move the pill any more, so there is
    // no new position to record. `restorePosition` still reads the key - an existing install
    // keeps the spot it was last left at - and "Reset Position" clears it, so the fallback to
    // `positionAtBottomCenter` is permanent rather than undone by the next launch.

    private func restorePosition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        if let saved = UserDefaults.standard.dictionary(forKey: positionKey),
           let fx = saved["fx"] as? CGFloat, let fy = saved["fy"] as? CGFloat {
            // Clamp into the current visible frame in case the display changed.
            //
            // The lower bound is the resting origin, not `visible.minY`: the pill
            // window carries transparent padding below the capsule, so its origin
            // legitimately sits *below* the visible frame when the pill is parked
            // just above the Dock. Clamping at `visible.minY` would drag it back
            // up by that inset on every relaunch.
            let restingY = visible.minY + Self.dockGap - PillMetrics.verticalInset
            let x = min(max(visible.minX + fx * visible.width, visible.minX),
                        visible.maxX - frame.width)
            let y = min(max(visible.minY + fy * visible.height, restingY),
                        visible.maxY - frame.height)
            setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            positionAtBottomCenter()
        }
    }

    @objc private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: positionKey)
        positionAtBottomCenter()
    }

    /// Visible gap between the bottom of the pill and the top of the Dock.
    ///
    /// `visibleFrame` already excludes the Dock, so this is measured from the
    /// Dock's top edge rather than the screen's.
    private static let dockGap: CGFloat = 10

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        // The window carries transparent padding below the capsule, so positioning by
        // window origin alone would add that to the gap and leave the pill floating
        // well clear of the Dock. `PillMetrics.verticalInset` is that padding.
        setFrameOrigin(NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.minY + Self.dockGap - PillMetrics.verticalInset
        ))
    }

    // MARK: - Context menu

    private lazy var pillMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Utter", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Utter", action: #selector(quitApp), keyEquivalent: ""))
        return menu
    }()

    /// Whether an event landed on the pill itself rather than the transparent panel round it.
    ///
    /// `ShapedHostingView.hitTest` returning nil only declines to hand the event to a
    /// *subview* - the event still belongs to the window, and AppKit walks on to the window's
    /// own responder methods. So these two overrides bypassed the hit region entirely and
    /// popped the context menu from anywhere in the panel, including the 96pt of empty space
    /// above the capsule now that the panel is permanently note-tall.
    private func hitsDrawnShell(_ event: NSEvent) -> Bool {
        guard let content = contentView else { return false }
        return drawnShellRect.contains(content.convert(event.locationInWindow, from: nil))
    }

    override func rightMouseDown(with event: NSEvent) {
        guard hitsDrawnShell(event) else { return }
        NSMenu.popUpContextMenu(pillMenu, with: event, for: contentView!)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            guard hitsDrawnShell(event) else { return }
            NSMenu.popUpContextMenu(pillMenu, with: event, for: contentView!)
            return
        }
        super.mouseDown(with: event)
    }

    @objc private func openMainWindow() { onLongPress?() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

// MARK: - Container

@MainActor
final class PillContainerViewModel: ObservableObject {
    @Published var pointerOnControl = false
    @Published var pointerInsidePill = false
    @Published var revealed = false
    var revealLatch = HoverRevealLatch()
    var hideWork: DispatchWorkItem?
    @Published var settle: CGFloat = 1
    @Published var colorState: PillState = .idle

    func restartSettle(state: PillState, capsuleWidth: CGFloat, reduceMotion: Bool) {
        guard !reduceMotion else {
            settle = 1
            colorState = state
            return
        }
        settle = Motion.settleScale(
            width: PillMetrics.shellWidth(for: state, measured: capsuleWidth),
            height: PillMetrics.shellHeight(for: state)
        )
        withAnimation(Motion.tintCross) { colorState = state }
        DispatchQueue.main.async { [weak self] in
            withAnimation(Motion.settle) { self?.settle = 1 }
        }
    }

    func refreshReveal() {
        let present = pointerInsidePill || pointerOnControl
        hideWork?.cancel()
        hideWork = nil
        revealed = revealLatch.update(present: present, at: ProcessInfo.processInfo.systemUptime)
        guard !present, revealed else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.revealed = self.revealLatch.update(present: false,
                                                   at: ProcessInfo.processInfo.systemUptime)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + HoverRevealLatch.grace, execute: work)
    }
}

struct PillContainerView: View {
    @ObservedObject var stateModel: PillStateModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var containerModel = PillContainerViewModel()
    var onLongPress: () -> Void = {}

    private var stateCase: Int {
        switch stateModel.state {
        case .preparing: return 0
        case .idle: return 1
        case .recording: return 2
        case .handsFree: return 3
        case .capturingNote: return 4
        case .capturingMemory: return 5
        case .processing: return 6
        case .notice: return 7
        case .error: return 8
        case .island: return 9
        }
    }

    var onStartHandsFree: (() -> Void)? = nil
    var onCloseIsland: () -> Void = {}

    private var extrusion: CGFloat {
        guard onStartHandsFree != nil,
              PillHoverControl.isRevealed(in: stateModel.state,
                                          pointerInsidePill: containerModel.revealed)
        else { return 0 }
        return 1
    }

    private var drawnCapsuleWidth: CGFloat {
        PillMetrics.shellWidth(for: stateModel.state, measured: stateModel.capsuleWidth)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
            PillContent(model: stateModel,
                        onStartHandsFree: onStartHandsFree,
                        onHoverChanged: { inside in
                            containerModel.pointerInsidePill = inside
                            if !inside { containerModel.pointerOnControl = false }
                            containerModel.refreshReveal()
                        },
                        colorState: containerModel.colorState,
                        extrusion: extrusion,
                        onCloseIsland: onCloseIsland)
                .fixedSize()
                .onLongPressGesture(minimumDuration: 2.0) {
                    if PillHoverControl.longPressOpensUtter(in: stateModel.state,
                                                            pointerOnControl: containerModel.pointerOnControl) {
                        onLongPress()
                    }
                }
                .padding(.bottom, PillMetrics.verticalInset)

            if let onStartHandsFree {
                let shown = PillHoverControl.isRevealed(
                    in: stateModel.state,
                    pointerInsidePill: containerModel.revealed
                )
                HandsFreeRevealButton(stops: PillHoverControl.stops(in: stateModel.state),
                                      emergence: shown ? 1 : 0,
                                      action: onStartHandsFree,
                                      onHoverChanged: {
                                          containerModel.pointerOnControl = $0
                                          containerModel.refreshReveal()
                                      })
                    .offset(x: drawnCapsuleWidth / 2
                               + PillMetrics.lobeCentreOffset(extrusion: extrusion,
                                                             capsuleWidth: drawnCapsuleWidth))
                    .allowsHitTesting(shown)
                    .padding(.bottom, PillMetrics.verticalInset
                                      + (PillMetrics.capsuleHeight - PillMetrics.handsFreeButtonSide) / 2)
            }
        }
        .scaleEffect(containerModel.settle, anchor: UnitPoint(x: 0.5, y: PillMetrics.shellBottomAnchorY))
        .onChange(of: stateCase) { _ in
            containerModel.restartSettle(state: stateModel.state, capsuleWidth: stateModel.capsuleWidth, reduceMotion: motion.reduceMotion)
        }
        .onAppear { containerModel.colorState = stateModel.state }
        .animation(motion.reduceMotion ? nil
                                       : (containerModel.revealed ? Motion.beadEmerge : Motion.beadRetract),
                   value: containerModel.revealed)
        .onChange(of: containerModel.revealed) { inside in
            stateModel.pointerInsidePill = inside
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The pill lives in its own NSPanel, so it needs the theme applied
        // directly - it doesn't inherit from the main window.
        //
        // Deliberately NO `.id(theme.id)` here. Keying the view on the theme
        // rebuilt the whole subtree from scratch every time `ThemeManager`
        // republished, and each rebuild restarted the glass material's fade-in  - 
        // which read as the pill quietly pulsing forever. Measured: brightness
        // swinging ~8% on a ~2s cycle while nothing on screen was changing,
        // where an identical static glass capsule held to within 0.03%.
        //
        // The theme still applies without it: `Tint`/`Surface` are computed
        // properties, and `themeManager` is observed here, so a theme change
        // invalidates this view and the children re-read the new values.
        .preferredColorScheme(themeManager.current.colorScheme)
    }
}

// MARK: - Pill content

struct PillContent: View {
    @ObservedObject var model: PillStateModel
    var onStartHandsFree: (() -> Void)? = nil
    /// Reports whether the pointer is on the *drawn capsule*, measured against
    /// `PillShape()` rather than the panel the capsule floats in.
    ///
    /// Owned by `PillContainerView` so there is one writer, but measured here because this is
    /// the view that knows where the shell actually is. The container cannot do it: its own
    /// bounds are the whole transparent panel.
    var onHoverChanged: (Bool) -> Void = { _ in }
    /// The state the *colours* are drawn from, which deliberately lags `model.state`.
    ///
    /// The container assigns it inside a `withAnimation`, so the tint and the border interpolate to
    /// the new state's hue while everything geometric - the shell's size, the clip, the content swap
    /// - reads `model.state` and changes instantly. That split is what allows a real transition here
    /// at all: resizing the glass body is the one thing that ghosts, but its *colour* is free to
    /// animate. The production pill starts at `.idle` until its first state transition.
    var colorState: PillState = .idle
    /// How far the shell's body has extended into the hands-free bead - see
    /// `PillShellShape.extrusion`. Owned by `PillContainerView`, which also positions the glyph
    /// from it. It starts at 0 while the pill is collapsed.
    var extrusion: CGFloat = 0
    var onCloseIsland: () -> Void = {}
    @ObservedObject private var motion = MotionPreference.shared
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    // No `@Namespace` for the glass any more.
    //
    // It existed to pair with a constant `glassEffectID`, on the theory that naming the body would
    // stop `glassEffect` cross-fading it while its shape changed every frame. That theory was
    // wrong: Apple documents `glassEffectID(_:in:)` as applying "during view hierarchy
    // transitions" - it identifies a shape that *appears or disappears* - and it has no bearing on
    // interpolating one body's size. The ghost is gone because the body's bounds no longer change
    // at all, because the shell's size change is instant (see `apply`), which needs no identity.

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: Space.x2) {
            content
            // Placed once, outside the state switch, because it is revealed in more than
            // one state now - a record ring on the resting pill, a stop square while a
            // session is latched. Keeping it in the `.idle` branch is what made the
            // pointer route one-way: you could start hands-free by clicking and then had
            // no way to stop it by clicking. `PillHoverControl` owns which states offer
            // it and what a press means there.
        }
        .padding(.horizontal, PillMetrics.horizontalPadding)
        // A minimum width, so the resting pill stays a *pill*.
        //
        // With only the microphone glyph inside, intrinsic width came out at 33pt
        // against a 28pt height - a 1.18 ratio, which is a circle, not a capsule.
        // 56pt holds a 2:1 capsule at rest and is still narrower than the old
        // keycap version. Wider states (level meter, timer, error text) grow past
        // it on their own, so this only ever affects the idle shape.
        .frame(minWidth: PillMetrics.minimumCapsuleWidth)
        // Lock the content at its own ideal width, so the animating box below cannot squeeze
        // it - and, more importantly, so what gets *measured* here is independent of what gets
        // *forced* there. `.fixedSize` discards the incoming width proposal, which is exactly
        // what breaks the measure -> set -> measure cycle: see `idealWidthProbe`.
        //
        // Not a layout change. The proposal reaching the row is `nil` either way, because
        // `PillContainerView` already wraps the whole pill in `.fixedSize()`, so every state
        // resolves to the same width it always did. What changes is only who is allowed to
        // *use* that width.
        .fixedSize(horizontal: true, vertical: false)
        .background { idealWidthProbe }
        // The one animating quantity in the morph - **both axes, one value.**
        //
        // This replaced `.frame(height: PillMetrics.shellHeight(for: model.state))` with the
        // width left intrinsic, and that pairing was the last cause of "it just bounces to the
        // note pop-up". The height was an animatable number interpolating 28 -> 124 under the
        // ambient transaction; the width was resolved from the content's ideal size by
        // `.fixedSize()` in `PillContainerView`, *above* every animation in this chain. So it
        // was not interpolated at all - `NoteCaptureBox` pins its content to
        // `PillMetrics.noteContentWidth`, and the ideal width stepped 56 -> 292 in the single
        // layout pass the state changed in. The shell snapped wide and then grew tall: two
        // events where the claim being made is one shape expanding.
        //
        // See `ShellSize` for why this is a type rather than a bare `.frame(width:height:)`.
        .modifier(ShellSize(
            width: PillMetrics.shellWidth(for: model.state, measured: model.capsuleWidth),
            height: PillMetrics.shellHeight(for: model.state)
        ))
        // Clip the interior to the pill's silhouette at whatever size the morph has reached,
        // so the growing capsule *reveals* the card instead of the card being drawn over it.
        // A mask, deliberately - not a transform: it was reverted once as a suspect in the
        // 2.0.84 crash, which turned out to be the ambient transaction colliding with the
        // window resize (see `setState`), and a clip cannot invalidate constraints.
        // Clip the *interior* to the capsule, not to the shell. Content never enters the lobe  - 
        // the bead carries a glyph drawn by `PillContainerView`, not a column of this row.
        .clipShape(PillShape())
        // Everything that draws the shell - glass, both strokes, the shadow - moved into this
        // background, and this is the change that makes the bead part of the pill.
        //
        // Applied to the content directly, all four are sized to the *capsule*, which leaves the
        // lobe nowhere to be drawn. A background does not participate in its parent's layout, so
        // a deliberately wider one grows the drawn shell rightward without moving the capsule:
        // giving the button a slot in the row instead is what shifted the microphone off centre
        // (`PillMetrics.handsFreeButtonSide` records it), and the panel has the room - the idle
        // bead's right edge lands 100pt inside the 320pt panel.
        //
        // The size comes from a `GeometryReader` *inside* the background rather than from the
        // numbers handed to `ShellSize`, and that distinction is load-bearing. Those numbers are
        // the animation's *target*; a reader here sees the size `ShellSize` has already resolved
        // for this frame, so glass, both strokes, the shadow and the clip above are all drawn at
        // one interpolated size. Reading the target instead would put the shell at its final
        // width on frame one - the snap, moved rather than fixed. At this morph's measured peak
        // of 1186 pt/s a single frame of disagreement is up to 9.9pt at 120Hz, which is the
        // shimmer the shape consolidation exists to delete.
        //
        // It publishes nothing upward, so it is not the self-measuring layout the main window
        // forbids (`nshostingview-intrinsic-size-collapses-window`).
        //
        // **And it must never publish `model.capsuleWidth`.** It used to, when the box it
        // measures and the pill's ideal width were the same rect. They are not any more: this
        // rect is `ShellSize`'s output, and `ShellSize`'s input is `model.capsuleWidth`. Writing
        // it from here would close that loop - `width = max(width, 56)` has a fixpoint at every
        // value, so the pill would not oscillate, it would *stick*, frozen at whatever width it
        // first measured and never widening for a level meter or a transcript again. The
        // measurement now comes from `idealWidthProbe`, one layer in, where nothing forces it.
        //
        // Wrapped in `GlassCluster` (a gated `GlassEffectContainer`) so the shell's
        // glass carries a constant `glassEffectID` across the morph: the reader
        // hands `glassEffect` a shape it reads as new every frame, which without an
        // identity is cross-faded - the old body fading behind the new one *is* the
        // ghost capsule. The container makes it one persistent body that morphs. It
        // is inside a `.background`, so it publishes no size upward and cannot become
        // the hosting root the window-collapse note forbids; on the fallbacks
        // `GlassCluster` is a passthrough and this is exactly what it was before.
        // The shell - glass, both strokes and the shadow - sized to the silhouette it draws.
        //
        // **The bounds must hug the shape, and that is now a measured fact rather than a
        // preference.** A previous version of this pinned the glass to a constant
        // `maxShellWidth` x `maxShellHeight` rectangle and animated only the path inside it, on the
        // reading that `glassEffect` "anchors the Liquid Glass to a view's *bounds*" and so a
        // *fixed* bounds could not be re-anchored mid-animation. The reading of the sentence was
        // right and the conclusion drawn from it was wrong: the material fills those bounds, it is
        // not clipped to the shape drawn in them. On screen that produced a pale full-panel slab
        // sitting behind the pill - visible for as long as the pill was up, which during
        // transcription is several seconds, and reported as "the full note pop-up stays for a few
        // seconds white".
        //
        // So the glass is sized to the shell again. The consequence is accepted rather than worked
        // around: a size change re-anchors the body, the system cross-fades the old against the new,
        // and that cross-fade is the ghost. Therefore **the shell's size change is instant** (see
        // `PillWindow.apply`) - an instant change has no intermediate frames to cross-fade. What
        // animates instead is everything that is not the glass body.
        //
        // No `GlassCluster` and no `GlassMorphIdentity`. There is exactly one glass body here and
        // nothing appears or disappears beside it, so the container had nothing to merge and the
        // identity had nothing to match - Apple documents that identity as acting "during view
        // hierarchy transitions", which is a shape appearing or disappearing, not a resize. Apple
        // also notes a real cost for containers that do no work. The mechanism is kept in
        // `GlassSurface.swift` because it is right for the case it documents; this is not that case.
        .background(alignment: .leading) {
            GeometryReader { geo in
                shell(capsuleWidth: geo.size.width, height: geo.size.height)
            }
        }
        // Hit-test the whole capsule, not whatever SwiftUI infers from the glass and the
        // glyph row inside it. Without this the reveal only fired near the trailing end of
        // the pill - the pointer had to reach the part of the row the control appears in  - 
        // where the ask is that it appears the moment the pointer is anywhere on the pill.
        //
        // The capsule, not the shell: the bead reports its own hover, and a contentShape covering
        // the lobe would take the presses meant for it.
        .contentShape(PillShape())
        // The pill's own hover, on the pill's own silhouette.
        .onHover(perform: onHoverChanged)
        // The island's buttons have to stay reachable; every other state is one element.
        .accessibilityElement(children: model.state.isIsland ? .contain : .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(model.state.isRecordingLike ? .updatesFrequently : [])
        // The control is revealed by hovering, which VoiceOver has no way to do, and the pill
        // is one accessibility element so the button inside it is unreachable. Offered as
        // an action on the element instead - and only in the state where it is offered to a
        // pointer, so VoiceOver never announces an action that would be swallowed.
        .modifier(HandsFreeAccessibilityAction(
            start: PillHoverControl.isOffered(in: model.state) ? onStartHandsFree : nil,
            name: PillHoverControl.actionName(in: model.state)
        ))
    }

    // MARK: The width the content asks for

    /// Measures the content's *ideal* width and publishes it, for the states whose width
    /// nothing can know ahead of layout.
    ///
    /// **Why the loop does not close, stated as arithmetic rather than hoped for.** This sits
    /// inside `.fixedSize(horizontal: true, vertical: false)`, which discards the width
    /// proposal - so the rect measured here is a function of the content alone and is
    /// *constant* with respect to `ShellSize`'s width. The dependency graph is therefore
    /// one-way:
    ///
    ///     capsuleWidth  ->  ShellSize.width  ->  the drawn box
    ///     capsuleWidth  <-  the content's ideal width   (never the drawn box)
    ///
    /// The gain around the cycle is zero, so it settles in exactly one extra layout pass and
    /// cannot oscillate: pass one lays the content out at its ideal and reports W, the write
    /// invalidates, pass two forces W and measures the same W again. Wire the probe to the
    /// *outer* box instead and the gain becomes one - see the note on that background for what
    /// that costs.
    ///
    /// The one-pass lag is why `PillMetrics.shellWidth(for:)` returns a constant for every
    /// state that is an endpoint of the note-card morph. This value is only ever the *starting*
    /// width of a morph, never the destination, and a starting width has been settled for at
    /// least a frame by definition.
    ///
    /// `Color.clear` inside a `.background`, which never participates in its parent's layout,
    /// so nothing intrinsic is published up through `NSHostingView`.
    private var idealWidthProbe: some View {
        GeometryReader { geo in
            Color.clear
                // Report the capsule's real width, so the companion can sit against its visible
                // edge rather than the window's, and so `drawnShellRect` knows where the pill
                // ends.
                .onChange(of: geo.size.width) { width in model.capsuleWidth = width }
                // `onChange` doesn't fire for the initial value, so seed it too.
                .onAppear { model.capsuleWidth = geo.size.width }
        }
    }

    // MARK: The shell

    /// The one glass body, the one outline, and the shadow under both.
    ///
    /// `PillShellShape` is handed to `glassSurface`, to both `strokeBorder`s and (through the
    /// rendered result) to `PillElevation`, so all four describe the same silhouette at every
    /// frame of the extrusion - capsule, neck and lobe as one continuous contour. There is no
    /// field function to approximate and nothing that can drift, which is exactly what a stroke
    /// drawn over `GlassEffectContainer`'s blended body could not promise.
    ///
    /// It degrades without losing the extrusion, which is the other half of why it is a shape:
    ///
    ///   * **Reduce Transparency** - `ChromeGlass` fills the shape with `Surface.raised` and
    ///     strokes it with `Line.strong`. The opaque fill *is* the union, so the pill still grows
    ///     a bead and still has one outline. There is no glass and so no merge, and nothing here
    ///     ever depended on one.
    ///   * **Pre-macOS-26** - `.regularMaterial` in the same shape. No lensing, so no light bends
    ///     across the neck, but the neck is there and thins from 25.8pt to 1.9pt before it lets go.
    /// The one glass body, the one outline, and the shadow under both.
    ///
    /// Sized by the `GeometryReader` that calls it, so the glass, both strokes and the shadow are
    /// all drawn at exactly the size the shell currently is - the material fills its view's bounds,
    /// so bounds larger than the silhouette render as a visible slab behind it.
    private func shell(capsuleWidth: CGFloat, height: CGFloat) -> some View {
        let shape = PillShellShape(extrusion: extrusion, capsuleWidth: capsuleWidth)
        return Color.clear
            .frame(width: PillMetrics.shellWidthWithBead(capsuleWidth: capsuleWidth),
                   height: height)
            // Foundation contrast layer so white glyphs and waveform bars never wash out over bright wallpapers
            .background(shape.fill(Color.black.opacity(isDark ? 0.35 : 0.42)))
            // The pill is the purest case for real Liquid Glass: a small floating control layer with
            // nothing but desktop behind it. State colour rides *on* the glass as a tint rather than
            // replacing it, so the material still refracts the wallpaper while reading as
            // recording/error/etc.
            .glassSurface(
                stateGlassTint == nil ? .chrome : .accentControl,
                in: shape,
                reduceTransparency: motion.reduceTransparency,
                isDark: isDark,
                tint: stateGlassTint
            )
            // A real border, always drawn.
            //
            // This was previously suppressed on macOS 26, on the theory that Liquid Glass's own
            // travelling highlight defines the silhouette well enough. In practice it does not: the
            // pill floats over arbitrary wallpaper with nothing but a soft shadow, so its edge
            // dissolves against busy or mid-toned backdrops and it reads as a translucent smudge
            // rather than an object.
            //
            // Two strokes, because one cannot do both jobs at once: an outer contrast ring that
            // holds the shape against *any* backdrop, and an inner top-lit highlight for the
            // glass-edge quality. Both are thin enough not to fight the material's own lighting.
            .overlay {
                ZStack {
                    shape.strokeBorder(borderColor, lineWidth: 1)
                    // `.inset(by:)`, not `.padding(0.6)`. Padding shrinks the *rect*, and this shape
                    // derives its body from the stored `capsuleWidth` rather than from the rect - so
                    // padding would slide the highlight 0.6pt to the right at the same width as the
                    // ring outside it, and it would cross that ring on the trailing edge.
                    // `inset(by:)` is the shape's own concentric offset and is what `strokeBorder`
                    // itself routes through.
                    // The light half of the two-tone edge, and the reason the pill is still visible
                    // on a dark backdrop once the ring outside it has receded.
                    //
                    // Appearance-independent for the same reason the ring is: keyed on `isDark` this
                    // dropped to 0.32 in dark appearance, which together with a white outer ring left
                    // the pill with no dark edge at all over a pale window.
                    shape.inset(by: 0.6)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.60), .white.opacity(0.14)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                }
            }
            // Glass carries a content-aware shadow of its own - Apple: it "increases the opacity of
            // its shadow when it is over text" and lowers it over a light background. Adding a
            // second fixed shadow doubles it.
            //
            // Applied last, so it composites over the rendered union and follows the neck for free  - 
            // a second silhouette cue exactly where the outline is thinnest.
            .modifier(PillElevation(dark: isDark,
                                    reduceTransparency: motion.reduceTransparency))
    }

    // MARK: Content per state

    /// The row of glyphs (or the note card) for the current state, with **every** branch swapped
    /// instantly rather than cross-faded.
    ///
    /// `.transition(.identity)` belongs out here, on the switch, and putting it on only one branch
    /// was a real bug rather than an oversight. A `switch` in a `ViewBuilder` inserts one branch and
    /// removes another, and each gets its own transition: the note card carried `.identity`, so it
    /// no longer faded *in* - but the outgoing recording row still had SwiftUI's default `.opacity`,
    /// so it kept fading *out* on top of the card for the length of the transaction. That is the
    /// "ghosts from the pill" seen when the note pop-up opens: two states' glyphs drawn over each
    /// other, one of them dissolving. Applied here it covers insertion and removal of every branch,
    /// so no two states are ever on screen together.
    private var content: some View {
        stateContent
            .animation(Motion.morph, value: model.state)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .preparing:
            BreathingDot(reduceMotion: motion.reduceMotion)

        case .idle:
            // Just the centered, high-contrast microphone glyph. No text clutter.
            AdaptivePillGlyph(systemName: "mic.fill", size: 13)

        case .capturingNote:
            NoteCaptureBox(model: model, liveTint: dotTint)

        case .recording:
            // Microphone morphs smoothly into active live sound waveform bars dancing with speech
            LevelMeter(signal: model.levels)

        case .handsFree:
            HStack(spacing: 4) {
                LevelMeter(signal: model.levels)
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Tint.handsFree)
            }

        case .capturingMemory:
            HStack(spacing: 4) {
                LevelMeter(signal: model.levels)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Tint.accent)
            }

        case .processing:
            // Waveform morphs into the writing pen, indicating active typing into the active application
            WritingPen(reduceMotion: motion.reduceMotion)

        case .notice:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tint.accent)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tint.danger)

        case .island(let transcript):
            TranscriptIsland(transcript: transcript, onClose: onCloseIsland)
        }
    }

    /// Live-indicator dot colour. Note capture gets the accent rather than the
    /// hands-free hue, so the pill shows *where the text is going* - the one thing
    /// the recording itself cannot convey.
    private var dotTint: Color {
        switch model.state {
        case .capturingNote, .capturingMemory: return Tint.accent
        case .handsFree: return Tint.handsFree
        default: return Tint.recording
        }
    }

    // No countdown line. The pill used to draw an amber bar along its foot as the
    // hands-free silence timer drained, and along the note card's foot too. It was real
    // data - `AudioRecorder`'s VAD progress, never a timer pretending - but the user asked
    // for it gone twice, and a line that creeps across the pill every time you pause for
    // breath is more alarming than the auto-stop it was announcing. What is lost is stated
    // plainly rather than replaced by a different line: you can no longer *see* the
    // auto-stop coming, so a pause that ends the recording now ends it without warning.
    // Talking still cancels it, exactly as before.

    // MARK: Styling

    // No `stateTint`. It was a seven-case ramp of wash colours that nothing painted with any more  - 
    // `stateGlassTint` below replaced it when the pill became real glass - computed only so that
    // `shell` could ask `stateTint == .clear` to choose a role. `shell` now asks `stateGlassTint`,
    // which is the value it actually passes as `tint:`, so the question is answered by the table it
    // is about. Two tables answering the same question is one of them drifting later.

    /// The state colour as a *glass tint*.
    ///
    /// Stronger than `stateTint` on purpose: that value was designed as a flat
    /// wash painted over an opaque capsule, whereas a tint is mixed into a
    /// material that is already sampling the wallpaper. At wash opacities the
    /// colour disappears entirely. Idle stays untinted - plain glass is the
    /// resting state, and the HIG asks that colour be reserved for emphasis.
    private var stateGlassTint: Color? { Self.glassTint(for: colorState) }

    /// The state colour as a *glass tint*, for an explicitly named state.
    ///
    /// Takes the state rather than reading `model.state`, because the container hands down a value
    /// that *lags* inside an animated transaction - that lag is what lets the hue cross-fade while
    /// the shell's geometry changes instantly. See `PillContainerView.colorState`.
    static func glassTint(for state: PillState) -> Color? {
        switch state {
        case .idle: return nil
        case .preparing, .processing, .notice, .island: return Tint.accent.opacity(0.45)
        case .recording: return Tint.recording.opacity(0.50)
        case .handsFree: return Tint.handsFree.opacity(0.52)
        case .capturingNote, .capturingMemory: return Tint.accent.opacity(0.52)
        case .error: return Tint.danger.opacity(0.52)
        }
    }

    /// The pill's outer contrast ring.
    ///
    /// Stronger than the old `stateRim`, which was tuned as a hairline on top of an
    /// opaque capsule. Floating glass needs a border that survives a light *and* a
    /// dark backdrop, so this leans on the state colour when there is one and on a
    /// neutral contrast edge when the pill is at rest.
    private var borderColor: Color { Self.border(for: colorState) }

    /// The pill's outer contrast ring, for an explicitly named state. See `glassTint(for:)`.
    /// The pill's outer contrast ring.
    ///
    /// **Appearance-independent, and that is the fix for the pill disappearing.** This used to answer
    /// `isDark ? .white.opacity(0.22) : .black.opacity(0.18)` - i.e. it chose its tone from the *app's*
    /// colour scheme. But the app's appearance and what is actually *behind* the pill are independent:
    /// the pill floats over the desktop, so a dark appearance can sit over a white window and a light
    /// appearance over a black one. In dark appearance both of the pill's strokes came out white (this
    /// ring at 0.22 and the inner highlight at 0.32), so over anything pale the pill had no dark edge
    /// anywhere and dissolved into it. Reported as: over a white background the pill goes white, and
    /// the same in reverse.
    ///
    /// The silhouette is now carried by a **two-tone edge** instead: this dark hairline on the outside
    /// and the light top-lit highlight just inside it. One of the two always registers, whatever is
    /// behind - which is how native controls survive being drawn over arbitrary content. Neither
    /// depends on the appearance, so neither can pick the one tone that vanishes.
    static func border(for state: PillState) -> Color {
        switch state {
        case .idle:
            // Dark, always. On a pale backdrop this is the edge; on a dark one it recedes and the
            // inner highlight takes over.
            return .black.opacity(0.30)
        case .preparing, .processing, .notice, .island:
            return Tint.accent.opacity(0.65)
        case .recording:
            return Tint.recording.opacity(0.75)
        case .handsFree:
            return Tint.handsFree.opacity(0.75)
        case .capturingNote, .capturingMemory:
            return Tint.accent.opacity(0.75)
        case .error:
            return Tint.danger.opacity(0.75)
        }
    }

    // No `stateRim`. It was the hairline the pill's outline used before `borderColor` above replaced
    // it, and it outlived the modifier that read it: seven colours nothing asked for. Worse than
    // dead, because `PillState` is exhaustively switched here - adding a state would have made the
    // compiler demand a rim colour for an outline that no longer exists.

    // No `.animation(_:value:)` on the shell, and no `stateKey` to drive one.
    //
    // There used to be `.animation(morphAnimation, value: stateKey)` here, and it was the second
    // of two drivers for one silhouette. `PillWindow.apply(_:)` is the only production writer of
    // `state` and already wraps the mutation in `withAnimation`; no view-local state driver remains.
    // Deleting the second driver left one *transaction*.
    //
    // One transaction was necessary and not sufficient, and that is the whole of why this bug
    // survived four fixes. Both axes rode the same transaction afterwards and the morph still
    // read as a snap-then-grow, because they rode it by two different *mechanisms*: the height
    // was an animatable number in a `.frame(height:)`, and the width was a layout
    // recomputation from the content's ideal size, which no transaction can interpolate.
    // `ShellSize` is what made them one mechanism - one `AnimatablePair`, both axes read from
    // it - and that is now the only thing that sizes the shell, the clip, the glass, both
    // strokes, the shadow and the lobe.

    // MARK: Accessibility

    private var accessibilityLabel: String {
        switch model.state {
        case .notice(let message): return "Utter, \(message)"
        case .preparing: return "Utter, getting ready"
        case .idle: return "Utter, ready"
        case .recording: return "Utter, recording"
        case .handsFree: return "Utter, recording hands-free"
        case .capturingNote: return "Utter, dictating into a note"
        case .capturingMemory: return "Utter, listening for a memory"
        case .processing(let phase): return "Utter, \(phase.rawValue.lowercased())"
        case .error: return "Utter, error"
        case .island: return "Utter, transcript not typed"
        }
    }

    /// Elapsed seconds only - never the meter value. A 30 Hz numeric update
    /// would make VoiceOver unusable.
    private var accessibilityValue: String {
        switch model.state {
        case .notice(let message):
            return message
        case .preparing:
            return "Loading the speech model. Dictation will be available in a moment."
        case .idle:
            return "Hold \(userData.hotkeyName) to dictate"
        case .recording:
            return "\(model.elapsed) seconds"
        case .handsFree:
            return "\(model.elapsed) seconds. Stops automatically after you finish speaking."
        case .capturingNote:
            // Names the destination, because the box that shows it on screen is behind
            // `children: .ignore` and VoiceOver cannot reach into it. The live transcript
            // deliberately stays out: it is a preview that rewrites itself every second,
            // and announcing that would bury the two facts that matter.
            //
            // The chord is spelled rather than drawn - `KeyChord.symbols` is glyphs, and
            // VoiceOver reads those as nothing useful.
            let destination = NoteStore.shared
                .captureDestination(appendsToOpenNote: userData.captureAppendsToOpenNote)
            return "\(model.elapsed) seconds. \(destination.label). "
                + "Press \(KeyChord.noteCapture.spelled) to finish."
        case .capturingMemory:
            return "\(model.elapsed) seconds. Saving privately in Companion. "
                + "Press \(KeyChord.memoryCapture.spelled) to finish."
        case .processing:
            return "Please wait"
        case .error(let reason):
            return reason
        case .island:
            return "No text field was focused, so nothing was typed. Copy it from here."
        }
    }
}

extension PillMetrics {
    static let islandLines: CGFloat = 6
    static let islandLineHeight = ceil(NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: 13)))
    static let islandButtonRow: CGFloat = 22
    static var islandHeight: CGFloat { islandLines * islandLineHeight + islandButtonRow + Space.x2 * 3 }
    static var islandWindowHeight: CGFloat { max(windowHeight, islandHeight + verticalInset * 2) }
}

/// A transcript held on the pill because there was nowhere to type it: up to six lines, then it
/// scrolls. Copy (⌘C once the island is clicked) and close both end it.
struct TranscriptIsland: View {
    let transcript: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            ScrollView {
                Text(transcript)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: PillMetrics.islandLines * PillMetrics.islandLineHeight)

            HStack(spacing: Space.x2) {
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(transcript, forType: .string)
                    onClose()
                }
                .keyboardShortcut("c", modifiers: .command)
                .accessibilityLabel("Copy transcript")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }
            .frame(height: PillMetrics.islandButtonRow)
        }
        .padding(.vertical, Space.x2)
        .frame(width: PillMetrics.noteContentWidth)
    }
}

/// A symbol that remains crisp and high-contrast over any wallpaper.
struct AdaptivePillGlyph: View {
    static let outerInk = Color.white
    static let innerInk = Color.black

    let systemName: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Self.outerInk)
            .shadow(color: Self.innerInk.opacity(0.40), radius: 1, x: 0, y: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - The shell's size

/// The shell's size - **both axes, one value.**
///
/// A type rather than a bare `.frame(width:height:)`, and the reasoning is worth keeping even now
/// that the size change is instant, because it is what stops the next person reintroducing the
/// original defect:
///
///   * **One `AnimatablePair`, so the axes cannot desynchronise.** Not two animatable properties
///     sharing a transaction - one value, from which both axes are read.
///   * **Neither axis can go missing.** `.frame(width:height:)` takes `CGFloat?`, and `nil` is not
///     one end of an interpolation - it is a layout recomputation. That was the bug the pill was
///     rejected five times for: the height was an animatable number stepping 28 -> 124 while the
///     width was resolved from the content's ideal size *above* every animation in the chain, so it
///     jumped 56 -> 292 in a single layout pass. The shell snapped wide and then grew tall. Storing
///     two non-optional `CGFloat`s makes that unrepresentable.
struct ShellSize: ViewModifier, Animatable {
    var width: CGFloat
    var height: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set {
            width = newValue.first
            height = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content.frame(width: width, height: height)
    }
}

// MARK: - Level meter

@MainActor
final class LevelMeterModel: ObservableObject {
    @Published var history: [Float] = Array(repeating: 0, count: LevelMeter.barCount)
    @Published var publishes = 0

    func process(newValue: Float, publishesPerShift: Int) {
        publishes += 1
        if publishes % publishesPerShift == 0 {
            history.removeFirst()
            history.append(newValue)
        } else if !history.isEmpty {
            history[history.count - 1] = newValue
        }
    }
}

/// Seven bars fed by a ring buffer of real levels, so the shape scrolls right-to-left like a
/// hardware meter. No `repeatForever`, no staggered delays.
struct LevelMeter: View {
    @ObservedObject var signal: PillLevelSignal

    private static let publishesPerShift = 2
    static let barCount = 7

    @StateObject private var model = LevelMeterModel()

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(model.history.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(0.65 + 0.35 * Double(model.history[index])))
                    .frame(width: 3, height: max(3, 3 + 17 * CGFloat(model.history[index])))
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0.5)
            }
        }
        .frame(height: 20)
        .animation(nil, value: signal.value)
        .onChange(of: signal.value) { newValue in
            model.process(newValue: newValue, publishesPerShift: Self.publishesPerShift)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Breathing dot

@MainActor
final class BreathingDotModel: ObservableObject {
    @Published var big = false
}

/// A slow pulse for the preparing state. One element, one animation - enough to
/// say "working" without the busy-spinner look.
struct BreathingDot: View {
    let reduceMotion: Bool
    @StateObject private var model = BreathingDotModel()

    var body: some View {
        Circle()
            .fill(Tint.accent)
            .frame(width: 8, height: 8)
            .scaleEffect(reduceMotion ? 1 : (model.big ? 1.0 : 0.82))
            .opacity(reduceMotion ? 0.8 : (model.big ? 1.0 : 0.60))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    model.big = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Writing pen

/// The processing indicator: a pencil that writes.
///
/// The nib bobs along a short baseline and leaves a stroke behind it, so the
/// pill *depicts* what is happening (your words being written) instead of
/// showing a generic progress line. One repeating animation, clipped to the
/// capsule, honours Reduce Motion by holding still.
struct WritingPen: View {
    let reduceMotion: Bool

    static let canvasSize = CGSize(width: 30, height: 20)
    private static let cycle = 1.45
    private static let writingFraction = 0.78

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.55 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
            let raw = min(1, phase / Self.writingFraction)
            let progress = raw * raw * (3 - 2 * raw)
            let opacity = phase <= Self.writingFraction
                ? 1
                : max(0, 1 - (phase - Self.writingFraction) / (1 - Self.writingFraction))
            let point = Self.writingPoint(at: progress, in: Self.canvasSize)

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    let path = Self.writingPath(upTo: progress, in: canvasSize)
                    context.stroke(
                        path,
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                }
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0.5)
                AdaptivePillGlyph(systemName: "pencil.tip", size: 9)
                    .rotationEffect(.degrees(-26))
                    .position(point)
            }
            .opacity(opacity)
            .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        }
        .accessibilityHidden(true)
    }

    static func writingPoint(at progress: Double, in size: CGSize) -> CGPoint {
        let p = min(max(progress, 0), 1)
        return CGPoint(
            x: 3 + p * (size.width - 9),
            y: size.height * 0.57
                + sin(p * .pi * 4) * 2.25
                + sin(p * .pi * 8 + 0.6) * 0.65
        )
    }

    static func writingPath(upTo progress: Double, in size: CGSize) -> Path {
        let clamped = min(max(progress, 0), 1)
        let samples = max(2, Int(36 * clamped))
        var path = Path()
        path.move(to: writingPoint(at: 0, in: size))
        for index in 1...samples {
            path.addLine(to: writingPoint(
                at: clamped * Double(index) / Double(samples),
                in: size
            ))
        }
        return path
    }
}

/// Elevation for the pill.
///
/// On macOS 26 the Liquid Glass material provides its own shadow, and Apple
/// describes it as content-aware: it "increases the opacity of its shadow when it
/// is over text" and lowers it "over a solid light background", with light
/// reflecting and bleeding into the shadow. A hand-drawn shadow on top of that
/// doubles the darkness and freezes it, so the pill only gets an explicit shadow
/// where there is no real glass to supply one.
private struct PillElevation: ViewModifier {
    let dark: Bool
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if GlassSupport.active(reduceTransparency: reduceTransparency) {
            // A single very soft ambient shadow, well below what the old
            // `.floating` pair drew: enough to seat the pill over a busy
            // wallpaper without fighting the material's own grounding.
            content.shadow(color: .black.opacity(dark ? 0.22 : 0.10),
                           radius: 12, y: 4)
        } else {
            content.elevation(.floating, dark: dark)
        }
    }
}
