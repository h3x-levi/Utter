import AppKit
import Foundation
import SwiftUI
import Testing

@testable import UtterKit
@testable import UtterCore

@MainActor
struct WordsTests {
    private func model(rewrite: @escaping (String, String) async throws -> String = { $1 },
                       ready: Bool = true) -> (WordsViewModel, UserData) {
        let data = UserData(storageDir: nil)
        let history = TranscriptionHistory(storageDir: nil)
        let model = WordsViewModel(userData: data, history: history, rewrite: rewrite,
                                   availability: { ready ? .ready : .appleIntelligenceOff })
        return (model, data)
    }

    @Test func addWordTrimsDedupesAndPersists() {
        let (model, data) = model()
        #expect(model.addWord("  Kubernetes "))
        #expect(!model.addWord("kubernetes"))
        #expect(!model.addWord("   "))
        #expect(data.dictionaryWords == ["Kubernetes"])
        model.removeWords(["Kubernetes"])
        #expect(data.dictionaryWords.isEmpty)
    }

    @Test func suggestionsFindNamesAndSkipKnownOnes() {
        let texts = ["Thanks Priya, see you Monday about GraphQL.", "Ask Priya to review the Kubernetes setup.", "We went home."]
        let found = WordsViewModel.suggestions(from: texts, excluding: ["kubernetes"])
        #expect(found == ["Priya", "GraphQL"])
    }

    @Test func snippetsKeepStableIDsThroughEditAndRejectDuplicateTriggers() {
        let (model, data) = model()
        #expect(model.addSnippet(trigger: "my email", expansion: "a@b.c"))
        #expect(!model.addSnippet(trigger: "My Email", expansion: "x"))
        model.addPack(SnippetPack.all[0])
        let id = model.snippets[0].id
        model.beginEditing(model.snippets[0])
        model.draftExpansion = "new@b.c"
        model.saveEdit()
        #expect(model.snippets[0].id == id)
        #expect(data.snippets.map(\.expansion) == ["new@b.c", "Best regards,"])
        model.beginEditing(model.snippets[0])
        model.draftTrigger = "my sign"
        #expect(!model.canSaveEdit)
        model.removeSnippets([id])
        #expect(data.snippets.count == 1)
    }

    @Test func commandsCreateEditDelete() {
        let (model, data) = model()
        var draft = CommandDraft()
        #expect(!draft.isValid)
        draft.trigger = " make it a commit "
        draft.instruction = "Write a commit message."
        model.saveCommand(draft, replacing: nil)
        let saved = model.commands[0]
        #expect(saved.trigger == "make it a commit")
        draft.instruction = "Short commit message."
        model.saveCommand(draft, replacing: saved)
        #expect(data.customAICommands.count == 1)
        #expect(data.customAICommands[0].id == saved.id)
        #expect(data.customAICommands[0].systemPrompt == "Short commit message.")
        model.deleteCommand(saved.id)
        #expect(data.customAICommands.isEmpty)
    }

    @Test func tryRunsThroughRewriteAndReportsUnavailable() async {
        let (ready, _) = model(rewrite: { _, prompt in prompt.uppercased() })
        var draft = CommandDraft()
        draft.trigger = "shout"
        draft.instruction = "Shout."
        draft.wrapper = "Shout: {{text}}"
        ready.saveCommand(draft, replacing: nil)
        ready.trySample = "hello"
        ready.runTry()
        for _ in 0..<50 where ready.tryResult == .running { await Task.yield() }
        #expect(ready.tryResult == .output("SHOUT: HELLO"))

        let (off, _) = model(ready: false)
        off.saveCommand(draft, replacing: nil)
        #expect(!off.canRunTry)
    }

    @Test func emptyDictionaryNoteGivesWayToSuggestions() {
        let history = TranscriptionHistory(storageDir: nil)
        let model = WordsViewModel(userData: UserData(storageDir: nil), history: history)
        #expect(model.dictionaryIsEmpty)
        history.entries = [TranscriptionEntry(text: "Ask about the GraphQL schema.")]
        model.refreshSuggestions()
        #expect(model.suggestions == ["GraphQL"])
        #expect(!model.dictionaryIsEmpty)
    }

    @Test func flowStackWrapsAndClampsToTheWidth() {
        let sizes = [CGSize(width: 40, height: 26), CGSize(width: 50, height: 26), CGSize(width: 30, height: 26),
                     CGSize(width: 200, height: 26)]
        let (frames, size) = FlowStack.arrange(sizes, width: 100, spacing: 6)
        #expect(frames.map(\.origin) == [CGPoint(x: 0, y: 0), CGPoint(x: 46, y: 0), CGPoint(x: 0, y: 32), CGPoint(x: 0, y: 64)])
        #expect(frames[3].width == 100)
        #expect(size == CGSize(width: 100, height: 90))
    }
}

@MainActor
@Suite("Words screen snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct WordsSnapshots {
    private func window(words: [String]) -> MainWindowModel {
        let data = UserData(storageDir: nil)
        data.dictionaryWords = words
        data.snippets = [("my address", "14 Harbour Row, Leith"), ("sign off", "Best, Sam"),
                         ("meeting link", "meet.example.com/sam"), ("insert date", "[date] [time]")]
        data.customAICommands = [CustomAICommand(trigger: "make it a commit", systemPrompt: "Turn this into a conventional commit message under 72 characters.")]
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = [TranscriptionEntry(text: "Ask Marcus to review the Terraform plan before Friday."),
                           TranscriptionEntry(text: "I told Marcus the Terraform module is ready for DynamoDB.")]
        let model = MainWindowModel(selection: SidebarSelection(arguments: []), status: CaptureStatus(), userData: data,
                                    history: history, notes: NoteStore(storageDir: nil), meeting: MeetingSession())
        model.selection.item = .words
        return model
    }

    @Test func render() throws {
        let words = ["Priya Raman", "Okafor", "Union Square", "Leith", "staging build", "release notes", "whisper.cpp",
                     "Thursday review", "Glasgow", "Tom Ashworth", "UTC"]
        for section in WordsViewModel.Section.allCases {
            for dark in [false, true] {
                let model = window(words: words)
                model.words.section = section
                try capture(model, "words-\(section == .commands ? "commands" : section.rawValue.lowercased())", dark: dark)
            }
        }
        try capture(window(words: []), "words-first-run", dark: true)
    }

    private func capture(_ model: MainWindowModel, _ name: String, dark: Bool) throws {
        let hosting = NSHostingController(rootView: MainWindowView(model: model))
        hosting.sizingOptions = []
        let size = NSSize(width: 1_180, height: 780)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.toolbarStyle = .unified
        window.contentViewController = hosting
        window.setContentSize(size)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        try SnapshotCanvas.capture(window, view: try #require(window.contentView), name, dark: dark)
    }
}
