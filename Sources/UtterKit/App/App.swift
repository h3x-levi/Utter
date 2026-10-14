import SwiftUI
import Cocoa
import AVFoundation
import Combine
import UserNotifications
import UtterCore

/// The SwiftUI app.
///
/// `public` and carrying no `@main`, because the whole app lives in the `UtterKit`
/// library and the `Utter` executable is a two-line shim that calls
/// `UtterApp.main()`. That split is what makes the app testable at all: SwiftPM
/// cannot attach a test target to an executable target, so with everything in
/// `main.swift` there was nowhere for a test to import from.
///
/// This is the *only* symbol the executable needs, so it is the only one that has to
/// be `public`. Everything else in `UtterKit` stays `internal` and the tests reach it
/// with `@testable import UtterKit`.
public struct UtterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    public init() {}

    public var body: some Scene {
        Settings { EmptyView() }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings\u{2026}") {
                    appDelegate.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    /// The running delegate, for the few views that need app-owned services
    /// (meeting capture needs the single shared recorder and transcriber).
    static private(set) var current: AppDelegate?

    var statusItem: NSStatusItem!
    private var hub: HubController?
    var pillWindow: PillWindow!
    /// The desktop companion. Created lazily the first time it is switched on, so a
    /// user who never enables it pays nothing - no panel, no ticker, no sprite scan.
    var companionWindow: CompanionWindow?
    var mainWindow: NSWindow?
    var audioRecorder: AudioRecorder!
    var transcriptionService: TranscriptionService!
    var keyMonitor: KeyMonitor!

    /// Meeting capture. Owned here because it needs the app's single
    /// `AudioRecorder` and `TranscriptionService` - a view cannot construct those
    /// without opening a second microphone tap on the same device.
    /// Lazy because `MeetingSession` is `@MainActor` and stored-property
    /// initialisers run in a nonisolated context; first access is from the UI.
    @MainActor lazy var meetingSession = MeetingSession()

    /// Notices when you are in a call, so Utter can offer to transcribe it. Only running while
    /// `UserData.offerToTranscribeCalls` is on - see `applyCallWatch`.
    @MainActor lazy var callDetector = CallDetector()

    /// The offer card above the pill. Non-nil only while it is on screen.
    private var meetingOfferPanel: MeetingOfferPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Line-buffered, so a log redirected to a file shows each line as it happens.
        setvbuf(stdout, nil, _IOLBF, 0)
        AXReader.configure()
        AppDelegate.current = self

        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        CompanionNotificationScheduler.shared.registerCategory()
        CompanionMemoryStore.shared.restoreScheduledNotifications()
        Task { await CompanionNotificationScheduler.shared.refreshState() }

        // Read the version first: the crash reporter caches it as raw bytes so its
        // signal handler can write it without allocating, and a handler installed
        // beforehand would have captured the hardcoded fallback instead of the real
        // bundle version. `load()` touches only Info.plist and UserDefaults, so
        // nothing here can fault in a way the reporter would have caught.
        ConfigManager.shared.load()

        // Install the crash reporter before anything that can fault.
        CrashReporter.shared.install()
        // Apply the saved theme's appearance to NSApp before any window exists,
        // so dynamic NSColor tokens resolve correctly from the first frame.
        ThemeManager.shared.applyAppearance()

        // Nothing past here runs until whoever has to sign in has.
        let account = AccountSession.shared
        guard account.isRequired else { return launchApp() }
        Task { @MainActor in
            await account.restore()
            if account.needsSignIn { showSignIn(required: true) } else { launchApp() }
        }
    }

    @MainActor private func launchApp() {
        // Carry the old single-buffer scratchpad over to a real note. Runs before
        // any window appears, so the notes screen never renders the empty state
        // while the user's previous text is still sitting in the old key.
        NoteStore.shared.migrateLegacyScratchpadIfNeeded()

        // Build the history store now, off the window-open path.
        //
        // `showMainWindow` builds `MainWindowModel` synchronously, and its view models subscribe to
        // `TranscriptionHistory.shared`, so the singleton is created there, before the window exists.
        // Its `init` reads history.json and streak.json and parses every entry.
        //
        // Measured, on a verbatim replica of `TranscriptionHistory.load()` against synthetic
        // files: 2.8 ms at 50 entries, 8.8 ms at 250, **33.8 ms at the 1000 entries `saveHistory`
        // caps at**, and 50.8 ms if those entries are long. Roughly 27 of those 34 ms are
        // per-entry work - `ISO8601DateFormatter.date(from:)` measured 21.7 us a call, and
        // `TranscriptionEntry.init`'s `text.split(separator: " ")` 5.6 us - so it scales with the
        // user's history and is worst for the users who have most of it. All of it landed between
        // the hotkey and the window appearing, once per launch.
        //
        // Deferred a runloop turn rather than run inline, so it is not on the launch path either:
        // the store is only needed when a window opens, and the pill has to come up first.
        // `--open-window` (below) still pays it inline, since that opens a window in this same
        // call - a dev flag, and no worse than before.
        DispatchQueue.main.async { _ = TranscriptionHistory.shared }

        transcriptionService = TranscriptionService()
        audioRecorder = AudioRecorder()
        SoundPlayer.preload()

        pillWindow = PillWindow(
            onLongPress: { [weak self] in self?.showMainWindow() },
            // The pointer route into hands-free, from the lock the pill reveals on hover.
            // The same entry point ⌃⌥Space uses, so the two cannot drift apart.
            onStartHandsFree: { [weak self] in self?.capture.toggle(.handsFree) }
        )
        capture = CaptureSession(
            recorder: audioRecorder,
            transcriber: transcriptionService,
            pill: pillWindow,
            meetingIsActive: { [weak self] in self?.meetingIsRecording ?? false },
            suppressRelease: { [weak self] in self?.keyMonitor?.suppressReleaseStop = $0 },
            celebrate: { [weak self] in self?.companionWindow?.behaviour.celebrateGoal($0) }
        )
        applyPillVisibility()
        setupMenuBar()

        // All of these are user preferences that change app-wide behaviour, so they are applied at
        // launch and re-applied whenever the preference changes.
        applyDockVisibility()
        applyCompanionVisibility()
        applyCallWatch()
        prefsObserver = UserData.shared.objectWillChange
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyDockVisibility()
                self?.applyPillVisibility()
                self?.applyCompanionVisibility()
                self?.applyCallWatch()
            }

        // Only now that the pill exists can it reflect load state. Observe first,
        // then kick off the load, so the initial `.preparing` emission lands.
        capture.observeModelLoad()
        transcriptionService.preload()

        keyMonitor = KeyMonitor(
            onRecordStart: { [weak self] in self?.capture.holdBegan() },
            onRecordStop: { [weak self] in self?.capture.holdEnded() },
            onAction: { [weak self] action in
                switch action {
                case .handsFree: self?.capture.toggle(.handsFree)
                case .noteCapture: self?.capture.toggle(.note)
                case .memoryCapture: self?.toggleMemoryCapture()
                case .openWindow: self?.showMainWindow()
                }
            },
            onCancel: { [weak self] in self?.capture.cancel() }
        )
        keyMonitor.start()

        // Listen for hotkey changes from Settings
        NotificationCenter.default.addObserver(forName: .hotkeyChanged, object: nil, queue: .main) { [weak self] _ in
            self?.keyMonitor.restart()
        }

        // Switching speech models means the cached whisper context is stale.
        NotificationCenter.default.addObserver(
            forName: .speechModelChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.transcriptionService.localProvider.invalidate()
            // preload() reads the selected tier from ModelStore, which is
            // main-actor isolated, so hop explicitly rather than relying on the
            // notification queue.
            Task { @MainActor in self.transcriptionService.preload() }
        }

        // First run: show the guided onboarding instead of silently prompting.
        // Returning users go straight to the permission checks.
        if !OnboardingState.hasCompleted {
            showOnboarding()
        } else {
            requestAccessibilityPermission()
            requestMicrophonePermission()
        }

        // `--open-window` opens the main window at launch. Utter is a menu-bar
        // app, so the window is normally opened by the user; this makes it
        // reachable from `open -a Utter --args --open-window`, which is the only
        // way to inspect the window when Accessibility is switched off (the
        // hotkey and the status-item menu both need it).
        if CommandLine.arguments.contains("--open-window") {
            showMainWindow()
        }
        if CommandLine.arguments.contains("--open-settings") { showSettingsWindow() }
        if CommandLine.arguments.contains("--open-onboarding") { showOnboarding() }
        if CommandLine.arguments.contains("--open-sign-in") { showSignIn() }
        if CommandLine.arguments.contains("--open-hub") { DispatchQueue.main.async { [weak self] in self?.hub?.open() } }

        // Suppress any spurious windows automatically opened by SwiftUI's default scene resolution
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for window in NSApp.windows {
                let isManaged = (window === self.onboardingWindow ||
                                 window === self.mainWindow ||
                                 window === self.settingsWindow ||
                                 window === self.pillWindow ||
                                 window === self.companionWindow ||
                                 window is PillWindow ||
                                 window is CompanionWindow)
                if !isManaged && window.isVisible && window.title.contains("Settings") {
                    window.orderOut(nil)
                    window.close()
                }
            }
        }
    }

    private var onboardingWindow: NSWindow?
    private var signInWindow: NSWindow?

    /// `required` is the launch gate: the window cannot be closed, and signing in finishes the launch.
    @MainActor func showSignIn(required: Bool = false) {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = signInWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = OnboardingView.makeWindow(ThemedRoot {
            SignInView(session: AccountSession.shared,
                       onSignedIn: { [weak self] in
                           self?.signInWindow?.close()
                           self?.signInWindow = nil
                           if required { self?.launchApp() }
                       },
                       onQuit: { NSApp.terminate(nil) })
        }, title: "Sign in to Utter")
        if required {
            window.styleMask.remove(.closable)
            // No menu-bar item exists yet, so the Dock icon is the only way back to this window.
            NSApp.setActivationPolicy(.regular)
        }
        window.delegate = self
        window.center()
        signInWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func showOnboarding() {
        // A second press must raise the window already on screen, not leave it orphaned beside a new one.
        if let existing = onboardingWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = OnboardingView.makeWindow(ThemedRoot {
            OnboardingView(onFinish: { [weak self] skipped in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.applyDockVisibility()
                guard !skipped else { return }
                self?.requestAccessibilityPermission()
                self?.requestMicrophonePermission()
            })
        })
        window.delegate = self
        window.center()
        onboardingWindow = window

        // The one window that does escalate, whatever "Show in Dock" says.
        //
        // Onboarding sends the user out to System Settings at the microphone,
        // accessibility and screen-recording steps, and an accessory app has no Dock
        // icon and no Cmd-Tab entry to come back through - and unlike the main window,
        // Settings and What's New, no menu-bar item reopens it. The Dock icon is the
        // way back to a flow the user is in the middle of. `onFinish` hands the policy
        // back to the preference.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Prevent app from quitting when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Release the speech context before AppKit calls `exit()`, without blocking main on it.
    ///
    /// Without this, whisper's Metal device was destroyed by a C++ static
    /// destructor during process teardown and aborted, so every normal quit was
    /// logged as a SIGABRT crash.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let provider = transcriptionService?.localProvider else { return .terminateNow }
        provider.shutdown { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A meeting in progress holds un-transcribed audio. Nothing can be done
        // about that window at quit time, but everything already transcribed goes
        // into the note here and the flush below persists it.
        meetingSession.flushPending()
        // Notes save on a 1s debounce, so a quit within that window would drop the
        // last edit. Queue the latest snapshot and wait for the serial writer to drain.
        NoteStore.shared.writeToDisk()
        NoteStore.shared.flushPendingWrites()
        TranscriptionHistory.shared.flushPendingWrites()
        UserData.shared.flushNow()
    }

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            // The app's own mark, as a template image.
            //
            // `isTemplate = true` is what makes it adapt: macOS then ignores the
            // file's colour and tints the alpha channel itself - black on a light
            // menu bar, white on a dark one, and highlighted while the menu is
            // open. A non-template image would render as a fixed-colour slab in
            // one of the two appearances.
            //
            // Falls back to an SF Symbol if the asset is missing, so a dev build
            // without generated assets still shows something sensible.
            if let mark = Self.menuBarImage() {
                mark.isTemplate = true
                mark.size = NSSize(width: 18, height: 18)
                button.image = mark
            } else {
                button.image = NSImage(systemSymbolName: "waveform",
                                       accessibilityDescription: "Utter")?
                    .withSymbolConfiguration(config)
            }
        }

        meetingSession.onCallEnded = { [weak self] in
            self?.capture.showNotice("Call ended. Meeting saved")
        }
        hub = HubController(
            statusItem: statusItem,
            pill: pillWindow.stateModel,
            meeting: meetingSession,
            startMeeting: { [weak self] in await self?.recordMeeting() ?? .refused("") },
            notify: { [weak self] message in self?.capture.showNotice(message) },
            command: { [weak self] action in
                guard let self else { return }
                switch action {
                case .handsFree: self.capture.toggle(.handsFree)
                case .newNote: self.capture.toggle(.note)
                case .openLibrary: self.showMainWindow()
                case .settings: self.showSettingsWindow()
                case .whatsNew: self.showWhatsNew()
                case .reportIssue: self.showReportIssue()
                case .quit: self.quit()
                case .recordMeeting, .open, .paste, .grant: break
                }
            }
        )
    }

    /// Load the menu-bar template from the bundle, or from the project root when
    /// running a dev build straight out of `.build`.
    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "menubar-icon",
                                     withExtension: "png",
                                     subdirectory: "MenuBarIcon"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Dev fallback: walk up from the binary to the project root.
        let binary = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let root = binary.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return NSImage(contentsOf: root
            .appendingPathComponent("MenuBarIcon/menubar-icon.png"))
    }

    @MainActor
    func showMainWindow() {
        if let w = mainWindow {
            if !w.isVisible, !w.isMiniaturized { ReadinessMonitor.shared.startPolling() }
            w.makeKeyAndOrderFront(nil)
            // Activation alone, no policy change: see `applyDockVisibility`.
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = MainWindowModel(
            status: CaptureStatus(source: pillWindow?.stateModel),
            meeting: meetingSession,
            startMeeting: { [weak self] in await self?.recordMeeting() ?? .refused("") },
            openSettings: { [weak self] group in
                if let group { SettingsModel.shared.group = group }
                self?.showSettingsWindow()
            },
            toggleHandsFree: { [weak self] in self?.capture.toggle(.handsFree) }
        )
        // SwiftUI owns the split view, toolbar and title; the window keeps AppKit's lifecycle.
        let hosting = NSHostingController(rootView: MainWindowView(model: model))
        hosting.sizingOptions = []
        hosting.sceneBridgingOptions = .all

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Layout.windowIdealWidth, height: Layout.windowIdealHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Utter"
        // Opt out of macOS window restoration: it would re-create the window from its own copy of the geometry.
        window.isRestorable = false
        window.toolbarStyle = .unified
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: Layout.windowIdealWidth, height: Layout.windowIdealHeight))
        window.contentMinSize = NSSize(width: Layout.windowMinWidth, height: Layout.windowMinHeight)
        window.minSize = NSSize(width: Layout.windowMinWidth, height: Layout.windowMinHeight)
        // Restore before registering: `setFrameAutosaveName` writes the current frame when none is stored.
        // The size suffix abandons frames saved at an older default size.
        let mainFrameName = "UtterMain.1380x960"
        if !window.setFrameUsingName(mainFrameName) {
            window.center()
        }
        window.setFrameAutosaveName(mainFrameName)
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        // The hosting view has collapsed the window to ~133x142 on some launches; restore the intended size.
        let intended = NSSize(width: Layout.windowIdealWidth, height: Layout.windowIdealHeight)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak window] in
            guard let window else { return }
            guard window.frame.width < Layout.windowMinWidth
                || window.frame.height < Layout.windowMinHeight else { return }
            window.setContentSize(intended)
            if let screen = window.screen ?? NSScreen.main,
               !screen.visibleFrame.intersects(window.frame) {
                window.center()
            }
        }

        ReadinessMonitor.shared.startPolling()
        // Activation alone, no policy change: see `applyDockVisibility`.
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    @MainActor
    func showCompanion(section: CompanionSection) {
        SettingsModel.shared.showCompanion(section)
        showSettingsWindow()
    }

    /// Show or hide the Dock icon.
    ///
    /// `.regular` puts Utter in the Dock and in Cmd-Tab; `.accessory` keeps it
    /// menu-bar-only. This is the only place the policy is chosen: it used to be that
    /// every window-opening path also forced `.regular` so its window could take
    /// focus, which meant "Show in Dock" off still put Utter in the Dock for as long
    /// as any window was open - the switch did not do what it said.
    ///
    /// It does not have to: an accessory app "may be activated programmatically or by
    /// clicking on one of its windows" (`NSRunningApplication.h`, the definition of
    /// `NSApplicationActivationPolicyAccessory`), and activation is what confers key
    /// status and keyboard input. So the windows now just call `NSApp.activate` and
    /// leave the policy to the preference. What an accessory app does *not* get is its
    /// own menu bar; ⌘C/⌘V/⌘W/⌘Q keep working because AppKit dispatches key
    /// equivalents through `NSApp.mainMenu` whether or not that menu is on screen
    /// (they are not in `StandardKeyBinding.dict`, so the menu is the only route  - 
    /// this is the part that needs confirming on a device).
    private func applyDockVisibility() {
        let target: NSApplication.ActivationPolicy =
            UserData.shared.showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return }

        // Dropping to `.accessory` deactivates the app, so a window on screen would
        // lose focus underneath the user - and one of the ways to get here is the
        // "Show in Dock" toggle inside the Settings window itself. Defer it instead:
        // every path that closes a window calls back here, so the policy always ends
        // up matching the preference once the last window is gone. Escalating to
        // `.regular` needs no such care (it only adds a Dock icon), and every window
        // in the app used to do exactly that with a window already on screen.
        if target == .accessory, isAnyWindowVisible { return }

        NSApp.setActivationPolicy(target)
    }

    /// Whether any titled window is on screen. Panels (pill, hub, companion, call card) never hold
    /// focus, and the status item's window has no title bar, so neither counts.
    private var isAnyWindowVisible: Bool {
        NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) && !($0 is NSPanel) }
    }

    /// Keep the pill on screen, or hide it until dictation starts.
    private func applyPillVisibility() {
        guard let pill = pillWindow else { return }
        if UserData.shared.alwaysShowPill {
            if !pill.isVisible { pill.orderFront(nil) }
        } else if pill.isVisible, !pill.currentState.isRecordingLike, !pill.currentState.isIsland {
            // Never yank it away mid-recording, or while it holds a transcript to copy.
            pill.orderOut(nil)
        }
    }

    // MARK: - Companion

    /// Create, show or hide the desktop companion to match the preference.
    ///
    /// The window is built on first use rather than at launch: a user who leaves the
    /// companion off should not be paying for a panel, a 30 Hz behaviour ticker, or a
    /// scan of the sprite-pack folder.
    @MainActor
    private func applyCompanionVisibility() {
        guard UserData.shared.companionEnabled else {
            // Cancel the state subscription, not just the window.
            //
            // `hide()` stops the behaviour ticker, but the subscription outlived it:
            // the next dictation turn delivered a `PillState` to `apply(pillState:)`,
            // which calls `set(mood:)` -> `wake()` -> `start()` and restarted the
            // 30 Hz ticker behind `hide()`'s back - publishing into an ordered-out
            // window with nothing left to stop it. `applyCompanionVisibility` returns
            // at this guard on every later call, so it never got another chance.
            companionStateObserver?.cancel()
            companionStateObserver = nil
            companionWindow?.hide()
            // Release the window as well, so `deinit` actually runs and the panel,
            // its hosting view, its observations and the behaviour engine are freed
            // rather than kept for the process lifetime. Nothing else holds a
            // reference - the companion is not a child of the pill any more, so the
            // pill does not retain it either; a later enable rebuilds it.
            companionWindow = nil
            return
        }
        guard let pill = pillWindow else { return }

        if companionWindow == nil {
            companionWindow = CompanionWindow(pill: pill) { [weak self] in
                self?.showCompanion(section: .companion)
            }
        }

        // Wire (or re-wire) the signals every time the companion is enabled. The
        // window survives a disable, so a second enable would otherwise find a live
        // panel with a cancelled subscription and a character that never reacts.
        if companionStateObserver == nil {
            wireCompanionSignals()
        }

        // The companion is an independent window with its own saved position, so this
        // is the whole of its visibility: on screen while the preference is on. It used
        // to be a child window of the pill, which meant AppKit ordered it in and out
        // with the pill and the character came and went with each dictation turn when
        // "always show the pill" was off - the companion has its own toggle, and that
        // is the one it should follow.
        companionWindow?.show()
    }

    // MARK: - Call detection

    /// Start or stop watching for calls, to match the preference.
    ///
    /// Called at launch and whenever the preference changes. With the preference off nothing samples
    /// CoreAudio at all - the feature costs nothing when unused, rather than running and discarding
    /// its answer. Restarting it here is also the detector's second chance to probe for the
    /// per-process API it needs, which it stops itself over when the system will not answer.
    @MainActor
    func applyCallWatch() {
        guard UserData.shared.offerToTranscribeCalls else {
            callDetector.stop()
            dismissMeetingOffer()
            return
        }
        guard !callDetector.isWatching else { return }

        // Not to stop the detector seeing Utter's own microphone - it excludes our pid itself now.
        // This covers what a pid cannot: meeting capture takes the other participants through
        // `ScreenCaptureKit`, which is not a HAL client of ours, and a capture started from the Notes
        // screen has to withdraw a live offer card. Read live rather than captured, because both can
        // change mid-call.
        callDetector.selfIsCapturing = { [weak self] in
            guard let self else { return false }
            return self.audioRecorder.isRecording || self.meetingIsRecording
        }
        callDetector.onCallStarted = { [weak self] in self?.showMeetingOffer() }
        callDetector.onCallEnded = { [weak self] in self?.dismissMeetingOffer() }
        callDetector.start()
    }

    @MainActor
    private func showMeetingOffer() {
        // Already capturing, or already asking: nothing to offer.
        guard meetingOfferPanel == nil,
              meetingSession.state == .idle,
              let pill = pillWindow else { return }

        let panel = MeetingOfferPanel(
            pill: pill,
            // "You're in a Zoom call" when CoreAudio would say which app is doing the audio, and
            // "You're in a call" when it would not - which is the ordinary case for a meeting in a
            // browser tab, not a failure. The card's height is measured from whichever string this is,
            // because a long app name wraps the title and the overflow is the button row.
            title: CallSource.offerTitle(appName: callDetector.currentCall?.appName),
            onSpeakers: MeetingSession.playsThroughSpeakers,
            // Deliberately does *not* dismiss the card first. A start can fail - no Screen
            // Recording, the microphone busy - and the card is the only surface that can say why and
            // the only try-again for this call: `onCallStarted` fires on a transition, so once the
            // card is gone nothing offers again until the next call. `startMeetingFromOffer`
            // dismisses it once a capture is actually running.
            onAccept: { [weak self] in self?.startMeetingFromOffer() },
            onDecline: { [weak self] in
                self?.dismissMeetingOffer()
                // Forget this call so the panel does not come back for it, while leaving the watch
                // running so the next call is still noticed.
                self?.callDetector.dismissCurrentCall()
            }
        )
        meetingOfferPanel = panel
        panel.show()
    }

    @MainActor
    private func dismissMeetingOffer() {
        guard let panel = meetingOfferPanel else { return }
        panel.dismiss { [weak self, panel] in
            guard self?.meetingOfferPanel === panel else { return }
            self?.meetingOfferPanel = nil
        }
    }

    /// Begin a meeting capture from the offer, filing it into a note.
    ///
    /// Goes through the same `MeetingSession.start` the Notes screen uses rather than a second
    /// entry point, including the permission check - which is now `MeetingSession.prepare`, shared
    /// with that screen so the two cannot answer the same denial differently. Whichever permission
    /// ends up being needed, capture without it records only the user, which is the failure most
    /// likely to go unnoticed: it produces a transcript that simply has half a conversation in it.
    @MainActor
    private func startMeetingFromOffer() {
        // Read before the hop: the call can end while the task is suspended, and the note's title and
        // the capture's target both come from this.
        let source = callDetector.currentCall
        Task { @MainActor in
            let outcome = await recordMeeting(source: source)
            guard case .started(let id) = outcome else {
                if case .refused(let why) = outcome { reportOfferFailure(why) }
                return
            }
            NoteStore.shared.selectedNoteID = id
            dismissMeetingOffer()

            // Recording a call captures other people's voices, so the running state has to be
            // obvious for the whole of it - the note screen's meeting bar states that invariant, and it is
            // the app's one recording banner: a red dot, the elapsed time, a Stop button, and the
            // warning that nothing has been heard from the other side yet. Opening the screen it
            // lives on reuses all of that; a new persistent `PillState` would be a second indicator
            // to keep in step, in the state machine this panel exists to stay out of.
            //
            // It costs an activation, which pulls focus from the call for a moment. That is the
            // deliberate trade: the alternative is recording other people with nothing on screen
            // saying so.
            SidebarSelection.shared.openNote(id)
            showMainWindow()

            capture.showNotice("Recording the meeting")
        }
    }

    @MainActor
    private func recordMeeting(source: CallSource? = nil) async -> MeetingSession.StartOutcome {
        await meetingSession.record(recorder: audioRecorder, transcriber: transcriptionService, source: source)
    }

    /// Report a failed start where the user pressed the button.
    ///
    /// On the card, which keeps its buttons so Transcribe is the try-again, and which is wide enough
    /// for a sentence - the pill is not, and these messages name a System Settings pane.
    @MainActor
    private func reportOfferFailure(_ message: String) {
        if let panel = meetingOfferPanel {
            panel.showFailure(message)
            return
        }
        // The card is already gone: the call ended, or the preference was switched off, while the
        // start was in flight. The pill is all that is left, so it gets the short version.
        capture.showError("Couldn\u{2019}t start the meeting recording")
    }

    @MainActor
    private func wireCompanionSignals() {
        guard let companion = companionWindow, let pill = pillWindow else { return }

        companionStateObserver = pill.stateModel.$state
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { state in
                // `receive(on: .main)` guarantees the thread but not the compiler's
                // knowledge of it, and the engine is `@MainActor`. `assumeIsolated`
                // asserts what the operator already ensures, rather than hopping
                // through a `Task` and delivering the mood a frame late.
                MainActor.assumeIsolated {
                    companion.behaviour.apply(pillState: state)
                }
            }
    }

    private var companionStateObserver: AnyCancellable?

    private var prefsObserver: AnyCancellable?
    @objc private func quit() { NSApp.terminate(nil) }

    private var settingsWindow: NSWindow?

    /// Autosave key for the Settings window's frame, suffixed with the default size so a new default
    /// is not shadowed by a frame saved at the old one. Distinct from "UtterMain": AppKit refuses a
    /// duplicate autosave name and then stops remembering either window.
    private static let settingsFrameName = "UtterSettings.780x700"

    /// Open Settings in its own window.
    @objc func showSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = SettingsWindowView.makeWindow()
        // `setFrameUsingName` replays the stored frame without consulting `contentMinSize`, and a frame
        // stored on a display that is gone reopens out of reach. Restore before registering the name.
        if window.setFrameUsingName(Self.settingsFrameName) {
            window.setContentSize(Layout.size(window.contentRect(forFrameRect: window.frame).size,
                                              atLeast: window.contentMinSize))
            if let screen = window.screen ?? NSScreen.main, !screen.visibleFrame.intersects(window.frame) {
                window.center()
            }
        } else {
            window.center()
        }
        window.setFrameAutosaveName(Self.settingsFrameName)
        // Only for `windowWillClose`, so the Dock preference is reasserted once this window is gone.
        window.delegate = self
        settingsWindow = window

        // Activation alone, no policy change: see `applyDockVisibility`.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private var whatsNewWindow: NSWindow?
    private var reportIssueWindow: NSWindow?

    @objc public func showReportIssue() {
        openReportIssue()
    }

    public func openReportIssue(crashLog: String? = nil, category: IssueCategory = .bug) {
        presentAuxWindow(
            &reportIssueWindow,
            title: "Report an Issue / Send Feedback",
            size: NSSize(width: 660, height: 620),
            content: AnyView(
                ThemedRoot {
                    ReportIssueSheet(initialCrashLog: crashLog, initialCategory: category)
                }
            )
        )
    }

    @objc private func showWhatsNew() {
        presentAuxWindow(
            &whatsNewWindow,
            title: "What\u{2019}s New in Utter",
            size: NSSize(width: 560, height: 620),
            // No `ScrollView` here. `WhatsNewView` is a `List` now, which is itself a
            // scroll view: nested, the inner one is handed unbounded height, never
            // scrolls, and the outer one owns the wheel - so the release sections laid
            // out at full height inside a second scroller.
            content: AnyView(
                WhatsNewView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        )
    }

    private func presentAuxWindow(_ slot: inout NSWindow?, title: String,
                                  size: NSSize, content: AnyView) {
        if let existing = slot {
            existing.makeKeyAndOrderFront(nil)
            // Activation alone, no policy change: see `applyDockVisibility`.
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Never open taller than the screen. An NSHostingView sizes itself to its
        // content, so without this clamp a long settings pane produced a window
        // whose title bar and bottom edge were both off-screen.
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let clamped = NSSize(
            width: min(size.width, visible.width - 80),
            height: min(size.height, visible.height - 80)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: clamped),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        // These keep a normal titlebar - they're secondary windows and the title
        // is the only thing naming them - but the content still gets the
        // translucent backing so cards inside read as the same material as the
        // main window's.
        window.isOpaque = false
        window.backgroundColor = .clear
        let hosting = NSHostingView(rootView: ThemedRoot {
            content
                .background(WindowBacking(material: .underWindowBackground)
                    .ignoresSafeArea())
        })
        // Let the window drive the view's size rather than the reverse - **and that takes both
        // lines.** `autoresizingMask` alone only says how the view follows a frame it is given; it
        // does nothing about the view *publishing* a size upward. `NSHostingView.sizingOptions`
        // defaults to `.standardBounds`, which includes `.intrinsicContentSize`, so as this
        // window's `contentView` the hosting view's Auto Layout constraints drive the window's
        // dimensions instead of the reverse. That is the ~133x142 collapse `showMainWindow`
        // documents and carries a re-assert loop for, and it is why `showOnboarding`,
        // `showMainWindow`, `showSettingsWindow` and `PillWindow` all set this. This was the one
        // window still exposed to it - and the clamp above is the same defect's other half, seen
        // as "a long settings pane produced a window whose title bar and bottom edge were both
        // off-screen". Every window in the app is now muzzled.
        if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.contentMinSize = NSSize(width: 460, height: 360)
        window.contentMaxSize = NSSize(width: 900, height: visible.height)
        window.center()
        window.isReleasedWhenClosed = false
        // For `windowWillClose` only, as in `showSettingsWindow`.
        window.delegate = self
        slot = window
        // Activation alone, no policy change: see `applyDockVisibility`.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The dictation turn: state machine, mic, preview and delivery. Built once the pill exists.
    private var capture: CaptureSession!

    /// Voice capture into the companion's private memory store, also offered on the Companion screen.
    @MainActor func toggleMemoryCapture() { capture.toggle(.memory) }

    /// Whether a meeting still owns the shared recorder.
    ///
    /// `.finishing` counts. `MeetingSession.stop()` closes the tap, then awaits the tail
    /// inference for seconds before calling `recorder?.consume(micConsumed)` and releasing
    /// the recorder. A dictation started inside that window has its own opening seconds
    /// deleted by that `consume` - up to a 30s window of bytes - and the user is never told.
    private var meetingIsRecording: Bool {
        MainActor.assumeIsolated {
            meetingSession.isCapturing
        }
    }

    /// Ask for Accessibility once, then stop asking.
    ///
    /// The rules - once ever, never when already granted, never a second ask after a screen has
    /// opened the pane itself - live in `AccessibilityPermission`, because they were previously
    /// enforced here and *not* in the onboarding step, which is how one button press ended up
    /// raising the system dialog on top of the System Settings pane it had just opened.
    ///
    /// The non-prompting check still runs each launch, so Home and Settings keep showing accurate
    /// status; only the modal is capped. Granting it later is a click away in Settings, which is
    /// where a returning user expects to find it.
    private func requestAccessibilityPermission() {
        if AccessibilityPermission.isTrusted {
            print("♿ Accessibility: trusted")
        } else if AccessibilityPermission.promptOnce() {
            print("♿ Accessibility: prompted for the first time")
        } else {
            // Includes the case that matters after onboarding: that screen opened the pane
            // itself, which counts as having asked, so this must not raise a second dialog.
            print("♿ Accessibility: not granted (already asked, not re-prompting)")
        }
    }

    private func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎤 Microphone: authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎤 Microphone: \(granted ? "granted" : "denied")")
            }
        case .denied, .restricted:
            // No prompt here either: once denied, macOS will not show the dialog
            // again, and asking would be a no-op. Settings has a Grant button.
            print("⚠️ Microphone: denied - grant it in Settings > General")
        @unknown default:
            break
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Only the main window is hidden rather than closed. Settings and What's New
        // are this delegate's clients purely for `windowWillClose`, and they are
        // ordinary closable windows - vetoing their close would leave AppKit
        // considering them open forever, which `isAnyWindowVisible` would then read as
        // a window on screen and never let the Dock icon go.
        guard sender == mainWindow else { return true }

        // Don't actually close - just hide the window and go back to pill mode
        sender.orderOut(nil)
        ReadinessMonitor.shared.stopPolling()
        // Keep `mainWindow` pointing at it.
        //
        // This used to nil the reference while also returning false, so the window
        // was hidden but never closed and nothing of ours pointed at it any more.
        // The next "Open Utter" therefore missed `showMainWindow`'s reuse branch and
        // built a *second* window with the same `frameAutosaveName` - and AppKit
        // refuses a duplicate autosave name, so from the first close onwards the
        // user's window size and position stopped being remembered. Every cycle also
        // left another split-view controller and its two SwiftUI trees alive for the
        // process lifetime.
        //
        // `isAnyWindowVisible` and `showMainWindow` both test `isVisible`, not
        // nil-ness, so a retained hidden window is what they already expect.
        //
        // Deferred a runloop turn because `orderOut` above has not yet taken effect
        // when the delegate is called, and asks for the *preference* rather than
        // hardcoding `.accessory`: this line used to drop the Dock icon on every close
        // even for someone who had asked to keep it.
        DispatchQueue.main.async { [weak self] in self?.applyDockVisibility() }
        return false // Prevent the window from actually closing
    }

    /// Reassert the Dock preference once a window is off screen.
    ///
    /// This is the other half of the deferral in `applyDockVisibility`: a demotion to
    /// `.accessory` that was postponed because a window was up has to actually happen
    /// when that window goes away, or turning "Show in Dock" off inside the Settings
    /// window would leave Utter in the Dock until the next launch. Never fires for the
    /// main window, which vetoes its own close - that path calls back directly above.
    func windowWillClose(_ notification: Notification) {
        if let closing = notification.object as? NSWindow {
            if closing === onboardingWindow {
                OnboardingState.markCompleted()
                onboardingWindow = nil
            }
            if closing === reportIssueWindow { reportIssueWindow = nil }
            if closing === signInWindow { signInWindow = nil }
            if closing === whatsNewWindow { whatsNewWindow = nil }
        }
        DispatchQueue.main.async { [weak self] in self?.applyDockVisibility() }
    }
}


extension AppDelegate {
    private static func memoryID(from response: UNNotificationResponse) -> UUID? {
        let raw = response.notification.request.content.userInfo[
            CompanionNotificationPayload.memoryIDKey
        ] as? String
        return raw.flatMap(UUID.init(uuidString:))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let raw = notification.request.content.userInfo[
            CompanionNotificationPayload.memoryIDKey
        ] as? String,
           let id = UUID(uuidString: raw) {
            Task { @MainActor in
                _ = CompanionMemoryStore.shared.markDelivered(id: id)
                SoundPlayer.playReminder()
            }
        }
        // The system banner is the native Apple notification surface and remains
        // actionable even while Utter's main window is open.
        completionHandler([.banner])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let id = Self.memoryID(from: response) else {
            completionHandler()
            return
        }

        Task { @MainActor in
            switch response.actionIdentifier {
            case CompanionNotificationScheduler.doneAction:
                CompanionMemoryStore.shared.complete(id: id)
            case CompanionNotificationScheduler.snoozeAction:
                CompanionMemoryStore.shared.snooze(id: id)
            default:
                _ = CompanionMemoryStore.shared.markDelivered(id: id)
                showCompanion(section: .remember)
            }
            completionHandler()
        }
    }
}
