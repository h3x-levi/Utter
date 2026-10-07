import Testing
import AppKit
@testable import UtterKit

/// The minimum-size floor applied to a restored window frame.
///
/// `NSWindow.setFrameUsingName` replays an autosaved frame verbatim - `contentMinSize`
/// constrains the user's dragging, not a programmatic frame - so the clamp is the only
/// thing standing between a frame saved while a window was collapsed and that window
/// reopening collapsed. Pure arithmetic, so it is tested here rather than by opening a
/// window.
@Suite("Window sizing")
struct WindowSizeTests {

    private static let settingsMin = NSSize(width: Layout.settingsMinWidth,
                                           height: Layout.settingsMinHeight)

    @Test("A collapsed stored frame is raised to the minimum")
    func raisesBothDimensions() {
        // 133x117 is what this app has actually measured a window collapsing to; see
        // the note in `showMainWindow`.
        #expect(Layout.size(NSSize(width: 133, height: 117), atLeast: Self.settingsMin)
                == Self.settingsMin)
    }

    @Test("A size the user chose is left alone")
    func leavesLargerSizesAlone() {
        let chosen = NSSize(width: 940, height: 760)
        #expect(Layout.size(chosen, atLeast: Self.settingsMin) == chosen)
    }

    @Test("Only the dimension below the floor is raised")
    func clampsPerAxis() {
        // A window dragged wide and short is a legitimate shape for the width and not
        // for the height; raising both would undo a resize the user meant.
        let squashed = Layout.size(NSSize(width: 1200, height: 200),
                                   atLeast: Self.settingsMin)
        #expect(squashed == NSSize(width: 1200, height: Layout.settingsMinHeight))
    }

    @Test("A zero size does not pass through")
    func zeroIsRaised() {
        // Observed as an empty `visibleFrame` while a display wakes, and it is what a
        // truncated autosave string decodes to.
        #expect(Layout.size(.zero, atLeast: Self.settingsMin) == Self.settingsMin)
    }

    @Test("Clamping is idempotent")
    func clampIsStable() {
        let once = Layout.size(NSSize(width: 400, height: 900), atLeast: Self.settingsMin)
        #expect(Layout.size(once, atLeast: Self.settingsMin) == once)
    }

    @Test("Each resizable window opens at or above its own minimum")
    func idealSizesClearTheirMinimums() {
        // The main window was missing from this list while the test claimed to cover "each"
        // resizable window. It is the one whose ideal size is asserted twice at runtime - once as
        // the opening `contentRect` and again by `showMainWindow`'s collapse re-assert loop, which
        // restores `intended` whenever the frame drops below the minimum. An ideal below the
        // minimum would make that loop fire forever on a window nobody had collapsed.
        #expect(Layout.windowIdealWidth >= Layout.windowMinWidth)
        #expect(Layout.windowIdealHeight >= Layout.windowMinHeight)
        #expect(Layout.settingsIdealWidth >= Layout.settingsMinWidth)
        #expect(Layout.settingsIdealHeight >= Layout.settingsMinHeight)
        #expect(Layout.onboardingIdealWidth >= Layout.onboardingMinWidth)
        #expect(Layout.onboardingIdealHeight >= Layout.onboardingMinHeight)
    }

    @Test("The main window opens noticeably larger than its floor")
    func idealIsAGenerousDefault() {
        // The default opening size was raised ~17% (1180x820 -> 1380x960) because the window read
        // as too small. Pinned so an accidental shrink back toward the old default is caught, and
        // so the ratio to the minimum stays a real gap rather than opening near-collapsed.
        #expect(Layout.windowIdealWidth == 1380)
        #expect(Layout.windowIdealHeight == 960)
        // A clear margin over the floor - at least 30% taller than the minimum, so "reset to
        // default" is unmistakably bigger than the smallest a user can drag the window.
        #expect(Layout.windowIdealWidth >= Layout.windowMinWidth * 1.3)
        #expect(Layout.windowIdealHeight >= Layout.windowMinHeight * 1.3)
    }

    @Test("The auxiliary minimums fit the smallest supported display")
    func minimumsFitASmallDisplay() {
        // 1280x800 is the smallest built-in display Utter runs on. `presentAuxWindow`
        // already clamps its opening size to the visible frame; a *minimum* taller
        // than the screen cannot be clamped, so it has to be small enough here - the
        // 90pt allowance covers the menu bar and a Dock.
        let usableHeight: CGFloat = 800 - 90
        #expect(Layout.settingsMinWidth <= 1280)
        #expect(Layout.settingsMinHeight <= usableHeight)
        #expect(Layout.onboardingMinWidth <= 1280)
        #expect(Layout.onboardingMinHeight <= usableHeight)
        // The main window has no clamp at all - `showMainWindow` sets both `contentMinSize` and
        // `minSize` and then re-asserts the ideal size, so a minimum taller or wider than the
        // smallest supported display would be a window that cannot be fitted on screen.
        #expect(Layout.windowMinWidth <= 1280)
        #expect(Layout.windowMinHeight <= usableHeight)
    }
}
