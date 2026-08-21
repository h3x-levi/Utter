import SwiftUI

// MARK: - Privacy content pieces
//
// `struct PrivacyView` used to live here: a full Privacy screen with five
// `PolicyCard`s and the app's only Reset Utter button. It had **no callers**.
// `SettingsGroup.privacy` routes to `PrivacySettingsContent`
// (`SettingsWindowView.detail`), so every one of those cards
// was unreachable — and, worse than dead prose, `clearAllData()` was unreachable
// too. The user could not reset the app, while the copy in this file told them a
// button below would do it.
//
// So the view is gone and its contents are not: `PrivacySettingsContent` composes
// `PolicyCard` and `DataResetSection` from here, one card per row to suit the
// settings detail column. Deleting the file outright would have deleted the reset
// itself, which is the opposite of the fix.
//
// The `BentoRow(columns: 2)` pairing the old view used went with it. That was a
// deliberate arrangement for the main window's ~840pt content card; the settings
// detail column is roughly half of it.

/// A group of plain statements about what the app does with the user's data.
///
/// Bullet glyphs are `Image(systemName:)` at a raw point size on purpose — a symbol's
/// size is a glyph metric rather than a step on the type scale, which is how
/// `BentoTile` and `EmptyStateView` in `DesignSystem/` size theirs. `Ink.tertiary` is
/// correct for it under `Ink.tertiary`'s own rule: decorative glyphs, never text the
/// user must read. The statements themselves are `.callout`.
struct PolicyCard: View {
    let icon: String
    let title: String
    let items: [String]

    var body: some View {
        BentoTile(title: title, systemImage: icon) {
            VStack(alignment: .leading, spacing: Space.x2) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: Space.x2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Ink.tertiary)
                            // The tick is a bullet. Reading "checkmark" before every
                            // one of eighteen statements is worse than reading none.
                            .accessibilityHidden(true)
                        Text(item)
                            .typo(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

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
