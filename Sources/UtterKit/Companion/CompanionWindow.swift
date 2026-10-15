import AppKit
import Combine
import SwiftUI
import UtterCore

/// The floating robot: a non-activating panel with its own saved position, one level above the pill.
final class CompanionWindow: NSPanel {
    let behaviour = CompanionBehaviour()

    static let positionKey = "companionWindowPosition"
    private static let pillGap: CGFloat = 16

    private weak var pill: PillWindow?
    private let onOpenSettings: () -> Void
    private let robot = RobotView(frame: .zero)
    private let host: CompanionRobotHost
    private let layout = CompanionBubbleLayout()
    private var geometry: CompanionGeometry
    private var reminders = ReminderScheduler()
    private var heartbeat: Timer?
    private var observers: [AnyCancellable] = []
    private var levelWatch: AnyCancellable?
    private var workspaceTokens: [NSObjectProtocol] = []
    private var screenSharing = false
    private var grabOffset: CGSize?
    private let library = RobotLibrary.shared
    private var routeMemory = RobotRouteMemory()
    private var stateChanged = false
    private var applyQueued = false
    private var pendingCues: [CompanionCue] = []
    private var lastActivity = CACurrentMediaTime()
    private var meetingSeconds = 0
    private var hidingMoment: String?
    private var hideFallback: DispatchWorkItem?

