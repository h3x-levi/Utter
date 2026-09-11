import Foundation
import Testing
@testable import UtterKit

@Suite("User settings persistence")
struct UserDataPersistenceTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("utter-userdata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Settings survive an atomic round trip")
    func roundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = UserData(storageDir: directory)
        saved.dictionaryWords = ["Utter", "WhisperKit"]
        saved.snippets = [(trigger: "sig", expansion: "Kind regards")]
        saved.captureAppendsToOpenNote = false
        saved.companionSize = .huge
        saved.companionMemoryEnabled = true
        saved.companionWindowEdges = false
        saved.companionHydrationGoal = 6
        _ = saved.recordCompanionReminder(.water, completed: false)
        _ = saved.recordCompanionReminder(.stretch, completed: true)
        _ = saved.recordCompanionDictation(words: 1_200)
        saved.customAICommands = [
            CustomAICommand(trigger: "make concise", systemPrompt: "Shorten it.")
        ]
        saved.doubleTapHotkeyForHandsFree = false
        saved.save()

        let loaded = UserData(storageDir: directory)
        #expect(loaded.doubleTapHotkeyForHandsFree == false)
        #expect(loaded.dictionaryWords == saved.dictionaryWords)
        #expect(loaded.snippets.map(\.trigger) == ["sig"])
        #expect(loaded.snippets.map(\.expansion) == ["Kind regards"])
        #expect(loaded.captureAppendsToOpenNote == false)
        #expect(loaded.companionSize == .huge)
        #expect(loaded.companionMemoryEnabled)
        #expect(loaded.companionWindowEdges == false)
        #expect(loaded.companionHydrationGoal == 6)
        #expect(loaded.companionProgress.dismissed["water"] == 1)
        #expect(loaded.companionProgress.extraDelayMinutes["water"] == 5)
        #expect(loaded.companionProgress.stretches == 1)
        #expect(loaded.companionProgress.dictationWords == 1_200)
        #expect(loaded.companionProgress.lifetimeWords == 1_200)
        #expect(loaded.companionProgress.dictations == 1)
        #expect(loaded.companionRewardUnlocked(.ball))
        #expect(loaded.companionRewardUnlocked(.yarn))
        #expect(loaded.companionRewardUnlocked(.curiousTrill))
        #expect(!loaded.companionAnimationUnlocked(.grooming))
        #expect(!loaded.companionAnimationUnlocked(.rolling))
        #expect(loaded.customAICommands == saved.customAICommands)
    }

    @Test("Unreadable settings are preserved instead of overwritten")
    func corruptFileIsSalvaged() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appendingPathComponent("userdata.json")
        try Data("{not json".utf8).write(to: settings)

        _ = UserData(storageDir: directory)

        #expect(!FileManager.default.fileExists(atPath: settings.path))
        let salvaged = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("userdata-unreadable-") }
        #expect(salvaged.count == 1)
        #expect(try Data(contentsOf: salvaged[0]) == Data("{not json".utf8))
    }
}
