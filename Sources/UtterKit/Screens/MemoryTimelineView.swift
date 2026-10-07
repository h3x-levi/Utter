import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Unified model uniting transient dictations and durable notes into a single timeline.
enum UnifiedTimelineItem: Identifiable, Equatable, Hashable {
    case dictation(id: UUID, text: String, date: Date, words: Int, language: String)
    case note(id: UUID, title: String, body: String, date: Date, isMeeting: Bool)

    var id: String {
        switch self {
        case .dictation(let id, _, _, _, _): return "dictation-\(id.uuidString)"
        case .note(let id, _, _, _, _): return "note-\(id.uuidString)"
        }
    }

    var uuid: UUID {
        switch self {
        case .dictation(let id, _, _, _, _): return id
        case .note(let id, _, _, _, _): return id
        }
    }

    var date: Date {
        switch self {
        case .dictation(_, _, let d, _, _): return d
        case .note(_, _, _, let d, _): return d
        }
    }

    var title: String {
        switch self {
        case .dictation(_, let text, _, _, _):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Quick dictation" : String(trimmed.prefix(50))
        case .note(_, let title, let body, _, _):
            if !title.isEmpty { return title }
            let derived = Note.derivedTitle(from: body)
            return derived.isEmpty ? "Untitled note" : derived
        }
    }

    var body: String {
        switch self {
        case .dictation(_, let text, _, _, _): return text
        case .note(_, _, let body, _, _): return body
        }
    }

    var wordCount: Int {
        switch self {
        case .dictation(_, _, _, let w, _): return w
        case .note(_, _, let body, _, _): return body.split { $0.isWhitespace }.count
        }
    }

    var isMeeting: Bool {
        switch self {
        case .dictation: return false
        case .note(_, _, _, _, let isM): return isM
        }
    }

    var icon: String {
        if isMeeting { return "video" }
        switch self {
        case .dictation: return "waveform"
        case .note: return "note.text"
        }
    }
}

@MainActor
final class MemoryTimelineViewModel: ObservableObject {
    @Published var filter: MemorySection = .all
    @Published var searchText: String = ""
    @Published var selectedItemID: String? = nil
    @Published var feedbackMessage: String? = nil
    @Published var draftNoteTitle: String = ""
    @Published var draftNoteBody: String = ""
    @Published var draftNoteID: UUID? = nil
    @Published var pendingDeleteID: String? = nil

    func syncDraft(from item: UnifiedTimelineItem?) {
        guard let item else {
            draftNoteID = nil
            draftNoteTitle = ""
            draftNoteBody = ""
            return
        }
        switch item {
        case .note(let id, let title, let body, _, _):
            draftNoteID = id
            draftNoteTitle = title
            draftNoteBody = body
        case .dictation:
            draftNoteID = nil
            draftNoteTitle = ""
            draftNoteBody = ""
        }
    }

    func commitNoteDraft(store: NoteStore) {
        guard let id = draftNoteID, store.notes.contains(where: { $0.id == id }) else { return }
        store.updateBody(draftNoteBody, for: id)
        store.updateTitle(draftNoteTitle, for: id)
        store.writeToDisk()
    }

    func showFeedback(_ message: String) {
        feedbackMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.feedbackMessage == message {
                self?.feedbackMessage = nil
            }
        }
    }
}

struct MemoryTimelineView: View {
    @ObservedObject private var history = TranscriptionHistory.shared
    @ObservedObject private var noteStore = NoteStore.shared
    @StateObject private var model = MemoryTimelineViewModel()

