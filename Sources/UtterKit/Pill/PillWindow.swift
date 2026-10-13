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
    /// Dark whatever the system, so the island's scroller and text selection suit its near-black body.
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

    var body: some View {
        let look = model.look
        VStack(spacing: PillMetrics.captionGap) {
            if model.presentation.caption {
                PillCaption(text: model.previewText)
                    .frame(height: PillMetrics.captionHeight, alignment: .bottom)
                    .transition(.opacity.animation(.easeOut(duration: 0.2)))
            }
            PillCapsule(look: look, levels: model.levels, onLock: onStartHandsFree, onCloseIsland: onCloseIsland)
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
}

/// One shell for every look, so the island rises out of the capsule rather than replacing it: the brand
/// stripe at rest, red while it listens or thinks, navy on hover and when done, gold for an error, and
/// chrome tape for the island. Also the onboarding demo's pill, driven there by `level`.
struct PillCapsule: View {
    let look: PillLook
    var levels: PillLevelSignal?
    var level: Float = 0
    var onLock: (() -> Void)?
    var onCloseIsland: () -> Void = {}
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        let size = PillMetrics.shellSize(for: look)
        ZStack {
            PillBars(mode: look.bars, height: size.height, levels: levels, level: level,
                     reduceMotion: motion.reduceMotion)
                .frame(width: PillBarGeometry.span, height: PillMetrics.capsuleHeight)
                .offset(x: PillMetrics.barsOffset(for: look))
                .allowsHitTesting(false)
            content(size: size)
        }
        .frame(width: size.width, height: size.height)
        .background(PillShape().fill(PillColor.restStripe).opacity(look == .rest ? 1 : 0))
        .pillSurface(PillShape(), fill: look.fill, ring: look.isIsland ? PillColor.tapeRing : PillColor.ring)
        .environment(\.colorScheme, .dark)
    }

    /// Laid out at the target size from the first frame, so a morph moves the shape, never reflows text.
    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch look {
        case .hover(handsFree: true):
            glyphSquare(PillLockButton(stops: false, ink: .white) { onLock?() }, side: size.height)
        case .listening(.lock):
            glyphSquare(PillLockButton(stops: true, ink: .white) { onLock?() }, side: size.height)
        case .listening(.note):
            glyphSquare(glyph("note.text"), side: size.height)
        case .listening(.memory):
            glyphSquare(glyph("brain"), side: size.height)
        case .done:
            PillTick(reduceMotion: motion.reduceMotion)
        case .message(let text, let tone):
            if tone == .error {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(look.ink)
                    .offset(x: PillMetrics.barsOffset(for: look))
                    .transition(.following(after: 0.1))
            }
            Text(text)
                .font(.callout.weight(.semibold))
                .foregroundStyle(look.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, PillMetrics.messagePadding + PillBarGeometry.span + PillMetrics.messageGap)
                .padding(.trailing, PillMetrics.messagePadding)
                .frame(width: size.width, alignment: .leading)
                .help(text)
                .id(text)
                .transition(.following(after: 0.1))
        case .island(let transcript):
            PillIsland(transcript: transcript, onClose: onCloseIsland)
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
            .foregroundStyle(Color.white.opacity(0.92))
    }
}

/// The done tick, drawn in one stroke once the bars have gone.
private struct PillTick: View {
    let reduceMotion: Bool
    @State private var drawn = false

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 1.4, y: 4.8))
            path.addLine(to: CGPoint(x: 4.2, y: 7.4))
            path.addLine(to: CGPoint(x: 9.6, y: 1.6))
        }
        .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
        .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        .frame(width: 11, height: 9)
        .onAppear {
            withAnimation(.easeOut(duration: PillMetrics.tickDraw).delay(PillMetrics.tickDelay)) { drawn = true }
        }
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

    var fill: Color {
        switch self {
        case .rest, .listening, .thinking: return PillColor.red
        case .hover, .done, .message(_, .notice), .dot(.notice): return PillColor.navy
        case .message(_, .error), .dot(.error): return PillColor.gold
        case .island: return PillColor.tape
        }
    }

    /// White on red and navy, navy on gold.
    var ink: Color {
        switch self {
        case .message(_, .error), .dot(.error): return PillColor.goldInk
        default: return .white
        }
    }
}

/// The pill's inks, always resolved dark because its window is.
enum PillColor {
    static let red = ink(Mixtape.Palette.pillRed)
    static let gold = Mixtape.gold
    static let navy = ink(Mixtape.Palette.pillNavy)
    static let goldInk = ink(Mixtape.Palette.pillGoldInk)
    static let tape = ink(Mixtape.Palette.pillTape)
    static let tapeInk = ink(Mixtape.Palette.pillTapeInk)
    static let transcript = ink(Mixtape.Palette.pillTranscript)
    static let tapeRule = ink(Mixtape.Palette.pillTapeRule)
    static let ring = Color.black.opacity(0.1)
    static let tapeRing = Mixtape.edge
    static let restStripe = stripe([(red, 0.6), (gold, 0.8), (ink(Mixtape.Palette.pillStripeNavy), 1)])
    static let islandStripe = stripe([(Mixtape.red, 0.7), (gold, 0.85), (ink(Mixtape.Palette.pillStripeBlue), 1)])

    private static func ink(_ swatch: Mixtape.Palette.Swatch) -> Color {
        Color(nsColor: swatch.nsColor)
    }

    /// Hard-edged bands, each colour running from the last one's end to its own.
    private static func stripe(_ bands: [(Color, CGFloat)]) -> LinearGradient {
        let starts: [CGFloat] = [0] + bands.dropLast().map(\.1)
        let stops = zip(bands, starts).flatMap { band, start in
            [Gradient.Stop(color: band.0, location: start), Gradient.Stop(color: band.0, location: band.1)]
        }
        return LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing)
    }
}

