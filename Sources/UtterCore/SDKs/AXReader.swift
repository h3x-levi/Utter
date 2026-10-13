import ApplicationServices

/// Accessibility reads into other apps. Every call is IPC into a process that may be hung,
/// so callers must stay off the main thread and every read is bounded by `timeout`.
package enum AXReader {
    static let timeout: Float = 0.25

    private static let queue = DispatchQueue(label: "utter.ax-reader", qos: .userInitiated)

    /// Sets the global messaging timeout once at launch; it applies to every AX element.
    package static func configure() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
    }

    package static func read<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: body()) }
        }
    }

    package static func focusedElement() -> AXUIElement? {
        element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString)
    }

    private static func element(_ parent: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute, &out) == .success,
              let ref = out, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    package static func string(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &out) == .success,
              let value = out, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return (value as! CFString) as String
    }

    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// Whether typed text would land somewhere: a text role, or a web/Electron element
    /// whose selection can be set.
    private static func isEditableText(_ element: AXUIElement, role: String?) -> Bool {
        if let role, textRoles.contains(role) { return true }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    static func isSecure(_ element: AXUIElement) -> Bool {
        isSecure(element, role: string(element, kAXRoleAttribute as CFString))
    }

    /// `AXSecureTextField` is the subrole AppKit reports; some web inputs report it as the role.
    private static func isSecure(_ element: AXUIElement, role: String?) -> Bool {
        role == "AXSecureTextField" || string(element, kAXSubroleAttribute as CFString) == "AXSecureTextField"
    }

    /// Whether the focused element of the frontmost app accepts text, read off main with the timeout.
    package static func focusAcceptsText() async -> Bool {
        await read {
            guard AXIsProcessTrusted(), let focused = focusedElement() else { return false }
            let role = string(focused, kAXRoleAttribute as CFString)
            return !isSecure(focused, role: role) && isEditableText(focused, role: role)
        }
    }
}
