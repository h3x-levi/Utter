import SwiftUI
import UtterCore

struct CommandsSection: View {
    @Bindable var model: WordsViewModel
    @State private var editing: CommandSheet?

    private struct CommandSheet: Identifiable {
        let id = UUID()
        let command: CustomAICommand?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            yourCommands
            tryIt.padding(.top, 34)
            builtIn.padding(.top, 34)
        }
        .sheet(item: $editing) { sheet in
            CommandEditor(command: sheet.command) { model.saveCommand($0, replacing: sheet.command) }
        }
        .background {
            Button("New command") { editing = CommandSheet(command: nil) }
                .keyboardShortcut("n")
                .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
        }
    }

    private var yourCommands: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("Your commands", detail: model.commands.isEmpty ? nil : "\(model.commands.count)")
            HStack(alignment: .firstTextBaseline) {
                WordsHint(text: "Rewrites you name yourself, like \u{201C}make it a commit message\u{201D}.")
                Spacer(minLength: 12)
                Button("New command") { editing = CommandSheet(command: nil) }
                    .buttonStyle(.pen(.fill, .small))
                    .padding(.top, 8)
            }
            if model.commands.isEmpty {
                WordsHint(text: "No commands yet. Make your own voice command, then try it on some text below.", strong: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.commands) { command in
                        let edit = { editing = CommandSheet(command: command) }
                        ActionRow(action: edit, removeLabel: "Delete \(command.trigger)", remove: { model.deleteCommand(command.id) }) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\u{201C}\(command.trigger)\u{201D}")
                                    .fontWeight(.semibold)
                                    .frame(width: 190, alignment: .leading)
                                Text(command.systemPrompt).foregroundStyle(Mixtape.ink2)
                            }
                        }
                        .accessibilityHint("Edit")
                        .contextMenu {
                            Button("Edit", action: edit)
                            Button("Delete", role: .destructive) { model.deleteCommand(command.id) }
                        }
                    }
                }
                .background(alignment: .top) { RuledBackground() }
                .padding(.top, 8)
            }
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("Try a command")
            if model.commands.isEmpty {
                WordsHint(text: "Create a command above to try it on some text here.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsRow("Command") {
                        SettingsPick("Command", value: model.tryCommand?.trigger ?? "") {
                            Picker("Command", selection: $model.tryCommandID) {
                                ForEach(model.commands) { Text($0.trigger).tag(Optional($0.id)) }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                    TextField("Sample text", text: $model.trySample, axis: .vertical)
                        .lineLimit(1...5)
                        .accessibilityLabel("Sample text to run the command on")
                        .inkLine()
                    let availability = model.aiAvailability
                    if !availability.isReady { InkNote(Text(availability.message)) }
                    HStack(spacing: 12) {
                        Button("Run") { model.runTry() }
                            .buttonStyle(.pen(.fill, .small))
                            .disabled(!model.canRunTry)
                        if model.tryResult == .running { SettingsStatus(text: "Running") }
                    }
                    switch model.tryResult {
                    case .output(let text): result(text, failed: false)
                    case .failed(let message): result(message, failed: true)
                    case .idle, .running: EmptyView()
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private func result(_ text: String, failed: Bool) -> some View {
        Text(text)
            .font(Mixtape.body(15))
            .foregroundStyle(failed ? Mixtape.red : Mixtape.penInk)
            .lineSpacing(16)
            .textSelection(.enabled)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .top) { RuledBackground() }
    }

    private var builtIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            SideHeader("Built-in commands", detail: "hold \(model.hotkeyName) and say one")
            WordsHint(text: "Select text or dictate first, then hold \(model.hotkeyName) and say one of these.")
            ForEach(BuiltInCommandGroup.all) { group in
                Text(group.title)
                    .mixtapeCaps(10, tracking: 0.2)
                    .foregroundStyle(Mixtape.ink3)
                    .padding(.top, 18)
                    .padding(.bottom, 4)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(group.commands) { command in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\u{201C}\(command.phrase)\u{201D}")
                                .fontWeight(.medium)
                                .frame(width: 230, alignment: .leading)
                            Text(command.detail).foregroundStyle(Mixtape.ink2)
                        }
                        .font(Mixtape.body(13))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: Mixtape.ruleSpacing, maxHeight: Mixtape.ruleSpacing, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .background(alignment: .top) { RuledBackground() }
            }
        }
    }
}

struct CommandEditor: View {
    let command: CustomAICommand?
    let onSave: (CommandDraft) -> Void
    @State private var draft: CommandDraft
    @Environment(\.dismiss) private var dismiss

    init(command: CustomAICommand?, onSave: @escaping (CommandDraft) -> Void) {
        self.command = command
        self.onSave = onSave
        _draft = State(initialValue: command.map(CommandDraft.init) ?? CommandDraft())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text(command == nil ? "New command" : "Edit command")
                .mixtapeCaps(24, tracking: 0.02)
                .accessibilityAddTraits(.isHeader)
            SettingsSection("The command") {
                SettingsRow("When I say") {
                    SettingsField("make it a commit message", label: "When I say", text: $draft.trigger)
                        .frame(maxWidth: 240)
                }
            }
            SettingsSection("What it should do") {
                SettingsField("", label: "What it should do", text: $draft.instruction, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                SettingsRow("Replace the selected text") {
                    Toggle("Replace the selected text", isOn: $draft.replacesSelection).toggleStyle(.settingsSwitch)
                }
            }
            SettingsSection("Wrap the text", detail: "optional", note: "Use {{text}} where your text should go.") {
                SettingsRow("Template") {
                    SettingsField("Rewrite this: {{text}}", label: "Template", text: $draft.wrapper)
                        .frame(maxWidth: 240)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.pen(.ghost))
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft); dismiss() }
                    .buttonStyle(.pen(.fill))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .frame(width: 480)
        .background(Mixtape.paper)
        .foregroundStyle(Mixtape.ink)
        .tint(Mixtape.ink)
    }
}
