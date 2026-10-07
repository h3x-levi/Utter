# Utter: Architecture, Performance, Product, and Release Readiness Review

**Prepared:** 6 October 2026; implementation update 7 October 2026  
**Scope:** Repository audit prepared before the implementation follow-up below. The audit describes the pre-change baseline; runtime claims are marked unverified unless the repository records a measurement. Implementation status and verification are tracked separately below and in the roadmap.

## Implementation follow-up - 6 October 2026

The audit below records the repository as inspected. Implementation passes have since addressed several findings:

- Reworked the broader app UI, not only the pill: the dictation page now leads with readiness and the hold-to-dictate action, keeps computed usage and recent activity secondary, and labels the transcription list as recent work. Shared feature sections and settings groups use a continuous content plane with native controls rather than a grid of raised cards. Settings detail now uses a calmer type hierarchy and more practical reading width. Companion has a prominent, quiet character stage and explicit Play/Rest actions, with no streak-decay framing. See [`PRODUCT_DESIGN_REBUILD.md`](PRODUCT_DESIGN_REBUILD.md) for the design record, reference-project boundaries, completed items, and remaining visual validation.
- **7 October product IA slice:** replaced the six peer feature destinations with Capture, Library, Tools and Companion. Transcripts/Notes and Dictionary/Snippets/Transforms are now contextual segmented subpages. Transcript search/export/history and usage summary moved to Library; Capture is now readiness + shortcut + latest-result preview. Legacy `--screen` values route to the relevant new subpage, and starting a meeting opens Library → Notes. The product-direction comparison and full screen/state tracker live in [`PRODUCT_DESIGN_REBUILD.md`](PRODUCT_DESIGN_REBUILD.md). This is a first implemented IA slice, not completion of the full redesign.
- **7 October first-run/model/settings slice:** replaced the login/guest interstitial and seven-step tour with a four-step task flow; meeting permissions and the optional companion are introduced contextually. Replaced model cards with a compact model list, retry/cancel states and confirmed removal. Readiness now checks availability for the active tier, not just the bundled file. Regrouped preferences as Workflow, Speech & Models, Appearance, Privacy & Data, Diagnostics and About. Corrected misleading “no network”/Core ML/active-core diagnostics copy; audio and model downloads are described separately.
- Reduced the seven-day activity summary from seven full history scans to one pass over recent entries, and gave days stable identities so updates do not recreate every chart row. This is a source-level cost reduction; scrolling smoothness and frame-time improvements still need Instruments measurement.
- Builds of the edited source passed. A standalone `swift run --render-snapshots` attempt did **not** produce screenshots: UserNotifications requires an app bundle. The packaged renderer now regenerates the main and Settings screenshots with their navigation columns; because offscreen `NSHostingView` does not instantiate AppKit-backed List rows, its snapshot uses static matching rows and a mock window frame. That verifies content layout, not live sidebar/material/toolbar behavior. Visual inspection of a live window, appearance and size variants remain open.

- Removed simulated Google/Apple sign-in and the matching Settings action. Existing saved fake identities are discarded and treated as an established local install.
- Changed model downloads to use a pinned Hugging Face revision and per-artifact SHA-256 verification. Hashing and staging happen off MainActor; failed verification leaves any installed model untouched, and canceled/stale downloads cannot install later.
- Changed the build script to preserve permissions, preferences, caches, and user data by default. Fresh-install simulation now requires `--reset-dev-state`, only resets Utter's own grants, and keeps every timestamped backup.
- Replaced the invented 145 WPM value with average words per saved dictation, corrected README claims about accounts, model download networking, Ollama, JSON storage, companions, and build usage, and removed unmeasured zero-latency/zero-CPU/perfect-recognition marketing claims.
- Moved note and transcription-history encoding/writes to ordered utility queues. Clear-all and termination explicitly drain those queues so durability does not depend on background work surviving process exit.
- Changed the audio tap to copy each PCM block and enqueue append/VAD/meter processing instead of synchronously waiting on the buffer queue. Conversion and the initial PCM copy remain in the callback; a bounded ring buffer still needs measurement and design.
- Moved end-of-recording silence trimming and WAV wrapping onto a user-initiated worker queue; the completion returns to the main queue for existing UI callers.
- Added privacy-safe structured timing records for PCM preparation, Whisper queue wait, context access, inference, polishing, end-to-end dictation, note persistence, and history persistence. Records contain durations and counts, never transcripts or audio.
- Coalesced ReadinessMonitor's detached availability checks into one retained, cancellable task, and snapshot the selected speech language before dispatching work to the Whisper queue.
- Made delayed pasteboard restoration conditional on its change count, so it will not overwrite a newer clipboard copy made while the target application is processing Utter's paste.

**Open-source follow-up:** Added `CONTRIBUTING.md`, `SECURITY.md`, and bug/feature issue forms. Reviewed and corrected the companion/performance and model-speed claims in the README. Asset provenance is partly documented in `NOTICE` and `Sounds/ATTRIBUTION.md`; historical sprite assets still require an ownership/license audit before distribution.

**Launch/release check:** `scripts/build-app.sh --no-dmg --version=1.1.57` completed with a universal arm64 + x86_64 app executable. The bundled app signature verifies locally, its Info.plist validates, and the bundled model digest matches the catalog. The main app was relaunched with `--open-window` and observed running. This machine has no Developer ID/Apple Development identity: the app is ad-hoc signed, and `spctl --assess` rejected it for Gatekeeper distribution. The desktop approval gate rejected in-app visual inspection, so the running process could not be visually inspected through that tool.

**Verification:** `bash -n scripts/build-app.sh`, `git diff --check`, and `swift build` passed with the Command Line Tools 26.5 SDK and a temporary Clang module cache. The bundled small-model digest matches the catalog SHA-256. `swift test` compiled the 469-test target but its normal bundle-sign step failed because this ExFAT workspace emits AppleDouble `._Info.plist` files. After removing those generated sidecars and ad-hoc signing the generated test bundle, `swift test --skip-build` passed all 469 tests. This is a workspace/tooling workaround, not a source change. The Swift Testing dependency also emits deprecation warnings on this Swift 6 toolchain. P0 release signing/notarization remains open. Instrumentation now covers major speech and persistence phases; UI hitch, audio callback backlog, download verification, and hardware-specific performance still need measurement.

## Evidence key and limits

- **Observed**: directly present in source/configuration or a checked-in measurement.
- **Likely**: implementation creates a credible mechanism, but profiling is needed to quantify it.
- **Hypothesis**: requires Instruments or hardware testing.
- **Recommendation**: proposed engineering or product change.
- **Optional**: useful but lower urgency.

The repository contains roughly 38,000 lines of Swift, a Swift Package Manager app, 300+ focused tests (README reports over 340), a React/Vite marketing site, build/asset scripts, images, audio, and a bundled model. This is a static audit, not an Instruments run. Some comments preserve historical behavior and measurements; I distinguish those from current behavior. The screenshot set has been regenerated after the workspace redesign. The main and Settings marketing snapshots depict grouped navigation using static preview rows, not an interactive/live AppKit shell.

## 1. Executive summary

Utter has real engineering substance: local Whisper inference, serialized access to the non-thread-safe C context, cancellable preview inference, rolling meeting windows, atomic note writes with a previous-generation backup, a system sidebar, reduced-motion/transparency support, explicit permission explanations, and a substantial body of focused tests. A wholesale rewrite is not justified.

