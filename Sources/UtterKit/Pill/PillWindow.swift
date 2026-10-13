import SwiftUI
import Cocoa
import Carbon.HIToolbox
import UtterCore

enum PillState: Equatable {
    /// The speech model is still loading, so holding the hotkey would queue rather than record.
    case preparing
    case idle
    case recording
    case handsFree
    /// Hands-free into a Utter note rather than the frontmost app.
    case capturingNote
    /// Hands-free into the private companion memory store.
    case capturingMemory
    case processing(Phase)
    case error(String)
    case notice(String)
    /// A transcript with nowhere to type it, offered for copying until handled or replaced.
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

    var isIsland: Bool {
        if case .island = self { return true }
        return false
    }
}

/// The microphone level, on a publisher of its own so the 30 Hz writes reach only the bars and the
/// companion, never the pill's SwiftUI views.
final class PillLevelSignal: ObservableObject {
    @Published var value: Float = 0
}

struct PillPresentation: Equatable {
    var look: PillLook = .rest
    var caption = false
    var motion = PillMotion.close
}

/// The pill's state and everything derived from it. `PillWindow` turns `presentation` into a frame.
final class PillStateModel: ObservableObject {
    @Published var state: PillState = .preparing { didSet { stateChanged(from: oldValue) } }
    @Published private(set) var presentation = PillPresentation()
    @Published var previewText = ""
    @Published private var elapsedSeconds = 0
    /// Moonlight, the owner's pick; assign another palette to switch.
    @Published var palette = PillPalette.moonlight

    let levels = PillLevelSignal()
    var offersHandsFree = false { didSet { refresh() } }
    var previewEnabled: () -> Bool = { UserData.shared.livePreviewEnabled }
    /// Called before a new presentation animates in, outside its transaction, so the window can grow.
    var onPresent: ((PillPresentation) -> Void)?
    /// Called once the morph to presentation `serial` has finished moving.
    var onSettled: ((Int) -> Void)?
    private(set) var serial = 0
    var schedule: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private(set) var unseen: PillMessage?
    private var celebrating = false
    private var hovering = false
    private var held = false
    private var sawMessage = false
    private var celebration = 0
    private var reveal = 0
    private var intent = 0

    var look: PillLook { presentation.look }

    var level: Float {
        get { levels.value }
        set { levels.value = newValue }
    }

    /// Guarded because the recording timer assigns it ten times a second and `@Published` would
    /// republish every one of them.
    var elapsed: Int {
        get { elapsedSeconds }
        set {
            guard newValue != elapsedSeconds else { return }
            elapsedSeconds = newValue
        }
    }

    var elapsedText: String {
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return minutes > 0
            ? String(format: "%d:%02d", minutes, seconds)
            : String(format: "0:%02d", seconds)
    }

    /// Entering waits out `hoverIntent`, so a cursor passing by does not open the pill; leaving is at once.
    func pointer(inside: Bool) {
        intent += 1
        guard inside else { return setHovering(false) }
        let mark = intent
        schedule(PillMetrics.hoverIntent) { [weak self] in
            guard let self, self.intent == mark else { return }
            self.setHovering(true)
        }
    }

    private func setHovering(_ inside: Bool) {
        guard inside != hovering else { return }
        hovering = inside
        if inside, case .message = look { sawMessage = true }
        if !inside, unseen != nil, case .message = look { hold(for: 1.2) }
        refresh()
    }

    /// A press on the pill: reopens a message the dot is holding.
    func click() {
        guard unseen != nil else { return }
        hold(for: 4)
        refresh()
    }

    private var revealed: Bool { hovering || held }

    private func hold(for seconds: TimeInterval) {
        held = true
        reveal += 1
        let mark = reveal
        schedule(seconds) { [weak self] in
            guard let self, self.reveal == mark else { return }
            self.held = false
            self.finishReveal()
        }
    }

