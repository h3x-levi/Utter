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
        VStack(alignment: .leading, spacing: 16) {
            yourCommands
            tryIt
            builtIn
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
            CardHeader("Your commands", subtitle: "Rewrites you name yourself, like \u{201C}make it a commit message\u{201D}.") {
                Button("New command") { editing = CommandSheet(command: nil) }
                    .buttonStyle(Look.ActionStyle(prominent: true))
            }
            if model.commands.isEmpty {
                EmptyNote(title: "No commands yet", message: "Make your own voice command, then try it on some text below.")
            }
            ForEach(model.commands) { command in
                if command.id != model.commands.first?.id { RowRule() }
                let edit = { editing = CommandSheet(command: command) }
                ActionRow(action: edit, removeLabel: "Delete \(command.trigger)", remove: { model.deleteCommand(command.id) }) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\u{201C}\(command.trigger)\u{201D}")
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .frame(width: 190, alignment: .leading)
                        Text(command.systemPrompt)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .accessibilityHint("Edit")
                .contextMenu {
                    Button("Edit", action: edit)
                    Button("Delete", role: .destructive) { model.deleteCommand(command.id) }
                }
            }
        }
        .contentCard()
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader("Try a command", subtitle: model.commands.isEmpty ? "Create a command above to try it on some text here." : nil)
            if !model.commands.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Command", selection: $model.tryCommandID) {
                        ForEach(model.commands) { Text($0.trigger).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    TextField("Sample text", text: $model.trySample, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityLabel("Sample text to run the command on")
                        .fieldBox()
                    let availability = model.aiAvailability
                    if !availability.isReady {
                        Look.Status(text: availability.message, kind: .warn)
                    }
                    HStack(spacing: 12) {
                        Button("Run") { model.runTry() }
                            .buttonStyle(Look.ActionStyle(prominent: true))
                            .disabled(!model.canRunTry)
                        if model.tryResult == .running { ProgressView().controlSize(.small) }
                    }
                    switch model.tryResult {
                    case .output(let text): result(text, failed: false)
                    case .failed(let message): result(message, failed: true)
                    case .idle, .running: EmptyView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .contentCard()
    }

    private func result(_ text: String, failed: Bool) -> some View {
        Text(text)
            .foregroundStyle(failed ? Color.red : Color.primary)
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Look.Color.hover, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var builtIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader("Built-in commands",
                       subtitle: "Select text or dictate first, then hold \(model.hotkeyName) and say one of these.")
            ForEach(BuiltInCommandGroup.all) { group in
                if group.id != BuiltInCommandGroup.all.first?.id { RowRule() }
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title).font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
                    ForEach(group.commands) { command in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\u{201C}\(command.phrase)\u{201D}")
                                .fontWeight(.medium)
                                .frame(width: 230, alignment: .leading)
                            Text(command.detail).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .contentCard()
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
        VStack(alignment: .leading, spacing: 16) {
            Text(command == nil ? "New command" : "Edit command").font(.headline)
            Form {
                TextField("When I say", text: $draft.trigger, prompt: Text("make it a commit message"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("What it should do")
                    TextEditor(text: $draft.instruction)
                        .font(.body)
                        .frame(height: 90)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator))
                        .accessibilityLabel("What it should do")
                }
                Toggle("Replace the selected text", isOn: $draft.replacesSelection)
                DisclosureGroup("Wrap the text (optional)") {
                    TextField("Template", text: $draft.wrapper, prompt: Text("Rewrite this: {{text}}"))
                    Text("Use {{text}} where your text should go.")
                        .font(.callout)
                        .foregroundStyle(Color.secondary)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isValid)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
