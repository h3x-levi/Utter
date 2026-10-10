import AppKit
import Observation

struct SnippetItem: Identifiable, Equatable {
    let id: UUID
    var trigger: String
    var expansion: String

    init(id: UUID = UUID(), trigger: String, expansion: String) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
    }
}

struct SnippetPack: Identifiable {
    let name: String
    let trigger: String
    let expansion: String
    var id: String { trigger }

    static let all = [
        SnippetPack(name: "Sign-off", trigger: "my sign", expansion: "Best regards,"),
        SnippetPack(name: "Date and time", trigger: "insert date", expansion: "[date] [time]"),
        SnippetPack(name: "Meeting notes", trigger: "meeting template",
                    expansion: "## Meeting Notes\n- Attendees:\n- Key Points:\n- Action Items:"),
        SnippetPack(name: "Looks good note", trigger: "lgtm note",
                    expansion: "LGTM! Verified build and test suite passes."),
    ]
}

struct BuiltInCommand: Identifiable {
    let phrase: String
    let detail: String
    var id: String { phrase }
}

struct BuiltInCommandGroup: Identifiable {
    let title: String
    let commands: [BuiltInCommand]
    var id: String { title }

    static let all = [
        BuiltInCommandGroup(title: "Change the tone", commands: [
            BuiltInCommand(phrase: "Make it professional", detail: "Rewrites in a business tone"),
            BuiltInCommand(phrase: "Make it concise", detail: "Cuts filler and shortens"),
            BuiltInCommand(phrase: "Make it casual", detail: "Rewrites in a relaxed, friendly tone"),
            BuiltInCommand(phrase: "Make it formal", detail: "Rewrites in an official tone"),
        ]),
        BuiltInCommandGroup(title: "Transform text", commands: [
            BuiltInCommand(phrase: "Translate to [language]", detail: "Translates into the language you name"),
            BuiltInCommand(phrase: "Fix this", detail: "Corrects grammar, spelling and punctuation"),
            BuiltInCommand(phrase: "Summarize this", detail: "Condenses the text to a few sentences"),
            BuiltInCommand(phrase: "Reply to this", detail: "Writes a short reply to the selected text"),
        ]),
        BuiltInCommandGroup(title: "Edit what you just said", commands: [
            BuiltInCommand(phrase: "Make it shorter / longer", detail: "Tightens or expands the last result"),
            BuiltInCommand(phrase: "Make it polite / direct", detail: "Softens or sharpens the tone"),
            BuiltInCommand(phrase: "Fix the punctuation", detail: "Repunctuates without changing words"),
            BuiltInCommand(phrase: "Remove the last sentence", detail: "Drops the final sentence"),
            BuiltInCommand(phrase: "Change that to [anything]", detail: "Any edit, such as \u{201C}change that to past tense\u{201D}"),
        ]),
        BuiltInCommandGroup(title: "Keyboard actions", commands: [
            BuiltInCommand(phrase: "Delete that / Undo that", detail: "Undoes the last action"),
            BuiltInCommand(phrase: "Select all", detail: "Selects all text"),
            BuiltInCommand(phrase: "New line / New paragraph", detail: "Starts a new line or paragraph"),
            BuiltInCommand(phrase: "Copy that / Paste that", detail: "Copies or pastes"),
        ]),
    ]
}

struct CommandDraft: Equatable {
    var trigger = ""
    var instruction = ""
    var wrapper = ""
    var replacesSelection = true

    init() {}

    init(_ command: CustomAICommand) {
        trigger = command.trigger
        instruction = command.systemPrompt
        wrapper = command.userPromptTemplate
        replacesSelection = command.replacesSelection
    }

    var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applied(to command: CustomAICommand?) -> CustomAICommand {
        var result = command ?? CustomAICommand(trigger: "", systemPrompt: "")
        result.trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        result.systemPrompt = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        result.userPromptTemplate = wrapper.trimmingCharacters(in: .whitespacesAndNewlines)
        result.replacesSelection = replacesSelection
        return result
    }
}

enum TryResult: Equatable {
    case idle
    case running
    case output(String)
    case failed(String)
}

@MainActor
@Observable
final class WordsViewModel {
    enum Section: String, CaseIterable, Identifiable {
        case dictionary = "Dictionary"
        case snippets = "Snippets"
        case commands = "Voice commands"
        var id: String { rawValue }
    }