    /// Once a held message has been opened and the pointer has gone, it has been seen.
    private func finishReveal() {
        if !revealed { unseen = nil }
        refresh()
    }

    private func stateChanged(from old: PillState) {
        switch state {
        case .error, .notice:
            sawMessage = hovering
            unseen = nil
        case .idle:
            if let message = Self.message(in: old), message.tone == .error, !sawMessage { unseen = message }
            if case .processing = old { celebrate() }
        case .preparing:
            break
        default:
            unseen = nil
            celebrating = false
        }
        refresh()
    }

    static func message(in state: PillState) -> PillMessage? {
        switch state {
        case .error(let text): return PillMessage(text: text, tone: .error)
        case .notice(let text): return PillMessage(text: text, tone: .notice)
        default: return nil
        }
    }

    private func celebrate() {
        celebrating = true
        celebration += 1
        let mark = celebration
        schedule(PillMetrics.doneHold) { [weak self] in
            guard let self, self.celebration == mark else { return }
            self.celebrating = false
            self.refresh()
        }
    }

    private func refresh() {
        let look = PillLook.derive(state: state, revealed: revealed, unseen: unseen,
                                   celebrating: celebrating, offersHandsFree: offersHandsFree)
        let caption = look.isListening && previewEnabled()
        guard look != presentation.look || caption != presentation.caption else { return }
        let next = PillPresentation(look: look, caption: caption, motion: PillMotion.between(presentation.look, look))
        serial += 1
        let mark = serial
        onPresent?(next)
        withAnimation(next.motion.animation(reduceMotion: MotionPreference.shared.reduceMotion),
                      completionCriteria: .removed) {
            presentation = next
        } completion: { [weak self] in
            self?.onSettled?(mark)
        }
    }

    var accessibilityLabel: String {
        switch state {
        case .notice(let message): return "Utter, \(message)"
        case .preparing: return "Utter, getting ready"
        case .idle: return unseen.map { $0.tone == .error ? "Utter, error" : "Utter, \($0.text)" } ?? "Utter, ready"
        case .recording: return "Utter, recording"
        case .handsFree: return "Utter, recording hands-free"
        case .capturingNote: return "Utter, dictating into a note"
        case .capturingMemory: return "Utter, listening for a memory"
        case .processing(let phase): return "Utter, \(phase.rawValue.lowercased())"
        case .error: return "Utter, error"
        case .island: return "Utter, transcript not typed"
        }
    }

    /// Elapsed seconds, never the level: a 30 Hz value would make VoiceOver unusable.
    @MainActor var accessibilityValue: String {
        switch state {
        case .notice(let message), .error(let message):
            return message
        case .preparing:
            return "Loading the speech model. Dictation will be available in a moment."
        case .idle:
            let ready = "Hold \(UserData.shared.hotkeyName) to dictate"
            return unseen.map { "\($0.text). \(ready)" } ?? ready
        case .recording:
            return "\(elapsed) seconds"
        case .handsFree:
            return "\(elapsed) seconds. Stops automatically after you finish speaking."
        case .capturingNote:
            let destination = NoteStore.shared
                .captureDestination(appendsToOpenNote: UserData.shared.captureAppendsToOpenNote)
            return "\(elapsed) seconds. \(destination.label). Press \(KeyChord.noteCapture.spelled) to finish."
        case .capturingMemory:
            return "\(elapsed) seconds. Saving privately in Companion. "
                + "Press \(KeyChord.memoryCapture.spelled) to finish."
        case .processing:
            return "Please wait"
        case .island:
            return "No text box was selected, so nothing was typed. Copy it from here."
        }
    }
}

final class PillWindow: NSPanel {
    let stateModel = PillStateModel()
    private var onLongPress: (() -> Void)?
    /// The same callback the ⌃⌥Space chord fires, so the pointer route cannot drift from it.
    private var onStartHandsFree: (() -> Void)?
    /// The island's copy, close and Escape all end it here.
    var onCloseIsland: (() -> Void)?

