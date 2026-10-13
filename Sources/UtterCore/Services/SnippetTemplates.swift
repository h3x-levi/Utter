import Foundation
import AppKit

/// Resolves dynamic placeholders inside snippet expansions at the moment of use.
///
/// Supported placeholders (case-insensitive, surrounded by square brackets):
///   - [date]      → localized long date, e.g. "May 27, 2026"
///   - [time]      → localized short time, e.g. "3:42 PM"
///   - [datetime]  → "<date> at <time>"
///   - [day]       → weekday name, e.g. "Wednesday"
///   - [clipboard] → current clipboard string contents (empty if none)
///
/// Unknown placeholders are left untouched so users see them and can fix the typo.
package enum SnippetTemplates {

    /// All recognized placeholder keys. Used by the UI to render quick-insert chips.
    package static let availablePlaceholders: [(token: String, description: String)] = [
        ("[date]", "Today's date"),
        ("[time]", "Current time"),
        ("[datetime]", "Date and time"),
        ("[day]", "Day of the week"),
        ("[clipboard]", "Clipboard contents"),
    ]

    /// Returns true if the text contains at least one recognized placeholder.
    static func hasPlaceholders(_ text: String) -> Bool {
        let lower = text.lowercased()
        return availablePlaceholders.contains { lower.contains($0.token) }
    }

    /// Substitute every recognized placeholder with its current value.
    /// Resolution happens at call-time so values are always fresh.
    static func expand(_ text: String, now: Date = Date()) -> String {
        guard hasPlaceholders(text) else { return text }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: now)

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: now)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayString = dayFormatter.string(from: now)

        let datetimeString = "\(dateString) at \(timeString)"
        let clipboardString = NSPasteboard.general.string(forType: .string) ?? ""

        let replacements: [(String, String)] = [
            ("[datetime]", datetimeString), // longest first to avoid partial match with [date]
            ("[date]", dateString),
            ("[time]", timeString),
            ("[day]", dayString),
            ("[clipboard]", clipboardString),
        ]

        var result = text
        for (token, value) in replacements {
            result = result.replacingOccurrences(
                of: token,
                with: value,
                options: .caseInsensitive
            )
        }
        return result
    }
}
