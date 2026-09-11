import Foundation
import Carbon.HIToolbox

/// Shared persistent store for all user preferences.
class UserData: ObservableObject {
    static let shared = UserData()

    @Published var dictionaryWords: [String] = []
    @Published var snippets: [(trigger: String, expansion: String)] = []
    @Published var selectedLanguage: String = "english"
    @Published var voiceCommandsEnabled: Bool = true
    @Published var spokenPunctuationEnabled: Bool = false // "period"/"comma" → symbols; off by default (words are ambiguous)
    @Published var hotkeyName: String = "Fn"
    /// Double-tap the hotkey (e.g. Fn twice) to start or toggle hands-free dictation.
    @Published var doubleTapHotkeyForHandsFree: Bool = true
    @Published var lastTranscription: String = ""
    @Published var appTheme: String = ThemeManager.systemThemeID
    @Published var customAICommands: [CustomAICommand] = []
    /// Scratchpad contents. Persisted so switching sidebar tabs (which rebuilds
    /// the detail view) doesn't silently discard the user's notes.
    @Published var scratchpad: String = ""

    // MARK: - Authentication & Account State
    @Published var isAuthenticated: Bool = false
    @Published var isGuestMode: Bool = false
    @Published var userEmail: String = ""
    @Published var userDisplayName: String = ""
    @Published var authProvider: String = "" // "Google", "Apple", or "Guest"

    // MARK: - App settings

    /// Show the floating pill at all times, or only while dictating.
    @Published var alwaysShowPill: Bool = true
    /// Show a Dock icon. Utter is a menu-bar app by default (`.accessory`), but
    /// some people want it in the Dock and in Cmd-Tab.
    @Published var showInDock: Bool = false
    /// Play the start/stop/done/error cues.
    @Published var soundsEnabled: Bool = true
    /// Pause other audio while recording, so music doesn't bleed into the mic.
    @Published var muteMusicWhileDictating: Bool = false
    /// What the Scratchpad shows when opened: the previous note, or a blank page.
    /// Whether dictating into Utter appends to the note that's open, or always
    /// starts a fresh one. Replaces `scratchpadResumesLastNote`, which lost its
    /// meaning when the single scratchpad buffer became a list of notes.
    @Published var captureAppendsToOpenNote: Bool = true
    /// Repunctuate dictated text with the on-device language model.
    ///
    /// On by default: Whisper's pause-based punctuation is the single most
    /// commented-on flaw in the raw output, and the pass is bounded and reversible
    /// (it fails open, keeping the original text, if anything looks wrong).
    @Published var sentencePolishEnabled: Bool = true

    /// Bias Whisper toward the custom dictionary at recognition time, instead of
    /// only correcting near-misses afterwards. See `SpeechBias`.
    ///
    /// On by default, but only does anything once the user has added dictionary
    /// words — with an empty dictionary the prompt is empty and inference is
    /// byte-identical to before.
    @Published var speechBiasEnabled: Bool = true

    /// Send a short window of text around the cursor to the model as context.
    ///
    /// Off by default, and deliberately so: unlike every other setting here, this
    /// one reads content the user did not choose to hand over. See
    /// `SurroundingContext` for what is and isn't captured.
    @Published var useSurroundingContext: Bool = false

    /// Adapt tone to the app being dictated into (formal in mail, loose in chat).
    @Published var perAppToneEnabled: Bool = false

    // MARK: - Companion

    /// Show the desktop companion beside the pill.
    ///
    /// Off by default. It is a character that moves next to a text field, which is
    /// exactly the kind of thing that is delightful to the people who want it and an
    /// unwelcome distraction to everyone else — so it is opt-in, like every other
    /// setting here that costs attention.
    @Published var companionEnabled: Bool = false

    /// The selected character: the folder name of a sprite pack, as it appears in
    /// `Companions/` — either one bundled with the app or one the user installed.
    ///
    /// A folder name rather than an enum because packs are discovered on disk, so the
    /// set of valid values is not known at compile time and a stored value can name a
    /// pack that is no longer there. `resolveCompanionCharacter` is the single rule for
    /// that, and everything that reads this goes through it.
    @Published var companionCharacter: String = UserData.defaultCompanionPack