The central architectural issue is that good components are coordinated through one large application module and broad shared stores. AppDelegate is about 2,400 lines and owns lifecycle, windows, menus, global shortcuts, recording, meeting routing, model state, text delivery, and companion interactions. UserData, NoteStore, TranscriptionHistory, ModelStore, ReadinessMonitor, PillWindow and CompanionWindow form a graph of observable singletons. The cost is cross-feature change risk: unrelated behavior can be affected by a locally reasonable edit.

The strongest code-grounded performance explanations are:

1. **Observed, historic and mitigated:** live preview previously inferred on the entire recording every 700 ms. The source documents O(N²) work, with a 30-second clip taking about 2.7 seconds per pass on a large model. Current code caps previews at a 10-second tail, serializes them, and aborts stale inference. Preserve this invariant and add signposts.
2. **Observed:** cold model context load is recorded as 7.686 seconds on an M4 with the shipped ~190 MB model; warm rebuild after eviction is recorded as 78–93 ms. Preload hides the cold cost while warm; five-minute eviction trades memory/GPU residency against variable first-use delay after idle.
3. **Likely:** AudioRecorder converts to PCM, allocates Data, then synchronously enters a queue to append, scan VAD, compute RMS, and publish. That may threaten callback deadlines under load; the source assertion that fixed work cannot overrun is not measurement evidence.
4. **Observed:** note JSON encoding, prior-file reads, backup, and atomic writes run through a main-queue debounce. History and preferences also serialize/write synchronously. These paths scale with user data and compete with UI rendering.
5. **Observed:** ReadinessMonitor launches detached work on a two-second timer, including a system-model availability query; tasks are not coalesced or retained for cancellation.
6. **Observed:** Whisper enables GPU use but does not publish which backend actually ran. CPU thread count is a fixed formula, and model recommendations rely on broad hardware heuristics rather than current memory pressure, thermal state, or measured throughput.
7. **Likely:** the optional companion’s 30 Hz behavior/rendering and the pill’s TimelineView/Canvas may contribute SwiftUI update and GPU costs. They are opt-in or state-limited; quantify with SwiftUI Instruments before redesigning them.

Utter is a menu-bar-first, on-device **dictation app**, not a general local chat client. Whisper is the speech-recognition model. Text rewriting is optionally delegated to Apple’s Foundation Models framework when the OS and device report it available (source gates macOS 26); Utter does not ship an open-ended local LLM and checked-in code has no Ollama client. AICommands and NoteActions are phrase/action routers, not a general function-calling system. A tool registry would be premature unless the product defines model-invoked capabilities.

The urgent issues exceed visual polish: LoginView simulates Google/Apple authentication with fixed identities; optional model downloads are accepted based on URL/HTTP/size rather than cryptographic integrity; and the default build script resets permissions including Terminal, moves app data aside, prunes backups, and clears user state. These are release blockers. Public README claims also conflict with source (Ollama fallback, SQLite, procedural-only/no-PNG companions, network claims, and hard-coded WPM).

**Recommendation:** retain the local-first product and proven audio/model work. Introduce explicit recording, meeting, model lifecycle, persistence, and delivery coordinators; measure each latency phase; authenticate model artifacts; make build operations non-destructive; remove fake sign-in; and keep the native system shell while reducing dashboard density.

## 2. Current system analysis

### What the app is

- Main ASR: bundled/downloadable quantized Whisper GGML via the pinned WhisperFramework XCFramework (Speech/LocalWhisperProvider.swift and Speech/ModelStore.swift).
- Text transforms: FoundationModels.LanguageModelSession in Speech/LocalAIEngine.swift, gated by runtime availability. This is not an app-bundled local text model.
- Audio: AVAudioEngine microphone capture; macOS 14.2+ CoreAudio process tap and ScreenCaptureKit fallback for meetings.
- Input/output: NSEvent global/local monitors, CGEvent tap for consuming a hold-then-tap key, Accessibility reads, and pasteboard plus synthetic key events for text delivery.
- Persistence: JSON in Application Support and some UserDefaults; no SQL store found.
- Network: URLSession downloads optional models from mutable Hugging Face resolve/main. No app backend, general REST API, analytics SDK, or Process/NSTask shell execution found. The React/Vite website is separate from app runtime.
- Permissions: microphone, Accessibility, system audio, and Screen Recording routes; Utter.entitlements reviewed here declares audio input but not App Sandbox.

### Current architecture

~~~mermaid
flowchart TD
  OS[macOS AppKit SwiftUI AVFoundation CoreAudio AX] --> AD[AppDelegate / UtterApp]
  AD --> KM[KeyMonitor]
  AD --> AR[AudioRecorder]
  AD --> TS[TranscriptionService]
  TS --> WP[LocalWhisperProvider: serial GCD queue + C context]
  TS --> CTX[SurroundingContext / AppContext]
  TS --> POL[SentencePolish]
  POL --> FM[LocalAIEngine / Foundation Models]
  AD --> TI[TextInjector]
  AD --> MS[MeetingSession]
  MS --> SA[SystemAudioCapture / ProcessTapCapture]
  AD --> UI[NSWindow NSPanel SwiftUI]
  UI --> U[UserData singleton]
  UI --> N[NoteStore singleton]
  UI --> H[TranscriptionHistory singleton]
  UI --> M[ModelStore singleton]
  AD --> P[PillWindow state machine]
  AD --> C[CompanionWindow and behavior]
  U --> JSON[Application Support JSON]
  N --> JSON
  H --> JSON
  M --> DL[URLSession model download]
~~~

The graph describes conceptual dependencies, not enforced modules. All Sources/UtterKit code compiles into one target. Directory names do not establish dependency direction or isolation. The Utter executable is a small shim over UtterKit, which is reasonable for SwiftPM test importability.

### End-to-end flow

~~~mermaid
sequenceDiagram
  participant User
  participant Key as KeyMonitor
  participant App as AppDelegate
  participant Audio as AudioRecorder
  participant Whisper as LocalWhisperProvider
  participant Polish as SentencePolish
  participant Target as Frontmost app
  User->>Key: hold configured key
  Key->>App: main-queue start callback
  App->>Audio: start AVAudioEngine
  App->>Whisper: enqueue warm-up
  loop recording
    Audio->>App: coalesced level updates
    App->>Whisper: optional bounded preview
  end
  User->>Key: release key
  Key->>App: main-queue stop callback
  App->>Audio: stop, trim, WAV encode
  App->>Whisper: parse samples and infer
  Whisper->>Polish: formatted transcript and optional context
  Polish-->>App: polished or original
  App->>Target: pasteboard plus synthetic Cmd-V
~~~

TranscriptionService adds optional preceding-text and per-app tone context, and may make a second Foundation Models call before delivery. End-to-end wait time is not just Whisper decode. Pill state is often updated before expensive work, which is useful for responsiveness.

Meeting capture reuses the one microphone recorder/transcriber while capturing system audio separately. MeetingSession consumes rolling windows and labels mic and “Others” turns. ProcessTapCapture attempts process-targeted capture on supported OS routes; SystemAudioCapture selects a ScreenCaptureKit fallback based on capability/permission. Privacy.md accurately states remote participants are not individually identified and consent remains the operator’s responsibility.

