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

@Suite("Whisper abort decisions")
struct WhisperAbortStateTests {

    @Test("A preview tick is skipped while the previous preview is still running")
    func previewSkippedWhileRunning() {
        var state = LocalWhisperProvider.AbortState()
        #expect(state.beginPreview() != nil)
        #expect(state.beginPreview() == nil)
        state.endPreview()
        #expect(state.beginPreview() != nil)
    }

    @Test("A cancelled preview aborts; a final pass does not")
    func cancelAbortsPreviewsOnly() {
        var state = LocalWhisperProvider.AbortState()
        let generation = state.beginPreview()
        #expect(!state.shouldAbort(preview: generation))
        state.cancelPreviews()
        #expect(state.shouldAbort(preview: generation))
        #expect(!state.shouldAbort(preview: nil))
    }

    @Test("Quitting aborts the final pass too, and starts no new preview")
    func quitAbortsEverything() {
        var state = LocalWhisperProvider.AbortState()
        state.shutDown()
        #expect(state.shouldAbort(preview: nil))
        #expect(state.shouldAbort(preview: state.previewGeneration))
        #expect(state.beginPreview() == nil)
    }
}

@Suite("Model download progress throttle")
struct ModelDownloadProgressThrottleTests {

    @Test("Updates closer than 100 ms apart are dropped, and 100% always gets through")
    func dropsCloseUpdatesKeepsCompletion() {
        var throttle = ModelStore.ProgressThrottle()
        let sent = [
            throttle.shouldSend(0.10, at: 5.00),
            throttle.shouldSend(0.11, at: 5.05),
            throttle.shouldSend(0.12, at: 5.15),
            throttle.shouldSend(1.0, at: 5.16),
        ]
        #expect(sent == [true, false, true, true])
    }

    @Test("A thousand updates in one second deliver at most ten")
    func capsAtTenPerSecond() {
        var throttle = ModelStore.ProgressThrottle()
        let sent = (0..<1000).filter { throttle.shouldSend(Double($0) / 2000, at: Double($0) / 1000) }.count
        #expect(sent > 1 && sent <= 10)
    }
}
