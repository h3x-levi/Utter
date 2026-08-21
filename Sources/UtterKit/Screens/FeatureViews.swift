import SwiftUI

// MARK: - Dictionary

struct DictionaryView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared
    @State private var newWord = ""

    /// The curve for a row arriving in or leaving the list.
    ///
    /// Every list mutation on this screen went through a bare `Motion.listChange`,
    /// and the rows carry `.move(edge: .top)` transitions — translation, which is
    /// precisely what Reduce Motion asks to be spared. `Motion.reduced` is the
    /// documented substitute ("a short crossfade, never a spring").
    private var listCurve: Animation {
        motion.reduceMotion ? Motion.reduced : Motion.listChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            BentoTile(title: "Add a word", systemImage: "plus.circle") {
                Text("Custom words help Utter transcribe names, acronyms, and jargon correctly.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.x2) {
                    GlassTextField(
                        placeholder: "Name, acronym, or technical term",
                        text: $newWord,
                        systemImage: "character.cursor.ibeam",
                        onSubmit: addWord
                    )
                    GlassButton(title: "Add", prominent: true, action: addWord)
                        .disabled(trimmedWord.isEmpty)
                }
            }

            if userData.dictionaryWords.isEmpty {
                EmptyStateView(
                    icon: "character.book.closed",
                    title: "No custom words",
                    message: "Add names, acronyms, and jargon that get transcribed wrong \u{2014} "
                        + "teammates, product names, technical terms."
                )
            } else {
                BentoTile(
                    title: "Your words",
                    systemImage: "character.book.closed",
                    accessory: AnyView(
                        Text("\(userData.dictionaryWords.count)")
                            .typo(.caption, ink: Ink.tertiary)
                    )
                ) {
                    // A glass container around the whole list, not one per row:
                    // Apple's guidance is to batch effects so they cost a single
                    // render pass.
                    GlassCluster(spacing: 0) {
                        VStack(spacing: Space.x1) {
                            ForEach(userData.dictionaryWords, id: \.self) { word in
                                WordRow(word: word) { remove(word) }
                            }
                        }
                    }
                    // Rows now slide in and out instead of appearing instantly.
                    .animation(listCurve, value: userData.dictionaryWords)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var trimmedWord: String {
        newWord.trimmingCharacters(in: .whitespaces)
    }

    private func addWord() {
        let word = trimmedWord
        guard !word.isEmpty, !userData.dictionaryWords.contains(word) else { return }
        withAnimation(listCurve) {
            userData.dictionaryWords.append(word)
        }
        userData.save()
        newWord = ""
    }

    private func remove(_ word: String) {
        withAnimation(listCurve) {
            userData.dictionaryWords.removeAll { $0 == word }
        }
        userData.save()
    }
}

/// One dictionary entry. The delete button only appears on hover, so a long list
/// reads as words rather than as a column of trash icons.
private struct WordRow: View {
    let word: String
    let onDelete: () -> Void

    @State private var isHovering = false
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
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x1)
        .frame(minHeight: 34)
        .background(Radius.rect(Radius.control).fill(
            isHovering ? Surface.fillHover : Surface.fillSubtle
        ))
        // Follows the fill above rather than a `Rectangle`: the row paints an 8pt corner,
        // so a square hit region accepted clicks in four corners where nothing is drawn.
        // Fixed radius, not `ConcentricRectangle` — see the note above `Radius`.
        .contentShape(Radius.rect(Radius.control))
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        // `.move` is translation, so it is exactly what Reduce Motion suppresses —
        // the row travelled the full height of the list on every insert and remove.
        // Fades in place instead, matching the substitute at `OnboardingView.stepContent`.
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Snippets

struct SnippetsView: View {
    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared
    @State private var newTrigger = ""
    @State private var newText = ""
    @FocusState private var expansionFocused: Bool

    /// See `DictionaryView.listCurve` — same reasoning, same rows.
    private var listCurve: Animation {
        motion.reduceMotion ? Motion.reduced : Motion.listChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            BentoTile(title: "New snippet", systemImage: "text.badge.plus") {
                Text("Say the trigger phrase and Utter types the full text.")
                    .typo(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.x2) {
                    GlassTextField(placeholder: "Trigger phrase", text: $newTrigger)
                        .frame(width: 170)
                    GlassTextField(placeholder: "Expands to…", text: $newText)
                    GlassButton(title: "Add", prominent: true, action: addSnippet)
                        .disabled(!canAdd)
                }

                // Placeholder chips — tap to insert into the expansion field.
                VStack(alignment: .leading, spacing: Space.x2) {
                    SectionHeader(title: "Placeholders")

                    // No `GlassCluster` here.
                    //
                    // `GlassChip` deliberately is not glass. `GlassChip.chipBackground`
                    // spells out why ("A standard material, deliberately *not*
                    // `glassEffect`… glass here sits directly behind 11pt type") and its
                    // background is `Capsule().fill(Surface.fillMuted)`. So the container
                    // had five children and nothing to batch.
                    //
                    // Wraps instead of overflowing: the chip row used to be a
                    // single HStack, so a narrow window clipped it.
                    FlowLayout(spacing: Space.x2) {
                        ForEach(SnippetTemplates.availablePlaceholders, id: \.token) { item in
                            Button {
                                newText.append(item.token)
                                expansionFocused = true
                            } label: {
                                GlassChip(
                                    text: item.token,
                                    tint: Tint.accent,
                                    mono: true
                                )
                            }
                            .buttonStyle(.plain)
                            .help(item.description)
                        }
                    }

                    Text("Placeholders are filled in when the snippet runs. Text without [brackets] is typed as written.")
                        .typo(.caption)
                        .fixedSize(horizontal: false, vertical: true)
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
                BentoTile(
                    title: "Your snippets",
                    systemImage: "text.quote",
                    accessory: AnyView(
                        Text("\(userData.snippets.count)")
                            .typo(.caption, ink: Ink.tertiary)
                    )
                ) {
                    GlassCluster(spacing: 0) {
                        VStack(spacing: Space.x1) {
                            ForEach(userData.snippets.indices, id: \.self) { i in
                                SnippetRow(
                                    trigger: userData.snippets[i].trigger,
                                    expansion: userData.snippets[i].expansion
                                ) { remove(at: i) }
                            }
                        }
                    }
                    .animation(listCurve, value: userData.snippets.count)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var canAdd: Bool {
        !newTrigger.trimmingCharacters(in: .whitespaces).isEmpty
            && !newText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func addSnippet() {
        let trigger = newTrigger.trimmingCharacters(in: .whitespaces)
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !text.isEmpty else { return }
        withAnimation(listCurve) {
            userData.snippets.append((trigger: trigger, expansion: text))
        }
        userData.save()
        newTrigger = ""
        newText = ""
    }

    private func remove(at index: Int) {
        guard userData.snippets.indices.contains(index) else { return }
        withAnimation(listCurve) {
            // `_ =` because `remove(at:)` returns the removed element, which
            // would otherwise make this closure return a value.
            _ = userData.snippets.remove(at: index)
        }
        userData.save()
    }
}

private struct SnippetRow: View {
    let trigger: String
    let expansion: String
    let onDelete: () -> Void

    @State private var isHovering = false
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
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x1)
        .frame(minHeight: 34)
        .background(Radius.rect(Radius.control).fill(
            isHovering ? Surface.fillHover : Surface.fillSubtle
        ))
        // Follows the fill above rather than a `Rectangle`: the row paints an 8pt corner,
        // so a square hit region accepted clicks in four corners where nothing is drawn.
        // Fixed radius, not `ConcentricRectangle` — see the note above `Radius`.
        .contentShape(Radius.rect(Radius.control))
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        // `.move` is translation, so it is exactly what Reduce Motion suppresses —
        // the row travelled the full height of the list on every insert and remove.
        // Fades in place instead, matching the substitute at `OnboardingView.stepContent`.
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Style

struct StyleView: View {
    @ObservedObject private var userData = UserData.shared
    @State private var editingCommand: CustomAICommand?
    @State private var isCreatingNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            Text("Restyle, translate, or transform any text by voice. Dictate something first, or select text in any app, then hold \(userData.hotkeyName) and speak a command.")
                .typo(.lede)
                .fixedSize(horizontal: false, vertical: true)

            // Your custom commands — listed first since they override built-ins
            CustomCommandsSection(
                commands: userData.customAICommands,
                onAdd: { isCreatingNew = true },
                onEdit: { editingCommand = $0 },
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
            BentoTile(title: "How it works", systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: Space.x3) {
                    HowToStep(number: 1, text: "Dictate text, or select existing text in any app.")
                    HowToStep(number: 2, text: "Hold \(userData.hotkeyName) and speak a command — for example, \u{201C}make it professional\u{201D}.")
                    HowToStep(number: 3, text: "Release the key. The original text is replaced with the result.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isCreatingNew) {
            CustomCommandEditor(command: nil) { newCommand in
                userData.customAICommands.append(newCommand)
                userData.save()
            }
        }
        .sheet(item: $editingCommand) { command in
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
        BentoTile(
            title: "Your commands",
            systemImage: "person.fill.questionmark",
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
                // See `DictionaryView.listCurve` — these rows carry the same
                // `.move(edge: .top)` transition.
                .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange,
                           value: commands.count)
            }
        }
    }
}

// MARK: - Custom Command Editor Sheet

struct CustomCommandEditor: View {
    let command: CustomAICommand?
    let onSave: (CustomAICommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var motion = MotionPreference.shared

    @State private var trigger: String = ""
    @State private var systemPrompt: String = ""
    @State private var userPromptTemplate: String = ""
    @State private var replacesSelection: Bool = true

    private var isEditing: Bool { command != nil }
    private var isValid: Bool {
        !trigger.trimmingCharacters(in: .whitespaces).isEmpty &&
        !systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.groupGap) {
            VStack(alignment: .leading, spacing: Space.x1) {
                Text(isEditing ? "Edit command" : "New AI command").typo(.heading)
                Text("Runs on-device. Nothing is sent anywhere.").typo(.caption)
            }

            EditorField(
                label: "Trigger phrase",
                hint: "What you’ll say. Matching ignores case and trailing punctuation."
            ) {
                GlassTextField(placeholder: "e.g. make it a commit", text: $trigger)
            }

            EditorField(
                label: "Instruction",
                hint: "What the model should do. Example: \u{201C}Convert this into a conventional commit message under 72 characters.\u{201D}"
            ) {
                GlassTextEditor(text: $systemPrompt, minHeight: 84)
            }

            EditorField(
                label: "Prompt template",
                hint: "Optional. Leave blank to send the text as-is, or use {{text}} to place it."
            ) {
                GlassTextField(
                    placeholder: "Use {{text}} to inject the source text",
                    text: $userPromptTemplate,
                    mono: true
                )
            }

            GlassToggle(
                title: "Replace the selected text",
                description: replacesSelection
                    ? "The result overwrites your selection."
                    : "The result is appended after the cursor, like a reply.",
                isOn: $replacesSelection
            )
            // The toggle's description swaps between two sentences of different
            // lengths, so this animates the row's height. Small travel, same rule.
            .animation(motion.reduceMotion ? Motion.reduced : Motion.listChange,
                       value: replacesSelection)

            HStack(spacing: Space.x2) {
                Spacer()
                GlassButton(title: "Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                GlassButton(
                    title: isEditing ? "Save changes" : "Create command",
                    prominent: true
                ) {
                    var cmd = command ?? CustomAICommand(
                        trigger: "",
                        systemPrompt: "",
                        userPromptTemplate: "",
                        replacesSelection: true
                    )
                    cmd.trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                    cmd.systemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    cmd.userPromptTemplate = userPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                    cmd.replacesSelection = replacesSelection
                    onSave(cmd)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(Space.x6)
        .frame(width: 540)
        // The sheet floats above the window, so it belongs to the glass layer.
        .background(SheetBacking())
        .onAppear {
            if let c = command {
                trigger = c.trigger
                systemPrompt = c.systemPrompt
                userPromptTemplate = c.userPromptTemplate
                replacesSelection = c.replacesSelection
            }
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
        BentoTile(title: title, systemImage: icon) {
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
                    .padding(.horizontal, Space.x3)
                    .padding(.vertical, Space.x2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Radius.rect(Radius.control).fill(Surface.fillSubtle))
                }
            }
        }
    }
}

// MARK: - Shared feature-screen rows

/// One numbered step in a "how it works" list.
///
/// The number sits in an accent disc rather than being plain accent-coloured text,
/// so the sequence reads as a sequence at a glance. (The old doc comment here said
/// "glass chip"; it never was one — a `Circle` with an accent fill, which is right,
/// because a numeral 11pt tall is exactly the case GlassChip's own note warns about.)
///
/// The numeral is `Tint.accentText`, and this was the worst of the three accent-text
/// failures in this pass because **the number is the content**: it carries the
/// ordering of a three-step instruction, so losing it loses the instruction. 11pt
/// semibold accent on `Tint.accentSoft` computes to **2.58:1** on Paper, and 11pt
/// semibold is not "large text" — the 3:1 exemption starts at 14pt bold / 18pt
/// regular, so the floor here is 4.5:1. `accentText` computes to 8.06:1 on Paper and
/// clears the floor on all six themes.
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

/// One user-defined AI command. Edit and delete reveal on hover, so a list of
/// commands reads as commands rather than as rows of buttons.
private struct CustomCommandRow: View {
    let command: CustomAICommand
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
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
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, Space.x3)
        .padding(.vertical, Space.x2)
        .background(Radius.rect(Radius.control).fill(
            isHovering ? Surface.fillHover : Surface.fillSubtle
        ))
        // Follows the fill above rather than a `Rectangle`: the row paints an 8pt corner,
        // so a square hit region accepted clicks in four corners where nothing is drawn.
        // Fixed radius, not `ConcentricRectangle` — see the note above `Radius`.
        .contentShape(Radius.rect(Radius.control))
        .onHover { hovering in
            withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovering = hovering }
        }
        // `.move` is translation, so it is exactly what Reduce Motion suppresses —
        // the row travelled the full height of the list on every insert and remove.
        // Fades in place instead, matching the substitute at `OnboardingView.stepContent`.
        .transition(motion.reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .move(edge: .top)))
    }
}

/// A labelled field with a hint beneath it, for the command editor.
private struct EditorField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x2) {
            Text(label).typo(.captionEmphasis, ink: Ink.primary)
            content()
            if let hint {
                Text(hint)
                    .typo(.caption, ink: Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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
/// **This is not glass, and the comment here used to say it was** — "this is
/// `.regular` glass over a scrim rather than clear glass". No branch of this view
/// calls `glassEffect`, on any OS version. What it actually is is the same two-layer
/// standard-material build every window shell in the app uses, which is also the
/// correct choice: the sheet is full of text fields and a multi-line editor, and
/// GlassSurface.swift is explicit that the content layer takes standard materials.
/// The description was the only thing wrong.
///
/// The `#available(macOS 26.0, *)` split is a *tuning knob*, not an API fallback —
/// both branches call exactly the same two views and differ only in the veil. That is
/// legitimate (`Veil`'s own note explains why: with no Liquid Glass above it the same
/// veil reads heavier below 26, and a sheet is the one role whose pre-26 tuning goes
/// up rather than down, because it must stay readable over a window still visible
/// behind it) — but it is worth knowing it is a tuning branch, since it looks like a
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
///     the panel there is no chrome layer at all — it is one form, top to bottom.
///   * **The form is content, and unusually text-heavy content**: three labelled
///     fields, a multi-line `GlassTextEditor`, and hint prose under each. Glassing the
///     panel would refract the backdrop behind every text field on it, and the button
///     row at its foot is not flush to an edge — it is the last row of the form, so a
///     glass band there would be glass in the middle of content.
///
/// The controls in the row already carry the sheet's glass: `GlassButton` resolves to
/// `.glass` / `.glassProminent` on macOS 26. That is the correct division — glass on
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