### State/context

State is divided among AppDelegate flags, PillStateModel, UserData, NoteStore, TranscriptionHistory, ModelStore, ReadinessMonitor, MeetingSession, CompanionBehaviour, and UserDefaults. There is no single typed session snapshot containing capture mode, destination, model state, permissions, and current operation. TranscriptionService reaches into global preference/context state rather than receiving an immutable request. LocalWhisperProvider serializes C calls, but reads UserData.shared.selectedLanguage from its worker queue. Snapshot UI-owned values before hopping off MainActor.

Login state is persisted, but LoginViewModel assigns fixed sample identities and delayed callbacks. There is no OAuth provider flow, AuthenticationServices integration, token handling, account backend, or credential store. This is false sign-in behavior, not a harmless visual placeholder. Remove it or implement actual authentication with an explicit product/privacy rationale.

### Dependencies and coupling

- AppDelegate constructs and coordinates most app services/windows.
- Screens read shared singleton stores directly.
- TranscriptionService depends on concrete LocalWhisperProvider, UserData, SurroundingContext, AppContext and SentencePolish.
- AICommands, SentencePolish, note actions and companion memory directly call static LocalAIEngine.
- ModelStore combines catalog, URLSession, disk location, preference, download progress and model selection.
- AudioRecorder combines engine lifecycle, conversion, buffering, VAD, level meter, silence trim and WAV encoding.
- NoteStore, UserData, TranscriptionHistory and CrashReporter implement persistence differently.
- CompanionWindow/CompanionBehaviour/SpritePack cover panel placement, system observation, behavior, assets, and rendering.

There are no compile-time module cycles because all sources live in one target; there are conceptual cycles through singleton state and notifications. God objects by responsibility include AppDelegate, UserData, AudioRecorder, CompanionWindow, SpritePack, PillWindow, and DesignTokens.

## 3. Architectural assessment

### Strengths to preserve

- Local-first privacy contract and explicit optional model download.
- Focused folders and pure helpers.
- Whisper context serialization, preview cancellation, and idle eviction.
- Bounded meeting windows and separated microphone/system streams.
- Atomic notes/history writes, note previous-generation backup, and malformed-data salvage.
- AppDirectory centralizes location, migration, and owner-only directory mode.
- Sprite pack paths are validated against traversal.
- Extensive deterministic tests cover behavior, timing, geometry, persistence, and hostile pack files.
- Current sidebar is native AppKit split/sidebar/list rather than a fake HStack sidebar; it has fallback paths for older macOS.
- Reduced-motion/transparency, system appearance, permissions, and window sizing have deliberate handling.

### Weaknesses, evidence, replacement, trade-off

1. **AppDelegate orchestration hotspot.** It owns lifecycle, windows, global monitors, permissions, dictation, meeting and text routing, telemetry, and error presentation. Change collisions and invalid state combinations become more likely as features grow. Extract DictationCoordinator, MeetingCoordinator, WindowRouter, PermissionCoordinator, and a small composition root. Trade-off: new interfaces and migration work; retain one integration-testable vertical flow at a time.
2. **Singleton-connected presentation.** Views reach shared stores, so tests/previews need global setup and business decisions cannot be injected cleanly. Inject feature view models and coordinator interfaces. Trade-off: initializer wiring, offset by predictable ownership.
3. **One package target.** Folders are organizational only. Add targets only when a coherent component can be independently built/tested and dependency direction is stable. Avoid one target per screen.
4. **Actor inconsistency.** Some observable state is MainActor-bound and UserData is not; worker code reads it. Isolate presentation state and cross actor boundaries with immutable Sendable values.
5. **Static/concrete services.** Appropriate for pure helpers, but model, persistence, audio, and input need fakeable boundaries for integration/performance tests. Add protocols where substitution matters, not universally.
6. **Uneven errors.** Rich typed errors coexist with try?, print, and nil collapse for multiple stop failures. Preserve internal typed category/context and expose concise user-safe UI copy.
7. **Sensitive context option.** SurroundingContext reads up to 320 preceding characters, gated off by default, refuses secure fields, and says it is never stored/logged. Keep that boundary explicit in UX, request construction, and diagnostics.

## 4. Performance analysis

### Model size is not application performance

Fitting weights in RAM only says they can be resident. It does not guarantee fast cold page-in, low working memory, available unified memory for other apps/GPU, supported backend activation, fast feature encoding/decoding, absence of GPU/CPU synchronization, safe audio callback timing, or low Swift/UI/persistence overhead. Total latency includes cold context creation, PCM conversion, feature encoding, decoder tokens, result extraction, optional text-model polish, UI publication, and text delivery. Model size alone is not a performance diagnosis.

### CPU/GPU and inference

**Observed:** LocalWhisperProvider has one serial DispatchQueue protecting a non-thread-safe whisper context. It sets use_gpu=true and n_threads to activeProcessorCount minus two, clamped 1...8. Comments say Metal and Core ML are compiled in, but the expected Core ML encoder model is not shipped; code filters the failed Core ML model message and assumes Metal remains useful. No actual backend status is surfaced. SpeechModelCatalog extrapolates speed from M4 results and uses broad core/RAM buckets.

**Likely:** the thread formula can be poor for low-core, thermally limited, Intel, or other backend configurations. A 12%-of-physical-RAM fit threshold ignores current pressure and other apps. Measure per model/device/backend before setting thread defaults or recommendations. Keep GPU-enabled as a request, not proof of GPU inference.

**Observed:** final inference is synchronous native work on the serial queue; preview abort is explicit because cancelling the Swift task alone does not stop C inference. Model changes invalidate/reload through notifications and contend with inference on that queue. Add a scheduler with final > preview > prewarm priorities and serialize model teardown/load.

**Observed:** stopRecording detaches a full Data snapshot, scans/copies PCM to Int16 for silence trimming, creates trimmed Data and WAV before completion. This may run on the UI-sensitive path and scales with recording duration. Move finalization to a worker after safely swapping out the recording buffer.

**Observed:** WAV parsing allocates a Float array before enqueuing whisper. It creates another audio representation; there is no explicit worker executor around that preprocessing. Profile thread and allocations and move it into the bounded inference operation where safe.

### Preview / model load

Current preview behavior is materially better than the documented historic defect: bounded 10-second tail; 900 ms initial wait; sequential work; 700 ms gap; no bias/polish; abort when stale/stop. It remains duplicate inference and an already-running preview can occupy the serial queue ahead of a final request. Add final-job preemption and measure worst-case preview service time on the largest tier and lowest-memory supported Mac.

The recorded cold M4 load is 7.686 s, warm rebuild 78–93 ms. Startup preload hides cold load until eviction/model switch. Five-minute eviction is a valid trade-off because comments record memory and Metal-residency costs, but distinguish model file available, context resident, and request processing in UI state. Re-evaluate eviction against measured RSS, GPU activity, swap, and first-use p95; do not treat five minutes as universal.

### Audio callback and memory

AudioRecorder converts AVAudioBuffer to 16 kHz mono Int16, allocates a Data block, synchronously enters a queue to append, scan VAD, compute RMS in Double, then schedules UI publication up to 30 Hz. Synchronization corrected real races, but synchronous handoff/dynamic allocation inside an audio callback is a risk until deadline/dropout data proves otherwise. Use a preallocated bounded ring/SPSC buffer and minimal callback work; no logging, file I/O, actor calls, or blocking waits from callback.