    /// How large the character is drawn. See `CompanionSize` for the ladder and why it
    /// is a ladder.
    ///
    /// The whole companion rig is derived from this — the panel, the roam range, the hop,
    /// and the size every sprite frame is decoded at — so it is read through
    /// `CompanionGeometry` rather than used raw.
    @Published var companionSize: CompanionSize = UserData.defaultCompanionSize

    /// The size on a fresh install, and the fallback for a stored value that names no
    /// size at all. 52pt: what the app drew before this was a choice, so an existing
    /// install is not silently resized by the arrival of the setting.
    static let defaultCompanionSize: CompanionSize = .medium

    // MARK: The pet layer
    //
    // The reactions driven by the user's own hands rather than by dictation: kneading while
    // you type, watching the cursor, purring when stroked, and the timed nudges. All local
    // — a cursor position, a keystroke count, a clock. Nothing here reaches the network.

    /// Whether the character reacts to typing, the cursor and scrolling at all.
    ///
    /// On by default, unlike `companionEnabled`: someone who has deliberately switched a
    /// desktop pet on has opted into a thing that reacts, and a cat that ignores you is a
    /// worse first impression than one that does not exist. Switching it off leaves the
    /// character reacting to dictation only.
    @Published var companionPetBehaviours: Bool = true

    /// What the character calls the user in reminders. Empty means no name is used.
    ///
    /// Never sent anywhere, never used for anything but this string. It exists because
    /// "Stretch time, Sam" reads as a companion and "Stretch time" reads as a notification.
    @Published var companionUserName: String = ""

    /// Minutes between stretch reminders, 0 for off.
    ///
    /// 45 by default: the common ergonomic advice is to move every 30-60 minutes, and 45
    /// lands in the middle without interrupting a focus block twice.
    @Published var companionStretchMinutes: Int = 45

    /// Minutes between water reminders, 0 for off. Off by default — two recurring nudges
    /// out of the box is one more than anyone asked for.
    @Published var companionWaterMinutes: Int = 0

    /// Pomodoro block lengths in minutes, 0 for off. The classic 25/5 when switched on.
    @Published var companionPomodoroFocusMinutes: Int = 0
    @Published var companionPomodoroBreakMinutes: Int = 5

    /// A note pinned above the character's head. Empty means nothing is pinned.
    @Published var companionPinnedMessage: String = ""

    /// Whether the character makes any sound: a meow when you tap it, a purr while you
    /// stroke it, a chirp when a reminder lands.
    ///
    /// Its own switch rather than sharing `soundsEnabled`. The dictation cues fire when you
    /// asked the app to do something; the cat's fire when you touch it or when a timer goes
    /// off, which is a different bargain — so silencing one should not silence the other.
    @Published var companionSounds: Bool = true
    @Published var companionObject: CompanionObject = .none
    @Published var companionMemoryEnabled: Bool = true
    @Published var companionGoalsEnabled: Bool = true
    @Published var companionWindowEdges: Bool = true
    @Published var companionQuietMode: Bool = false
    @Published var companionAutomaticQuietMode: Bool = true
    @Published var companionHydrationGoal: Int = 4
    @Published var companionStretchGoal: Int = 3
    @Published var companionFocusGoal: Int = 2
    @Published var companionDictationGoal: Int = 500
    @Published var companionProgress = CompanionProgress.today()

    /// The character selected on a fresh install. The pixel cat is drawn in code, so it is
    /// available in both app bundles and plain `swift run` development builds.
    ///
    /// A bundled pack rather than "whichever is installed first", so a new user gets a
    /// known character. Only a default, though: resolution still falls back to another
    /// available character if a stored selection no longer exists.
    static let defaultCompanionPack = "pixel-cat-gray"

    /// The prefix this value used to carry when it named a sprite pack rather than one
    /// of the four code-drawn characters that used to ship alongside them.
    ///
    /// Those characters are gone, so every selection is a pack now and the prefix
    /// distinguishes nothing. It survives only to read a `userdata.json` written before
    /// the change: values are stripped on the way in and `save()` writes the bare id,
    /// so a file is migrated the first time it is written.
    static let legacyPackPrefix = "pack:"

