<div align="center">

<img src="Assets/AppIconSource.png" alt="Utter app icon: seven red, gold and blue bars on black tape" width="112" height="112" />

# Utter

**Voice dictation for the Mac that never leaves the Mac.**

Hold a key, say it, let go. Your words appear wherever the cursor is.<br />
The speech model runs on your Mac, so it works offline, with no account and no subscription.

<a href="https://github.com/h3x-levi/Utter/releases/download/v1.2.0/Utter-1.2.0.dmg"><img src="https://img.shields.io/badge/Download_for_Mac-Utter_1.2.0_(.dmg)-1c2a5e?style=for-the-badge&logo=apple&logoColor=white" alt="Download Utter 1.2.0 for Mac" height="44" /></a>
&nbsp;
<a href="https://utter-eight.vercel.app/"><img src="https://img.shields.io/badge/Live_Website-utter--eight.vercel.app-000000?style=for-the-badge&logo=vercel&logoColor=white" alt="Utter Live Website" height="44" /></a>

<sub>macOS 14 or later · Apple silicon and Intel · 192 MB, speech model included · <a href="https://github.com/h3x-levi/Utter/releases">All releases</a> · <a href="https://utter-eight.vercel.app/">Official Website</a></sub>

[![Website](https://img.shields.io/badge/website-utter--eight.vercel.app-000000?style=flat-square&logo=vercel)](https://utter-eight.vercel.app/)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache_2.0-1c2a5e?style=flat-square)](LICENSE)
[![Runs on-device](https://img.shields.io/badge/speech-on--device-d8352a?style=flat-square)](PRIVACY.md)
[![Contributions welcome](https://img.shields.io/badge/contributions-welcome-f1b632?style=flat-square)](#contributing)

<br />

<video src="promo/Utter-Hype-16x9.mp4" controls="controls" width="100%" playsinline>
  <source src="promo/Utter-Hype-16x9.mp4" type="video/mp4" />
</video>

<p align="center">
  🎬 <strong><a href="promo/Utter-Hype-16x9.mp4">Watch the Utter promo video (16:9 Landscape)</a></strong>
</p>

<br />

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Assets/screenshots/library-dark.webp" />
  <img src="Assets/screenshots/library.webp" alt="Utter's Library: today as a cassette tape with Side A and Side B tracklists and running times, and the open track on the right with Paste again, Copy and Delete" width="100%" />
</picture>

</div>

---

## How it works

1. **Hold `fn`** in any app: Mail, Slack, Notes, Xcode, a terminal, a browser.
2. **Talk.** The pill at the bottom of the screen turns red and shows it's listening.
3. **Let go.** Utter turns your speech into text on your Mac and types it at the cursor.

Double-tap `fn` to keep listening hands-free, and press `Esc` to cancel.

<p align="center">
  <img src="Assets/screenshots/pill-states.webp" alt="The pill's six looks: a small red, gold and navy stripe at rest, red with white bars while listening, hands-free with a lock, thinking, navy with a tick once typed, and gold when something needs you" width="100%" />
</p>

At rest the pill is a 32 by 6 point stripe. It only grows while you talk.

If no text box was selected when you finished, your words wait in the island, so nothing you said is lost. Copy them, or save them as a note.

<p align="center">
  <img src="Assets/screenshots/pill-island.webp" alt="The island: 'No text box selected, so your words are here', the transcript, Copy and Save as note buttons, and an Esc to close hint" width="70%" />
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

### The menu bar: today's tape, one click away

<table>
<tr>
<td width="52%">

Click the Utter icon in the menu bar to see today's tracks, newest first.

- **`↩`** types a track again into the app you were just in.
- **`⌘C`** copies it, and **`⌘O`** opens it in the Library.
- Search looks through every day, note and meeting.
- Start hands-free, a new note or a meeting recording from the keys underneath.

The red stripe across the top fills up as you talk toward your daily word goal.

</td>
<td width="48%" align="center">

<img src="Assets/screenshots/hub.webp" alt="The menu-bar hub: a red 'Ready, hold fn' stripe with today's word count, a search line, today's tracks with running times, and Hands-free, New note and Record meeting keys" width="100%" />

</td>
</tr>
</table>

### Library: every dictation, note and meeting

Each day is a tape. Morning tracks go on Side A and the afternoon and evening on Side B, each with its running time. Pick a track and it opens on the right, where you can paste it again, copy it, turn it into a note or delete it. Deleting can be undone.

Dictate straight into a note with `⌃⌥N`. When a Zoom, Teams, FaceTime, Webex, Slack or Discord call starts, Utter can offer to transcribe it. It records your microphone and the call audio and labels the two sides **You** and **Others**, all on your Mac.

### Words: teach it your vocabulary

- **Dictionary:** names and terms Utter should always spell your way, such as colleagues, products and jargon. When Utter hears a new name, it offers to add it.
- **Snippets:** say a short phrase and it expands into longer text, with `[date]`, `[time]`, `[day]` and `[clipboard]` filled in when it expands.
- **Voice commands:** select text in any app and say what to do with it ("make this shorter", "fix the punctuation"). On Macs with Apple Intelligence these run on the on-device model.

### Companion: a small friend beside the pill

An optional robot that floats near the pill, listens along with you, and sleeps when you're idle. It can remind you to stretch, drink water or take a break, and keep private reminders you speak with `⌃⌥R`. It goes quiet by itself while you share your screen or record a meeting. Turn it on in Settings → Companion.

<img src="Assets/screenshots/companion.webp" alt="Settings, Companion tab: the robot preview, show beside the pill, size, head shape, quiet mode and reminders" width="100%" />

### Two speech engines

| Engine | Best for | Size |
| :--- | :--- | :--- |
| **Accurate** (Whisper small.en, included) | Everyday dictation with the best results | 190 MB |
| **Fast** ([Whistle](https://cactuscompute.com/blog/whistle), included) | Text that appears instantly; Apple silicon on macOS 26 | 17 MB |

In Settings → Speech you can switch engines, or download larger Whisper models, including multilingual ones.

<img src="Assets/screenshots/settings.webp" alt="Settings window with General, Speech, Shortcuts, Companion and Privacy tabs, under a red Daily tape stripe" width="100%" />

### Made for macOS

Utter is a native Swift app, designed like a cassette J-card: white ruled card, navy ink, and a red stripe for today's tape. In Dark mode it becomes chrome tape. It lives in the menu bar and stays out of the Dock unless you ask for it there.

---

## Keyboard shortcuts

**Anywhere**

| Shortcut | What it does |
| :--- | :--- |
| Hold **`fn`** (or Right `⌥`, Right `⌘`, Right `⌃`) | Dictate into the app you're using |
| Double-tap **`fn`**, or **`⌃⌥Space`** | Hands-free: keep listening until you stop |
| **`⌃⌥N`** | Dictate into a new Utter note |
| **`⌃⌥R`** | Tell your companion a private reminder |
| **`⌃⌥U`** | Open the Library |
| **`Esc`** | Cancel |

You can change the dictation key in Settings → Shortcuts.

**In the menu-bar hub**

| Shortcut | What it does |
| :--- | :--- |
| **`↑`** **`↓`** | Choose a track |
| **`↩`** | Type it again into the app you were in (opens a meeting instead) |
| **`⌘C`** | Copy it |
| **`⌘O`** | Open it in the Library |
| **`⌘N`** | New note |
| **`⌘,`** | Settings |

**In the Library**

| Shortcut | What it does |
| :--- | :--- |
| **`↑`** **`↓`** | Choose a track |
| **`↩`** | Paste a dictation again |
| **`⌘C`** | Copy the track |
| **`⌫`** or **`⌘⌫`** | Delete the track |
| **`⌘Z`** | Undo the delete |
| **`⌘N`** | New note |
| **`⌘F`** | Search |
| **`⌘1`** to **`⌘4`** | Everything, Dictations, Notes, Meetings |
| **`⌘5`** | Words |

---

## Install

1. **[Download Utter-1.2.0.dmg](https://github.com/h3x-levi/Utter/releases/download/v1.2.0/Utter-1.2.0.dmg)** and open it.
2. Drag **Utter** into **Applications**.
3. Open Utter. Setup asks for two permissions:
   - **Microphone**, to hear you.
   - **Accessibility**, to notice the `fn` key and type into other apps.

<img src="Assets/screenshots/onboarding.webp" alt="First-run setup, step 1 of 3: 'Talk instead of typing', with an fn key beside the red listening pill" width="100%" />

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
bash scripts/build-app.sh --version=1.2.0    # make build/Utter-1.2.0.dmg too
```

To try a build without touching your own notes and history, point it at a throwaway folder:

```bash
open --env UTTER_DATA_DIR=/tmp/utter-dev build/Utter.app --args --open-window
```

---

## Contributing

Utter is a community project and contributions are welcome, whether code, design, bug reports or docs.

- **Found a bug?** [Open an issue](https://github.com/h3x-levi/Utter/issues/new). Include your macOS version, Mac model and microphone. Settings → General → Report an Issue fills most of this in for you.
- **Want to build something?** Open an issue first for anything large so we can agree on the shape, then send a pull request.
- **Before you start,** read [CONTRIBUTING.md](CONTRIBUTING.md). Above all, never log or upload audio, transcripts or anything the user typed.

How the code is laid out:

| Folder | What lives there |
| :--- | :--- |
| `Sources/UtterCore` | Audio, speech engines, storage, the dictation pipeline. No UI. |
| `Sources/UtterKit` | Every window and view: pill, island, menu-bar hub, Library, Words, Settings and the companion. |
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
