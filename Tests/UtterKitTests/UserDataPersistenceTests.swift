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
        saved.flushNow()

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

    private static let goldenKeys: Set<String> = [
        "words", "snippets", "language", "voiceCommands", "spokenPunctuation", "hotkeyId", "hotkeyName",
        "doubleTapHotkeyForHandsFree", "appTheme", "scratchpad", "customAICommands",
        "alwaysShowPill", "showInDock", "soundsEnabled", "muteMusicWhileDictating",
        "captureAppendsToOpenNote", "sentencePolishEnabled", "speechBiasEnabled",
        "useSurroundingContext", "perAppToneEnabled", "livePreviewEnabled",
        "offerToTranscribeCalls", "keepHistory", "companionEnabled", "companionCharacter",
        "companionSize", "companionPetBehaviours", "companionUserName",
        "companionStretchMinutes", "companionWaterMinutes", "companionPomodoroFocusMinutes",
        "companionPomodoroBreakMinutes", "companionPinnedMessage", "companionSounds",
        "companionObject", "companionMemoryEnabled", "companionGoalsEnabled",
        "companionWindowEdges", "companionQuietMode", "companionAutomaticQuietMode",
        "companionHydrationGoal", "companionStretchGoal", "companionFocusGoal",
        "companionDictationGoal", "companionProgress",
    ]

    private static let goldenFile = """
    {
      "words": ["Kubernetes", "Utter"],
      "snippets": [{"trigger": "sig", "expansion": "Kind regards"}],
      "language": "english",
      "voiceCommands": false,
      "spokenPunctuation": true,
      "hotkeyId": "rightOption",
      "hotkeyName": "Right ⌥ Option",
      "doubleTapHotkeyForHandsFree": false,
      "appTheme": "midnight",
      "scratchpad": "draft",
      "customAICommands": [{
        "id": "5B3D8C2E-1F4A-4B6C-9D8E-0A1B2C3D4E5F",
        "trigger": "make concise", "systemPrompt": "Shorten it.",
        "userPromptTemplate": "{{text}}", "replacesSelection": false
      }],
      "alwaysShowPill": false,
      "showInDock": true,
      "soundsEnabled": false,
      "muteMusicWhileDictating": true,
      "captureAppendsToOpenNote": false,
      "sentencePolishEnabled": false,
      "speechBiasEnabled": false,
      "useSurroundingContext": true,
      "perAppToneEnabled": true,
      "livePreviewEnabled": true,
      "offerToTranscribeCalls": true,
      "keepHistory": false,
      "companionEnabled": true,
      "companionCharacter": "pixel-dog-brown",
      "companionSize": "huge",
      "companionPetBehaviours": false,
      "companionUserName": "Alex",
      "companionStretchMinutes": 30,
      "companionWaterMinutes": 60,
      "companionPomodoroFocusMinutes": 25,
      "companionPomodoroBreakMinutes": 7,
      "companionPinnedMessage": "Ship it",
      "companionSounds": false,
      "companionObject": "yarn",
      "companionMemoryEnabled": false,
      "companionGoalsEnabled": false,
      "companionWindowEdges": false,
      "companionQuietMode": true,
      "companionAutomaticQuietMode": false,
      "companionHydrationGoal": 6,
      "companionStretchGoal": 5,
      "companionFocusGoal": 4,
      "companionDictationGoal": 900,
      "companionProgress": {
        "day": 20261010, "hydration": 1, "stretches": 2, "focusBlocks": 3,
        "dictationWords": 4, "dismissed": {"water": 2}, "preferredHours": {"stretch": 9},
        "extraDelayMinutes": {"water": 5}, "unlocked": ["loaf", "rolling"],
        "lifetimeWords": 1200, "dictations": 8, "memoriesCreated": 3, "memoriesCompleted": 2
      }
    }
    """

    private func jsonObject(at directory: URL) throws -> NSDictionary {
        let data = try Data(contentsOf: directory.appendingPathComponent("userdata.json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    @Test("A golden userdata.json round-trips every key unchanged")
    func goldenFileRoundTrips() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(Self.goldenFile.utf8).write(to: directory.appendingPathComponent("userdata.json"))
        let original = try jsonObject(at: directory)
        #expect(Set(original.allKeys.compactMap { $0 as? String }) == Self.goldenKeys)

        let data = UserData(storageDir: directory)
        try FileManager.default.removeItem(at: directory.appendingPathComponent("userdata.json"))
        data.save()
        data.flushNow()

        #expect(try jsonObject(at: directory) == original)
    }

    @Test("Legacy keys and values are migrated on load")
    func legacyKeysAreMigrated() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = """
        {"scratchpadResumesLastNote": false, "appTheme": "ember",
         "companionCharacter": "pack:pixel-dog-brown", "companionSize": "gigantic",
         "companionObject": "unknown", "companionStretchMinutes": 9999}
        """
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("userdata.json"))

        let loaded = UserData(storageDir: directory)

        #expect(loaded.captureAppendsToOpenNote == false)
        #expect(loaded.appTheme == ThemeManager.systemThemeID)
        #expect(loaded.companionCharacter == "pixel-dog-brown")
        #expect(loaded.companionSize == UserData.defaultCompanionSize)
        #expect(loaded.companionObject == .none)
        #expect(loaded.companionStretchMinutes == 480)

        loaded.save()
        loaded.flushNow()
        let saved = try jsonObject(at: directory)
        #expect(saved["captureAppendsToOpenNote"] as? Bool == false)
        #expect(saved["scratchpadResumesLastNote"] == nil)
    }

    private func loadHotkey(_ fields: String) throws -> (loaded: UserData, saved: NSDictionary) {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("{\(fields)}".utf8).write(to: directory.appendingPathComponent("userdata.json"))
        let loaded = UserData(storageDir: directory)
        loaded.save()
        loaded.flushNow()
        return (loaded, try jsonObject(at: directory))
    }

    @Test("Every stored hotkey label migrates to its id, and ids are written from then on",
          arguments: [
            ("Fn", "fn"),
            ("Right ⌥ Option", "rightOption"),
            ("Right ⌘ Command", "rightCommand"),
            ("Right ⌃ Control", "rightControl"),
          ])
    func hotkeyLabelMigratesToId(label: String, id: String) throws {
        let (loaded, saved) = try loadHotkey("\"hotkeyName\": \"\(label)\"")

        #expect(loaded.hotkeyId == id)
        #expect(loaded.hotkeyName == label)
        #expect(saved["hotkeyId"] as? String == id)
    }

    @Test("A stored id wins over a stale label")
    func hotkeyIdWins() throws {
        let (loaded, _) = try loadHotkey("\"hotkeyId\": \"rightControl\", \"hotkeyName\": \"Renamed\"")

        #expect(loaded.hotkeyId == "rightControl")
        #expect(loaded.hotkeyName == "Right ⌃ Control")
    }

    @Test("An unknown hotkey value falls back to Fn")
    func unknownHotkeyFallsBackToFn() throws {
        let (loaded, saved) = try loadHotkey("\"hotkeyName\": \"Caps Lock\"")

        #expect(loaded.hotkeyId == "fn")
        #expect(loaded.hotkeyName == "Fn")
        #expect(saved["hotkeyId"] as? String == "fn")
    }

    @Test("A burst of saves is debounced into one write holding the latest value")
    func burstCoalesces() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = UserData(storageDir: directory, debounce: 0.1)

        for index in 0..<20 {
            data.scratchpad = "draft \(index)"
            data.save()
        }
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("userdata.json").path))

        try await Task.sleep(nanoseconds: 600_000_000)

        #expect(data.diskWriteCount == 1)
        #expect(try jsonObject(at: directory)["scratchpad"] as? String == "draft 19")
    }

    @Test("flushNow writes the latest value synchronously and then has nothing left to write")
    func flushWritesLatest() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = UserData(storageDir: directory, debounce: 60)

        data.scratchpad = "first"
        data.save()
        data.scratchpad = "latest"
        data.save()
        data.flushNow()

        #expect(try jsonObject(at: directory)["scratchpad"] as? String == "latest")
        #expect(data.diskWriteCount == 1)
        data.flushNow()
        #expect(data.diskWriteCount == 1)
    }

    @Test("A failed write keeps the in-memory value and retries on the next flush")
    func failedWriteKeepsValue() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent("not-created", isDirectory: true)
        let data = UserData(storageDir: missing, debounce: 60)

        data.scratchpad = "keep me"
        data.save()
        data.flushNow()

        #expect(data.scratchpad == "keep me")
        #expect(data.diskWriteCount == 0)

        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        data.flushNow()

        #expect(data.diskWriteCount == 1)
        #expect(try jsonObject(at: missing)["scratchpad"] as? String == "keep me")
    }
}
