import SwiftUI

struct DictionarySection: View {
    @Bindable var model: WordsViewModel
    @State private var selection: Set<String> = []
    @FocusState private var focus: Field?

    private enum Field { case add, search }

    var body: some View {
        Look.Well(spacing: Look.Space.x4) {
            HStack(spacing: Look.Space.x2) {
                TextField("Add a name, acronym or term", text: $model.newWord)
                    .focused($focus, equals: .add)
                    .onSubmit { model.submitNewWord() }
                    .accessibilityLabel("New word")
                Button("Add") { model.submitNewWord() }
                    .disabled(model.trimmedNewWord.isEmpty)
            }
            if !model.suggestions.isEmpty { suggestions }
            if model.words.isEmpty {
                Look.EmptyCue(message: "Add the names and terms Utter gets wrong, and it will spell them your way.",
                              actionTitle: "Add a word") { focus = .add }
            } else {
                list
            }
        }
        .background { shortcuts }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Look.Space.x2) {
            Text("From your recent dictations")
                .font(Look.Font.heading)
            ForEach(model.suggestions, id: \.self) { word in
                HStack {
                    Text(word).font(Look.Font.body)
                    Spacer()
                    Button("Add") { model.addWord(word) }
                        .controlSize(.small)
                        .accessibilityLabel("Add \(word) to the dictionary")
                }
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Look.Space.x2) {
            HStack(spacing: Look.Space.x3) {
                TextField("Search words", text: $model.wordQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .search)
                    .frame(maxWidth: 240)
                    .accessibilityLabel("Search words")
                Spacer()
                Text(model.words.count == 1 ? "1 word" : "\(model.words.count) words")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
                Button("Copy all") { model.copyAllWords() }
                    .controlSize(.small)
            }
            List(model.filteredWords, id: \.self, selection: $selection) { word in
                HStack {
                    Text(word).font(Look.Font.body)
                    Spacer()
                    Button { model.removeWords([word]) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Look.Color.inkTertiary)
                        .accessibilityLabel("Remove \(word)")
                }
                .contextMenu { Button("Remove", role: .destructive) { model.removeWords([word]) } }
            }
            .listStyle(.inset)
            .frame(minHeight: 260)
            .onDeleteCommand {
                model.removeWords(selection)
                selection = []
            }
            .overlay {
                if model.filteredWords.isEmpty {
                    Text("No word matches \u{201C}\(model.wordQuery)\u{201D}.")
                        .font(Look.Font.secondary)
                        .foregroundStyle(Look.Color.inkSecondary)
                }
            }
        }
    }

    private var shortcuts: some View {
        VStack {
            Button("Find") { focus = .search }.keyboardShortcut("f")
            Button("New word") { focus = .add }.keyboardShortcut("n")
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}

struct SnippetsSection: View {
    @Bindable var model: WordsViewModel
    @State private var selection: Set<UUID> = []
    @FocusState private var focus: Field?

    private enum Field: Hashable { case trigger, expansion, search, draftTrigger, draftExpansion }

    var body: some View {
        Look.Well(spacing: Look.Space.x4) {
            VStack(alignment: .leading, spacing: Look.Space.x2) {
                Text("Say a short phrase and Utter types the full text.")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
                HStack(spacing: Look.Space.x2) {
                    TextField("When I say", text: $model.newTrigger)
                        .focused($focus, equals: .trigger)
                        .onSubmit { focus = .expansion }
                        .frame(maxWidth: 190)
                    TextField("Type this", text: $model.newExpansion)
                        .focused($focus, equals: .expansion)
                        .onSubmit { model.submitNewSnippet() }
                    Menu {
                        ForEach(SnippetTemplates.availablePlaceholders, id: \.token) { item in
                            Button("\(item.token)  \(item.description)") { model.newExpansion += item.token }
                        }
                    } label: { Text("Insert") }
                        .fixedSize()
                        .accessibilityLabel("Insert a placeholder")
                    Button("Add") { model.submitNewSnippet() }
                        .disabled(!model.canAddSnippet)
                }
                HStack {
                    Text("Placeholders like [date] and [clipboard] are filled in when the snippet runs.")
                        .font(Look.Font.secondary)
                        .foregroundStyle(Look.Color.inkTertiary)
                    Spacer()
                    Menu("Add a pack") {
                        ForEach(SnippetPack.all) { pack in
                            Button(pack.name) { model.addPack(pack) }
                                .disabled(model.isInstalled(pack))
                        }
                    }
                    .fixedSize()
                }
            }
            if model.snippets.isEmpty {
                Look.EmptyCue(message: "Add a phrase and what it should type, or start from a pack.",
                              actionTitle: "Add a snippet") { focus = .trigger }
            } else {
                list
            }
        }
        .background { shortcuts }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Look.Space.x2) {
            HStack {
                TextField("Search snippets", text: $model.snippetQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .search)
                    .frame(maxWidth: 240)
                    .accessibilityLabel("Search snippets")
                Spacer()
                Text(model.snippets.count == 1 ? "1 snippet" : "\(model.snippets.count) snippets")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
            }
            List(model.filteredSnippets, selection: $selection) { snippet in
                if model.editingSnippetID == snippet.id { editor } else { row(snippet) }
            }
            .listStyle(.inset)
            .frame(minHeight: 260)
            .onDeleteCommand {
                model.removeSnippets(selection)
                selection = []
            }
        }
    }

    private func row(_ snippet: SnippetItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Look.Space.x3) {
            VStack(alignment: .leading, spacing: Look.Space.x1) {
                Text("\u{201C}\(snippet.trigger)\u{201D}").font(Look.Font.body.weight(.medium))
                Text(snippet.expansion)
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Button { model.beginEditing(snippet); focus = .draftTrigger } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit \(snippet.trigger)")
            Button { model.removeSnippets([snippet.id]) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(snippet.trigger)")
        }
        .foregroundStyle(Look.Color.ink)
        .contextMenu {
            Button("Edit") { model.beginEditing(snippet); focus = .draftTrigger }
            Button("Remove", role: .destructive) { model.removeSnippets([snippet.id]) }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Look.Space.x2) {
            TextField("When I say", text: $model.draftTrigger)
                .focused($focus, equals: .draftTrigger)
                .onSubmit { focus = .draftExpansion }
            TextField("Type this", text: $model.draftExpansion, axis: .vertical)
                .lineLimit(1...6)
                .focused($focus, equals: .draftExpansion)
                .onSubmit { model.saveEdit() }
            HStack {
                Spacer()
                Button("Cancel") { model.cancelEdit() }.keyboardShortcut(.cancelAction)
                Button("Save") { model.saveEdit() }.disabled(!model.canSaveEdit)
            }
        }
        .padding(.vertical, Look.Space.x1)
    }

    private var shortcuts: some View {
        VStack {
            Button("Find") { focus = .search }.keyboardShortcut("f")
            Button("New snippet") { focus = .trigger }.keyboardShortcut("n")
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}
