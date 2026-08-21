import Testing
@testable import UtterKit

/// Pins the one invariant a sidebar row's fills have to satisfy: hover and
/// selection both lift the row *toward white*, and hover lifts it less.
///
/// Tested rather than eyeballed because the failure already shipped. Hover was
/// `Surface.fillHover` — `Color.primary.opacity(0.06)`, which inverts per
/// appearance — while selection was a white wash, so on a light theme the pointer
/// arriving at a row darkened it and clicking then jumped it to 75% white. One
/// control moving in two directions is indistinguishable from a rendering fault,
/// and nothing in the build catches it: both fills compile, and both look
/// deliberate in isolation.
///
/// Composited over a backdrop *B*, a lift *k* lands at `B + k(1 - B)`, monotonic in
/// *k* for every *B* in [0, 1] — so asserting the ordering of the lifts is enough
/// to assert the ordering of the rendered tones, whatever the theme, wallpaper or
/// material behind the sidebar turns out to be. That is why this can be a pure test
/// instead of a screenshot.
@Suite("Sidebar row lift")
struct SidebarLiftTests {

    @Test("Hover and selection both lift toward white, in both appearances",
          arguments: [true, false])
    func liftsAreAdditive(isDark: Bool) {
        #expect(SidebarLift.hover(isDark: isDark) > 0)
        #expect(SidebarLift.selected(isDark: isDark) > 0)
    }

    @Test("Hover never overtakes selection", arguments: [true, false])
    func hoverIsWeakerThanSelection(isDark: Bool) {
        #expect(SidebarLift.hover(isDark: isDark) < SidebarLift.selected(isDark: isDark))
    }

    /// Hover has to be *visible*, not merely ordered: a lift small enough to
    /// disappear is the same bug in the other direction. Over the darkest plausible
    /// backdrop — the 49/255 measured on the glass sidebar — 0.03 is the point where
    /// the step falls below ~6/255 and stops reading as feedback.
    @Test("Hover is a visible step, not a token gesture", arguments: [true, false])
    func hoverIsPerceptible(isDark: Bool) {
        #expect(SidebarLift.hover(isDark: isDark) >= 0.03)
    }

    /// The two lifts are one gesture at two strengths rather than two independent
    /// tunings, so the ratio is what keeps light and dark consistent with each
    /// other. Pinned loosely — this is a design relationship, not a magic number.
    @Test("Hover is roughly half the selection's lift in both appearances",
          arguments: [true, false])
    func ratioIsConsistent(isDark: Bool) {
        let ratio = SidebarLift.hover(isDark: isDark) / SidebarLift.selected(isDark: isDark)
        #expect(ratio > 0.35 && ratio < 0.65)
    }
}
