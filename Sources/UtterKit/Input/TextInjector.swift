import Cocoa
import Carbon.HIToolbox

/// Full-fidelity snapshot of the pasteboard: every item with every type it holds,
/// so restoring preserves rich text, images, and files — not just the plain string.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard = .general) {
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

    static func typeText(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        usleep(10_000) // 10ms
        simulateKeyCombo(key: kVK_ANSI_V, flags: .maskCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            snapshot.restore(to: pasteboard)
        }
    }

    /// Execute a voice command action
    static func executeAction(_ action: VoiceAction) {
        switch action {
        case .startNewNote, .continueNote:
            // Routing decisions, not keystrokes — AppDelegate handles these before
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
            usleep(20_000)
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
