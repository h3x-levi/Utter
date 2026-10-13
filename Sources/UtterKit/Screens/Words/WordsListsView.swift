import SwiftUI
import UtterCore

/// Words: the dictionary, snippets and voice commands, written on the rules.
struct WordsScreen: View {
    @Bindable var model: WordsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Words")
                    .mixtapeCaps(30, tracking: 0.02)
                    .accessibilityAddTraits(.isHeader)
                Text("Names and terms Utter should always hear right, short phrases that expand as you speak, and commands that rewrite your words.")
                    .font(Mixtape.body(13))
                    .foregroundStyle(Mixtape.ink3)
                    .frame(maxWidth: 560, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)
                picker.padding(.top, 18)
                section
                    .id(model.section)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 4)))
                    .padding(.top, 30)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.section)
            .padding(EdgeInsets(top: 22, leading: 34, bottom: 34, trailing: 30))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { model.reload() }
    }

    private var picker: some View {
        HStack(spacing: 6) {
            ForEach(WordsViewModel.Section.allCases) { section in
                let on = model.section == section
                Button { model.section = section } label: {
                    HStack(spacing: 6) {
                        Text(section.rawValue)
                        Text(count(section), format: .number).font(Mixtape.mono(10.5, .semibold)).foregroundStyle(Mixtape.ink3)
                    }
                }
                .buttonStyle(.pen(on ? .outline : .ghost, .small))
                .background { if on { Capsule().fill(Mixtape.wash) } }
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Words section")
    }

    @ViewBuilder
    private var section: some View {
        switch model.section {
        case .dictionary: DictionarySection(model: model)
        case .snippets: SnippetsSection(model: model)
        case .commands: CommandsSection(model: model)
        }
    }

    private func count(_ section: WordsViewModel.Section) -> Int {
        switch section {
        case .dictionary: model.words.count
        case .snippets: model.snippets.count
        case .commands: model.commands.count
        }
    }
}

struct DictionarySection: View {
    @Bindable var model: WordsViewModel
    @FocusState private var focus: Field?

    private enum Field { case add, search }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("Your dictionary", detail: model.words.isEmpty ? nil : "\(model.words.count) words")
            WordsHint(text: "Utter spells these your way.")
            if !model.words.isEmpty {
                HStack(spacing: 12) {
                    LineField("Search words", text: $model.wordQuery)
                        .focused($focus, equals: .search)
                        .frame(maxWidth: 220)
                    Spacer(minLength: 0)
                    Button("Copy all") { model.copyAllWords() }.buttonStyle(.pen(.ghost, .small))
                }
                .padding(.top, 10)
            }
            if model.dictionaryIsEmpty {
                WordsHint(text: "No words yet. Add the names and terms Utter gets wrong, and it will spell them your way.", strong: true)
            } else if model.filteredWords.isEmpty, !model.words.isEmpty {
                WordsHint(text: "No word matches \u{201C}\(model.wordQuery)\u{201D}.", strong: true)
            }
            FlowStack(spacing: 0) {
                ForEach(model.filteredWords, id: \.self) { word in
                    WrittenWord(word: word) { model.removeWords([word]) }
                }
                addField
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .top) { RuledBackground() }
            .padding(.top, 8)
            if !model.suggestions.isEmpty { suggestions }
        }
        .background { shortcuts }
    }

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(Mixtape.ink3)
            TextField("Add a word", text: $model.newWord)
                .textFieldStyle(.plain)
                .focused($focus, equals: .add)
                .onSubmit { model.submitNewWord() }
                .accessibilityLabel("New word")
                .frame(width: 130)
        }
        .font(Mixtape.body(13.5))
        .frame(height: Mixtape.ruleSpacing)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("From your recent dictations", detail: "click one to add it")
            FlowStack(spacing: 0) {
                ForEach(model.suggestions, id: \.self) { word in
                    Button { model.addWord(word) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 9, weight: .bold)).foregroundStyle(Mixtape.ink3)
                            Text(word)
                        }
                        .font(Mixtape.body(13.5))
                        .foregroundStyle(Mixtape.ink2)
                        .padding(.trailing, 22)
                        .frame(height: Mixtape.ruleSpacing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(word) to the dictionary")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .top) { RuledBackground() }
        }
        .padding(.top, 34)
    }

    private var shortcuts: some View {
        VStack {
            Button("Find") { focus = .search }.keyboardShortcut("f")
            Button("New word") { focus = .add }.keyboardShortcut("n")
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}

/// A dictionary word written on a line, with its remove mark on hover.
private struct WrittenWord: View {
    let word: String
    let remove: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Text(word).font(Mixtape.body(13.5)).foregroundStyle(Mixtape.ink)
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Mixtape.ink3)
            .opacity(hovering ? 1 : 0)
            .accessibilityLabel("Remove \(word)")
        }
        .padding(.trailing, 22)
        .frame(height: Mixtape.ruleSpacing)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu { Button("Remove", role: .destructive, action: remove) }
    }
}

