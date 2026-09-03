import SwiftUI

// MARK: - Reset

/// Erase everything Utter has saved, behind a confirmation.
///
/// Extracted from the unreachable `PrivacyView` so the action exists on screen again.
/// The destructive path itself is unchanged — see `clearAllData()`, whose ordering is
/// load-bearing and documented there.
@MainActor
private final class DataResetModel: ObservableObject {
    @Published var showClearConfirm = false
    @Published var cleared = false

    func reset() {
        TranscriptionHistory.shared.deleteAll()
        NoteStore.shared.deleteAll()

        let userData = UserData.shared
        userData.dictionaryWords.removeAll()
        userData.snippets.removeAll()
        userData.customAICommands.removeAll()
        userData.scratchpad = ""
        userData.lastTranscription = ""
        userData.selectedLanguage = "english"
        userData.voiceCommandsEnabled = true
        userData.spokenPunctuationEnabled = false
        userData.hotkeyName = "Fn"
        userData.appTheme = ThemeManager.systemThemeID
        userData.save()

        ThemeManager.shared.setTheme(ThemeManager.systemThemeID)

        let fm = FileManager.default
        try? fm.removeItem(at: AppDirectory.support)
        for legacy in AppDirectory.legacySupportDirectories {
            try? fm.removeItem(at: legacy)
        }

        cleared = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.cleared = false
        }
    }
}

struct DataResetSection: View {
    @StateObject private var model = DataResetModel()

    var body: some View {
        HStack(spacing: Space.x3) {
            Spacer()
            if model.cleared {
                Label("All data cleared", systemImage: "checkmark.circle.fill")
                    .typo(.caption, ink: Tint.successText)
            }
            GlassButton(
                title: "Reset Utter",
                systemImage: "arrow.counterclockwise",
                role: .destructive
            ) {
                model.showClearConfirm = true
            }
            Spacer()
        }
        .padding(.top, Space.x1)
        .alert("Reset Utter?", isPresented: $model.showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                model.reset()
            }
        } message: {
            Text("""
            This permanently deletes your transcription history, every note (the only \
            copy of what you dictated into Utter), any companion packs you installed, \
            dictionary words, snippets, custom AI commands, and all preferences — \
            including your theme and hotkey choice. This cannot be undone.
            """)
        }
    }
}
