import Testing
@testable import UtterKit

/// The one gate every glass surface in the app passes through.
///
/// `GlassSupport.active` is two clauses - the OS can draw Liquid Glass, *and* the
/// user has not asked for reduced transparency - and the second one is an
/// accessibility guarantee that no rendering test can catch. Nothing draws a pixel
/// in CI, so a future edit that inverted the condition, or dropped the
/// `reduceTransparency` clause while keeping the `#available` at each call site,
/// would compile, pass the whole suite, and quietly ship glass to the users who
/// switched it off.
///
/// It is worth pinning because of what still reads it *inverted*:
/// `SettingsSidebar.paneDivider` draws the hairline between the two panes only on the
/// paths where there is no glass to define the edge. So this predicate is the only
/// thing standing between a Reduce Transparency user and a Settings window with
/// neither glass nor a separator.
///
/// The set shrank rather than grew: `flushChromeGlass` used to route both navigation
/// columns through this gate and is now deleted - AppKit's `NSSplitViewItem.sidebar`
/// supplies the material on every path, so the gate no longer decides whether the
/// column has a surface, only whether it needs a drawn edge.
///
/// Pure booleans, so this runs without a window, an appearance, or a Mac on 26.
@Suite("Glass support gate")
struct GlassSupportTests {

    @Test("Reduce Transparency never draws glass, on any OS")
    func reduceTransparencySuppressesGlass() {
        // The clause that cannot be observed from a screenshot in CI. True on
        // macOS 13 and on macOS 26 alike - the setting wins over capability.
        #expect(GlassSupport.active(reduceTransparency: true) == false)
    }

    @Test("With the setting off, glass follows what the OS can do")
    func withoutTheSettingGlassFollowsAvailability() {
        // Not asserted as `true`: this suite has to pass on the 13.3 deployment
        // floor as well as on 26, so the fact being pinned is that the gate defers
        // to `available` rather than hardcoding either answer.
        #expect(GlassSupport.active(reduceTransparency: false) == GlassSupport.available)
    }

    @Test("Reduce Transparency falls to the hairline divider, not to nothing")
    func reduceTransparencyDisablesGlass() {
        #expect(GlassSupport.active(reduceTransparency: true) == false)
    }
}
