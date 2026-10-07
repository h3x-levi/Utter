import SwiftUI

@MainActor
private final class RowHoverModel: ObservableObject {
    @Published var isHovering = false
}

// MARK: - Dictionary

@MainActor
private final class DictionaryViewModel: ObservableObject {
    @Published var newWord = ""
    @Published var searchText = ""
    @Published var exportedMessage = ""

    var trimmedWord: String {
        newWord.trimmingCharacters(in: .whitespaces)
    }

    func addWord(userData: UserData, listCurve: Animation) {
        let word = trimmedWord
        guard !word.isEmpty, !userData.dictionaryWords.contains(word) else { return }
        withAnimation(listCurve) {
            userData.dictionaryWords.append(word)
        }
        userData.save()
        newWord = ""
    }

    func addSpecificWord(_ word: String, userData: UserData, listCurve: Animation) {
        guard !userData.dictionaryWords.contains(word) else { return }
        withAnimation(listCurve) {
            userData.dictionaryWords.append(word)
        }
        userData.save()
    }

    func exportWords(userData: UserData) {
        if let data = try? JSONEncoder().encode(userData.dictionaryWords),
           let json = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            exportedMessage = "Copied to clipboard!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.exportedMessage = ""
            }
        }
    }

    func remove(_ word: String, userData: UserData, listCurve: Animation) {
        withAnimation(listCurve) {
            userData.dictionaryWords.removeAll { $0 == word }
        }
        userData.save()
    }
}

