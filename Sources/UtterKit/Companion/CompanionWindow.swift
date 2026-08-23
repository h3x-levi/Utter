import SwiftUI
import Cocoa
import Combine
import ApplicationServices
import os

/// The desktop companion's window.
///
/// A sibling of `PillWindow`, and deliberately the same species of panel:
/// non-activating, borderless, `.statusBar` level, joins all Spaces. A companion
/// that stole focus or vanished when you switched Spaces would be worse than no
/// companion.
///
/// It is a *separate* panel rather than extra content inside the pill for one
/// concrete reason: the pill sizes itself to its state (56pt at rest, wider with a
/// level meter and a live transcript), and anything sharing that window would be
/// shoved sideways every time the user spoke. The one exception is the note card,
/// which is a fixed 292x124pt box and has room to hold the character itself — so
/// while the card is open this panel steps aside and the card draws it. See
/// `applyCardHandover`.
///
/// It used to be welded to the pill: a *child* window that re-derived its own origin
/// from the pill's frame on every move, every resize and every change of capsule
/// width, flipped sides when the chosen one ran out of room, and dragged the pill
/// when you dragged the character. It is now an ordinary independent window with a
/// position of its own — the pill is consulted only for the *first* placement and for
/// which way the character turns when it glances at it. Everything that existed to
/// serve following (the frame observers, the settling flag, the persisted side) went
/// with it.
final class CompanionWindow: NSPanel {
    let behaviour = CompanionBehaviour()

    /// The one diagnostic channel for the companion.
    ///
    /// `os.Logger` rather than the `print` the rest of the app uses, and deliberately: a
    /// bundled GUI app's stdout is not captured anywhere the user can reach, so a `print`
    /// meant to be *checked* would vanish. This is viewable at any time, however the app was
    /// launched, with:
    ///   log stream --predicate 'subsystem == "utter.dictation.app"'
    private static let log = Logger(subsystem: "utter.dictation.app", category: "Companion")

    /// The keystroke count at the last diagnostic beat, so the log reports a per-second
    /// delta rather than an ever-growing total. Never the keys themselves — `KeystrokeTicker`
    /// has nowhere to put a key code, and this reads only its count.
    private var diagStrokes: UInt64 = 0
    /// Seconds the diagnostic has gone without seeing a keystroke, so the "Accessibility is
    /// off" explanation repeats at a low rate instead of every second.
    private var diagSilentSeconds = 0

    /// The geometry the panel is currently built for.
    ///
    /// Everything positional asks this rather than a constant, because the character's
    /// size is a user preference: the panel, the roam range, the hop and both screen
    /// clamps all move with it. `applyPreferredSize` is the only thing that assigns it.
    private var geometry: CompanionGeometry

    /// The pill, for the three moments the companion still cares about it: the first
    /// placement (`placeBesidePill`), the direction of a glance, and whether the note card
    /// currently has the character (`applyCardHandover`). All three *sample* it; none
    /// follows it.
    private weak var pill: PillWindow?
    private var onOpenSettings: (() -> Void)?

    /// Where the user dragged it, as a fraction of the visible frame.
    ///
    /// The same scheme and the same key shape as `PillWindow`'s, because it is the same
    /// problem: a stored absolute origin saved on a large display is off screen on a
    /// small one, so a display change would strand the companion somewhere unreachable.
    /// See `CompanionGeometry.fraction(ofOrigin:in:)`.
    private let positionKey = "companionWindowPosition"

    /// The two things the window still has to react to, and neither is the pill.
    private var sizeObserver: AnyCancellable?
    private var screenObserver: NSObjectProtocol?

    init(pill: PillWindow, onOpenSettings: @escaping () -> Void) {
        self.pill = pill
        self.onOpenSettings = onOpenSettings
        // A local, because `super.init` has to run before `self` can be read.
        let geometry = CompanionGeometry(UserData.shared.companionSize)
        self.geometry = geometry

        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: geometry.panelSide, height: geometry.panelSide),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // One level above the pill, which sits at `.statusBar`.
        //
        // The child-window relationship used to guarantee this — `addChildWindow(_:
        // ordered: .above)`, because the character overlaps the capsule's edge when it
        // leans and should lean *in front of* the pill rather than behind it. Two
        // independent windows at the same level are ordered by whichever was ordered
        // front last, and the pill is ordered front from `applyPillVisibility` at the
        // start of a dictation turn — so the character would have been painted over by
        // the pill, and it can now be parked deliberately close to it. Still below
        // `.popUpMenu`, so the companion's own context menu draws above it.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        // The companion is dragged by grabbing the character itself, not the whole
        // window: the panel is mostly empty space the character roams through, and
        // `isMovableByWindowBackground` would let a click on that emptiness drag
        // it. See `CompanionContainerView`'s drag gesture.
        isMovableByWindowBackground = false
        // Clicks land on the character only. Without this the invisible panel — 2.1x the
        // character's size — would swallow clicks meant for whatever is behind it, the
        // single most annoying thing a desktop pet can do.
        ignoresMouseEvents = false

        // The window owns the geometry, so it tells the behaviour engine how far it
        // may travel rather than the two keeping separate numbers in step.
        behaviour.roamRange = geometry.roamRange
        behaviour.hopHeight = geometry.hopHeight
        // Answered live rather than stored: both windows move independently now, so the
        // only correct answer is the one at the moment of asking.
        behaviour.pillIsToTheRight = { [weak self, weak pill] in
            guard let self, let pill else { return true }
            return pill.frame.midX >= self.frame.midX
        }

        // The pet signals, injected the same way and for the same reason: the engine pulls
        // once per tick rather than subscribing to something that changes continuously.
        //
        // `NSEvent.mouseLocation` is a plain read of the global cursor — no event monitor,
        // no tap, and so no permission prompt of any kind. Eye-follow, hunting and petting
        // are all derived from this one call.
        behaviour.cursorSource = { NSEvent.mouseLocation }
        behaviour.characterRectSource = { [weak self] in
            self?.characterScreenRect ?? .zero
        }
        // The ambient walk moves the whole window across the desktop, which only the window
        // can do (the engine owns no frame). The engine asks; this clamps to the screen and
        // reports back how far it actually went, so the engine can turn at an edge.
        behaviour.walkStep = { [weak self] dx in self?.applyWalkStep(dx) ?? 0 }

