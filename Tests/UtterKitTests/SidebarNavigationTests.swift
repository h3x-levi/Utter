import AppKit
import Testing
@testable import UtterKit

/// The sidebar's rows are custom buttons in the system floating sidebar, so the data they are built from
/// is what a test can hold: distinct destinations and symbols that resolve.
@Suite("Sidebar navigation")
struct SidebarNavigationTests {

    @Test("Each destination is distinct")
    func tagsAreDistinct() {
        #expect(Set(SidebarItem.allCases.map(\.id)).count == SidebarItem.allCases.count)
        #expect(Set(SidebarItem.allCases).count == SidebarItem.allCases.count)
    }

    /// A name that does not resolve renders nothing, and the row silently loses its icon.
    @Test("Every row's symbol resolves", arguments: SidebarItem.allCases)
    @MainActor
    func iconsResolve(item: SidebarItem) {
        #expect(NSImage(systemSymbolName: item.icon, accessibilityDescription: nil) != nil,
                "\(item.rawValue) has no SF Symbol named \(item.icon)")
    }
}
