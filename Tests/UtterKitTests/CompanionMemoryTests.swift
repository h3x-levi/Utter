import Foundation
import Testing
@testable import UtterKit
@testable import UtterCore

@Suite("Companion memory", .serialized)
@MainActor
struct CompanionMemoryTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-memory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Plain language is cleaned without inventing a reminder time")
    func deterministicWithoutDate() throws {
        let proposal = try CompanionMemoryParser.deterministic(
            "Please remember to buy oat milk"
        )
        #expect(proposal.text == "buy oat milk")
        #expect(proposal.remindAt == nil)
    }

    @Test("Empty and oversized memories are rejected at the boundary")
    func inputValidation() throws {
        #expect(throws: CompanionMemoryError.empty) {
            try CompanionMemoryParser.deterministic("   ")
        }
        #expect(throws: CompanionMemoryError.tooLong) {
            try CompanionMemoryParser.deterministic(String(repeating: "a", count: 1_001))
        }
    }

    @Test("Memories round-trip with their source and reminder")
    func roundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var created = 0
        let store = CompanionMemoryStore(
            storageDir: directory,
            onCreated: { created += 1 }
        )
        let remindAt = Date().addingTimeInterval(3_600)
        let saved = try store.add(
            proposal: CompanionMemoryProposal(text: "Send the proposal", remindAt: remindAt),
            source: .typed
        )

        let loaded = CompanionMemoryStore(storageDir: directory)
        #expect(created == 1)
        #expect(loaded.memories.count == 1)
        #expect(loaded.memories[0].id == saved.id)
        #expect(loaded.memories[0].text == "Send the proposal")
        #expect(loaded.memories[0].source == .typed)
        #expect(abs((loaded.memories[0].remindAt ?? .distantPast)
            .timeIntervalSince(remindAt)) < 0.001)
    }

    @Test("Completing a memory is durable and counted once")
    func completion() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var completed = 0
        let store = CompanionMemoryStore(
            storageDir: directory,
            onCompleted: { completed += 1 }
        )
        let memory = try store.add(
            proposal: CompanionMemoryProposal(text: "Call the dentist", remindAt: nil),
            source: .spoken
        )
        let finished = Date()
        store.complete(id: memory.id, at: finished)
        store.complete(id: memory.id, at: finished.addingTimeInterval(1))

        let loaded = CompanionMemoryStore(storageDir: directory)
        #expect(completed == 1)
        #expect(loaded.completed.count == 1)
        #expect(abs((loaded.completed[0].completedAt ?? .distantPast)
            .timeIntervalSince(finished)) < 0.001)
    }

    @Test("Snooze moves an active reminder and clears delivery state")
    func snooze() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionMemoryStore(storageDir: directory)
        let now = Date()
        let memory = try store.add(
            proposal: CompanionMemoryProposal(
                text: "Move the laundry",
                remindAt: now.addingTimeInterval(60)
            ),
            source: .typed,
            now: now
        )
        _ = store.markDelivered(id: memory.id, at: now)
        store.snooze(id: memory.id, minutes: 10, from: now)

        let updated = store.memories.first { $0.id == memory.id }
        #expect(updated?.deliveredAt == nil)
        #expect(updated?.remindAt == now.addingTimeInterval(600))
    }

    @Test("An unreadable memory file is preserved instead of overwritten")
    func corruptFileIsSalvaged() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("companion-memories.json")
        try Data("{broken".utf8).write(to: file)

        let store = CompanionMemoryStore(storageDir: directory)

        #expect(store.memories.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let salvaged = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("companion-memories-unreadable-") }
        #expect(salvaged.count == 1)
        #expect(try Data(contentsOf: salvaged[0]) == Data("{broken".utf8))
    }

    @Test("A failed save rolls the in-memory mutation back")
    func failedSaveRollsBack() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let invalidStorage = directory.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: invalidStorage)
        var created = 0
        let store = CompanionMemoryStore(
            storageDir: invalidStorage,
            onCreated: { created += 1 }
        )

        #expect(throws: CompanionMemoryError.self) {
            try store.add(
                proposal: CompanionMemoryProposal(text: "Never show false success", remindAt: nil),
                source: .typed
            )
        }
        #expect(store.memories.isEmpty)
        #expect(created == 0)
    }

    @Test("A damaged newest file restores the previous generation")
    func previousGenerationRecovery() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CompanionMemoryStore(storageDir: directory)
        _ = try store.add(
            proposal: CompanionMemoryProposal(text: "First", remindAt: nil),
            source: .typed
        )
        _ = try store.add(
            proposal: CompanionMemoryProposal(text: "Second", remindAt: nil),
            source: .typed
        )
        let file = directory.appendingPathComponent("companion-memories.json")
        try Data("{broken".utf8).write(to: file, options: .atomic)

        let recovered = CompanionMemoryStore(storageDir: directory)

        #expect(recovered.memories.map(\.text) == ["First"])
        #expect(recovered.lastError?.contains("restored the previous") == true)
        #expect(CompanionMemoryStore(storageDir: directory).memories.map(\.text) == ["First"])
    }

    @Test("System notifications are only initialized inside a real app bundle")
    func notificationBundleGate() {
        #expect(CompanionNotificationScheduler.supportsSystemNotifications(
            bundleURL: URL(fileURLWithPath: "/Applications/Utter.app")
        ))
        #expect(!CompanionNotificationScheduler.supportsSystemNotifications(
            bundleURL: URL(fileURLWithPath: "/usr/libexec/swift/pm")
        ))
        #expect(!CompanionNotificationScheduler.supportsSystemNotifications(
            bundleURL: URL(fileURLWithPath: "/tmp/UtterPackageTests.xctest")
        ))
    }
}

@Suite("Companion progression")
struct CompanionProgressionTests {
    @Test("Rewards unlock exactly at cumulative word milestones")
    func milestones() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-progression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = UserData(storageDir: directory)
        defer { data.flushNow() }

        _ = data.recordCompanionDictation(words: 999)
        #expect(data.companionRewardUnlocked(.ball))
        #expect(!data.companionRewardUnlocked(.yarn))

        _ = data.recordCompanionDictation(words: 1)
        #expect(data.companionRewardUnlocked(.yarn))
        #expect(data.companionRewardUnlocked(.curiousTrill))
        #expect(!data.companionRewardUnlocked(.grooming))

        _ = data.recordCompanionDictation(words: 1_500)
        #expect(data.companionRewardUnlocked(.grooming))
    }

    @Test("Lifetime word migration is monotonic and grants retroactive rewards")
    func migration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-progression-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = UserData(storageDir: directory)
        defer { data.flushNow() }

        let first = data.syncCompanionLifetimeWords(10_000)
        let second = data.syncCompanionLifetimeWords(500)

        #expect(data.companionProgress.lifetimeWords == 10_000)
        #expect(first.contains(.rolling))
        #expect(second.isEmpty)
    }
}