Meeting windows consume already-transcribed bytes. Still measure long-session high-water memory with two streams, previews, companion and a large model. Track process physical footprint, dirty memory, swap, buffer bytes, model context, temporary PCM arrays, Metal resources, and memory pressure. Avoid inferring memory safety from file size.

### Main-thread candidates

- NoteStore write debounce fires on main and encodes/reads/backs up/writes full notes.
- UserData.save builds a large dictionary, JSON-bridges custom commands, pretty-prints, writes synchronously.
- TranscriptionHistory serializes up to 1,000 full transcripts and writes synchronously.
- AudioRecorder stop snapshot/trim/WAV work may block UI.
- TextInjector snapshots every pasteboard item/type/data, replaces clipboard, calls usleep(2_000), posts a key, then restores after 100 ms. Make this an async delivery transaction; handle clipboard changes during the interval.
- ReadinessMonitor spawns detached work every two seconds without coalescing.
- Pill timer publishes elapsed state every 100 ms; audio level publishes up to 30 Hz. Scope observation to meter/status subviews and stop when hidden.
- Companion behavior ticks 30 Hz when active; pill has TimelineView/Canvas animation. Measure update fan-out with it on/off.

The code already has useful protections: separate PillLevelSignal, coalesced level publishing, companion idle ticker shutdown, cached readiness/grouping, native sidebar and animation preferences. Preserve these.

### Required profiling

There is no trace in the repository. Measure hotkey-to-visible state; engine start; callback duration/dropouts; stop-to-PCM; WAV decode; context cold/warm; encoder; decoder first segment/final; polish; command/tool routing; text insertion; persistence flush; first window appearance. Compare cold/warm page cache, tier, preview, companion, meeting, Intel/Apple Silicon, memory pressure, external display, battery mode, and reduced transparency.

## 5. AI/model analysis

### Two different model systems

SpeechModelCatalog lists Base (~57 MB download / 180 MB peak estimate), Small (~181 / 395 MB), Medium (~514 / 815 MB), Turbo (~547 / 718 MB); source says only Small is bundled. Foundation Models is a system capability, not part of these model files. The app creates a new Foundation Models session per rewrite; for one-shot transforms this is reasonable. Session reuse should only be adopted if a real multi-turn or prefix reuse need is measured, since reuse can retain context the app does not intend to share.

README says “offline heuristics or local Ollama” fallback; no Ollama implementation was found. README says SQLite/JSON though stores found are JSON. It says companion art is code-only/no PNG, while SpritePack loads PNG and CodePixelCat still has active code paths. Correct claims before public release.

### Request/result contract

Use immutable Sendable request/result types containing audio ownership, model ID, language, vocabulary snapshot, capture mode, explicit optional context, request ID, segments, timings and error categories. Emit stage/partial/completed events. One scheduler actor manages priority and context generation; one worker serializes C context use. Capture language/preferences before worker handoff. Distinguish model file available, context resident, backend selected, and request phase.

Meeting timestamps/turn segmentation are a good purpose-specific boundary. Source forces English even with multilingual Turbo; comments state English-only policy. Either communicate this clearly or define supported-language behavior and tests; “multilingual model” must not imply multilingual product support.

## 6. UI/UX assessment

### Good foundations

Utter has a clear desktop utility role, floating pill, keyboard-first paths, explicit route states, native AppKit sidebar and toolbar migration, resizable windows, appearance support, and reduced motion/transparency. The current architecture direction is appropriate for macOS.

### Current weaknesses

- Dashboard/Notes screenshots show old web-dashboard conventions: large KPI cards, stacked bordered panels, pill badges, and a large blank editor. Refresh them from a released build; don’t publish screenshots with empty state or fabricated values.
- Dashboard prioritizes metrics/readiness panels over primary dictation. Make capture status, shortcut help, model readiness, and recent history secondary/searchable.
- TranscriptionHistory.averageWPM returns literal “145 WPM” whenever history is nonempty. It is not computed. Remove or calculate honestly with clear method.
- Seven custom glass/color themes, materials, and tokens create compatibility burden. Prefer system appearance, one accent and modest customization unless theme usage justifies the cost.
- Multiple modes/shortcuts (hold, double tap, chords, note/memory, voice actions, meeting offers) require onboarding to teach one main gesture first, then optional modes.
- Pill must clearly show destination (frontmost app vs note vs memory vs meeting) and whether preview is provisional.
- Readiness screenshots mix “Getting ready” with “model missing” and “AI unavailable”. Separate microphone permission, Whisper file/context, optional Foundation Models, and download state.
- Use semantic typography and larger text/high contrast/VoiceOver testing; reserve fixed point sizes for compact meters/decoration.

## 7. macOS design recommendations

Keep NSSplitViewController, system toolbar/titlebar, native sidebar/list focus, menu-bar item, proper windows/panels, and native controls. Use system content material; treat macOS 26 glass as progressive enhancement with tested fallbacks to 13.3+. Apple’s current HIG supports succinct adaptable sidebars and deliberate contextual toolbars.

**Main window:** toolbar leading sidebar toggle/title, only current-screen actions trailing/center; sidebar Dictation, Notes, Dictionary, Snippets, Transforms, optional Companion. Settings stays in standard Settings/menu. Dictation screen: concise ready/model state, one shortcut lesson, recent searchable history. Notes: native list/editor split, title/source, export/share, explicit meeting control with permissions/consent. Settings: General, Speech, Shortcuts & Permissions, Privacy, Companion, About/Diagnostics using native forms.

**Menu bar:** immediate actions, configured hotkey, open workspace, settings/setup/quit. **Pill:** small idle state; visible recording indicator and destination; phase-specific processing; provisional preview; actionable error/retry. Motion must be interruptible and honor Reduce Motion. **Meeting start:** explicit streams, destination, permission and consent info; detection can offer but never auto-start. **Text transforms:** named operation, source/selection, destination confirmation.

Use semantic colors, SF Symbols, one accent, standard materials, and custom surfaces only to communicate hierarchy. Avoid web-dashboard aesthetics.

## 8. Cross-hardware compatibility

**Observed:** Device.current reads architecture, CPU, memory, free disk; recommendations use buckets. Some panels use their own screen or saved display, but main/auxiliary paths use NSScreen.main and presentAuxWindow has a 1440×900 fallback. Sprite renderer uses environment scale in parts; window tests exist.

**Risks:** main screen is not always correct for existing panel; hard-coded fallback assumes resolution; physical RAM does not reflect unified-memory pressure, battery, thermal state, Metal capability, or other apps; retina points differ from backing pixels; refresh is variable (60/120 Hz examples are not universal); OS feature floors vary across 13.3, 14.2 and 26; Intel and Apple Silicon backend behavior must be separately verified.

Use window.screen/target-screen visibleFrame and point geometry; respond to screen changes; clamp restored positions after display disconnect. Create a DeviceCapabilities snapshot of facts (OS, architecture, Metal, memory pressure, capture route, display rate), use it for initial model recommendation only, and let users choose. Do not silently switch model mid-workflow.

## 9. Proposed architecture