struct DictionaryView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var model = DictionaryViewModel()

    private var listCurve: Animation {
        motion.reduceMotion ? Motion.reduced : Motion.listChange
    }

    private var filteredWords: [String] {
        if model.searchText.isEmpty {
            return userData.dictionaryWords
        }
        return userData.dictionaryWords.filter { $0.localizedCaseInsensitiveContains(model.searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            ContentSection(title: "Add a word", systemImage: "plus.circle") {
                Text("Custom words help Utter transcribe names, acronyms, and jargon correctly.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.x2) {
                    GlassTextField(
                        placeholder: "Name, acronym, or technical term",
                        text: $model.newWord,
                        systemImage: "character.cursor.ibeam",
                        onSubmit: { model.addWord(userData: userData, listCurve: listCurve) }
                    )
                    GlassButton(title: "Add", prominent: true) {
                        model.addWord(userData: userData, listCurve: listCurve)
                    }
                    .disabled(model.trimmedWord.isEmpty)
                }

                // Quick Add Dev Pack
                HStack(spacing: Space.x2) {
                    Text("Quick add:").font(.caption2).foregroundStyle(Ink.secondary)
                    ForEach(["Kubernetes", "GraphQL", "PostgreSQL", "Tailwind", "Whisper"], id: \.self) { tech in
                        Button(action: { model.addSpecificWord(tech, userData: userData, listCurve: listCurve) }) {
                            Text(tech).font(.caption2.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(userData.dictionaryWords.contains(tech))
                    }
                }
                .padding(.top, 2)
            }

            if userData.dictionaryWords.isEmpty {
                EmptyStateView(
                    icon: "character.book.closed",
                    title: "No custom words",
                    message: "Add names, acronyms, and jargon that get transcribed wrong \u{2014} "
                        + "teammates, product names, technical terms."
                )
            } else {
                ContentSection(
                    title: "Your words",
                    systemImage: "character.book.closed",
                    accessory: AnyView(
                        HStack(spacing: Space.x2) {
                            if !model.exportedMessage.isEmpty {
                                Text(model.exportedMessage)
                                    .font(.caption2)
                                    .foregroundStyle(Tint.successText)
                            }
                            Button(action: { model.exportWords(userData: userData) }) {
                                Label("Export JSON", systemImage: "square.and.arrow.up")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Text("\(userData.dictionaryWords.count)")
                                .typo(.caption, ink: Ink.tertiary)
                        }
                    )
                ) {
                    // Live Search Bar
                    HStack(spacing: Space.x2) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(Ink.secondary)
                        TextField("Search custom words…", text: $model.searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    GlassCluster(spacing: 0) {
                        VStack(spacing: Space.x1) {
                            ForEach(filteredWords, id: \.self) { word in
                                WordRow(word: word) { model.remove(word, userData: userData, listCurve: listCurve) }
                            }
                        }
                    }
                    .animation(listCurve, value: userData.dictionaryWords)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WordRow: View {
    let word: String
    let onDelete: () -> Void

    @StateObject private var hover = RowHoverModel()
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        HStack(spacing: Space.x2) {
            Text(word).typo(.body)
            Spacer(minLength: Space.x4)
            GlassIconButton(
                systemName: "trash",
                label: "Remove \(word)",
                tint: Tint.danger,
                action: onDelete
            )
            .opacity(hover.isHovering ? 1 : 0)
            .allowsHitTesting(hover.isHovering)
            .accessibilityHidden(!hover.isHovering)
        }
        .padding(.horizontal, Space.rowPaddingH)
        .padding(.vertical, Space.x1)
        .frame(minHeight: 34)
        .rowFill(isHovering: hover.isHovering)
        .contentShape(Radius.rect(Radius.control))
        .contextMenu {
            Button("Remove \(word)", role: .destructive, action: onDelete)
        }
        .onHover { hovering in
            hover.isHovering = hovering
        }
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Snippets

@MainActor
private final class SnippetsViewModel: ObservableObject {
    @Published var newTrigger = ""
    @Published var newText = ""
    @Published var searchText = ""
    @Published var exportedMessage = ""

    var canAdd: Bool {
        !newTrigger.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func addSnippet(userData: UserData, listCurve: Animation) {
        let t = newTrigger.trimmingCharacters(in: .whitespaces)
        let e = newText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !e.isEmpty else { return }
        withAnimation(listCurve) {
            userData.snippets.append((trigger: t, expansion: e))
        }
        userData.save()
        newTrigger = ""
        newText = ""
    }

    func addSpecificSnippet(trigger: String, text: String, userData: UserData, listCurve: Animation) {
        guard !userData.snippets.contains(where: { $0.trigger == trigger }) else { return }
        withAnimation(listCurve) {
            userData.snippets.append((trigger: trigger, expansion: text))
        }
        userData.save()
    }

    func exportSnippets(userData: UserData) {
        let dictArray = userData.snippets.map { ["trigger": $0.trigger, "expansion": $0.expansion] }
        if let data = try? JSONSerialization.data(withJSONObject: dictArray, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            exportedMessage = "CSV Copied!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.exportedMessage = ""
            }
        }
    }

    func remove(at index: Int, userData: UserData, listCurve: Animation) {
        guard userData.snippets.indices.contains(index) else { return }
        withAnimation(listCurve) {
            _ = userData.snippets.remove(at: index)
        }
        userData.save()
    }
}

struct SnippetsView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var model = SnippetsViewModel()
    @FocusState private var expansionFocused: Bool

    private var listCurve: Animation {
        motion.reduceMotion ? Motion.reduced : Motion.listChange
    }

    private var filteredSnippets: [(trigger: String, expansion: String)] {
        if model.searchText.isEmpty {
            return userData.snippets
        }
        return userData.snippets.filter {
            $0.trigger.localizedCaseInsensitiveContains(model.searchText) ||
            $0.expansion.localizedCaseInsensitiveContains(model.searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            ContentSection(title: "New snippet", systemImage: "text.badge.plus") {
                Text("Say the trigger phrase and Utter types the full text.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.x2) {
                    GlassTextField(placeholder: "Trigger phrase", text: $model.newTrigger)
                        .frame(width: 170)
                    GlassTextField(placeholder: "Expands to…", text: $model.newText)
                    GlassButton(title: "Add", prominent: true) {
                        model.addSnippet(userData: userData, listCurve: listCurve)
                    }
                    .disabled(!model.canAdd)
                }

                // Quick Add Snippet Packs
                HStack(spacing: Space.x2) {
                    Text("Packs:").font(.caption2).foregroundStyle(Ink.secondary)
                    SnippetPackButton(label: "✉️ Sign-off", trigger: "my sign", expansion: "Best regards,\nAlex") { t, e in
                        model.addSpecificSnippet(trigger: t, text: e, userData: userData, listCurve: listCurve)
                    }
                    SnippetPackButton(label: "📅 Date & Time", trigger: "insert date", expansion: "[date] [time]") { t, e in
                        model.addSpecificSnippet(trigger: t, text: e, userData: userData, listCurve: listCurve)
                    }
                    SnippetPackButton(label: "📝 Meeting", trigger: "meeting template", expansion: "## Meeting Notes\n- Attendees:\n- Key Points:\n- Action Items:") { t, e in
                        model.addSpecificSnippet(trigger: t, text: e, userData: userData, listCurve: listCurve)
                    }
                    SnippetPackButton(label: "🚀 LGTM", trigger: "lgtm note", expansion: "LGTM! Verified build and test suite passes. 🚀") { t, e in
                        model.addSpecificSnippet(trigger: t, text: e, userData: userData, listCurve: listCurve)
                    }
                }
                .padding(.top, 2)

                // Placeholder buttons - click to insert into the expansion field.
                VStack(alignment: .leading, spacing: Space.x2) {
                    Section {
                        FlowLayout(spacing: Space.x2) {
                            ForEach(SnippetTemplates.availablePlaceholders, id: \.token) { item in
                                Button {
                                    model.newText.append(item.token)
                                    expansionFocused = true
                                } label: {
                                    Text(item.token).monospaced()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help(item.description)
                            }
                        }
                    } header: {
                        SectionHeader(title: "Placeholders")
                    } footer: {
                        Text("Placeholders are filled in when the snippet runs. Text without [brackets] is typed as written.")
                            .typo(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, Space.x1)
            }

            if userData.snippets.isEmpty {
                EmptyStateView(
                    icon: "text.badge.plus",
                    title: "No snippets yet",
                    message: "Say a short trigger phrase and Utter types the full text. "
                        + "For example, say \u{201C}my email\u{201D} to type your address."
                )
            } else {
                ContentSection(
                    title: "Your snippets",
                    systemImage: "text.quote",
                    accessory: AnyView(
                        HStack(spacing: Space.x2) {
                            if !model.exportedMessage.isEmpty {
                                Text(model.exportedMessage)
                                    .font(.caption2)
                                    .foregroundStyle(Tint.successText)
                            }
                            Button(action: { model.exportSnippets(userData: userData) }) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                                    .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Text("\(userData.snippets.count)")
                                .typo(.caption, ink: Ink.tertiary)
                        }
                    )
                ) {
                    // Live Search Bar
                    HStack(spacing: Space.x2) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(Ink.secondary)
                        TextField("Search triggers or expansions…", text: $model.searchText)
                            .textFieldStyle(.plain)
                            .font(.caption)
                    }
                    .padding(6)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    GlassCluster(spacing: 0) {
                        VStack(spacing: Space.x1) {
                            ForEach(Array(filteredSnippets.enumerated()), id: \.offset) { _, item in
                                SnippetRow(
                                    trigger: item.trigger,
                                    expansion: item.expansion
                                ) {
                                    if let idx = userData.snippets.firstIndex(where: { $0.trigger == item.trigger && $0.expansion == item.expansion }) {
                                        model.remove(at: idx, userData: userData, listCurve: listCurve)
                                    }
                                }
                            }
                        }
                    }
                    .animation(listCurve, value: userData.snippets.count)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SnippetPackButton: View {
    let label: String
    let trigger: String
    let expansion: String
    let onAdd: (String, String) -> Void

    var body: some View {
        Button(action: { onAdd(trigger, expansion) }) {
            Text(label).font(.caption2.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}

private struct SnippetRow: View {
    let trigger: String
    let expansion: String
    let onDelete: () -> Void

    @StateObject private var hover = RowHoverModel()
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        HStack(spacing: Space.x2) {
            Text(trigger).typo(.bodyEmphasis)
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(Ink.tertiary)
            Text(expansion)
                .typo(.body, ink: Ink.secondary)
                .lineLimit(1)
            if SnippetTemplates.hasPlaceholders(expansion) {
                GlassChip(text: "dynamic", systemImage: "wand.and.stars", tint: Tint.accent)
                    .help("Contains placeholders that are filled in when used")
            }
            Spacer(minLength: Space.x4)
            GlassIconButton(
                systemName: "trash",
                label: "Remove \(trigger)",
                tint: Tint.danger,
                action: onDelete
            )
            .opacity(hover.isHovering ? 1 : 0)
            .allowsHitTesting(hover.isHovering)
            .accessibilityHidden(!hover.isHovering)
        }
        .padding(.horizontal, Space.rowPaddingH)
        .padding(.vertical, Space.x1)
        .frame(minHeight: 34)
        .rowFill(isHovering: hover.isHovering)
        .contentShape(Radius.rect(Radius.control))
        .contextMenu {
            Button("Remove \(trigger)", role: .destructive, action: onDelete)
        }
        .onHover { hovering in
            hover.isHovering = hovering
        }
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Style

@MainActor
private final class StyleViewModel: ObservableObject {
    @Published var editingCommand: CustomAICommand?
    @Published var isCreatingNew = false
}

struct StyleView: View {
    @ObservedObject private var userData = UserData.shared
    @StateObject private var model = StyleViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            Text("Restyle, translate, or transform any text by voice. Dictate something first, or select text in any app, then hold \(userData.hotkeyName) and speak a command.")
                .typo(.lede)
                .fixedSize(horizontal: false, vertical: true)

            // Your custom commands - listed first since they override built-ins
            CustomCommandsSection(
                commands: userData.customAICommands,
                onAdd: { model.isCreatingNew = true },
                onEdit: { model.editingCommand = $0 },
                onDelete: { id in
                    userData.customAICommands.removeAll { $0.id == id }
                    userData.save()
                }
            )

            // Style commands
            CommandSection(title: "Restyle text", icon: "textformat.alt", commands: [
                CommandInfo(phrase: "Make it professional", description: "Rewrites in a business-appropriate tone"),
                CommandInfo(phrase: "Make it concise", description: "Removes filler words, shortens text"),
                CommandInfo(phrase: "Make it casual", description: "Rewrites in a relaxed, friendly tone"),
                CommandInfo(phrase: "Make it formal", description: "Rewrites in academic/official tone"),
            ])

            CommandSection(title: "Transform text", icon: "wand.and.stars", commands: [
                CommandInfo(phrase: "Translate to [language]", description: "Translates to any language (Spanish, Hindi, French, etc.)"),
                CommandInfo(phrase: "Fix this", description: "Corrects grammar, spelling, and punctuation"),
                CommandInfo(phrase: "Summarize this", description: "Condenses text to 1-3 sentences"),
                CommandInfo(phrase: "Reply to this", description: "Generates a professional reply to selected text"),
            ])

            CommandSection(title: "Edit what you just said", icon: "arrow.uturn.backward.circle", commands: [
                CommandInfo(phrase: "Make it shorter / longer", description: "Tightens or expands the last result"),
                CommandInfo(phrase: "Make it polite / direct", description: "Softens or sharpens the tone"),
                CommandInfo(phrase: "Fix the punctuation", description: "Repunctuates without changing words"),
                CommandInfo(phrase: "Remove the last sentence", description: "Drops the final sentence"),
                CommandInfo(phrase: "Change that to [anything]", description: "Free-form edit, e.g. \u{201C}change that to past tense\u{201D}"),
            ])

            CommandSection(title: "Keyboard actions", icon: "keyboard", commands: [
                CommandInfo(phrase: "Delete that / Undo that", description: "Undoes the last action (Cmd+Z)"),
                CommandInfo(phrase: "Select all", description: "Selects all text (Cmd+A)"),
                CommandInfo(phrase: "New line / New paragraph", description: "Inserts line break(s)"),
                CommandInfo(phrase: "Copy that / Paste that", description: "Copy or paste clipboard"),
            ])

            // How it works
            ContentSection(title: "How it works", systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: Space.x3) {
                    HowToStep(number: 1, text: "Dictate text, or select existing text in any app.")
                    HowToStep(number: 2, text: "Hold \(userData.hotkeyName) and speak a command - for example, \u{201C}make it professional\u{201D}.")
                    HowToStep(number: 3, text: "Release the key. The original text is replaced with the result.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $model.isCreatingNew) {
            CustomCommandEditor(command: nil) { newCommand in
                userData.customAICommands.append(newCommand)
                userData.save()
            }
        }
        .sheet(item: $model.editingCommand) { command in
            CustomCommandEditor(command: command) { updated in
                if let idx = userData.customAICommands.firstIndex(where: { $0.id == updated.id }) {
                    userData.customAICommands[idx] = updated
                    userData.save()
                }
            }
        }
    }
}

// MARK: - Custom Commands Section

struct CustomCommandsSection: View {
    let commands: [CustomAICommand]
    let onAdd: () -> Void
    let onEdit: (CustomAICommand) -> Void
    let onDelete: (UUID) -> Void

    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        ContentSection(
            title: "Your commands",
            systemImage: "slider.horizontal.3",
            accessory: AnyView(
                GlassButton(title: "New command", systemImage: "plus", size: .small, action: onAdd)
            )
        ) {

            if commands.isEmpty {
                VStack(alignment: .leading, spacing: Space.x2) {
                    Text("Define your own voice commands. Each pairs a trigger phrase with an instruction, and runs on-device.")
                        .typo(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Example: \u{201C}make it a commit\u{201D} \u{2192} rewrite selected notes into a conventional commit message.")
                        .typo(.caption, ink: Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                GlassCluster(spacing: 0) {
                    VStack(spacing: Space.x1) {
                        ForEach(commands) { cmd in
                            CustomCommandRow(
                                command: cmd,
                                onEdit: { onEdit(cmd) },
                                onDelete: { onDelete(cmd.id) }
                            )
                        }
                    }
                }
                // See `DictionaryView.listCurve` - these rows carry the same
                // `.move(edge: .top)` transition.
                .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange,
                           value: commands.count)
            }
        }
    }
}

// MARK: - Custom Command Editor Sheet

@MainActor
private final class CustomCommandEditorModel: ObservableObject {
    @Published var trigger: String = ""
    @Published var systemPrompt: String = ""
    @Published var userPromptTemplate: String = ""
    @Published var replacesSelection: Bool = true
    @Published var sampleInput: String = "feat(auth): add local keychain storage"
    @Published var testOutput: String = ""
    @Published var isTesting: Bool = false

    func load(command: CustomAICommand?) {
        if let c = command {
            trigger = c.trigger
            systemPrompt = c.systemPrompt
            userPromptTemplate = c.userPromptTemplate
            replacesSelection = c.replacesSelection
        }
    }

    var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespaces).isEmpty &&
        !systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func runTestTransform() {
        isTesting = true
        testOutput = ""
        Task {
            do {
                let prompt = userPromptTemplate.isEmpty ? sampleInput : userPromptTemplate.replacingOccurrences(of: "{{text}}", with: sampleInput)
                let res = try await LocalAIEngine.rewrite(
                    instructions: systemPrompt,
                    prompt: prompt
                )
                await MainActor.run {
                    self.isTesting = false
                    self.testOutput = res
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.testOutput = "Model response: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct CustomCommandEditor: View {
    let command: CustomAICommand?
    let onSave: (CustomAICommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var model = CustomCommandEditorModel()

    private var isEditing: Bool { command != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.groupGap) {
                HStack {
                    VStack(alignment: .leading, spacing: Space.x1) {
                        Text(isEditing ? "Edit Transform" : "New AI Transform").typo(.heading)
                        Text("Runs privately on-device via Apple Intelligence.").typo(.caption)
                    }
                    Spacer()
                    GlassChip(text: "Apple Intelligence", systemImage: "sparkles")
                }

                EditorField(
                    label: "Trigger phrase",
                    hint: "What you’ll say. Matching ignores case and trailing punctuation."
                ) {
                    GlassTextField(placeholder: "e.g. make it a commit", text: $model.trigger)
                }

                EditorField(
                    label: "Instruction",
                    hint: "What the model should do. Example: \u{201C}Convert this into a conventional commit message under 72 characters.\u{201D}"
                ) {
                    GlassTextEditor(text: $model.systemPrompt, minHeight: 72)
                }

                EditorField(
                    label: "Prompt template",
                    hint: "Optional. Click a variable tag below to insert into template."
                ) {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        GlassTextField(
                            placeholder: "Use {{text}} to inject the source text",
                            text: $model.userPromptTemplate,
                            mono: true
                        )

                        HStack(spacing: Space.x2) {
                            Text("Insert variable:").font(.caption).foregroundStyle(Ink.secondary)
                            Button("{{text}}") {
                                model.userPromptTemplate += "{{text}}"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("{{clipboard}}") {
                                model.userPromptTemplate += "{{clipboard}}"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("{{date}}") {
                                model.userPromptTemplate += "{{date}}"
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // Interactive Test Playground
                ContentSection(title: "Test Run Playground", systemImage: "play.circle.fill", tint: Color.purple) {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        Text("Preview how this transform processes sample text:").font(.caption).foregroundStyle(Ink.secondary)
                        
                        GlassTextField(placeholder: "Sample input text...", text: $model.sampleInput)

                        HStack {
                            GlassButton(title: model.isTesting ? "Transforming…" : "Run Test", systemImage: "sparkles") {
                                model.runTestTransform()
                            }
                            .disabled(model.isTesting || model.sampleInput.isEmpty || model.systemPrompt.isEmpty)

                            Spacer()
                        }

                        if !model.testOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Output:").font(.caption.weight(.semibold)).foregroundStyle(Ink.secondary)
                                Text(model.testOutput)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(Space.x3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                GlassToggle(
                    title: "Replace the selected text",
                    description: model.replacesSelection
                        ? "The result overwrites your selection."
                        : "The result is appended after the cursor, like a reply.",
                    isOn: $model.replacesSelection
                )
                .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange,
                           value: model.replacesSelection)

                HStack(spacing: Space.x2) {
                    Spacer()
                    GlassButton(title: "Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    GlassButton(
                        title: isEditing ? "Save changes" : "Create Transform",
                        prominent: true
                    ) {
                        var cmd = command ?? CustomAICommand(
                            trigger: "",
                            systemPrompt: "",
                            userPromptTemplate: "",
                            replacesSelection: true
                        )
                        cmd.trigger = model.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                        cmd.systemPrompt = model.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        cmd.userPromptTemplate = model.userPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                        cmd.replacesSelection = model.replacesSelection
                        onSave(cmd)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.isValid)
                }
            }
            .padding(Space.x6)
        }
        .frame(width: 560, height: 600)
        .background(SheetBacking())
        .onAppear {
            model.load(command: command)
        }
    }
}

struct CommandInfo {
    let phrase: String
    let description: String
}

struct CommandSection: View {
    let title: String
    let icon: String
    let commands: [CommandInfo]

    var body: some View {
        ContentSection(title: title, systemImage: icon) {
            VStack(spacing: Space.x1) {
                ForEach(commands.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: Space.x3) {
                        Text("\u{201C}\(commands[i].phrase)\u{201D}")
                            .typo(.bodyEmphasis)
                            .frame(width: 210, alignment: .leading)
                        Text(commands[i].description)
                            .typo(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Space.x2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Shared feature-screen rows

private struct HowToStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.x3) {
            Text("\(number)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tint.accentText)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Tint.accentSoft))
                .overlay(Circle().strokeBorder(Tint.accentRim, lineWidth: 0.5))
            Text(text)
                .typo(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CustomCommandRow: View {
    let command: CustomAICommand
    let onEdit: () -> Void
    let onDelete: () -> Void

    @StateObject private var hover = RowHoverModel()
    @ObservedObject private var motion = MotionPreference.shared

    var body: some View {
        HStack(alignment: .top, spacing: Space.x3) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\u{201C}\(command.trigger)\u{201D}").typo(.bodyEmphasis)
                Text(command.systemPrompt)
                    .typo(.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Space.x3)

            GlassChip(
                text: command.replacesSelection ? "replaces" : "appends",
                systemImage: command.replacesSelection
                    ? "arrow.triangle.2.circlepath" : "text.append"
            )
            .help(command.replacesSelection
                  ? "Replaces the selected text" : "Appends after the cursor")

            HStack(spacing: 2) {
                GlassIconButton(systemName: "pencil",
                                label: "Edit \(command.trigger)", action: onEdit)
                GlassIconButton(systemName: "trash",
                                label: "Delete \(command.trigger)",
                                tint: Tint.danger, action: onDelete)
            }
            .opacity(hover.isHovering ? 1 : 0)
            .allowsHitTesting(hover.isHovering)
            .accessibilityHidden(!hover.isHovering)
        }
        .padding(.horizontal, Space.rowPaddingH)
        .padding(.vertical, Space.x2)
        .rowFill(isHovering: hover.isHovering)
        .contentShape(Radius.rect(Radius.control))
        .contextMenu {
            Button("Edit \(command.trigger)", action: onEdit)
            Divider()
            Button("Delete \(command.trigger)", role: .destructive, action: onDelete)
        }
        .onHover { hovering in
            hover.isHovering = hovering
        }
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

/// A labelled field with a hint beneath it, for the command editor.
///
/// A real `Section`: the label is the `header:` and the hint is the `footer:`, which
/// is exactly what they are. Before this they were two anonymous `Text` siblings of
/// the control, so nothing in the view tree said that the first line named the field
/// and the last line explained it. The enclosing `VStack` and its `Space.x2` stay  - 
/// a `Section` outside a `List` is flattened into its parent's layout, so the parent
/// is what spaces header from content from footer, and this keeps the field's rhythm
/// byte-identical to what it was. `Section` is macOS 10.15; the three-slot
/// `Section(content:header:footer:)` initialiser likewise.
///
/// **Not `LabeledContent`, and not inside a `Form`** - the two things that would give
/// the label a real control association. Both change the layout to horizontal:
/// `LabeledContent`'s default style puts content at the trailing edge, and `Form`'s
/// `.columns` style aligns labels into a right-aligned column. That is the correct
/// macOS look for short fields, and it is a genuine improvement over what is here  - 
/// but one of the three fields is an 84pt-tall `GlassTextEditor`, the sheet is a fixed
/// `.frame(width: 540)` whose height comes from its content, and whether `Form`
/// introduces a scroll container (and so stops publishing an intrinsic height) is not
/// answerable from the SDK. This app has already resized its own window twice from an
/// intrinsic size propagating through `NSHostingView` - see the workspace sizing notes - so that
/// is not a change to make without the app on screen. Routed rather than guessed.
private struct EditorField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            Section {
                content()
            } header: {
                Text(label).typo(.captionEmphasis, ink: Ink.primary)
            } footer: {
                if let hint {
                    Text(hint)
                        .typo(.caption, ink: Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Backing for a modal sheet.
///
/// Backing for the command editor sheet: `NSVisualEffectView` with the `.sheet`
/// material, plus a themed veil over it, and an opaque surface under Reduce
/// Transparency.
///
/// **This is not glass, and the comment here used to say it was** - "this is
/// `.regular` glass over a scrim rather than clear glass". No branch of this view
/// calls `glassEffect`, on any OS version. What it actually is is the same two-layer
/// standard-material build every window shell in the app uses, which is also the
/// correct choice: the sheet is full of text fields and a multi-line editor, and
/// GlassSurface.swift is explicit that the content layer takes standard materials.
/// The description was the only thing wrong.
///
/// The `#available(macOS 26.0, *)` split is a *tuning knob*, not an API fallback  - 
/// both branches call exactly the same two views and differ only in the veil. That is
/// legitimate (`Veil`'s own note explains why: with no Liquid Glass above it the same
/// veil reads heavier below 26, and a sheet is the one role whose pre-26 tuning goes
/// up rather than down, because it must stay readable over a window still visible
/// behind it) - but it is worth knowing it is a tuning branch, since it looks like a
/// capability check and would be deleted as one. Left in place; the 13.3 floor is real.
///
/// Re-asked during the pass that gave the Settings window's navigation column real
/// glass, because a sheet *is* a floating surface and the caller's comment above says
/// so ("the sheet floats above the window, so it belongs to the glass layer"). The
/// answer is still no, on two counts:
///
///   * **What floats is the sheet's window, not a layer inside it.** AppKit draws the
///     sheet's own shadow, corner radius and animation; that framing is what expresses
///     "above the window", and there is no `NSWindow` glass API to add to it. Inside
///     the panel there is no chrome layer at all - it is one form, top to bottom.
///   * **The form is content, and unusually text-heavy content**: three labelled
///     fields, a multi-line `GlassTextEditor`, and hint prose under each. Glassing the
///     panel would refract the backdrop behind every text field on it, and the button
///     row at its foot is not flush to an edge - it is the last row of the form, so a
///     glass band there would be glass in the middle of content.
///
/// The controls in the row already carry the sheet's glass: `GlassButton` resolves to
/// `.glass` / `.glassProminent` on macOS 26. That is the correct division - glass on
/// the controls, standard material behind the prose.
private struct SheetBacking: View {
    @ObservedObject private var motion = MotionPreference.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        if motion.reduceTransparency {
            Surface.canvas
        } else if #available(macOS 26.0, *) {
            ZStack {
                WindowBacking(material: .sheet)
                // A sheet is a window shell, so it takes that role's veil. 0.40 → 0.42
                // in light mode is the only drift this removes.
                Surface.canvas.opacity(Veil.windowShell(isDark: isDark))
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                WindowBacking(material: .sheet)
                Surface.canvas.opacity(Veil.sheetLegacy(isDark: isDark))
            }
            .ignoresSafeArea()
        }
    }
}
