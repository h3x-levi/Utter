import Foundation
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Main window")
@MainActor
struct MainWindowTests {
    @Test("--screen opens the screen and the section inside it", arguments: [
        ("dictation", SidebarItem.home, LibraryFilter.all),
        ("library", .library, .all),
        ("notes", .library, .notes),
        ("meetings", .library, .meetings),
        ("dictations", .library, .dictations),
        ("snippets", .words, .all),
        ("companion", .companion, .all),
        ("nonsense", .home, .all),
    ])
    func deepLinks(screen: String, item: SidebarItem, filter: LibraryFilter) {
        let selection = SidebarSelection(arguments: ["Utter", "--screen", screen])
        #expect(selection.item == item)
        #expect(selection.libraryFilter == filter)
    }

    @Test func wordsDeepLinkSelectsTheSection() {
        #expect(SidebarSelection(arguments: ["Utter", "--screen", "commands"]).wordsSection == .commands)
        #expect(SidebarSelection(arguments: ["Utter"]).item == .home)
    }

    @Test func openingAnItemWidensAFilterThatWouldHideIt() {
        let selection = SidebarSelection(arguments: [])
        selection.libraryFilter = .meetings
        let id = UUID()
        selection.open(libraryItem: LibraryItem.dictationID(id))
        #expect(selection.item == .library)
        #expect(selection.libraryFilter == .all)
        #expect(selection.libraryItemID == "dictation-\(id.uuidString)")

        selection.libraryFilter = .dictations
        selection.open(libraryItem: LibraryItem.dictationID(id))
        #expect(selection.libraryFilter == .dictations)

        selection.libraryFilter = .notes
        selection.openNote(id)
        #expect(selection.libraryFilter == .all, "a note id may be a meeting, which Notes would hide")
    }

    @Test func aTurnLandsOnlyAfterProcessing() {
        let status = CaptureStatus()
        #expect(status.turn == .idle)
        status.apply(.recording)
        #expect(status.turn == .listening)
        status.apply(.processing(.transcribing))
        #expect(status.turn == .thinking)
        status.apply(.idle)
        #expect(status.turn == .landed)
        status.apply(.notice("Typed"))
        #expect(status.turn == .landed)
        status.apply(.error("Microphone is busy"))
        #expect(status.turn == .failed)
        status.apply(.idle)
        #expect(status.turn == .idle)
    }

    @Test func statusLineNamesWhatIsMissing() {
        #expect(CaptureStatus.line(for: .idle, micGranted: false, axGranted: true, hotkey: "Fn") == "Needs microphone access")
        #expect(CaptureStatus.line(for: .idle, micGranted: true, axGranted: false, hotkey: "Fn") == "Needs Accessibility access")
        #expect(CaptureStatus.line(for: .idle, micGranted: true, axGranted: true, hotkey: "Fn") == "Ready. Hold Fn to talk.")
        #expect(CaptureStatus.line(for: .processing(.typing), micGranted: true, axGranted: true, hotkey: "Fn") == "Typing")
    }

    @Test func homeShowsOnlyWhatIsMissing() {
        typealias Home = HomeViewModel
        let ready = Home.Readiness(mic: true, ax: true, modelPresent: true, modelLoad: .ready)
        #expect(Home.needs(ready, modelState: .bundled).isEmpty)
        #expect(Home.cardTitle(1) == "One thing left.")

        var missing = ready
        missing.mic = false
        missing.modelPresent = false
        #expect(Home.needs(missing, modelState: .downloading(0.4)) == [.microphone, .model(downloading: 0.4)])
        #expect(Home.cardTitle(Home.needs(missing, modelState: nil).count) == "2 things left.")

        var failed = ready
        failed.modelLoad = .failed("Out of memory")
        #expect(Home.needs(failed, modelState: .bundled) == [.modelFailed("Out of memory")])
    }