/// The shell's outline. Its corner radius is a function of its size, so the two spring together.
struct PillShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: PillMetrics.cornerRadius(for: rect.size), style: .continuous)
    }
}

/// An opaque fill with a neutral shadow and a 1 pt ring just outside the edge. Increase Contrast firms
/// the ring and adds a light inner edge, so the shape reads on any desktop.
struct PillSurface<S: Shape>: ViewModifier {
    let shape: S
    let fill: Color
    let ring: Color
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let firm = contrast == .increased
        content
            .background {
                shape.fill(fill).shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                shape.stroke(firm ? Color.black.opacity(0.6) : ring, lineWidth: 1).padding(-0.5)
            }
            .overlay {
                if firm {
                    shape.stroke(Color.white.opacity(0.7), lineWidth: 1).padding(0.5).allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func pillSurface<S: Shape>(_ shape: S, fill: Color, ring: Color) -> some View {
        modifier(PillSurface(shape: shape, fill: fill, ring: ring))
    }
}

/// The live words above the pill, when "Show words as you speak" is on, on the island's chrome tape.
struct PillCaption: View {
    let text: String

    var body: some View {
        Text(LiveTranscript.tail(of: text))
            .font(.callout)
            .foregroundStyle(PillColor.transcript)
            .lineLimit(2)
            .truncationMode(.head)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .pillSurface(RoundedRectangle(cornerRadius: 12, style: .continuous), fill: PillColor.tape,
                         ring: PillColor.tapeRing)
            .frame(maxWidth: PillMetrics.captionMaxWidth)
            .opacity(text.isEmpty ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A transcript held because there was nowhere to type it, on a chrome-tape label: six ruled lines,
/// then it scrolls. Copy or Save as note says so, then puts the island away.
struct PillIsland: View {
    let transcript: String
    let onClose: () -> Void
    @State private var done: Done?
    @Environment(\.colorSchemeContrast) private var contrast

    private enum Done { case copied, saved }

    var body: some View {
        let quiet = PillColor.tapeInk.opacity(contrast == .increased ? 0.85 : 0.6)
        VStack(alignment: .leading, spacing: PillMetrics.islandSpacing) {
            Text("No text box selected, so your words are here")
                .font(.caption)
                .foregroundStyle(quiet)
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .foregroundStyle(PillColor.transcript)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PillRules())
            }
            .frame(height: PillMetrics.islandTextHeight(for: transcript))
            HStack(spacing: 8) {
                Button(done == .copied ? "Copied" : "Copy", action: copy)
                    .buttonStyle(PillIslandButtonStyle(filled: true))
                    .keyboardShortcut("c", modifiers: .command)
                    .accessibilityLabel(done == .copied ? "Copied" : "Copy transcript")
                Button(done == .saved ? "Saved" : "Save as note", action: save)
                    .buttonStyle(PillIslandButtonStyle(filled: false))
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityLabel(done == .saved ? "Saved as a note" : "Save as note")
                Spacer(minLength: 0)
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        PillKeycap(text: "Esc")
                        Text("to close").font(.caption)
                    }
                    .foregroundStyle(quiet)
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
        .overlay(alignment: .top) { Rectangle().fill(PillColor.islandStripe).frame(height: 5) }
        .clipShape(PillShape())
        .task(id: done) {
            guard done != nil else { return }
            try? await Task.sleep(for: .seconds(PillMetrics.copiedHold))
            if !Task.isCancelled { onClose() }
        }
    }

    private func copy() {
        guard done == nil else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        finish(.copied, announcing: "Copied")
    }

    private func save() {
        guard done == nil else { return }
        Self.saveAsNote(transcript, in: .shared)
        finish(.saved, announcing: "Saved as a note")
    }

    private func finish(_ result: Done, announcing announcement: String) {
        withAnimation(.snappy(duration: 0.25)) { done = result }
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// A new note that leaves the Library's open note, and so where ⌃⌥N adds, alone. Written through,
    /// because the island is the transcript's only other copy.
    @MainActor static func saveAsNote(_ transcript: String, in store: NoteStore) {
        store.create(body: transcript, source: .dictated, select: false)
        store.writeToDisk()
    }
}

/// The tape's faint rules, one under each line of the transcript.
private struct PillRules: View {
    var body: some View {
        Canvas { context, size in
            let font = NSFont.preferredFont(forTextStyle: .body)
            let pitch = font.ascender - font.descender + font.leading
            for y in stride(from: pitch, through: size.height, by: pitch) {
                context.fill(Path(CGRect(x: 0, y: y - 1, width: size.width, height: 1)),
                             with: .color(PillColor.tapeRule))
            }
        }
    }
}

private struct PillKeycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundStyle(PillColor.tapeInk)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(PillColor.tapeInk.opacity(0.3)))
    }
}

/// The island's pen buttons: Copy filled in the tape's ink, Save as note outlined in it. Hover
/// brightens, a press springs.
private struct PillIslandButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        PillIslandButton(configuration: configuration, filled: filled)
    }
}

private struct PillIslandButton: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool
    @State private var hovering = false
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .tracking(0.84)
            .textCase(.uppercase)
            .foregroundStyle(filled ? PillColor.tape : PillColor.tapeInk)
            .padding(.horizontal, 11)
            .frame(height: PillMetrics.islandFooterHeight)
            .background(Capsule().fill(filled ? hovering ? Color.white : PillColor.tapeInk
                                              : Color.white.opacity(hovering ? 0.08 : 0)))
            .overlay { if !filled { Capsule().strokeBorder(PillColor.tapeInk.opacity(0.7), lineWidth: 1.5) } }
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