    /// The pack id inside a stored selection, with the legacy prefix removed.
    private static func packID(in stored: String) -> String {
        stored.hasPrefix(legacyPackPrefix)
            ? String(stored.dropFirst(legacyPackPrefix.count))
            : stored
    }

    /// Which pack a stored selection resolves to, given the packs actually present.
    ///
    /// Pure, and the only definition of the rule — the renderer, the window's decision
    /// to appear at all, and the correction on first scan all ask this, so none of them
    /// can disagree about which character is selected.
    ///
    /// `nil` means there is no character to show. That is a real state rather than an
    /// error: every character is a sprite pack now, so a build with no bundled packs and
    /// an empty Companions folder has nothing to draw.
    ///
    /// A selection that names nothing installed falls back to `defaultCompanionPack`
    /// first, and only then to whatever is available. Someone upgrading from a version
    /// with the code-drawn characters lands on the same character a fresh install gets,
    /// which is a choice; the alphabetically-first pack is an accident. `available` is
    /// expected in the order the picker lists them, so the last resort is still the
    /// first pack the user would see rather than an arbitrary one.
    static func resolveCompanionCharacter(_ stored: String, available: [String]) -> String? {
        let id = packID(in: stored)
        if available.contains(id) { return id }
        if available.contains(defaultCompanionPack) { return defaultCompanionPack }
        return available.first
    }

    /// Correct `companionCharacter` to a pack that exists, and persist the correction.
    ///
    /// Called once the pack folders have been scanned, which is the earliest anything
    /// knows what is installed — `load()` runs from `init()`, long before that. Writing
    /// the corrected value back is what stops an upgraded install (one still naming a
    /// code-drawn character) resolving the same dead selection on every launch.
    ///
    /// Returns the resolved id, or nil when no pack is installed. In that case the
    /// stored value is deliberately left alone: a missing Companions folder is usually
    /// temporary, and overwriting the user's choice with nothing would lose it.
    @discardableResult
    func resolveCompanionCharacter(against available: [String]) -> String? {
        let resolved = Self.resolveCompanionCharacter(companionCharacter, available: available)
        // Only assign on a real change. This runs from the same preference-observer
        // path that `save()` feeds, and publishing an identical value would schedule
        // another pass through it for nothing.
        guard let resolved, resolved != companionCharacter else { return resolved }
        companionCharacter = resolved
        save()
        return resolved
    }

    /// Show a rough live transcript in the pill while speaking.
    ///
    /// Off by default. It runs extra inference passes over partial audio, which
    /// costs battery and CPU for a preview the user may not want — and on a busy
    /// machine the preview competes with the transcription that actually matters.
    /// Opt-in is the honest default for a feature that trades power for reassurance.
    @Published var livePreviewEnabled: Bool = false

    /// Offer to transcribe when Utter notices you are in a call.
    ///
    /// Off by default, and that is not timidity. The offer needs Screen Recording to be useful, it
    /// concerns recording other people, and a panel that appears on its own is the most intrusive
    /// thing this app does — so it is something the user turns on, not something they discover
    /// happening. Detection itself (`CallDetector`) only runs while this is true, so with it off the
    /// app is not watching the audio devices at all.
    @Published var offerToTranscribeCalls: Bool = false

    /// Keep a searchable on-disk log of everything dictated (`history.json`).
    ///
    /// On by default so an existing install is not silently changed — history has
    /// always been recorded, and flipping the stored default to `false` would look
    /// like the app had lost the user's log. This is the one switch that turns the
    /// recording off: with it off, `deliverTranscript` and the AI-command path skip
    /// `TranscriptionHistory.add`, so nothing new is written. Entries already on
    /// disk stay until the user clears them — this stops new writes, it is not a wipe.
    @Published var keepHistory: Bool = true

    /// The bundled model is `small.en` — English only. Offering other languages
    /// produced confidently wrong romanized text rather than an error, so the
    /// list reflects what the model actually supports. A multilingual build would
    /// need `ggml-small.bin` (~470 MB) instead of the 181 MB English model.
    static let supportedLanguages: [(code: String, name: String)] = [
        ("english", "English"),
    ]

