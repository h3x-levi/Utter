import SwiftUI

// MARK: - Reset

/// Erase everything Utter has saved, behind a confirmation.
///
/// Extracted from the unreachable `PrivacyView` so the action exists on screen again.
/// The destructive path itself is unchanged — see `clearAllData()`, whose ordering is
/// load-bearing and documented there.
struct DataResetSection: View {
    @State private var showClearConfirm = false
    @State private var cleared = false

    var body: some View {
        HStack(spacing: Space.x3) {
            Spacer()
            if cleared {
                Label("All data cleared", systemImage: "checkmark.circle.fill")
                    .typo(.caption, ink: Tint.successText)
            }
            // `GlassButton` with the destructive role, not a bare `Button`: the role
            // is what tints it, and this is the one control in Settings that cannot
            // be undone, so it should not also be the one that looks unstyled.
            GlassButton(
                title: "Reset Utter",
                systemImage: "arrow.counterclockwise",
                role: .destructive
            ) {
                showClearConfirm = true
            }
            Spacer()
        }
        .padding(.top, Space.x1)
        // The version string that used to sit under this button is gone. The same
        // string is pinned to the foot of the settings group list in this very window
        // (`SettingsWindowView.groupList`) and appears again on the About pane, so
        // here it was the app version twice on one screen.
        .alert("Reset Utter?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { clearAllData() }
        } message: {
            Text("""
            This permanently deletes your transcription history, every note (the only \
            copy of what you dictated into Utter), any companion packs you installed, \
            dictionary words, snippets, custom AI commands, and all preferences — \
            including your theme and hotkey choice. This cannot be undone.
            """)
        }
    }

    /// Erase every trace of the user's data.
    ///
    /// The in-memory singletons must be reset *as well as* the files on disk:
    /// they outlive the deletion, and any later `save()` would write the old
    /// values straight back out. Preferences are reset to their defaults rather
    /// than left in a half-cleared state.
    private func clearAllData() {
        TranscriptionHistory.shared.deleteAll()
        // Notes live in their own file, so clearing UserData no longer reaches
        // them — they must be erased explicitly or "clear all data" would leave
        // the user's writing on disk.
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

        // Re-apply the default theme so the UI reflects the reset immediately.
        ThemeManager.shared.setTheme(ThemeManager.systemThemeID)

        // Remove the on-disk store last: the resets above rewrite the files, so
        // deleting first would leave them recreated.
        let fm = FileManager.default
        try? fm.removeItem(at: AppDirectory.support)
        // Every pre-rename folder too, if a failed migration left one behind — "delete everything"
        // has to mean everything, not everything under the current name. The app has been renamed
        // twice, so this is a list; deleting only the newest old name would leave a folder full of
        // transcripts behind while telling the user it was gone.
        for legacy in AppDirectory.legacySupportDirectories {
            try? fm.removeItem(at: legacy)
        }

        cleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { cleared = false }
    }
}