    var section: Section = .dictionary

    private(set) var words: [String] = []
    private(set) var suggestions: [String] = []
    var newWord = ""
    var wordQuery = ""

    private(set) var snippets: [SnippetItem] = []
    var newTrigger = ""
    var newExpansion = ""
    var snippetQuery = ""
    private(set) var editingSnippetID: UUID?
    var draftTrigger = ""
    var draftExpansion = ""

    private(set) var commands: [CustomAICommand] = []
    var tryCommandID: UUID?
    var trySample = "hey team just finished the deployment and everything looks healthy let me know if you want to sync later"
    private(set) var tryResult: TryResult = .idle

    @ObservationIgnored private let userData: UserData
    @ObservationIgnored private let history: TranscriptionHistory
    @ObservationIgnored private let rewrite: (String, String) async throws -> String
    @ObservationIgnored private let availabilityProvider: () -> LocalAIEngine.Availability
    @ObservationIgnored private var tryTask: Task<Void, Never>?

    init(
        userData: UserData = .shared,
        history: TranscriptionHistory = .shared,
        rewrite: @escaping (String, String) async throws -> String = { try await LocalAIEngine.rewrite(instructions: $0, prompt: $1) },
        availability: @escaping () -> LocalAIEngine.Availability = { LocalAIEngine.availability }
    ) {
        self.userData = userData
        self.history = history
        self.rewrite = rewrite
        self.availabilityProvider = availability
        reload()
    }

    var hotkeyName: String { userData.hotkeyName }
    var aiAvailability: LocalAIEngine.Availability { availabilityProvider() }

    func reload() {
        words = userData.dictionaryWords
        snippets = userData.snippets.map { SnippetItem(trigger: $0.trigger, expansion: $0.expansion) }
        commands = userData.customAICommands
        if tryCommandID == nil || !commands.contains(where: { $0.id == tryCommandID }) {
            tryCommandID = commands.first?.id
        }
        refreshSuggestions()
    }

    // MARK: Dictionary

    var trimmedNewWord: String { newWord.trimmingCharacters(in: .whitespacesAndNewlines) }