    /// Voice commands that map spoken phrases to keyboard actions
    static let voiceCommands: [(phrase: String, description: String, action: VoiceAction)] = [
        ("delete that", "Delete last transcription", .undo),
        ("undo that", "Undo last action", .undo),
        ("select all", "Select all text", .selectAll),
        ("new line", "Insert new line", .newLine),
        ("new paragraph", "Insert double new line", .newParagraph),
        ("go to end", "Move cursor to end", .goToEnd),
        ("copy that", "Copy selection", .copy),
        ("paste that", "Paste clipboard", .paste),
        // Note routing. These change *where the next dictation goes*, so they are
        // useful hands-free: you can start a note without reaching for ⌃⌥N, and a
        // long thought can be broken into separate notes by voice alone.
        ("start a new note", "Dictate into a fresh note", .startNewNote),
        ("start new note", "Dictate into a fresh note", .startNewNote),
        ("new note", "Dictate into a fresh note", .startNewNote),
        ("continue the note", "Add to the note already open", .continueNote),
        ("continue note", "Add to the note already open", .continueNote),
    ]

    private let storageDir: URL

    init(storageDir: URL = AppDirectory.support) {
        self.storageDir = storageDir
        load()
    }

    func applySnippets(to text: String) -> String {
        var result = text
        for snippet in snippets {
            // Resolve dynamic placeholders ([date], [time], [clipboard], …) at expansion time
            // so values are always current. Snippets without placeholders are unaffected.
            let expansion = SnippetTemplates.expand(snippet.expansion)
            result = result.replacingOccurrences(of: snippet.trigger, with: expansion, options: .caseInsensitive)
        }
        return result
    }

    /// Check if text is a voice command. Returns the action if matched, nil otherwise.
    func checkVoiceCommand(_ text: String) -> VoiceAction? {
        guard voiceCommandsEnabled else { return nil }
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trailing punctuation for matching
        let cleaned = lower.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
        for cmd in Self.voiceCommands {
            if cleaned == cmd.phrase || cleaned.hasSuffix(cmd.phrase) {
                return cmd.action
            }
        }
        return nil
    }

    // MARK: - Authentication Actions

    func signInWithGoogle(name: String = "Alex Rivers", email: String = "alex.rivers@gmail.com") {
        isAuthenticated = true
        isGuestMode = false
        userDisplayName = name
        userEmail = email
        authProvider = "Google"
        save()
    }

    func signInAsGuest() {
        isAuthenticated = false
        isGuestMode = true
        userDisplayName = "Guest"
        userEmail = ""
        authProvider = "Guest"
        save()
    }

    func signOut() {
        isAuthenticated = false
        isGuestMode = false
        userDisplayName = ""
        userEmail = ""
        authProvider = ""
        save()
    }