        let hosting = ShapedHostingView(rootView: CompanionContainerView(
            behaviour: behaviour,
            onPoke: { [weak self] in self?.behaviour.poke() },
            onDragTo: { [weak self] cursor in self?.drag(to: cursor) },
            onDragEnded: { [weak self] in
                self?.dragGrabOffset = nil
                self?.behaviour.isBeingDragged = false
                self?.savePosition()
            }
        ))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        // **This line stops a hard crash, and it was the only hosting view in the app missing it.**
        //
        // Symptom: `SIGTRAP`, an `NSException` from
        // `-[NSWindow _postWindowNeedsUpdateConstraints]`, thrown *inside* the window's own
        // constraint pass. Read the reported stack from the bottom up and it is a re-entrancy
        // loop, not a layout mistake:
        //
        //   NSWindow.updateConstraintsIfNeeded          ← the display cycle's constraint pass
        //     → NSHostingView.updateConstraints
        //       → updateWindowContentSizeExtremaIfNecessary   ← runs ONLY when sizingOptions
        //         → minSize → _sizeThatFits                     asks for min/max propagation
        //           → ViewGraph.invalidateTransform → graphDidChange
        //             → NSHostingView.setNeedsUpdate
        //               → NSView.setNeedsUpdateConstraints  ← invalidating mid-pass → throw
        //
        // `sizingOptions` defaults to `.standardBounds`, so the hosting view volunteers to
        // publish its SwiftUI content's min and max size to the window. Satisfying that means
        // *evaluating the view graph* during the constraint pass — and this particular graph is
        // a `TimelineView` driving a live character at 30 Hz, so an evaluation almost always
        // dirties it. Dirtying it calls `setNeedsUpdateConstraints` while AppKit is walking the
        // constraint tree, which AppKit refuses. The animation is what makes the companion the
        // one window that trips it; every other window's content is static between events.
        //
        // `[]` publishes nothing, so `updateWindowContentSizeExtremaIfNecessary` never runs and
        // the graph is never evaluated from inside the pass. It is also correct on its own
        // terms — this panel's size comes from `CompanionSize`, never from its content, exactly
        // as `PillWindow` and `MeetingOfferPanel` document at their matching lines.
        if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
        // Only the character takes the mouse. The panel is 2.1x its size so a hop or a
        // stroll is not clipped, and all of that margin used to swallow clicks meant for
        // whatever is behind it.
        hosting.interactiveRect = { [weak self] in self?.drawnCharacterRect ?? .zero }
        contentView = hosting

