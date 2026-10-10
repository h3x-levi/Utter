import Foundation
import SwiftUI

/// Preview-mode isolation and deterministic fixtures for marketing snapshots.
///
/// Ensures static snapshot rendering (`--render-snapshots`) operates entirely
/// within an in-memory sandbox:
/// 1. Real Application Support files (`userdata.json`, `history.json`, `notes.json`,
///    `companion-memories.json`, `streak.json`, `crashes/`) are NEVER read or written.
/// 2. Fixes harmless, clean, realistic product and developer marketing content
///    for all views, eliminating private transcripts and developer environment values.
/// 3. Does not initialize audio/microphone hardware, model warming, notification centers,
///    or crash reporting handlers.
public enum SnapshotPreviewMode {
    public private(set) static var isActive: Bool = false

    @MainActor
    public static func disable() {
        isActive = false
        UserData.preview = nil
        TranscriptionHistory.preview = nil
        NoteStore.preview = nil
        CompanionMemoryStore.preview = nil
        CrashReporter.preview = nil
    }

    @MainActor
    public static func enable() {
        guard !isActive else { return }
        isActive = true

        print("🛡️ Enabling SnapshotPreviewMode sandbox (in-memory fixtures, zero disk I/O)...")

        // 1. Populate harmless UserData fixtures
        let userData = UserData(storageDir: nil)
        UserData.preview = userData
        userData.dictionaryWords = ["Kubernetes", "GraphQL", "PostgreSQL", "Tailwind", "Whisper", "CoreAudio", "Metal"]
        userData.snippets = [
            ("meet", "https://meet.google.com/abc-defg-hij"),
            ("addr", "1 Infinite Loop, Cupertino, CA 95014"),
            ("sig", "Sent with Utter on macOS")
        ]
        userData.hotkeyName = "Fn"
        userData.doubleTapHotkeyForHandsFree = true
        userData.sentencePolishEnabled = true
        userData.speechBiasEnabled = true
        userData.alwaysShowPill = true
        userData.companionEnabled = true
        userData.companionCharacter = "gray"
        userData.companionSize = .medium
        userData.companionUserName = "Alex"
        userData.companionPinnedMessage = "Ready to transcribe"
        userData.customAICommands = [
            CustomAICommand(
                trigger: "Format as bullet points",
                systemPrompt: "Convert the selected text into clean, concise bullet points.",
                replacesSelection: true
            )
        ]
        var progress = CompanionProgress(day: CompanionProgress.dayStamp(Date()))
        progress.lifetimeWords = 1420
        progress.dictations = 34
        progress.unlocked = Set(["grooming", "rolling", "loaf"])
        userData.companionProgress = progress

        // 2. Populate harmless TranscriptionHistory fixtures
        let history = TranscriptionHistory(storageDir: nil)
        TranscriptionHistory.preview = history
        let now = Date()
        let sampleEntries: [TranscriptionEntry] = [
            TranscriptionEntry(
                text: "Hold Fn in any macOS app to dictate with local whisper.cpp Metal acceleration.",
                timestamp: now.addingTimeInterval(-180),
                language: "English"
            ),
            TranscriptionEntry(
                text: "Refactor speech engine queue to stream partial audio buffers directly into whisper.cpp.",
                timestamp: now.addingTimeInterval(-3600 * 2),
                language: "English"
            ),
            TranscriptionEntry(
                text: "All voice dictation runs entirely in unified memory with zero network telemetry.",
                timestamp: now.addingTimeInterval(-86400),
                language: "English"
            ),
            TranscriptionEntry(
                text: "Weekly engineering sync: audio capture latency benchmarked at 168 milliseconds.",
                timestamp: now.addingTimeInterval(-86400 * 2),
                language: "English"
            )
        ]
        history.entries = sampleEntries
        history.totalWords = sampleEntries.reduce(0) { $0 + $1.wordCount }
        history.streakDays = 3

        // 3. Populate harmless NoteStore fixtures
        let note1ID = UUID()
        let note2ID = UUID()
        let note3ID = UUID()
        let sampleNotes: [Note] = [
            Note(
                id: note1ID,
                title: "Voice Workspace Architecture",
                body: """
                # Voice Workspace Architecture

                Utter processes speech entirely on-device via Metal GPU kernels in unified memory.

                ## Core Guarantees
                - Zero cloud dependencies or recurring fees
                - 100% air-gapped privacy with zero network sockets
                - Real-time transcription streaming into any macOS application
                """,
                created: now.addingTimeInterval(-86400 * 3),
                modified: now.addingTimeInterval(-1200),
                tags: ["Architecture", "macOS"],
                source: .dictated
            ),
            Note(
                id: note2ID,
                title: "Audio Engine Roadmap",
                body: "Dual-channel meeting recording with speaker diarization and CoreAudio tap integration.",
                created: now.addingTimeInterval(-86400 * 5),
                modified: now.addingTimeInterval(-86400 * 2),
                tags: ["Roadmap"],
                source: .typed
            ),
            Note(
                id: note3ID,
                title: "Custom Vocabulary List",
                body: "Domain terms and technical framework identifiers added for speech bias prompt injection.",
                created: now.addingTimeInterval(-86400 * 7),
                modified: now.addingTimeInterval(-86400 * 4),
                tags: ["Vocabulary"],
                source: .typed
            )
        ]
        NoteStore.preview = NoteStore(storageDir: nil, seed: sampleNotes, selectedID: note1ID)

        // 4. Populate harmless CompanionMemoryStore fixtures
        let sampleMemories: [CompanionMemory] = [
            CompanionMemory(
                id: UUID(),
                text: "Drink a glass of water",
                createdAt: now.addingTimeInterval(-3600),
                source: .spoken,
                completedAt: nil
            ),
            CompanionMemory(
                id: UUID(),
                text: "Take a 2-minute posture stretch",
                createdAt: now.addingTimeInterval(-7200),
                source: .spoken,
                completedAt: now.addingTimeInterval(-3600)
            )
        ]
        CompanionMemoryStore.preview = CompanionMemoryStore(storageDir: nil, seed: sampleMemories)
        CrashReporter.preview = CrashReporter(crashDir: nil)

        // 5. Ensure navigation starts on Capture
        SidebarSelection.shared.item = .capture
        WorkspaceSectionSelection.shared.library = .transcripts
        WorkspaceSectionSelection.shared.tools = .dictionary
    }
}
