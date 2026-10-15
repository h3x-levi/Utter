# Utter for Windows and Linux

The Electron port of Utter. It keeps the Mac app's behaviour, its Mixtape look and its data files (`history.json`, `notes.json`, `userdata.json`). Speech runs on this computer through the official whisper.cpp v1.9.2 `whisper-server`. Utter starts it on a private `127.0.0.1` port and sends each recording from memory. Audio is never written to disk.

## What it does

The same app as the Mac, screen for screen: sign-in, onboarding, the tray hub, the pill, the Library, Words, Settings, Report an Issue, What's New and the companion.

- **Dictation:** hold Ctrl + Windows (Ctrl + Super on Linux) to talk, and it pastes where the cursor is. PC keyboards have no Fn key that Windows can see, so this is the pair beside it. Right Ctrl, Right Alt and the right Windows key are options in Settings. Double-tap for hands-free, which stops after 3 s of silence; Esc cancels. Ctrl+Alt+Space toggles hands-free, Ctrl+Alt+N dictates into a note, Ctrl+Alt+R remembers something for the companion, and Ctrl+Alt+U opens the Library.
- **Meetings:** the microphone is "You" and the computer's sound is "Others", in the order they were said, with the speaker-echo filter. Utter offers to record when Zoom, Teams, Webex, Slack or Discord starts using the microphone, and stops 20 s after the call ends. System sound comes from WASAPI loopback on Windows and from the default PulseAudio/PipeWire monitor through `parec` on Linux.
- **Sign-in:** Google isn't connected yet. Until it is, the screen shows at first launch with Skip for now, and the test account `utter@gmail.com` signs in by email.

## Differences from the Mac

- Apple Intelligence features (Fix sentence structure, Match the app, Read text around the cursor, AI commands, Summarise) need Apple's on-device model, so their rows show as unavailable, like a Mac without Apple Intelligence.
- The "no text box selected" island and Pause music use a PowerShell helper on Windows. On Linux, Pause music uses MPRIS and the island isn't available, so Utter always pastes.
- Companion reminders post a notification without Done or Snooze buttons, because Electron only offers notification buttons on macOS; both are in Settings > Companion. Reminders fire only while Utter is running.
- On Linux, hold-to-talk needs X11. On Wayland, Utter restarts itself under XWayland and can miss keys typed into native Wayland apps.

## Platform notes

- **Windows 10/11 x64.** The installer walks through the privacy notice and license, the folder, and a desktop shortcut, and installs for the current user without admin rights. It isn't code-signed yet, so Windows warns on first run (More info, then Run anyway). See Signing below.
- **Linux x64.** AppImage and .deb. Meetings need `parec`, from `pulseaudio-utils`.

## Signing

`.github/workflows/windows.yml` builds the installer on GitHub's Windows machines. Once the project is approved by SignPath Foundation (free for open source) and the `SIGNPATH_API_TOKEN` secret and `SIGNPATH_ORGANIZATION_ID` variable are added to the repository, the same run signs it.

## Build

Builds run in Docker from macOS (Colima with Rosetta works) or any x64 Linux. Run from the repository root, so the model in `Models/` is in reach:

```bash
docker run --rm --platform linux/amd64 -v "$PWD":/project -v utter-nm:"/project/Windows and Linux/node_modules" \
  -v utter-cache-electron:/root/.cache/electron -v utter-cache-builder:/root/.cache/electron-builder \
  -w "/project/Windows and Linux" electronuserland/builder:wine \
  bash -c 'apt-get update && apt-get install -y nsis && npm install && npm run dist:win && npx electron-builder --linux --x64'
```

The installers land in `Windows and Linux/Builds/`:

- `Utter-Setup-1.2.1.exe` (Windows installer)
- `Utter-1.2.1-win.zip` (portable)
- `Utter-1.2.1-x86_64.AppImage`
- `utter_1.2.1_amd64.deb`

`npm test` runs the text-rule checks, which are ported from the Mac test suite. `.npmrc` pins the public npm registry.

## Layout

| Path | What it is |
|---|---|
| `src/main.js` | Main process: speech engine, hotkey, dictation turns, paste, data files, meetings, tray and windows |
| `src/text.js` | The Mac app's text rules: formatting, dictionary, snippets, voice commands, titles, turns, echo filter, WAV |
| `src/pill.html`, `src/pill.js`, `src/capture-worklet.js` | The pill, plus microphone and Windows loopback capture at 16 kHz |
| `src/app.html`, `src/app.css`, `src/app.js` | Library, Words and Settings |
| `src/win-helper.js` | The Windows PowerShell helper: which app has focus, and pausing media |
| `src/companion*` | The companion robot window and its behaviour |
| `installer.nsi`, `installer-terms.txt` | The Windows installer wizard and its privacy notice and license page |
| `vendor/win`, `vendor/linux` | whisper.cpp v1.9.2 release binaries (MIT), plus the MSVC runtime and `libgomp` |
| `assets/` | Icon, tray icon, sounds, and Nunito (SIL OFL) for the rounded capitals |
