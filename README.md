<div align="center">

<img src="Assets/AppIconSource.png" alt="Utter app icon" width="112" height="112" />

# Utter

**Voice dictation for the Mac that never leaves the Mac.**

Hold a key, say it, let go. Your words appear wherever the cursor is.<br />
The speech model runs on your Mac, so it works offline, with no account and no subscription.

<a href="https://github.com/h3x-levi/Utter/releases"><img src="https://img.shields.io/badge/Download_for_Mac-Utter_v1.0_(.dmg)-0b0f17?style=for-the-badge&logo=apple&logoColor=white" alt="Download Utter v1.0 for Mac" height="44" /></a>

<sub>macOS 14 or later · Apple silicon and Intel · 192 MB, speech model included · <a href="https://github.com/h3x-levi/Utter/releases">All releases</a></sub>

[![Version: 1.0 (v1)](https://img.shields.io/badge/version-1.0_(v1)-blue?style=flat-square)](https://github.com/h3x-levi/Utter/releases)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache_2.0-3b82f6?style=flat-square)](LICENSE)
[![Runs on-device](https://img.shields.io/badge/speech-on--device-22c55e?style=flat-square)](PRIVACY.md)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-f59e0b?style=flat-square)](#contributing)

> [!NOTE]
> **Version 1 (Initial Release):** Utter is currently at **Version 1 (v1.0)**. Core on-device voice dictation, local Whisper/Whistle speech models, meeting transcription, dictionary snippets, and companion features are fully operational on your Mac. As this is version one, active polish, performance optimizations, and community feedback are continuously incorporated.

<br />

<img src="Assets/screenshots/home.webp" alt="Utter's Home window: today's dictations as beads on a line, with a list of recent dictations" width="100%" />

</div>

---

## How it works

<table>
<tr>
<td width="55%">

1. **Hold `fn`** in any app: Mail, Slack, Notes, Xcode, a terminal, a browser.
2. **Talk.** The small pill at the bottom of the screen shows it's listening.
3. **Let go.** Utter turns your speech into text on your Mac and types it at the cursor.

Double-tap `fn` to keep listening hands-free, and press `Esc` to cancel.

</td>
<td width="45%" align="center">

<img src="Assets/screenshots/pill-listening.webp" alt="The Utter pill while listening: seven white bars in a small dark capsule" width="100%" />

</td>
</tr>
</table>

If no text box was selected when you finished, your words wait in a small island with a Copy button, so nothing you said is lost.

<p align="center">
  <img src="Assets/screenshots/pill-island.webp" alt="The island: 'No text box was focused, so your words are here', the transcript, a Copy button and an Esc to close hint" width="70%" />
</p>

---

## Local-first by design

Utter was built to keep your voice on your Mac. This is how the code behaves out of the box:

| | |
| :--- | :--- |
| **Where speech becomes text** | In the Utter process on your Mac, with [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (or the optional Whistle engine). Audio is never uploaded. |
| **When it goes online** | Only when you choose to download another speech model. The model that ships in the app works with Wi-Fi off. |
| **Accounts and tracking** | None. No sign-in, no analytics, no telemetry. |
| **Where your data lives** | Plain JSON files in `~/Library/Application Support/Utter`, a folder only your user account can read. Delete it and everything is gone. |
| **Cost** | Free and open source under Apache 2.0. |

Read [PRIVACY.md](PRIVACY.md) for the details.

---

## What's inside

### Library: every dictation, note and meeting

Search everything you've said, grouped by day. Dictate straight into a note with `⌃⌥N`. When a Zoom, Teams, FaceTime, Webex, Slack or Discord call starts, Utter can offer to transcribe it. It records your microphone and the call audio and labels the two sides **You** and **Others**, all on your Mac.

<img src="Assets/screenshots/library.webp" alt="Library: today's dictations, notes and a meeting, with filters for All, Dictations, Notes and Meetings" width="100%" />

### Words: teach it your vocabulary

- **Dictionary:** names and terms Utter should always spell your way, such as colleagues, products and jargon.
- **Snippets:** say a short phrase and it expands into longer text, with `[date]`, `[time]`, `[day]` and `[clipboard]` filled in when it expands.
- **Voice commands:** select text in any app and say what to do with it ("make this shorter", "fix the punctuation"). On Macs with Apple Intelligence these run on the on-device model.

### Companion: a small friend beside the pill

An optional robot that floats near the pill, listens along with you, and sleeps when you're idle. It can remind you to stretch, drink water or take a break, track a daily word goal, and keep private reminders you speak with `⌃⌥R`. It goes quiet by itself while you share your screen or record a meeting.

<img src="Assets/screenshots/companion.webp" alt="Companion settings: the robot preview, size and head shape controls, and reminders" width="100%" />

### Two speech engines

| Engine | Best for | Size |
| :--- | :--- | :--- |
| **Accurate** (Whisper small.en, included) | Everyday dictation with the best results | 190 MB |
| **Fast** ([Whistle](https://cactuscompute.com/blog/whistle), included) | Text that appears instantly; Apple silicon on macOS 26 | 17 MB |

In Settings → Speech you can switch engines, or download larger Whisper models, including multilingual ones.

<img src="Assets/screenshots/settings.webp" alt="Settings window with General, Speech, Shortcuts, Privacy and Help tabs" width="100%" />

### Made for macOS

Utter is a native Swift app. On macOS 26 it uses Liquid Glass for the floating sidebar and toolbar, and it follows your Light or Dark setting. It is a menu bar app, so it stays out of the Dock unless you ask for it there.

---

## Keyboard shortcuts

| Shortcut | What it does |
| :--- | :--- |
| Hold **`fn`** (or Right `⌥`, Right `⌘`, Right `⌃`) | Dictate into the app you're using |
| Double-tap **`fn`**, or **`⌃⌥Space`** | Hands-free: keep listening until you stop |
| **`⌃⌥N`** | Dictate into a new Utter note |
| **`⌃⌥R`** | Tell your companion a private reminder |
| **`⌃⌥U`** | Open the Utter window |
| **`Esc`** | Cancel |

You can change the dictation key in Settings → Shortcuts.

---

## Install

1. **[Download Utter-1.0.0.dmg](https://github.com/h3x-levi/Utter/releases)** and open it.
2. Drag **Utter** into **Applications**.
3. Open Utter. Setup asks for two permissions:
   - **Microphone**, to hear you.
   - **Accessibility**, to notice the `fn` key and type into other apps.

<img src="Assets/screenshots/onboarding.webp" alt="First-run setup: 'Talk instead of typing'" width="100%" />

> [!NOTE]
> Utter is signed but not notarized, because notarization needs a paid Apple developer account. The first time you open a downloaded copy, macOS says it can't verify the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**. [Installing on another Mac](docs/INSTALLING-ON-ANOTHER-MAC.md) has the details.

---

## Build it yourself

You need macOS 26 with Xcode 26 or its Command Line Tools, because the app uses the macOS 26 SDK. The app itself runs on macOS 14 and later.

```bash
git clone https://github.com/h3x-levi/Utter.git
cd Utter
swift build                                  # compile
swift test                                   # run the test suite
bash scripts/build-app.sh --no-dmg           # make build/Utter.app
bash scripts/build-app.sh --version=1.0.0    # make build/Utter-1.0.0.dmg too
```

To try a build without touching your own notes and history, point it at a throwaway folder:

```bash
open --env UTTER_DATA_DIR=/tmp/utter-dev build/Utter.app --args --open-window
```

---

## Contributing

Utter is a community project and contributions are welcome, whether code, design, bug reports or docs.

- **Found a bug?** [Open an issue](https://github.com/h3x-levi/Utter/issues/new). Include your macOS version, Mac model and microphone. Settings → Help → Report an Issue fills most of this in for you.
- **Want to build something?** Open an issue first for anything large so we can agree on the shape, then send a pull request.
- **Before you start,** read [CONTRIBUTING.md](CONTRIBUTING.md). Above all, never log or upload audio, transcripts or anything the user typed.

How the code is laid out:

| Folder | What lives there |
| :--- | :--- |
| `Sources/UtterCore` | Audio, speech engines, storage, the dictation pipeline. No UI. |
| `Sources/UtterKit` | Every window and view: pill, island, Home, Library, Words, Companion, Settings. |
| `Sources/Utter` | The app's entry point. |
| `Tests/UtterKitTests` | The test suite. `UTTER_SCREEN_SNAPSHOTS=1 swift test` also renders every screen to `.build/screen-snapshots/`. |

---

## Credits

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT) for the Accurate engine.
- [Whistle](https://cactuscompute.com/blog/whistle) by Cactus Compute (Apache 2.0) for the Fast engine.
- The companion robot is a native port of a design by CX-ArtLab (MIT).

Full notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
