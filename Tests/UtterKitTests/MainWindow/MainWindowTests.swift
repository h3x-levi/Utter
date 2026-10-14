import Foundation
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Main window")
@MainActor
struct MainWindowTests {
    @Test("--screen opens the screen and the section inside it", arguments: [
        ("dictation", SidebarItem.library, LibraryFilter.all),
        ("library", .library, .all),
        ("notes", .library, .notes),
        ("meetings", .library, .meetings),
        ("dictations", .library, .dictations),
        ("snippets", .words, .all),
        ("companion", .companion, .all),
        ("nonsense", .library, .all),
    ])
    func deepLinks(screen: String, item: SidebarItem, filter: LibraryFilter) {
        let selection = SidebarSelection(arguments: ["Utter", "--screen", screen])
        #expect(selection.item == item)
        #expect(selection.libraryFilter == filter)
    }

    @Test func wordsDeepLinkSelectsTheSection() {
        #expect(SidebarSelection(arguments: ["Utter", "--screen", "commands"]).wordsSection == .commands)
        #expect(SidebarSelection(arguments: ["Utter"]).item == .library)
    }

    @Test func companionRouteOpensSettingsAndLeavesLibrary() {
        var opened: [SettingsGroup?] = []
        let model = MainWindowModel(selection: SidebarSelection(arguments: ["Utter", "--screen", "companion"]),
                                    userData: UserData(storageDir: nil), history: TranscriptionHistory(storageDir: nil),
                                    notes: NoteStore(storageDir: nil), openSettings: { opened.append($0) })
        model.followRoute()
        #expect(opened == [.companion])
        #expect(model.selection.item == .library)
        model.followRoute()
        #expect(opened.count == 1, "Library itself never opens Settings")
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

    @Test func setupShowsOnlyWhatIsMissing() {
        typealias Setup = SetupNeeds
        let ready = Setup.Readiness(mic: true, ax: true, modelPresent: true, modelLoad: .ready)
        #expect(Setup.needs(ready, modelState: .bundled).isEmpty)
        #expect(Setup.cardTitle(1) == "One thing left")

        var missing = ready
        missing.mic = false
        missing.modelPresent = false
        #expect(Setup.needs(missing, modelState: .downloading(0.4)) == [.microphone, .model(downloading: 0.4)])
        #expect(Setup.cardTitle(Setup.needs(missing, modelState: nil).count) == "Two things left")

        var failed = ready
        failed.modelLoad = .failed("Out of memory")
        #expect(Setup.needs(failed, modelState: .bundled) == [.modelFailed("Out of memory")])
    }

    @Test func offersTheModelThisMacRunsBestWithoutRequiringIt() {
        let m4 = Device(chipName: "Apple M4", ramGB: 16, performanceCores: 4, totalCores: 10, isAppleSilicon: true, freeDiskGB: 100)
        let air = Device(chipName: "Apple M1", ramGB: 8, performanceCores: 4, totalCores: 8, isAppleSilicon: true, freeDiskGB: 100)
        let nothing: (SpeechModel.Tier) -> Bool = { _ in false }
        #expect(ModelStore.upgrade(recommended: m4.recommended, active: .small, onDisk: nothing)?.tier == .medium)
        #expect(ModelStore.upgrade(recommended: m4.recommended, active: .small, onDisk: { $0 == .medium }) == nil,
                "downloaded but not chosen: the user decided, so no offer")
        #expect(ModelStore.upgrade(recommended: m4.recommended, active: .medium, onDisk: nothing) == nil)
        #expect(ModelStore.upgrade(recommended: air.recommended, active: .small, onDisk: nothing) == nil, "8 GB stays on Small")
        #expect(m4.recommendationReason.hasPrefix("Your Apple M4 with 16 GB runs Medium smoothly"))
    }
}

