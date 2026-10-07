# Antigravity handoff: Utter product redesign

**Updated:** 7 October 2026  
**Repository:** `/Volumes/SSD/Utter`  
**Working tree:** Changes are staged for 1.1.58 release; preserve all files and tests.

## Goal & Architecture

Utter 2.0 has been redesigned and rebuilt from first principles as an authentic native macOS voice workspace adhering to the unified 3-Tier Attention Hierarchy:

1. **Tier 0 (The Dynamic Capsule / HUD)**: Ephemeral push-to-talk in any app via global hotkey (`Fn`), sub-150ms Metal injection, live audio waveform visualizer.
2. **Tier 1 (The Unified Voice Canvas / Main Window)**:
   - **Studio (The Present)**: Live speech readiness monitor, active meeting detection (`CallDetector`) and dual-stream recording banner (`MeetingSession`), distraction-free voice scratchpad canvas with on-device AI polish (`SentencePolish`), and desktop companion co-pilot stage (`CodePixelCat`).
   - **Memory (The Past)**: Chronological timeline uniting dictations (`TranscriptionHistory`) and meeting notes (`NoteStore`) into a single searchable stream with instant AI actions (`NoteActionRunner`) and multi-format export (Markdown, CSV, Text).
   - **Voice Engine (The Intelligence)**: The user's personal language center combining Custom Vocabulary (`UserData.dictionaryWords`), Voice Snippets with variable expansions (`UserData.snippets`), and AI Writing Personas (`UserData.customAICommands`) with an interactive sandbox playground.
3. **Tier 2 (System Preferences)**: Apple-native Settings window (`Cmd+,`).

## Completed Work & Invariants

- **Surfaces Implemented**:
  - `Sources/UtterKit/Screens/StudioWorkspaceView.swift`
  - `Sources/UtterKit/Screens/MemoryTimelineView.swift`
  - `Sources/UtterKit/Screens/VoiceEngineView.swift`
  - `Sources/UtterKit/Screens/FlowMainView.swift` (with backward-compatible routing aliases for CLI flags, tests, and preview isolation).
- **Snapshot Preview Data Isolation**:
  - `Sources/UtterKit/App/SnapshotPreviewIsolation.swift` provides in-memory mock fixtures for `UserData`, `TranscriptionHistory`, `NoteStore`, `CompanionMemoryStore`, and `CrashReporter`.
  - Zero disk reads or writes of private user data occur during snapshot rendering.
  - All repository screenshots in `Assets/screenshots/`, `docs/assets/screenshots/`, and `website/public/assets/screenshots/` have been regenerated and verified sanitized.
- **Zero Em-Dash Rule**:
  - Audited and enforced across all source files, documentation, screens, and website components.
- **Automated Test Suite**:
  - **470 / 470 tests passed** in **0.984s** (`swift test --scratch-path /tmp/utter-build`).
- **Production Packaging**:
  - `bash scripts/build-app.sh --version=1.1.58` completed successfully.
  - Universal binary (`arm64` + `x86_64`) packaged into `build/Utter.app` and `build/Utter-1.1.58.dmg` (176MB).
- **Website Production Build**:
  - `npm run build` in `website/` completes cleanly via Vite with zero errors.

## Runtime Launch Command

To launch the current verified production bundle:

```sh
open -n /Volumes/SSD/Utter/build/Utter.app --args --open-window
```