/// The quiet line under a header, or a stronger one standing in for an empty list.
struct WordsHint: View {
    let text: String
    var strong = false

    var body: some View {
        Text(text)
            .font(Mixtape.body(strong ? 12.5 : 12))
            .foregroundStyle(strong ? Mixtape.ink2 : Mixtape.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, strong ? 14 : 8)
    }
}

extension View {
    /// A plain text field written on one 34 pt line, its ink underline sitting on the rule.
    func inkLine() -> some View {
        textFieldStyle(.plain)
            .font(Mixtape.body(13))
            .foregroundStyle(Mixtape.ink)
            .frame(minHeight: Mixtape.ruleSpacing)
            .overlay(alignment: .bottom) { Rectangle().fill(Mixtape.ink).frame(height: 1.5) }
    }
}

struct SnippetsSection: View {
    @Bindable var model: WordsViewModel
    @FocusState private var focus: Field?

    private enum Field: Hashable { case trigger, expansion, search, draftTrigger, draftExpansion }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("Snippets", detail: model.snippets.isEmpty ? nil : "\(model.snippets.count)")
            WordsHint(text: "Say a short phrase and Utter types the full text. Placeholders like [date] and [clipboard] are filled in when it runs.")
            HStack(spacing: 12) {
                if !model.snippets.isEmpty {
                    LineField("Search snippets", text: $model.snippetQuery)
                        .focused($focus, equals: .search)
                        .frame(maxWidth: 220)
                }
                Spacer(minLength: 0)
                Menu("Add a pack") {
                    ForEach(SnippetPack.all) { pack in
                        Button(pack.name) { model.addPack(pack) }
                            .disabled(model.isInstalled(pack))
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.pen(.ghost, .small))
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.top, 10)
            VStack(alignment: .leading, spacing: 0) {
                addRow
                ForEach(model.filteredSnippets) { snippet in
                    if model.editingSnippetID == snippet.id { editor } else { row(snippet) }
                }
            }
            .background(alignment: .top) { RuledBackground() }
            .padding(.top, 8)
            if model.snippets.isEmpty {
                WordsHint(text: "No snippets yet. Add a phrase and what it should type, or start from a pack.", strong: true)
            } else if model.filteredSnippets.isEmpty {
                WordsHint(text: "No snippet matches \u{201C}\(model.snippetQuery)\u{201D}.", strong: true)
            }
        }
        .background { shortcuts }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            TextField("When I say", text: $model.newTrigger)
                .accessibilityLabel("When I say")
                .focused($focus, equals: .trigger)
                .onSubmit { focus = .expansion }
                .inkLine()
                .frame(width: 150)
            TextField("Type this", text: $model.newExpansion)
                .accessibilityLabel("Type this")
                .focused($focus, equals: .expansion)
                .onSubmit { model.submitNewSnippet() }
                .inkLine()
            Menu {
                ForEach(SnippetTemplates.availablePlaceholders, id: \.token) { item in
                    Button("\(item.token)  \(item.description)") { model.newExpansion += item.token }
                }
            } label: { Text("Insert") }
                .menuStyle(.button)
                .buttonStyle(.pen(.ghost, .small))
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Insert a placeholder")
            Button("Add") { model.submitNewSnippet() }
                .buttonStyle(.pen(.fill, .small))
                .disabled(!model.canAddSnippet)
        }
        .frame(height: Mixtape.ruleSpacing)
    }

    private func row(_ snippet: SnippetItem) -> some View {
        let edit = { model.beginEditing(snippet); focus = .draftTrigger }
        return ActionRow(action: edit, removeLabel: "Remove \(snippet.trigger)", remove: { model.removeSnippets([snippet.id]) }) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\u{201C}\(snippet.trigger)\u{201D}")
                    .fontWeight(.semibold)
                    .frame(width: 150, alignment: .leading)
                Text(snippet.expansion.replacingOccurrences(of: "\n", with: " "))
                    .foregroundStyle(Mixtape.ink2)
            }
        }
        .accessibilityHint("Edit")
        .contextMenu {
            Button("Edit", action: edit)
            Button("Remove", role: .destructive) { model.removeSnippets([snippet.id]) }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("When I say", text: $model.draftTrigger)
                .accessibilityLabel("When I say")
                .focused($focus, equals: .draftTrigger)
                .onSubmit { focus = .draftExpansion }
                .inkLine()
            TextField("Type this", text: $model.draftExpansion, axis: .vertical)
                .accessibilityLabel("Type this")
                .lineLimit(1...6)
                .focused($focus, equals: .draftExpansion)
                .onSubmit { model.saveEdit() }
                .inkLine()
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { model.cancelEdit() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.pen(.ghost, .small))
                Button("Save") { model.saveEdit() }
                    .buttonStyle(.pen(.fill, .small))
                    .disabled(!model.canSaveEdit)
            }
            .frame(height: Mixtape.ruleSpacing)
        }
    }

    private var shortcuts: some View {
        VStack {
            Button("Find") { focus = .search }.keyboardShortcut("f")
            Button("New snippet") { focus = .trigger }.keyboardShortcut("n")
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}

/// A 34 pt row on the rules that acts when clicked, with its remove button shown on hover.
struct ActionRow<Content: View>: View {
    let action: () -> Void
    let removeLabel: String
    let remove: () -> Void
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .font(Mixtape.body(13))
                .foregroundStyle(Mixtape.ink)
                .lineLimit(1)
                .background {
                    if hovering {
                        LinearGradient(stops: [.init(color: .clear, location: 0.58), .init(color: Mixtape.wash, location: 0.58)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
                .padding(.trailing, 40)
                .frame(maxWidth: .infinity, minHeight: Mixtape.ruleSpacing, maxHeight: Mixtape.ruleSpacing, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button(action: remove) { Image(systemName: "trash") }
                .buttonStyle(.inkIcon)
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(hovering)
                .accessibilityLabel(removeLabel)
        }
        .onHover { hovering = $0 }
    }
}

/// Wraps its children onto as many lines as the width needs, like v2's chip sets.
struct FlowStack: SwiftUI.Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        Self.arrange(subviews.map { $0.sizeThatFits(.unspecified) }, width: proposal.width ?? .infinity, spacing: spacing).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let frames = Self.arrange(sizes, width: bounds.width, spacing: spacing).frames
        for (view, frame) in zip(subviews, frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }

    static func arrange(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for size in sizes {
            let item = CGSize(width: min(size.width, width), height: size.height)
            if x > 0, x + item.width > width {
                x = 0
                y += line + spacing
                line = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: item))
            widest = max(widest, x + item.width)
            line = max(line, item.height)
            x += item.width + spacing
        }
        return (frames, CGSize(width: widest, height: y + line))
    }
}
