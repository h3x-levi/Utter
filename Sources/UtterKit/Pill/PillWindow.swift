import SwiftUI
import Cocoa

enum PillState: Equatable {
    /// The speech model is still loading. Distinct from `idle` because holding
    /// the hotkey now would queue behind the load rather than record — telling
    /// the user "Hold Fn to dictate" here would be a lie.
    case preparing
    case idle
    case recording
    case handsFree
    /// Hands-free, but the transcript is going into a Utter note rather than
    /// being typed into the frontmost app. A separate state because the
    /// *destination* is the one thing the user cannot otherwise see — the
    /// recording itself looks identical either way.
    case capturingNote
    /// The pipeline has three distinct phases; naming the current one is real
    /// feedback, where the old wiggling pencil carried no information.
    case processing(Phase)
    case error(String)
    /// A neutral, transient confirmation — "New note, keep talking". Distinct from
    /// `.error` because that one carries a warning glyph and a danger tint, which
    /// would tell the user something had gone wrong when nothing had.
    case notice(String)

    enum Phase: String {
        case transcribing = "Transcribing"
        case rewriting = "Rewriting"
        case typing = "Typing"
    }

    var isRecordingLike: Bool {
        self == .recording || self == .handsFree || self == .capturingNote
    }

    /// Hands-free variants keep recording until explicitly stopped, rather than ending when
    /// a held hotkey is released.
    var isHandsFreeLike: Bool {
        self == .handsFree || self == .capturingNote
    }
}

/// The microphone level, on a publisher of its own.
///
/// **Split off `PillStateModel` because it is the only quantity in the pill that moves at 30 Hz,
/// and the level meter is the only thing that draws it.** `@Published` invalidates every view
/// observing the *object*, not the property, so while `level` lived on the model a mic publish
/// re-ran the whole pill — and the pill is what is on screen for the entire length of every
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
/// `AppDelegate`'s `$inputLevel` sink, its reset to 0, the companion's `levelSource` pull and
/// `PillDemoView`'s scripted gallery all still assign and read `stateModel.level`.
final class PillLevelSignal: ObservableObject {
    @Published var value: Float = 0
}

/// Observable state for the pill, owned by AppDelegate.
final class PillStateModel: ObservableObject {
    @Published var state: PillState = .preparing

    /// Real microphone level, 0...1, forwarded from AudioRecorder — held on its own publisher.
    ///
    /// A pass-through rather than a stored `@Published`, so the 30 Hz write reaches only
    /// `LevelMeter` and not the glass, the strokes, the shell shape and the accessibility
    /// strings. See `PillLevelSignal` for the measurements.
    ///
    /// **The cost of that, stated so it is not discovered the hard way: reading `level` inside a
    /// SwiftUI `body` no longer subscribes to it.** A view that observes this model and draws
    /// `model.level` will render the value it happened to see and never update — it has to observe
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
    /// second is never late. That invalidated `PillContent` — glass, both strokes, the shell shape
    /// and the level meter — 10x/s to redraw a number that changes 1x/s, and it did it during
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
    /// Preview only — never typed anywhere. It comes from a fast, unbiased,
    /// unpolished pass over partial audio, so it lags and will disagree with the
    /// final text. Its job is to prove the app is hearing you.
    @Published var previewText: String = ""

    /// The width the capsule's *content* asks for, in points.
    ///
    /// The pill's *window* is a fixed 320pt wide and the capsule is centred inside
    /// it — 56pt at rest, wider once a level meter, timer or live transcript
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
    /// has to grow to cover it — and `ShapedHostingView` nils every click outside that
    /// region, which would make a visible button unclickable. View state, reported upward,
    /// exactly like `capsuleWidth`.
    /// Whether the pointer is over the pill or over the control beside it.
    ///
    /// The raw input, deliberately — not "is the button showing". `PillHoverControl` turns
    /// this into the reveal decision, and `PillWindow.drawnShellRect` and `PillContainerView`
    /// both ask it rather than each keeping an answer. Two answers is what made the stop
    /// button unclickable; see `drawnShellRect`.
    @Published var pointerInsidePill: Bool = false

