import SwiftUI

struct CommandsSection: View {
    @Bindable var model: WordsViewModel
    @State private var editing: CommandSheet?

    private struct CommandSheet: Identifiable {
        let id = UUID()
        let command: CustomAICommand?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Look.Space.x4) {
                yourCommands
                tryIt
                builtIn
            }
        }
        .scrollIndicators(.automatic)
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
        Look.Well(spacing: Look.Space.x3) {
            HStack {
                Text("Your commands").font(Look.Font.heading)
                Spacer()
                Button("New command") { editing = CommandSheet(command: nil) }
            }
            if model.commands.isEmpty {
                Look.EmptyCue(message: "Make your own voice command, like \u{201C}make it a commit message\u{201D}.",
                              actionTitle: "New command") { editing = CommandSheet(command: nil) }
            } else {
                ForEach(model.commands) { command in
                    HStack(alignment: .firstTextBaseline, spacing: Look.Space.x3) {
                        VStack(alignment: .leading, spacing: Look.Space.x1) {
                            Text("\u{201C}\(command.trigger)\u{201D}").font(Look.Font.body.weight(.medium))
                            Text(command.systemPrompt)
                                .font(Look.Font.secondary)
                                .foregroundStyle(Look.Color.inkSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button { editing = CommandSheet(command: command) } label: { Image(systemName: "pencil") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Edit \(command.trigger)")
                        Button { model.deleteCommand(command.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete \(command.trigger)")
                    }
                    .contextMenu {
                        Button("Edit") { editing = CommandSheet(command: command) }
                        Button("Delete", role: .destructive) { model.deleteCommand(command.id) }
                    }
                    if command.id != model.commands.last?.id { Divider() }
                }
            }
        }
    }

    private var tryIt: some View {
        Look.Well(spacing: Look.Space.x3) {
            Text("Try a command").font(Look.Font.heading)
            if model.commands.isEmpty {
                Text("Create a command above to try it on some text here.")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
            } else {
                Picker("Command", selection: $model.tryCommandID) {
                    ForEach(model.commands) { Text($0.trigger).tag(Optional($0.id)) }
                }
                .frame(maxWidth: 340)
                TextField("Sample text", text: $model.trySample, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityLabel("Sample text to run the command on")
                let availability = model.aiAvailability
                if !availability.isReady {
                    HStack(alignment: .firstTextBaseline, spacing: Look.Space.x2) {
                        Look.SoundTag("unavailable", state: .warn)
                        Text(availability.message)
                            .font(Look.Font.secondary)
                            .foregroundStyle(Look.Color.inkSecondary)
                    }
                }
                HStack(spacing: Look.Space.x3) {
                    Button("Run") { model.runTry() }.disabled(!model.canRunTry)
                    if model.tryResult == .running { ProgressView().controlSize(.small) }
                }
                switch model.tryResult {
                case .output(let text): result(text, failed: false)
                case .failed(let message): result(message, failed: true)
                case .idle, .running: EmptyView()
                }
            }
        }
    }

    private func result(_ text: String, failed: Bool) -> some View {
        Text(text)
            .font(Look.Font.body)
            .foregroundStyle(failed ? Look.Color.warn : Look.Color.ink)
            .textSelection(.enabled)
            .padding(Look.Space.x3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Look.Radius.control, style: .continuous)
                .strokeBorder(Look.Color.hairline))
    }

    private var builtIn: some View {
        Look.Well(spacing: Look.Space.x4) {
            VStack(alignment: .leading, spacing: Look.Space.x1) {
                Text("Built-in commands").font(Look.Font.heading)
                Text("Select text or dictate first, then hold \(model.hotkeyName) and say one of these.")
                    .font(Look.Font.secondary)
                    .foregroundStyle(Look.Color.inkSecondary)
            }
            ForEach(BuiltInCommandGroup.all) { group in
                VStack(alignment: .leading, spacing: Look.Space.x2) {
                    Look.SoundTag(group.title)
                    ForEach(group.commands) { command in
                        HStack(alignment: .firstTextBaseline, spacing: Look.Space.x3) {
                            Text("\u{201C}\(command.phrase)\u{201D}")
                                .font(Look.Font.secondary.weight(.medium))
                                .frame(width: 230, alignment: .leading)
                            Text(command.detail)
                                .font(Look.Font.secondary)
                                .foregroundStyle(Look.Color.inkSecondary)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
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
        VStack(alignment: .leading, spacing: Look.Space.x4) {
            Text(command == nil ? "New command" : "Edit command").font(Look.Font.heading)
            Form {
                TextField("When I say", text: $draft.trigger, prompt: Text("make it a commit message"))
                VStack(alignment: .leading, spacing: Look.Space.x1) {
                    Text("What it should do")
                    TextEditor(text: $draft.instruction)
                        .font(Look.Font.body)
                        .frame(height: 90)
                        .overlay(RoundedRectangle(cornerRadius: Look.Radius.control).strokeBorder(Look.Color.hairline))
                        .accessibilityLabel("What it should do")
                }
                Toggle("Replace the selected text", isOn: $draft.replacesSelection)
                DisclosureGroup("Wrap the text (optional)") {
                    TextField("Template", text: $draft.wrapper, prompt: Text("Rewrite this: {{text}}"))
                    Text("Use {{text}} where your text should go.")
                        .font(Look.Font.secondary)
                        .foregroundStyle(Look.Color.inkSecondary)
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
        .padding(Look.Space.x5)
        .frame(width: 480)
    }
}
