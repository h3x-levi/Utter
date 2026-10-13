import SwiftUI
import UtterCore

/// The release notes as a reading list: newest first, one column, user-facing changes only.
struct WhatsNewView: View {
    struct Release: Identifiable {
        let version: String
        let date: String
        let highlights: [String]

        var id: String { version }
    }

    var appVersion = ConfigManager.shared.appVersion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                (Text("You\u{2019}re running Utter ") + Text(verbatim: appVersion).font(.callout.monospaced()))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LazyVStack(alignment: .leading, spacing: 32) {
                    ForEach(Self.releases) { release in
                        ReleaseNotes(release: release)
                    }
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .tint(Look.Color.tint)
    }

    static let releases: [Release] = [
        Release(version: "1.1.57", date: "September 2026", highlights: [
            "Double-tap the hotkey (Fn) to start hands-free dictation without holding it",
        ]),
        Release(version: "3.0.40", date: "August 2026", highlights: [
            "Companion is now organized into native Today, Remember, Rewards, and Customize tabs.",
            "Type or speak private memories and reminders; review them before saving, edit them later, or erase them all.",
            "Dictation milestones now unlock companion objects, animations, and original cat sounds without purchases or expiring rewards.",
            "Pill symbols remain visible on light or dark backgrounds, and the processing pencil now draws a continuous handwriting stroke.",
            "Memory files recover their previous saved generation after corruption and roll back cleanly when a disk write fails.",
        ]),
        Release(version: "3.0.39", date: "August 2026", highlights: [
            "Companion now uses the full settings width instead of a narrow centered form.",
            "Both pixel cats have longer bodies plus new grooming, rolling, and loaf animations.",
            "The cat can play with its ball, box, yarn, and cushion by itself, and reacts to double-clicking, tossing, feeding, and brushing.",
            "Local relationship memory, daily goals, earned animations, window-edge avoidance, and automatic quiet behavior are now available.",
        ]),
        Release(version: "3.0.38", date: "August 2026", highlights: [
            "Fixed the standard Settings command and Command-, opening an empty window instead of Utter Settings.",
            "Settings sections now open at the top instead of inheriting another section’s scroll position.",
            "Fixed Home activity labels and values collapsing into a centered cluster on wide windows.",
            "Settings are now written atomically, failures are reported, and an unreadable settings file is preserved for recovery instead of being overwritten.",
        ]),
        Release(version: "3.0.37", date: "August 2026", highlights: [
            "Expanded local automatic call detection beyond Zoom and Teams to Webex, Skype, WhatsApp, Signal, Telegram, Viber, RingCentral, GoTo, Jitsi Meet, LINE, WeChat, and KakaoTalk.",
        ]),
        Release(version: "3.0.36", date: "August 2026", highlights: [
            "The resting pill’s microphone is now solid black in light themes and solid white in dark themes.",
        ]),
        Release(version: "3.0.35", date: "August 2026", highlights: [
            "Fixed automatic meeting offers appearing for browser playback such as YouTube.",
            "Automatic offers now require an active call in Zoom, Microsoft Teams, FaceTime, Slack, or Discord. Browser meetings can still be started manually from Notes.",
        ]),
        Release(version: "3.0.32", date: "August 2026", highlights: [
            "The companion is now a pixel cat. The two Mochi packs and the two code-drawn Persian cats were removed; the bundled characters are Golden Dog, Panda, Pixel Cat (Ginger) and Pixel Cat (Gray).",
            "An existing selection naming a removed character is migrated to the default pack on first launch and the correction saved, so nobody lands on an empty companion window.",
            "Fixed: a pixel-art pack whose canvas is larger than the chosen character size was drawn at full canvas size, overflowing the panel that clips it, so the cat was sliced at the window edge while roaming. Only reproduced on a non-Retina display.",
        ]),
        Release(version: "3.0.15", date: "August 2026", highlights: [
            "The pill stays visible over any background - its outline no longer matches what is behind it",
        ]),
        Release(version: "3.0.14", date: "August 2026", highlights: [
            "The pencil shows again while transcribing - it was being drawn past the edge of its own frame",
        ]),
        Release(version: "3.0.13", date: "August 2026", highlights: [
            "No more faint empty shape before the pill fills in when you press the hotkey",
            "The pill no longer stretches open - it is the right width on its first frame",
            "Removed the phase text from the pill; the pencil is back on its own",
        ]),
        Release(version: "3.0.12", date: "August 2026", highlights: [
            "The note card's rows arrive top-down, and its transcript is finally full-strength instead of footnote grey",
            "The pill shows which phase it is in - Transcribing, Rewriting, Typing",
            "The pencil no longer jumps back and erases its own line every 1.4 seconds",
            "The level meter shows half a second of history instead of a sixth, so it scrolls instead of flickering",
        ]),
        Release(version: "3.0.11", date: "August 2026", highlights: [
            "The pill's colour now crosses smoothly into each state instead of cutting - the snap you saw on every dictation",
            "The settle animation added two releases ago was never actually running; it does now",
            "Clicking the hands-free button no longer strands it on screen and kill the long-press",
            "A long error message can no longer draw the pill wider than its own window",
        ]),
        Release(version: "3.0.10", date: "August 2026", highlights: [
            "The hands-free button no longer retracts while you reach for it",
            "The button's outline and ring now emerge together on one curve instead of two",
        ]),
        Release(version: "3.0.9", date: "August 2026", highlights: [
            "The pill animates again - it lands at its new size and springs into place, and the note card fills after the shape arrives",
        ]),
        Release(version: "3.0.8", date: "August 2026", highlights: [
            "The hotkey reacts immediately - every press used to freeze the app for 80ms before the pill could draw",
            "The pale full-size panel behind the pill is gone, and the old glyphs no longer dissolve on top of the note card",
        ]),
        Release(version: "3.0.7", date: "August 2026", highlights: [
            "The pill grows into the note card without the ghosting that got the animation removed before - the glass now keeps one fixed set of bounds and only its outline animates",
        ]),
        Release(version: "3.0.6", date: "August 2026", highlights: [
            "The morph animation is switched back on",
            "Faster: the speech model is released when idle instead of holding 869 MB, two thirds of it in swap",
            "The live preview reads the last ten seconds instead of re-transcribing everything every 0.7s",
            "Sounds and call detection no longer stall the main thread",
        ]),
        Release(version: "3.0.5", date: "August 2026", highlights: [
            "Fixed a crash that could interrupt a meeting recording after about a minute",
        ]),
        Release(version: "2.0.87", date: "August 2026", highlights: [
            "The note card now grows out of the pill when it opens, matching the way it shrinks back when it closes - the card used to be drawn at full size on the first frame, hiding the animation behind it",
            "The hands-free button is Liquid Glass like the pill, with the same tint and edge, and morphs out of the pill’s edge instead of appearing beside it",
        ]),
        Release(version: "2.0.86", date: "August 2026", highlights: [
            "The hands-free button now pops out beside the pill as its own circular button instead of sitting inside it - the microphone stays centred and the pill never changes size or shifts",
            "Hovering anywhere on the pill reveals it, and it stays put while you move onto it to click",
            "The pill grows smoothly into the note card and shrinks back again, without the crash that animation caused in 2.0.84",
        ]),
        Release(version: "2.0.85", date: "August 2026", highlights: [
            "Fixed the crash when starting a note - the smooth pill-to-card animation added in 2.0.84 invalidated the window’s layout mid-display-cycle and AppKit killed the app",
            "The resting pill is a centred microphone again; the hands-free button appears beside it on hover, as it did before 2.0.84",
        ]),
        Release(version: "2.0.84", date: "August 2026", highlights: [
            "The pill now grows smoothly into the note card and shrinks back into the pill, instead of the card appearing all at once",
            "The pill is fixed in place - it cannot be dragged, and it no longer shifts sideways when the hands-free button appears",
            "Hovering anywhere on the pill reveals the hands-free button; the companion’s window no longer covers the pill’s left half",
            "The stop button stays visible for the whole hands-free recording instead of hiding until you hover",
            "The companion’s window is now sized to the character instead of being twice as large, so it stops swallowing clicks near the pill",
        ]),
        Release(version: "2.0.83", date: "August 2026", highlights: [
            "The companion now rides inside the note card while you dictate a note, instead of standing beside the pill where it could overlap",
            "Drag the pill anywhere and it stays - it no longer snaps or jumps after you let go",
            "The whole pill is hoverable now: the record button appears wherever you point, not only near one end",
            "No more dead zone - a click beside the pill or the companion passes through to whatever is behind, instead of being swallowed; only the pill and the character take clicks",
            "A stop button appears on the pill while hands-free is recording, so a click can stop it",
            "Fixed: the pill was briefly unclickable for a moment right after a note card closed",
            "New “Keep dictation history” setting - turn it off to stop Utter logging what you dictate",
            "Dictated text no longer appears in internal debug logs",
            "The privacy page now states the facts accurately: one optional model download, and Screen Recording used only for meetings",
            "Reset now names your notes and installed characters before it deletes them",
            "Removing a downloaded speech model no longer edits the app itself, which could quietly reset your permissions",
            "Utter now declares its minimum macOS version, so an unsupported system gets a clear message instead of failing silently",
        ]),
        Release(version: "2.0.80", date: "August 2026", highlights: [
            "The companion is larger and easier to read - 52pt instead of 28, so its face and mood register at a glance",
            "Each character is sized on its own: a tall slim figure reads smaller than a round one at the same height, so it is drawn a little larger",
            "Characters redrawn from individual poses: consistent size between moods, nothing cropped",
            "The companion sits on the pill’s line in every mood - the sleeping pose used to hang 8pt below it",
            "The companion is its own window now: drag it anywhere, independently of the pill, and it stays where you put it",
            "Four companion sizes to choose from, in the companion settings",
            "The Dog is now a golden retriever puppy, drawn pose by pose",
            "Every character now animates at the speed it was drawn for - sleepy was playing 60% too fast, celebrating 33% too slow",
            "Characters no longer float over the menu bar when the pill sits at the top of the screen",
            "The four code-drawn characters have been retired; the animated packs are the companions now",
            "Dictating into a note no longer types into whatever app is in front, and the pill shows when a note is the destination",
            "Say \"start a new note\" and the next thing you say goes into it - this never worked before",
            "Starting a meeting now tells you when the microphone could not be opened instead of recording only the other side",
            "A meeting window that fails to transcribe is retried rather than lost",
            "The window remembers its size and position again after being closed once",
            "Onboarding scrolls instead of pushing its buttons off the bottom at larger text sizes",
            "The installer window shows its background again instead of opening plain white",
            "Settings follows the theme the moment you change it, instead of when you next reopen it",
            "Settings and the setup window can be resized, and Settings remembers the size you chose",
            "The Hotkey settings card now explains hands-free and note dictation, and the voice commands that route into a note",
            "Hands-free without a chord - while you are dictating, keep the hotkey held and tap Space; the recording carries on after you let go, and the tapped key never reaches the app you are typing into",
            "Hover the pill and a record button appears; click it to start hands-free, no keyboard needed",
            "Setup resumes where you left it: granting Screen Recording makes macOS relaunch Utter, which used to send you back to the welcome screen",
            "\u{201C}Show in Dock\u{201D} off now really means no Dock icon - opening a window no longer adds one until you close it again",
            "No Dock icon flashes at launch any more",
            "The countdown line along the foot of the pill is gone; hands-free still stops on its own when you stop talking",
        ]),
        Release(version: "2.0.72", date: "August 2026", highlights: [
            "Panda and Dog companions now ship with the app - no setup, available on a fresh install",
            "Companion art is no longer cropped: full body, including hair, tails and legs",
            "Your own character packs still work, and override a shipped one of the same name",
        ]),
        Release(version: "2.0.68", date: "August 2026", highlights: [
            "Permissions now survive replacing the app - Utter is signed with a real developer certificate, so macOS keeps your Accessibility, Microphone and Screen Recording grants across updates",
            "Granting Accessibility takes effect immediately instead of needing a relaunch",
            "Fixed a crash risk in the microphone path when a recording stopped mid-buffer",
            "Quitting during transcription no longer hangs",
            "A meeting that produced no audio from others now says why instead of failing silently",
            "The companion is fully released when switched off",
        ]),
        Release(version: "2.0.66", date: "August 2026", highlights: [
            "Companion sits fully in view beside the pill and never overlaps it",
            "Companion moved into the main window, and offered once during setup",
            "Say \u{201C}start a new note\u{201D} or \u{201C}continue the note\u{201D} to route dictation by voice",
            "The note hotkey (\u{2303}\u{2325}N) is now shown where you would look for it",
            "Screen Recording for meetings is asked for during setup and listed with the other permissions",
            "Dictation history scrolls smoothly with a trackpad, however long it gets",
        ]),
        Release(version: "2.0.65", date: "August 2026", highlights: [
            "Notes - dictate straight into Utter with ⌃⌥N instead of into the app in front; notes are searchable, exportable to Markdown, and no longer a single overwritten buffer",
            "Meeting capture - records both sides of a call and files it as a transcript, labelled You and Others, transcribed on this Mac in rolling windows",
            "AI note actions - summarise, extract action items, clean up dictation, format as a document, or suggest a title, all on-device",
            "Desktop companion - an animated character beside the pill, with built-in designs or your own APNG sprite packs",
            "Onboarding now shows the pill working instead of describing it",
            "Diagnostics - crash reports are readable in Settings, with a link to Apple’s symbolicated report",
            "Fixed: dictating during a meeting could type the whole meeting into the app in front of you",
            "Fixed: a transcription hiccup mid-meeting silently discarded 30 seconds of speech",
            "Fixed: a long meeting grew memory without bound; now flat",
            "Fixed: crash reports were unreliable exactly when they mattered, and suppressed macOS’s own report",
            "Fixed: holding the hands-free chord toggled it repeatedly; the Right Control option fired on every Control shortcut",
            "Fixed: editing a note’s body froze its automatic title for good",
        ]),
        Release(version: "2.0.51", date: "August 2026", highlights: [
            "The sidebar is now fixed - no collapsing, and the toggle button is gone",
            "New Liquid Glass look for the pill, the window, and every tile",
            "Softer sounds: redesigned from scratch, not just quieter",
            "Fixed an unreadable selected row in the sidebar",
        ]),
        Release(version: "2.0.16", date: "July 2026", highlights: [
            "Speech recognition and writing transforms run on this Mac. The included Small model works offline; downloading other model weights and app updates require a network connection",
            "Utter does not upload dictation audio or transcript text and has no account, API-key, or telemetry service",
            "Dictation is much faster, typically under half a second instead of waiting on a network round trip",
            "Redesigned interface: a native sidebar, a consistent type scale, real empty states, and a Home screen that shows live status instead of decorative cards",
            "The floating pill now shows a real microphone level, names what it\u{2019}s doing (transcribing, rewriting, typing), explains errors instead of just turning red, and shows the hands-free countdown so you can keep talking to cancel it",
            "Your scratchpad notes are saved instead of being lost when you switch tabs",
            "Fixed: Clear All Data now clears everything it promises, exports keep their file extension, permission indicators refresh live, and a fresh install follows your macOS appearance",
        ]),
        Release(version: "2.0.13", date: "July 2026", highlights: [
            "Your clipboard is now fully preserved - dictating no longer wipes copied images, rich text, or files, and starting a recording never touches the clipboard when nothing is selected",
            "New: Spoken punctuation toggle (Settings → Behavior) - say \"period\" or \"comma\" to punctuate. Off by default, and word-aware so phrases like \"a difficult period\" or \"first thing in the morning\" are left alone",
        ]),
        Release(version: "2.0.12", date: "July 2026", highlights: [
            "Custom Dictionary now actually improves your transcriptions - it fixes the spelling and capitalization of your terms (e.g. 'kubernetes' → 'Kubernetes') and corrects close misspellings of distinctive names",
            "Smarter language handling - the detected language is now shown on each history entry, and forcing a specific language is honored as a strong hint",
            "History upgrades - re-inject any past transcription into the app you’re using with one click, plus a language tag on each entry",
            "Fixed AI commands (Translate, Style, Fix, Summarize) corrupting your document when run on selected text in another app",
            "Failed AI commands now give clear error feedback instead of a silent 'success' chime",
        ]),
        Release(version: "2.0.4", date: "May 2026", highlights: [
            "Hands-free dictation - press ⌃⌥Space (Control+Option+Space) anywhere to start a hands-free recording",
            "Works from idle, or upgrades an active push-to-talk session into hands-free without losing audio",
            "Hands-free auto-stops after 3 seconds of silence, or press ⌃⌥Space again to finalize manually",
            "New 'hands-free' pill state with orange tint and lock icon while locked on",
            "User-defined commands override built-ins so you can customize behavior",
            "Optional {{text}} template placeholder for shaping the user prompt sent to Claude",
            "Replace-vs-append toggle controls whether AI output overwrites your selection or appends after the cursor",
            "Dynamic snippet placeholders - [date], [time], [datetime], [day], [clipboard]",
            "Click-to-insert chips in the Snippets editor for placeholder discovery",
            "Static snippets keep working unchanged - placeholders are opt-in per snippet",
        ]),
        Release(version: "2.0.1", date: "April 2026", highlights: [
            "Major UI overhaul - two-column Home with feature cards and history",
            "5 themes - Default, Midnight, Frost, Ocean, Ember (pill + window)",
            "Style commands - make it professional/concise/casual/formal on any text",
            "Works on selected text in any app - not just dictation",
            "What’s New page with full version history",
            "Responsive layout - resizes with window",
            "Theme picker in Settings with live preview",
            "Custom menu bar icon",
        ]),
        Release(version: "1.1.3", date: "April 2026", highlights: [
            "Multiple themes - Default, Midnight, Frost, Ocean, Ember (pill + window)",
            "What’s New page with version history",
        ]),
        Release(version: "1.1.2", date: "April 2026", highlights: [
            "AI Commands page replacing Style - full guide for voice commands",
            "Clear All Data confirmation dialog",
            "Style commands - make it professional/concise/casual/formal",
            "Works on selected text in any app, not just dictation",
        ]),
        Release(version: "1.1.1", date: "March 2026", highlights: [
            "Context-aware formatting (code, chat, email, document detection)",
            "Auto-detect language with force option",
        ]),
        Release(version: "1.1.0", date: "March 2026", highlights: [
            "Renamed to Utter with lightbulb icon",
            "Multi-language support (20 languages)",
            "Voice commands - keyboard actions (undo, select all, new line)",
            "Configurable hotkey (Fn, Right Option, Right Command, Right Control)",
            "Dark/light mode toggle",
            "History search and export (Markdown, CSV, Text)",
            "Privacy & Security page",
            "Custom sounds for recording feedback",
            "Pill position memory",
            "Right-click context menu on pill",
        ]),
        Release(version: "1.0.0", date: "March 2026", highlights: [
            "Initial release",
            "Voice to text using Whisper speech models",
            "Floating pill UI with recording states",
            "Menu bar integration",
            "Transcription history with word count and streak",
            "Dictionary, Snippets, Scratchpad",
        ]),

    ]
}

private struct ReleaseNotes: View {
    let release: WhatsNewView.Release

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: release.version)
                    .font(.headline.monospaced())
                Text(release.date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(release.highlights, id: \.self) { line in
                Text(line)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