    /// The companion's live behaviour engine, or `nil` while the companion is switched off.
    ///
    /// The note card draws the character itself while it is open, and the desktop panel
    /// steps aside for the duration (`CompanionWindow.applyCardHandover`) — so there is
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
    /// is the one expensive thing in it — a first `Image(nsImage:)` draw of an APNG frame plus a
    /// subscription to the companion's **30 Hz** behaviour ticker — and building it on the
    /// morph's first frame is what made opening look hurried while closing looked right.
    ///
    /// The asymmetry is structural, not a matter of taste in curves. Opening constructs
    /// `NoteCaptureBox`: three new `@ObservedObject` subscriptions, that first image decode, and
    /// then ~5 more `body` re-runs inside the animating window as the 30 Hz ticker fires. Closing
    /// constructs nothing — the removal snapshot re-lays-out behind the clip, where it cannot be
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
    /// On the model rather than inside a view because two of them draw it now — the
    /// capsule's timer and the note box's header — and a second copy of the format
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
    /// The pointer route into hands-free dictation — see `PillHoverControl`.
    ///
    /// Deliberately the *same* callback the ⌃⌥Space chord fires (`AppDelegate
    /// .toggleHandsFree`) rather than a second path into the recorder: a pointer route with
    /// its own entry point would be free to drift out of step with the chord's handling of
    /// upgrade, refusal-while-processing and rollback.
    private var onStartHandsFree: (() -> Void)?
    private let positionKey = "pillWindowPosition"

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
        // and removing the 40pt edge-snapping earlier only stopped it *jumping* — it stayed
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
            onStartHandsFree: { [weak self] in self?.onStartHandsFree?() }
        ))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        // Never let the SwiftUI content size this window. This is the whole of the
        // "note pop-up is broken — sometimes smaller, sometimes bigger, sometimes it
        // goes down and comes back up" report, and it is the same collapse `showMainWindow`
        // and `showOnboarding` (App.swift) already guard against.
        //
        // `NSHostingView.sizingOptions` defaults to `.standardBounds`, which includes
        // `.intrinsicContentSize` — so the hosting view publishes Auto Layout constraints for
        // its SwiftUI content's *ideal* size, and as this window's `contentView` those
        // constraints drive the window's dimensions instead of the reverse (Apple's docs, and
        // the two working windows above, both say so). The pill's ideal size is the shell size:
        // ~56×28 at rest, 292×124 as a note card, and — since the prior change made both axes
        // an animatable `ShellSize` — every value in between, republished at 60-120 Hz through
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
        // Only the capsule — or the note card, when it has grown into one — takes the
        // mouse. The rest of the panel is transparent to it, so a click beside the
        // pill reaches the desktop instead of vanishing into a dead zone.
        hostingView.interactiveRect = { [weak self] in self?.drawnShellRect ?? .zero }
        contentView = hostingView

        restorePosition()
    }

    /// Where the pill is actually drawn inside its panel, in content-view coordinates.
    ///
    /// The shell is bottom-anchored with `verticalInset` of clearance and centred
    /// horizontally, which is what `PillContainerView` lays out — so this has to be read
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
        // Bottom-anchored, in the hosting view's flipped (top-left, y-down) space —
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
        // outside this rect — so without the extension the bead would be plainly visible
        // and completely unclickable. Only extended while it is actually on screen, so the
        // resting pill keeps the tight hit region that stopped the dead zone swallowing
        // clicks meant for the desktop.
        //
        // Asks `PillHoverControl` the same question the view asks, rather than reading a
        // flag the view mirrored into the model. A mirror was what broke it: the flag was
        // written from the pointer alone (`pointer && isOffered`), while the button is drawn
        // from `isRevealed` — which is true in `.handsFree` *without* any pointer, because
        // stopping a latched session is a persistent control. Latching hands-free from the
        // chord with the pointer elsewhere therefore drew a stop button the window refused
        // every click for: the one control that ends the recording, visible and inert, with
        // no way to recover because reaching it delivered no hover either.
        if PillHoverControl.isRevealed(in: stateModel.state,
                                       pointerInsidePill: stateModel.pointerInsidePill) {
            // `shellWidth`, not `+ handsFreeButtonReach`: the bead's resting position is clamped
            // to the panel's edge, so past a ~256pt capsule the naive sum claims up to 10.5pt of
            // region that nothing is drawn in — points the window would take clicks for and the
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

    /// The most recent state any caller has asked for, applied or not.
    ///
    /// `setState` is called from 20-odd places and more than one of them fires twice in a
    /// single runloop turn. Two of those double-fires were real bugs:
    ///
    ///   * `⌃⌥N` from idle set `.capturingNote` twice — once inside `startRecording` (which
    ///     reads the same `captureToNote` flag) and once after it. The first call resized the
    ///     window and deferred its animation; the second, drained from the same libdispatch
    ///     drain, saw a window that was already tall and animated *immediately*, inside the
    ///     resize's own display cycle — defeating the deferral that existed to prevent that,
    ///     and then getting a second transaction on the same state a turn later. The
    ///     redundant call is gone and the window no longer resizes, but the shape of the
    ///     mistake is a property of the call sites, not of that one caller.
    ///   * A failed microphone start set `.capturingNote` and then `.error` in one turn. The
    ///     error applied inline while the note state was still deferred, so the note state
    ///     landed *after* it: the pill sat wedged as a note card that was recording nothing
    ///     and the error was never seen.
    ///
    /// So the newest request wins and repeats coalesce, rather than every call site having to
    /// know what the others did in the same turn.
    private var requestedState: PillState?

    /// Whether an apply is already queued for the next turn.
    private var applyScheduled = false

    func setState(_ state: PillState) {
        // One runloop turn of delay, not two.
        //
        // This used to open with an unconditional `DispatchQueue.main.async` *and then* schedule a
        // second one, so even a call already on the main thread waited two turns before anything
        // reached the screen. That is invisible on an idle app and not on a busy one: the main
        // thread here also carries the companion's ticker and every SwiftUI update, so two turns is
        // two chances to queue behind other work — and this is the path from a keypress to the pill
        // reacting.
        //
        // The hop is still needed when the caller is off the main thread, and the *scheduled* apply
        // is still needed: it is what coalesces repeats, which is the whole point of
        // `requestedState` (see its doc for the two real bugs that came from applying twice in one
        // turn). What is gone is the hop that bought nothing when already on main.
        if Thread.isMainThread {
            enqueue(state)
        } else {
            DispatchQueue.main.async { self.enqueue(state) }
        }
    }

    /// Record the newest requested state and make sure exactly one apply is queued for this turn.
    /// **Main thread only.**
    private func enqueue(_ state: PillState) {
        requestedState = state
        // One apply per turn, carrying whatever the newest request turned out to be.
        // A second `setState` in the same turn updates `requestedState` and returns —
        // it does not get an apply of its own to race the first one with.
        guard !applyScheduled else { return }
        applyScheduled = true
        DispatchQueue.main.async {
            self.applyScheduled = false
            guard let target = self.requestedState else { return }
            self.apply(target)
            // Returning to rest is the moment to honour "don't show the pill at all
            // times". Handled here rather than at the six `setState(.idle)` call sites,
            // so a new one can't forget to hide it.
            if target == .idle, !UserData.shared.alwaysShowPill, self.isVisible {
                self.orderOut(nil)
            }
        }
    }

    /// The one transaction that drives the morph.
    ///
    /// Everything the shell does — width, height, glass, both strokes, the clip and the bead's
    /// lobe — rides this single `withAnimation`, and reaches the screen through the single
    /// `AnimatablePair` in `ShellSize`. Those are two separate requirements and it took both.
    ///
    /// It used to ride two transactions: this one, plus an `.animation(morphAnimation, value:
    /// stateKey)` attached inside `PillContent`. Deleting that left one transaction — and the
    /// morph still read as a snap followed by a growth, because one transaction cannot animate a
    /// quantity that is not a value. The height was `.frame(height:)`, an animatable number. The
    /// width was intrinsic, resolved from the content's ideal size by `.fixedSize()` in
    /// `PillContainerView`, which sits *above* every animation in the chain: a layout
    /// recomputation, stepping 56 -> 292 in the pass the state changed in. `ShellSize` is what
    /// turned the width into a value, so the two axes are now one interpolation rather than one
    /// interpolation and one relayout. That is the "jittery" as distinct from the "very fast".
    ///
    /// Nothing here resizes a window, so there is no display cycle for a SwiftUI animation to
    /// start inside: `PillMetrics.windowHeight` is a constant (its doc explains why), and the only
    /// frame calls anywhere in the pill are the two `setFrameOrigin`s in the position methods,
    /// neither on a state path. The two `DispatchQueue.main.async` hops above are kept exactly as
    /// they were — they are no longer buying crash avoidance, they are buying the coalescing that
    /// `requestedState` documents.
    private func apply(_ target: PillState) {
        // **The shell's size change is instant, and that is now an evidence-based decision rather
        // than a taste one.**
        //
        // Nine attempts at an animated morph have failed, and they failed for one reason that took
        // all nine to name: `glassEffect` fills its view's *bounds*, so the bounds must match the
        // silhouette, and a bounds change re-anchors the glass body — at which point the system
        // cross-fades the outgoing body against the incoming one. Every intermediate frame of an
        // animated resize is a doubled pill. There is no intermediate frame if there is no
        // animation.
        //
        // The dead ends, so nobody spends another release on them:
        //
        //   * Animating the frame, with or without `ShellSize` as a single `AnimatablePair` — the
        //     original ghost, seen repeatedly.
        //   * A constant `glassEffectID` inside a `GlassEffectContainer` — Apple documents that
        //     identity as acting "during view hierarchy transitions", i.e. when a shape appears or
        //     disappears. It has nothing to say about a resize, so it silently does nothing.
        //   * Constant oversized bounds with only the `Shape`'s path animating inside them. This
        //     looked correct on paper and was worse in practice: the material filled the whole
        //     fixed rectangle instead of being clipped to the path, so a pale full-panel slab sat
        //     behind the pill for as long as it was on screen — several seconds during
        //     transcription.
        //   * Masking a full-size body down, and `scaleEffect`. The first strips the specular rim
        //     (a mask removes pixels and cannot synthesise a new lit edge, so it reads as a die-cut
        //     hole); the second needs anisotropic scaling, because the capsule and the card are
        //     2.00 and 2.355 aspect ratios, which turns the corner arcs into ellipses.
        //
        // What *is* animated is everything that is not the glass body: the hands-free bead's
        // extrusion, the hover reveal and the state tint all keep their own transactions, none of
        // which resizes a glass body. If an animated expansion is wanted later, the route left is
        // AppKit's `NSGlassEffectView` driven by Core Animation, which is a different rendering
        // path — not another SwiftUI transaction.
        stateModel.state = target

        // Set outright, not staged. `noteCardSettled` gates the card's companion column, and it was
        // briefly delayed so that an expensive first APNG decode could not land inside the morph's
        // opening frames. With no morph there is nothing to protect: a delay here would simply leave
        // the card visibly empty for the length of it.
        stateModel.noteCardSettled = PillMetrics.isExpanded(target)
    }

    /// The state the pill is going to be in — the newest request, applied or not.
    ///
    /// Reads the *requested* state rather than the applied one, because `setState` defers its apply
    /// by a runloop turn and callers use this to decide whether to overwrite it. `showPillError`'s
    /// 2.5-second timer asks "is an error still showing?" before returning the pill to `.idle`: if a
    /// recording started in the same turn as that timer fired, the applied state was still `.error`,
    /// the guard passed, and `.idle` overwrote the pending `.recording` — hiding the pill while a
    /// recording ran invisibly, which is the exact outcome the guard exists to prevent.
    /// `applyPillVisibility` reads `isRecordingLike` off this for the same reason.
    var currentState: PillState { requestedState ?? stateModel.state }

    // MARK: - Position

    // `savePosition` used to live here, writing the dropped origin as a fraction of the
    // visible frame. It went with the drag: nothing can move the pill any more, so there is
    // no new position to record. `restorePosition` still reads the key — an existing install
    // keeps the spot it was last left at — and "Reset Position" clears it, so the fallback to
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
    /// *subview* — the event still belongs to the window, and AppKit walks on to the window's
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

struct PillContainerView: View {
    @ObservedObject var stateModel: PillStateModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var motion = MotionPreference.shared
    var onLongPress: () -> Void = {}

    /// Whether the pointer is on the hands-free control. Lives here because the long press
    /// does; `PillContent` reports into it.
    @State private var pointerOnControl = false
    /// Whether the pointer is anywhere over the pill or its bead. Lives here because the
    /// bead is a sibling of the capsule, so the tracked region has to span both.
    @State private var pointerInsidePill = false

    /// The reveal, latched through `HoverRevealLatch` so it survives the pointer crossing the
    /// gap between the pill and the bead. Everything that shows the bead — `extrusion`, the
    /// button's `shown`, the window hit-region publish — reads this, not the raw flags, so the
    /// bead cannot retract mid-transit. See `HoverRevealLatch` for why.
    @State private var revealed = false
    @State private var revealLatch = HoverRevealLatch()
    /// The pending "hide after grace" flip. Cancelled the moment the pointer returns.
    @State private var hideWork: DispatchWorkItem?

    /// The settle: how far the shell is scaled while it springs into a new state.
    ///
    /// **Owned here, not in `PillContent`, and that placement is a fix rather than a preference.**
    /// It lived one level down and scaled only the capsule — but the hands-free bead's *glyph* is a
    /// sibling in this `ZStack`, so the pill's lobe scaled while the ring drawn on it did not. At the
    /// `.handsFree` capsule width the lobe's centre sits ~74pt from the anchor, so a 0.90 settle put
    /// the ring **7.4pt** off its own bead — 28% of the bead's diameter — for the length of the
    /// spring. Scaling this container transforms the capsule and the bead as the single object they
    /// are meant to read as.
    @State private var settle: CGFloat = 1

    /// The state the shell's **colours** are drawn from — assigned inside a transaction so the tint
    /// and border cross-fade, while geometry keeps reading `stateModel.state` and changes instantly.
    ///
    /// This is the transition the pill was most obviously missing. The tint and the outer ring were a
    /// hard cut: `idle -> recording` went from untinted glass with a neutral 0.18-0.22 border to red
    /// glass at 0.50 with a red border at 0.75, in a single frame. Unlike the note card, that fires on
    /// **every** dictation and on all nine states, so it is the snap the user actually meets — and
    /// colour is the one property here that is both freely animatable and provably unable to
    /// re-anchor the glass body, because it changes no bounds.
    ///
    /// Seeded on appear rather than initialised, since the real state is only known then.
    @State private var colorState: PillState = .idle

    /// Identifies the state's *case*, ignoring anything that rides inside it.
    ///
    /// The settle fires on a state change and **must not** fire on a width change: `.recording`
    /// republishes `capsuleWidth` on every word of the live transcript, so keying this on the drawn
    /// size would pulse the pill continuously while someone was talking.
    ///
    /// An `Int`, not a `String`. This is read on every `body` run, and `body` runs at 30Hz while
    /// recording (the microphone level publishes at that rate) — so a `String` here was an allocation
    /// and a comparison thirty times a second to answer a question that changes a handful of times
    /// per dictation.
    private var stateCase: Int {
        switch stateModel.state {
        case .preparing: return 0
        case .idle: return 1
        case .recording: return 2
        case .handsFree: return 3
        case .capturingNote: return 4
        case .processing: return 5
        case .notice: return 6
        case .error: return 7
        }
    }

    /// Restart the settle.
    ///
    /// **The deferred hop is what makes this animate at all.** Setting the start value and calling
    /// `withAnimation` in the same synchronous call does nothing: SwiftUI coalesces `@State` writes
    /// and evaluates the graph once, at the end of the turn, so the animation is built from the last
    /// *committed* presentation value (1) to the new value (1) — a delta of zero, and 0.90 is never
    /// displayed. It failed silently and safely, which is why the pill still looked right and still
    /// snapped. Committing the start values in one turn and animating home in the next gives the
    /// interpolation two different endpoints to work with.
    ///
    /// Only these two values are ever animated. An ambient transaction around the state change
    /// itself would also animate `ShellSize`, which resizes the glass body — the one thing that
    /// ghosts.
    private func restartSettle() {
        guard !motion.reduceMotion else {
            settle = 1
            colorState = stateModel.state
            return
        }
        // Scaled for constant edge travel, so the card does not lurch four times as far as the
        // capsule — see `Motion.settleEdgeTravel`.
        settle = Motion.settleScale(
            width: PillMetrics.shellWidth(for: stateModel.state, measured: stateModel.capsuleWidth),
            height: PillMetrics.shellHeight(for: stateModel.state)
        )
        // The colour crosses immediately — it has no start value to commit, it interpolates from
        // whatever hue is currently on screen to the new one.
        withAnimation(Motion.tintCross) { colorState = stateModel.state }
        DispatchQueue.main.async {
            withAnimation(Motion.settle) { settle = 1 }
        }
    }

    var onStartHandsFree: (() -> Void)? = nil

    /// How far the pill's body has extended into the hands-free bead: 0 reabsorbed, 1 at rest.
    ///
    /// One scalar, read by both the shell's shape and the glyph's offset, so the outline and the
    /// ring inside it are the same event rather than two animations of it. Asks
    /// `PillHoverControl.isRevealed` — the same question `PillWindow.drawnShellRect` asks — so
    /// what is drawn and what can be clicked cannot disagree. Two answers is what made the stop
    /// button visible and inert; see `drawnShellRect`.
    private var extrusion: CGFloat {
        guard onStartHandsFree != nil,
              PillHoverControl.isRevealed(in: stateModel.state,
                                          pointerInsidePill: revealed)
        else { return 0 }
        return 1
    }

    /// The capsule's drawn width — the same value `PillContent` hands to `ShellSize`.
    ///
    /// The bead's glyph has to be placed on the lobe the shell has drawn, and the shell is
    /// drawn at this width, so it must be asked for by the same expression rather than read off
    /// `capsuleWidth` directly. That distinction is not theoretical: `capsuleWidth` is now the
    /// content's *ideal* width, which lands a layout pass before the box that is forced from it.
    /// Reading it raw would put the glyph a frame ahead of its own bead every time a word
    /// arrived in the `.handsFree` live transcript — the same disagreement, in the opposite
    /// direction, that the shell's `GeometryReader` exists to avoid.
    private var drawnCapsuleWidth: CGFloat {
        PillMetrics.shellWidth(for: stateModel.state, measured: stateModel.capsuleWidth)
    }

    /// Recompute the reveal from the raw pointer flags, with grace on the way out.
    ///
    /// Called from both hover callbacks. On entry it reveals immediately and cancels any pending
    /// hide; on exit it does not hide now — it schedules one flip `HoverRevealLatch.grace` later,
    /// which a returning pointer cancels. That single deferred call is what actually lowers the
    /// bead, since no hover event fires while the pointer simply sits outside.
    private func refreshReveal() {
        let present = pointerInsidePill || pointerOnControl
        hideWork?.cancel()
        hideWork = nil
        revealed = revealLatch.update(present: present, at: ProcessInfo.processInfo.systemUptime)
        guard !present, revealed else { return }
        let work = DispatchWorkItem {
            revealed = revealLatch.update(present: false,
                                          at: ProcessInfo.processInfo.systemUptime)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + HoverRevealLatch.grace, execute: work)
    }

    var body: some View {
        // Anchored to the *bottom* of the window, not centred in it.
        //
        // The panel is a fixed `PillMetrics.windowHeight` — tall enough for the note card at
        // all times — so all but the last 28pt of it is empty in every resting state. The
        // shell has to be pinned to the edge the pill is positioned against. Centred, the
        // capsule would float 48pt above where `positionAtBottomCenter` put it, and the note
        // card would grow downward into the Dock the pill is parked above.
        //
        // `verticalInset` reproduces the previous centred position exactly: a 28pt
        // capsule centred in a 60pt window sat 16pt off the bottom.
        //
        // No `GlassEffectContainer` here any more. The bead is not a sibling glass body being
        // proximity-blended with the capsule; it is a *lobe of the capsule's own shape*, drawn by
        // `PillShellShape` inside `PillContent`. See that shape's doc for why — in one line, the
        // container's merged silhouette has no `Path`, so nothing could stroke it, and the pill's
        // outer contrast ring is not decoration.
        //
        // So what is left out here is the *glyph*, riding on top of a lobe the shell has already
        // drawn.
        ZStack(alignment: .bottom) {
            Color.clear
            // `onStartHandsFree` is forwarded because `PillContent` carries the
            // VoiceOver action for it: the bead is revealed by hovering, which VoiceOver
            // has no way to do, so the action on the pill's accessibility element is the
            // only route to hands-free without a pointer.
            PillContent(model: stateModel,
                        onStartHandsFree: onStartHandsFree,
                        onHoverChanged: { inside in
                            pointerInsidePill = inside
                            // Leaving the capsule clears the bead's flag too. The pointer
                            // can exit across the bead without SwiftUI delivering the
                            // inner `onHover(false)`, and a stale `true` is what
                            // `longPressOpensUtter` guards against.
                            if !inside { pointerOnControl = false }
                            refreshReveal()
                        },
                        colorState: colorState,
                        extrusion: extrusion)
                // No longer what resolves the pill's width — `ShellSize` inside `PillContent`
                // fixes both axes outright, so this proposes nothing to a view that would
                // ignore the proposal anyway. Kept because it still states the intent (the
                // pill sizes itself; the `ZStack` filling the 320x156 panel must not stretch
                // it), and because `PillDemoView` hosts `PillContent` without it, which is
                // the proof that the pill's size no longer depends on who is asking.
                .fixedSize()
                // The press sits out here, on the same rect as before the hands-free
                // control existed, and deliberately not on the shell inside `PillContent`:
                // a gesture there consumed the mouse-down the window needed, and the pill
                // stopped responding. It still yields to the bead — `pointerOnControl` is
                // reported up from `HandsFreeRevealButton` for exactly that.
                .onLongPressGesture(minimumDuration: 2.0) {
                    if PillHoverControl.longPressOpensUtter(in: stateModel.state,
                                                            pointerOnControl: pointerOnControl) {
                        onLongPress()
                    }
                }
                .padding(.bottom, PillMetrics.verticalInset)

            // The glyph on the bead — and only the glyph.
            //
            // It used to carry the bead's glass and its own two `Circle().strokeBorder`s, and
            // travel from a tucked offset to a resting one. All three are gone: the shell's shape
            // draws the bead now, so there is exactly one glass body and exactly one outline on
            // screen, and there is nothing here to keep in step with a merge it cannot see.
            //
            // Its offset reads `PillMetrics.lobeCentreOffset` — the *same* function the shape uses
            // to place the lobe — so the ring cannot sit a point off its own bead. Both are driven
            // by the same `extrusion` scalar in the same transaction.
            //
            // Kept always-present with `allowsHitTesting(shown)` rather than made conditional. An
            // invisible SwiftUI `Button` still takes clicks and still fires `onHover`, so the
            // tucked copy would capture presses meant for the pill and set `pointerOnControl`,
            // silently killing the 2s long press that opens Utter — and this is the form of that
            // guard `PillHoverControlTests` pins. Presence keyed on `shown` would swap one hazard
            // for another: SwiftUI is not obliged to deliver `onHover(false)` to a view it has just
            // removed, which is the stale-flag case `longPressOpensUtter` exists for.
            // Present whenever a handler exists — **not** gated on `isOffered`.
            //
            // The comment above spends six lines explaining why this must not be conditional, and
            // then the condition reintroduced exactly the hazard it describes. Stopping hands-free
            // moves the pill to `.processing`, which does not offer the control, so SwiftUI *removed*
            // this `Button` while the pointer was still on it — and delivered no `onHover(false)` for
            // a view it had just removed. `pointerOnControl` is only cleared inside the *capsule's*
            // `onHover(false)`, which cannot fire because the pointer was never on the capsule. So
            // the flag stuck true, and with it: the bead sat revealed on the resting pill with no
            // pointer near it, `longPressOpensUtter` returned false forever so the 2-second press
            // that opens Utter was dead, and `drawnShellRect` stayed extended over a 33pt strip that
            // ate desktop clicks. Recovering needed the pointer to enter *and* leave the capsule.
            //
            // Dropping the term costs nothing visually: `isRevealed` already requires `isOffered`, so
            // in every non-offering state `shown` is false, which means `extrusion` is 0 (tucked
            // inside the capsule's end arc, contributing nothing to the silhouette), the glyph's
            // opacity is 0, and it takes no clicks.
            if let onStartHandsFree {
                let shown = PillHoverControl.isRevealed(
                    in: stateModel.state,
                    pointerInsidePill: revealed
                )
                HandsFreeRevealButton(stops: PillHoverControl.stops(in: stateModel.state),
                                      emergence: shown ? 1 : 0,
                                      action: onStartHandsFree,
                                      onHoverChanged: { pointerOnControl = $0; refreshReveal() })
                    // Measured from the panel's centre, which is where the capsule's centre is:
                    // the lobe offset is measured from the capsule's trailing edge, so half the
                    // capsule's width bridges the two frames.
                    .offset(x: drawnCapsuleWidth / 2
                               + PillMetrics.lobeCentreOffset(extrusion: extrusion,
                                                             capsuleWidth: drawnCapsuleWidth))
                    .allowsHitTesting(shown)
                    // Centred on the capsule's own centre line, so the neck runs straight
                    // and the two read as one horizontal body.
                    .padding(.bottom, PillMetrics.verticalInset
                                      + (PillMetrics.capsuleHeight - PillMetrics.handsFreeButtonSide) / 2)
                    // No animation of its own. The container's single `.animation(value: revealed)`
                    // drives the glyph and the lobe it sits on together — a second transaction here
                    // is what put the ring on a different clock from its own bead.
            }
        }
        // **The settle** — the capsule and its bead scaled as one object.
        //
        // A transform, not a resize, and that is the whole reason it is allowed to animate:
        // `scaleEffect` transforms a layer that has already been composited, so the glass body is
        // neither re-anchored nor re-created and there is nothing for the system to cross-fade. An
        // animated *size* is the ghost, and nine attempts have died on it.
        //
        // The anchor is the shell's bottom edge, not the panel's — see
        // `PillMetrics.shellBottomAnchorY`. `Motion.settle` overshoots by 0.0006 on a 0.10 change, so
        // the drawn pill is never more than 0.18pt larger than `PillWindow.drawnShellRect` claims,
        // which keeps the clickable region a superset of the drawing at every frame.
        .scaleEffect(settle, anchor: UnitPoint(x: 0.5, y: PillMetrics.shellBottomAnchorY))
        // One settle per state change; never on a width change — see `stateCase`.
        .onChange(of: stateCase) { _ in restartSettle() }
        // Seeded, not initialised: `@State` cannot see the model at construction, and starting the
        // colours on `.idle` would cross-fade once on first appearance for no reason.
        .onAppear { colorState = stateModel.state }
        // Hover is tracked on the container, not the capsule.
        //
        // The button lives outside the pill now, so moving the pointer onto it *leaves* the
        // capsule — and a reveal driven by the capsule's own hover would hide the button the
        // instant you reached for it. `pointerOnControl` keeps it alive while the pointer is
        // on the bead.
        //
        // Deliberately NOT an `.onHover` out here. This view is a `ZStack` holding a
        // `Color.clear`, so it fills the entire 320x156 panel — and since the panel is now
        // permanently note-tall, an `.onHover` here fired with the pointer up to 96pt *above*
        // the capsule and 130pt either side of it. The bead appeared long before the pointer
        // reached the pill. `PillContent` reports its own hover against `PillShape()`
        // (`.contentShape(PillShape())`), which is the actual drawn capsule.
        // **One curve for the whole reveal**, and this is what makes the hands-free transition read
        // as smooth rather than as two things happening.
        //
        // It used to be `Motion.hoverIn` — `easeOut(0.11)` — while the bead's *glyph* carried its own
        // `.animation(Motion.morph, value: extrusion)`, a `snappy(0.32)` spring with 0.19 bounce. So
        // one event was drawn on two clocks: the pill's outline grew its lobe and settled in 110ms
        // while the ring inside it was still springing, and overshooting, for another 210ms. The
        // outline and the thing it is supposed to contain visibly disagreed.
        //
        // Now the container owns the transaction and the glyph has no animation of its own, so the
        // lobe, the neck, the outline and the ring are one interpolation. `Motion.morph` is the
        // spring, because a bead emerging from a liquid pill should have a little life in it — and
        // it is safe to animate, unlike the note-card resize: `PillMetrics.shellWidthWithBead` does
        // not depend on `extrusion`, so the glass body's frame is **constant** across the whole
        // reveal and only the path inside it changes. That is why this animation has never ghosted.
        // Emerge and retract differ — see `Motion.beadEmerge`. One transaction still drives the
        // lobe, the neck, the outline and the glyph together, which is the part that must not split.
        .animation(motion.reduceMotion ? nil
                                       : (revealed ? Motion.beadEmerge : Motion.beadRetract),
                   value: revealed)
        // Publish the raw pointer, not a decision about it. `PillWindow.drawnShellRect` and
        // this view both put it through `PillHoverControl.isRevealed`, so the drawn button and
        // the region that can be clicked cannot disagree.
        .onChange(of: revealed) { inside in
            stateModel.pointerInsidePill = inside
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The pill lives in its own NSPanel, so it needs the theme applied
        // directly — it doesn't inherit from the main window.
        //
        // Deliberately NO `.id(theme.id)` here. Keying the view on the theme
        // rebuilt the whole subtree from scratch every time `ThemeManager`
        // republished, and each rebuild restarted the glass material's fade-in —
        // which read as the pill quietly pulsing forever. Measured: brightness
        // swinging ~8% on a ~2s cycle while nothing on screen was changing,
        // where an identical static glass capsule held to within 0.03%.
        //
        // The theme still applies without it: `Tint`/`Surface` are computed
        // properties, and `themeManager` is observed here, so a theme change
        // invalidates this view and the children re-read the new values.
        .preferredColorScheme(themeManager.current.colorScheme)
        .tint(Tint.accent)
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
    /// the new state's hue while everything geometric — the shell's size, the clip, the content swap
    /// — reads `model.state` and changes instantly. That split is what allows a real transition here
    /// at all: resizing the glass body is the one thing that ghosts, but its *colour* is free to
    /// animate. Defaults to `.idle` for `PillDemoView`, which drives colours from the state directly.
    var colorState: PillState = .idle
    /// How far the shell's body has extended into the hands-free bead — see
    /// `PillShellShape.extrusion`. Owned by `PillContainerView`, which also positions the glyph
    /// from it. 0 in `PillDemoView`, which plays a scripted gallery with no pointer in it.
    var extrusion: CGFloat = 0
    @ObservedObject private var motion = MotionPreference.shared
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    // No `@Namespace` for the glass any more.
    //
    // It existed to pair with a constant `glassEffectID`, on the theory that naming the body would
    // stop `glassEffect` cross-fading it while its shape changed every frame. That theory was
    // wrong: Apple documents `glassEffectID(_:in:)` as applying "during view hierarchy
    // transitions" — it identifies a shape that *appears or disappears* — and it has no bearing on
    // interpolating one body's size. The ghost is gone because the body's bounds no longer change
    // at all, because the shell's size change is instant (see `apply`), which needs no identity.

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        HStack(spacing: Space.x2) {
            content
            // Placed once, outside the state switch, because it is revealed in more than
            // one state now — a record ring on the resting pill, a stop square while a
            // session is latched. Keeping it in the `.idle` branch is what made the
            // pointer route one-way: you could start hands-free by clicking and then had
            // no way to stop it by clicking. `PillHoverControl` owns which states offer
            // it and what a press means there.
        }
        .padding(.horizontal, PillMetrics.horizontalPadding)
        // A minimum width, so the resting pill stays a *pill*.
        //
        // With only the microphone glyph inside, intrinsic width came out at 33pt
        // against a 28pt height — a 1.18 ratio, which is a circle, not a capsule.
        // 56pt holds a 2:1 capsule at rest and is still narrower than the old
        // keycap version. Wider states (level meter, timer, error text) grow past
        // it on their own, so this only ever affects the idle shape.
        .frame(minWidth: PillMetrics.minimumCapsuleWidth)
        // Lock the content at its own ideal width, so the animating box below cannot squeeze
        // it — and, more importantly, so what gets *measured* here is independent of what gets
        // *forced* there. `.fixedSize` discards the incoming width proposal, which is exactly
        // what breaks the measure -> set -> measure cycle: see `idealWidthProbe`.
        //
        // Not a layout change. The proposal reaching the row is `nil` either way, because
        // `PillContainerView` already wraps the whole pill in `.fixedSize()`, so every state
        // resolves to the same width it always did. What changes is only who is allowed to
        // *use* that width.
        .fixedSize(horizontal: true, vertical: false)
        .background { idealWidthProbe }
        // The one animating quantity in the morph — **both axes, one value.**
        //
        // This replaced `.frame(height: PillMetrics.shellHeight(for: model.state))` with the
        // width left intrinsic, and that pairing was the last cause of "it just bounces to the
        // note pop-up". The height was an animatable number interpolating 28 -> 124 under the
        // ambient transaction; the width was resolved from the content's ideal size by
        // `.fixedSize()` in `PillContainerView`, *above* every animation in this chain. So it
        // was not interpolated at all — `NoteCaptureBox` pins its content to
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
        // A mask, deliberately — not a transform: it was reverted once as a suspect in the
        // 2.0.84 crash, which turned out to be the ambient transaction colliding with the
        // window resize (see `setState`), and a clip cannot invalidate constraints.
        // Clip the *interior* to the capsule, not to the shell. Content never enters the lobe —
        // the bead carries a glyph drawn by `PillContainerView`, not a column of this row.
        .clipShape(PillShape())
        // Everything that draws the shell — glass, both strokes, the shadow — moved into this
        // background, and this is the change that makes the bead part of the pill.
        //
        // Applied to the content directly, all four are sized to the *capsule*, which leaves the
        // lobe nowhere to be drawn. A background does not participate in its parent's layout, so
        // a deliberately wider one grows the drawn shell rightward without moving the capsule:
        // giving the button a slot in the row instead is what shifted the microphone off centre
        // (`PillMetrics.handsFreeButtonSide` records it), and the panel has the room — the idle
        // bead's right edge lands 100pt inside the 320pt panel.
        //
        // The size comes from a `GeometryReader` *inside* the background rather than from the
        // numbers handed to `ShellSize`, and that distinction is load-bearing. Those numbers are
        // the animation's *target*; a reader here sees the size `ShellSize` has already resolved
        // for this frame, so glass, both strokes, the shadow and the clip above are all drawn at
        // one interpolated size. Reading the target instead would put the shell at its final
        // width on frame one — the snap, moved rather than fixed. At this morph's measured peak
        // of 1186 pt/s a single frame of disagreement is up to 9.9pt at 120Hz, which is the
        // shimmer the shape consolidation exists to delete.
        //
        // It publishes nothing upward, so it is not the self-measuring layout the main window
        // forbids (`nshostingview-intrinsic-size-collapses-window`).
        //
        // **And it must never publish `model.capsuleWidth`.** It used to, when the box it
        // measures and the pill's ideal width were the same rect. They are not any more: this
        // rect is `ShellSize`'s output, and `ShellSize`'s input is `model.capsuleWidth`. Writing
        // it from here would close that loop — `width = max(width, 56)` has a fixpoint at every
        // value, so the pill would not oscillate, it would *stick*, frozen at whatever width it
        // first measured and never widening for a level meter or a transcript again. The
        // measurement now comes from `idealWidthProbe`, one layer in, where nothing forces it.
        //
        // Wrapped in `GlassCluster` (a gated `GlassEffectContainer`) so the shell's
        // glass carries a constant `glassEffectID` across the morph: the reader
        // hands `glassEffect` a shape it reads as new every frame, which without an
        // identity is cross-faded — the old body fading behind the new one *is* the
        // ghost capsule. The container makes it one persistent body that morphs. It
        // is inside a `.background`, so it publishes no size upward and cannot become
        // the hosting root the window-collapse note forbids; on the fallbacks
        // `GlassCluster` is a passthrough and this is exactly what it was before.
        // The shell — glass, both strokes and the shadow — sized to the silhouette it draws.
        //
        // **The bounds must hug the shape, and that is now a measured fact rather than a
        // preference.** A previous version of this pinned the glass to a constant
        // `maxShellWidth` x `maxShellHeight` rectangle and animated only the path inside it, on the
        // reading that `glassEffect` "anchors the Liquid Glass to a view's *bounds*" and so a
        // *fixed* bounds could not be re-anchored mid-animation. The reading of the sentence was
        // right and the conclusion drawn from it was wrong: the material fills those bounds, it is
        // not clipped to the shape drawn in them. On screen that produced a pale full-panel slab
        // sitting behind the pill — visible for as long as the pill was up, which during
        // transcription is several seconds, and reported as "the full note pop-up stays for a few
        // seconds white".
        //
        // So the glass is sized to the shell again. The consequence is accepted rather than worked
        // around: a size change re-anchors the body, the system cross-fades the old against the new,
        // and that cross-fade is the ghost. Therefore **the shell's size change is instant** (see
        // `PillWindow.apply`) — an instant change has no intermediate frames to cross-fade. What
        // animates instead is everything that is not the glass body.
        //
        // No `GlassCluster` and no `GlassMorphIdentity`. There is exactly one glass body here and
        // nothing appears or disappears beside it, so the container had nothing to merge and the
        // identity had nothing to match — Apple documents that identity as acting "during view
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
        // the pill — the pointer had to reach the part of the row the control appears in —
        // where the ask is that it appears the moment the pointer is anywhere on the pill.
        //
        // The capsule, not the shell: the bead reports its own hover, and a contentShape covering
        // the lobe would take the presses meant for it.
        .contentShape(PillShape())
        // The pill's own hover, on the pill's own silhouette.
        .onHover(perform: onHoverChanged)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(model.state.isRecordingLike ? .updatesFrequently : [])
        // The control is revealed by hovering, which VoiceOver has no way to do, and the pill
        // is one accessibility element so the button inside it is unreachable. Offered as
        // an action on the element instead — and only in the state where it is offered to a
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
    /// proposal — so the rect measured here is a function of the content alone and is
    /// *constant* with respect to `ShellSize`'s width. The dependency graph is therefore
    /// one-way:
    ///
    ///     capsuleWidth  ->  ShellSize.width  ->  the drawn box
    ///     capsuleWidth  <-  the content's ideal width   (never the drawn box)
    ///
    /// The gain around the cycle is zero, so it settles in exactly one extra layout pass and
    /// cannot oscillate: pass one lays the content out at its ideal and reports W, the write
    /// invalidates, pass two forces W and measures the same W again. Wire the probe to the
    /// *outer* box instead and the gain becomes one — see the note on that background for what
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
    /// frame of the extrusion — capsule, neck and lobe as one continuous contour. There is no
    /// field function to approximate and nothing that can drift, which is exactly what a stroke
    /// drawn over `GlassEffectContainer`'s blended body could not promise.
    ///
    /// It degrades without losing the extrusion, which is the other half of why it is a shape:
    ///
    ///   * **Reduce Transparency** — `ChromeGlass` fills the shape with `Surface.raised` and
    ///     strokes it with `Line.strong`. The opaque fill *is* the union, so the pill still grows
    ///     a bead and still has one outline. There is no glass and so no merge, and nothing here
    ///     ever depended on one.
    ///   * **Pre-macOS-26** — `.regularMaterial` in the same shape. No lensing, so no light bends
    ///     across the neck, but the neck is there and thins from 25.8pt to 1.9pt before it lets go.
    /// The one glass body, the one outline, and the shadow under both.
    ///
    /// Sized by the `GeometryReader` that calls it, so the glass, both strokes and the shadow are
    /// all drawn at exactly the size the shell currently is — the material fills its view's bounds,
    /// so bounds larger than the silhouette render as a visible slab behind it.
    private func shell(capsuleWidth: CGFloat, height: CGFloat) -> some View {
        let shape = PillShellShape(extrusion: extrusion, capsuleWidth: capsuleWidth)
        return Color.clear
            .frame(width: PillMetrics.shellWidthWithBead(capsuleWidth: capsuleWidth),
                   height: height)
            // The pill is the purest case for real Liquid Glass: a small floating control layer with
            // nothing but desktop behind it. State colour rides *on* the glass as a tint rather than
            // replacing it, so the material still refracts the wallpaper while reading as
            // recording/error/etc.
            .glassSurface(
                // Untinted glass at rest, tinted glass otherwise — asked of `stateGlassTint`, which
                // is the value passed as `tint:` on the next line. It used to ask a second table
                // (`stateTint == .clear`) that agreed only by coincidence.
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
                    // derives its body from the stored `capsuleWidth` rather than from the rect — so
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
            // Glass carries a content-aware shadow of its own — Apple: it "increases the opacity of
            // its shadow when it is over text" and lowers it over a light background. Adding a
            // second fixed shadow doubles it.
            //
            // Applied last, so it composites over the rendered union and follows the neck for free —
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
    /// no longer faded *in* — but the outgoing recording row still had SwiftUI's default `.opacity`,
    /// so it kept fading *out* on top of the card for the length of the transaction. That is the
    /// "ghosts from the pill" seen when the note pop-up opens: two states' glyphs drawn over each
    /// other, one of them dissolving. Applied here it covers insertion and removal of every branch,
    /// so no two states are ever on screen together.
    private var content: some View {
        stateContent.transition(.identity)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch model.state {
        case .preparing:
            BreathingDot(reduceMotion: motion.reduceMotion)
            Text("Getting ready").typo(.caption)

        case .idle:
            // Just the microphone. The hotkey name used to sit beside it in a
            // keycap chip, which is what forced the pill wide — and it was
            // telling the user something they only need once. The hint lives in
            // the menu-bar item, Settings, and onboarding; the resting pill's
            // whole job is to say "ready" and otherwise stay out of the way.
            Image(systemName: "mic")
                .font(.system(size: 13))
                .foregroundStyle(Ink.secondary)
        case .capturingNote:
            // The one state that is not a row of glyphs in a capsule. The shell above — glass,
            // border, frame — is the same view either way; only what sits inside is swapped.
            //
            // No `.transition` here. It carried `.identity` for exactly the right reason and it was
            // not enough: a transition on one branch says nothing about the branch being *removed*,
            // which kept its default `.opacity` and faded out over the top of this card. The
            // `.identity` now sits on the switch itself (see `content`), which covers both.
            NoteCaptureBox(model: model, liveTint: dotTint)

        case .recording, .handsFree:
            // Static dot: the meter beside it already says "live". A pulsing
            // ring plus animating bars is two things saying the same thing.
            Circle()
                .fill(dotTint)
                .frame(width: 8, height: 8)
            LevelMeter(signal: model.levels)
            if model.previewText.isEmpty {
                Text(model.elapsedText).typo(.timestamp)
            } else {
                // The live transcript replaces the timer rather than joining it.
                // Both are secondary to the level meter, and a pill carrying dot +
                // meter + timer + text + lock is a status bar, not a pill.
                //
                // Truncated from the *head*: the interesting end of a growing
                // transcript is the most recent words, so the tail must stay
                // visible as it grows.
                // Pre-trimmed, like the card's copy. This was handed the whole unbounded
                // `previewText` and left to `truncationMode(.head)`, so SwiftUI laid out an
                // ever-growing string just to find the cut, and the cut landed mid-word with no
                // ellipsis — where `LiveTranscript.tail` cuts on a word boundary and says it did.
                // 40 characters against the ~33 that fit at this width, so the truncator still has
                // something to trim.
                Text(LiveTranscript.tail(of: model.previewText, maxCharacters: 40))
                    .typo(.caption)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            if model.state == .handsFree {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Tint.handsFree)
            }

        case .processing:
            // Pen only, no phase name. `PillState`'s doc argues that naming the phase is "real
            // feedback" and it was briefly drawn on that basis — but it was asked for by a comment,
            // not by anyone using the app, and on screen it turned a small round pill into a wide
            // label three times per dictation. The phase still reaches VoiceOver, where a name is
            // the only thing available.
            WritingPen(reduceMotion: motion.reduceMotion)

        case .notice(let message):
            // 13pt regular, matching the error glyph below and the idle microphone. These two
            // siblings disagreed — 11pt semibold against 13pt regular — so the same row of the same
            // pill changed weight depending on whether the news was good.
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(Tint.accent)
            Text(message).typo(.caption, ink: Ink.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: PillMetrics.messageWidth, alignment: .leading)

        case .error(let reason):
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(Tint.danger)
            // Primary ink: an error the user has to act on should not be drawn in the same grey as a
            // footnote. And a width, because these messages come from arbitrary failures — without
            // one, a long reason drew the shell wider than the 320pt panel, which clipped its rounded
            // ends. `PillMetrics.shellWidth(for:measured:)` also caps it now; this is the half that
            // keeps the *text* readable rather than merely the shell intact.
            Text(reason).typo(.caption, ink: Ink.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: PillMetrics.messageWidth, alignment: .leading)
        }
    }

    /// Live-indicator dot colour. Note capture gets the accent rather than the
    /// hands-free hue, so the pill shows *where the text is going* — the one thing
    /// the recording itself cannot convey.
    private var dotTint: Color {
        switch model.state {
        case .capturingNote: return Tint.accent
        case .handsFree: return Tint.handsFree
        default: return Tint.recording
        }
    }

    // No countdown line. The pill used to draw an amber bar along its foot as the
    // hands-free silence timer drained, and along the note card's foot too. It was real
    // data — `AudioRecorder`'s VAD progress, never a timer pretending — but the user asked
    // for it gone twice, and a line that creeps across the pill every time you pause for
    // breath is more alarming than the auto-stop it was announcing. What is lost is stated
    // plainly rather than replaced by a different line: you can no longer *see* the
    // auto-stop coming, so a pause that ends the recording now ends it without warning.
    // Talking still cancels it, exactly as before.

    // MARK: Styling

    // No `stateTint`. It was a seven-case ramp of wash colours that nothing painted with any more —
    // `stateGlassTint` below replaced it when the pill became real glass — computed only so that
    // `shell` could ask `stateTint == .clear` to choose a role. `shell` now asks `stateGlassTint`,
    // which is the value it actually passes as `tint:`, so the question is answered by the table it
    // is about. Two tables answering the same question is one of them drifting later.

    /// The state colour as a *glass tint*.
    ///
    /// Stronger than `stateTint` on purpose: that value was designed as a flat
    /// wash painted over an opaque capsule, whereas a tint is mixed into a
    /// material that is already sampling the wallpaper. At wash opacities the
    /// colour disappears entirely. Idle stays untinted — plain glass is the
    /// resting state, and the HIG asks that colour be reserved for emphasis.
    private var stateGlassTint: Color? { Self.glassTint(for: colorState) }

    /// The state colour as a *glass tint*, for an explicitly named state.
    ///
    /// Takes the state rather than reading `model.state`, because the container hands down a value
    /// that *lags* inside an animated transaction — that lag is what lets the hue cross-fade while
    /// the shell's geometry changes instantly. See `PillContainerView.colorState`.
    static func glassTint(for state: PillState) -> Color? {
        switch state {
        case .idle: return nil
        case .preparing, .processing, .notice: return Tint.accent.opacity(0.45)
        case .recording: return Tint.recording.opacity(0.50)
        case .handsFree: return Tint.handsFree.opacity(0.52)
        case .capturingNote: return Tint.accent.opacity(0.52)
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
    /// `isDark ? .white.opacity(0.22) : .black.opacity(0.18)` — i.e. it chose its tone from the *app's*
    /// colour scheme. But the app's appearance and what is actually *behind* the pill are independent:
    /// the pill floats over the desktop, so a dark appearance can sit over a white window and a light
    /// appearance over a black one. In dark appearance both of the pill's strokes came out white (this
    /// ring at 0.22 and the inner highlight at 0.32), so over anything pale the pill had no dark edge
    /// anywhere and dissolved into it. Reported as: over a white background the pill goes white, and
    /// the same in reverse.
    ///
    /// The silhouette is now carried by a **two-tone edge** instead: this dark hairline on the outside
    /// and the light top-lit highlight just inside it. One of the two always registers, whatever is
    /// behind — which is how native controls survive being drawn over arbitrary content. Neither
    /// depends on the appearance, so neither can pick the one tone that vanishes.
    static func border(for state: PillState) -> Color {
        switch state {
        case .idle:
            // Dark, always. On a pale backdrop this is the edge; on a dark one it recedes and the
            // inner highlight takes over.
            return .black.opacity(0.30)
        case .preparing, .processing, .notice:
            return Tint.accent.opacity(0.65)
        case .recording:
            return Tint.recording.opacity(0.75)
        case .handsFree:
            return Tint.handsFree.opacity(0.75)
        case .capturingNote:
            return Tint.accent.opacity(0.75)
        case .error:
            return Tint.danger.opacity(0.75)
        }
    }

    // No `stateRim`. It was the hairline the pill's outline used before `borderColor` above replaced
    // it, and it outlived the modifier that read it: seven colours nothing asked for. Worse than
    // dead, because `PillState` is exhaustively switched here — adding a state would have made the
    // compiler demand a rim colour for an outline that no longer exists.

    // No `.animation(_:value:)` on the shell, and no `stateKey` to drive one.
    //
    // There used to be `.animation(morphAnimation, value: stateKey)` here, and it was the second
    // of two drivers for one silhouette. `PillWindow.apply(_:)` is the only production writer of
    // `state` and already wraps the mutation in `withAnimation`; `PillDemoView.advance` wraps its
    // own in `withAnimation(Motion.layout)`. Deleting it left one *transaction*.
    //
    // One transaction was necessary and not sufficient, and that is the whole of why this bug
    // survived four fixes. Both axes rode the same transaction afterwards and the morph still
    // read as a snap-then-grow, because they rode it by two different *mechanisms*: the height
    // was an animatable number in a `.frame(height:)`, and the width was a layout
    // recomputation from the content's ideal size, which no transaction can interpolate.
    // `ShellSize` is what made them one mechanism — one `AnimatablePair`, both axes read from
    // it — and that is now the only thing that sizes the shell, the clip, the glass, both
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
        case .processing(let phase): return "Utter, \(phase.rawValue.lowercased())"
        case .error: return "Utter, error"
        }
    }

    /// Elapsed seconds only — never the meter value. A 30 Hz numeric update
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
            // The chord is spelled rather than drawn — `KeyChord.symbols` is glyphs, and
            // VoiceOver reads those as nothing useful.
            let destination = NoteStore.shared
                .captureDestination(appendsToOpenNote: userData.captureAppendsToOpenNote)
            return "\(model.elapsed) seconds. \(destination.label). "
                + "Press \(KeyChord.noteCapture.spelled) to finish."
        case .processing:
            return "Please wait"
        case .error(let reason):
            return reason
        }
    }
}

// MARK: - The shell's size

/// The shell's size — **both axes, one value.**
///
/// A type rather than a bare `.frame(width:height:)`, and the reasoning is worth keeping even now
/// that the size change is instant, because it is what stops the next person reintroducing the
/// original defect:
///
///   * **One `AnimatablePair`, so the axes cannot desynchronise.** Not two animatable properties
///     sharing a transaction — one value, from which both axes are read.
///   * **Neither axis can go missing.** `.frame(width:height:)` takes `CGFloat?`, and `nil` is not
///     one end of an interpolation — it is a layout recomputation. That was the bug the pill was
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

/// Seven bars fed by a ring buffer of real levels, so the shape scrolls right-to-left like a
/// hardware meter. No `repeatForever`, no staggered delays.
///
/// **The history window was the defect, not the bar count.** Five bars shifted at the recorder's
/// 30Hz publish rate hold 5/30 s = 167ms of history, which is below the eye's integration time for a
/// scrolling display — so it read as five bars flickering rather than as a meter scrolling, which is
/// the opposite of what this comment used to claim. Seven bars shifted every *other* publish gives
/// 7/15 s = 467ms: a legible half-second of speech, for 11pt more width.
///
/// The newest bar is still fed at the full 30Hz, so the leading edge is exactly as responsive as it
/// was; only the *history* is sampled at a rate that can be seen. Every bar remains a real RMS
/// measurement — this decimates when the buffer shifts, it never invents a value.
struct LevelMeter: View {
    /// The level, observed directly rather than passed down as a `Float`.
    ///
    /// **This is what confines the 30 Hz redraw to the seven bars.** Taking a `Float` meant the
    /// level had to be *read* by whoever built the meter — `PillContent` and `NoteCaptureBox` —
    /// so both of them, and everything above them, were subscribers to a signal only this view
    /// draws. Observing it here makes this the only view a mic publish invalidates; see
    /// `PillLevelSignal` for the before/after counts.
    @ObservedObject var signal: PillLevelSignal

    /// How many publishes to collect before shifting the buffer. The recorder publishes at 30Hz, so
    /// 2 gives a 15Hz scroll.
    private static let publishesPerShift = 2
    static let barCount = 7

    @State private var history: [Float] = Array(repeating: 0, count: LevelMeter.barCount)
    @State private var publishes = 0

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(history.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Ink.secondary.opacity(0.55 + 0.45 * Double(history[index])))
                    .frame(width: 3, height: 3 + 17 * CGFloat(history[index]))
            }
        }
        .frame(height: 20)
        // Bar heights come straight from the already-smoothed signal; animating
        // again would double-filter and add lag.
        .animation(nil, value: signal.value)
        .onChange(of: signal.value) { newValue in
            publishes += 1
            if publishes % Self.publishesPerShift == 0 {
                history.removeFirst()
                history.append(newValue)
            } else if !history.isEmpty {
                // Between shifts the leading bar keeps tracking, so the meter's response to a
                // sudden sound is unchanged at 30Hz.
                history[history.count - 1] = newValue
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Breathing dot

/// A slow pulse for the preparing state. One element, one animation — enough to
/// say "working" without the busy-spinner look.
struct BreathingDot: View {
    let reduceMotion: Bool
    @State private var big = false

    var body: some View {
        Circle()
            .fill(Tint.accent)
            .frame(width: 8, height: 8)
            // 0.82, not 0.6. An 8pt dot scaling to 4.8pt while *also* dropping to 0.45 opacity is
            // two channels doing the same job, both of them deep — it read as a blink rather than a
            // breath. And 0.85s autoreversing is a 1.7s cycle: 35 a minute, which is panting.
            // 1.1s gives a 2.2s cycle, close to a resting breath, with the depth carried mostly by
            // opacity where it is least distracting on a 8pt dot.
            .scaleEffect(reduceMotion ? 1 : (big ? 1.0 : 0.82))
            .opacity(reduceMotion ? 0.8 : (big ? 1.0 : 0.60))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    big = true
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

    /// How far the wave has travelled, in whole wavelengths.
    ///
    /// **Periodic on purpose, and that is what removed the teleport.** This used to be a `progress`
    /// that a `repeatForever(autoreverses: false)` drove 0 -> 1 and then reset instantly, so once
    /// every 1.4 seconds the pen jumped 22pt to the left and the stroke it had drawn vanished — for
    /// however long transcription took, which is the longest the pill ever holds one state. Shifting
    /// a sine by exactly one wavelength gives a path identical to the one it started from, so the
    /// animation still restarts and there is simply nothing to see when it does.
    @State private var phase: CGFloat = 0

    // Every number here is checked against the frame, because the first version of this was not and
    // the pen went missing. `Image(systemName:)` reports a layout box of about its font size, but
    // `rotationEffect` is a *render* transform that does not change that box — so a 11pt glyph turned
    // 38 degrees actually paints across 11 * (cos38 + sin38) = 15.4pt. Parking it by offset alone put
    // 7.2pt of it outside a 28pt frame, hard against the capsule's bright rim, and what was left read
    // as no pen at all.
    //
    // So the pen gets an explicit box big enough for what it paints, and the layout is stated in
    // absolute terms from `.topLeading` rather than inferred from a `ZStack`'s centring.
    private let waveWidth: CGFloat = 18
    private let waveHeight: CGFloat = 10
    /// The rotated glyph's real extent, rounded up.
    private let penBox: CGFloat = 16
    private var frameWidth: CGFloat { waveWidth + penBox / 2 + 2 }   // 28
    private var frameHeight: CGFloat { penBox + 2 }                   // 18

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The line being written: a continuous wave that scrolls, rather than one drawn and
            // wiped. Fully stroked — there is no `trim` any more, because the reveal was what needed
            // a beginning and an end.
            WaveStroke(phase: reduceMotion ? 0 : phase)
                .stroke(Ink.secondary.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .frame(width: waveWidth, height: waveHeight)
                .offset(x: 0, y: (frameHeight - waveHeight) / 2)     // y 4..14 of 18

            // The pen sits at the wave's right end with its nib on the line, and stays there while
            // the paper moves under it. Its box is centred on x = waveWidth, so it spans
            // 10..26 of 28 horizontally and 1..17 of 18 vertically — inside on both axes, with a
            // point of margin, which is the property the previous version lacked.
            Image(systemName: "pencil")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Ink.primary)
                .rotationEffect(.degrees(38))
                .frame(width: penBox, height: penBox)
                .offset(x: waveWidth - penBox / 2, y: (frameHeight - penBox) / 2)
        }
        .frame(width: frameWidth, height: frameHeight)
        .onAppear {
            guard !reduceMotion else { return }
            // Linear, because a scroll is continuous. `easeInOut` on a `repeatForever` pulses at every
            // cycle boundary even when the geometry matches across it.
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// A gentle wave, the "handwriting" the pen leaves behind, scrolled by `phase`.
///
/// `animatableData` is what lets SwiftUI interpolate the scroll: without it the shape would be
/// rebuilt only when the state changed, and the phase would jump rather than travel.
private struct WaveStroke: Shape {
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        let amp = rect.height * 0.30
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            // `+ phase` shifts the whole wave by whole wavelengths, so phase 1 draws phase 0.
            let point = CGPoint(x: t * rect.width,
                                y: mid + sin((t + phase) * .pi * 2) * amp)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
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
