import SwiftUI
import Cocoa
import AVFoundation
import Combine
import UserNotifications

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
        Settings {
            HStack(spacing: 0) {
                SettingsSidebar()
                SettingsDetail()
            }
        }
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
        AXReader.configure()
        AppDelegate.current = self

        // Preview generation is a rendering-only tool. Isolate all data stores in memory
        // and keep it ahead of notification restoration, crash reporting, credential
        // migration, and audio/model service startup.
        if CommandLine.arguments.contains("--render-snapshots") {
            SnapshotPreviewMode.enable()
            NSApp.setActivationPolicy(.accessory)
            ConfigManager.shared.load()
            ThemeManager.shared.applyAppearance()
            SnapshotRenderer.renderAll()
            exit(0)
        }

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

        // Carry the old single-buffer scratchpad over to a real note. Runs before
        // any window appears, so the notes screen never renders the empty state
        // while the user's previous text is still sitting in the old key.
        NoteStore.shared.migrateLegacyScratchpadIfNeeded()

        // Build the history store now, off the window-open path.
        //
        // `showMainWindow` constructs `FlowContent()` synchronously, and `FlowContent` carries
        // `@ObservedObject private var history = TranscriptionHistory.shared` - a *property
        // initialiser*, so the singleton is created at `FlowContent()`, before the window exists.
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
        DispatchQueue.main.async {
            let history = TranscriptionHistory.shared
            _ = UserData.shared.syncCompanionLifetimeWords(history.totalWords)
        }

        transcriptionService = TranscriptionService()
        audioRecorder = AudioRecorder()
        SoundPlayer.preload()

        setupMenuBar()

        pillWindow = PillWindow(
            onLongPress: { [weak self] in self?.showMainWindow() },
            // The pointer route into hands-free, from the lock the pill reveals on hover.
            // The same entry point ⌃⌥Space uses, so the two cannot drift apart.
            onStartHandsFree: { [weak self] in self?.toggleHandsFree() }
        )
        applyPillVisibility()

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
        observeModelLoad()
        transcriptionService.preload()

        keyMonitor = KeyMonitor(
            onRecordStart: { [weak self] in self?.startRecording() },
            onRecordStop: { [weak self] in self?.stopRecording() },
            onHandsFreeToggle: { [weak self] in self?.toggleHandsFree() },
            onNoteCaptureToggle: { [weak self] in self?.toggleNoteCapture() },
            onMemoryCaptureToggle: { [weak self] in self?.toggleMemoryCapture() }
        )
        keyMonitor.start()
        // The menu was built before the monitor existed, so its hands-free hint was
        // written without knowing whether hold-then-tap got an event tap. Now it does.
        refreshMenuHint()

        // Listen for hotkey changes from Settings
        NotificationCenter.default.addObserver(forName: .hotkeyChanged, object: nil, queue: .main) { [weak self] _ in
            self?.keyMonitor.restart()
            self?.refreshMenuHint()
        }

        // Switching speech models means the cached whisper context is stale.
        NotificationCenter.default.addObserver(
            forName: .speechModelChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.transcriptionService.localProvider?.invalidate()
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

    private func showOnboarding() {
        // Re-openable from the status menu now, so a second press must raise the window
        // that is already on screen. Without this the old `NSWindow` was overwritten in
        // the slot and left visible with nothing holding it, and the user got two
        // welcome screens.
        if let existing = onboardingWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        // Onboarding is the first-run product flow; Utter has no account step.
        let hosting = NSHostingView(rootView: ThemedRoot {
            OnboardingView(onFinish: { [weak self] skipped in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.applyDockVisibility()
                guard !skipped else { return }
                self?.requestAccessibilityPermission()
                self?.requestMicrophonePermission()
            })
        })
        // Never let the hosting view size the window. `OnboardingView` is flexible
        // now - it has to be, to resize - and an NSHostingView that publishes an
        // intrinsic size drives the window's dimensions instead of the reverse,
        // which is the collapse documented in `showMainWindow`.
        if #available(macOS 13.0, *) { hosting.sizingOptions = [] }
        hosting.autoresizingMask = [.width, .height]
        // Its own view supplies the glass background so the material and the warm
        // veil match the main window exactly.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: Layout.onboardingIdealWidth,
                                height: Layout.onboardingIdealHeight),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Translucent surfaces need the desktop behind them to sample.
        window.isOpaque = false
        window.backgroundColor = .clear
        // Opt out of macOS window restoration, for the reason `showMainWindow`
        // gives: it keeps its own copy of the geometry and re-creates the window
        // from it, which now that this window is resizable would override the size
        // set here. A comment claimed this was already the case; it wasn't.
        window.isRestorable = false
        window.contentView = hosting
        // Resizable with a floor, rather than the previous fixed 620x600: the
        // tallest step still fits at this height, and below it the step content
        // scrolls (see the GeometryReader in `OnboardingView`) instead of pushing
        // the nav row off the bottom edge. No frame autosave - this window is shown
        // once, on first run, so there is no size worth remembering and no chance
        // for a stale tiny frame to greet a new user.
        window.contentMinSize = NSSize(width: Layout.onboardingMinWidth,
                                       height: Layout.onboardingMinHeight)
        window.center()
        window.isReleasedWhenClosed = false
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
        // about that window at quit time, but everything already transcribed is in
        // the note and the flush below persists it.
        // Notes save on a 1s debounce, so a quit within that window would drop the
        // last edit. Queue the latest snapshot and wait for the serial writer to drain.
        NoteStore.shared.writeToDisk()
        NoteStore.shared.flushPendingWrites()
        TranscriptionHistory.shared.flushPendingWrites()
        UserData.shared.flushNow()
    }

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

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Utter v\(ConfigManager.shared.appVersion)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let hintItem = NSMenuItem(
            title: "Hold \(UserData.shared.hotkeyName) to dictate",
            action: nil, keyEquivalent: ""
        )
        hintItem.isEnabled = false
        hintItem.tag = MenuHintTag.hotkey
        menu.addItem(hintItem)

        // Hands-free, spelled whichever way will actually fire - see
        // `handsFreeHintTitle`. Both spellings name the hotkey or the chord from the
        // values `KeyMonitor` matches on, so this line cannot get out of step with it.
        let handsFreeHint = NSMenuItem(title: handsFreeHintTitle, action: nil, keyEquivalent: "")
        handsFreeHint.isEnabled = false
        handsFreeHint.tag = MenuHintTag.handsFree
        menu.addItem(handsFreeHint)

        // Note capture is a chord, not a held key, so nothing on screen reveals it.
        // The chord is read from `KeyChord`, the same value `KeyMonitor` matches on,
        // so this line cannot advertise a shortcut that no longer fires.
        let noteHint = NSMenuItem(
            title: "\(KeyChord.noteCapture.symbols) to dictate into a note",
            action: nil, keyEquivalent: ""
        )
        noteHint.isEnabled = false
        menu.addItem(noteHint)

        let memoryHint = NSMenuItem(
            title: "\(KeyChord.memoryCapture.symbols) to remember something",
            action: nil, keyEquivalent: ""
        )
        memoryHint.isEnabled = false
        menu.addItem(memoryHint)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Utter", action: #selector(showMainWindowAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Show Pill", action: #selector(showPill), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Settings\u{2026}", action: #selector(showSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        // Setup, reachable again. Onboarding is where microphone, Accessibility, Screen
        // Recording and the model choice are all explained in one place, and it was
        // presented exactly once, on first launch - a user who pressed Skip, or who
        // denied a permission and wanted the walkthrough back, had no route to it short
        // of deleting a UserDefaults key. Every other window in this menu is reopenable;
        // this was the one that was not.
        menu.addItem(NSMenuItem(title: "Setup\u{2026}", action: #selector(showSetup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "What\u{2019}s New in Utter", action: #selector(showWhatsNew), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Report an Issue / Feedback\u{2026}", action: #selector(showReportIssue), keyEquivalent: "i"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Utter", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
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

    private func makeSidebarToolbar(identifier: NSToolbar.Identifier) -> NSToolbar {
        let toolbar = NSToolbar(identifier: identifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        return toolbar
    }

    @objc func showMainWindowAction() { showMainWindow() }

    func showMainWindow() {
        if let w = mainWindow {
            w.makeKeyAndOrderFront(nil)
            // Activation alone, no policy change: see `applyDockVisibility`.
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // The window's chrome is AppKit's, not SwiftUI's.
        //
        //     NSWindow  .titled + .fullSizeContentView, NSToolbar attached
        //       └─ NSSplitViewController
        //            ├─ NSSplitViewItem.sidebar(with: NSHostingController(FlowSidebar))
        //            └─ NSSplitViewItem(viewController: NSHostingController(FlowContent))
        //
        // It used to be one `NSHostingController(rootView: FlowMainView)`, and `FlowMainView` was an
        // `HStack { sidebar; content }` with a hand-written `glassEffect` on the sidebar column and
        // 30pt of padding standing in for a titlebar. The reason for the change is that macOS only
        // attaches automatic Liquid Glass, automatic scroll-edge treatment and automatic
        // accessibility adaptation to chrome *structures* - a titlebar, an `NSToolbar`, an
        // `NSSplitViewItem` sidebar - and an `HStack` is not one, so that layout could not inherit
        // any of it however the glass was applied inside it. `FlowMainView.swift`'s file note
        // carries the full before/after and the probe measurements; the AppKit half is here.
        //
        // Three things had to be true for this to be safe, and each was measured offscreen against
        // exactly this structure on macOS 26.5 rather than assumed:
        //
        //   1. Nothing publishes a size. `sizingOptions = []` on both hosting controllers leaves
        //      `intrinsicContentSize` at (-1, -1), `fittingSize` at (0, 0) and `preferredContentSize`
        //      at (0, 0) for both, and the window held 1180x820 through a 1.2s runloop. That is the
        //      ~133x142 collapse this method has a re-assert loop for: an `NSHostingView` publishing
        //      its SwiftUI content's intrinsic size up through the content-view relationship, which
        //      no `contentMinSize`, `minSize`, constraint or `windowWillResize` veto could reject
        //      because it does not arrive as a resize request. Two hosting views now instead of one,
        //      so both are muzzled. The loop below stays regardless - the collapse was intermittent
        //      (2 of 5 launches) and a measurement is not a guarantee.
        //   2. The sidebar cannot vanish. `minimumThickness == maximumThickness == 168` held exactly
        //      at 1180, 1000 and 640pt wide, and `canCollapseFromWindowResize = false` kept
        //      `isCollapsed` false at 640x480 - below the window's own minimum. Without that a narrow
        //      window would auto-collapse the sidebar, and this app has no toggle to bring it back.
        //   3. The toolbar does not cross the sidebar. This was the recorded objection to ever adding
        //      one: a toolbar spans the window and would land on the wordmark. It does not. The
        //      titlebar comes back as *two* sections - `NSTitlebarBackgroundView` at
        //      (0, 0, 1180, 66) for the content pane and a second one at (0, 0, 176, 66) inside the
        //      sidebar's own wrapper, with the sidebar's glass drawn over it - because a `.sidebar`
        //      split item on a `.fullSizeContentView` window gets `allowsFullHeightLayout` for free.
        //      The wordmark lands at y=74 and the close button ends at y=33. (Rects here and below
        //      are top-down window points, converted from AppKit's bottom-left origin.)
        let sidebarController = NSHostingController(rootView: FlowSidebar())
        sidebarController.sizingOptions = []
        let contentController = NSHostingController(rootView: FlowContent())
        contentController.sizingOptions = []

        // `sidebar(with:)` is what buys the material: per its header it gives the item a
        // "translucent material background", which on macOS 26 is a real
        // `NSContainerConcentricGlassEffectView` wrapped around the hosting view - Liquid Glass that
        // is concentric with the window's corner radius, which a `glassEffect(_:in: Rectangle())`
        // cannot be. Whether it *also* substitutes for itself under Reduce Transparency is the
        // documented promise for standard components and is **not verified here** - no way to check
        // it without the accessibility switch and a screen - so `FlowSidebar` keeps drawing its own
        // opaque fill on that path rather than trusting it.
        //
        // `FlowSidebar`'s rows are a `List(selection:).listStyle(.sidebar)` inside this, i.e. an
        // `NSTableView` inside the glass wrapper, which is where the rows' hover, selection, focus
        // ring and keyboard traversal come from. The one thing that arrangement needs from the
        // SwiftUI side is `.scrollContentBackground(.hidden)`: a list would otherwise draw its own
        // `.sidebar` material *inside* the material this item already supplies.
        //
        // Let AppKit size, collapse, and restore the sidebar through the standard toolbar control.
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 150
        sidebarItem.maximumThickness = 260
        sidebarItem.preferredThicknessFraction = 0.16
        sidebarItem.canCollapse = true
        // Setting `canCollapse` resets this, per the header, so it has to come second.
        sidebarItem.canCollapseFromWindowResize = true

        let contentItem = NSSplitViewItem(viewController: contentController)
        if #available(macOS 26.0, *) {
            // The one line that makes content run *under* the sidebar, which was structurally
            // impossible with the `HStack` and is why nothing in this window could refract app
            // content - the glass had only the desktop to sample. Its header: "other items such as
            // sidebars or inspectors may appear overlaid on top of this item's viewController and
            // this item's safeAreaInsets will be adjusted with respect to overlaid content."
            //
            // Measured, at 1180x820: on → the content view is (0, 0, 1180, 820) with a 176pt leading
            // safe-area inset. Off → (176, 0, 1004, 820) with no leading inset, i.e. exactly the old
            // `HStack` geometry. `FlowContent` puts its surface behind the safe area and its text
            // inside it, so the plane reaches the window's edges (measured 1180x820) while the first
            // line of text lands at x=200.
            contentItem.automaticallyAdjustsSafeAreaInsets = true
        }

        let splitController = NSSplitViewController()
        splitController.splitView.isVertical = true
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(contentItem)

        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Layout.windowIdealWidth,
                height: Layout.windowIdealHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable,
                        .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Utter"
        // Opt out of macOS window restoration: it writes its own copy of the
        // geometry to ~/Library/Saved Application State/ and re-creates the window
        // from it, overriding everything set here.
        window.isRestorable = false
        // Use standard unified window chrome so title, traffic lights, and toolbar adapt with macOS.
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        // Translucent surfaces need the desktop behind them to sample. Kept: `FlowContent`'s content
        // layer is still a `.behindWindow` `NSVisualEffectView`.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.toolbar = makeSidebarToolbar(identifier: .utterMain)
        window.contentViewController = splitController
        window.setContentSize(NSSize(width: Layout.windowIdealWidth,
                                     height: Layout.windowIdealHeight))
        window.contentMinSize = NSSize(width: Layout.windowMinWidth,
                                       height: Layout.windowMinHeight)
        window.minSize = NSSize(width: Layout.windowMinWidth,
                                height: Layout.windowMinHeight)
        // Restore any frame the user has chosen, then start autosaving. Order
        // matters: `setFrameAutosaveName` *writes* the current frame when no
        // stored one exists, so registering first would persist the default.
        //
        // The name carries a size suffix (`.1380x960`) so that enlarging the default *takes
        // effect*. `setFrameUsingName` restores the last saved frame, and every prior build wrote
        // the old 1180x820 - so without changing the key, the bigger default would be shadowed by
        // the stored small frame on every machine that ran an older build, and only a truly fresh
        // install would ever see it. Bumping the key once abandons that stale frame; the user's
        // own later resizes are saved under the new key and respected as before. Bump the suffix
        // again if the default size changes again.
        let mainFrameName = "UtterMain.1380x960"
        if !window.setFrameUsingName(mainFrameName) {
            window.center()
        }
        window.setFrameAutosaveName(mainFrameName)
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        // Re-assert the size across the first few runloop turns.
        //
        // The collapse is a race: measured 2 of 5 launches on Dictation and 3 of 3
        // on Scratchpad, the window shrinks to ~133x142 shortly after being shown.
        // Everything tried to prevent SwiftUI publishing that size failed
        // (sizingOptions, root .frame, constraints, contentViewController,
        // windowWillResize), because the size is applied through the content-view
        // relationship rather than a resize request.
        //
        // So instead of preventing it, this corrects it: if the frame is below the
        // designed minimum on any of the next few turns, restore it. The user's own
        // resizes are untouched, because anything at or above the minimum is left
        // alone.
        // Capture the INTENDED size, not the current one.
        //
        // Reading `window.frame` here was subtly wrong: on a fresh install the
        // collapse happens before this line runs, so it captured the *collapsed*
        // frame and every later correction faithfully restored 133x117. The size
        // the window is supposed to be is known independently, so use that.
        // Validate window dimensions on the next runloop turn.
        let intended = NSSize(width: Layout.windowIdealWidth,
                              height: Layout.windowIdealHeight)
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

        // Activation alone, no policy change: see `applyDockVisibility`.
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    @MainActor
    func showCompanion(section: CompanionSection) {
        SidebarSelection.shared.item = .companion
        CompanionSectionSelection.shared.section = section
        showMainWindow()
    }

    @objc private func showPill() {
        // Explicitly asking for the pill also turns the preference back on  - 
        // otherwise the menu item would appear to do nothing.
        if !UserData.shared.alwaysShowPill {
            UserData.shared.alwaysShowPill = true
            UserData.shared.save()
        }
        pillWindow.orderFront(nil)
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

    /// Whether any window that takes focus is on screen.
    ///
    /// The pill and the companion are deliberately absent: both are
    /// `.nonactivatingPanel`s, so they never hold focus and there is nothing for a
    /// policy change to disturb. Settings and What's New used to be absent too, which
    /// is how closing either one could leave the app `.regular` with the preference
    /// off - nothing reasserted it afterwards.
    private var isAnyWindowVisible: Bool {
        [mainWindow, onboardingWindow, settingsWindow, whatsNewWindow, reportIssueWindow]
            .contains { $0?.isVisible == true }
    }

    /// Keep the pill on screen, or hide it until dictation starts.
    private func applyPillVisibility() {
        guard let pill = pillWindow else { return }
        if UserData.shared.alwaysShowPill {
            if !pill.isVisible { pill.orderFront(nil) }
        } else if pill.isVisible, !pill.currentState.isRecordingLike {
            // Never yank it away mid-recording - that's the one moment it is
            // carrying live information.
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
            // And take the engine off the pill, which is what stops the note card drawing a
            // character: with this nil the card lays out exactly as it did before the
            // companion could appear in it.
            pillWindow?.stateModel.companionBehaviour = nil
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
            let companion = CompanionWindow(pill: pill) { [weak self] in
                self?.showSettingsWindow()
            }
            companionWindow = companion
            // Scan for installed packs the first time the companion appears, so a
            // pack the user added is available without a relaunch.
            SpritePackStore.shared.reload()
            // Only now is it known what is installed, so this is the first moment a
            // selection naming a pack that is gone can be corrected and written back.
            UserData.shared.resolveCompanionCharacter(
                against: SpritePackStore.shared.packs.map(\.id)
            )
        }

        // Wire (or re-wire) the signals every time the companion is enabled. The
        // window survives a disable, so a second enable would otherwise find a live
        // panel with a cancelled subscription and a character that never reacts.
        if companionStateObserver == nil {
            wireCompanionSignals()
        }

        // Hand the pill the live engine, so the note card can draw the character itself
        // while it is open and this panel steps aside for the duration. The *same*
        // instance, deliberately - that is what carries mood, pose and frame timing across
        // the handover instead of restarting them. Set every time, not just on creation: a
        // disable clears it.
        pill.stateModel.companionBehaviour = companionWindow?.behaviour

        // The companion is an independent window with its own saved position, so this
        // is the whole of its visibility: on screen while the preference is on. It used
        // to be a child window of the pill, which meant AppKit ordered it in and out
        // with the pill and the character came and went with each dictation turn when
        // "always show the pill" was off - the companion has its own toggle, and that
        // is the one it should follow.
        //
        // It declines to appear at all if the selection resolves to no installed pack,
        // and nothing here configures the character beyond that: a pack carries its own
        // per-frame timing (`CompanionAnimation.delays`), which is why APNG is the
        // recommended format, and the behaviour engine needs nothing from the choice.
        companionWindow?.show()
    }

    /// Feed the companion the two real signals it reacts to: dictation state and
    /// microphone level.
    ///
    /// The state arrives by observing the pill's published state rather than by
    /// calling the companion from each `setState` site. There are more than twenty of
    /// those, and the same reasoning `PillWindow.setState` gives for its hide-on-idle
    /// rule applies here: a new exit path must not be able to leave the character
    /// stuck mid-thought.
    ///
    /// The level is *pulled* instead, once per animation frame - see
    /// `CompanionBehaviour.levelSource`. `PillStateModel.level` is already the
    /// smoothed signal the pill's meter draws, so the character bounces to the same
    /// real audio the pill does, never to a timer.
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
            return self.audioRecorder.isRecording || self.meetingSession.state != .idle
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
        if let why = MeetingSession.prepare() {
            reportOfferFailure(why)
            return
        }

        // Read before the hop: the call can end while the task is suspended, and the note's title and
        // the capture's target both come from this.
        let source = callDetector.currentCall
        Task { @MainActor in
            guard let id = await meetingSession.start(recorder: audioRecorder,
                                                     transcriber: transcriptionService,
                                                     source: source) else {
                // The session already named the reason (microphone busy, system audio refused);
                // "Could not start the meeting recording" threw it away.
                if case .failed(let why) = meetingSession.state {
                    reportOfferFailure(why)
                } else {
                    reportOfferFailure("Couldn\u{2019}t start the meeting recording.")
                }
                return
            }
            NoteStore.shared.selectedNoteID = id
            dismissMeetingOffer()

            // Recording a call captures other people's voices, so the running state has to be
            // obvious for the whole of it - `NotesView.meetingBar` states that invariant, and it is
            // the app's one recording banner: a red dot, the elapsed time, a Stop button, and the
            // warning that nothing has been heard from the other side yet. Opening the screen it
            // lives on reuses all of that; a new persistent `PillState` would be a second indicator
            // to keep in step, in the state machine this panel exists to stay out of.
            //
            // It costs an activation, which pulls focus from the call for a moment. That is the
            // deliberate trade: the alternative is recording other people with nothing on screen
            // saying so.
            WorkspaceSectionSelection.shared.library = .notes
            SidebarSelection.shared.item = .library
            showMainWindow()

            // And a transient confirmation on the pill, which has to be brought up first: with
            // "show at all times" off, `setState(.idle)` has already ordered it out and `.notice`
            // does not bring it back, so both the success and the failure were invisible. Same
            // reasoning as `startRecording` - this is exactly when its feedback matters.
            if !pillWindow.isVisible { pillWindow.orderFront(nil) }
            showPillNotice("Recording the meeting")
        }
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
        if !pillWindow.isVisible { pillWindow.orderFront(nil) }
        showPillError("Couldn\u{2019}t start the meeting recording")
    }

    @MainActor
    private func wireCompanionSignals() {
        guard let companion = companionWindow, let pill = pillWindow else { return }

        companion.behaviour.levelSource = { [weak pill] in pill?.stateModel.level ?? 0 }

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
                    // The note card draws the character itself while it is open, so the
                    // panel steps aside - and comes back however the turn ends, which is
                    // why this rides the same single observation the mood does rather than
                    // the twenty-odd `setState` sites. Idempotent: it orders a window out
                    // or in and touches no frame.
                    companion.applyCardHandover()
                }
            }
    }

    private var companionStateObserver: AnyCancellable?

    private var prefsObserver: AnyCancellable?
    @objc private func quit() { NSApp.terminate(nil) }

    private var settingsWindow: NSWindow?

    /// Autosave key for the Settings window's frame. Distinct from the main
    /// window's "UtterMain" - AppKit refuses a duplicate autosave name and then
    /// silently stops remembering either window's geometry.
    /// Suffixed with the size so enlarging the default is not shadowed by a frame saved at the
    /// old size - see the note on the main window's autosave name.
    private static let settingsFrameName = "UtterSettings.864x600"

    /// Open Settings in its own window.
    ///
    /// Settings used to be a page inside the main window's sidebar. It is a
    /// different *kind* of thing from the feature screens - you visit it, change
    /// something, and leave - so it gets its own window, which is also what the
    /// reference design does and what Cmd-, already implies on macOS.
    @objc func showSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // The same structure as `showMainWindow`, for the same reason - this was the same shape of
        // window carrying the same hand-written substitutes:
        //
        //     NSWindow  .titled + .fullSizeContentView, NSToolbar attached
        //       └─ NSSplitViewController
        //            ├─ NSSplitViewItem.sidebar(with: NSHostingController(SettingsSidebar))
        //            └─ NSSplitViewItem(viewController: NSHostingController(SettingsDetail))
        //
        // It used to be one `NSHostingView(rootView: ThemedRoot { SettingsWindowView() })` whose
        // root was an `HStack { groupList; 1pt rule; detail }`, with `flushChromeGlass` on the
        // column and `Layout.toolbarBand + Space.x3` of padding in both panes standing in for a
        // titlebar. macOS only attaches automatic Liquid Glass, automatic scroll-edge treatment and
        // automatic accessibility adaptation to chrome *structures*, and an `HStack` is not one.
        // `SettingsWindowView.swift`'s file note carries the full before/after table and the probe
        // measurements; the AppKit half is here. Everything below was measured offscreen against
        // exactly this structure on macOS 26.6.1 at the 720x500 opening size, never on a window
        // ordered front.
        //
        // `sizingOptions = []` on both controllers: `NSHostingView.sizingOptions` defaults to
        // `.standardBounds`, which includes `intrinsicContentSize`, and that is the ~133x142
        // collapse `showMainWindow` carries a re-assert loop for - a size applied through the
        // content-view relationship rather than as a resize request, which no `contentMinSize` or
        // `windowWillResize` veto can refuse. Measured here: `intrinsicContentSize` (-1, -1),
        // `fittingSize` (0, 0) and `preferredContentSize` (0, 0) on both, and the window held
        // 720x500 across a 1.2s runloop. Two hosting views instead of one, so both are muzzled.
        // Settings has never carried the loop and one is not added here - the collapse was only
        // ever observed with the hosting view as the window's own `contentView`, which is what this
        // change moves away from - but the failure was intermittent (2 of 5 launches), so if it
        // ever appears in this window the fix is the loop in `showMainWindow`, verbatim.
        let sidebarController = NSHostingController(rootView: SettingsSidebar())
        sidebarController.sizingOptions = []
        let detailController = NSHostingController(rootView: SettingsDetail())
        detailController.sizingOptions = []

        // `sidebar(with:)` is what buys the material: per its header it gives the item a
        // "translucent material background", which on macOS 26 is a real
        // `NSContainerConcentricGlassEffectView` wrapped around the hosting view - Liquid Glass
        // concentric with the window's corner radius, which a `glassEffect(_:in: Rectangle())`
        // cannot be. Measured at x 8-160, y 8-492, with the SwiftUI content as its *subview*, so
        // the rows' white selection lift still composites on top of the material.
        //
        // Let AppKit size, collapse, and restore the sidebar through the standard toolbar control.
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 145
        sidebarItem.maximumThickness = 230
        sidebarItem.preferredThicknessFraction = 0.22
        sidebarItem.canCollapse = true
        // Setting `canCollapse` resets this, per the header, so it has to come second.
        sidebarItem.canCollapseFromWindowResize = true

        let detailItem = NSSplitViewItem(viewController: detailController)
        if #available(macOS 26.0, *) {
            // The one line that makes the detail pane run *under* the group list, which was
            // structurally impossible with the `HStack` and is why nothing in this window could
            // refract app content - the glass had only the desktop to sample. Measured, at
            // 720x500: on → the detail view is (0, 0, 720, 500) with a 160pt leading safe-area
            // inset (152pt column plus the glass's 8pt outset). Off → (160, 0, 560, 500) with no
            // leading inset, i.e. exactly the old `HStack` geometry.
            detailItem.automaticallyAdjustsSafeAreaInsets = true
        }

        let splitController = NSSplitViewController()
        splitController.splitView.isVertical = true
        splitController.addSplitViewItem(sidebarItem)
        splitController.addSplitViewItem(detailItem)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: Layout.settingsIdealWidth,
                                height: Layout.settingsIdealHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        // Use standard unified window chrome so title, traffic lights, and toolbar adapt with macOS.
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isRestorable = false
        window.isMovableByWindowBackground = true
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.toolbar = makeSidebarToolbar(identifier: .utterSettingsWindow)
        window.contentViewController = splitController
        window.setContentSize(NSSize(width: Layout.settingsIdealWidth,
                                     height: Layout.settingsIdealHeight))
        // A floor the two-pane layout survives with either sidebar width.
        window.contentMinSize = NSSize(width: Layout.settingsMinWidth,
                                       height: Layout.settingsMinHeight)
        // Remember the size the user picks, and refuse to reopen at a size they
        // cannot work in: `setFrameUsingName` replays the stored frame verbatim and
        // never consults `contentMinSize`, so a frame saved while the window was
        // collapsed would come back collapsed. Register the autosave name *after*
        // restoring - registering writes the current frame when nothing is stored
        // yet, the same ordering `showMainWindow` depends on.
        if window.setFrameUsingName(Self.settingsFrameName) {
            window.setContentSize(Layout.size(
                window.contentRect(forFrameRect: window.frame).size,
                atLeast: window.contentMinSize
            ))
            // And on screen: a frame stored on a display that is no longer attached
            // reopens where the window cannot be reached to move it.
            // `showMainWindow` guards the same way.
            if let screen = window.screen ?? NSScreen.main,
               !screen.visibleFrame.intersects(window.frame) {
                window.center()
            }
        } else {
            window.center()
        }
        window.setFrameAutosaveName(Self.settingsFrameName)
        window.isReleasedWhenClosed = false
        // Only for `windowWillClose`, so the Dock preference is reasserted once this
        // window is gone. `windowShouldClose` deliberately excludes it - this is an
        // ordinary closable window, unlike the main one.
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

    /// The hint line names the user's configured hotkey, so it must be rebuilt
    /// when that changes rather than hardcoding "Fn".
    /// Tags for the hint items the hotkey preference rewrites. Tagged rather than found
    /// by index - this used `menu.items[1]`, which silently retitles the wrong row the
    /// first time an item is inserted above it, and there are two of them now.
    private enum MenuHintTag {
        static let hotkey = 1001
        static let handsFree = 1002
    }

    /// The hands-free spelling that will actually fire: hold-then-tap when `KeyMonitor`
    /// has an event tap to swallow the tapped key, the chord otherwise. Same test
    /// Settings applies, so the menu and the card never disagree.
    private var handsFreeHintTitle: String {
        if HoldTap.isAvailable, let holdTap = HoldTap.binding(for: .handsFree) {
            return "Hold \(UserData.shared.hotkeyName), tap \(holdTap.keyLabel) for hands-free"
        }
        return "\(KeyChord.handsFree.symbols) for hands-free"
    }

    private func refreshMenuHint() {
        guard let menu = statusItem?.menu else { return }
        menu.item(withTag: MenuHintTag.hotkey)?.title = "Hold \(UserData.shared.hotkeyName) to dictate"
        // `.hotkeyChanged` also fires the moment Accessibility is granted (see
        // `ReadinessMonitor`), which is exactly when hold-then-tap becomes available  - 
        // so this line has to be re-read here too, not only on a hotkey change.
        menu.item(withTag: MenuHintTag.handsFree)?.title = handsFreeHintTitle
    }

    /// Replay onboarding from the status menu.
    @objc private func showSetup() { showOnboarding() }

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

    private var isProcessing = false
    private var isHandsFree = false

    /// When true, the finished transcript goes into a Utter note instead of being
    /// typed into the frontmost app.
    ///
    /// Two things set it, and they differ in lifetime:
    ///
    ///   * **⌃⌥N** sets it for the turn it starts, so an ordinary hotkey press
    ///     afterwards still types where the user expects.
    ///   * **"start a new note" / "continue the note"** *arm* it for the turn that
    ///     follows, because the spoken phrase is the command and what comes next is
    ///     the content. That arming has to outlive the turn it was spoken in, so
    ///     `routeNextDictation` is called *after* `finishTurn()` - see the voice
    ///     command branch in `stopRecording`.
    ///
    /// Cleared via `finishTurn()` rather than at each of the six places a turn can
    /// end - the same reasoning `PillWindow.setState` uses for its hide-on-idle
    /// rule: a new exit path must not be able to leave the flag stuck on, or every
    /// later dictation would silently land in a note.
    private var captureToNote = false
    /// When true, the finished transcript becomes a private companion memory.
    private var captureToMemory = false

    private var recordingPillState: PillState {
        if captureToNote { return .capturingNote }
        if captureToMemory { return .capturingMemory }
        return isHandsFree ? .handsFree : .recording
    }

    /// Reset per-turn state. Call from every path that ends a dictation turn,
    /// success or failure.
    private func finishTurn() {
        isProcessing = false
        captureToNote = false
        captureToMemory = false
        SurroundingContext.clearPrewarmed()
    }

    private func startRecording(vad: Bool = false) {
        guard !isProcessing else { return }
        // A meeting owns the microphone tap. Without this the dictation path would
        // call `startRecording` (a silent no-op while the tap is live) and then, on
        // release, `stopRecording` would hand back the ENTIRE meeting so far and
        // type it into the frontmost app - while tearing down the engine the
        // meeting was still recording through.
        guard !meetingIsRecording else {
            showPillError("Recording a meeting - stop it first")
            return
        }
        // Something is already recording through this tap, so there is nothing to start.
        //
        // `KeyMonitor` delivers `onRecordStart` on every hotkey press regardless of state  - 
        // `suppressReleaseStop` only suppresses the *release* - so brushing the dictation
        // hotkey during a latched hands-free session or a note capture ran this whole path:
        // `audioRecorder.startRecording` returns false while its engine is already up, so the
        // user got "Couldn't start the microphone" over a capture that was in fact recording
        // fine, with the elapsed timer, level meter and live preview all torn down for the
        // rest of it. Deliberately *after* the meeting guard, which owns the same recorder and
        // has a more specific thing to say about it.
        guard !audioRecorder.isRecording else { return }
        // If the pill is hidden ("show at all times" off), bring it up for the
        // duration of the turn - this is exactly when its feedback matters.
        if !pillWindow.isVisible { pillWindow.orderFront(nil) }
        Signposts.beginKeyDownToPill()

        // First, and applied at once: everything after this is work the first frame must not wait on.
        pillWindow.setState(recordingPillState)
        SurroundingContext.prewarm()

        // Pause other audio so music doesn't bleed into the microphone.
        MediaControl.pauseIfPlaying()

        // Rebuild the speech context now, if the 5-minute idle eviction released it, so the
        // transcription that is about to happen does not pay for it.
        //
        // This is latency moved, not latency removed, and the move is the whole value: the user
        // is about to speak for a couple of seconds, and the rebuild runs on the whisper queue
        // during that time. The inference is queued behind it on the same serial queue, so it
        // finds a warm context and no lock is needed.
        //
        // Measured on this machine against the shipped 190 MB model: **78-93 ms** to rebuild
        // in-process after a `whisper_free` with the file still in the page cache, and
        // **7,686 ms** for a first load with a cold one. Eviction is deliberately aggressive and
        // a menu-bar app can sit idle for hours, so a long-idle rebuild is somewhere on that
        // range rather than reliably at the low end - and the user cannot tell in advance which
        // turn will be the slow one. This removes the variance, which is the part that is felt.
        //
        // Non-blocking, and deliberately silent: nothing about the engine's *capability* changed
        // while it was unloaded, so it publishes no `loadState`. See `LocalWhisperProvider.warmUp`.
        //
        // Hopped to the main actor because `warmUp` reads the active tier from `ModelStore`, which
        // lives there, and `startRecording` is nonisolated - the same reason the tier-change preload
        // at `observeModelTier` is wrapped. One runloop turn of delay is irrelevant here: what this
        // has to beat is the user finishing their sentence, not the next frame.
        Task { @MainActor in self.transcriptionService.warmUp() }

        if !modelReady {
            // Recording is safe - audio capture doesn't need the model. The clip
            // will transcribe as soon as the load finishes, so capture it rather
            // than dropping what the user said.
            print("⏳ Recording while the speech model finishes loading")
        }

        // Before the mic opens, so the chime stays out of the recording.
        SoundPlayer.playStart()
        startPillTelemetry()
        openMicrophone(vad: vad)
    }

    /// Open the mic off main; a failed start rolls back the turn the caller set up.
    private func openMicrophone(vad: Bool) {
        let onVoiceStopped: (() -> Void)? = vad
            ? { [weak self] in self?.handsFreeFinalize(reason: "VAD silence") }
            : nil
        audioRecorder.open(onVoiceStopped: onVoiceStopped) { [weak self] started in
            guard let self, !started else { return }
            if self.isHandsFree {
                self.isHandsFree = false
                self.keyMonitor.suppressReleaseStop = false
                self.captureToNote = false
                self.captureToMemory = false
            }
            self.stopPillTelemetry()
            MediaControl.resumeIfPaused()
            self.showPillError("Couldn\u{2019}t start the microphone")
        }
    }

    /// Whether meeting capture currently owns the microphone.
    ///
    /// Read through the delegate's lazy session without creating it: touching
    /// `meetingSession` would instantiate it on the first hotkey press, which is
    /// wasteful but harmless - the guard is about the *state*, so a session that
    /// does not exist yet is by definition not recording.
    /// Whether a meeting still owns the shared recorder.
    ///
    /// `.finishing` counts. `MeetingSession.stop()` closes the tap, then awaits the tail
    /// inference for seconds before calling `recorder?.consume(micConsumed)` and releasing
    /// the recorder. A dictation started inside that window has its own opening seconds
    /// deleted by that `consume` - up to a 30s window of bytes - and the user is never told.
    private var meetingIsRecording: Bool {
        MainActor.assumeIsolated {
            meetingSession.state == .recording || meetingSession.state == .finishing
        }
    }

    /// Toggle hands-free mode. Triggered by Control+Option+Space from any state.
    ///
    /// State machine:
    ///   - idle              → start a fresh hands-free recording
    ///   - push-to-talk      → upgrade in-flight recording to hands-free, ignore hotkey release
    ///   - hands-free        → finalize and transcribe
    /// ⌃⌥N: dictate into a Utter note rather than the frontmost app.
    ///
    /// Runs the same recording machinery as hands-free - the only difference is
    /// `captureToNote`, which redirects the finished text at the end of the
    /// pipeline. Deliberately hands-free rather than push-to-talk: notes tend to
    /// be longer than a sentence typed into a field, and holding a chord for a
    /// paragraph is uncomfortable.
    private func toggleNoteCapture() {
        // Already capturing → finish and file the note.
        if isHandsFree, captureToNote {
            print("📝 Note capture: manual stop")
            isHandsFree = false
            keyMonitor.suppressReleaseStop = false
            stopRecording()
            return
        }

        guard !isProcessing else {
            print("⚠️ Note capture ignored: still processing previous transcription")
            return
        }

        guard !meetingIsRecording else {
            showPillError("Recording a meeting - stop it first")
            return
        }

        // A plain hands-free session is already running: redirect it rather than
        // refusing, so the user can decide mid-thought that this belongs in a note.
        if isHandsFree {
            captureToNote = true
            captureToMemory = false
            pillWindow.setState(.capturingNote)
            // The card is about to appear over a recording that started without a preview.
            startLivePreviewIfNeeded()
            print("📝 Note capture: redirecting active hands-free session")
            return
        }

        captureToNote = true
        captureToMemory = false

        // Same reasoning as `toggleHandsFree`: ask the recorder whether a tap is
        // open rather than reading it off the pill's state.
        if audioRecorder.isRecording {
            print("📝 Note capture: upgrading active push-to-talk recording")
            isHandsFree = true
            keyMonitor.suppressReleaseStop = true
            pillWindow.setState(.capturingNote)
            startLivePreviewIfNeeded()
            installHandsFreeVAD()
            return
        }

        isHandsFree = true
        keyMonitor.suppressReleaseStop = true
        startRecording(vad: true)
        // `startRecording` reports failure through the pill, so treat "not
        // recording" as the signal to unwind rather than duplicating its checks.
        guard audioRecorder.isRecording else {
            isHandsFree = false
            keyMonitor.suppressReleaseStop = false
            captureToNote = false
            return
        }
    }

    /// Toggle voice capture into the companion's private memory store.
    ///
    /// This uses the same recorder and transcription service as dictation, but it
    /// never injects text into another app and never enters transcription history.
    func toggleMemoryCapture() {
        if isHandsFree, captureToMemory {
            print("🧠 Memory capture: manual stop")
            isHandsFree = false
            keyMonitor.suppressReleaseStop = false
            stopRecording()
            return
        }

        guard !isProcessing else {
            print("⚠️ Memory capture ignored: still processing previous transcription")
            return
        }
        guard !meetingIsRecording else {
            showPillError("Recording a meeting - stop it first")
            return
        }

        captureToNote = false
        captureToMemory = true

        if isHandsFree {
            pillWindow.setState(.capturingMemory)
            startLivePreviewIfNeeded()
            return
        }

        if audioRecorder.isRecording {
            isHandsFree = true
            keyMonitor.suppressReleaseStop = true
            pillWindow.setState(.capturingMemory)
            startLivePreviewIfNeeded()
            installHandsFreeVAD()
            return
        }

        isHandsFree = true
        keyMonitor.suppressReleaseStop = true
        startRecording(vad: true)
        guard audioRecorder.isRecording else {
            isHandsFree = false
            keyMonitor.suppressReleaseStop = false
            captureToMemory = false
            return
        }
    }

    /// Point the next dictation at a new or the currently open note.
    ///
    /// Spoken rather than typed, so a long thought can be split into separate notes
    /// without reaching for the keyboard. Arming a mode rather than acting now: the
    /// phrase itself is the command, and what follows it is the content.
    ///
    /// Must be called *after* `finishTurn()`, never before: `finishTurn` clears
    /// `captureToNote`, so arming first and finishing second undid the arming in the
    /// same statement list - the command created an empty note, said "keep talking",
    /// and then the next dictation typed into the frontmost app anyway.
    ///
    /// Leaves the pill in `.notice` and does not return it to `.idle`; the notice
    /// expires on its own. Setting `.idle` after this call would replace the
    /// confirmation before a single frame had been drawn with it.
    @MainActor
    private func routeNextDictation(_ action: VoiceAction) {
        captureToNote = true
        switch action {
        case .startNewNote:
            // An empty note becomes the destination, so the next capture appends to
            // it rather than creating a second one.
            NoteStore.shared.create(body: "", source: .dictated)
            UserData.shared.captureAppendsToOpenNote = true
            showPillNotice("New note - keep talking")
        case .continueNote:
            UserData.shared.captureAppendsToOpenNote = true
            showPillNotice(NoteStore.shared.selectedNote == nil
                            ? "No note open - starting one"
                            : "Adding to the open note")
            if NoteStore.shared.selectedNote == nil {
                NoteStore.shared.create(body: "", source: .dictated)
            }
        default:
            break
        }
        UserData.shared.save()
    }

    /// Run a finished transcript through the correction pipeline and deliver it.
    ///
    /// Extracted so the two callers cannot drift: an ordinary dictation reaches it
    /// after the AI-command pass declines the text, and a note capture reaches it
    /// directly (that pass is skipped - see `stopRecording`). Every correction stage
    /// runs identically either way, so a note never gets second-class text for
    /// having skipped the dictionary or snippet pass; the destination at the end is
    /// the only difference.
    @MainActor
    private func deliverTranscript(_ text: String, elapsed: TimeInterval) {
        // Fix custom-dictionary near-misses (Whisper can't be biased at the
        // endpoint, so we correct its output here).
        let delivery = Signposts.poster.beginInterval("Delivery")
        defer { Signposts.poster.endInterval("Delivery", delivery) }
        var processed = DictionaryCorrector.correct(text, using: UserData.shared.dictionaryWords)
        processed = UserData.shared.applySnippets(to: processed)

        if captureToMemory {
            saveSpokenMemory(processed, elapsed: elapsed)
            return
        } else if captureToNote {
            deliverToNote(processed)
        } else {
            // Context formatting is destination formatting, so it only applies on the path
            // that actually types into the destination. `AppContext.detect()` reads
            // `NSWorkspace.frontmostApplication`, and a note capture never changes that  - 
            // the pill and the note card are both `.nonactivatingPanel`, so whatever the
            // user was looking at stays frontmost. A note dictated with a terminal in front
            // was therefore filed under `.code` rules and had its full stop stripped; with
            // Slack in front it was shortened as a chat message. None of those rules describe
            // a note.
            let context = AppContext.detect()
            processed = AppContext.adjustFormatting(processed, context: context)
            TextInjector.typeText(processed)
        }
        UserData.shared.lastTranscription = processed
        if let celebration = UserData.shared.recordCompanionDictation(
            words: processed.split(whereSeparator: \.isWhitespace).count
        ) {
            companionWindow?.behaviour.celebrateGoal(celebration)
        }
        // Recording the searchable log is opt-out (`keepHistory`, default on). Off
        // → the transcript is typed but never written to `history.json`. The
        // language detection only feeds the history entry, so it is skipped too.
        if UserData.shared.keepHistory {
            let detected = LanguageDetector.detect(processed)
            TranscriptionHistory.shared.add(
                text: processed,
                language: detected?.displayName ?? ""
            )
        }
        print("⚡ Total latency: \(String(format: "%.1f", elapsed))s")
        SoundPlayer.playDone()
        finishTurn()
        pillWindow.setState(.idle)
    }

    @MainActor
    private func saveSpokenMemory(_ text: String, elapsed: TimeInterval) {
        pillWindow.setState(.processing(.rewriting))
        Task {
            do {
                let proposal = try await CompanionMemoryParser.parse(text)
                try await MainActor.run {
                    _ = try CompanionMemoryStore.shared.add(
                        proposal: proposal,
                        source: .spoken
                    )
                    _ = UserData.shared.recordCompanionDictation(
                        words: proposal.text.split(whereSeparator: \.isWhitespace).count
                    )
                    print("🧠 Saved spoken memory in \(String(format: "%.1f", elapsed))s")
                    SoundPlayer.playDone()
                    finishTurn()
                    showPillNotice(
                        proposal.remindAt == nil ? "Remembered" : "Reminder saved"
                    )
                }
            } catch {
                await MainActor.run {
                    SoundPlayer.playError()
                    finishTurn()
                    showPillError(error.localizedDescription)
                }
            }
        }
    }

    /// File a finished transcript into the notes store.
    ///
    /// Appends to the open note when the user asked for that and one is actually
    /// open; otherwise starts a new note so dictation is never silently dropped
    /// for want of a destination.
    ///
    /// The choice itself lives in `NoteCaptureDestination.resolve`, because the pill's
    /// note box has to *name* the destination while the user is still speaking. Deciding
    /// it here and describing it there would be two copies of one rule, and the pill
    /// would eventually name a note the text does not land in.
    @MainActor
    private func deliverToNote(_ text: String) {
        let store = NoteStore.shared
        switch store.captureDestination(
            appendsToOpenNote: UserData.shared.captureAppendsToOpenNote
        ) {
        case .appending(let id, _):
            store.append(text, to: id)
            print("📝 Appended \(text.split(separator: " ").count) words to the open note")
        case .newNote:
            store.create(body: text, source: .dictated)
            print("📝 Created a note from dictation (\(text.split(separator: " ").count) words)")
        }
        // Write through rather than waiting on the debounce: this text exists
        // nowhere else, and the user may quit straight after speaking.
        store.writeToDisk()
    }

    private func toggleHandsFree() {
        // Already hands-free → finalize.
        if isHandsFree {
            print("🔓 Hands-free: manual stop")
            isHandsFree = false
            keyMonitor.suppressReleaseStop = false
            stopRecording()
            return
        }

        // Currently processing a previous transcription → ignore.
        guard !isProcessing else {
            print("⚠️ Hands-free toggle ignored: still processing previous transcription")
            return
        }

        guard !meetingIsRecording else {
            showPillError("Recording a meeting - stop it first")
            return
        }

        // Already recording (push-to-talk) → upgrade to hands-free.
        //
        // Asks the recorder, not the pill: an armed note capture shows
        // `.capturingNote` while push-to-talk records, so a state comparison here
        // missed it and fell through to "start fresh from idle" on top of a live tap.
        if audioRecorder.isRecording {
            print("🔒 Hands-free: upgrading active push-to-talk recording")
            isHandsFree = true
            keyMonitor.suppressReleaseStop = true
            pillWindow.setState(recordingPillState)
            installHandsFreeVAD()
            return
        }

        // Idle → start a fresh hands-free recording.
        print("🔒 Hands-free: starting from idle")
        Signposts.beginKeyDownToPill()
        isHandsFree = true
        keyMonitor.suppressReleaseStop = true
        pillWindow.setState(recordingPillState)
        SoundPlayer.playStart()
        startPillTelemetry()
        openMicrophone(vad: true)
    }

    /// Attach a VAD silence callback to an in-flight recording.
    private func installHandsFreeVAD() {
        audioRecorder.installVoiceStoppedCallback { [weak self] in
            self?.handsFreeFinalize(reason: "VAD silence")
        }
    }

    /// Finalize a hands-free session triggered by VAD or another internal event.
    private func handsFreeFinalize(reason: String) {
        guard isHandsFree else { return }
        print("🔇 Hands-free: \(reason) → finalize")
        isHandsFree = false
        keyMonitor.suppressReleaseStop = false
        stopRecording()
    }

    /// The frontmost app's selection, for an AI command that has matched. Accessibility first, off
    /// main; ⌘C only where that attribute is not exposed.
    @MainActor
    private func readSelection() async -> String {
        let selected = await AXReader.read {
            AXReader.focusedElement().flatMap { AXReader.string($0, kAXSelectedTextAttribute as CFString) }
        }
        if let selected { return selected }
        return await copySelection()
    }

    /// Copy the selection with ⌘C and put the pasteboard back, awaiting rather than sleeping.
    ///
    /// Waits for the count to move *and* a readable string: an app bumps `changeCount` in
    /// `declareTypes` before it writes the data. 80 ms ceiling, for an app with nothing selected.
    @MainActor
    private func copySelection() async -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let changeCountBefore = pasteboard.changeCount

        TextInjector.simulateCopy()

        var selected = ""
        let deadline = ContinuousClock.now + .milliseconds(80)
        while ContinuousClock.now < deadline {
            if pasteboard.changeCount != changeCountBefore,
               let string = pasteboard.string(forType: .string) {
                selected = string
                break
            }
            try? await Task.sleep(for: .milliseconds(2))
        }

        // Cmd+C with no selection leaves the pasteboard untouched.
        guard pasteboard.changeCount != changeCountBefore else { return "" }

        snapshot.restore(to: pasteboard)
        return selected
    }

    private func stopRecording() {
        guard !isProcessing else { return }
        isProcessing = true
        stopPillTelemetry()
        pillWindow.setState(.processing(.transcribing))
        if !captureToNote, !captureToMemory { TextInjector.prepareSnapshot() }
        let sendTime = Date()
        // Media resumes once the mic is closed, before transcription: waiting several seconds
        // for it would feel like the app forgot. The stop chime waits for the close too.
        audioRecorder.stopRecording(onClosed: {
            MediaControl.resumeIfPaused()
            SoundPlayer.playStop()
        }) { [weak self] audioData in
            guard let self = self else { return }
            // No usable audio. `AudioRecorder.stopRecording` reports nil for four different
            // reasons - nothing captured, the trim left under 640 bytes, the WAV encode
            // failed, or it was not recording - and this collapsed all of them to a silent
            // return to idle. With "show at all times" off that also orders the pill away, so
            // a capture that filed nothing into the note looked exactly like one that worked.
            // The empty-transcript branch below already treats this as an error; so does this.
            guard let audioData else {
                SoundPlayer.playError()
                self.finishTurn()
                self.showPillError("No speech detected")
                return
            }
            Task {
                do {
                    let text = try await self.transcriptionService.transcribe(audioData: audioData)
                    let elapsed = Date().timeIntervalSince(sendTime)
                    await MainActor.run {
                        if !text.isEmpty {
                            // Check for voice commands first.
                            //
                            // While dictating into a note, only the *routing* commands
                            // are honoured. The editing ones (`select all`, `copy`,
                            // `new line`…) are keystrokes for the frontmost app's text
                            // field, and the text is not going there - so obeying them
                            // would type into an unrelated document. Nor are they
                            // swallowed as rejected commands: `checkVoiceCommand`
                            // matches on `hasSuffix`, so "the old config is stale so
                            // I'll delete that" *is* the `undo` command by that test
                            // (verified - see `VoiceCommandRoutingTests`), and dropping
                            // it would delete a sentence from the only copy the user
                            // has. Treating them as ordinary text puts them in the
                            // note, which is where the user was speaking.
                            if self.captureToMemory {
                                self.deliverTranscript(text, elapsed: elapsed)
                            } else if let action = UserData.shared.checkVoiceCommand(text),
                               !self.captureToNote || action.isNoteRouting {
                                // Log the matched action, not the spoken text it came from.
                                print("🗣️ Voice command: \(action)")
                                SoundPlayer.playDone()
                                // Finish the turn *first*. `finishTurn` clears
                                // `captureToNote`, and the note-routing commands set
                                // it to arm the *next* dictation - so routing before
                                // finishing wiped the arming one line later and the
                                // commands did nothing at all.
                                self.finishTurn()
                                // Note routing is an app decision, not a keystroke,
                                // so it is handled here rather than in TextInjector.
                                switch action {
                                case .startNewNote, .continueNote:
                                    // No `setState(.idle)`: `routeNextDictation`
                                    // leaves a `.notice` on the pill that expires by
                                    // itself. Both calls hop through
                                    // `DispatchQueue.main.async`, so an `.idle` here
                                    // would be applied in the same runloop drain and
                                    // the confirmation would never be seen.
                                    self.routeNextDictation(action)
                                default:
                                    TextInjector.executeAction(action)
                                    self.pillWindow.setState(.idle)
                                }
                            } else if self.captureToNote {
                                // A note capture skips the AI-command pass entirely.
                                //
                                // `AICommands.process` matches its style patterns with
                                // `hasSuffix`, so a note whose last words happen to be
                                // "…make it shorter" was read as a command - and every
                                // one of its outcomes acts on the *frontmost app*: the
                                // rewrite is pasted there, and because
                                // `sourceWasDictation` is "no selection"
                                // (true during a note capture) it first sent Cmd+Z to
                                // "undo" text it had never typed, corrupting whatever
                                // document happened to be in front. AI actions on note
                                // bodies belong to the note editor, where the user can
                                // see what is being rewritten.
                                self.deliverTranscript(text, elapsed: elapsed)
                            } else {
                                // Check for AI commands (async)
                                Task {
                                    await MainActor.run { self.pillWindow.setState(.processing(.rewriting)) }
                                    var selection: String?
                                    if let result = await AICommands.process(text, selectedText: {
                                        if selection == nil { selection = await self.readSelection() }
                                        return selection ?? ""
                                    }) {
                                        if let aiText = result.text {
                                            // A live selection is still highlighted, so a plain paste
                                            // replaces it; ⌘Z would undo the user's own last edit.
                                            // Undo-then-paste only when the source was our dictation.
                                            let sourceWasDictation = (selection ?? "").isEmpty
                                            if result.replacesSelection && sourceWasDictation {
                                                // Replace our own dictation: undo it, then paste.
                                                await MainActor.run { TextInjector.undoLastTranscription() }
                                                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms for undo to apply
                                            }
                                            await MainActor.run {
                                                self.pillWindow.setState(.processing(.typing))
                                                // Replace (selection still highlighted) or append  - 
                                                // both are a paste at the current cursor/selection.
                                                TextInjector.typeText(aiText)
                                                // Same opt-out as ordinary dictation: an
                                                // AI-rewritten result is history too, so it is
                                                // only logged when the user keeps history.
                                                if UserData.shared.keepHistory {
                                                    TranscriptionHistory.shared.add(text: aiText)
                                                }
                                                print("🤖 AI result: \(aiText.count) chars")
                                                SoundPlayer.playDone()
                                                self.finishTurn()
                                                self.pillWindow.setState(.idle)
                                            }
                                        } else {
                                            // Command failed (e.g. nothing to transform). Surface it  - 
                                            // don't play the success chime and silently return to idle.
                                            await MainActor.run {
                                                if let err = result.error { print("⚠️ AI command: \(err)") }
                                                SoundPlayer.playError()
                                                self.finishTurn()
                                                self.showPillError(result.error ?? "Command failed")
                                            }
                                        }
                                    } else {
                                        // Normal transcription
                                        await MainActor.run {
                                            self.deliverTranscript(text, elapsed: elapsed)
                                        }
                                    }
                                }
                            }
                        } else {
                            SoundPlayer.playError()
                            self.finishTurn()
                            self.showPillError("No speech detected")
                        }
                    }
                } catch {
                    print("Transcription error: \(error)")
                    await MainActor.run {
                        SoundPlayer.playError()
                        self.finishTurn()
                        self.showPillError(Self.pillMessage(for: error))
                    }
                }
            }
        }
    }

    // MARK: - Model load state

    private var loadObserver: AnyCancellable?

    /// Mirror the engine's load state onto the pill, so the first launch reads
    /// "Getting ready" instead of inviting a dictation that would just queue.
    private func observeModelLoad() {
        guard let local = transcriptionService.localProvider else { return }
        loadObserver = local.$loadState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.modelReady = (state == .ready)
                // Share it with the main window's readiness panel.
                Task { @MainActor in ReadinessMonitor.shared.modelLoad = state }
                // Never override an in-flight recording or an error being shown.
                switch self.pillWindow.currentState {
                case .preparing, .idle:
                    break
                default:
                    return
                }
                switch state {
                case .loading, .idle:
                    self.pillWindow.setState(.preparing)
                case .ready:
                    self.pillWindow.setState(.idle)
                case .failed(let reason):
                    self.showPillError(reason)
                }
            }
    }

    /// Whether the engine can transcribe right now.
    private var modelReady = false

    // MARK: - Pill telemetry

    private var elapsedTimer: Timer?
    /// The live-preview polling loop, cancelled when recording stops.
    private var previewTask: Task<Void, Never>?
    private var levelObserver: AnyCancellable?
    private var recordingStart = Date()

    /// Forward the recorder's real level and an elapsed-seconds counter to the pill.
    ///
    /// The hands-free silence countdown used to be forwarded here too, for the amber drain
    /// along the pill's foot. That line is gone (see `PillContent`), so nothing consumes the
    /// progress and the subscription went with it - `AudioRecorder` still measures it and
    /// still auto-stops on it; it is simply no longer drawn.
    private func startPillTelemetry() {
        recordingStart = Date()
        pillWindow.stateModel.elapsed = 0

        levelObserver = audioRecorder.$inputLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in self?.pillWindow.stateModel.level = level }

        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pillWindow.stateModel.elapsed = Int(Date().timeIntervalSince(self.recordingStart))
        }

        startLivePreview()
    }

    private func stopPillTelemetry() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        levelObserver?.cancel()
        levelObserver = nil
        pillWindow.stateModel.level = 0
        stopLivePreview()
    }

    // MARK: - Live preview

    /// Start the live preview for a recording that is already running.
    ///
    /// `startLivePreview` is only ever reached from `startPillTelemetry`, i.e. at the moment
    /// recording begins - and its first guard is `livePreviewEnabled || captureToNote`. Both
    /// note-capture *redirects* arm `captureToNote` on an already-live recording, long after
    /// that guard was evaluated as false, so with the preference off (the default) the note
    /// card sat reading "Listening…" for the whole capture: the one thing the card exists to
    /// show never appeared.
    ///
    /// Guarded on the task rather than calling straight through, because `startLivePreview`
    /// blanks `previewText` and cancels the running task - with the preference *on* a plain
    /// call would throw away a transcript that was already accumulating and re-impose the
    /// 900ms warm-up.
    private func startLivePreviewIfNeeded() {
        guard previewTask == nil else { return }
        startLivePreview()
    }

    private func startLivePreview() {
        // Note capture always previews, whatever the preference says.
        //
        // The note card exists to show the words landing in the note as they are heard
        // - that is the whole reason the pill grows into it. With
        // `livePreviewEnabled` off, which is the default, the card had room for three
        // lines of transcript and drew a message asking the user to switch a setting on.
        // Ordinary dictation keeps honouring the preference: there the preview is a
        // nicety over text that is about to be typed anyway, so paying for inference
        // twice is the user's call. Here it is the feature.
        guard UserData.shared.livePreviewEnabled || captureToNote || captureToMemory else { return }
        guard let local = transcriptionService.localProvider else { return }

        pillWindow.stateModel.previewText = ""
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            // Let a little speech accumulate first: a preview of the first
            // fraction of a second is noise, and would flash a wrong word.
            try? await Task.sleep(nanoseconds: 900_000_000)

            while !Task.isCancelled {
                guard let self else { return }
                // The tail only. An uncapped read re-transcribed the whole utterance from its
                // first byte on every pass, so the work grew as the square of the utterance's
                // length and a single pass eventually took longer than the interval between
                // passes - previews then ran back to back on the serial whisper queue and
                // delayed the final transcript they are supposed to stay out of the way of.
                let snapshot = self.audioRecorder.audioSnapshot(
                    lastBytes: AudioRecorder.previewWindowBytes
                )

                // Below ~0.6s of audio there is not enough signal to transcribe.
                // 16 kHz mono 16-bit = 32,000 bytes per second.
                if snapshot.count >= 19_200 {
                    if let text = await local.previewTranscribe(pcm: snapshot),
                       !Task.isCancelled {
                        await MainActor.run {
                            self.pillWindow.stateModel.previewText = text
                        }
                    }
                }
                // Yield between passes so previews never monopolise the whisper
                // queue that the final transcription needs.
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    private func stopLivePreview() {
        previewTask?.cancel()
        previewTask = nil
        // Abandon in-flight inference too - cancelling the Task alone would leave
        // a started pass running on the whisper queue, delaying the real one.
        transcriptionService.localProvider?.cancelPreviews()
        pillWindow.stateModel.previewText = ""
    }

    /// Show a named failure, then return to idle. An icon with no reason tells
    /// the user something broke without telling them what.
    private func showPillError(_ reason: String) {
        stopPillTelemetry()
        pillWindow.setState(.error(reason))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            if case .error = self.pillWindow.currentState {
                self.pillWindow.setState(.idle)
            }
        }
    }

    /// Show a neutral confirmation, then return to idle.
    ///
    /// Separate from `showPillError` because `.error` carries a warning glyph and a
    /// danger tint: routing the next dictation into a note is the app doing exactly
    /// what it was asked, and reporting it in red said the opposite. `.notice` was
    /// added to `PillState` for this and had no caller until now.
    ///
    /// The return to `.idle` is guarded on the state still *being* the notice, so a
    /// recording started inside the 2.5s window is not cancelled out from under the
    /// user - the same guard `showPillError` uses.
    private func showPillNotice(_ message: String) {
        stopPillTelemetry()
        pillWindow.setState(.notice(message))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            if case .notice = self.pillWindow.currentState {
                self.pillWindow.setState(.idle)
            }
        }
    }

    /// Map an internal error to something a user can act on.
    private static func pillMessage(for error: Error) -> String {
        if let transcription = error as? TranscriptionError {
            switch transcription {
            case .modelMissing: return "Speech model missing"
            case .modelLoadFailed: return "Could not load model"
            case .invalidAudio: return "Could not read audio"
            default: return "Transcription failed"
            }
        }
        return "Transcription failed"
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
        DispatchQueue.main.async { [weak self] in self?.applyDockVisibility() }
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .utterSettings {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Settings"
            item.paletteLabel = item.label
            item.toolTip = item.label
            item.image = NSImage(
                systemSymbolName: "gearshape",
                accessibilityDescription: item.label
            )
            item.target = self
            item.action = #selector(showSettingsWindow)
            return item
        }

        guard itemIdentifier == .toggleSidebar else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Toggle Sidebar"
        item.paletteLabel = item.label
        item.toolTip = item.label
        item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: item.label)
        item.target = nil
        item.action = #selector(NSSplitViewController.toggleSidebar(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var items: [NSToolbarItem.Identifier] = [
            .toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace,
        ]
        if toolbar.identifier == .utterMain { items.append(.utterSettings) }
        return items
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
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
                SoundPlayer.playTrill()
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

private extension NSToolbar.Identifier {
    static let utterMain = NSToolbar.Identifier("UtterMainToolbar")
    static let utterSettingsWindow = NSToolbar.Identifier("UtterSettingsToolbar")
}

private extension NSToolbarItem.Identifier {
    static let utterSettings = NSToolbarItem.Identifier("UtterSettings")
}
