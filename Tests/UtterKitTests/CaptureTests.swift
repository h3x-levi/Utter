import Foundation
import Testing
@testable import UtterKit

@Suite("Dictation pipeline")
struct DictationPipelineTests {

    private func marking(_ log: Log) -> DictationPipeline {
        DictationPipeline(
            polish: { $0 + ">polish" },
            voiceCommand: { $0 == "select all" ? .selectAll : $0 == "new note" ? .startNewNote : nil },
            correct: { log.note("correct"); return $0 + ">correct" },
            expandSnippets: { log.note("snippets"); return $0 + ">snippets" },
            formatForApp: { log.note("format"); return $0 + ">format" },
            detectLanguage: { _ in "Fixture" }
        )
    }

    final class Log { var stages: [String] = []; func note(_ s: String) { stages.append(s) } }

    @Test("Typed text runs dictionary, snippets, then app formatting, in that order")
    func appStageOrder() {
        let log = Log()
        #expect(marking(log).prepare("x", for: .app) == "x>correct>snippets>format")
        #expect(log.stages == ["correct", "snippets", "format"])
    }

    @Test("Notes and memories get dictionary and snippets but no app formatting")
    func nonAppStages() {
        #expect(marking(Log()).prepare("x", for: .note) == "x>correct>snippets")
        #expect(marking(Log()).prepare("x", for: .memory) == "x>correct>snippets")
    }

    @Test("Inside a note only routing commands run; a memory runs none")
    func commandsByDestination() {
        let pipeline = marking(Log())
        #expect(pipeline.command(in: "select all", for: .app) == .selectAll)
        #expect(pipeline.command(in: "select all", for: .note) == nil)
        #expect(pipeline.command(in: "new note", for: .note) == .startNewNote)
        #expect(pipeline.command(in: "new note", for: .memory) == nil)
        #expect(pipeline.command(in: "hello", for: .app) == nil)
    }

    /// The live wiring is the only caller of these four features; dropping a stage fails here.
    @Test("The live pipeline wires dictionary, snippets, app formatting and language detection")
    func liveWiring() {
        let data = UserData(storageDir: nil)
        data.dictionaryWords = ["macOS"]
        data.snippets = [(trigger: "my sig", expansion: "Kind regards")]
        let pipeline = DictationPipeline.live(data, context: { .email })

        #expect(pipeline.prepare("I use macos my sig", for: .app) == "I use macOS Kind regards.")
        #expect(pipeline.prepare("I use macos my sig", for: .note) == "I use macOS Kind regards")
        #expect(pipeline.detectLanguage("Bonjour tout le monde, comment allez-vous aujourd'hui ?") == "Français")
        #expect(pipeline.command(in: "select all", for: .app) == .selectAll)
    }
}