    private var escapeMonitor: Any?
    private var passThroughMonitors: [Any] = []
    private var shown = PillPresentation()
    private var settledSerial = 0
    private var anchor = CGPoint.zero
    /// Whether the press in progress started on the lock; nil when there is none.
    private var pressOnLock: Bool?
    private var longPress: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    /// Visible gap between the bottom of the pill and the top of the Dock.
    private static let dockGap: CGFloat = 10
    /// Dark whatever the system, so the white bars read: glass takes its look from the view's appearance.
    static let darkAppearance = NSAppearance(named: .darkAqua)

    /// Only the island takes keys (⌘C, Escape), and only once the user clicks it.
    override var canBecomeKey: Bool { stateModel.state.isIsland }

    convenience init(onLongPress: @escaping () -> Void,
                     onStartHandsFree: @escaping () -> Void = {}) {
        self.init()
        self.onLongPress = onLongPress
        self.onStartHandsFree = onStartHandsFree
    }

    override init(
        contentRect: NSRect = .zero,
        styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .fullSizeContentView, .borderless],
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false
    ) {
        let size = PillMetrics.panelSize(for: .rest, caption: false)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                   backing: .buffered, defer: false)
        level = .statusBar
        appearance = Self.darkAppearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false

        let hosting = PillHostingView(rootView: PillRootView(
            model: stateModel,
            onStartHandsFree: { [weak self] in self?.onStartHandsFree?() },
            onCloseIsland: { [weak self] in self?.onCloseIsland?() }
        ))
        // The content must never size the window: the panel follows the shell, set from here.
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        hosting.interactiveRect = { [weak self] in self?.hitRect ?? .zero }
        hosting.onHover = { [weak self] inside in self?.stateModel.pointer(inside: inside) }
        contentView = hosting

        stateModel.offersHandsFree = true
        placeAtBottomCentre()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeAtBottomCentre() }
        }
        stateModel.onPresent = { [weak self] in self?.present($0) }
        stateModel.onSettled = { [weak self] in self?.settled($0) }
    }

    /// The shell, in the content view's flipped space.
    var drawnShellRect: NSRect {
        guard let content = contentView else { return .zero }
        return PillMetrics.shellRect(for: stateModel.look, in: content.bounds.size)
    }

    var drawnShellScreenRect: NSRect? {
        guard let contentView else { return nil }
        return convertToScreen(contentView.convert(drawnShellRect, to: nil))
    }

    private var hitRect: NSRect {
        guard let content = contentView else { return .zero }
        return PillMetrics.hitRect(for: shown.look, in: content.bounds.size)
    }

    var currentState: PillState { stateModel.state }

    /// Applied at once on the main thread, so a key-down's first frame is not queued behind the turn.
    @MainActor func setState(_ state: PillState) {
        let leavingIsland = stateModel.state.isIsland && !state.isIsland
        stateModel.state = state
        if state.isRecordingLike { Signposts.endKeyDownToPill() }
        watchEscape(state.isIsland)
        // Give the keyboard back to the app the user was in.
        if leavingIsland, isKeyWindow {
            super.orderOut(nil)
            orderFront(nil)
        }
    }

    /// Never hidden while it is showing something; a message the user has not seen keeps it up.
    override func orderOut(_ sender: Any?) {
        guard stateModel.look.isResting else { return }
        super.orderOut(sender)
    }

    // MARK: - Frame

    /// Grows at once to hold both looks, before the morph starts; `settled` shrinks it to the new one.
    private func present(_ next: PillPresentation) {
        let previous = shown
        shown = next
        if previous.look.isResting, !next.look.isResting { placeAtBottomCentre() }
        watchCaptionPassThrough(next.caption)
        let target = PillMetrics.panelSize(for: next.look, caption: next.caption)
        if !next.look.isResting, !isVisible { orderFront(nil) }
        setPanelSize(CGSize(width: max(frame.width, target.width), height: max(frame.height, target.height)))
        // The morph's completion shrinks the panel; this covers one that never ran, as when hidden.
        let mark = stateModel.serial
        let backstop = next.motion.settle(reduceMotion: MotionPreference.shared.reduceMotion) * 2 + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + backstop) { [weak self] in self?.settled(mark) }
        if case .message(let text, _) = next.look, previous.look != next.look {
            NSAccessibility.post(element: self, notification: .announcementRequested, userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
        }
    }

    /// Once the shell has stopped moving, nothing is clipped by shrinking to it.
    private func settled(_ serial: Int) {
        guard serial == stateModel.serial, serial != settledSerial else { return }
        settledSerial = serial
        setPanelSize(PillMetrics.panelSize(for: shown.look, caption: shown.caption))
        if shown.look.isResting, !UserData.shared.alwaysShowPill { orderOut(nil) }
    }

    private func setPanelSize(_ size: CGSize) {
        let next = PillMetrics.panelFrame(anchor: anchor, size: size)
        guard next != frame else { return }
        setFrame(next, display: true)
    }

    // MARK: - Position

    /// Fixed at the bottom centre of the screen holding the key window, or the main screen, above the Dock.
    private func placeAtBottomCentre() {
        guard let visible = (NSApplication.shared.keyWindow?.screen ?? NSScreen.main)?.visibleFrame else { return }
        // Whole points, so every even panel width puts the shell on the same pixels.
        anchor = CGPoint(x: visible.midX.rounded(), y: (visible.minY + Self.dockGap).rounded())
        setFrame(PillMetrics.panelFrame(anchor: anchor, size: frame.size), display: isVisible)
    }

    // MARK: - Pointer

    /// The caption is opaque, so the window server would hand its clicks to this panel and drop them.
    private func watchCaptionPassThrough(_ on: Bool) {
        if on, passThroughMonitors.isEmpty {
            let update: () -> Void = { [weak self] in self?.updatePassThrough() }
            passThroughMonitors = [
                NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in update() },
                NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in update(); return event },
            ].compactMap { $0 }
            acceptsMouseMovedEvents = true
            updatePassThrough()
        } else if !on, !passThroughMonitors.isEmpty {
            passThroughMonitors.forEach(NSEvent.removeMonitor)
            passThroughMonitors = []
            ignoresMouseEvents = false
        }
    }

    private func updatePassThrough() {
        guard let content = contentView else { return }
        let point = content.convert(convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        ignoresMouseEvents = !hitRect.contains(point)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .rightMouseDown where isOnPill(event):
            showMenu(event)
            return
        case .leftMouseDown where isOnPill(event):
            if event.modifierFlags.contains(.control) {
                showMenu(event)
                return
            }
            beginPress(event)
        case .leftMouseUp:
            endPress()
        default:
            break
        }
        super.sendEvent(event)
    }

    private func isOnPill(_ event: NSEvent) -> Bool {
        guard let content = contentView else { return false }
        return hitRect.contains(content.convert(event.locationInWindow, from: nil))
    }

    private func beginPress(_ event: NSEvent) {
        guard !stateModel.state.isIsland, let content = contentView else { return }
        let point = content.convert(event.locationInWindow, from: nil)
        let onLock = PillMetrics.lockRect(for: shown.look, in: content.bounds.size)?.contains(point) ?? false
        pressOnLock = onLock
        longPress?.cancel()
        guard PillHoverControl.longPressOpensUtter(in: stateModel.state, pointerOnControl: onLock) else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.pressOnLock = nil
            self?.onLongPress?()
        }
        longPress = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func endPress() {
        longPress?.cancel()
        guard let onLock = pressOnLock else { return }
        pressOnLock = nil
        if !onLock { stateModel.click() }
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

    // MARK: - Context menu

    private lazy var pillMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Utter", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Utter", action: #selector(quitApp), keyEquivalent: ""))
        return menu
    }()

    private func showMenu(_ event: NSEvent) {
        guard let contentView else { return }
        NSMenu.popUpContextMenu(pillMenu, with: event, for: contentView)
    }

    @objc private func openMainWindow() { onLongPress?() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

/// Takes the mouse only on the shell, and reports the pointer over the whole panel as hover, so the
/// 8pt sliver has a forgiving target.
final class PillHostingView: NSHostingView<PillRootView> {
    var interactiveRect: () -> NSRect = { .zero }
    var onHover: (Bool) -> Void = { _ in }
    private var hoverArea: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveRect().contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard hoverArea == nil else { return }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea { onHover(true) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { onHover(false) }
    }
}

// MARK: - Views

struct PillRootView: View {
    @ObservedObject var model: PillStateModel
    var onStartHandsFree: (() -> Void)?
    var onCloseIsland: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var glass

    private var style: PillLiquidStyle { model.palette.style(dark: colorScheme == .dark) }
    private var ink: Color { colorScheme == .dark ? Color(white: 0.97) : Color(red: 0.05, green: 0.07, blue: 0.13) }

    var body: some View {
        let look = model.look
        VStack(spacing: PillMetrics.captionGap) {
            if model.presentation.caption {
                PillCaption(text: model.previewText, tint: style.tint, ink: ink)
                    .frame(height: PillMetrics.captionHeight, alignment: .bottom)
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
            shell(look)
                .accessibilityElement(children: look.isIsland ? .contain : .ignore)
                .accessibilityLabel(model.accessibilityLabel)
                .accessibilityValue(model.accessibilityValue)
                .accessibilityAddTraits(model.state.isRecordingLike ? .updatesFrequently : [])
                .modifier(HandsFreeAccessibilityAction(
                    start: PillHoverControl.isOffered(in: model.state) ? onStartHandsFree : nil,
                    name: PillHoverControl.actionName(in: model.state)))
        }
        .padding(.bottom, PillMetrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    /// One glass shape for every look, so the island rises out of the capsule rather than replacing it.
    @ViewBuilder
    private func shell(_ look: PillLook) -> some View {
        let capsule = PillCapsule(look: look, levels: model.levels, palette: model.palette, namespace: glass,
                                  onLock: onStartHandsFree, onCloseIsland: onCloseIsland)
        if #available(macOS 26, *) {
            GlassEffectContainer { capsule }
        } else {
            capsule
        }
    }
}

/// The shell: dark glass with the icon's white bars, a trailing lock or glyph, a message, a dot, or
/// the island. Also the onboarding demo's pill, driven there by `level` instead of the microphone.
struct PillCapsule: View {
    let look: PillLook
    var levels: PillLevelSignal?
    var level: Float = 0
    var palette = PillPalette.moonlight
    let namespace: Namespace.ID
    var onLock: (() -> Void)?
    var onCloseIsland: () -> Void = {}
    @ObservedObject private var motion = MotionPreference.shared

    private let ink = Color(white: 0.97)

    var body: some View {
        let size = PillMetrics.shellSize(for: look)
        let style = palette.dark
        ZStack {
            if case .dot(let tone) = look {
                Circle().fill(tone.color(style))
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
            PillBars(mode: look.bars, height: size.height, color: barColor(style), levels: levels, level: level,
                     reduceMotion: motion.reduceMotion)
                .frame(width: PillBarGeometry.span, height: PillMetrics.capsuleHeight)
                .offset(x: PillMetrics.barsOffset(for: look))
                .allowsHitTesting(false)
            content(size: size, style: style)
        }
        .frame(width: size.width, height: size.height)
        // Dark glass still reads mid-grey over white; this keeps the white bars and the error ink legible,
        // and the rim keeps the sliver findable on a dark desktop.
        .background(PillShape().fill(Color.black.opacity(0.32)))
        .overlay(PillShape().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
        .pillGlass(PillShape(), tint: Color(nsColor: style.tint.color), interactive: !look.isIsland, id: "shell",
                   in: namespace)
        .opacity(look == .rest ? 0.78 : 1)
        .environment(\.colorScheme, .dark)
    }

    private func barColor(_ style: PillLiquidStyle) -> NSColor {
        if case .message(_, .error) = look { return style.error.color }
        return .white
    }

    /// Laid out at the target size from the first frame, so a morph moves the shape, never reflows text.
    @ViewBuilder
    private func content(size: CGSize, style: PillLiquidStyle) -> some View {
        switch look {
        case .hover(handsFree: true):
            glyphSquare(PillLockButton(stops: false, ink: ink) { onLock?() }, side: size.height)
        case .listening(.lock):
            glyphSquare(PillLockButton(stops: true, ink: ink) { onLock?() }, side: size.height)
        case .listening(.note):
            glyphSquare(glyph("note.text"), side: size.height)
        case .listening(.memory):
            glyphSquare(glyph("brain"), side: size.height)
        case .message(let text, let tone):
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone == .error ? Color(nsColor: style.error.color) : ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, PillMetrics.messagePadding + PillBarGeometry.span + PillMetrics.messageGap)
                .padding(.trailing, PillMetrics.messagePadding)
                .frame(width: size.width, alignment: .leading)
                .help(text)
                .id(text)
                .transition(.following(after: 0.1))
        case .island(let transcript):
            PillIsland(transcript: transcript, ink: ink, onClose: onCloseIsland)
                .frame(width: size.width, height: size.height)
                .id(transcript)
                .transition(.following(after: PillMetrics.islandTextDelay))
        default:
            EmptyView()
        }
    }

    private func glyphSquare(_ content: some View, side: CGFloat) -> some View {
        content
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    private func glyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(ink.opacity(0.9))
    }
}

private extension AnyTransition {
    /// Content that follows the shell: in once the shape has led, out quickly before it closes.
    static func following(after delay: TimeInterval) -> AnyTransition {
        .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.22).delay(delay)),
                    removal: .opacity.animation(.easeOut(duration: 0.1)))
    }
}

private extension PillLook {
    var isIsland: Bool {
        if case .island = self { return true }
        return false
    }
}

extension PillTone {
    func color(_ style: PillLiquidStyle) -> Color {
        Color(nsColor: (self == .error ? style.error : style.thinking).color)
    }
}

/// The shell's outline. Its corner radius is a function of its size, so the two spring together.
struct PillShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: PillMetrics.cornerRadius(for: rect.size), style: .continuous)
    }
}