        observeSizePreference()
        observeScreenChanges()
        restorePosition()
    }

    deinit {
        // A block observer is retained by the notification centre until it is removed,
        // so it would go on firing after the window is gone. `deinit` is reachable:
        // `applyCompanionVisibility` releases the window when the companion is switched
        // off.
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    /// Where the character is actually drawn inside its panel, in content-view coordinates.
    ///
    /// Centred, plus the live stroll offsets — so poking and dragging follow the character
    /// rather than a fixed square it has wandered out of. `maxPoseScale` covers a stretch at
    /// the peak of a hop; without it the top of a jumping character would stop being
    /// clickable at exactly the moment it is most inviting to click.
    /// The character's rect in *screen* coordinates, for hit-testing the global cursor.
    ///
    /// `drawnCharacterRect` cannot be reused directly: it is in the hosting view's flipped,
    /// y-down space (see its own note), while `NSEvent.mouseLocation` is y-up screen space.
    /// Mixing the two makes petting work only on the character's mirror image — the pointer
    /// has to be below it to register. So this is computed in screen space from scratch
    /// rather than converted.
    ///
    /// Inset to the drawn body rather than the full pose envelope: `maxPoseScale` exists so
    /// a hop stays clickable, but for petting it would mean stroking the empty air above the
    /// cat counts as stroking the cat.
    var characterScreenRect: NSRect {
        let side = geometry.characterSize
        return NSRect(x: frame.midX - side / 2 + behaviour.offsetX,
                      y: frame.midY - side / 2 - behaviour.offsetY,
                      width: side,
                      height: side)
    }

    private var drawnCharacterRect: NSRect {
        guard let content = contentView else { return .zero }
        let side = geometry.characterSize * CompanionGeometry.maxPoseScale
        // `+ offsetY`, not `-`. `ShapedHostingView.hitTest` works in the hosting view's
        // flipped (top-left, y-down) space — measured: `NSHostingView.isFlipped` is true.
        // SwiftUI draws the character with `.offset(y: offsetY)`, whose y-down matches that
        // space, so the drawn character sits at `centre + offsetY` and the hit rect must
        // use the same sign to track a hop. (A review once "corrected" this to `-`, reading
        // the space as y-up; it is not.)
        return NSRect(x: (content.bounds.width - side) / 2 + behaviour.offsetX,
                      y: (content.bounds.height - side) / 2 + behaviour.offsetY,
                      width: side,
                      height: side)
    }

    // MARK: Visibility

    /// Whether the "no pack installed" line has already been printed.
    ///
    /// `show()` runs from the debounced preference observer, and preferences change
    /// several times during an ordinary dictation turn (`lastTranscription` alone does),
    /// so an unguarded line would repeat for as long as the condition lasts. It is a
    /// state, not an event — printing it once per transition is what makes it readable.
    private var reportedMissingPack = false

    /// Show the companion.
    ///
    /// There is nothing to keep in step with the pill any more: the companion is on
    /// screen whenever it is switched on. That is a real behaviour change — as a child
    /// window it was ordered in and out with the pill by AppKit, so with "always show
    /// the pill" off the character came and went for the duration of each dictation
    /// turn. A window with its own position and its own toggle should follow that
    /// toggle, not the pill's.
    func show() {
        // The note card has the character while it is open, and this runs from the
        // debounced preference observer — which fires several times during an ordinary
        // dictation turn, `lastTranscription` alone being enough. Without this the panel
        // would order itself back in mid-capture and there would be two characters on
        // screen, which is the collision this whole design exists to make impossible.
        guard !cardHasTheCharacter else { return }

        // Nothing to draw, no companion. Showing the panel anyway would leave a large
        // invisible click target on the desktop and a toggle that looks broken. Declining is
        // the honest behaviour; the Companion settings pane says why in words (see
        // `CompanionSettingsContent`), which is the only place the user can act on it.
        let selection = UserData.shared.companionCharacter
        guard SpritePackStore.shared.pack(matching: selection) != nil
        else {
            if !reportedMissingPack {
                reportedMissingPack = true
                print("⚠️ Companion is on but no character pack is installed — not showing it")
            }
            // Not just `return`: a pack deleted while the companion was on screen has
            // to take the panel with it rather than leave an empty one behind.
            hide()
            return
        }
        reportedMissingPack = false

        orderFront(nil)
        behaviour.start()
        startPetMonitors()
    }

    /// Take the companion off screen *and* stop it thinking — the companion being switched
    /// off, or its pack having disappeared.
    ///
    /// Not the same thing as the note-card handover, which orders the panel out and leaves
    /// the ticker running because something else is drawing from it. Here nothing is: a
    /// companion nobody can see must not keep waking the CPU 30 times a second.
    func hide() {
        orderOut(nil)
        behaviour.stop()
        stopPetMonitors()
    }

    // MARK: Pet monitors
    //
    // Two things the engine cannot get by pulling, both owned here so they live and die
    // with the panel rather than with the app.

    /// Global scroll observer, for the paper-unroll reaction.
    private var scrollMonitor: Any?

    /// Low-rate watcher that notices the user coming back while the character sleeps.
    private var wakeWatcher: Timer?

    /// Keystroke count at the last wake check, so returning activity is a change, not a level.
    private var wakeWatchStrokes: UInt64 = 0
    private var wakeWatchCursor: CGPoint = .zero

    private func startPetMonitors() {
        if scrollMonitor == nil {
            // Observe-only, so nothing is swallowed and normal scrolling is untouched — the
            // handler reads a delta and returns. This is the one pet signal that genuinely
            // cannot be polled: a flick arrives as a burst whose *total* is the signal, so
            // sampling at 30 Hz would catch whichever fraction landed on the tick boundary.
            //
            // Like the keyboard monitors this is inert until Accessibility is granted, which
            // the app already requests, polls and surfaces. Inert means the paper simply
            // never unrolls — no error, no prompt of our own.
            scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                // `scrollingDeltaY` rather than `deltaY`: the former is in the same units for
                // a trackpad and a wheel, where `deltaY` reports wheel *lines* and would make
                // a mouse unroll the paper about ten times faster than a trackpad.
                self?.behaviour.recordScroll(delta: event.scrollingDeltaY)
            }
        }

        if wakeWatcher == nil {
            // 1 Hz, and only meaningful while asleep. The engine's own 30 Hz ticker STOPS
            // when the character falls asleep — that is what makes sleeping free — so at
            // that moment nothing is polling the cursor or the keystroke count and the pet
            // signals go blind. Without this the cat would sleep until the next dictation
            // turn even as you typed straight past it.
            //
            // A second of latency on waking is invisible: the character has to play a
            // waking animation anyway.
            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.petHeartbeat()
            }
            RunLoop.main.add(timer, forMode: .common)
            wakeWatcher = timer
            reminders.begin(at: Date())
        }
    }

    /// The reminder clocks. Wall-clock, and driven from the 1 Hz timer above rather than
    /// from the 30 Hz tick, because the tick stops when the character sleeps and every
    /// reminder here is for a user who has gone quiet. See `ReminderScheduler`.
    private var reminders = ReminderScheduler()

    /// Once a second: notice the user coming back, and deliver anything that has come due.
    private func petHeartbeat() {
        checkForReturningUser()
        updatePeek()

        let data = UserData.shared
        // Read the preferences every beat rather than observing them. Once a second is
        // cheap, and it means a changed interval takes effect immediately without a
        // subscription that has to be torn down with the window.
        behaviour.petBehavioursEnabled = data.companionPetBehaviours
        behaviour.pinnedMessage = data.companionPinnedMessage
        logTypingDiagnostic(petEnabled: data.companionPetBehaviours)
        // Minutes to seconds, and 0 means off.
        reminders.stretchEvery = data.companionStretchMinutes > 0
            ? TimeInterval(data.companionStretchMinutes) * 60 : nil
        reminders.waterEvery = data.companionWaterMinutes > 0
            ? TimeInterval(data.companionWaterMinutes) * 60 : nil
        reminders.pomodoroFocus = data.companionPomodoroFocusMinutes > 0
            ? TimeInterval(data.companionPomodoroFocusMinutes) * 60 : nil
        reminders.pomodoroBreak = data.companionPomodoroBreakMinutes > 0
            ? TimeInterval(data.companionPomodoroBreakMinutes) * 60 : nil

        guard data.companionPetBehaviours else {
            behaviour.setPomodoroCountdown(nil)
            return
        }
        let now = Date()
        behaviour.setPomodoroCountdown(reminders.pomodoroRemaining(at: now))
        if let due = reminders.due(at: now) {
            behaviour.announce(due, name: data.companionUserName)
        }
    }

    private func stopPetMonitors() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        wakeWatcher?.invalidate()
        wakeWatcher = nil
    }

    // MARK: Peek mode
    //
    // While something is filling the screen — a video, a presentation, a game — the
    // character gets out of the way: it parks against the nearest screen edge and stops
    // reacting to the pointer, so it is present without being in front of what you are
    // watching. It comes back to where it was afterwards.

    /// Where the character was before it went to peek, so it can be put back exactly.
    private var positionBeforePeek: NSPoint?

    /// Whether a full-screen window is currently in front.
    ///
    /// Measured from window *geometry*, not from a list of video apps: an app allowlist
    /// cannot know about the next video site, and a browser tab playing a film and one
    /// showing a spreadsheet are the same app. Geometry is the actual signal — something
    /// covering the whole screen is something you are looking at.
    ///
    /// `CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` returns window *bounds*
    /// without any permission. Screen Recording is only needed for window titles and
    /// images, neither of which this reads — which is the whole reason the detection is
    /// done this way rather than by sampling the screen.
    /// **Runs off the main thread.** The window list is the expensive part and it does not belong
    /// on the run loop: measured on an M4 with 38 on-screen windows, one call is **2.30ms**, most of
    /// it the `as? [[String: Any]]` bridge that copies a dictionary of every window's attributes.
    /// At the 1 Hz heartbeat that is a dropped frame every second, which is visible precisely when
    /// the pill is mid-morph beside it.
    ///
    /// `nonisolated static` because it reads no instance state — the screen's frame and this
    /// process's pid are passed in, so nothing here needs the window. `CGWindowListCopyWindowInfo`
    /// is itself thread-safe; only the decision it feeds (`applyPeek`) touches AppKit.
    nonisolated static func fullScreenWindowIsFrontmost(screenFrame: CGRect,
                                                        ourPID: pid_t) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        let screenArea = screenFrame.width * screenFrame.height
        guard screenArea > 0 else { return false }

        for window in windows {
            // Only real application windows at the normal level. A full-screen video puts
            // its window at level 0; menu bars, docks and our own panels sit above it, and
            // counting those would make the character think every screen was full.
            guard let level = window[kCGWindowLayer as String] as? Int, level == 0 else { continue }
            if let pid = window[kCGWindowOwnerPID as String] as? Int32, pid == ourPID { continue }
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"]
            else { continue }

            // 92% of the screen's area. Not 100%: a full-screen video on macOS leaves the
            // window a pixel or two shy in places, and a maximised-but-not-full-screen
            // window is around 85% once the menu bar and Dock are excluded — so the gap
            // between the two is wide enough to sit in.
            if (width * height) / screenArea >= 0.92 { return true }
        }
        return false
    }

    /// Whether a peek check's window-list query is in flight, so the 1 Hz heartbeat cannot stack
    /// them. The answer is a state machine with hysteresis (`positionBeforePeek`); two queries
    /// landing out of order could park the character and then immediately un-park it.
    private var isCheckingPeek = false

    /// Ask whether something full-screen is in front, off the main thread, then act on it.
    private func updatePeek() {
        // Switching pet behaviours off used to strand a peeking character two thirds off-screen: the
        // guard returned before `applyPeek` could ever restore `positionBeforePeek`, so it stayed at
        // the edge until the app was relaunched. Bringing it home on the way out costs one line and
        // also covers the setting being flipped between the query and its result.
        guard UserData.shared.companionPetBehaviours else {
            applyPeek(false)
            return
        }
        guard !isCheckingPeek else { return }
        guard let screen = self.screen ?? NSScreen.main else { return }
        isCheckingPeek = true
        let screenFrame = screen.frame
        let ourPID = ProcessInfo.processInfo.processIdentifier
        Task.detached(priority: .utility) { [weak self] in
            let peeking = Self.fullScreenWindowIsFrontmost(screenFrame: screenFrame,
                                                           ourPID: ourPID)
            // Unwrapped before the hop: referencing the captured `weak var` inside the nested
            // concurrently-executing closure is an error in the Swift 6 language mode.
            guard let self else { return }
            await MainActor.run {
                self.isCheckingPeek = false
                self.applyPeek(peeking)
            }
        }
    }

    /// Move to the nearest screen edge, or come back. **Main thread**: this moves a window.
    private func applyPeek(_ shouldPeek: Bool) {
        if shouldPeek, positionBeforePeek == nil {
            guard let screen = self.screen ?? NSScreen.main else { return }
            positionBeforePeek = frame.origin
            // Whichever side it is already closer to, so it takes the shortest trip and
            // stays on the half of the screen the user last put it on.
            let visible = screen.visibleFrame
            let toLeft = frame.midX - visible.minX
            let toRight = visible.maxX - frame.midX
            // Two thirds off-screen: enough of the character showing to be found and
            // stroked, little enough to stop being a distraction.
            let hidden = geometry.panelSide * 0.66
            let x = toLeft <= toRight ? visible.minX - hidden : visible.maxX - geometry.panelSide + hidden
            setFrameOrigin(clamped(origin: NSPoint(x: x, y: frame.origin.y)))
            behaviour.isPeeking = true
        } else if !shouldPeek, let restore = positionBeforePeek {
            positionBeforePeek = nil
            behaviour.isPeeking = false
            setFrameOrigin(clamped(origin: restore))
        }
    }

    /// Wake a sleeping character if the user has typed or moved the pointer.
    ///
    /// Compares against the previous sample rather than testing an absolute, because both
    /// signals are levels: a stationary cursor and a keyboard nobody is touching both look
    /// identical every second forever, and only the *change* means someone came back.
    private func checkForReturningUser() {
        let strokes = KeystrokeTicker.snapshot.count
        let cursor = NSEvent.mouseLocation
        defer {
            wakeWatchStrokes = strokes
            wakeWatchCursor = cursor
        }

        // 12pt of travel, so a desk bump or a trackpad reading its own noise does not count
        // as the user returning.
        let moved = hypot(cursor.x - wakeWatchCursor.x, cursor.y - wakeWatchCursor.y) > 12
        guard strokes != wakeWatchStrokes || moved else { return }
        behaviour.wakeIfSleeping()
    }

    /// Once a second, report what the companion's typing signal actually sees.
    ///
    /// This is the answer to "the cat won't do the typing animation": the engine turning
    /// keystrokes into kneading is proven correct by tests, so the failure is upstream — the
    /// global key monitor is completely inert without Accessibility (macOS hands back a valid
    /// monitor and then never calls it), and there is nothing on screen that separates "the
    /// signal never arrived" from "the animation looks wrong". This log makes the wiring
    /// checkable without watching the animation:
    ///
    ///   * `N keystroke(s)/s` climbing while you type in another app  → the signal is alive,
    ///     any remaining problem is the art.
    ///   * stuck at 0 while you type, with "Accessibility not granted" → grant Accessibility.
    ///
    /// It records only *how many* keys, never which — `KeystrokeTicker` cannot hold a key
    /// code, and this reads only its count.
    private func logTypingDiagnostic(petEnabled: Bool) {
        let strokes = KeystrokeTicker.snapshot.count
        let delta = strokes &- diagStrokes
        diagStrokes = strokes

        if delta > 0 {
            diagSilentSeconds = 0
            // `.notice`, so a plain `log stream --predicate 'subsystem == "utter.dictation.app"'`
            // shows it with no extra flags — the point is that it can be checked easily.
            Self.log.notice(
                """
                typing signal alive: \(delta, privacy: .public) keystroke(s)/s · \
                mood \(String(describing: self.behaviour.mood), privacy: .public) · \
                reactions \(petEnabled ? "on" : "off", privacy: .public)
                """
            )
        } else if petEnabled && !AXIsProcessTrusted() {
            // The dead-feature case, explained at a low rate so it does not spam a log the
            // user is streaming while they try to reproduce the bug.
            diagSilentSeconds += 1
            if diagSilentSeconds % 5 == 1 {
                Self.log.notice(
                    "typing reactions inactive: Accessibility not granted, so keystrokes in other apps are invisible to the companion — grant Utter in Privacy & Security \u{203A} Accessibility"
                )
            }
        }
    }

    /// Move the companion horizontally by `dx` points (screen space, + is right), clamped to
    /// the screen, and report how far it actually went so the walk can turn at an edge.
    ///
    /// The ambient walk translates the *window*, unlike the stroll which only shifts the
    /// character inside its panel — so the character genuinely crosses the desktop. It does
    /// not save the new position: walking is wandering, and "home" stays wherever the user
    /// last dragged it, so a relaunch or a display change returns it there rather than to
    /// wherever it happened to have ambled. Refuses to move while the note card is drawing the
    /// character (the panel is ordered out), so it cannot wander off unseen.
    ///
    /// **This is the one thing the companion does that moves a window per tick, and it is
    /// measured.** `walkSpeed` (42 pt/s) over a 1/30 s tick is 1.4 pt — on a 2x display 2.8
    /// device pixels, so it is *not* a sub-pixel move and a "only move when it changes by
    /// ≥1 pt" guard would never once fire. The move cannot be replaced by interpolating inside
    /// SwiftUI either: the panel is only 2.1x the character, so a walk that stayed inside it
    /// would be clipped after ~18 pt — and the window origin is the character's real position,
    /// which is what the pet signals hit-test and what the pill's side is computed against.
    /// Faking it with an animation would make all three lie.
    ///
    /// The measured share is real, though: over 24 000 release-build engine ticks of ordinary
    /// awake-and-resting behaviour, `walkStep` was called on 4 913 of them — **20% of idle
    /// ticks move the window.** The avoidable part is the clamp's screen query, not the move:
    /// `NSScreen.visibleFrame` measured **16 444 ns** per call against 119 ns for
    /// `NSScreen.screens` and 3 ns for a held screen's `.frame`, because it re-derives the
    /// dock and menu-bar insets from the window server every time. That is ~6x the entire
    /// 2.7 us behaviour tick, on a fifth of all ticks. It is left uncached deliberately: at
    /// 20% duty it is 98 us/s, or 0.01% of one core, which does not pay for a cache with a
    /// staleness window (the dock can auto-hide mid-walk). Recorded so the next person to
    /// profile this does not have to re-measure it — and so nobody adds a *second* per-tick
    /// `visibleFrame` caller thinking it is free.
    private func applyWalkStep(_ dx: CGFloat) -> CGFloat {
        // Refuse to move while parked out of the way of something full-screen, or while the
        // note card is drawing the character (the panel is ordered out). Returning 0 both
        // keeps it put and ends any walk already in flight, via the engine's stuck-at-edge
        // logic — a new one cannot start, since `chooseAct` drops `.walk` while peeking.
        guard !behaviour.isPeeking, !cardHasTheCharacter else { return 0 }
        let origin = frame.origin
        guard let visible = visibleFrame(forPanelOrigin: origin) else { return 0 }
        let targetX = geometry.clampedX(desired: origin.x + dx, visible: visible)
        let actual = targetX - origin.x
        if actual != 0 { setFrameOrigin(NSPoint(x: targetX, y: origin.y)) }
        return actual
    }

    // MARK: The note card

    /// Whether the note card is drawing the character, in which case this panel does not.
    ///
    /// **One character at a time, and the card wins while it is up.** This replaces a whole
    /// displacement mechanism — measure the card, compute the smallest escape that clears
    /// it, animate the window there, remember the position, hand it back on collapse, and
    /// reconcile all of it from five different triggers because any one of them could put
    /// the character back. The card growing over the companion is now impossible by
    /// construction rather than corrected by arithmetic.
    ///
    /// Pure and static so the decision is testable without a screen, a pack or a window.
    /// The two facts it needs are what the pill is drawing and whether there is a character
    /// to draw at all.
    static func noteCardDrawsCharacter(pillState: PillState, hasCharacter: Bool) -> Bool {
        hasCharacter && PillMetrics.isExpanded(pillState)
    }

    /// The same question, answered from the live pill.
    ///
    /// Derived on every read rather than cached in a flag: `show()` consults it too, and
    /// that runs from the debounced preference observer at moments this class does not
    /// choose. A cached copy is one more thing that can be stale exactly when it is asked.
    private var cardHasTheCharacter: Bool {
        guard let pill, pill.isVisible else { return false }
        let pack = SpritePackStore.shared.pack(matching: UserData.shared.companionCharacter)
        return Self.noteCardDrawsCharacter(pillState: pill.currentState,
                                           hasCharacter: pack != nil)
    }

    /// Hand the character to the note card, or take it back.
    ///
    /// Driven from the pill's published state (`AppDelegate.wireCompanionSignals`) rather
    /// than from the twenty-odd `setState` call sites, for the reason that observation
    /// already exists: a turn ends by succeeding, by being cancelled and by failing, and a
    /// character left invisible because one exit path forgot to restore it is the failure
    /// this shape rules out. Quitting needs nothing — the panel dies with the process.
    ///
    /// `orderOut` rather than `hide()`, and that is the trap in this change: `hide()` stops
    /// the 30 Hz ticker, and the card renders from that same engine, so a stopped ticker
    /// would freeze the character mid-pose inside the card. The panel goes; the engine
    /// keeps running, which is also what makes this a handover rather than a teleport.
    ///
    /// Nothing here touches the frame, so the character reappears on precisely the point it
    /// left. The saved position is untouched too: `savePosition` is reached only from the
    /// end of a drag, so a handover cannot rewrite a preference the user set.
    func applyCardHandover() {
        if cardHasTheCharacter {
            orderOut(nil)
        } else {
            show()
        }
    }

    // MARK: Size

    /// Re-read the character size when the preference changes.
    ///
    /// A subscription of its own rather than a ride on the app's debounced
    /// `objectWillChange` observer (which also calls `show()`): that one waits 250 ms
    /// for the preferences to go quiet, and a size control the user is clicking should
    /// resize the thing it describes now, not a beat later. `removeDuplicates` because
    /// every other preference publishes through the same object.
    private func observeSizePreference() {
        sizeObserver = UserData.shared.$companionSize
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] size in self?.applyPreferredSize(size) }
    }

    /// Resize the panel, keeping the character where it stands.
    ///
    /// The character is centred in the panel and the panel is square, so growing it has
    /// to move the origin by half the growth on both axes — resizing about the origin
    /// would slide the character up and to the right as it grew.
    private func applyPreferredSize(_ size: CompanionSize) {
        let next = CompanionGeometry(size)
        guard next != geometry else { return }
        geometry = next
        behaviour.roamRange = next.roamRange
        behaviour.hopHeight = next.hopHeight

        let centre = CGPoint(x: frame.midX, y: frame.midY)
        setFrame(
            NSRect(x: centre.x - next.panelSide / 2, y: centre.y - next.panelSide / 2,
                   width: next.panelSide, height: next.panelSide),
            display: true
        )
        // A bigger character reaches further, so a position that was legal at the old
        // size can put the new one over the menu bar.
        setFrameOrigin(clamped(origin: frame.origin))
    }

    // MARK: Position

    /// Keep the character on screen when the displays change.
    ///
    /// The one thing a free-floating window has to react to that a pill-following one
    /// did not: unplug the display it was parked on, or change resolution, and its
    /// absolute frame is somewhere else entirely — off screen, or over a menu bar that
    /// is now lower down. Re-running the restore maps the *saved fraction* onto the new
    /// visible frame, so the companion lands in the same relative spot rather than
    /// wherever the old points happen to point now, and the user's stored position is
    /// left untouched for when the display comes back.
    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.restorePosition() }
    }

    /// Put the companion where the user left it, or beside the pill if it has never
    /// been moved.
    private func restorePosition() {
        guard let saved = UserDefaults.standard.dictionary(forKey: positionKey),
              let fx = saved["fx"] as? CGFloat, let fy = saved["fy"] as? CGFloat
        else {
            placeBesidePill()
            return
        }
        // Restore onto the display the position was saved against.
        //
        // A fraction of a visible frame cannot name a display, and the two ends of the
        // round-trip resolved it differently: `savePosition` measured against the screen the
        // panel was actually on, `restorePosition` always applied the result to
        // `NSScreen.main` — the one holding the key window. So dropping the companion on a
        // secondary display and relaunching put it at the same *fraction* of the primary one
        // instead, and `observeScreenChanges` re-ran this on every
        // `didChangeScreenParametersNotification` (display sleep/wake, a resolution change,
        // even resizing the Dock), so it jumped back mid-session too.
        let savedDisplay = saved["display"] as? UInt32
        let screen = NSScreen.screens.first { $0.displayID == savedDisplay } ?? NSScreen.main
        guard let screen else {
            placeBesidePill()
            return
        }
        let origin = geometry.origin(forCentreFraction: CGPoint(x: fx, y: fy),
                                     in: screen.visibleFrame)
        setFrameOrigin(clamped(origin: NSPoint(x: origin.x, y: origin.y)))
    }

    private func savePosition() {
        // The display under the character's middle, resolved the same way `clamped(origin:)`
        // does — `NSWindow.screen` names the display holding the largest part of the panel,
        // which on a panel straddling two is not necessarily the one the user dropped it on.
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centre) })
            ?? self.screen ?? NSScreen.main else { return }
        let fraction = CompanionGeometry.fraction(ofCentre: centre, in: screen.visibleFrame)
        var stored: [String: Any] = ["fx": fraction.x, "fy": fraction.y]
        // Recorded so `restorePosition` can put it back on this display rather than on
        // whichever one happens to hold the key window at launch.
        if let id = screen.displayID { stored["display"] = id }
        UserDefaults.standard.set(stored, forKey: positionKey)
    }

    /// The companion's *first* position: beside the pill, on its eye line — where it
    /// used to live permanently. After this the user owns it; "Reset Position" comes
    /// back here.
    ///
    /// Two corrections the window frames alone would get wrong, both because each panel
    /// is larger than the art inside it:
    ///
    ///   * **Horizontally**, the pill's window is a fixed 320pt but the capsule is
    ///     centred inside it at 56pt-and-up (`PillStateModel.capsuleWidth`). Placing
    ///     against `frame.minX` would strand the companion ~130pt out in empty space,
    ///     on the wrong side of a gap.
    ///   * **Vertically**, the character is centred in this panel and the capsule is
    ///     centred in the pill's, so aligning the two window midlines is what puts
    ///     them on one eye line.
    ///
    /// The character therefore rests `panelSide / 2 - characterSize / 2` from the capsule —
    /// 20.7pt at `small` to 47.0pt at `huge`, a little further out than the old
    /// character-edge gap (18.8 to 38.4) and not negotiable: what has to clear the capsule
    /// is the reach envelope, because the envelope is the window.
    ///
    /// The side with more room wins, so a pill parked at the right edge gets its
    /// companion on the left without the user thinking about it. That is the whole of
    /// what is left of the old side handling: a one-off preference at placement time,
    /// not a persisted choice re-evaluated on every pill move.
    private func placeBesidePill() {
        guard let pill else { return }
        let pillFrame = pill.frame

        // The capsule's real edges, derived from its measured width.
        let capsuleMinX = pillFrame.midX - pill.stateModel.capsuleWidth / 2
        let capsuleMaxX = pillFrame.midX + pill.stateModel.capsuleWidth / 2

        // The capsule's centre height, which is NOT the pill window's midline.
        //
        // The pill's content is bottom-anchored and its panel is a fixed
        // `PillMetrics.windowHeight` — tall enough for the note card at all times — so the
        // capsule's centre sits `PillMetrics.capsuleCentreAboveBottom` (30pt) above the
        // window's bottom edge while `midY` is 78pt above it. Reading `midY` put the
        // character 48pt above the pill it is supposed to stand beside. The two coincided
        // only while the panel was 60pt, which it no longer ever is.
        let capsuleCentreY = pillFrame.minY + PillMetrics.capsuleCentreAboveBottom

        // Resolve the screen from the *capsule's* centre, not the pill window.
        // `NSWindow.screen` returns the display holding the largest part of the window
        // and nil when the window is ordered out; the pill's panel is a fixed 320pt with
        // a ~56pt capsule centred in it, so on a multi-display setup `pill.screen` can
        // name the display the capsule is *not* on.
        let capsuleCentre = CGPoint(x: pillFrame.midX, y: capsuleCentreY)
        let visible = (NSScreen.screens.first { $0.frame.contains(capsuleCentre) }
            ?? pill.screen ?? NSScreen.main)?.visibleFrame

        // Measured from the *panel's* inner edge, not the character's. The panel is above
        // the pill in the window order, so wherever it overlaps the capsule it takes the
        // mouse — and placing by the character's edge (what this did) still left the
        // transparent margin 2.0pt at `small` to 8.6pt at `huge` over the capsule even
        // after `panelSide` stopped double-counting the character. That overlap is why
        // hovering the pill's left half never revealed its hands-free control.
        let clearance = CompanionGeometry.clearanceFromCapsule
        let onTheLeft = capsuleMinX - clearance - geometry.panelSide
        let onTheRight = capsuleMaxX + clearance

        let preferLeft = visible.map { capsuleMinX - $0.minX >= $0.maxX - capsuleMaxX } ?? true
        // Neither side fits on a very narrow display; the clamp picks the least bad
        // position rather than oscillating between two.
        setFrameOrigin(clamped(origin: NSPoint(x: preferLeft ? onTheLeft : onTheRight,
                                               y: capsuleCentreY - geometry.panelSide / 2)))
    }

    /// `origin`, moved as little as possible to keep the character on screen.
    ///
    /// The screen is resolved from the panel's centre rather than from `NSWindow.screen`:
    /// this runs before the window has ever been ordered in (where `screen` is nil) and
    /// during a drag that can cross displays, and the character is what has to stay
    /// visible, so the display under its middle is the one that decides.
    private func clamped(origin: NSPoint) -> NSPoint {
        guard let visible = visibleFrame(forPanelOrigin: origin) else { return origin }
        return NSPoint(x: geometry.clampedX(desired: origin.x, visible: visible),
                       y: geometry.clampedY(desired: origin.y, visible: visible))
    }

    /// The visible frame of the display under a panel placed at `origin`.
    ///
    /// Resolved from the panel's centre rather than from `NSWindow.screen`: this runs before
    /// the window has ever been ordered in (where `screen` is nil) and during a drag that can
    /// cross displays, and the character is what has to stay visible, so the display under its
    /// middle is the one that decides. Shared by the clamp, the drag and the walk so all three
    /// agree on which screen they are keeping the character on.
    private func visibleFrame(forPanelOrigin origin: NSPoint) -> CGRect? {
        let centre = CGPoint(x: origin.x + geometry.panelSide / 2,
                             y: origin.y + geometry.panelSide / 2)
        let screen = NSScreen.screens.first { $0.frame.contains(centre) }
            ?? self.screen ?? NSScreen.main
        return screen?.visibleFrame
    }

    // MARK: Dragging

    private var dragGrabOffset: CGSize?

    /// Dragging the character moves the companion, and nothing else.
    ///
    /// It used to move the *pill* and let the companion follow, on the reasoning that
    /// they were one unit on screen. They are not one unit any more: the two windows
    /// have separate positions the user sets separately, which is the whole point of
    /// the change.
    private func drag(to cursor: CGPoint) {
        var origin = frame.origin

        if dragGrabOffset == nil {
            let carried = behaviour.takeAmbientOffsetForDrag()
            origin.x += carried.width
            origin.y -= carried.height
            if carried != .zero { setFrameOrigin(origin) }
            dragGrabOffset = CGSize(width: cursor.x - origin.x, height: cursor.y - origin.y)
        }

        // Told, not inferred. The character also moves during a stroll, so deriving "held"
        // from position changes would leave it dangling from an invisible hand every time
        // it walked. A drag also has to wake it: this is the one interaction that happens
        // *to* a sleeping cat, and while asleep the engine's ticker is stopped.
        behaviour.isBeingDragged = true
        behaviour.wakeIfSleeping()

        guard let grab = dragGrabOffset,
              let visible = visibleFrame(forPanelOrigin: origin) else { return }
        setFrameOrigin(geometry.draggedOrigin(cursor: cursor, grabOffset: grab, visible: visible))
    }

    // MARK: Context menu

    private lazy var companionMenu: NSMenu = {
        let menu = NSMenu()

        // Every item needs an explicit `target`.
        //
        // With a nil target AppKit walks the *key* window's responder chain to find
        // something implementing the selector. This panel is `.nonactivatingPanel`
        // with no title bar, so `canBecomeKey` is false and the app has no key
        // window when the companion is right-clicked — nothing to walk, and all
        // three items render greyed out and do nothing.
        func item(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            return item
        }

        // "Reset Position" replaces "Switch Sides", which stopped meaning anything when
        // the companion stopped sitting on a side of the pill. It is the same item the
        // pill's own menu carries, and for the same reason: a window the user can drag
        // anywhere needs a way back.
        menu.addItem(item("Reset Position", #selector(resetPosition)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(item("Companion Settings\u{2026}", #selector(openSettings)))
        menu.addItem(item("Hide Companion", #selector(hideCompanion)))
        return menu
    }()

    override func rightMouseDown(with event: NSEvent) {
        guard let contentView else { return }
        NSMenu.popUpContextMenu(companionMenu, with: event, for: contentView)
    }

    @objc private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: positionKey)
        placeBesidePill()
    }

    @objc private func openSettings() { onOpenSettings?() }

    /// Hiding from the character's own menu turns the preference off, so the
    /// companion doesn't reappear on the next launch as if the choice were ignored.
    @objc private func hideCompanion() {
        UserData.shared.companionEnabled = false
        UserData.shared.save()
    }
}

// MARK: - Container

/// The character plus its hit area.
///
/// Only the character is interactive. The rest of the panel is transparent *and*
/// non-interactive, which matters: the panel is 2.1x the character's size so it has
/// room to roam, and every point of that square that isn't the character must pass
/// clicks through to the desktop.
private struct CompanionContainerView: View {
    @ObservedObject var behaviour: CompanionBehaviour
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var packStore = SpritePackStore.shared

    let onPoke: () -> Void
    let onDragTo: (CGPoint) -> Void
    let onDragEnded: () -> Void

    /// Read from the preference rather than passed in, so the drawn character follows a
    /// size change immediately: this body already observes `userData`, where a value
    /// handed down at construction would need the hosting view's root to be rebuilt.
    /// The *panel* is resized separately, by the window that owns it.
    private var characterSize: CGFloat { userData.companionSize.points }

    @State private var isDragging = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Explicitly non-interactive: `Color.clear` still takes hits in a
            // ZStack, which would make the whole invisible panel a click target.
            Color.clear.allowsHitTesting(false)

            character
                .offset(x: behaviour.offsetX, y: behaviour.offsetY)
                // A hover lift, so the character acknowledges the pointer before
                // it is even clicked.
                .scaleEffect(isHovering ? CompanionGeometry.hoverScale : 1)
                .animation(MotionPreference.shared.reduceMotion ? Motion.reduced : Motion.morph,
                           value: isHovering)
                .contentShape(Circle())
                .onHover { hovering in isHovering = hovering }
                .onTapGesture { onPoke() }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { _ in
                            isDragging = true
                            onDragTo(NSEvent.mouseLocation)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onDragEnded()
                        }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The bubble hangs off the **panel**, not off the character, and that is load-bearing
        // rather than tidiness. As an overlay on the character it was proposed the character's
        // own width — 84pt at `huge` — so "Water break" wrapped to two lines inside a 178pt
        // panel with 141pt of text column going spare. Rendered and measured; see
        // /tmp/companion-bubble-huge-light.png before the move. The panel is also the frame the
        // bubble's geometry is expressed in, and it does not move when the character strolls or
        // hops, so a hop cannot carry the bubble with it.
        .overlay(alignment: .top) { quipBubble }
        // The companion lives in its own panel, so it needs the theme applied
        // directly — same reason `PillContainerView` does it, and deliberately
        // with no `.id(theme.id)`: keying on the theme rebuilds the subtree, which
        // restarts every material fade and reads as a pulse.
        .preferredColorScheme(themeManager.current.colorScheme)
    }

    /// The character, or nothing at all.
    ///
    /// Nothing is the only honest rendering when no pack resolves. `CompanionWindow.show()`
    /// refuses to put the panel on screen in that case, so this branch is reachable only when
    /// a pack disappears while the companion is already up — for the moment between the folder
    /// going away and the next scan.
    ///
    /// `userData.companionCharacter` is read here, rather than only inside
    /// `pack(matching:)`, so this body actually observes the preference and redraws when
    /// the user picks a different character.
    @ViewBuilder
    private var character: some View {
        if let pack = packStore.pack(matching: userData.companionCharacter) {
            SpritePackView(
                pack: pack,
                mood: behaviour.mood,
                pose: behaviour.pose,
                size: characterSize,
                elapsed: behaviour.moodElapsed
            )
        }
    }

    /// What the bubble is showing, or nil for no bubble.
    ///
    /// Real messages only — never chatter: a pet that invents things to say turns into noise
    /// beside a text field. Four kinds, and each is derived from *state*, never from reading
    /// the words:
    ///
    ///   * **failure** — `mood == .startled` alongside a quip. `apply(pillState: .error)` is
    ///     the only thing that sets that mood, and it sets it in the same call that sets the
    ///     quip, so it is an honest discriminator. Reminders arrive through `announce`, which
    ///     sets `.stretch`/`.delighted` instead.
    ///   * **reminder** — any other quip.
    ///   * **timer** — the pomodoro countdown while a block is running.
    ///   * **pinned** — the note the user pinned, which never expires.
    ///
    /// `CompanionBehaviour` does not publish *which* `CompanionReminder` fired — `announce`
    /// collapses it to a line — so stretch, water, a block boundary and a timed message all
    /// share the one bell glyph. Publishing the case alongside the line is a one-property
    /// change in that file and is what would give each its own symbol.
    ///
    /// The pinned note now survives as the **detail** line underneath a countdown or a
    /// reminder. It used to be dropped outright by the priority order, which meant a note the
    /// user deliberately pinned was invisible for the whole of a focus block — up to 25
    /// minutes.
    private var notice: CompanionNotice? {
        let pinned = behaviour.pinnedMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = pinned.isEmpty ? nil : pinned

        if !behaviour.quip.isEmpty {
            let kind: CompanionNoticeKind = behaviour.mood == .startled ? .failure : .reminder
            return CompanionNotice(kind: kind, line: behaviour.quip, detail: detail)
        }
        if let countdown = behaviour.pomodoroCountdown {
            return CompanionNotice(kind: .timer, line: countdown, detail: detail)
        }
        if let pinnedLine = detail {
            return CompanionNotice(kind: .pinned, line: pinnedLine, detail: nil)
        }
        return nil
    }

    @ViewBuilder
    private var quipBubble: some View {
        if let notice {
            let geometry = CompanionGeometry(userData.companionSize)
            CompanionBubbleView(notice: notice, geometry: geometry)
                // The bubble sizes to its content, bounded by what the panel has spare.
                .frame(maxWidth: geometry.bubbleMaxWidth,
                       maxHeight: geometry.bubbleMaxHeight,
                       alignment: .bottom)
                // A slot exactly `bubbleHeadroom` tall at the panel's top edge, with the bubble
                // **bottom-aligned** in it. Since the panel is square and the character is
                // centred in it, the slot's bottom edge is precisely the top of the character's
                // resting frame — so the bubble grows *upward, away from the character*. That is
                // the whole change: it used to be anchored a full `characterSize` above centre
                // and grow *downward over the cat*, bounded only by the panel's far edge. At
                // 84pt a three-line bubble reached 5pt into the character's frame and a
                // four-line one 24pt.
                //
                // What this cannot fix, and it is a property of the panel rather than of the
                // bubble: `bubbleHeadroom` (20.7-47.0pt across the ladder) is almost exactly the
                // character's own motion budget above its resting top
                // (`characterMotionAboveRest`, 19.7-45.9pt). The margin is 1.07-1.17pt. So at
                // the peak of a hop the character still rises into this strip, and no placement
                // inside this panel avoids it.
                .frame(height: geometry.bubbleHeadroom, alignment: .bottom)
                .transition(
                    MotionPreference.shared.reduceMotion
                        ? .opacity
                        : .scale(scale: 0.96, anchor: .bottom).combined(with: .opacity)
                )
                .animation(MotionPreference.shared.reduceMotion ? Motion.reduced : Motion.layout,
                           value: notice)
                // The bubble is a label, so it must not eat clicks meant for the
                // character underneath it.
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Display identity

extension NSScreen {
    /// The display's `CGDirectDisplayID`, or nil if AppKit does not report one.
    ///
    /// There is no property for this: `NSScreen` identity is only exposed through
    /// `deviceDescription`, and the object itself must not be persisted or compared across
    /// screen-parameter changes (AppKit rebuilds the array). The id is what survives a
    /// relaunch, so it is what the companion's saved position is keyed to.
    var displayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }
}