    var filteredWords: [String] {
        let query = wordQuery.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? words : words.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    @discardableResult
    func addWord(_ raw: String) -> Bool {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !words.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { return false }
        words.append(word)
        commitWords()
        refreshSuggestions()
        return true
    }

    func submitNewWord() {
        if addWord(newWord) { newWord = "" }
    }

    func removeWords(_ removed: Set<String>) {
        guard !removed.isEmpty else { return }
        words.removeAll { removed.contains($0) }
        commitWords()
        refreshSuggestions()
    }

    var allWordsText: String { words.joined(separator: "\n") }

    func copyAllWords() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allWordsText, forType: .string)
    }

    func refreshSuggestions() {
        let texts = history.entries.prefix(100).map(\.text)
        suggestions = Self.suggestions(from: texts, excluding: words)
    }

    private func commitWords() {
        userData.dictionaryWords = words
        userData.save()
    }

    private static let notNames: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "june", "july", "august", "september",
        "october", "november", "december",
    ]

    static func suggestions(from texts: [String], excluding existing: [String], limit: Int = 6) -> [String] {
        let known = Set(existing.map { $0.lowercased() })
        var seen: [String: (word: String, count: Int, internalCaps: Bool)] = [:]
        let edge = CharacterSet.punctuationCharacters.union(.symbols)
        for text in texts {
            var startsSentence = true
            for token in text.split(whereSeparator: \.isWhitespace) {
                let atStart = startsSentence
                startsSentence = token.last.map { ".!?".contains($0) } ?? false
                var word = String(token).trimmingCharacters(in: edge)
                for suffix in ["'s", "\u{2019}s"] where word.hasSuffix(suffix) { word.removeLast(suffix.count) }
                guard word.count >= 3, word.allSatisfy({ $0.isLetter || $0.isNumber }),
                      let first = word.first else { continue }
                let key = word.lowercased()
                guard !known.contains(key), !notNames.contains(key) else { continue }
                let internalCaps = word.dropFirst().contains(where: \.isUppercase)
                guard internalCaps || (first.isUppercase && !atStart) else { continue }
                let entry = seen[key] ?? (word, 0, internalCaps)
                seen[key] = (entry.word, entry.count + 1, entry.internalCaps)
            }
        }
        return seen.values
            .filter { $0.internalCaps || $0.count >= 2 }
            .sorted { ($0.count, $1.word) > ($1.count, $0.word) }
            .prefix(limit)
            .map(\.word)
    }

    // MARK: Snippets

    var filteredSnippets: [SnippetItem] {
        let query = snippetQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return snippets }
        return snippets.filter {
            $0.trigger.localizedCaseInsensitiveContains(query) || $0.expansion.localizedCaseInsensitiveContains(query)
        }
    }

    var canAddSnippet: Bool { Self.clean(newTrigger) != nil && Self.clean(newExpansion) != nil }

    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isTaken(_ trigger: String, except id: UUID? = nil) -> Bool {
        snippets.contains { $0.id != id && $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame }
    }

    @discardableResult
    func addSnippet(trigger: String, expansion: String) -> Bool {
        guard let trigger = Self.clean(trigger), let expansion = Self.clean(expansion), !isTaken(trigger) else { return false }
        snippets.append(SnippetItem(trigger: trigger, expansion: expansion))
        commitSnippets()
        return true
    }

    func submitNewSnippet() {
        if addSnippet(trigger: newTrigger, expansion: newExpansion) {
            newTrigger = ""
            newExpansion = ""
        }
    }

    func isInstalled(_ pack: SnippetPack) -> Bool { isTaken(pack.trigger) }

    func addPack(_ pack: SnippetPack) { addSnippet(trigger: pack.trigger, expansion: pack.expansion) }

    func removeSnippets(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        snippets.removeAll { ids.contains($0.id) }
        if let editing = editingSnippetID, ids.contains(editing) { editingSnippetID = nil }
        commitSnippets()
    }

    func beginEditing(_ snippet: SnippetItem) {
        editingSnippetID = snippet.id
        draftTrigger = snippet.trigger
        draftExpansion = snippet.expansion
    }

    var canSaveEdit: Bool {
        guard let id = editingSnippetID, let trigger = Self.clean(draftTrigger), Self.clean(draftExpansion) != nil else { return false }
        return !isTaken(trigger, except: id)
    }

    func saveEdit() {
        guard canSaveEdit, let id = editingSnippetID, let index = snippets.firstIndex(where: { $0.id == id }),
              let trigger = Self.clean(draftTrigger), let expansion = Self.clean(draftExpansion) else { return }
        snippets[index].trigger = trigger
        snippets[index].expansion = expansion
        editingSnippetID = nil
        commitSnippets()
    }

    func cancelEdit() { editingSnippetID = nil }

    private func commitSnippets() {
        userData.snippets = snippets.map { (trigger: $0.trigger, expansion: $0.expansion) }
        userData.save()
    }

    // MARK: Voice commands

    func saveCommand(_ draft: CommandDraft, replacing existing: CustomAICommand?) {
        guard draft.isValid else { return }
        let command = draft.applied(to: existing)
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
        } else {
            commands.append(command)
            tryCommandID = tryCommandID ?? command.id
        }
        commitCommands()
    }

    func deleteCommand(_ id: UUID) {
        commands.removeAll { $0.id == id }
        if tryCommandID == id { tryCommandID = commands.first?.id }
        commitCommands()
    }

    private func commitCommands() {
        userData.customAICommands = commands
        userData.save()
    }

    var tryCommand: CustomAICommand? { commands.first { $0.id == tryCommandID } }

    var canRunTry: Bool {
        aiAvailability.isReady && tryCommand != nil && Self.clean(trySample) != nil && tryResult != .running
    }

    func runTry() {
        guard canRunTry, let command = tryCommand, let sample = Self.clean(trySample) else { return }
        tryResult = .running
        let prompt = command.buildUserPrompt(source: sample)
        tryTask?.cancel()
        tryTask = Task { [rewrite] in
            do {
                let output = try await rewrite(command.systemPrompt, prompt)
                guard !Task.isCancelled else { return }
                tryResult = .output(output)
            } catch {
                guard !Task.isCancelled else { return }
                tryResult = .failed(error.localizedDescription)
            }
        }
    }

    func resetTry() {
        tryTask?.cancel()
        tryResult = .idle
    }
}
