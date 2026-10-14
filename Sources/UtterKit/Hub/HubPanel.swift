import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import UtterCore

/// A borderless panel that takes typing without activating Utter, so the user's app stays frontmost.
final class HubPanel: NSPanel {
    var onResignKey: () -> Void = {}

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: HubView.width, height: 560),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        setAccessibilityLabel("Utter")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }
}

/// The status item and its hub: opens under the icon, closes on Escape or a click elsewhere, and paints the icon's dot.
@MainActor
final class HubController: NSObject {
    let model = HubModel()
    let panel = HubPanel()
    private let statusItem: NSStatusItem
    private let startMeeting: () async -> MeetingSession.StartOutcome
    private let notify: (String) -> Void
    private let command: (HubModel.Action) -> Void
    private let dot = NSView()
    private var watches: Set<AnyCancellable> = []
    private var monitors: [Any] = []
    private var isOpen = false
    private var target: NSRunningApplication?
    private var lastSeen: Date?
    private var pillState = PillState.idle
    private var pollingForSetup = false

    init(statusItem: NSStatusItem, pill: PillStateModel, meeting: MeetingSession,
         startMeeting: @escaping () async -> MeetingSession.StartOutcome, notify: @escaping (String) -> Void,
         command: @escaping (HubModel.Action) -> Void) {
        self.statusItem = statusItem
        self.startMeeting = startMeeting
        self.notify = notify
        self.command = command
        super.init()

        let host = NSHostingView(rootView: ThemedRoot { HubView(model: model) })
        host.sizingOptions = []
        panel.contentView = host
        panel.onResignKey = { [weak self] in self?.close() }
        model.perform = { [weak self] in self?.handle($0) }
        installDot()

        pill.$state.combineLatest(meeting.$state).sink { [weak self] state, meeting in
            MainActor.assumeIsolated { self?.pillChanged(state, meetingRecording: meeting == .recording) }
        }.store(in: &watches)

        let readiness = ReadinessMonitor.shared
        // Settles the launch burst: the model check publishes a moment after the permission checks.
        Publishers.CombineLatest4(readiness.$micGranted, readiness.$axGranted, readiness.$modelPresent, readiness.$modelLoad)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] mic, ax, present, load in
                let state = SetupNeeds.Readiness(mic: mic, ax: ax, modelPresent: present, modelLoad: load)
                MainActor.assumeIsolated { self?.setNeeds(SetupNeeds.needs(state, modelState: nil)) }
            }.store(in: &watches)
        readiness.startPolling()
        pollingForSetup = true

        TranscriptionHistory.shared.$entries.combineLatest(NoteStore.shared.$notes).sink { [weak self] entries, notes in
            MainActor.assumeIsolated {
                guard let self, self.isOpen else { return }
                self.model.reload(entries: entries, notes: notes)
            }
        }.store(in: &watches)

        let userData = UserData.shared
        userData.$hotkeyName.sink { [weak self] name in
            MainActor.assumeIsolated { self?.model.hotkey = name }
        }.store(in: &watches)
        userData.$companionDictationGoal.sink { [weak self] _ in
            MainActor.assumeIsolated { self?.model.goal = UserData.shared.tapeGoal }
        }.store(in: &watches)
    }

    // MARK: Open and close

    @objc func toggle() { isOpen ? close() : open() }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let front = NSWorkspace.shared.frontmostApplication
        target = front
        model.targetApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? "" : front?.localizedName ?? ""
        model.opened(entries: TranscriptionHistory.shared.entries, notes: NoteStore.shared.notes, lastSeen: lastSeen)
        model.unkeptWords = UserData.shared.unkeptWordsToday(onTape: model.dictationWordsToday)
        ReadinessMonitor.shared.startPolling()
        place()
        panel.makeKeyAndOrderFront(nil)
        if let field = Self.textField(in: panel.contentView) { panel.makeFirstResponder(field) }
        DispatchQueue.main.async { [weak self] in self?.statusItem.button?.highlight(self?.isOpen ?? false) }

        monitors = [
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let key = Key(window: event.windowNumber, code: Int(event.keyCode), chars: event.charactersIgnoringModifiers,
                              flags: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
                return MainActor.assumeIsolated { self?.handleKey(key) ?? false } ? nil : event
            },
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.close() }
            },
        ].compactMap { $0 }
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        ReadinessMonitor.shared.stopPolling()
        lastSeen = .now
    }

    private func place() {
        guard let host = panel.contentView, let icon = statusItem.button?.window else { return }
        let size = host.fittingSize
        let screen = icon.screen?.frame ?? NSScreen.main?.frame ?? icon.frame
        let x = min(max(icon.frame.midX - size.width * 0.72, screen.minX + 8), screen.maxX - size.width - 8)
        panel.setFrame(NSRect(x: x, y: icon.frame.minY - 6 - size.height, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }

    private func replace() {
        guard isOpen else { return }
        DispatchQueue.main.async { [weak self] in self?.place() }
    }

    static func textField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        return view.subviews.lazy.compactMap { textField(in: $0) }.first
    }

    // MARK: Keys and actions

    private struct Key {
        let window: Int
        let code: Int
        let chars: String?
        let flags: NSEvent.ModifierFlags
    }

    private func handleKey(_ key: Key) -> Bool {
        let editor = panel.firstResponder as? NSTextView
        guard key.window == panel.windowNumber, editor?.hasMarkedText() != true else { return false }
        switch key.code {
        case kVK_Escape: close()
        case kVK_DownArrow: model.move(1)
        case kVK_UpArrow: model.move(-1)
        case kVK_Return, kVK_ANSI_KeypadEnter: model.activateSelected()
        default:
            guard key.flags == .command else { return false }
            switch key.chars {
            case "c" where (editor?.selectedRange().length ?? 0) == 0: model.copySelected()
            case "o":
                guard let track = model.selected else { return false }
                handle(.open(track))
            case "n": handle(.newNote)
            case ",": handle(.settings)
            default: return false
            }
        }
        return true
    }

    private func handle(_ action: HubModel.Action) {
        switch action {
        case .paste(let track):
            paste(track)
        case .open(let track):
            close()
            if track.kind == .dictation {
                SidebarSelection.shared.open(libraryItem: LibraryItem.dictationID(track.id))
            } else {
                SidebarSelection.shared.openNote(track.id)
            }
            command(.openLibrary)
        case .grant(let need):
            close()
            grant(need)
        case .recordMeeting:
            if let why = MeetingSession.prepare() {
                model.message = why
                replace()
                return
            }
            close()
            Task { [weak self] in
                guard let self else { return }
                switch await startMeeting() {
                case .started(let id):
                    SidebarSelection.shared.openNote(id)
                    command(.openLibrary)
                case .refused(let why):
                    notify(why)
                }
            }
        default:
            close()
            command(action)
        }
    }

    private func paste(_ track: HubTrack) {
        let pid = target?.processIdentifier
        close()
        let back = PasteBack(hubIsKey: { [panel] in panel.isKeyWindow })
        Task { [weak self] in
            let outcome = await back.run(track.text, into: pid)
            guard let self else { return }
            if outcome == .typed {
                model.markPasted(track.id)
            } else {
                notify(AXIsProcessTrusted() ? "Copied. Paste with \u{2318}V" : "Copied. Allow Accessibility to paste")
            }
        }
    }

    private func grant(_ need: SetupNeeds.Need) {
        switch need {
        case .microphone: AccessibilityPermission.requestMicrophone()
        case .accessibility: AccessibilityPermission.openSettingsPane()
        case .model, .modelFailed: command(.settings)
        }
    }

    // MARK: State

    private func pillChanged(_ state: PillState, meetingRecording: Bool) {
        let started = state.isRecordingLike && !pillState.isRecordingLike
        pillState = state
        model.recording = state.isRecordingLike || meetingRecording
        model.handsFree = state == .handsFree
        // A turn types into the key window, so the hub steps aside before any text lands.
        if case .processing = state { close() } else if started { close() }
        refreshDot()
    }

    private func setNeeds(_ needs: [SetupNeeds.Need]) {
        model.needs = needs
        if needs.isEmpty == pollingForSetup {
            pollingForSetup.toggle()
            pollingForSetup ? ReadinessMonitor.shared.startPolling() : ReadinessMonitor.shared.stopPolling()
        }
        refreshDot()
        replace()
    }

    private func installDot() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(toggle)
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        dot.isHidden = true
        dot.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(dot)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.topAnchor.constraint(equalTo: button.topAnchor, constant: 2),
            dot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -3),
        ])
    }

    private func refreshDot() {
        let color: NSColor? = switch model.status {
        case .recording: .hex(0xD8352A)
        case .setup: .hex(0xF1B632)
        case .ready: nil
        }
        dot.layer?.backgroundColor = color?.cgColor
        dot.isHidden = color == nil
        statusItem.button?.setAccessibilityValue(color == nil ? nil : model.stripeLabel)
    }
}