~~~mermaid
flowchart TB
  subgraph Presentation
    Workspace[Workspace / Notes / Settings]
    Pill[Pill panel]
    Menu[Status item + commands]
  end
  subgraph Application
    Dictation[DictationCoordinator]
    Meeting[MeetingCoordinator]
    Notes[NotesCoordinator]
    Lifecycle[ModelLifecycleCoordinator]
    Transform[TextActionCoordinator]
  end
  subgraph Domain
    Session[Capture session and destination]
    Speech[Speech request/result/stage/error]
    Tool[Optional typed tool contract]
  end
  subgraph Infrastructure
    Audio[AVAudioEngine / CoreAudio]
    Whisper[Whisper worker and scheduler]
    Foundation[Foundation Models adapter]
    Repo[Persistence actor]
    Input[Accessibility / pasteboard / CGEvent]
    ModelRepo[Verified model catalog/downloader]
  end
  Workspace --> Dictation
  Pill --> Dictation
  Menu --> Dictation
  Workspace --> Notes
  Workspace --> Lifecycle
  Dictation --> Session
  Dictation --> Audio
  Dictation --> Whisper
  Dictation --> Input
  Meeting --> Audio
  Meeting --> Whisper
  Notes --> Repo
  Lifecycle --> ModelRepo
  Transform --> Tool
  Transform --> Foundation
~~~

Use feature workflows over a small domain/infrastructure core. Presentation → Application → Domain; Infrastructure implements contracts owned by application/domain. Translate AppKit/C types into Sendable values at boundaries.

Initially retain one SwiftPM target while extracting cohesive files and injection points. Later consider small targets: UtterDomain, UtterAudio, UtterSpeech, UtterPersistence, UtterApp. Keep target count low, especially while binary framework/resource packaging is fragile. Do not create targets for each screen.

## 10. Proposed folder structure

~~~text
Utter/
├── Package.swift / Package.resolved
├── README.md PRIVACY.md LICENSE NOTICE CHANGELOG.md
├── CONTRIBUTING.md SECURITY.md
├── docs/
│   ├── ARCHITECTURE.md PERFORMANCE.md PRIVACY-DATA-FLOW.md RELEASE.md
│   └── decisions/                 # architecture decision records
├── Sources/
│   ├── UtterApp/                  # AppKit lifecycle, composition root
│   ├── UtterDomain/
│   │   ├── Capture/ Speech/ Notes/ Tools/
│   ├── UtterAudio/                # capture, conversion, ring buffer, routes
│   ├── UtterSpeech/               # Whisper adapter, scheduler, catalog
│   ├── UtterPersistence/          # repositories, formats, migrations
│   └── UtterFeatures/
│       ├── Dictation/ Notes/ Meetings/ Transforms/
│       └── Companion/ Settings/
├── Resources/                     # Info, model manifest, licensed sounds/art
├── Tests/                         # Domain Audio Speech Persistence Integration UI Performance
├── scripts/                       # safe explicit build/sign/release actions
├── website/                       # separate marketing product
└── Assets/                        # screenshots and marketing artwork only
~~~

Feature-first folders keep workflow context together; stable domain/infrastructure boundaries control dependencies. Runtime resources, source-generation inputs and marketing assets should be distinct. Contributor/agent context benefits more from focused files, dependency rules, typed interfaces and verified commands than a deep taxonomy.

## 11. Responsibilities

- **UtterApp:** construct services/coordinators once; bridge AppKit callbacks; own activation/window routing.
- **Dictation:** capture intent, destination, pill presentation, stop/cancel/failure flow; never own Whisper pointers.
- **Audio:** engine lifecycle, normalization, bounded PCM buffer, VAD/meter events, meeting route selection; no SwiftUI writes from callback.
- **Speech:** verified model catalog, context lifecycle, inference scheduler, cancellation, stages and timings.
- **Input:** narrow SelectionReader/TextDelivery contracts with permissions, timeout/error status and safe pasteboard semantics.
- **Notes:** note rules/editor state through persistence repository; disk I/O away from MainActor.
- **Transforms:** typed request, Foundation Models adapter, output validation; no side effects from arbitrary text.
- **Companion:** optional isolated feature with own update clock, panel lifecycle and sprite-pack validation.
- **Persistence:** settings/notes/history/companion formats, migrations, backups, serial writes and recoverable errors.
- **Diagnostics:** structured privacy-safe logs, signposts and local export.
- **Resources:** model manifest/hashes, sounds and art with provenance/licenses.

## 12. Tool/API architecture

**Challenge:** current source contains no general tool/function system. AICommands maps finite spoken phrases to rewrites; NoteActions maps UI actions to prompts. LanguageModelSession is created without tools. A giant router today would be unnecessary complexity.

If concrete model-invoked capabilities are added, separate:

1. Tool definition/schema: versioned ID, typed arguments/result, purpose, side-effect class, permission/deadline.
2. Tool implementation: narrow adapter such as SearchNotes/CreateNote; validate all inputs.
3. Router/orchestrator: allow-list, decoding, authorization, confirmation for destructive/external effects, cancellation, deadlines, bounded concurrency, idempotent retries.
4. UI: render requested/running/succeeded/failed/confirmation via safe DTOs.

~~~mermaid
sequenceDiagram
  participant Model
  participant Router as Tool Router
  participant Policy as Permission/Confirmation
  participant Tool as Typed Adapter
  participant Store as Repository or OS
  participant UI
  Model->>Router: ToolCall with schema version and arguments
  Router->>Router: decode, validate, deadline
  Router->>Policy: authorize effect and scope
  Policy-->>UI: confirmation if required
  UI-->>Policy: user decision
  Router->>Tool: execute validated request
  Tool->>Store: narrow operation
  Store-->>Tool: typed result/error
  Tool-->>Router: bounded result DTO
  Router-->>Model: result
  Router-->>UI: progress/result/error
~~~

Do not expose arbitrary shell execution, unrestricted filesystem access, text injection, or meeting capture as model-callable tools. For Foundation Models, use Apple typed tool APIs behind availability gates and confirmation for side effects.

For existing transforms, use TransformRequest(source, instruction, destination, context policy) → TransformResult or typed failure (unavailable, cancelled, invalid output, context limit). Text insertion should target the app/field captured at recording start or ask the user; current path can paste into whatever app is focused when model work completes.

## 13. Concurrency model

- MainActor owns AppKit, SwiftUI, windows and presentation state.
- Audio callback performs bounded allocation-free handoff to preallocated storage; no blocking queue, logging, file work, actor hop, or UI publication.
- Audio worker owns AVAudioEngine and conversion; bounded async events coalesce meter/preview values.
- InferenceScheduler actor handles admission/priority; a dedicated serial worker performs synchronous C calls.
- Final inference outranks preview; preview outranks prewarm. Cancel stale preview on stop/model switch and abort native work through current callback.
- Structured tasks belong to capture/meeting sessions and cancel on stop/close/termination. No untracked detached work per timer tick.
- Immutable Sendable snapshots carry model tier, language, vocabulary, capture mode and explicitly opted-in context. Never read UserData from worker queues.
- QoS should reflect capture/final work without starving UI/system; do not assume interactive QoS suits long inference.
- Model switch/delete/context teardown/load must serialize with active inference; don’t unlink an in-use model.

ReadinessMonitor’s per-refresh Task.detached is a direct coalescing/cancellation candidate. ModelStore already retains URLSession task handles; add integrity verification, install atomicity, timeout/resume policy and partial cleanup.

