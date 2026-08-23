# Utter

A macOS menu-bar app that turns your speech into text, wherever the cursor is.
Hold a key, talk, let go, and the words are typed into whatever you were writing
in — mail, a terminal, a code review, a text field on a web page.

It runs entirely on your Mac. Transcription is whisper.cpp in-process, the model
ships inside the app, and there is no account, no server and no telemetry. The only
address in the whole codebase is a speech-model download you have to ask for.
[PRIVACY.md](PRIVACY.md) lists every file the app writes and the commands that
verify the rest.

This is a personal project, published because it works and someone else may want
it. It is not a product and there is no support promise. Read
[Status and known limitations](#status-and-known-limitations) before you rely on
it for anything.

## Who it is for

Someone who dictates a lot and does not want their voice going to a server to do
it. The design bias throughout is local-first and quiet: no cloud round-trip, no
sign-in, no dock icon, no notifications you did not ask for.

## What it does

**Dictation with a global hotkey.** Hold the hotkey, speak, release. The text is
inserted into the frontmost app. The default hotkey is **Fn**; Settings offers
right **⌥**, right **⌘** and right **⌃** instead. Holding is push-to-talk, so a
recording lasts exactly as long as you hold the key.

**Hands-free mode.** `⌃⌥Space` latches the recording on, so you can put your hands
back on the keyboard. A turn ends by itself after **3 seconds** of silence, or when
you press the chord again. You can also start a hands-free turn by holding the
hotkey and tapping Space, or by clicking the record bead that appears when you
hover the pill.

**Dictating into notes.** `⌃⌥N` sends the dictation into a note inside Utter
instead of typing it into another app, which is what you want for a thought you
have not decided where to put yet. The pill turns into a card showing the
destination note and a live preview. It can start a new note or append to the one
you have open. Notes are plain text, stored as JSON, and export to Markdown one at
a time.

**Meeting transcription.** Captures your microphone and the audio your Mac is
playing at the same time, transcribes both on-device, and writes the result into a
note labelled **You** and **Others**. It is off by default and never starts on its
own. Read the limits in
[Status and known limitations](#status-and-known-limitations) — particularly that
"Others" means "came in over the speakers", not a particular person.

**AI text commands.** Speak an instruction instead of dictating text — "make this
concise", "fix grammar", "translate to Japanese", "summarize this", "reply to this"
— and it rewrites your current selection, or your last transcription if nothing is
selected. You can define your own commands too, and yours take precedence over the
built-ins. This uses Apple's on-device model via the `FoundationModels` framework,
so it needs **macOS 26 with Apple Intelligence enabled**, and it is the one feature
with a hard requirement beyond the app's floor. Where it is unavailable the app
says exactly why and dictation carries on working.

**A desktop companion.** An optional pixel character in a small floating window
that reacts to what is actually happening: your microphone level, whether a
transcription is running, your cursor, and the *rate* of your typing — never its
content. Off by default. Four packs ship, and you can add your own; see
[Companion packs](#companion-packs).

## Requirements

| | |
|---|---|
| **To run** | macOS 13.3 or later, Apple silicon or Intel |
| **Liquid Glass** | macOS 26. Below it the interface falls back to standard translucent materials — by design, and also what happens on 26 if you have Reduce Transparency on |
| **Meeting capture** | The narrow, meeting-process-only audio tap needs macOS 14.2. Below that it falls back to the ScreenCaptureKit route (macOS 13) |
| **AI text commands** | macOS 26 with Apple Intelligence enabled. Everything else works without it |
| **To build** | A Swift 5.9 toolchain. Xcode is not required — Command Line Tools is enough, and that is what this was developed on |
| **To regenerate art** | Python 3 and Pillow (`pip install -r requirements.txt`). Only needed if the generated icons or sprite packs are missing or stale |
| **To build the DMG** | `create-dmg` (`brew install create-dmg`). Skip it with `--no-dmg` |

## Building

There is **no Xcode project** and no `.xcodeproj` to open. It is a SwiftPM package.

First, fetch the speech model, which is not in the repository because it is 181 MB:

```sh
mkdir -p Models
curl -L -o Models/ggml-small.en-q5_1.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin
```

The build refuses to continue without it, since the app cannot transcribe anything
without a model.

Then, to compile and run the tests:

```sh
swift build            # or: swift build -c release
swift test             # 431 test functions across 42 files
```

To produce an installable `Utter.app` and a DMG:

```sh
bash scripts/build-app.sh              # app + DMG in build/
bash scripts/build-app.sh --no-dmg     # just the app
```

`build-app.sh` does more than compile. It bumps the patch version in `.version`,
generates any stale art, assembles the bundle, copies in `whisper.framework` and
the model, writes `Info.plist`, and signs the result.

**One thing to know before you run it.** By default it resets your permissions and
moves your app data aside, so the DMG it makes installs like a first install. Your
notes are *moved*, not deleted — to
`~/Library/Application Support/Utter-backup-<timestamp>`, keeping the three most
recent — but if you are just iterating you want:

```sh
bash scripts/build-app.sh --keep-permissions
```

which leaves your data and your granted permissions alone.

To build a specific version rather than bumping the patch:

```sh
bash scripts/build-app.sh --version=3.1.0
```

## Installing a build

Open `build/Utter-<version>.dmg` and drag Utter to Applications.

### The app is not notarized

Notarization needs a paid Apple Developer account, which this project does not
have. The build signs with an Apple Development certificate when one is on the
machine and ad-hoc otherwise, and neither satisfies Gatekeeper on a Mac other than
the one it was built on.

Whether you get blocked depends on how the file arrived. macOS enforces this only
on files carrying a quarantine flag, and the *receiving* program sets it: a USB
stick, `scp` or `rsync` do not, while a browser download, AirDrop, email or chat
attachment do.

If it is blocked, clear the flag once:

```sh
xattr -dr com.apple.quarantine /Applications/Utter.app
```

Then open it normally. A greyed-out or generic icon is usually this same block
rather than a broken icon file, so try clearing the flag before assuming the build
is bad. The alternative route is **System Settings → Privacy & Security → Open
Anyway**; Control-clicking the app and choosing Open no longer works, since Apple
removed that bypass in macOS 15.

Permissions are tied to each machine, so a new Mac prompts for Microphone and
Accessibility again regardless of what the old one allowed.
[docs/INSTALLING-ON-ANOTHER-MAC.md](docs/INSTALLING-ON-ANOTHER-MAC.md) has the full
detail, including what a paid account would change.

## Companion packs

The companion's art is data, not code. Four packs ship inside the app — `dog`,
`panda`, `pixel-cat-orange` and `pixel-cat-gray`, which is the default on a fresh
install — and you add your own by dropping a folder into:

```
~/Library/Application Support/Utter/Companions
```

One folder per pack, one level deep — a pack nested deeper is not found, and
hidden folders are skipped. The folder name is the pack's id, and a user pack whose
folder name matches a bundled one replaces it. The directory is created for you the
first time the app looks.

### The six states

A pack supplies art for up to six states, named exactly:

```
resting   alert   thinking   delighted   startled   sleepy
```

**Only `resting` is required.** Any state you leave out falls back to `resting`, so
a single-image pack is a legitimate pack.

### Three ways to supply the frames

**1. A folder of numbered frames per state.** The simplest thing that animates:

```
my-pack/
  resting/01.png 02.png 03.png …
  thinking/01.png 02.png …
```

Accepted extensions are `png`, `webp`, `heic`, `tiff`, `gif`. Frames are sorted
naturally, so `2.png` comes before `10.png` and zero-padding is optional. Playback
is an even cadence at 8 fps unless you say otherwise.

**2. One file per state.** `resting.png`, `thinking.png`, and so on, in the pack
root. If the file is an animated APNG, GIF or WebP, its frames are used with their
own per-frame delays; a still image is simply held. Extensions are tried in the
order `png`, `webp`, `heic`, `tiff`, `gif`, and the first that exists wins.

A `<state>/` folder beats a `<state>.png` file when both are present.

**3. A horizontal sprite strip, declared in `pack.json`.** For art already cut as a
strip:

```json
{
  "name": "My Pack",
  "author": "you",
  "frameWidth": 64,
  "frameHeight": 64,
  "states": {
    "resting":  { "file": "resting.png",  "frames": 4, "fps": 8 },
    "thinking": { "file": "thinking.png", "frames": 6, "fps": 12 }
  }
}
```

`frameWidth` and `frameHeight` are in pixels and are required as soon as you use
`states` — the strip cannot be cut without them. Strips are a single row, cut left
to right; there is no grid layout.

### `pack.json`

Optional. Without it the pack is discovered by the naming conventions above.

| Key | Type | Default |
|---|---|---|
| `name` | string | the folder name |
| `author` | string | empty |
| `fps` | number | pack-wide frame rate, clamped to 1–60. Per-state settings win |
| `animation.<state>.fps` | number | none. Per-state frame rate for the folder and single-file layouts, since those have no `states` block to put it in |
| `pixelArt` | boolean | `false`. `true` snaps the pack to a whole-number scale and uses nearest-neighbour, which is what keeps pixel art crisp |
| `eyeTravel` | number | `2`. How far the eye overlay moves, in source pixels. Clamped to 0–4 |
| `eyeAnchors` | `{ "<state>": [dx, dy] }` | none. Nudges the eye layer per state, in source pixels, clamped to ±12 |
| `frameWidth`, `frameHeight` | number | none. Required when `states` is present |
| `states` | object | none. Selects the sprite-strip layout |

Unknown keys are ignored, so you can keep your own notes in the file.

Frame rate resolves most-specific-first: `states.<state>.fps`, then
`animation.<state>.fps`, then the top-level `fps`, then 8 fps.

### `eyes.png`

Optional. A transparent overlay containing only the eyes, drawn on top of the body
and offset to follow the cursor. It must be **exactly the same size as the body
frames** or it is ignored, with a warning on the console and the rest of the pack
still loading.

Body frames are downsampled at load to a cap derived from the character size you
have chosen, while `eyes.png` is read at full size, and the size comparison happens
after that downsampling. So keep the whole pack's canvas small: the two pixel-art
packs that ship use a 64×64 canvas, and with larger art the two sizes may never
agree.

### Limits and one gotcha

- 64 frames per state maximum; extra frames are dropped rather than erroring.
- Frames larger than the cap for your chosen character size are downsampled, and
  the extra resolution is discarded.
- A malformed pack is skipped on its own, with the reason shown in Settings. One
  bad pack does not stop the others loading.
- **Editing a frame in place may not be noticed.** The rescan is keyed on the pack
  folder's modification time, and rewriting a file inside a subfolder does not
  change it. Use the Rescan button in Settings.

The scripts under `scripts/` (`build_pack.py`, `animate_pack.py`, `dechecker.py`)
are what the shipped photo packs were generated with, if you would rather derive a
pack from source art than hand-assemble one. The two pixel packs have no source art
to derive from — they are drawn from primitives by
`tools/newcat/generate_cat.py`, which also carries a `--verify` mode that checks the
art without writing it.

## Status and known limitations

It works and gets daily use. These are the things that would otherwise surprise you.

**It is a personal project.** No support, no roadmap commitment, no guarantee the
next commit keeps your workflow. Version numbers auto-bump on every build, so they
are build markers more than releases.

**Not notarized.** Every install on a new Mac needs the quarantine step above.
Fixing this properly costs $99/year.

**The pill's note-card morph is not animated.** It is an instant state change. An
animated expansion was built and rebuilt several times and kept ghosting and
leaving stray outlines, so it was dropped rather than shipped as a smear. It looks
plainer and it is right more of the time.

**Meeting transcription cannot tell two remote people apart.** The You/Others split
is by audio source — your microphone versus your speakers — not by voice. There is
no speaker identification. The two streams are also written source-major rather than
interleaved chronologically, because the only clocks available are per-stream sample
counts and the two captures start at an offset nothing measures. A meeting held in a
browser tab additionally cannot be distinguished from an ordinary video playing.

**Downloaded speech models are not hash-verified.** The default model is bundled so
most installs download nothing, but an optional larger tier is fetched from a
mutable branch reference and checked only for approximate size. Documented in the
source and in [PRIVACY.md](PRIVACY.md).

**Some routes fail quietly by design.** Holding the hotkey and tapping Space needs
an event tap, so without Accessibility it is silently unavailable while the chords
keep working. In a meeting, a 30-second window that fails to transcribe three times
is given up on so the meeting keeps moving.

**The Windows app is not part of this.** This repository is the macOS app.

## Repository layout

```
Sources/UtterKit/     the whole app, as a library so it can be tested
Sources/Utter/        a two-line executable shim
Tests/UtterKitTests/  431 test functions, swift-testing
Companions/           the sprite packs that ship
scripts/              build script and asset generators
tools/                standalone pack-authoring tools
docs/                 installing on another Mac, glossary
```

The app has been renamed twice — `AWSFlow` while it was an internal tool, then
`Lumen`, now `Utter`. Both renames are finished: the package, the executable, the
bundle identifier and the log subsystem are all Utter.

**Four old-name strings survive on purpose and should not be swept up by anyone
finishing the job.** `AppDirectory.legacyNames` lists both old names, and the
permission-reset step of `scripts/build-app.sh` repeats them. They are the on-disk
names of real folders belonging to anyone who ran an earlier build, and they are the
only thing that finds that person's notes, history and crash logs in order to migrate
them. Removing one orphans that data silently, with no error and nothing to recover
from. `legacyNames` is ordered newest-first, so a further rename adds to the **front**
of the list — appending would migrate the oldest folder and abandon the newer one.

## Licence

Apache 2.0 — see [LICENSE](LICENSE). Third-party components and their licences are
listed in [NOTICE](NOTICE), which distinguishes what is shipped inside the app
(whisper.cpp, the Whisper model weights) from what is only used to build and test it.

Apache 2.0 rather than MIT deliberately: its trademark clause makes explicit that
the licence grants no rights in the name. The code is yours to use; "Utter" is a
name in use by others and is not being licensed to anyone here.