@Suite("Library")
@MainActor
struct LibraryModelTests {
    private let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func make(paste: @escaping @MainActor (String) -> Void = { _ in }) -> (LibraryViewModel, NoteStore, TranscriptionHistory) {
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
                                     paste: paste)
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
        #expect(model.days.map(\.items.count) == [1], "a search shows only the days it found something on")
        model.search = "nowhere"
        #expect(model.days.isEmpty)
        model.search = ""
        #expect(model.days.first?.id == Calendar.current.startOfDay(for: .now))
        #expect(model.days.first?.items.map(\.title) == ["Groceries", "Running five minutes late", "Design sync"], "a day runs oldest first")
        #expect(model.days.count == 2)
        model.filter = .meetings
        model.search = ""
        #expect(model.days.map(\.items.count) == [1])
    }

    @Test func todayLeadsEvenWithNothingOnItsTape() {
        let history = TranscriptionHistory(storageDir: nil)
        history.entries = [TranscriptionEntry(text: "Book the dentist", timestamp: now.addingTimeInterval(-90_000))]
        let model = LibraryViewModel(selection: SidebarSelection(arguments: []), history: history,
                                     store: NoteStore(storageDir: nil))
        #expect(model.days.map(\.items.count) == [0, 1])
        #expect(model.days.first?.id == Calendar.current.startOfDay(for: .now))
    }

    @Test func groupsByCalendarDayNewestDayFirst() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 12)))
        let at = { (days: Int, hour: Int) in
            LibraryItem(TranscriptionEntry(text: "said \(days) \(hour)",
                                           timestamp: calendar.date(byAdding: .day, value: -days, to: now)!.addingTimeInterval(Double(hour) * 3_600)))
        }
        let days = LibraryViewModel.days([at(0, 2), at(0, -3), at(1, 0), at(5, 0), at(5, 4)], calendar: calendar)
        #expect(days.map(\.items.count) == [2, 1, 2])
        #expect(days[0].items.map(\.title) == ["said 0 -3", "said 0 2"])
        #expect(days[0].items.map(\.isMorning) == [true, false])

        #expect(LibraryViewModel.dayTitle(calendar.date(byAdding: .day, value: -1, to: now)!, now: now, calendar: calendar) == "Yesterday")
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now)!
        #expect(LibraryViewModel.dayTitle(lastYear, now: now, calendar: calendar).contains("2025"))
        #expect(!LibraryViewModel.dayTitle(now, now: now, calendar: calendar).contains("2026"))
    }

    @Test func tracksCarryTheirAppAndTalkTime() {
        let said = "Dear Ms Okafor, thank you for the quick reply. Tuesday works well for us, and I'll bring the revised plan."
        let estimated = LibraryItem(TranscriptionEntry(text: said, app: "Mail"))
        #expect(estimated.words == 20)
        #expect(estimated.talkTime == 8, "20 words at about 2.4 a second")
        #expect(estimated.destination == "Into Mail")
        #expect(estimated.heading == "Dear Ms Okafor")
        let recorded = LibraryItem(TranscriptionEntry(text: "Hi", duration: 3.25))
        #expect(recorded.talkTime == 3.25)
        #expect(recorded.destination == "Dictation")
        #expect(LibraryItem(TranscriptionEntry(text: "On my way")).talkTime == 3, "never shorter than three seconds")

        let meeting = LibraryItem(Note(title: "Sync", body: "**You:** hi", created: now, modified: now.addingTimeInterval(1_920),
                                       source: .meeting, titleIsCustom: true))
        #expect(LibraryViewModel.clock(meeting.talkTime) == "32:00")
        #expect(LibraryViewModel.clock(3_723) == "1:02:03")
        #expect(LibraryViewModel.clock(8) == "0:08")
        #expect(LibraryViewModel.talk(40) == "40 s")
        #expect(LibraryViewModel.talk(1_974) == "32 min 54 s")
        #expect(LibraryViewModel.talk(3_720) == "1 h 2 min")
        #expect(LibraryViewModel.summary([estimated, recorded]) == "2 tracks · 11 s of talk")
        #expect(LibraryViewModel.summary([meeting]) == "1 track · 32 min 0 s of talk")
    }

    @Test func trackNumbersCountEveryKindOldestFirst() throws {
        let (model, _, _) = make()
        let tapes = model.tapes
        let today = try #require(tapes[Calendar.current.startOfDay(for: .now)])
        #expect(today.map(\.title) == ["Groceries", "Running five minutes late", "Design sync"])
        let meeting = try #require(today.last)
        #expect(LibraryViewModel.trackNumber(meeting, in: tapes) == 3)
        model.filter = .meetings
        #expect(LibraryViewModel.trackNumber(meeting, in: model.tapes) == 3, "a filter doesn't renumber the tape")
    }

    @Test func aNewDictationWritesItselfInButTheFirstLoadDoesNot() {
        let (model, _, history) = make()
        #expect(model.freshID == nil)
        let fresh = TranscriptionEntry(text: "Just said this", timestamp: now.addingTimeInterval(30))
        history.entries.insert(fresh, at: 0)
        #expect(model.freshID == LibraryItem.dictationID(fresh.id))
    }

    @Test func pasteAgainTypesTheTextAndTicksTheTrack() throws {
        var pasted: [String] = []
        let (model, _, _) = make(paste: { pasted.append($0) })
        let item = try #require(model.visibleItems.first { $0.kind == .dictation })
        model.pasteAgain(item)
        #expect(pasted == ["Running five minutes late"])
        #expect(model.pastedIDs == [item.id])
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

    @Test func theRecordingBannerShowsOneHintAtATime() {
        let silent = MeetingNote.hint(heardOthers: false, onSpeakers: true)
        #expect(silent?.hasPrefix("Nothing heard") == true)
        #expect(MeetingNote.hint(heardOthers: true, onSpeakers: true)?.contains("headphones") == true)
        #expect(MeetingNote.hint(heardOthers: true, onSpeakers: false) == nil)
    }

    @Test func csvExportQuotesEveryTextCell() {
        let note = Note(title: "Say \"hi\"", body: "one, two", source: .typed, titleIsCustom: true)
        let csv = LibraryViewModel.export([LibraryItem(note)], as: .csv)
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "Date,Kind,Words,Title,Text")
        #expect(lines.last?.hasSuffix(",\"Note\",2,\"Say \"\"hi\"\"\",\"one, two\"") == true)
    }
}