    func save() {
        let snipData = snippets.map { ["trigger": $0.trigger, "expansion": $0.expansion] }
        let customCmdData = (try? JSONEncoder().encode(customAICommands))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
        let data: [String: Any] = [
            "isAuthenticated": isAuthenticated,
            "isGuestMode": isGuestMode,
            "userEmail": userEmail,
            "userDisplayName": userDisplayName,
            "authProvider": authProvider,
            "words": dictionaryWords,
            "snippets": snipData,
            "language": selectedLanguage,
            "voiceCommands": voiceCommandsEnabled,
            "spokenPunctuation": spokenPunctuationEnabled,
            "hotkeyName": hotkeyName,
            "doubleTapHotkeyForHandsFree": doubleTapHotkeyForHandsFree,
            "appTheme": appTheme,
            "scratchpad": scratchpad,
            "customAICommands": customCmdData,
            "alwaysShowPill": alwaysShowPill,
            "showInDock": showInDock,
            "soundsEnabled": soundsEnabled,
            "muteMusicWhileDictating": muteMusicWhileDictating,
            "captureAppendsToOpenNote": captureAppendsToOpenNote,
            "sentencePolishEnabled": sentencePolishEnabled,
            "speechBiasEnabled": speechBiasEnabled,
            "useSurroundingContext": useSurroundingContext,
            "perAppToneEnabled": perAppToneEnabled,
            "livePreviewEnabled": livePreviewEnabled,
            "offerToTranscribeCalls": offerToTranscribeCalls,
            "keepHistory": keepHistory,
            "companionEnabled": companionEnabled,
            "companionCharacter": companionCharacter,
            "companionSize": companionSize.rawValue,
            "companionPetBehaviours": companionPetBehaviours,
            "companionUserName": companionUserName,
            "companionStretchMinutes": companionStretchMinutes,
            "companionWaterMinutes": companionWaterMinutes,
            "companionPomodoroFocusMinutes": companionPomodoroFocusMinutes,
            "companionPomodoroBreakMinutes": companionPomodoroBreakMinutes,
            "companionPinnedMessage": companionPinnedMessage,
            "companionSounds": companionSounds,
            "companionObject": companionObject.rawValue,
            "companionMemoryEnabled": companionMemoryEnabled,
            "companionGoalsEnabled": companionGoalsEnabled,
            "companionWindowEdges": companionWindowEdges,
            "companionQuietMode": companionQuietMode,
            "companionAutomaticQuietMode": companionAutomaticQuietMode,
            "companionHydrationGoal": companionHydrationGoal,
            "companionStretchGoal": companionStretchGoal,
            "companionFocusGoal": companionFocusGoal,
            "companionDictationGoal": companionDictationGoal,
            "companionProgress": companionProgress.jsonObject,
        ]
        let url = storageDir.appendingPathComponent("userdata.json")
        if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
            do { try json.write(to: url, options: .atomic) }
            catch { print("⚠️ Could not write settings: \(error.localizedDescription)") }
        }
    }

    private func load() {
        let url = storageDir.appendingPathComponent("userdata.json")
        guard let data = try? Data(contentsOf: url) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let salvage = storageDir.appendingPathComponent(
                "userdata-unreadable-\(Int(Date().timeIntervalSince1970)).json"
            )
            do {
                try FileManager.default.moveItem(at: url, to: salvage)
                print("⚠️ Settings file unreadable; moved aside to \(salvage.lastPathComponent)")
            } catch {
                print("⚠️ Settings file unreadable and could not be moved aside: "
                      + error.localizedDescription)
            }
            return
        }

        if let v = json["isAuthenticated"] as? Bool { isAuthenticated = v }
        if let v = json["isGuestMode"] as? Bool { isGuestMode = v }
        if let v = json["userEmail"] as? String { userEmail = v }
        if let v = json["userDisplayName"] as? String { userDisplayName = v }
        if let v = json["authProvider"] as? String { authProvider = v }

        if let words = json["words"] as? [String] { dictionaryWords = words }
        if let snips = json["snippets"] as? [[String: String]] {
            snippets = snips.compactMap { dict in
                guard let t = dict["trigger"], let e = dict["expansion"] else { return nil }
                return (trigger: t, expansion: e)
            }
        }
        if let lang = json["language"] as? String { selectedLanguage = lang }
        if let vc = json["voiceCommands"] as? Bool { voiceCommandsEnabled = vc }
        if let sp = json["spokenPunctuation"] as? Bool { spokenPunctuationEnabled = sp }
        if let hn = json["hotkeyName"] as? String { hotkeyName = hn }
        if let dth = json["doubleTapHotkeyForHandsFree"] as? Bool { doubleTapHotkeyForHandsFree = dth }
        if let theme = json["appTheme"] as? String {
            appTheme = (theme == "ember") ? ThemeManager.systemThemeID : theme
        }
        if let pad = json["scratchpad"] as? String { scratchpad = pad }
        if let v = json["alwaysShowPill"] as? Bool { alwaysShowPill = v }
        if let v = json["showInDock"] as? Bool { showInDock = v }
        if let v = json["soundsEnabled"] as? Bool { soundsEnabled = v }
        if let v = json["muteMusicWhileDictating"] as? Bool { muteMusicWhileDictating = v }
        // Read the old key as a fallback so an existing install keeps a sensible
        // value rather than silently resetting to the default.
        if let v = json["captureAppendsToOpenNote"] as? Bool { captureAppendsToOpenNote = v }
        else if let v = json["scratchpadResumesLastNote"] as? Bool { captureAppendsToOpenNote = v }
        if let v = json["sentencePolishEnabled"] as? Bool { sentencePolishEnabled = v }
        if let v = json["speechBiasEnabled"] as? Bool { speechBiasEnabled = v }
        if let v = json["useSurroundingContext"] as? Bool { useSurroundingContext = v }
        if let v = json["perAppToneEnabled"] as? Bool { perAppToneEnabled = v }
        if let v = json["livePreviewEnabled"] as? Bool { livePreviewEnabled = v }
        if let v = json["offerToTranscribeCalls"] as? Bool { offerToTranscribeCalls = v }
        // Absent in a file written before this setting existed → stays `true`, so an
        // upgrade keeps recording history exactly as it did before the switch arrived.
        if let v = json["keepHistory"] as? Bool { keepHistory = v }
        if let v = json["companionEnabled"] as? Bool { companionEnabled = v }
        // Strip the legacy `pack:` prefix here so nothing downstream has to know the
        // old format existed. The name may still be a pack that is no longer installed
        // — including one of the code-drawn characters — which cannot be checked yet:
        // no pack folder has been scanned at this point. See
        // `resolveCompanionCharacter(against:)`.
        if let v = json["companionCharacter"] as? String, !v.isEmpty {
            companionCharacter = Self.packID(in: v)
        }
        // An unknown name falls back to the default rather than being coerced to the
        // nearest step: the value is a name, not a number, so a file written by a future
        // version (or edited by hand) has no "nearest" — and a companion that silently
        // came back at 52pt is a better answer than one at an unbudgeted size, because
        // every clamp and the frame-decode cap are derived from it.
        if let v = json["companionSize"] as? String {
            companionSize = CompanionSize(rawValue: v) ?? Self.defaultCompanionSize
        }
        if let v = json["companionPetBehaviours"] as? Bool { companionPetBehaviours = v }
        if let v = json["companionUserName"] as? String { companionUserName = v }
        // Intervals are clamped rather than rejected: they are minutes typed into a field,
        // so a nonsense value should still leave a working companion. 0 means off, and the
        // 8-hour ceiling exists because a "reminder" longer than a working day is a value
        // someone fat-fingered, not a preference.
        if let v = json["companionStretchMinutes"] as? Int {
            companionStretchMinutes = min(480, max(0, v))
        }
        if let v = json["companionWaterMinutes"] as? Int {
            companionWaterMinutes = min(480, max(0, v))
        }
        if let v = json["companionPomodoroFocusMinutes"] as? Int {
            companionPomodoroFocusMinutes = min(480, max(0, v))
        }
        if let v = json["companionPomodoroBreakMinutes"] as? Int {
            companionPomodoroBreakMinutes = min(480, max(0, v))
        }
        if let v = json["companionPinnedMessage"] as? String { companionPinnedMessage = v }
        if let v = json["companionSounds"] as? Bool { companionSounds = v }
        if let v = json["companionObject"] as? String {
            companionObject = CompanionObject(rawValue: v) ?? .none
        }
        if let v = json["companionMemoryEnabled"] as? Bool { companionMemoryEnabled = v }
        if let v = json["companionGoalsEnabled"] as? Bool { companionGoalsEnabled = v }
        if let v = json["companionWindowEdges"] as? Bool { companionWindowEdges = v }
        if let v = json["companionQuietMode"] as? Bool { companionQuietMode = v }
        if let v = json["companionAutomaticQuietMode"] as? Bool {
            companionAutomaticQuietMode = v
        }
        if let v = json["companionHydrationGoal"] as? Int {
            companionHydrationGoal = min(20, max(0, v))
        }
        if let v = json["companionStretchGoal"] as? Int {
            companionStretchGoal = min(20, max(0, v))
        }
        if let v = json["companionFocusGoal"] as? Int {
            companionFocusGoal = min(20, max(0, v))
        }
        if let v = json["companionDictationGoal"] as? Int {
            companionDictationGoal = min(10_000, max(0, v))
        }
        if let v = json["companionProgress"] as? [String: Any] {
            companionProgress = CompanionProgress(jsonObject: v)
        }
        if let cmds = json["customAICommands"] as? [[String: Any]],
           let raw = try? JSONSerialization.data(withJSONObject: cmds),
           let decoded = try? JSONDecoder().decode([CustomAICommand].self, from: raw) {
            customAICommands = decoded
        }
    }

    @discardableResult
    func recordCompanionDictation(words: Int, at date: Date = Date()) -> String? {
        guard words > 0 else { return nil }
        var progress = companionProgress(for: date)
        progress.dictationWords += words
        progress.lifetimeWords += words
        progress.dictations += 1
        grantCompanionRewards(in: &progress)
        companionProgress = progress
        save()
        guard companionGoalsEnabled, companionDictationGoal > 0,
              progress.dictationWords - words < companionDictationGoal,
              progress.dictationWords >= companionDictationGoal
        else { return nil }
        return "Dictation goal complete"
    }

    @discardableResult
    func recordCompanionReminder(
        _ reminder: CompanionReminder,
        completed: Bool,
        at date: Date = Date()
    ) -> String? {
        var progress = companionProgress(for: date)
        let key = reminder.memoryKey
        if companionMemoryEnabled {
            if completed {
                progress.preferredHours[key] = Calendar.current.component(.hour, from: date)
            } else {
                progress.dismissed[key, default: 0] += 1
                progress.extraDelayMinutes[key] =
                    min(30, progress.extraDelayMinutes[key, default: 0] + 5)
            }
        }

        var celebration: String?
        if completed, companionGoalsEnabled {
            switch reminder {
            case .water:
                progress.hydration += 1
                if companionHydrationGoal > 0,
                   progress.hydration == companionHydrationGoal {
                    celebration = "Hydration goal complete"
                }
            case .stretch:
                progress.stretches += 1
                if companionStretchGoal > 0,
                   progress.stretches == companionStretchGoal {
                    celebration = "Stretch goal complete"
                }
            case .pomodoro(let focus) where focus:
                progress.focusBlocks += 1
                if companionFocusGoal > 0,
                   progress.focusBlocks == companionFocusGoal {
                    celebration = "Focus goal complete"
                }
            case .pomodoro, .message:
                break
            }
        }
        companionProgress = progress
        save()
        return celebration
    }

    func forgetCompanionMemory() {
        var progress = companionProgress
        progress.dismissed = [:]
        progress.preferredHours = [:]
        progress.extraDelayMinutes = [:]
        companionProgress = progress
        save()
    }

    func recordCompanionMemoryCreated() {
        var progress = companionProgress
        progress.memoriesCreated += 1
        companionProgress = progress
        save()
    }

    func recordCompanionMemoryCompleted() {
        var progress = companionProgress
        progress.memoriesCompleted += 1
        companionProgress = progress
        save()
    }

    @discardableResult
    func syncCompanionLifetimeWords(_ totalWords: Int) -> [CompanionReward] {
        var progress = companionProgress
        progress.lifetimeWords = max(progress.lifetimeWords, max(0, totalWords))
        let before = progress.unlocked
        grantCompanionRewards(in: &progress)
        guard progress != companionProgress else { return [] }
        companionProgress = progress
        save()
        return CompanionReward.allCases.filter {
            progress.unlocked.contains($0.rawValue) && !before.contains($0.rawValue)
        }
    }

    func companionRewardUnlocked(_ reward: CompanionReward) -> Bool {
        companionProgress.unlocked.contains(reward.rawValue)
    }

    func companionObjectUnlocked(_ object: CompanionObject) -> Bool {
        object.reward.map(companionRewardUnlocked) ?? true
    }

    func companionAnimationUnlocked(_ unlock: CompanionUnlock) -> Bool {
        companionRewardUnlocked(unlock.reward)
    }

    func companionExtraDelay(for reminder: CompanionReminder) -> Int {
        guard companionMemoryEnabled else { return 0 }
        return companionProgress.extraDelayMinutes[reminder.memoryKey, default: 0]
    }

    private func companionProgress(for date: Date) -> CompanionProgress {
        var progress = companionProgress
        let stamp = CompanionProgress.dayStamp(date)
        guard progress.day != stamp else { return progress }
        progress.day = stamp
        progress.hydration = 0
        progress.stretches = 0
        progress.focusBlocks = 0
        progress.dictationWords = 0
        return progress
    }

    private func grantCompanionRewards(in progress: inout CompanionProgress) {
        for reward in CompanionReward.allCases
        where progress.lifetimeWords >= reward.wordRequirement {
            progress.unlocked.insert(reward.rawValue)
        }
    }
}

