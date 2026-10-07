import Testing
import Foundation
@testable import UtterKit

@Suite("Snapshot preview isolation")
@MainActor
struct SnapshotPreviewIsolationTests {
    @Test("SnapshotPreviewMode populates harmless fixtures and enables preview flag")
    func fixturesArePopulated() {
        SnapshotPreviewMode.enable()
        defer {
            SnapshotPreviewMode.disable()
        }
        #expect(SnapshotPreviewMode.isActive == true)

        let userData = UserData.shared
        #expect(userData.dictionaryWords.contains("Kubernetes"))
        #expect(userData.dictionaryWords.contains("Whisper"))
        #expect(!userData.snippets.isEmpty)

        let history = TranscriptionHistory.shared
        #expect(!history.entries.isEmpty)
        #expect(history.totalWords > 0)
        #expect(history.entries.first?.text.contains("whisper.cpp") == true)

        let notes = NoteStore.shared
        #expect(!notes.notes.isEmpty)
        #expect(notes.selectedNote != nil)
        #expect(notes.selectedNote?.title == "Voice Workspace Architecture")
    }
}
