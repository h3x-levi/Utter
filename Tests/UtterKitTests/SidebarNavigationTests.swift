import AppKit
import Testing
@testable import UtterKit

/// Pins what the sidebar's *navigation* has to satisfy now that its rows are a system
/// `List(selection:).listStyle(.sidebar)`.
///
/// This file used to be `SidebarLiftTests` and pinned `SidebarLift` — the ordering of two hand-drawn
/// white washes, `0 < hover < selected`, in both appearances. That enum is deleted, and the reason it
/// went is worth keeping here rather than only in the source, because it is the more useful half of
/// the lesson: **the test passed and the bug shipped anyway.** Composited over a backdrop *B*, a lift
/// *k* lands at `B + k(1 - B)`, monotonic in *k*, so asserting the lifts' ordering did genuinely
/// assert the rendered tones' ordering for every possible backdrop. What it could not assert is that
/// the step was large enough to *see*: over a light theme's ~230/255 sidebar there are ~25 units of
/// headroom above the backdrop in total, and 0.35 of that is the "no indication the mouse is hovering,
/// nothing in light themes" the report described. Ordering is not contrast. A property that can be
/// proved about a colour is not the same as a property you can check by looking at one.
///
/// AppKit owns hover, selection, the focus ring and keyboard traversal now, so there is nothing left
/// here to pin about appearance — and nothing this suite could honestly claim about it either. What
/// *is* newly load-bearing is the data the list is built from, because two things that used to be
/// cosmetic became structural when `SidebarItem` started acting as a selection tag:
///
///   * `SidebarSelection` resolves `--screen` against `allCases` while the list draws `primary`, so a
///     destination in one and not the other is a selection value with no row to land on.
///   * `.tag(item)` identifies a row by `Hashable` conformance, so two items that compared equal
///     would be one row as far as selection is concerned.
///
/// Neither needs a screen to check, which is the point: these are the invariants that a test can
/// actually hold, and the appearance ones now belong to the system that renders them.
@Suite("Sidebar navigation")
struct SidebarNavigationTests {

    /// `--screen <name>` searches `SidebarItem.allCases`; the list draws `SidebarItem.primary`. If a
    /// case is added to the enum and not to `primary`, launching with `--screen` on it leaves the
    /// window showing that screen with no row selected — and the selection binding is non-optional,
    /// so there is no state in which the sidebar can honestly say "none of these".
    @Test("Every destination the launch flag can select is a row the sidebar draws")
    func primaryCoversAllCases() {
        #expect(Set(SidebarItem.primary) == Set(SidebarItem.allCases))
        // Set equality would also hold if `primary` listed something twice, and a duplicated tag is
        // its own bug: `ForEach` would emit two rows the list cannot tell apart.
        #expect(SidebarItem.primary.count == SidebarItem.allCases.count)
    }

    /// Selection is by tag, and a tag is only as unique as the value behind it. `id` is the raw
    /// string, so a copy-pasted `case` label would collide there first.
    @Test("Each destination is a distinct selection tag")
    func tagsAreDistinct() {
        #expect(Set(SidebarItem.allCases.map(\.id)).count == SidebarItem.allCases.count)
        #expect(Set(SidebarItem.allCases).count == SidebarItem.allCases.count)
    }

    /// The glyph is inside a system `Label` now, with no `.frame(width: 16)` reserving space for it.
    /// A name that does not resolve therefore renders *nothing* and the row silently loses its icon,
    /// where the old hand-built row at least held the gap open. Cheap to catch here.
    @Test("Every row's symbol resolves", arguments: SidebarItem.allCases)
    @MainActor
    func iconsResolve(item: SidebarItem) {
        #expect(NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) != nil,
                "\(item.rawValue) has no SF Symbol named \(item.icon)")
    }
}
