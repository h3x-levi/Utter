import SwiftUI
import UtterCore

struct DictionarySection: View {
    @Bindable var model: WordsViewModel
    @FocusState private var focus: Field?

    private enum Field { case add, search }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader("Your dictionary", subtitle: "Utter spells these your way.") {
                if !model.words.isEmpty {
                    TextField("Search words", text: $model.wordQuery)
                        .focused($focus, equals: .search)
                        .accessibilityLabel("Search words")
                        .fieldBox(icon: "magnifyingglass")
                        .frame(width: 180)
                    Button("Copy all") { model.copyAllWords() }
                        .buttonStyle(Look.ActionStyle())
                }
            }
            if model.dictionaryIsEmpty {
                EmptyNote(title: "No words yet",
                          message: "Add the names and terms Utter gets wrong, and it will spell them your way.")
            } else if model.filteredWords.isEmpty, !model.words.isEmpty {
                EmptyNote(title: "No matches", message: "No word matches \u{201C}\(model.wordQuery)\u{201D}.")
            }
            FlowStack {
                ForEach(model.filteredWords, id: \.self) { word in
                    WordChip(word: word) { model.removeWords([word]) }
                }
                addField
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            if !model.suggestions.isEmpty { suggestions }
        }
        .contentCard()
        .background { shortcuts }
    }

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            TextField("Add a word", text: $model.newWord)
                .textFieldStyle(.plain)
                .focused($focus, equals: .add)
                .onSubmit { model.submitNewWord() }
                .accessibilityLabel("New word")
                .frame(width: 120)
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 11)
        .frame(height: 26)
        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Look.Color.edge) }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            RowRule()
            CardHeader("From your recent dictations", subtitle: "Click one to add it.")
            FlowStack {
                ForEach(model.suggestions, id: \.self) { word in
                    Button { model.addWord(word) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                            Text(word)
                        }
                        .chip()
                        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Look.Color.edge) }
                    }
                    .buttonStyle(Look.RowStyle(radius: 11, scale: Look.Press.button))
                    .accessibilityLabel("Add \(word) to the dictionary")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
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

private struct WordChip: View {
    let word: String
    let remove: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Text(word)
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovering ? 1 : 0.35)
            .accessibilityLabel("Remove \(word)")
        }
        .chip(trailing: 8)
        .background(Look.Color.hover, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .offset(y: hovering && !reduceMotion ? -1 : 0)
        .animation(Look.Motion.press.animation(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .contextMenu { Button("Remove", role: .destructive, action: remove) }
    }
}

private extension View {
    func chip(trailing: CGFloat = 11) -> some View {
        font(.system(size: 12.5))
            .padding(.leading, 11)
            .padding(.trailing, trailing)
            .frame(height: 26)
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct SnippetsSection: View {
    @Bindable var model: WordsViewModel
    @FocusState private var focus: Field?

    private enum Field: Hashable { case trigger, expansion, search, draftTrigger, draftExpansion }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader("Snippets", subtitle: "Say a short phrase and Utter types the full text.") {
                if !model.snippets.isEmpty {
                    TextField("Search snippets", text: $model.snippetQuery)
                        .focused($focus, equals: .search)
                        .accessibilityLabel("Search snippets")
                        .fieldBox(icon: "magnifyingglass")
                        .frame(width: 180)
                }
                Menu("Add a pack") {
                    ForEach(SnippetPack.all) { pack in
                        Button(pack.name) { model.addPack(pack) }
                            .disabled(model.isInstalled(pack))
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .fixedSize()
            }
            addRow
            Text("Placeholders like [date] and [clipboard] are filled in when the snippet runs.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 8)
            if model.snippets.isEmpty {
                EmptyNote(title: "No snippets yet", message: "Add a phrase and what it should type, or start from a pack.")
            } else if model.filteredSnippets.isEmpty {
                EmptyNote(title: "No matches", message: "No snippet matches \u{201C}\(model.snippetQuery)\u{201D}.")
            }
            ForEach(model.filteredSnippets) { snippet in
                if snippet.id != model.filteredSnippets.first?.id { RowRule() }
                if model.editingSnippetID == snippet.id { editor } else { row(snippet) }
            }
        }
        .contentCard()
        .background { shortcuts }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("When I say", text: $model.newTrigger)
                .focused($focus, equals: .trigger)
                .onSubmit { focus = .expansion }
                .fieldBox()
                .frame(width: 150)
            TextField("Type this", text: $model.newExpansion)
                .focused($focus, equals: .expansion)
                .onSubmit { model.submitNewSnippet() }
                .fieldBox()
            Menu {
                ForEach(SnippetTemplates.availablePlaceholders, id: \.token) { item in
                    Button("\(item.token)  \(item.description)") { model.newExpansion += item.token }
                }
            } label: { Text("Insert") }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .fixedSize()
                .accessibilityLabel("Insert a placeholder")
            Button("Add") { model.submitNewSnippet() }
                .buttonStyle(Look.ActionStyle(prominent: true))
                .disabled(!model.canAddSnippet)
        }
        .padding(.horizontal, 12)
    }

    private func row(_ snippet: SnippetItem) -> some View {
        let edit = { model.beginEditing(snippet); focus = .draftTrigger }
        return ActionRow(action: edit, removeLabel: "Remove \(snippet.trigger)", remove: { model.removeSnippets([snippet.id]) }) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\u{201C}\(snippet.trigger)\u{201D}")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)
                Text(snippet.expansion)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityHint("Edit")
        .contextMenu {
            Button("Edit", action: edit)
            Button("Remove", role: .destructive) { model.removeSnippets([snippet.id]) }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("When I say", text: $model.draftTrigger)
                .focused($focus, equals: .draftTrigger)
                .onSubmit { focus = .draftExpansion }
                .fieldBox()
            TextField("Type this", text: $model.draftExpansion, axis: .vertical)
                .lineLimit(1...6)
                .focused($focus, equals: .draftExpansion)
                .onSubmit { model.saveEdit() }
                .fieldBox()
            HStack {
                Spacer()
                Button("Cancel") { model.cancelEdit() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(Look.ActionStyle())
                Button("Save") { model.saveEdit() }
                    .buttonStyle(Look.ActionStyle(prominent: true))
                    .disabled(!model.canSaveEdit)
            }
        }
        .padding(12)
        .background(Look.Color.hover, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var shortcuts: some View {
        VStack {
            Button("Find") { focus = .search }.keyboardShortcut("f")
            Button("New snippet") { focus = .trigger }.keyboardShortcut("n")
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}

/// A list row that acts when clicked, with its remove button shown on hover.
struct ActionRow<Content: View>: View {
    let action: () -> Void
    let removeLabel: String
    let remove: () -> Void
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.leading, 12)
                .padding(.trailing, 40)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        }
        .buttonStyle(Look.RowStyle())
        .overlay(alignment: .trailing) {
            Button(action: remove) { Image(systemName: "trash").frame(width: 26, height: 26) }
                .buttonStyle(Look.RowStyle(radius: 8, scale: Look.Press.button))
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
                .accessibilityLabel(removeLabel)
        }
        .onHover { hovering = $0 }
    }
}
