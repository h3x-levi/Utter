import AppKit
import Foundation
import SwiftUI
import Testing

@testable import UtterKit

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
}

@MainActor
@Suite("Words screen snapshots", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_SCREEN_SNAPSHOTS"] == "1"))
struct WordsSnapshots {
    private static let output = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".build/screen-snapshots", isDirectory: true)

    private func fixture() -> WordsViewModel {
        let data = UserData(storageDir: nil)
        data.dictionaryWords = ["Kubernetes", "GraphQL", "Priya", "CoreAudio", "Tahoe", "Whisper"]
        data.snippets = [("my email", "priya@example.com"), ("insert date", "[date] [time]"),
                         ("meeting template", "## Meeting Notes\n- Attendees:\n- Action Items:")]
        data.customAICommands = [CustomAICommand(trigger: "make it a commit", systemPrompt: "Turn this into a conventional commit message under 72 characters.")]
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = [TranscriptionEntry(text: "Ask Marcus to review the Terraform plan before Friday."),
                           TranscriptionEntry(text: "I told Marcus the Terraform module is ready.")]
        return WordsViewModel(userData: data, history: history, rewrite: { $1 }, availability: { .appleIntelligenceOff })
    }

    @Test func render() throws {
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        for (name, section) in [("words-dictionary", WordsViewModel.Section.dictionary),
                                ("words-snippets", .snippets), ("words-commands", .commands)] {
            for dark in [false, true] {
                let model = fixture()
                model.section = section
                let host = NSHostingView(rootView: VoiceEngineView(model: model)
                    .padding(24).background(Look.Color.ground)
                    .environment(\.colorScheme, dark ? .dark : .light))
                host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.frame = CGRect(x: 0, y: 0, width: 820, height: 720)
                let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: rep)
                let png = try #require(rep.representation(using: .png, properties: [:]))
                try png.write(to: Self.output.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