## 14. State management

Represent capture as a typed state machine:

~~~text
idle
 → preparing(destination, model status)
 → recording(sessionID, mode, destination, start)
 → transcribing(sessionID, stage)
 → transforming(sessionID, operation)
 → delivering(sessionID, destination)
 → completed | failed(recoverable error) | cancelled
~~~

One coordinator owns transitions. Model state separately tracks file availability, download, context loading/residency and failure. Permission state is separate. CaptureContext snapshots mode, destination, target app identity, optional selection and opt-in preceding text. This prevents focus or singleton changes from silently changing output destination.

Split observable models by feature/update rate. A 30 Hz meter should invalidate only a meter. @Observable may improve dependency granularity if compiler/deployment constraints permit, but it is not a mandatory rewrite; measure first.

## 15. Performance strategy and budgets

### Instrument first

Add OSLog/OSSignposter intervals with request ID and names: CaptureStart, AudioCapture, PreviewInference, StopAndSnapshot, PCMDecode, WhisperContextLoad, WhisperEncode, WhisperDecode, SentencePolish, ToolExecution, TextDelivery, PersistenceWrite, WindowShow, UIStateTransition. Never signpost audio, transcripts, prompts, selected context, or note text.

| Metric | Definition | Acceptance |
|---|---|---|
| Hotkey acknowledgement | event → first recording UI state | Next practical render turn; no disk/model work in callback; capture p50/p95 |
| Audio callback health | callback duration/dropout vs measured audio quantum | Zero app-owned overruns/dropouts during 30-minute capture in supported matrix |
| Cold context load | start → context ready | Report per model/backend; never block launch; existing M4 comment says 7.686 s, not universal |
| Warm transcription | request admission → first segment/final by audio duration/model | Establish controlled p50/p95 per device before numeric product SLO |
| Preview | start → displayed partial | Must not queue over final request; final wait bounded by currently executing preview |
| Text delivery | final text → insertion and clipboard restore | No main-thread sleep; measure paste/AX transaction |
| UI | view-body/hitch metrics | Frequently hit bodies below 1 ms where practical; track hitches against actual frame interval (8.3 ms at 120 Hz and 16.7 ms at 60 Hz are examples) |
| Idle | 10-minute CPU/GPU/wakeups/footprint | No app-owned repeating work while hidden unless explicitly enabled; set numeric ceiling after baseline |
| Meeting memory | peak footprint over 60-minute capture | Bounded, not linear with duration |

The 1 ms view-body marker corresponds to Apple SwiftUI Instruments guidance for red updates above 1,000 μs; it is a hot-path diagnostic bar, not an absolute for every view. Cold model load is allowed to take time while app window/menu remains interactive.

### Order of work

1. Add signposts and repeatable traces.
2. Move persistence/audio finalization off main; remove blocking sleep from delivery.
3. Replace callback sync/allocation with bounded ring-buffer handoff.
4. Enforce final-over-preview priority.
5. Measure backend/thread/model recommendations across hardware.
6. Profile SwiftUI update fan-out and companion/pill rendering.
7. Revisit eviction against footprint, GPU activity, swap and first-use p95.

## 16. Stability strategy

- Typed state machine prevents UI saying “recording” after audio start failed; current code documents this old failure class and checks result now.
- Scope resource ownership for AVAudio taps, aggregate/process taps, event taps, run loops, native model context, tasks and download staging.
- Meeting fallback must explain partial capture/permission state; never claim dual-stream if only mic is live.
- Distinguish no speech, too-short capture, conversion, engine start, model missing/load, inference, cancellation, delivery and persistence errors.
- Persistence failures for the only note copy must be visible and leave previous data intact. try? is only for genuinely best-effort secondary work.
- Retry only transient download/network failure with backoff/cancellation; never retry bad hash/parser as transient.
- AX force casts follow type-ID checks but can be replaced with typed helper results; audit unwraps reachable from user data.
- Termination should stop capture/hotkeys, cancel previews/downloads, bounded-flush notes, then free C context safely. shutdown() queue.sync protects context but may wait on main.
- Keep custom crash report subordinate to macOS symbolicated reports; validate signal behavior per architecture.

## 17. Observability

Replace emoji print with Logger subsystem/category: app.lifecycle, audio.capture, speech.lifecycle/inference, model.download, input.delivery, persistence, meeting, companion. Mark strings private. Log durations, tier, phase, route, status/error category and counts only. Never log transcript, note, selected text, prompt, clipboard, audio, token or identifying file path.

Add histograms for cold/warm load, preprocessing, encode/decode, polish, delivery, download, persistence, callback duration, queue wait, preview cancellation, memory footprint, hitches and idle wakeups. Diagnostic export should be user-triggered, allow-listed, locally reviewed and contain no transcript/audio. Optional profiling should be bounded, saved locally, and deletable.

## 18. Testing strategy

Current deterministic tests are a strength. Keep simulated clocks and real temporary files for untrusted formats.

- **Unit:** state transitions/cancellation; destination snapshots; hotkey policy; PCM/WAV malformed chunks; VAD; segmentation; model capability/recommendation; hash manifest; transform validation; migrations; privacy redaction; permissions.
- **Integration:** fake audio → buffer → worker result; delayed preview cancelled by final job; staged download/corrupt hash/cancel; JSON migrations/backup/write failure; pasteboard restore/focus change; meeting dual-stream accounting; success/no speech/permission/model failure/cancel flows.
- **UI:** first-run denied permissions/regrant; pill destination/VoiceOver; download progress; sidebar keyboard/collapse; Notes split; appearance, high contrast, reduce motion/transparency; smallest window; external displays; activation policy/multiple windows.
- **Performance:** launch separate from model load; cold/warm model; 5/15/30-second clips; first segment/final; preview on/off; model switch; 30–60-minute meeting memory; save growth; idle CPU/wakeups; memory pressure, battery and refresh.
- **Compatibility:** minimum/new macOS, Intel if supported, base Apple Silicon/lowest RAM, Pro/Max/Ultra, low disk, mixed-scale displays, thermal/power states, denied/newly granted permissions.

Do not assert one absolute latency across uncontrolled hardware. Compare repeated distributions on controlled runners. Never commit user audio; fixtures should be synthetic or consent-cleared.

## 19. Security and privacy

PRIVACY.md documents local JSON under Application Support, owner-only directory, no audio written, optional model download, and sensitive meeting capture. Files are plain text/JSON, not app-encrypted. The reviewed entitlement file has audio input only; no App Sandbox entitlement is present. Accessibility and audio capture are privileged integration points.

**Critical risks:**