    init(pill: PillWindow, onOpenSettings: @escaping () -> Void) {
        self.pill = pill
        self.onOpenSettings = onOpenSettings
        let geometry = CompanionGeometry(UserData.shared.companionSize)
        self.geometry = geometry
        host = CompanionRobotHost(robot: robot)
        super.init(contentRect: NSRect(origin: .zero, size: geometry.panelSize),
                   styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let content = CompanionPassThroughView(frame: NSRect(origin: .zero, size: geometry.panelSize))
        let bubble = ShapedHostingView(rootView: CompanionBubbleSlot(behaviour: behaviour, layout: layout))
        bubble.sizingOptions = []
        bubble.frame = content.bounds
        bubble.autoresizingMask = [.width, .height]
        content.addSubview(bubble)
        content.addSubview(host)
        contentView = content

        robot.roundness = UserDefaults.standard.companionHeadRoundness
        host.menuSource = { [weak self] in self?.makeMenu() ?? NSMenu() }
        host.onDragBegan = { [weak self] cursor in self?.beginDrag(at: cursor) }
        host.onDrag = { [weak self] cursor in self?.drag(to: cursor) }
        host.onDragEnded = { [weak self] velocity in self?.endDrag(velocity: velocity) }
        host.onPoke = { [weak self] count in self?.behaviour.signal("poke", ["count": .number(Double(count))]) }
        robot.onNear = { [weak self] in self?.behaviour.signal("near") }
        robot.onMomentEnd = { [weak self] id in self?.momentEnded(id) }
        updateLook()
        layoutRobot()
        observe()
        restorePosition()
    }

    deinit {
        workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        NotificationCenter.default.removeObserver(self)
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated { heartbeat?.invalidate() }
    }

    func show() {
        let wasVisible = isVisible
        orderFront(nil)
        startHeartbeat()
        if !wasVisible { behaviour.signal("shown") }
    }

    func hide() {
        orderOut(nil)
        heartbeat?.invalidate()
        heartbeat = nil
    }

    // MARK: Wiring

    private func observe() {
        observers = [
            behaviour.$robotState.sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.stateChanged = true
                    self?.queueApply()
                }
            },
            behaviour.$cue.compactMap { $0 }.sink { [weak self] cue in
                MainActor.assumeIsolated {
                    self?.pendingCues.append(cue)
                    self?.queueApply()
                }
            },
            behaviour.$isQuiet.sink { [weak self] quiet in
                MainActor.assumeIsolated { self?.robot.isQuiet = quiet }
            },
            UserData.shared.$companionSize.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] size in
                MainActor.assumeIsolated { self?.resize(to: size) }
            },
            UserData.shared.$companionPinnedMessage.removeDuplicates().sink { [weak self] note in
                MainActor.assumeIsolated { self?.behaviour.pinnedMessage = note }
            },
            UserDefaults.standard.publisher(for: \.companionHeadRoundness).removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] value in
                MainActor.assumeIsolated { self?.robot.roundness = value }
            },
        ]
        if let meeting = AppDelegate.current?.meetingSession {
            observers += [
                // Read `elapsed` now: the sink runs before the change, and stopping zeroes it.
                meeting.$state.dropFirst().removeDuplicates().sink { [weak self] state in
                    let seconds = meeting.elapsed
                    DispatchQueue.main.async { MainActor.assumeIsolated { self?.meetingChanged(state, seconds: seconds) } }
                },
                meeting.$finishedNoteID.dropFirst().compactMap { $0 }.receive(on: DispatchQueue.main).sink { [weak self] _ in
                    MainActor.assumeIsolated { self?.meetingSaved() }
                },
            ]
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceTokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshScreenSharing() }
            })
        }
        refreshScreenSharing()
    }

    private func queueApply() {
        guard !applyQueued else { return }
        applyQueued = true
        DispatchQueue.main.async { [weak self] in MainActor.assumeIsolated { self?.applyBehaviour() } }
    }

    /// As the Windows and Linux renderer applies an update: a routed moment beats the state that came with it.
    private func applyBehaviour() {
        applyQueued = false
        let state = behaviour.robotState
        let changed = stateChanged
        stateChanged = false
        let cues = pendingCues
        pendingCues = []
        var picked: (moment: String, cue: CompanionCue)?
        for cue in cues {
            lastActivity = CACurrentMediaTime()
            guard !behaviour.isQuiet,
                  cue.mayRoute(state: state, stateChanged: changed, momentPlaying: robot.isPlayingMoment || picked != nil),
                  let moment = route(cue) else { continue }
            picked = (moment, cue)
        }
        if hidingMoment != nil, picked != nil || changed { return disable() }
        if let picked {
            robot.play(moment: picked.moment, loop: library?.moments[picked.moment]?.loopFrom != nil,
                       hold: CompanionCue.hold.contains(picked.cue.event))
        } else if changed {
            if robot.isPlayingMoment { robot.stopMoment() }
            play(state)
        }
        if let picked, picked.cue.event == "hiding" {
            hideAfter(picked.moment)
        } else if cues.contains(where: { $0.event == "hiding" }) {
            disable()
        }
        watchLevels()
    }

    private func route(_ cue: CompanionCue) -> String? {
        guard let library else { return nil }
        let now = Date()
        let detail = cue.detail.merging(library.clock(now)) { own, _ in own }
        return library.route(cue.event, detail, memory: &routeMemory, now: now.timeIntervalSince1970 * 1000)
    }

    private func momentEnded(_ id: String) {
        lastActivity = CACurrentMediaTime()
        if id == hidingMoment { return disable() }
        let state = behaviour.robotState
        guard !robot.isPlayingMoment, !behaviour.isQuiet, state.persists else { return }
        play(state)
    }

    private func play(_ state: RobotState) {
        robot.play(state)
        lastActivity = CACurrentMediaTime()
    }

    private func watchLevels() {
        guard behaviour.robotState == .input, let pill else {
            levelWatch = nil
            return
        }
        guard levelWatch == nil else { return }
        levelWatch = pill.stateModel.levels.$value.sink { [weak self] level in
            MainActor.assumeIsolated {
                self?.robot.inputLevel = level
                self?.behaviour.hear(level, at: CACurrentMediaTime() * 1000)
            }
        }
    }

    private func updateLook() {
        let data = UserData.shared
        let look = RobotLook(finish: data.companionFinish, accessory: data.companionAccessory)
        if robot.look != look { robot.look = look }
    }

    private func meetingChanged(_ state: MeetingSession.State, seconds: Int) {
        switch state {
        case .recording:
            refreshQuiet()
            behaviour.signal("meeting", ["state": .string("recording")])
        case .finishing:
            meetingSeconds = seconds
        default:
            break
        }
    }

    private func meetingSaved() {
        refreshQuiet()
        behaviour.signal("meeting", ["state": .string("saved"), "minutes": .number((Double(meetingSeconds) / 60).rounded())])
    }

    private func startHeartbeat() {
        guard heartbeat == nil else { return }
        reminders.begin(at: Date())
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.beat() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer
    }

    /// Once a second: reminder clocks, the focus countdown and automatic quiet. No IPC into other apps.
    private func beat() {
        let data = UserData.shared
        func every(_ minutes: Int, _ reminder: CompanionReminder) -> TimeInterval? {
            minutes > 0 ? TimeInterval(minutes + data.companionExtraDelay(for: reminder)) * 60 : nil
        }
        reminders.stretchEvery = every(data.companionStretchMinutes, .stretch)
        reminders.waterEvery = every(data.companionWaterMinutes, .water)
        reminders.pomodoroFocus = data.companionPomodoroFocusMinutes > 0 ? TimeInterval(data.companionPomodoroFocusMinutes) * 60 : nil
        reminders.pomodoroBreak = data.companionPomodoroBreakMinutes > 0 ? TimeInterval(data.companionPomodoroBreakMinutes) * 60 : nil
        refreshQuiet()
        let now = Date()
        behaviour.setPomodoroCountdown(reminders.pomodoroRemaining(at: now))
        if let due = reminders.due(at: now) { behaviour.announce(due, name: data.companionUserName) }
        updateLook()
        if !applyQueued, !behaviour.isQuiet, !behaviour.robotState.persists, !robot.isPlayingMoment, !robot.isNapping,
           CACurrentMediaTime() - lastActivity >= 12 {
            behaviour.signal("ambient")
        }
    }

    private func refreshQuiet() {
        let data = UserData.shared
        behaviour.setQuietMode(data.companionQuietMode || (data.companionAutomaticQuietMode && automaticQuiet))
    }

    private var automaticQuiet: Bool {
        if screenSharing { return true }
        return AppDelegate.current?.meetingSession.isCapturing ?? false
    }

    private func refreshScreenSharing() {
        screenSharing = NSWorkspace.shared.runningApplications.contains { app in
            let name = app.localizedName?.lowercased() ?? ""
            return ["screen sharing", "cpt host", "webex share", "slideshow"].contains { name.contains($0) }
        }
    }

    // MARK: Layout and position

    private func layoutRobot() {
        host.frame = geometry.robotFrameInPanel
        layout.robotSide = geometry.robotSide
    }

    private func resize(to size: CompanionSize) {
        let next = CompanionGeometry(size)
        guard next != geometry else { return }
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        geometry = next
        setFrame(NSRect(origin: clamped(next.panelOrigin(robotCentre: centre)), size: next.panelSize), display: true)
        layoutRobot()
        updateBubbleLayout()
    }

    private func visibleFrame(around origin: CGPoint) -> CGRect? {
        let centre = CGPoint(x: origin.x + geometry.panelSize.width / 2, y: origin.y + geometry.panelSize.height / 2)
        return (NSScreen.screens.first { $0.frame.contains(centre) } ?? screen ?? NSScreen.main)?.visibleFrame
    }

    private func clamped(_ origin: CGPoint) -> CGPoint {
        visibleFrame(around: origin).map { geometry.clamped(origin, in: $0) } ?? origin
    }

    private func updateBubbleLayout() {
        guard let visible = visibleFrame(around: frame.origin) else { return }
        let below = geometry.bubbleBelow(panelOrigin: frame.origin, visible: visible)
        let insets = geometry.bubbleInsets(panelOrigin: frame.origin, visible: visible)
        if layout.below != below { layout.below = below }
        if layout.leading != insets.leading { layout.leading = insets.leading }
        if layout.trailing != insets.trailing { layout.trailing = insets.trailing }
    }

    @objc private func screensChanged() { restorePosition() }

    private func restorePosition() {
        guard let saved = UserDefaults.standard.dictionary(forKey: Self.positionKey),
              let fx = saved["fx"] as? CGFloat, let fy = saved["fy"] as? CGFloat,
              let screen = NSScreen.screens.first(where: { $0.displayID == saved["display"] as? UInt32 }) ?? NSScreen.main
        else { return placeBesidePill() }
        setFrameOrigin(geometry.panelOrigin(forCentreFraction: CGPoint(x: fx, y: fy), in: screen.visibleFrame))
        updateBubbleLayout()
    }

    private func savePosition() {
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(centre) }) ?? screen ?? NSScreen.main else { return }
        let fraction = CompanionGeometry.fraction(ofCentre: centre, in: screen.visibleFrame)
        var stored: [String: Any] = ["fx": fraction.x, "fy": fraction.y]
        if let id = screen.displayID { stored["display"] = id }
        UserDefaults.standard.set(stored, forKey: Self.positionKey)
    }

    /// First placement: on the pill's line, clear of the widest thing the pill becomes, the transcript island.
    private func placeBesidePill() {
        guard let pill else { return }
        let p = pill.frame
        let y = p.minY + PillMetrics.capsuleCentreAboveBottom
        let reach = PillMetrics.islandWidth / 2 + Self.pillGap + geometry.robotSide / 2
        let right = CGPoint(x: p.midX + reach, y: y)
        let fitsRight = (visibleFrame(around: geometry.panelOrigin(robotCentre: right))?.maxX ?? .infinity)
            >= right.x + geometry.robotSide / 2
        let centre = fitsRight ? right : CGPoint(x: p.midX - reach, y: y)
        setFrameOrigin(clamped(geometry.panelOrigin(robotCentre: centre)))
        updateBubbleLayout()
    }

    // MARK: Dragging

    private func beginDrag(at cursor: CGPoint) {
        lastActivity = CACurrentMediaTime()
        grabOffset = CGSize(width: cursor.x - frame.origin.x, height: cursor.y - frame.origin.y)
    }

    private func drag(to cursor: CGPoint) {
        guard let grab = grabOffset else { return }
        setFrameOrigin(clamped(CGPoint(x: cursor.x - grab.width, y: cursor.y - grab.height)))
    }

    /// Momentum: travel the distance a fast-decelerating flick would cover, then settle.
    private func endDrag(velocity: CGVector) {
        grabOffset = nil
        let speed = hypot(velocity.dx, velocity.dy)
        behaviour.signal("fling", ["speed": .number(speed)])
        guard speed > 300, !MotionPreference.shared.reduceMotion else {
            savePosition()
            updateBubbleLayout()
            return
        }
        let projection = 0.099
        let target = clamped(CGPoint(x: frame.origin.x + velocity.dx * projection, y: frame.origin.y + velocity.dy * projection))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            animator().setFrame(NSRect(origin: target, size: frame.size), display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.savePosition()
                self?.updateBubbleLayout()
            }
        }
    }

    // MARK: Menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if behaviour.currentReminder != nil {
            item("Done", #selector(completeReminder))
            item("Not Now", #selector(dismissReminder))
            menu.addItem(.separator())
        }
        item("Reset Position", #selector(resetPosition))
        menu.addItem(.separator())
        item("Companion Settings\u{2026}", #selector(openSettings))
        item("Hide Companion", #selector(hideCompanion))
        return menu
    }

    @objc private func completeReminder() {
        guard let reminder = behaviour.respondToCurrentReminder(completed: true) else { return }
        if let celebration = UserData.shared.recordCompanionReminder(reminder, completed: true) {
            let kind = switch reminder {
            case .water: "hydration"
            case .stretch: "stretch"
            default: "focus"
            }
            behaviour.celebrateGoal(celebration, kind: kind)
        }
    }

    @objc private func dismissReminder() {
        guard let reminder = behaviour.respondToCurrentReminder(completed: false) else { return }
        UserData.shared.recordCompanionReminder(reminder, completed: false)
    }

    @objc private func resetPosition() {
        UserDefaults.standard.removeObject(forKey: Self.positionKey)
        placeBesidePill()
    }

    @objc private func openSettings() { onOpenSettings() }

    @objc private func hideCompanion() { behaviour.signal("hiding") }

    private func hideAfter(_ moment: String) {
        hidingMoment = moment
        let fallback = DispatchWorkItem { [weak self] in self?.disable() }
        hideFallback = fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: fallback)
    }

    private func disable() {
        hideFallback?.cancel()
        hideFallback = nil
        hidingMoment = nil
        UserData.shared.companionEnabled = false
        UserData.shared.save()
    }
}

// MARK: - Views

/// The robot takes the pointer; everything else in the panel lets clicks through.
private final class CompanionPassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

/// A press-and-drag carries the window; the antenna pull and the squeeze stay the robot's own.
private final class CompanionRobotHost: NSView {
    let robot: RobotView
    var menuSource: () -> NSMenu = { NSMenu() }
    var onDragBegan: (CGPoint) -> Void = { _ in }
    var onDrag: (CGPoint) -> Void = { _ in }
    var onDragEnded: (CGVector) -> Void = { _ in }
    var onPoke: (Int) -> Void = { _ in }

    private var pressedAt: CGPoint?
    private var pressedTime: TimeInterval = 0
    private var pressedAntenna = false
    private var lastPoke: (time: TimeInterval, count: Int)?
    private var moving = false
    private var samples: [(point: CGPoint, time: TimeInterval)] = []

    init(robot: RobotView) {
        self.robot = robot
        super.init(frame: .zero)
        robot.autoresizingMask = [.width, .height]
        robot.setAccessibilityElement(false)
        addSubview(robot)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        robot.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.insetBy(dx: bounds.width * 0.08, dy: 0).contains(local) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { return rightMouseDown(with: event) }
        robot.mouseDown(with: event)
        pressedAt = NSEvent.mouseLocation
        pressedTime = event.timestamp
        pressedAntenna = robot.isHoldingAntenna
        moving = false
        samples = [(NSEvent.mouseLocation, event.timestamp)]
    }

    override func mouseDragged(with event: NSEvent) {
        guard let pressedAt else { return }
        if robot.isHoldingAntenna { return robot.mouseDragged(with: event) }
        let p = NSEvent.mouseLocation
        if !moving, hypot(p.x - pressedAt.x, p.y - pressedAt.y) > 3 {
            moving = true
            onDragBegan(pressedAt)
        }
        guard moving else { return }
        samples = Array((samples + [(p, event.timestamp)]).suffix(4))
        onDrag(p)
    }

    override func mouseUp(with event: NSEvent) {
        robot.mouseUp(with: event)
        defer {
            pressedAt = nil
            moving = false
        }
        guard moving else { return poked(at: event.timestamp) }
        onDragEnded(velocity(endingAt: event.timestamp))
    }

    private func poked(at time: TimeInterval) {
        guard pressedAt != nil, !pressedAntenna, time - pressedTime <= 0.14 else { return }
        let count = lastPoke.map { time - $0.time < 1.5 ? $0.count + 1 : 1 } ?? 1
        lastPoke = (time, count)
        onPoke(count)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(menuSource(), with: event, for: self)
    }

    /// Screen points per second over the last few drag events; zero when the pointer stopped before release.
    private func velocity(endingAt time: TimeInterval) -> CGVector {
        guard let first = samples.first, let last = samples.last, time - last.time < 0.05, last.time > first.time else { return .zero }
        let dt = last.time - first.time
        return CGVector(dx: (last.point.x - first.point.x) / dt, dy: (last.point.y - first.point.y) / dt)
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { "Companion" }
    override func accessibilityHelp() -> String? { "Drag to move. Open the actions menu for reminders and settings." }

    override func accessibilityPerformShowMenu() -> Bool {
        menuSource().popUp(positioning: nil, at: NSPoint(x: bounds.midX, y: bounds.midY), in: self)
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        menuSource().items.compactMap { item in
            guard let action = item.action else { return nil }
            return NSAccessibilityCustomAction(name: item.title) {
                NSApp.sendAction(action, to: item.target, from: item)
            }
        }
    }
}

final class CompanionBubbleLayout: ObservableObject {
    @Published var below = false
    @Published var leading: CGFloat = 0
    @Published var trailing: CGFloat = 0
    @Published var robotSide: CGFloat = 45
}

private struct CompanionBubbleSlot: View {
    @ObservedObject var behaviour: CompanionBehaviour
    @ObservedObject var layout: CompanionBubbleLayout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            slot(shown: !layout.below, edge: .bottom)
            Color.clear.frame(height: layout.robotSide)
            slot(shown: layout.below, edge: .top)
        }
        .padding(.leading, layout.leading)
        .padding(.trailing, layout.trailing)
        .lookAnimation(.settle, value: behaviour.notice)
    }

    private func slot(shown: Bool, edge: VerticalEdge) -> some View {
        ZStack {
            if shown, let notice = behaviour.notice {
                CompanionBubbleView(notice: notice)
                    .padding(edge == .bottom ? .bottom : .top, 4)
                    .transition(reduceMotion ? .opacity
                                : .scale(scale: 0.9, anchor: edge == .bottom ? .bottom : .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .bottom ? .bottom : .top)
        .frame(height: CompanionGeometry.bubbleRoom)
    }
}

extension RobotLook {
    /// Saved ids are checked when drawn, not when stored, so a library edit never strands a setting.
    init(finish: String, accessory: String, at date: Date = Date(), library: RobotLibrary? = RobotLibrary.shared) {
        self.init()
        guard let library else { return }
        self.finish = library.finishes[finish] == nil ? library.defaults["finish"] ?? self.finish : finish
        worn = library.accessories[accessory]?.wear == true ? accessory : nil
        time = library.timeOfDay(date)
    }
}

extension UserDefaults {
    static let companionHeadRoundnessKey = "companionHeadRoundness"

    /// 0 squarest, 100 roundest, 50 the upstream head.
    @objc dynamic var companionHeadRoundness: Double {
        get { object(forKey: Self.companionHeadRoundnessKey) as? Double ?? Double(RobotGeometry.defaultRoundness) }
        set { set(newValue, forKey: Self.companionHeadRoundnessKey) }
    }
}

extension NSScreen {
    /// The `CGDirectDisplayID` the saved position is keyed to; it survives a relaunch, the `NSScreen` does not.
    var displayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }
}
