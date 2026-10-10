import Cocoa
import Carbon.HIToolbox
import os

/// Full-fidelity snapshot of the pasteboard: every item with every type it holds,
/// so restoring preserves rich text, images, and files - not just the plain string.
struct PasteboardSnapshot {
    /// Read before the items, so a write during the snapshot makes it look stale rather than current.
    let changeCount: Int
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard = .general) {
        changeCount = pasteboard.changeCount
        items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [:]) { typedData, type in
                typedData[type] = item.data(forType: type)
            }
        }
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { typedData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typedData { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}

/// Injects text or executes keyboard actions in the focused app.
struct TextInjector {

    static let snapshotQueue = DispatchQueue(label: "utter.pasteboard-snapshot", qos: .userInitiated)
    private static let preparedLock = NSLock()
    private static var prepared: PasteboardSnapshot?
    private static let signposter = OSSignposter(subsystem: "utter.dictation.app", category: .pointsOfInterest)

    /// Snapshots the clipboard off main while transcription runs, so `typeText` can skip it.
    static func prepareSnapshot(_ pasteboard: NSPasteboard = .general) {
        snapshotQueue.async {
            let snapshot = PasteboardSnapshot(pasteboard)
            preparedLock.withLock { prepared = snapshot }
        }
    }

    /// The prepared snapshot if the clipboard has not changed since, otherwise a fresh one.
    static func takeSnapshot(_ pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let reusable = preparedLock.withLock { () -> PasteboardSnapshot? in
            defer { prepared = nil }
            return prepared
        }
        // A prepare still running lands after this; drop it rather than hold the clipboard until the next turn.
        snapshotQueue.async { preparedLock.withLock { prepared = nil } }
        if let reusable, reusable.changeCount == pasteboard.changeCount { return reusable }
        return PasteboardSnapshot(pasteboard)
    }

    static func typeText(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let snapshot = signposter.withIntervalSignpost("PasteboardSnapshot") { takeSnapshot(pasteboard) }

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            snapshot.restore(to: pasteboard)
            return
        }
        let injectedChangeCount = pasteboard.changeCount

        // 2ms yield is sufficient for NSPasteboard system daemon synchronization
        // without introducing perceptible UI micro-stalls.
        usleep(2_000)
        simulateKeyCombo(key: kVK_ANSI_V, flags: .maskCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // A user may copy something new while the target app processes the
            // paste. Do not replace that newer clipboard with our old snapshot.
            guard pasteboard.changeCount == injectedChangeCount else { return }
            snapshot.restore(to: pasteboard)
        }
    }

    /// Execute a voice command action
    static func executeAction(_ action: VoiceAction) {
        switch action {
        case .startNewNote, .continueNote:
            // Routing decisions, not keystrokes - AppDelegate handles these before
            // dispatching here. Listed explicitly so a new VoiceAction can't be
            // silently ignored by a `default`.
            break
        case .undo:
            simulateKeyCombo(key: kVK_ANSI_Z, flags: .maskCommand)
        case .selectAll:
            simulateKeyCombo(key: kVK_ANSI_A, flags: .maskCommand)
        case .newLine:
            simulateKeyCombo(key: kVK_Return, flags: [])
        case .newParagraph:
            simulateKeyCombo(key: kVK_Return, flags: [])
            usleep(3_000)
            simulateKeyCombo(key: kVK_Return, flags: [])
        case .goToEnd:
            simulateKeyCombo(key: kVK_End, flags: .maskCommand)
        case .copy:
            simulateKeyCombo(key: kVK_ANSI_C, flags: .maskCommand)
        case .paste:
            simulateKeyCombo(key: kVK_ANSI_V, flags: .maskCommand)
        }
    }

    /// Simulate Cmd+C to copy selected text
    static func simulateCopy() {
        simulateKeyCombo(key: kVK_ANSI_C, flags: .maskCommand)
    }

    /// Undo the last paste (Cmd+Z)
    static func undoLastTranscription() {
        simulateKeyCombo(key: kVK_ANSI_Z, flags: .maskCommand)
    }

    private static func simulateKeyCombo(key: Int, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
}
