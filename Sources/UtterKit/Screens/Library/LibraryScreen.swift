import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UtterCore

struct LibraryScreen: View {
    @Bindable var model: LibraryViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var listFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            column.frame(minWidth: 300, maxWidth: .infinity)
            if let item = model.selectedItem {
                InspectorPane(model: model, item: item)
                    .padding([.top, .bottom, .trailing], 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(paneMotion, value: model.isInspecting)
        .alert("Export failed", isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var paneMotion: Animation {
        if reduceMotion { return .easeOut(duration: 0.18) }
        return model.isInspecting ? .spring(duration: 0.42, bounce: 0.14) : .spring(duration: 0.36, bounce: 0)
    }

    private var column: some View {
        content
            .topBar { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { undoBar }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    FilterSegments(model: model, counted: true)
                    FilterSegments(model: model, counted: false)
                }
                Spacer(minLength: 0)
                ControlGroup {
                    Button(action: model.startMeeting) { Label("Record a Meeting", systemImage: "record.circle") }
                        .disabled(!model.canStartMeeting)
                        .help("Record a Meeting")
                    Menu {
                        ForEach(LibraryViewModel.ExportFormat.allCases) { format in
                            Button(format.rawValue) { export(format) }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .menuIndicator(.hidden)
                    .disabled(model.visibleItems.isEmpty)
                    .help("Export what's shown")
                }
                .labelStyle(.iconOnly)
                .fixedSize()
            }
            if let meeting = model.meeting {
                MeetingBar(meeting: meeting, message: model.meetingMessage, retry: model.startMeeting, stop: model.stopMeeting)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        let days = model.days
        if days.isEmpty {
            ScrollView { empty }.modifier(HardTopEdge())
        } else {
            list(days)
        }
    }

    private func list(_ days: [LibraryViewModel.Day]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(days) { day in
                        Text(day.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(EdgeInsets(top: 12, leading: 12, bottom: 5, trailing: 12))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(day.items) { item in
                            LibraryRow(item: item, selected: item.id == model.selectedID) {
                                listFocused = true
                                model.selectedID = item.id
                            }
                            .contextMenu { menu(item) }
                            .transition(rowTransition)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .focusable()
            .focused($listFocused)
            .focusEffectDisabled()
            .onMoveCommand(perform: move)
            .onDeleteCommand { if let item = model.selectedItem { model.delete(item) } }
            .onChange(of: model.selectedID, initial: true) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            .modifier(HardTopEdge())
        }
    }

    private var rowTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: -6)), removal: .opacity)
    }

    @ViewBuilder
    private func menu(_ item: LibraryItem) -> some View {
        Button("Copy") { model.copy(item) }
        if item.kind == .dictation, let entry = model.entries.first(where: { $0.id == item.uuid }) {
            Button("Convert to Note") { model.convertToNote(entry) }
        }
        Divider()
        Button("Delete", role: .destructive) { model.delete(item) }.disabled(!model.canDelete(item))
    }

    /// Arrow keys step through what's shown; keyboard moves never animate.
    private func move(_ direction: MoveCommandDirection) {
        let items = model.visibleItems
        guard !items.isEmpty, direction == .up || direction == .down else { return }
        let index = items.firstIndex { $0.id == model.selectedID }
        let next = direction == .up ? max((index ?? 1) - 1, 0) : min((index ?? -1) + 1, items.count - 1)
        withTransaction(\.disablesAnimations, true) { model.selectedID = items[next].id }
    }

    @ViewBuilder
    private var empty: some View {
        let query = model.search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            LibraryEmpty(title: "Nothing matches",
                         message: "No dictation, note or meeting mentions \u{201C}\(query)\u{201D}.") {
                Button("Clear Search") { model.search = "" }
            }
        } else {
            switch model.filter {
            case .meetings:
                LibraryEmpty(title: "No meetings yet",
                             message: "Record a meeting and Utter writes down what you and the others say.") {
                    Button("Record a Meeting", action: model.startMeeting).disabled(!model.canStartMeeting)
                }
            case .notes:
                LibraryEmpty(title: "No notes yet",
                             message: "Write one here, or press \(KeyChord.noteCapture.symbols) to talk into a new note.") {
                    Button("New Note", action: model.newNote)
                }
            case .all, .dictations:
                LibraryEmpty(title: "Nothing here yet",
                             message: "Hold your Utter key and talk in any app. What you say shows up here.") {
                    Button("New Note", action: model.newNote)
                }
            }
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let item = model.pendingDelete {
            HStack(spacing: 12) {
                Text("Deleted \u{201C}\(item.title)\u{201D}")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Undo", action: model.undoDelete)
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .foregroundStyle(Look.Color.tint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .modifier(FloatingCapsule())
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func export(_ format: LibraryViewModel.ExportFormat) {
        let text = model.exportText(format)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Utter \(model.filter.title).\(format.fileExtension)"
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            model.save(text, to: url)
        }
    }
}

// MARK: - List

private struct FilterSegments: View {
    @Bindable var model: LibraryViewModel
    let counted: Bool

    @Namespace private var lens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryFilter.allCases) { filter in
                let on = model.filter == filter
                Button { model.filter = filter } label: {
                    HStack(spacing: 6) {
                        Text(filter.title)
                        if counted {
                            let count = model.count(filter)
                            Text(count, format: .number)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .contentTransition(.numericText(value: Double(count)))
                        }
                    }
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background {
                        if on { Lozenge(shape: Capsule()).matchedGeometryEffect(id: "lens", in: lens) }
                    }
                }
                .buttonStyle(Look.RowStyle(radius: 14, scale: Look.Press.nav, quiet: true, selected: on))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Look.Color.hover, in: Capsule())
        .animation(Look.Motion.lens.animation(reduceMotion: reduceMotion), value: model.filter)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Show")
    }
}

private struct LibraryRow: View {
    let item: LibraryItem
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            label
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { if selected { Lozenge(shape: RoundedRectangle(cornerRadius: Look.Card.rowRadius, style: .continuous)) } }
        }
        .buttonStyle(Look.RowStyle(selected: selected))
        .accessibilityLabel(item.title)
        .accessibilityValue("\(item.kindName), \(item.date.formatted(date: .omitted, time: .shortened)), \(item.words) words")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.symbol)
                .foregroundStyle(.tertiary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.title).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(item.date, format: .dateTime.hour().minute())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                if item.kind == .meeting, !item.previewTurns.isEmpty {
                    ForEach(item.previewTurns) { turn in
                        TurnLine(turn: turn, isYou: turn.speaker == item.you)
                    }
                } else {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var meta: String {
        [item.preview ?? (item.kind == .dictation ? nil : item.kindName), item.words == 1 ? "1 word" : "\(item.words) words"]
            .compactMap { $0 }
            .joined(separator: "  ")
    }
}

private struct TurnLine: View {
    let turn: LibraryItem.Turn
    let isYou: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let speaker = turn.speaker {
                Text(speaker)
                    .fontWeight(.semibold)
                    .foregroundStyle(isYou ? AnyShapeStyle(Look.Color.tint) : AnyShapeStyle(.secondary))
            }
            Text(turn.text).foregroundStyle(.secondary)
        }
        .font(.callout)
        .lineLimit(1)
    }
}

/// The small mark over an empty list, with one next step.
private struct LibraryEmpty<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 10) {
            LivingMark(tint: .secondary).frame(height: 22)
            Text(title).fontWeight(.semibold).foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            action.buttonStyle(Look.ActionStyle()).padding(.top, 4)
        }
        .frame(maxWidth: 320)
        .padding(.top, 44)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inspector