    private var allItems: [UnifiedTimelineItem] {
        var items: [UnifiedTimelineItem] = []

        if model.filter == .all || model.filter == .dictations {
            items.append(contentsOf: history.entries.map {
                UnifiedTimelineItem.dictation(id: $0.id, text: $0.text, date: $0.timestamp, words: $0.wordCount, language: $0.language)
            })
        }

        if model.filter == .all || model.filter == .notes || model.filter == .meetings {
            let notes = noteStore.notes.compactMap { note -> UnifiedTimelineItem? in
                let isMeeting = (note.source == .meeting)
                if model.filter == .meetings && !isMeeting { return nil }
                if model.filter == .notes && isMeeting { return nil }
                return UnifiedTimelineItem.note(id: note.id, title: note.titleIsCustom ? note.title : "", body: note.body, date: note.modified, isMeeting: isMeeting)
            }
            items.append(contentsOf: notes)
        }

        let query = model.searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(query) ||
                item.body.localizedCaseInsensitiveContains(query)
            }
        }

        return items.sorted { $0.date > $1.date }
    }

    private var selectedItem: UnifiedTimelineItem? {
        guard let id = model.selectedItemID else { return nil }
        return allItems.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter Bar and Search Header
            topHeaderBar

            Divider()

            // Split View: Timeline Stream on Left, Inspector/Editor on Right
            HSplitView {
                timelineListView
                    .frame(minWidth: 260, idealWidth: 320, maxWidth: 440)

                detailInspectionView
                    .frame(minWidth: 380, maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if model.selectedItemID == nil, let first = allItems.first {
                model.selectedItemID = first.id
                model.syncDraft(from: first)
            }
        }
        .onChange(of: model.selectedItemID) { newID in
            model.commitNoteDraft(store: noteStore)
            if let newID, let item = allItems.first(where: { $0.id == newID }) {
                model.syncDraft(from: item)
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(
                get: { model.pendingDeleteID != nil },
                set: { if !$0 { model.pendingDeleteID = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.pendingDeleteID
        ) { id in
            Button("Delete Permanently", role: .destructive) {
                deleteItem(withID: id)
                model.pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { model.pendingDeleteID = nil }
        } message: { id in
            Text("This will remove this item from your timeline. Utter has no remote backup.")
        }
    }

    // MARK: - Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: Space.x3) {
            Picker("Filter", selection: $model.filter) {
                ForEach(MemorySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            GlassTextField(
                placeholder: "Search memory",
                text: $model.searchText,
                systemImage: "magnifyingglass"
            )
            .frame(maxWidth: 240)

            Spacer()

            if let msg = model.feedbackMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tint.success)
            }

            Button(action: { createNewNote() }) {
                Label("New Note", systemImage: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button("Export as Markdown") { exportTimeline(as: .markdown) }
                Button("Export as CSV") { exportTimeline(as: .csv) }
                Button("Export as Plain Text") { exportTimeline(as: .text) }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Export timeline")
        }
        .padding(.horizontal, Space.pageInset)
        .padding(.vertical, Space.x2)
    }

    // MARK: - Timeline List

    private var timelineListView: some View {
        Group {
            if allItems.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Nothing recorded yet",
                    message: "Dictations and notes you record will appear here in chronological order."
                )
            } else {
                List(selection: $model.selectedItemID) {
                    ForEach(allItems) { item in
                        HStack(alignment: .top, spacing: Space.x2) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(item.isMeeting ? Tint.danger : (item.icon == "waveform" ? Color.accentColor : Ink.secondary))
                                .frame(width: 16)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Ink.primary)
                                    .lineLimit(1)

                                HStack(spacing: Space.x2) {
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10))
                                        .foregroundStyle(Ink.tertiary)
                                    Text("·")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Ink.tertiary)
                                    Text("\(item.wordCount) words")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Ink.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .tag(item.id)
                        .contextMenu {
                            Button("Copy Text") { copyText(item.body) }
                            Button("Delete", role: .destructive) { model.pendingDeleteID = item.id }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Detail Inspection / Editor

    private var detailInspectionView: some View {
        Group {
            if let item = selectedItem {
                switch item {
                case .note(let id, _, _, _, let isMeeting):
                    noteEditorView(id: id, isMeeting: isMeeting)
                case .dictation(let id, let text, let date, let words, let language):
                    dictationCardView(id: id, text: text, date: date, words: words, language: language)
                }
            } else {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "Select an item",
                    message: "Choose any spoken dictation or note from the timeline to review."
                )
            }
        }
    }

    private func noteEditorView(id: UUID, isMeeting: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.x3) {
            HStack {
                TextField("Note Title", text: $model.draftNoteTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .textFieldStyle(.plain)
                    .onChange(of: model.draftNoteTitle) { _ in
                        model.commitNoteDraft(store: noteStore)
                    }

                Spacer()

                Button(action: { copyText(model.draftNoteBody) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive, action: { model.pendingDeleteID = "note-\(id.uuidString)" }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: Space.x2) {
                if let note = noteStore.notes.first(where: { $0.id == id }) {
                    Text(note.modified.formatted(date: .long, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
                if isMeeting {
                    Text("· Meeting Recording")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Tint.danger)
                }
            }

            Divider()

            TextEditor(text: $model.draftNoteBody)
                .font(.system(size: 13))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .onChange(of: model.draftNoteBody) { _ in
                    model.commitNoteDraft(store: noteStore)
                }

            Divider()

            HStack {
                Text("\(model.draftNoteBody.split { $0.isWhitespace }.count) words")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                Spacer()
                Menu("AI Note Actions") {
                    ForEach(NoteAction.allCases) { action in
                        Button(action.title) {
                            if let note = noteStore.notes.first(where: { $0.id == id }) {
                                performNoteAction(action, for: note)
                            }
                        }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(Space.pageInset)
    }

    private func dictationCardView(id: UUID, text: String, date: Date, words: Int, language: String) -> some View {
        VStack(alignment: .leading, spacing: Space.x4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Dictation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Ink.primary)
                    Text(date.formatted(date: .complete, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer()
                Button(action: { copyText(text) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive, action: { model.pendingDeleteID = "dictation-\(id.uuidString)" }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            ScrollView {
                Text(text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Text("\(words) words" + (language.isEmpty ? "" : " · \(language)"))
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.secondary)
                Spacer()
                Button("Convert to Note") {
                    let note = noteStore.create(body: text)
                    noteStore.writeToDisk()
                    model.selectedItemID = "note-\(note.id.uuidString)"
                    model.showFeedback("Converted to Note")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(Space.pageInset)
    }

    // MARK: - Actions

    private func createNewNote() {
        let note = noteStore.create(body: "")
        noteStore.writeToDisk()
        model.selectedItemID = "note-\(note.id.uuidString)"
        model.syncDraft(from: .note(id: note.id, title: "", body: "", date: note.modified, isMeeting: false))
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        model.showFeedback("Copied to clipboard")
    }

    private func deleteItem(withID id: String) {
        if id.hasPrefix("dictation-"), let uuid = UUID(uuidString: id.replacingOccurrences(of: "dictation-", with: "")) {
            if let entry = history.entries.first(where: { $0.id == uuid }) {
                history.delete(entry: entry)
            }
        } else if id.hasPrefix("note-"), let uuid = UUID(uuidString: id.replacingOccurrences(of: "note-", with: "")) {
            noteStore.delete(id: uuid)
            noteStore.writeToDisk()
        }
        model.selectedItemID = allItems.first?.id
    }

    private func performNoteAction(_ action: NoteAction, for note: Note) {
        Task {
            let result = await NoteActionRunner.run(action, noteID: note.id, store: noteStore)
            await MainActor.run {
                switch result {
                case .applied:
                    if let updated = noteStore.notes.first(where: { $0.id == note.id }) {
                        model.syncDraft(from: .note(id: updated.id, title: updated.displayTitle, body: updated.body, date: updated.modified, isMeeting: updated.source == .meeting))
                    }
                    model.showFeedback("Applied \(action.title)")
                case .nothingToDo(let reason), .rejected(let reason), .unavailable(let reason):
                    model.showFeedback(reason)
                }
            }
        }
    }

    private func exportTimeline(as format: ExportFormat) {
        let text: String
        let filename: String

        switch format {
        case .markdown:
            text = allItems.map { "### \($0.title) (\($0.date))\n\n\($0.body)\n" }.joined(separator: "\n---\n\n")
            filename = "utter-memory.md"
        case .csv:
            text = "Title,Date,Words,Content\n" + allItems.map { "\"\($0.title)\",\"\($0.date)\",\($0.wordCount),\"\($0.body.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: "\n")
            filename = "utter-memory.csv"
        case .text:
            text = allItems.map { "\($0.title) (\($0.date))\n\($0.body)" }.joined(separator: "\n\n")
            filename = "utter-memory.txt"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
            model.showFeedback("Exported timeline")
        }
    }

    private enum ExportFormat {
        case markdown, csv, text
    }
}