/// The shell's material: tinted Liquid Glass on macOS 26, a material below it, solid under Reduce
/// Transparency, and an outline under Increase Contrast.
struct PillGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color
    var interactive = true
    let id: String?
    let namespace: Namespace.ID
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let edged = content.overlay {
            if contrast == .increased { shape.stroke(Color.primary.opacity(0.7), lineWidth: 1) }
        }
        if #available(macOS 26, *), GlassSupport.active(reduceTransparency: motion.reduceTransparency) {
            let glass = Glass.regular.tint(tint.opacity(0.5)).interactive(interactive)
            if let id {
                edged.glassEffect(glass, in: shape).glassEffectID(id, in: namespace)
            } else {
                edged.glassEffect(glass, in: shape)
            }
        } else {
            edged.background {
                ZStack {
                    if !motion.reduceTransparency { shape.fill(.ultraThinMaterial) }
                    shape.fill(tint.opacity(motion.reduceTransparency ? 1 : 0.7))
                    shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            }
        }
    }
}

extension View {
    func pillGlass<S: Shape>(_ shape: S, tint: Color, interactive: Bool = true, id: String? = nil,
                             in namespace: Namespace.ID) -> some View {
        modifier(PillGlass(shape: shape, tint: tint, interactive: interactive, id: id, namespace: namespace))
    }
}