    @Test func ribbonBeadsFollowWordsAndOnlyFillTheTroughWhenCrowded() {
        let light = RibbonLayout.widths([1, 10, 20, 100], in: 800)
        #expect(light == [12, 40, 80, 120], "a light day keeps bead-sized beads instead of stretching two across the trough")
        #expect(RibbonLayout.starts(light) == [0, 16, 60, 144])

        let crowded = RibbonLayout.widths(Array(repeating: 30, count: 40) + [1], in: 1_200)
        #expect(abs(crowded.reduce(0, +) + RibbonLayout.spacing * 40 - 1_200) < 0.001)
        #expect(crowded.allSatisfy { $0 >= 0 })
        #expect(crowded[0] > crowded[40])

        #expect(RibbonLayout.widths([], in: 100).isEmpty)
    }
}

@Suite("Library")
@MainActor
struct LibraryModelTests {
    private let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func make() -> (LibraryViewModel, NoteStore, TranscriptionHistory) {
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = [
            TranscriptionEntry(text: "Running five minutes late", timestamp: now.addingTimeInterval(-60)),
            TranscriptionEntry(text: "Book the dentist", timestamp: now.addingTimeInterval(-90_000)),
        ]
        let store = NoteStore(storageDir: nil, seed: [
            Note(body: "Groceries\noat milk, lemons", modified: now.addingTimeInterval(-120)),
            Note(title: "Design sync", body: "**You:** keep the pill small", created: now.addingTimeInterval(-30),
                 modified: now.addingTimeInterval(-20), source: .meeting, titleIsCustom: true),
        ])
        let model = LibraryViewModel(selection: SidebarSelection(arguments: []), history: history, store: store,
                                     prepareMeeting: { nil })
        return (model, store, history)
    }

    @Test func filtersSearchesAndGroupsByDay() {
        let (model, _, _) = make()
        #expect(model.visibleItems.map(\.title) == ["Design sync", "Running five minutes late", "Groceries", "Book the dentist"])
        #expect(model.count(.meetings) == 1)
        model.filter = .dictations
        #expect(model.visibleItems.count == 2)
        model.filter = .all
        model.search = "lemons"
        #expect(model.visibleItems.map(\.title) == ["Groceries"])
        model.search = ""
        #expect(model.days.map(\.title).first == "Today")
        #expect(model.days.count == 2)
    }

