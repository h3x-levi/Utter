# Contributing to Utter

Thanks for considering a contribution. Utter is a native macOS app built with Swift, SwiftUI, AppKit, AVFoundation, and a pinned whisper.cpp framework. Keep changes focused and preserve users' notes, permissions, and preferences across upgrades.

## Before you start

- Search existing issues and pull requests before opening a new one.
- For a large change, open an issue first to agree on the behavior and scope.
- Do not include recordings, transcripts, API keys, personal paths, or user data in a report or test fixture.
- Never run `scripts/build-app.sh --reset-dev-state` on a machine with data you need; the flag is only for an explicit fresh-install simulation.

## Build and validate

Requirements: macOS 26 with Xcode 26 or its Command Line Tools, for the macOS 26 SDK. The app itself runs on macOS 14 and later. The whisper.cpp binary target is pinned in `Package.swift`.

Set `UTTER_DATA_DIR` to a scratch folder to run a build without touching your own notes and history: `open --env UTTER_DATA_DIR=/tmp/utter-dev build/Utter.app --args --open-window`.

```sh
swift build
swift test
bash -n scripts/build-app.sh
```

The full app bundle can be built with `bash scripts/build-app.sh --no-dmg`. This updates the local build metadata and creates `build/Utter.app`; it preserves existing user data and permissions by default. The app can be launched with `open build/Utter.app`.

If a test bundle's ad-hoc signing fails on an ExFAT checkout, run tests from an APFS checkout. Do not treat deleting generated bundle sidecars and manually signing a build product as a source-level fix.

## Change guidelines

- Keep UI state and user-facing errors on the main actor; move blocking I/O, hashing, and inference away from it.
- Keep the Whisper context serialized and make cancellation and model lifecycle behavior explicit.
- Never log audio, transcripts, prompt contents, or user text. Prefer durations, counts, model identifiers, and error categories.
- Preserve existing JSON formats or add a tested migration before changing them.
- Use native Apple frameworks where they fit the user-facing behavior; avoid adding a dependency for a small utility.
- Keep model URLs pinned to immutable revisions and verify downloads against checked-in digests.
- Update documentation and screenshots when behavior or visible UI changes. Distinguish measured performance from estimates.
- Add or update focused tests for behavior changes. Include the macOS version and hardware when reporting platform-specific behavior.

## Pull requests

Keep each pull request centered on one user-visible or maintenance outcome. Describe the problem, the behavior change, data or permission impact, validation performed, and any platform or performance limitation. Link related issues. Do not include generated build products, model downloads, local secrets, or unrelated formatting churn.

The macOS CI workflow runs `swift build` and `swift test` for changes targeting `main`. A green CI run does not replace manual validation of microphone, Accessibility, system-audio, multi-display, and signed-release workflows.
