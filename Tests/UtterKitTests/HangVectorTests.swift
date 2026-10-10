import Testing
import AppKit
@testable import UtterKit

/// `typeText` restores the user's clipboard from a snapshot taken while transcription ran,
/// which is only safe while nothing has written to the clipboard since.
@Suite("Clipboard snapshot reuse", .serialized)
struct PasteboardSnapshotReuseTests {

    private let custom = NSPasteboard.PasteboardType("utter.tests.custom")

    private func withPasteboard(_ body: (NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: .init("utter.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        body(pasteboard)
    }

    private func write(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let first = NSPasteboardItem()
        first.setString(text, forType: .string)
        first.setData(Data(text.utf8.reversed()), forType: custom)
        let second = NSPasteboardItem()
        second.setString(text + " second", forType: .string)
        pasteboard.writeObjects([first, second])
    }

    private func prepared(_ pasteboard: NSPasteboard) {
        TextInjector.prepareSnapshot(pasteboard)
        TextInjector.snapshotQueue.sync {}
    }

    @Test("A snapshot stays current through reads and goes stale on any write")
    func changeCountTracksWrites() {
        withPasteboard { pasteboard in
            write("A", to: pasteboard)
            let snapshot = PasteboardSnapshot(pasteboard)
            _ = pasteboard.string(forType: .string)
            #expect(snapshot.changeCount == pasteboard.changeCount)

            write("B", to: pasteboard)
            #expect(snapshot.changeCount != pasteboard.changeCount)
        }
    }

    @Test("An unchanged clipboard restores every item and type through the prepared snapshot")
    func unchangedClipboardRestoresInFull() {
        withPasteboard { pasteboard in
            write("A", to: pasteboard)
            prepared(pasteboard)
            let snapshot = TextInjector.takeSnapshot(pasteboard)
            #expect(snapshot.changeCount == pasteboard.changeCount)

            pasteboard.clearContents()
            pasteboard.setString("transcript", forType: .string)
            snapshot.restore(to: pasteboard)

            let items = pasteboard.pasteboardItems ?? []
            #expect(items.count == 2)
            #expect(items.first?.string(forType: .string) == "A")
            #expect(items.first?.data(forType: custom) == Data("A".utf8.reversed()))
            #expect(items.last?.string(forType: .string) == "A second")
        }
    }

    @Test("A clipboard changed after the prepare is snapshotted again, never restored stale")
    func changedClipboardIsSnapshottedAgain() {
        withPasteboard { pasteboard in
            write("A", to: pasteboard)
            prepared(pasteboard)
            write("B", to: pasteboard)

            let snapshot = TextInjector.takeSnapshot(pasteboard)
            #expect(snapshot.changeCount == pasteboard.changeCount)
            pasteboard.clearContents()
            snapshot.restore(to: pasteboard)
            #expect(pasteboard.pasteboardItems?.first?.string(forType: .string) == "B")
        }
    }
}