enum CompanionUnlock: String, CaseIterable {
    case grooming, rolling, loaf

    var label: String {
        switch self {
        case .grooming: return "Grooming"
        case .rolling: return "Roll over"
        case .loaf: return "Cozy loaf"
        }
    }

    var requirement: String {
        "\(reward.wordRequirement.formatted()) dictated words"
    }

    var reward: CompanionReward {
        switch self {
        case .grooming: return .grooming
        case .rolling: return .rolling
        case .loaf: return .loaf
        }
    }
}

struct CompanionProgress: Equatable {
    var day: Int
    var hydration = 0
    var stretches = 0
    var focusBlocks = 0
    var dictationWords = 0
    var dismissed: [String: Int] = [:]
    var preferredHours: [String: Int] = [:]
    var extraDelayMinutes: [String: Int] = [:]
    var unlocked: Set<String> = []
    var lifetimeWords = 0
    var dictations = 0
    var memoriesCreated = 0
    var memoriesCompleted = 0

    static func today() -> CompanionProgress {
        CompanionProgress(day: dayStamp(Date()))
    }

    static func dayStamp(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    init(day: Int) {
        self.day = day
    }

    init(jsonObject json: [String: Any]) {
        day = json["day"] as? Int ?? Self.dayStamp(Date())
        hydration = json["hydration"] as? Int ?? 0
        stretches = json["stretches"] as? Int ?? 0
        focusBlocks = json["focusBlocks"] as? Int ?? 0
        dictationWords = json["dictationWords"] as? Int ?? 0
        dismissed = Self.intDictionary(json["dismissed"])
        preferredHours = Self.intDictionary(json["preferredHours"])
        extraDelayMinutes = Self.intDictionary(json["extraDelayMinutes"])
        unlocked = Set(json["unlocked"] as? [String] ?? [])
        lifetimeWords = json["lifetimeWords"] as? Int ?? 0
        dictations = json["dictations"] as? Int ?? 0
        memoriesCreated = json["memoriesCreated"] as? Int ?? 0
        memoriesCompleted = json["memoriesCompleted"] as? Int ?? 0
    }

    var jsonObject: [String: Any] {
        [
            "day": day,
            "hydration": hydration,
            "stretches": stretches,
            "focusBlocks": focusBlocks,
            "dictationWords": dictationWords,
            "dismissed": dismissed,
            "preferredHours": preferredHours,
            "extraDelayMinutes": extraDelayMinutes,
            "unlocked": unlocked.sorted(),
            "lifetimeWords": lifetimeWords,
            "dictations": dictations,
            "memoriesCreated": memoriesCreated,
            "memoriesCompleted": memoriesCompleted,
        ]
    }

    private static func intDictionary(_ value: Any?) -> [String: Int] {
        guard let raw = value as? [String: Any] else { return [:] }
        return raw.compactMapValues { ($0 as? NSNumber)?.intValue }
    }
}

enum VoiceAction {
    /// Route the next dictation into a brand-new note.
    case startNewNote
    /// Route the next dictation into whichever note is already open.
    case continueNote
    case undo
    case selectAll
    case newLine
    case newParagraph
    case goToEnd
    case copy
    case paste

    /// Whether this command changes where dictation goes rather than editing text.
    ///
    /// The two are honoured in different circumstances: routing works everywhere,
    /// while the editing commands are keystrokes aimed at the frontmost app's text
    /// field and are meaningless — actively harmful — when the dictation is being
    /// filed into a Utter note instead. See the voice-command branch in
    /// `stopRecording`.
    var isNoteRouting: Bool {
        switch self {
        case .startNewNote, .continueNote: return true
        case .undo, .selectAll, .newLine, .newParagraph, .goToEnd, .copy, .paste: return false
        }
    }
}