private struct InspectorPane: View {
    @Bindable var model: LibraryViewModel
    let item: LibraryItem

    @State private var dragStart: CGFloat?
    @State private var cursorPushed = false

    var body: some View {
        LibraryInspector(model: model, item: item)
            .frame(minWidth: 280, idealWidth: model.inspectorWidth, maxWidth: model.inspectorWidth, maxHeight: .infinity)
            .modifier(PaneSurface())
            .overlay(alignment: .leading) { resizeEdge }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Details")
    }

    private var resizeEdge: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .offset(x: -6)
            .onHover { setCursor($0) }
            .onDisappear { setCursor(false) }
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { drag in
                    let start = dragStart ?? model.inspectorWidth
                    dragStart = start
                    model.inspectorWidth = min(560, max(280, start - drag.translation.width))
                }
                .onEnded { _ in dragStart = nil })
            .accessibilityHidden(true)
    }

    private func setCursor(_ resize: Bool) {
        guard resize != cursorPushed else { return }
        cursorPushed = resize
        if resize { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
    }
}

/// Reads `item` rather than the selection, so the pane keeps its content while it slides away.
private struct LibraryInspector: View {
    @Bindable var model: LibraryViewModel
    let item: LibraryItem

    private var note: Note? { item.kind == .dictation ? nil : model.notes.first { $0.id == item.uuid } }
    private var entry: TranscriptionEntry? { item.kind == .dictation ? model.entries.first { $0.id == item.uuid } : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Group {
                if let note {
                    NoteDetail(model: model, note: note, item: item).id(note.id)
                } else if let entry {
                    DictationDetail(model: model, entry: entry)
                }
            }
            .padding(EdgeInsets(top: 6, leading: 22, bottom: 22, trailing: 22))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var head: some View {
        HStack(spacing: 7) {
            Circle().fill(Look.Color.tint).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(item.kindName).font(.callout).foregroundStyle(.tertiary).lineLimit(1)
            Spacer(minLength: 4)
            ControlGroup {
                Button { model.copy(item) } label: {
                    Label(model.copiedID == item.id ? "Copied" : "Copy",
                          systemImage: model.copiedID == item.id ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .help("Copy")
                Menu {
                    if let entry {
                        Button("Convert to Note") { model.convertToNote(entry) }
                    }
                    if let note, note.source == .meeting {
                        Button(model.editingTranscript ? "Show Transcript" : "Edit as Text") { model.editingTranscript.toggle() }
                        Button("Rename Speakers\u{2026}") { model.namingSpeakers = true }
                    }
                    if let note {
                        Menu("Improve") {
                            ForEach(NoteAction.allCases) { action in
                                Button { model.run(action, on: note) } label: { Label(action.title, systemImage: action.systemImage) }
                            }
                        }
                        .disabled(model.runningAction != nil || note.body.isEmpty)
                    }
                    ShareLink("Share", item: item.body)
                    Divider()
                    Button("Delete", role: .destructive) { model.delete(item) }.disabled(!model.canDelete(item))
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .menuIndicator(.hidden)
                Button { model.selectedID = nil } label: { Label("Close", systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction)
                    .help("Close")
            }
            .labelStyle(.iconOnly)
            .controlSize(.regular)
            .fixedSize()
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .frame(height: 50)
    }
}

private struct NoteDetail: View {
    @Bindable var model: LibraryViewModel
    let note: Note
    let item: LibraryItem

    @FocusState private var focusedSpeaker: SpeakerRole?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(note.displayTitle, text: $model.titleDraft)
                .textFieldStyle(.plain)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.4)
                .accessibilityLabel("Title")
            metadata.padding(.top, 6)
            if let running = model.runningAction {
                Label(running.runningLabel, systemImage: "sparkles").foregroundStyle(.secondary).padding(.top, 10)
            } else if let message = model.actionMessage {
                Text(message)
                    .foregroundStyle(model.actionFailed ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            Group {
                if note.source == .meeting && !model.editingTranscript {
                    transcript
                } else {
                    TextEditor(text: model.body(of: note))
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Note text")
                }
            }
            .padding(.top, 14)
        }
        .sheet(isPresented: $model.namingSpeakers) { speakers }
        .onAppear { model.edit(note) }
        .onChange(of: focusedSpeaker) { if focusedSpeaker == nil { model.commitSpeakers() } }
        .onDisappear { model.commitSpeakers() }
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            Text(LibraryViewModel.stamp(note.source == .meeting ? item.date : note.modified))
            if note.source == .meeting {
                Text("\(max(1, Int(item.duration / 60))) min, \(note.speakerLabels.you) and \(note.speakerLabels.others)")
            } else {
                Text(note.wordCount == 1 ? "1 word" : "\(note.wordCount) words")
                if note.source == .dictated { Label("Dictated", systemImage: "mic") }
            }
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(.tertiary)
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(item.turns) { turn in
                    let isYou = turn.speaker == note.speakerLabels.you
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(turn.speaker ?? "")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isYou ? AnyShapeStyle(Look.Color.tint) : AnyShapeStyle(.secondary))
                            .lineLimit(1)
                            .frame(width: 64, alignment: .leading)
                        Text(turn.text)
                            .lineSpacing(4)
                            .foregroundStyle(isYou ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .textSelection(.enabled)
            .padding(.vertical, 4)
        }
    }

    private var speakers: some View {
        VStack(alignment: .trailing, spacing: 16) {
            Form {
                speakerField(.you, label: "Your microphone")
                speakerField(.others, label: "The call")
            }
            Text("Utter hears your microphone and the call separately. It can't tell two people in the call apart.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done") { model.namingSpeakers = false }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 360)
        .onDisappear { model.commitSpeakers() }
    }

    private func speakerField(_ role: SpeakerRole, label: String) -> some View {
        TextField(label, text: Binding(get: { model.speakerDrafts[role] }, set: { model.speakerDrafts[role] = $0 }),
                  prompt: Text(MeetingSpeakers.default[role]))
            .focused($focusedSpeaker, equals: role)
            .onSubmit { model.commitSpeakers() }
    }
}

private struct DictationDetail: View {
    let model: LibraryViewModel
    let entry: TranscriptionEntry

    @Environment(\.libraryTransition) private var transition

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.timestamp, format: .dateTime.hour().minute())
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .tracking(-0.4)
            Text(metadata)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
            ScrollView {
                Text(entry.text)
                    .font(.title3)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sharedWords(LibraryItem.dictationID(entry.id), in: transition, isSource: false)
            }
            .padding(.top, 14)
        }
    }

    private var metadata: String {
        var parts = [LibraryViewModel.stamp(entry.timestamp), entry.wordCount == 1 ? "1 word" : "\(entry.wordCount) words"]
        if !entry.language.isEmpty { parts.append(entry.language) }
        return parts.joined(separator: "  ")
    }
}

// MARK: - Meeting bar

private struct MeetingBar: View {
    @ObservedObject var meeting: MeetingSession
    let message: String?
    let retry: () -> Void
    let stop: () -> Void

    var body: some View {
        if meeting.state != .idle || message != nil {
            VStack(alignment: .leading, spacing: 6) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(PaneSurface())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch meeting.state {
        case .recording:
            HStack(spacing: 10) {
                Look.LiveDot()
                Text("Recording this meeting").font(.headline)
                Text(String(format: "%d:%02d", meeting.elapsed / 60, meeting.elapsed % 60))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Stop", action: stop).buttonStyle(Look.ActionStyle(prominent: true))
            }
            if !meeting.heardOthers {
                Text("Nothing heard from the others yet. Check the call isn't muted or on a headset Utter can't hear.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .finishing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Finishing the transcript").foregroundStyle(.secondary)
            }
        case .failed(let why):
            HStack(spacing: 10) {
                Text(why).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Try Again", action: retry).buttonStyle(Look.ActionStyle())
            }
        case .idle:
            Text(message ?? "").fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Surfaces and states

/// The selection: lit from above, never system blue.
private struct Lozenge<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape.fill(Look.Color.lens)
            .overlay { shape.fill(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)) }
            .overlay { shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center)) }
    }
}

private struct PaneSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            surface(content, ConcentricRectangle(corners: .concentric(minimum: .fixed(Look.Card.radius)), isUniform: true))
        } else {
            surface(content, RoundedRectangle(cornerRadius: Look.Card.radius, style: .continuous))
        }
    }

    private func surface(_ content: Content, _ shape: some Shape) -> some View {
        content
            .background(Look.Color.fill, in: shape)
            .overlay {
                shape.stroke(LinearGradient(colors: [.white.opacity(0.15), Look.Color.edge], startPoint: .top,
                                            endPoint: UnitPoint(x: 0.5, y: 0.1)), lineWidth: 1)
            }
    }
}

/// A floating control: Liquid Glass on macOS 26, a thick material before it.
private struct FloatingCapsule: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.thickMaterial), in: Capsule())
                .overlay { Capsule().stroke(.separator) }
        }
    }
}

private struct HardTopEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) { content.scrollEdgeEffectStyle(.hard, for: .top) } else { content }
    }
}

private extension View {
    /// A bar above scrolling content; on macOS 26 the content softens beneath it instead of meeting a hairline.
    @ViewBuilder
    func topBar(@ViewBuilder _ bar: () -> some View) -> some View {
        if #available(macOS 26, *) {
            safeAreaBar(edge: .top, spacing: 0, content: bar)
        } else {
            safeAreaInset(edge: .top, spacing: 0, content: bar)
        }
    }
}