1. **Downloaded model integrity:** source explicitly acknowledges mutable resolve/main and size-only validation before native GGML parser. Pin immutable artifact revision and per-model SHA-256, verify before atomic install, validate header/metadata/content size, retain old valid file on failure.
2. **Fake authentication:** remove or replace with actual secure flow; local flags and fixed names are not authentication.
3. **Target drift:** revalidate captured app/focus before delayed paste or require user confirmation.
4. **Pasteboard:** snapshot copies every type/data to memory and restores after 100 ms. Handle large data, user clipboard change during delay, target timeout, app quit and restore failure without overwriting newer clipboard contents.
5. **Custom prompts:** user data; keep bounded and local; model output never performs side effects by itself.
6. **Supply chain:** Whisper framework checksum is good. Audit signed provenance, architecture slices, release notices and build flags. Upstream had releases newer than v1.9.2 as of this audit; evaluate deliberately.
7. **Permissions:** request at relevant feature use, explain distinct routes, never imply permission needed for unrelated dictation.
8. **Data reset:** build/reset operations must not silently destroy local data or permissions.
9. **Sandboxing:** evaluate hardened runtime/Developer ID distribution and sandbox feasibility separately. Global hotkeys, cross-app injection and audio capture may constrain it. Never claim sandboxing until signed artifact entitlements are verified.

Meeting capture records other people and does not notify them. Keep manual opt-in, visible active recording and immediate stop. Call detection only offers. Put consent guidance in start UI as well as privacy docs.

## 20. Dependency strategy

| Dependency | Role | Recommendation |
|---|---|---|
| Apple frameworks | Native UI, audio, OS integration, notifications, Foundation Models | Keep; capability-gate newer APIs and test fallbacks |
| whisper.cpp XCFramework v1.9.2 | Offline speech recognition, checksummed SPM binary | Keep for now; upstream lists newer v1.9.4. Deliberately test API/model accuracy, Metal/Core ML flags, arm64/x86 slices, minimum OS and license before upgrade |
| Swift Testing 0.99.0 exact | Test framework for author’s local command-line toolchain | Exact pin avoids silent drift. Move to toolchain-bundled Testing when CI/contributor baseline permits; define supported Swift/Xcode versions |
| Pillow >=10,<13 | Build-time artwork/icon/DMG generators | Keep build-only if scripts remain; document Python/venv and consider lock |
| React/Vite/Tailwind/Three/R3F/GSAP/Framer/ShaderGradient | Website only | Keep separate; justify bundle/motion cost; never link into native runtime |
| SQLite/GRDB/CoreData/SwiftData | None found in app | Do not add by default. JSON remains human-recoverable; move only if measured need |
| Analytics/crash SDK/updater | None found | Keep absent unless explicit user value/privacy review; document network behavior if updater added |

Package.swift’s remote Swift Testing workaround is environment-specific. Supported macOS CI should become canonical, then remove the extra dependency when practical.

## 21. Open-source readiness

**Good:** Apache license, NOTICE, sound attribution, privacy page, changelog, install/build docs, screenshots, model source notes, tests, DMG guide.

**Gaps:** no .github workflow/templates found; no CONTRIBUTING.md, SECURITY.md or Code of Conduct; no CI/build/test/lint/release automation found; README conflicts with current code; model/art provenance should be discoverable; distribution script says a development/ad-hoc signed unnotarized DMG will be blocked on other Macs.

Add workflows for Swift build/test, website build, shell/static checks, checksum validation, architecture compile matrix, and protected-tag signing/notarization. Add security disclosure, contribution guide, bug/performance/compatibility forms, and PR checklist for data/privacy changes. Releases should include signed tags, changelog, SBOM/license notices and app/model checksums.

**Build script is a public clone risk:** normal build resets TCC grants including Microphone/Accessibility and Terminal, resets preferences, moves app data, prunes old backups, clears caches/saved state, writes version state, then builds. A build must not mutate another application’s grants or user backups. Make build non-destructive by default; split package, sign, notarize, and reset-dev-state. Reset should be separate, narrowly scoped to Utter, explicit, and never prune backups implicitly.

## 22. UI/UX redesign specification

**Primary journey:** install → one clear privacy/permission explanation → grant needed access → included model ready → learn one shortcut → dictate into current field → clear completion feedback. Introduce optional modes after first success.

- Keep system toolbar/sidebar/window. New main navigation: Capture, Library, Tools, Companion. Library subpages: Transcripts, Notes; Tools subpages: Dictionary, Snippets, Transforms. Settings stays in a dedicated preferences window.
- Capture screen: concise readiness, shortcut guidance, a small last-result preview; history/search/export and activity metrics live in Library, not on the primary action screen.
- Notes: native list/editor split, title/source, export/share, explicit meeting control, durable autosave.
- Model: compact toolbar menu for tier, download status, estimated memory, ready/resident; no standalone chooser unless multiple options matter.
- Settings: native Form controls in General, Speech, Shortcuts & Permissions, Privacy, Companion and About.
- Pill states: idle compact; recording has visible indicator and destination; processing has phase; preview visually provisional; failure has actionable next step.
- Meeting: explicit source/permission/destination/consent and stop action; detection offers only.
- Text transforms: named operation, source/destination, optional preview/undo; no invisible replacement.
- Use semantic colors, SF Symbols, one accent, standard materials. Motion is interruptible and honors Reduce Motion; stop hidden/asleep timelines.

## 23. Migration strategy

This app has user data, model choice, TCC grants, JSON formats, folder aliases and multi-mode workflows; migrate by vertical slices.

1. Correct truth/safety: remove fake auth; correct public claims/screenshots; split build reset; add model hashes. Preserve bundle/data identity.
2. Add signposts and record performance baselines before optimizing.
3. Define typed capture request/result/destination/error and inject into TranscriptionService without behavior change.
4. Extract DictationCoordinator; move ordinary dictation, note, hands-free, then memory routing one path at a time.
5. Move audio finalization/persistence off main; replace callback queue sync with bounded handoff; add cancellation tests.
6. Add inference scheduler/model state; coordinate context switch/delete/load.
7. Preserve JSON through versioned migrations; retain note backup/salvage.
8. Add module targets only after boundaries stabilize; Companion is a plausible optional feature boundary.
9. Simplify UI and regenerate screenshots after native shell is validated.
10. Release only after clean-machine install, upgrade/data migration, notarization and docs match artifact.

## 24. Prioritized roadmap

Status legend: **[x] Done** in this implementation pass; **[~] Partial** (some scope landed, material work remains); **[ ] Open**. “Done” means code changed and static/build evidence exists; hardware/release validation is called out separately. P3 items are intentionally deferred ideas rather than release requirements. The audit is not a claim that the application is production-ready.

### P0 - Critical

1. [x] Remove fake OAuth or implement genuine secure sign-in. Removed simulated Google/Apple flows; local-first behavior preserves established onboarding state.
2. [x] Pin immutable speech model artifacts and verify SHA-256 before install. Pinned revision and all catalog hashes; install is staged/verified before atomic replacement.
3. [x] Make build non-destructive; never reset Terminal, prune backups, or move user data during normal build. Reset is now opt-in and scoped to Utter; backups are retained.
4. [~] Correct false README claims, fake WPM, network wording and screenshots. README and WPM are corrected and current packaged preview images were regenerated; real-window screenshots and live appearance/size review remain.
5. [~] Establish supported architectures, Developer ID signing/notarization and clean second-Mac Gatekeeper validation. Build script now compiles arm64 and x86_64 and verifies a universal executable; Intel hardware validation, Developer ID signing, notarization, and Gatekeeper acceptance on a clean Mac remain open. The current ad-hoc bundle is locally signature-valid but rejected by `spctl`.
6. [~] Add phase-level latency instrumentation. Speech/inference and persistence phases are logged with privacy-safe durations/counts; UI hitch, audio callback backlog, model download, startup, and hardware baseline measurement remain.

### P1 - High