/// The live words above the pill, when "Show words as you speak" is on.
struct PillCaption: View {
    let text: String
    let tint: SIMD3<Float>
    let ink: Color
    @Namespace private var glass

    var body: some View {
        Text(LiveTranscript.tail(of: text))
            .font(.callout)
            .foregroundStyle(ink)
            .lineLimit(2)
            .truncationMode(.head)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .pillGlass(RoundedRectangle(cornerRadius: 12, style: .continuous), tint: Color(nsColor: tint.color),
                       interactive: false, in: glass)
            .frame(maxWidth: PillMetrics.captionMaxWidth)
            .opacity(text.isEmpty ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A transcript held because there was nowhere to type it: six lines, then it scrolls. Copy says so,
/// then puts the island away.
struct PillIsland: View {
    let transcript: String
    let ink: Color
    let onClose: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: PillMetrics.islandSpacing) {
            Text("No text box was focused, so your words are here")
                .font(.caption)
                .foregroundStyle(ink.opacity(0.62))
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .foregroundStyle(ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: PillMetrics.islandTextHeight(for: transcript))
            HStack(spacing: 8) {
                Button(action: copy) {
                    Label {
                        Text(copied ? "Copied" : "Copy")
                    } icon: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(PillIslandButtonStyle(ink: ink))
                .keyboardShortcut("c", modifiers: .command)
                .accessibilityLabel(copied ? "Copied" : "Copy transcript")
                Spacer(minLength: 0)
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        PillKeycap(text: "Esc", ink: ink)
                        Text("to close").font(.caption)
                    }
                    .foregroundStyle(ink.opacity(0.62))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close")
                .accessibilityLabel("Close")
            }
            .frame(height: PillMetrics.islandFooterHeight)
        }
        .padding(PillMetrics.islandPadding)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(PillMetrics.copiedHold))
            if !Task.isCancelled { onClose() }
        }
    }

    private func copy() {
        guard !copied else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        withAnimation(.snappy(duration: 0.25)) { copied = true }
        AccessibilityNotification.Announcement("Copied").post()
    }
}

