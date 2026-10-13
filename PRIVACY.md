# Privacy

Utter transcribes your speech on your own Mac. Your audio is never uploaded, your
transcripts are never uploaded, and there is no account, no server, and no
analytics. There is exactly one thing the app can download, a speech model, and it
happens only if you ask for one.

This page says what is stored, where, and what each permission is for. Where a
claim comes from a specific place in the source it cites the file, and the last
section lists the commands that check the broad ones.

## What leaves your Mac

One address, in the whole app:

```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/<model-filename>
```

That is `Sources/UtterKit/Speech/ModelStore.swift:133`, and it is the only
`URLSession` call in the codebase. It is reached only when you pick a speech model
tier in Settings that is not the one bundled in the app. A default install never
makes it: the `small.en` model ships inside the app so dictation works offline on
first launch.

Nothing is sent with that request except the request itself.

What is *not* in the app, verified by reading the linked libraries of the built
binary: 42 libraries, all Apple system frameworks except `whisper.framework`. No
cloud SDKs, no analytics or telemetry SDK, no Sentry, Crashlytics, Firebase,
Amplitude, Segment, PostHog, and no Sparkle-style updater. The app also never
shells out to another program: there is no `Process`, `posix_spawn` or `popen`
anywhere in the source. There are no credentials of any kind, and the build fails
outright if a `.env` file appears next to it.

Transcription is whisper.cpp running in-process on your machine. Apple's Speech
framework is not used at all, so nothing is routed through it either.

### Downloaded models are not hash-verified

The model download fetches from the mutable `resolve/main` branch reference and
checks only that the file is roughly the expected size before handing it to the
model parser. There is no SHA-256 pin on those bytes. The code says so itself, in
a `SECURITY:` comment at `ModelStore.swift:122-131`, and pinning an immutable
revision plus a per-model hash is outstanding work rather than something already
done.

In practice this affects only the optional larger models, because the default
model is bundled and downloaded by nobody. But if you download one, you are
trusting huggingface.co and your network path at that moment, and Utter is not
independently verifying the result.

## What is stored, and where

Everything lives in one folder:

```
~/Library/Application Support/Utter
```

It is created owner-only (mode `0700`), so other user accounts on the Mac cannot
read it.

| File | What is in it |
|---|---|
| `notes.json` | Every note, including anything you dictated into a note. This is the only copy. |
| `notes.previous.json` | One generation of backup of the above, so a bad write cannot lose everything. |
| `history.json` | Your dictation history: the **full text** of each transcription, its timestamp, a word count, and the detected language. Capped at the most recent 1000 entries. |
| `streak.json` | Daily-streak counters. |
| `userdata.json` | Preferences and your own content: dictionary words, snippets, custom AI commands, scratchpad, last transcription, language, theme, hotkey choice. |
| `crashes/` | Local crash logs. See below. |
| `Models/` | Speech models you chose to download. Empty unless you did. |
| `Companions/` | Companion packs you installed yourself. |

Two more files can appear: if `notes.json` or `history.json` is ever unreadable,
it is renamed to `notes-unreadable-<timestamp>.json` or
`history-unreadable-<timestamp>.json` rather than deleted, so a parsing bug cannot
silently destroy your writing. Some window and toggle preferences are also kept in
the app's own preferences file under `~/Library/Preferences`, which is the normal
place macOS puts them.

Note bodies are plain text. Nothing here is encrypted beyond the directory
permissions and whatever FileVault does for your disk as a whole.

### Audio is not one of these files

Recorded audio is held in memory as raw samples, wrapped into a WAV in memory,
handed to whisper, and dropped. It is never written to disk — not as a temporary
file, not as a cache. The only paths the app writes to are the ones in the table
above, and none of them takes audio.

## Permissions, and what each one is actually for

Utter asks for four. Each is requested for one job, and the app degrades rather
than breaks when one is missing.

**Microphone.** Recording your voice so it can be transcribed. Prompted the first
time you dictate. Without it there is no dictation at all — this is the one
permission the app cannot work without.

**Accessibility.** Two jobs. It is how the global hotkey is seen at all, no matter
which app is in front, and it is how the transcribed text gets typed into whatever
you were writing in. It is also what lets the desktop companion react to your
typing — and the only thing it learns from your typing is *how many* keystrokes
happened and when. Not the keys, not the characters, not the app you were in; the
counter is a type that physically cannot hold them. Without Accessibility the
hotkey and text insertion stop working, and the companion sits still.

**System audio capture** (`NSAudioCaptureUsageDescription`). The preferred route
for meeting capture on macOS 14.2 and later. It taps the audio of the meeting
process only, so your music and notification sounds are not captured. This is a
different permission from Screen Recording, with its own prompt.

**Screen Recording.** The fallback route for meeting capture, used only where the
narrower system-audio tap above is unavailable or does not deliver audio. Utter
does not read your screen, take screenshots, or record video; on this route
macOS's screen-capture API is simply the only way to reach system audio, and the
permission is named for the API rather than for what is used of it. Without either
of these two, dictation is unaffected and only meeting capture stops.

## Meeting capture records other people

This is the one feature that records someone other than you.

When you start a meeting transcription, Utter captures two streams: your
microphone, labelled **You**, and the audio your Mac is playing, labelled
**Others** — which is every remote participant, already mixed together by the
conferencing app. Both are transcribed on your Mac and the audio is discarded;
only the text is saved, into a note.

"Others" is a statement about which audio input it came from, not about who was
speaking. Utter cannot tell two remote participants apart and does not pretend to:
there is no speaker identification, and no "Speaker 1 / Speaker 2" numbering.

It is off by default and never starts on its own. It can *offer*, when it notices a
call, and that offer is itself off by default.

**Recording other people may carry legal obligations where you are.** Some places
require every participant's consent. That is your responsibility as the person
running the app, not something the app can decide for you or check on your behalf.
Utter does not notify the other participants that you are transcribing.

## Crash logs

Crash handling is entirely local — the logs are written to `crashes/` in the folder
above and are never sent anywhere. There is no upload code.

A report contains the date, the crash type and signal name, the failure reason,
Utter's version, your macOS version, and a stack trace. It does not contain your
transcriptions, your notes, or your audio. You can read them yourself in the
Diagnostics pane.

## Deleting everything

**Settings → Privacy → Reset Utter.**

It asks for confirmation first, then deletes your transcription history, every
note, installed companion packs, dictionary words, snippets, custom AI commands and
all preferences, and removes the folder above. It resets the in-memory state too,
so nothing gets written back out afterwards. This cannot be undone — notes are the
only copy of what you dictated into Utter.

To remove the app itself, drag it out of `/Applications`. That leaves the data
folder behind; delete `~/Library/Application Support/Utter` by hand if you want it
gone as well.

## Checking any of this yourself

Each of these takes a few seconds and needs nothing but the repository:

```sh
# Every network call in the app. One address.
grep -rn "URLSession\|https://" Sources/

# The app never runs another program.
grep -rn "Process(\|posix_spawn\|popen" Sources/

# Apple's Speech framework is not used.
grep -rn "import Speech\|SFSpeechRecognizer" Sources/

# What the built binary links against.
otool -L .build/release/Utter
```
