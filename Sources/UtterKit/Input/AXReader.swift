import ApplicationServices

/// Accessibility reads into other apps. Every call is IPC into a process that may be hung,
/// so callers must stay off the main thread and every read is bounded by `timeout`.
enum AXReader {
    static let timeout: Float = 0.25

    private static let queue = DispatchQueue(label: "utter.ax-reader", qos: .userInitiated)

    /// Sets the global messaging timeout once at launch; it applies to every AX element.
    static func configure() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
    }

    static func read<T>(_ body: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: body()) }
        }
    }

    static func focusedElement() -> AXUIElement? {
        element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString)
    }

    static func element(_ parent: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute, &out) == .success,
              let ref = out, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    static func string(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &out) == .success,
              let value = out, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return (value as! CFString) as String
    }

    static func pid(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// Whether typed text would land somewhere: a text role, or a web/Electron element
    /// whose selection can be set.
    static func isEditableText(_ element: AXUIElement) -> Bool {
        if let role = string(element, kAXRoleAttribute as CFString), textRoles.contains(role) { return true }
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success
            && settable.boolValue
    }

    /// `AXSecureTextField` is the subrole AppKit reports; some web inputs report it as the role.
    static func isSecure(_ element: AXUIElement) -> Bool {
        string(element, kAXRoleAttribute as CFString) == "AXSecureTextField"
            || string(element, kAXSubroleAttribute as CFString) == "AXSecureTextField"
    }

    /// Whether the focused element of the frontmost app accepts text, read off main with the timeout.
    static func focusAcceptsText() async -> Bool {
        await read {
            guard AXIsProcessTrusted(), let focused = focusedElement() else { return false }
            return isEditableText(focused) && !isSecure(focused)
        }
    }
}
