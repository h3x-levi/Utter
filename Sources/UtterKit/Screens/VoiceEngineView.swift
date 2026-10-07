import SwiftUI
import AppKit

@MainActor
final class VoiceEngineViewModel: ObservableObject {
    @Published var selectedSection: VoiceEngineSection = .vocabulary
    @Published var newWord: String = ""
    @Published var searchWordText: String = ""
    @Published var newSnippetTrigger: String = ""
    @Published var newSnippetExpansion: String = ""
    @Published var isAddingSnippet: Bool = false
    @Published var playgroundInput: String = "hey team just finished the kubernetes cluster deployment and all pods are healthy let me know if you want to sync later today"
    @Published var playgroundOutput: String = ""
    @Published var isTransforming: Bool = false
    @Published var feedbackMessage: String? = nil

    func showFeedback(_ message: String) {
        feedbackMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.feedbackMessage == message {
                self?.feedbackMessage = nil
            }
        }
    }
}

struct VoiceEngineView: View {
    @ObservedObject private var userData = UserData.shared
    @StateObject private var model = VoiceEngineViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            // Top Section Picker
            HStack {
                Picker("Voice Engine Section", selection: $model.selectedSection) {
                    ForEach(VoiceEngineSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)

                Spacer()

                if let msg = model.feedbackMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tint.success)
                }
            }
            .padding(.bottom, Space.x2)

            // Active Tab Content
            switch model.selectedSection {
            case .vocabulary:
                vocabularySection
            case .snippets:
                snippetsSection
            case .styles:
                personasSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Vocabulary Tab

    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            ContentSection(
                title: "Custom Vocabulary & Jargon",
                systemImage: "character.book.closed"
            ) {
                Text("Teach Whisper proper nouns, technical acronyms, and teammate names that are usually misrecognized.")
                    .font(.system(size: 13))
                    .foregroundStyle(Ink.secondary)

                HStack(spacing: Space.x2) {
                    GlassTextField(
                        placeholder: "e.g. Kubernetes, GraphQL, or colleague's name",
                        text: $model.newWord,
                        systemImage: "plus.circle"
                    )

                    Button("Add Term") {
                        addWord(model.newWord)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Quick Add Developer & Tech Pack
                HStack(spacing: Space.x2) {
                    Text("Popular tech:")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                    ForEach(["Kubernetes", "GraphQL", "PostgreSQL", "Tailwind", "Whisper"], id: \.self) { tech in
                        Button(tech) {
                            addWord(tech)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(userData.dictionaryWords.contains(tech))
                    }
                }
                .padding(.top, 2)
            }

            Divider()

            ContentSection(
                title: "Your Vocabulary (\(userData.dictionaryWords.count))",
                systemImage: "list.bullet",
                accessory: AnyView(
                    HStack(spacing: Space.x2) {
                        GlassTextField(
                            placeholder: "Search words",
                            text: $model.searchWordText,
                            systemImage: "magnifyingglass"
                        )
                        .frame(width: 180)

                        Button(action: { exportVocabulary() }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Copy all terms")
                    }
                )
            ) {
                if filteredWords.isEmpty {
                    EmptyStateView(
                        icon: "character.book.closed",
                        title: "No custom words yet",
                        message: "Add names, acronyms, and technical terms to ensure 100% accurate transcription."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: Space.x2) {
                            ForEach(filteredWords, id: \.self) { word in
                                HStack {
                                    Text(word)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Button(role: .destructive, action: { removeWord(word) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9))
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, Space.x2)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Line.hairline, lineWidth: 1))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var filteredWords: [String] {
        let query = model.searchWordText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return userData.dictionaryWords }
        return userData.dictionaryWords.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func addWord(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !userData.dictionaryWords.contains(word) else { return }
        userData.dictionaryWords.append(word)
        userData.save()
        model.newWord = ""
        model.showFeedback("Added “\(word)”")
    }

    private func removeWord(_ word: String) {
        userData.dictionaryWords.removeAll { $0 == word }
        userData.save()
        model.showFeedback("Removed “\(word)”")
    }

    private func exportVocabulary() {
        let text = userData.dictionaryWords.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        model.showFeedback("Copied \(userData.dictionaryWords.count) terms")
    }

    // MARK: - Snippets Tab

    private var snippetsSection: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            ContentSection(
                title: "Spoken Snippet Triggers",
                systemImage: "text.quote",
                accessory: AnyView(
                    Button(action: { model.isAddingSnippet.toggle() }) {
                        Label(model.isAddingSnippet ? "Cancel" : "New Snippet", systemImage: model.isAddingSnippet ? "xmark" : "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                )
            ) {
                Text("Spoken triggers that expand into full text templates when dictated.")
                    .font(.system(size: 13))
                    .foregroundStyle(Ink.secondary)

                if model.isAddingSnippet {
                    VStack(alignment: .leading, spacing: Space.x2) {
                        TextField("Spoken trigger phrase (e.g. 'insert zoom link')", text: $model.newSnippetTrigger)
                            .textFieldStyle(.roundedBorder)

                        TextEditor(text: $model.newSnippetExpansion)
                            .font(.system(size: 12))
                            .frame(height: 60)
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Line.hairline))

                        Button("Save Snippet") {
                            addSnippet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(model.newSnippetTrigger.isEmpty || model.newSnippetExpansion.isEmpty)
                    }
                    .padding(Space.x3)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Line.hairline))
                }
            }

            Divider()

            if userData.snippets.isEmpty {
                EmptyStateView(
                    icon: "text.quote",
                    title: "No snippets created",
                    message: "Create shortcuts like saying 'meeting calendar link' to instantly insert your calendar URL."
                )
            } else {
                ScrollView {
                    VStack(spacing: Space.x2) {
                        ForEach(Array(userData.snippets.enumerated()), id: \.offset) { index, snippet in
                            HStack(alignment: .top, spacing: Space.x3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("“\(snippet.trigger)”")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                    Text(snippet.expansion)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Ink.primary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button(role: .destructive, action: {
                                    userData.snippets.remove(at: index)
                                    userData.save()
                                    model.showFeedback("Removed snippet")
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(Space.x3)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Line.hairline))
                        }
                    }
                }
            }
        }
    }

    private func addSnippet() {
        let trigger = model.newSnippetTrigger.trimmingCharacters(in: .whitespaces)
        let expansion = model.newSnippetExpansion.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !expansion.isEmpty else { return }
        userData.snippets.append((trigger: trigger, expansion: expansion))
        userData.save()
        model.newSnippetTrigger = ""
        model.newSnippetExpansion = ""
        model.isAddingSnippet = false
        model.showFeedback("Added snippet “\(trigger)”")
    }

    // MARK: - Personas Tab

    private var personasSection: some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            ContentSection(
                title: "Writing Personas & AI Styles",
                systemImage: "wand.and.stars"
            ) {
                Text("Local on-device style transforms that adapt your dictation into different tones.")
                    .font(.system(size: 13))
                    .foregroundStyle(Ink.secondary)

                HStack(spacing: Space.x2) {
                    personaCard(title: "Executive", subtitle: "Clear, concise, professional bullet points")
                    personaCard(title: "Casual", subtitle: "Relaxed tone for Slack & team chats")
                    personaCard(title: "Developer", subtitle: "Technical Markdown & code documentation")
                }
            }

            Divider()

            ContentSection(title: "Persona Playground", systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: Space.x2) {
                    Text("Input text:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ink.secondary)

                    TextEditor(text: $model.playgroundInput)
                        .font(.system(size: 12))
                        .frame(height: 50)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Line.hairline))

                    HStack {
                        Button("Transform with Executive Tone") {
                            runPlaygroundTransform(style: "Rewrite this text for an executive audience. Make it crisp, concise, and structured with bullet points.")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(model.isTransforming)

                        Button("Fix Grammar & Polish") {
                            runPlaygroundTransform(style: "Fix grammar, spelling, and sentence structure without changing vocabulary or meaning.")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(model.isTransforming)

                        if model.isTransforming {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    if !model.playgroundOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Output:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                            Text(model.playgroundOutput)
                                .font(.system(size: 13))
                                .padding(Space.x3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor.opacity(0.2)))
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func personaCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.primary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
        }
        .padding(Space.x3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Line.hairline))
    }

    private func runPlaygroundTransform(style: String) {
        model.isTransforming = true
        Task {
            do {
                let output = try await LocalAIEngine.rewrite(instructions: style, prompt: model.playgroundInput)
                await MainActor.run {
                    model.playgroundOutput = output
                    model.isTransforming = false
                    model.showFeedback("Transformed with local AI")
                }
            } catch {
                await MainActor.run {
                    model.playgroundOutput = "Transformation unavailable or failed."
                    model.isTransforming = false
                }
            }
        }
    }
}