    @Test func groupsByRecencyTheWayNotesDoes() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 12)))
        let ago = { (days: Int) in LibraryItem(TranscriptionEntry(text: "said", timestamp: calendar.date(byAdding: .day, value: -days, to: now)!)) }
        let days = LibraryViewModel.days([ago(0), ago(1), ago(5), ago(30), ago(40), ago(400)], now: now, calendar: calendar)
        let september = calendar.date(byAdding: .day, value: -40, to: now)!.formatted(.dateTime.month(.wide))
        #expect(days.map(\.title) == ["Today", "Yesterday", "Previous 30 Days", september, "2025"])
        #expect(days.map(\.items.count) == [1, 1, 2, 1, 1])
    }

    @Test func meetingRowsPreviewEachSide() {
        let note = Note(title: "Sync", body: "**You:** one\n\n**You:** two\n\n**Sam:** three", source: .meeting, titleIsCustom: true)
        #expect(LibraryItem(note).previewTurns.map(\.text) == ["one", "three"])
        #expect(LibraryViewModel.arrival(from: 3, to: 4) != nil)
        #expect(LibraryViewModel.arrival(from: 0, to: 12) == nil, "a load or a filter swap never animates")
    }

    @Test func deleteHidesAtOnceAndUndoBringsItBack() throws {
        let (model, store, _) = make()
        let groceries = try #require(model.visibleItems.first { $0.title == "Groceries" })
        model.selectedID = groceries.id
        model.delete(groceries)
        #expect(!model.visibleItems.contains(groceries))
        #expect(store.notes.count == 2)
        #expect(model.selectedID != groceries.id)

        model.undoDelete()
        #expect(model.visibleItems.contains(groceries))
        #expect(model.selectedID == groceries.id)

        model.delete(groceries)
        model.commitPendingDelete()
        #expect(store.notes.count == 1)
        #expect(model.pendingDelete == nil)
    }

    @Test func newAndConvertedNotesAreSelectedAndVisible() throws {
        let (model, store, history) = make()
        model.filter = .dictations
        let entry = try #require(history.entries.first)
        model.convertToNote(entry)
        #expect(model.filter == .all)
        #expect(model.selectedNote?.body == entry.text)
        #expect(model.selectedNote?.source == .dictated)

        model.filter = .meetings
        model.newNote()
        #expect(model.filter == .all)
        #expect(store.notes.count == 4)
        #expect(model.selectedNote?.body == "")
    }

    @Test func titleDraftFollowsTheNoteOnScreen() throws {
        let (model, store, _) = make()
        let meeting = try #require(store.notes.first { $0.source == .meeting })
        let groceries = try #require(store.notes.first { $0.source == .typed })
        model.edit(meeting)
        #expect(model.titleDraft == "Design sync")
        model.edit(groceries)
        #expect(model.titleDraft == "")
        model.titleDraft = "Shopping "
        #expect(store.notes.first { $0.id == groceries.id }?.title == "Shopping")
        #expect(store.notes.first { $0.id == meeting.id }?.title == "Design sync")
    }

    @Test func openingANoteMakesItTheOneControlOptionNAddsTo() throws {
        let (model, store, _) = make()
        let meeting = try #require(store.notes.first { $0.source == .meeting })
        let groceries = try #require(store.notes.first { $0.source == .typed })
        store.selectedNoteID = meeting.id
        model.edit(groceries)
        #expect(store.captureDestination(appendsToOpenNote: true) == .appending(id: groceries.id, title: "Groceries"))
    }

    @Test func aKeystrokeReplacesOnlyTheEditedItem() throws {
        let (model, store, _) = make()
        let groceries = try #require(store.notes.first { $0.source == .typed })
        model.body(of: groceries).wrappedValue = "Groceries\noat milk, lemons, bread"
        #expect(model.allItems.first { $0.uuid == groceries.id }?.words == 5)
        #expect(model.allItems.count == 4)
        #expect(zip(model.allItems, model.allItems.dropFirst()).allSatisfy { $0.date >= $1.date })

        var edited = groceries
        edited.body += "\nbread"
        edited.modified = now.addingTimeInterval(60)
        let stray = LibraryItem(TranscriptionEntry(text: "Not in any store", timestamp: now))
        let patched = LibraryViewModel.replacingEditedNote(in: [stray, LibraryItem(groceries)], old: [groceries], new: [edited])
        #expect(patched?.map(\.title) == ["Groceries", "Not in any store"], "a rebuild would have dropped the stray item")
        #expect(patched?.first?.words == 5)
        #expect(LibraryViewModel.replacingEditedNote(in: [], old: [groceries], new: [edited, groceries]) == nil)
    }

    @Test func meetingTurnsSplitAtSpeakerHeadings() {
        let turns = LibraryItem.turns(in: "# Meeting, Oct 12\n\n**You:** Let's start.\nWith the pill.\n\n**Sam:** Agreed.\n")
        #expect(turns.map(\.speaker) == ["You", "Sam"])
        #expect(turns.map(\.text) == ["Let's start.\nWith the pill.", "Agreed."])
        #expect(LibraryItem.turns(in: "No headings here").first?.speaker == nil)
    }

    @Test func homeSummaryCountsTodaysWords() throws {
        let (model, _, _) = make()
        let today = model.allItems.filter { Calendar.current.isDateInToday($0.date) }
        #expect(HomeViewModel.summary(today, on: now).hasSuffix(" · 3 dictations and notes, 12 words"))
        #expect(HomeViewModel.summary([], on: now) == now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
    }

    @Test func csvExportQuotesEveryTextCell() {
        let note = Note(title: "Say \"hi\"", body: "one, two", source: .typed, titleIsCustom: true)
        let csv = LibraryViewModel.export([LibraryItem(note)], as: .csv)
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "Date,Kind,Words,Title,Text")
        #expect(lines.last?.hasSuffix(",\"Note\",2,\"Say \"\"hi\"\"\",\"one, two\"") == true)
    }
}
