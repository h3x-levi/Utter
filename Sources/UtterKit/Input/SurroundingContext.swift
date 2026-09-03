import Cocoa
import ApplicationServices

/// Reads a short window of text around the insertion point in the focused app.
///
/// Dictation is the one input method with no idea what it is interrupting. Typing
/// a name a second time is easy; saying it again gets the same mis-hearing. If the
/// document already contains "Kubernetes" three lines up, that word is the single
/// best hint available about what the next sentence contains — and it costs nothing
/// to read.
///
/// The text is used two ways: as extra vocabulary for `SpeechBias` (proper nouns
/// the user never added to their dictionary), and as the sentence the new text has
/// to continue for `SentencePolish` (so capitalisation and a leading conjunction
/// are judged against a real preceding clause).
///
/// ## Privacy
///
/// This is the only part of Utter that reads content the user did not explicitly
/// hand over, so it is constrained accordingly:
///
///   * **Off by default.** `UserData.useSurroundingContext` gates every call.
///   * **Never leaves the machine.** Both consumers are on-device — whisper.cpp and
///     Apple's local model. There is no network path.
///   * **Never persisted or logged.** Only the character count is ever printed.
///   * **Bounded.** At most `maxCharacters` before the cursor, one field, no
///     traversal into sibling views or other windows.
///   * **Password fields are refused**, checked by role and by subrole.
///
/// It also requires Accessibility permission, which Utter already holds for
/// keystroke injection — so this adds no new prompt, but it does mean a failure
/// here is silent and must never block dictation.
enum SurroundingContext {

    /// How much text before the cursor to read.
    ///
    /// Enough for a sentence or two of real context; short enough that it cannot
    /// crowd out the dictionary in the prompt budget (`SpeechBias` caps the total
    /// separately) or dominate the polish prompt.
    private static let maxCharacters = 320

    /// A snapshot of the text around the insertion point.
    struct Snapshot {
        /// Text immediately before the cursor, up to `maxCharacters`.
        let before: String

        /// Whether anything usable was found.
        var isEmpty: Bool { before.isEmpty }

        /// The trailing sentence fragment, for judging whether dictation continues
        /// an existing sentence or starts a new one.
        var trailingFragment: String {
            guard let idx = before.lastIndex(where: { ".!?\n".contains($0) }) else {
                return before
            }
            return String(before[before.index(after: idx)...])
                .trimmingCharacters(in: .whitespaces)
        }

        /// Capitalised words, as candidate proper nouns for speech biasing.
        ///
        /// Filtered to words that are capitalised *mid-sentence*: a capital after a
        /// full stop is just sentence case and says nothing about vocabulary.
        var properNouns: [String] {
            var found: [String] = []
            var atSentenceStart = true

            for token in before.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
                let word = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                let endsSentence = token.contains(".") || token.contains("!") || token.contains("?")

                if !atSentenceStart, word.count >= 3, let first = word.first, first.isUppercase,
                   word != word.uppercased() || word.count > 3 {
                    found.append(word)
                }
                atSentenceStart = endsSentence
            }
            return found
        }
    }

    private static let cacheLock = NSLock()
    private static var prewarmedSnapshot: Snapshot?
    private static var prewarmedAt: Date?

    /// Pre-warm surrounding context when recording starts.
    /// Captures the insertion point state ahead of time so Whisper and SentencePolish
    /// find a warm cache with zero main-thread AX delay when recording completes.
    static func prewarm() {
        guard UserData.shared.useSurroundingContext, AXIsProcessTrusted() else {
            cacheLock.lock()
            prewarmedSnapshot = nil
            prewarmedAt = nil
            cacheLock.unlock()
            return
        }
        let captured = directCapture()
        cacheLock.lock()
        prewarmedSnapshot = captured
        prewarmedAt = Date()
        cacheLock.unlock()
    }

    /// Clear the cached prewarmed snapshot after a dictation turn finishes.
    static func clearPrewarmed() {
        cacheLock.lock()
        prewarmedSnapshot = nil
        prewarmedAt = nil
        cacheLock.unlock()
    }

    /// Read the context, or return an empty snapshot.
    /// Returns the prewarmed snapshot if still fresh (<= 45s), falling back to direct capture.
    static func capture() -> Snapshot {
        let empty = Snapshot(before: "")
        guard UserData.shared.useSurroundingContext else { return empty }
        guard AXIsProcessTrusted() else { return empty }

        cacheLock.lock()
        let cached = prewarmedSnapshot
        let at = prewarmedAt
        cacheLock.unlock()

        if let cached, let at, Date().timeIntervalSince(at) <= 45.0 {
            return cached
        }

        return directCapture()
    }

    private static func directCapture() -> Snapshot {
        let empty = Snapshot(before: "")
        guard let focused = focusedTextElement() else { return empty }
        guard !isSecure(focused) else { return empty }

        guard let value = stringAttribute(focused, kAXValueAttribute as CFString),
              !value.isEmpty else { return empty }

        // Where the cursor is. Without a selection range we cannot know which part
        // of the field precedes it, and guessing "the end" would be wrong in any
        // field the user has clicked into mid-text.
        guard let caret = caretOffset(focused) else { return empty }

        let clamped = min(max(caret, 0), value.count)
        let cut = value.index(value.startIndex, offsetBy: clamped)
        let before = String(value[value.startIndex..<cut]).suffix(maxCharacters)

        return Snapshot(before: String(before))
    }

    // MARK: - Accessibility plumbing

    /// The focused element, if it is a text-bearing control.
    private static func focusedTextElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system, kAXFocusedUIElementAttribute as CFString, &focused
        ) == .success else { return nil }

        // `as?` on a CFTypeRef whose type is AXUIElement does not bridge, so the
        // check has to go through CFGetTypeID.
        guard let ref = focused, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    /// Whether the element is a password field, or claims to be.
    ///
    /// `AXSecureTextField` is checked as both role and subrole. AppKit's
    /// `NSSecureTextField` reports it as the *subrole* (the only form the SDK
    /// defines a constant for, `kAXSecureTextFieldSubrole`), while some web and
    /// Electron inputs report it as the role instead. The string is spelled out
    /// because there is no `kAXSecureTextFieldRole` in the headers — only the
    /// subrole constant exists.
    ///
    /// A field reporting neither is read. Refusing everything unlabelled would
    /// disable the feature in most apps; the `maxCharacters` cap and the
    /// never-logged, never-persisted rules are what bound the damage if some app
    /// mislabels a sensitive field.
    private static let secureIdentifier = "AXSecureTextField"

    private static func isSecure(_ element: AXUIElement) -> Bool {
        if let role = stringAttribute(element, kAXRoleAttribute as CFString),
           role == secureIdentifier {
            return true
        }
        if let subrole = stringAttribute(element, kAXSubroleAttribute as CFString),
           subrole == secureIdentifier {
            return true
        }
        return false
    }

    /// The insertion point as a character offset.
    private static func caretOffset(_ element: AXUIElement) -> Int? {
        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &range
        ) == .success, let value = range, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        var cfRange = CFRange()
        guard AXValueGetValue((value as! AXValue), .cfRange, &cfRange) else { return nil }
        // With a selection active, the location is still the start — which is the
        // boundary the preceding text ends at, so this is correct either way.
        return cfRange.location
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var out: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &out) == .success,
              let value = out, CFGetTypeID(value) == CFStringGetTypeID() else { return nil }
        return (value as! CFString) as String
    }
}