1. [~] Move file serialization/writes and audio finalization off MainActor. Note/history writes and end-of-recording trim/WAV work moved off main; remaining UserData writes and measurement need review.
2. [~] Replace allocation/sync audio callback with bounded ring-buffer handoff. Removed synchronous queue wait; current tap still converts/copies data and uses asynchronous handoff, without a bounded ring buffer or measured backpressure policy.
3. [ ] Add final-over-preview scheduler priority and context lifecycle state. No explicit priority scheduler/lifecycle state was introduced.
4. [~] Replace cross-feature booleans with typed capture state and immutable destination/context. Selected language is snapshotted before queue dispatch; broad capture/destination state remains to be modeled.
5. [ ] Scope high-frequency meter/pill state; profile companion. Not addressed or profiled in this pass.
6. [x] Fix fake WPM and simplify readiness/Home surface. WPM is derived from saved dictations, readiness checks coalesce, and the main workspace now leads with dictation readiness while computed usage/activity is supporting context. The visual implementation builds; packaged screenshot, accessibility, narrow-window, and multi-display validation remain.
7. [~] Capture intended target app and make pasteboard safe against focus/clipboard changes. Delayed restore respects clipboard change count; destination-app capture/focus behavior remains.
8. [~] Add adapter fakes, integration/performance suite and CI. Existing suite passes 469 tests via the workspace signing workaround noted above; a macOS 14 GitHub Actions build/test workflow is now checked in, but has not run on GitHub. Adapter fakes and dedicated integration/performance coverage remain.

### P2 - Medium

1. [ ] Extract Dictation/Meeting/ModelLifecycle/Window/Permission coordinators from AppDelegate.
2. [ ] Split broad UserData into feature settings and repositories with migrations.
3. [ ] Add a few SwiftPM targets only where dependency rules are stable.
4. [ ] Improve model choice from measured backend/thread/footprint data.
5. [ ] Use actual target-screen geometry and test external display reconnect.
6. [ ] Add accessibility/appearance regression matrix and semantic typography.
7. [~] Add contributor/security docs, GitHub workflows/templates and provenance. Added contributor/security policies, issue forms, and macOS CI. The workflow is not yet verified on GitHub; artifact provenance/attestation remains open.
8. [~] Audit model/sound/sprite/art licenses. `NOTICE` and `Sounds/ATTRIBUTION.md` cover the bundled Whisper framework/model and external sound sources. Historical companion sprite folders still need a verified rights/source decision before redistribution.

### P3 - Future

1. [ ] Add typed model-callable tools only for concrete user-authorized capabilities.
2. [ ] Move JSON to SQL only if measured need justifies it.
3. [ ] Reduce theme complexity if use does not warrant maintenance.
4. [ ] Add resumable downloads after integrity/release process matures.
5. [ ] Evaluate sandboxing against real global input/audio requirements.
6. [ ] Add opt-in reviewed local diagnostics exporter.

## Current data and model flow

~~~mermaid
flowchart LR
  User --> Hotkey[KeyMonitor]
  Hotkey --> Delegate[AppDelegate]
  Delegate --> Context[Selection/context/destination]
  Delegate --> Audio[AudioRecorder]
  Audio --> PCM[PCM/WAV Data]
  PCM --> Service[TranscriptionService]
  Service --> Whisper[Whisper provider]
  Service --> Polish[Formatting and sentence polish]
  Polish --> Router[Voice/AI/note routing]
  Router --> Inject[TextInjector]
  Inject --> Target[Frontmost app]
  Router --> Notes[NoteStore]
  Notes --> Disk[JSON]
  Polish --> History[History]
  History --> Disk
~~~

~~~mermaid
flowchart TD
  Catalog[SpeechModelCatalog] --> Store[ModelStore]
  Store --> Bundle[Bundled Small model]
  Store --> Download[URLSession from resolve/main]
  Download --> Check{Current check}
  Check -->|HTTP and size only| Install[Application Support]
  Bundle --> Context[Whisper context]
  Install --> Context
  Context --> Queue[Serial worker]
  Queue --> Preview[Abortable preview]
  Queue --> Final[Final inference]
  Final --> Polish[Optional Foundation Models polish]
~~~

The current download flow’s size-only check is a security issue; insert a cryptographic hash gate before model installation.

## External references checked 6 October 2026

Primary platform sources; they support macOS guidance, not claims about this app’s runtime:

- Apple, [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance): profile long bodies, frequent updates and hitches with SwiftUI Instruments.
- Apple, [Performance analysis](https://developer.apple.com/documentation/swiftui/performance-analysis): use Instruments for hangs, hitches, main-thread delays and rendering.
- Apple HIG, [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), and [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars): native window anatomy, contextual actions and adaptable sidebar.
- Apple, [LanguageModelSession](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession) and [Generating content with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models): availability, async response and context behavior.
- Apple, [Foundation Models streaming response](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse%28to%3Aoptions%3Acontextoptions%3Ametadata%3A%29): use streaming for visible foreground response; Apple notes background requests may be more likely rate-limited.
- Upstream, [whisper.cpp releases](https://github.com/ggml-org/whisper.cpp/releases): repository pins v1.9.2 while v1.9.4 is listed upstream at review time; evaluate, do not blindly upgrade.
- Upstream, [Swift Testing](https://github.com/swiftlang/swift-testing): relevant to removing the temporary remote testing dependency once CI/toolchain allows.

## Repository evidence index

| Finding | Source |
|---|---|
| Package target/minimum OS/binary dependency | Package.swift |
| Lifecycle/workflow hotspot | Sources/UtterKit/App/App.swift |
| Native shell/sidebar | Sources/UtterKit/Screens/FlowMainView.swift |
| Whisper queue/context/backend/threading | Sources/UtterKit/Speech/LocalWhisperProvider.swift |
| Capture, VAD, buffer, trim, WAV | Sources/UtterKit/Audio/AudioRecorder.swift |
| Preview and delivery | Sources/UtterKit/App/App.swift |
| Model tiers/recommendation/download integrity | Sources/UtterKit/Speech/SpeechModelCatalog.swift; ModelStore.swift |
| Foundation Models | Sources/UtterKit/Speech/LocalAIEngine.swift |
| Transformation routers | Sources/UtterKit/Speech/AICommands.swift; NoteActions.swift; Model/UserData.swift |
| Notes/history/settings persistence | Sources/UtterKit/Model/NoteStore.swift; TranscriptionHistory.swift; UserData.swift |
| Fake auth | Sources/UtterKit/Screens/LoginView.swift; Sources/UtterKit/Model/UserData.swift |
| Pasteboard injection | Sources/UtterKit/Input/TextInjector.swift |
| Readiness work loop | Sources/UtterKit/Speech/ReadinessMonitor.swift |
| Meeting capture | Sources/UtterKit/Audio/SystemAudioCapture.swift; ProcessTapCapture.swift; MeetingSession.swift |
| Privacy/data description | PRIVACY.md; Sources/UtterKit/Model/AppDirectory.swift |
| Build/reset/release behavior | scripts/build-app.sh |
| Public claim mismatches | README.md; Sources/UtterKit/README.md; PRIVACY.md; docs/ |
| Dependencies | Package.swift; Package.resolved; requirements.txt; website/package.json |
| Existing tests | Tests/UtterKitTests/ |
