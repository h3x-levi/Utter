import Cocoa
import ApplicationServices

/// Reads a short window of text around the insertion point in the focused app.
///
/// Dictation is the one input method with no idea what it is interrupting. Typing
/// a name a second time is easy; saying it again gets the same mis-hearing. If the
/// document already contains "Kubernetes" three lines up, that word is the single
/// best hint available about what the next sentence contains - and it costs nothing
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
///   * **Never leaves the machine.** Both consumers are on-device - whisper.cpp and
///     Apple's local model. There is no network path.
///   * **Never persisted or logged.** Only the character count is ever printed.
///   * **Bounded.** At most `maxCharacters` before the cursor, one field, no
///     traversal into sibling views or other windows.
///   * **Password fields are refused**, checked by role and by subrole.
///
/// It also requires Accessibility permission, which Utter already holds for
/// keystroke injection - so this adds no new prompt, but it does mean a failure
/// here is silent and must never block dictation.
package enum SurroundingContext {

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
    private static var prewarmed: (read: Task<Snapshot, Never>, at: Date)?

    /// Starts the read when recording begins, on `AXReader`'s queue, so `capture` finds it ready.
    package static func prewarm() {
        guard UserData.shared.useSurroundingContext else {
            clearPrewarmed()
            return
        }
        let read = Task { await AXReader.read(directCapture) }
        cacheLock.withLock { prewarmed = (read, Date()) }
    }

    /// Clear the cached prewarmed snapshot after a dictation turn finishes.
    package static func clearPrewarmed() {
        cacheLock.withLock { prewarmed = nil }
    }

    /// Read the context, or return an empty snapshot.
    /// Returns the prewarmed snapshot if still fresh (<= 45s), falling back to a direct read.
    @MainActor
    static func capture() async -> Snapshot {
        guard UserData.shared.useSurroundingContext else { return Snapshot(before: "") }
        if let cached = cacheLock.withLock({ prewarmed }), Date().timeIntervalSince(cached.at) <= 45.0 {
            return await cached.read.value
        }
        return await AXReader.read(directCapture)
    }

    private static func directCapture() -> Snapshot {
        let empty = Snapshot(before: "")
        guard AXIsProcessTrusted(), let focused = AXReader.focusedElement() else { return empty }
        guard !AXReader.isSecure(focused) else { return empty }

        guard let value = AXReader.string(focused, kAXValueAttribute as CFString),
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
        // With a selection active, the location is still the start - which is the
        // boundary the preceding text ends at, so this is correct either way.
        return cfRange.location
    }
}
