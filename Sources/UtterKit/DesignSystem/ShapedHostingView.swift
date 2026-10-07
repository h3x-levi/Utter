import AppKit
import SwiftUI

/// A hosting view that only accepts the mouse where something is actually drawn.
///
/// Both floating windows are much larger than their contents, and for good reasons: the
/// pill's panel is a fixed 320×60 so the note card has room to grow into it without a
/// resize, and the companion's panel is roughly three times the character so a hop or a
/// stroll is not clipped. The cost was paid by the user - the transparent margin still
/// swallowed clicks, so a wide dead zone around a 56pt capsule ate presses meant for the
/// desktop or the window underneath, and hover was reported as only working near one end
/// of the pill.
///
/// `hitTest` returning nil is the AppKit answer: the event is offered to whatever is
/// behind instead, so the margin becomes genuinely transparent to the mouse rather than
/// merely invisible. It also fixes hover as a side effect - SwiftUI's tracking follows
/// hit-testing, so the reveal now happens anywhere on the capsule instead of wherever the
/// glyph row happened to reach.
///
/// The rect is a closure, not a stored value: both windows change shape at runtime (the
/// pill grows into the card, the companion resizes with `CompanionSize` and its character
/// moves as it roams), and a cached rect would be wrong the moment either did.
final class ShapedHostingView<Content: View>: NSHostingView<Content> {

    /// The region that accepts the mouse, in this view's own coordinates. Everything
    /// outside it is transparent to clicks, drags and hover.
    var interactiveRect: () -> NSRect = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // `hitTest` is handed a point in the *superview's* space; for a window's content
        // view that is the window's own coordinate system, which `from: nil` converts.
        guard interactiveRect().contains(convert(point, from: nil)) else { return nil }
        return super.hitTest(point)
    }
}