private struct PillKeycap: View {
    let text: String
    let ink: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(ink)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .background(Color.white.opacity(0.07), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
    }
}

/// A content-layer button on the island: no glass on the glass, a fill that brightens on hover and a
/// press that springs. Its corners are the island's less its padding.
private struct PillIslandButtonStyle: ButtonStyle {
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        PillIslandButton(configuration: configuration, ink: ink)
    }
}

private struct PillIslandButton: View {
    let configuration: ButtonStyleConfiguration
    let ink: Color
    @State private var hovering = false
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PillMetrics.islandCornerRadius - PillMetrics.islandPadding,
                                     style: .continuous)
        let pressed = configuration.isPressed
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .frame(height: PillMetrics.islandFooterHeight)
            .background(Color.white.opacity(pressed ? 0.04 : hovering ? 0.11 : 0.07), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.1)))
            .scaleEffect(pressed && !motion.reduceMotion ? 0.94 : 1)
            .animation(motion.reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.22, dampingFraction: 0.62),
                       value: pressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Preparing a live transcript for a caption that shows its last two lines.
enum LiveTranscript {
    /// Comfortably more than two lines of the caption, so the view's head truncation makes the cut.
    static let tailCharacters = 160

    /// The end of `text`, starting on a word boundary, with an ellipsis where the start was cut.
    static func tail(of text: String, maxCharacters: Int = tailCharacters) -> String {
        guard text.count > maxCharacters else { return text }
        let cut = text.suffix(maxCharacters)
        if let firstSpace = cut.firstIndex(where: { $0.isWhitespace }) {
            let whole = cut[cut.index(after: firstSpace)...]
            if !whole.isEmpty { return "\u{2026}" + whole }
        }
        return "\u{2026}" + cut
    }
}
