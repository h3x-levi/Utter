# UtterKit - source layout

UtterKit is the app layer: windows, screens, the hub, the pill and the companion. Everything
that is not UI lives in `Sources/UtterCore` (SDKs, Services, Features), which must not import
SwiftUI; `AppIdentityTests` fails the suite if a file does.

`Sources/Utter/main.swift` is a two-line executable that calls `UtterApp.main()`, and that
split is the reason UtterKit is a library: **SwiftPM cannot attach a test target to an
executable target**, so while the app was one executable, none of it was reachable from a
test - `import XCTest` fails to resolve and `@testable import` has no module to enter.
Verified on this machine before the move.

The practical rule that follows is to keep symbols `internal`. The executable needs only
`UtterApp`, and `Tests/UtterKitTests` reaches everything else with `@testable import UtterKit`.
If you find yourself adding `public` to something, check whether a test is what you actually
needed.

Nine folders, grouped by role. SwiftPM compiles nested directories automatically, so
these are organisational only - `Package.swift` names just `Sources/UtterKit` as the
target path and needs no update when files move between them.

| Folder | What belongs here |
|---|---|
| `App/` | Process lifecycle: the `NSApplicationDelegate`, the status item, every window, and `ThemedRoot`, which applies the appearance to an AppKit-hosted SwiftUI tree. |
| `Model/` | `ThemeManager`: the System, Light or Dark appearance choice. Persisted data (`UserData`, notes, history) lives in `UtterCore/Services`. |
| `Capture/` | One dictation turn. `CaptureMachine` holds it as one value; `CaptureSession` runs its effects and is the only writer of the pill's state. |
| `Audio/` | `MeetingOfferPanel`, the card offering to record a call Utter has detected. |
| `Hub/` | The menu-bar hub. `HubController` opens a non-activating `HubPanel` under the status item; `HubModel` feeds `HubView` (today's tape, search, deck keys). |
| `DesignSystem/` | Reusable appearance, nothing app-specific. See [Design system](#design-system-mixtape). |
| `Screens/` | One file per screen, plus the window shells they live in. `Library/`, `Words/` and `Companion/` hold the larger ones. |
| `Pill/` | The REC stripe and the transcript island. Its own folder because it is a separate `NSPanel`, not a screen in a window; its looks are derived from `PillState` in `PillMetrics.swift`. |
| `Companion/` | The floating CX ArtLab robot: an independent `NSPanel` with its own saved position, one level above the pill. `Robot/` is the Core Animation port; the rest is the bubble, the panel geometry and `CompanionBehaviour`, which turns app state into robot states and bubbles. |

## Tests

`swift test` - over 450 tests. The screen-snapshot suites are skipped unless asked for (see
[Seeing your change](#seeing-your-change)). The suite covers window sizing, the capture state
machine, the pill's morph timing and shell shape, the hub, note and settings persistence,
meeting audio and WAV framing, key chords, crash-log summarising, the robot's springs and
gestures, and the Mixtape palette's contrast and tape maths.

Three patterns worth copying when adding more:

**Pin the relationship, not the number.** A design token is a constant, so asserting
its value only restates the source. What is worth a test is the relationship that has to
hold: `MixtapeTests.contrast` measures each ink against paper with WCAG contrast, and pins
that Increase Contrast makes `rule`, `rule2`, `ink3` and `edge` stronger than their normal
values, in light and dark, without naming a hex value.

**Step the clock, never sleep.** The robot's springs and gestures advance through
`step(seconds:)` and `step(ms:)`, the same functions `RobotView`'s display link calls each
frame. `RobotTests` loops them at 60 fps, so a test covers seconds of motion without waiting
for it, and never flakes against a wall clock on a loaded machine.

**Write real files for persistence.** Settings arrive from disk, so `UserDataPersistenceTests`
writes into a temporary directory and reads back through the real `UserData(storageDir:)`,
including an unreadable file that must be preserved rather than overwritten and a golden
`userdata.json` that must round-trip every key. A mocked store proves nothing about either.

## Design system: Mixtape

The app ships the Mixtape look: a cassette J-card on white ruled stock, navy ballpoint ink,
one red tape stripe per surface, chrome tape in dark mode. [`DESIGN.md`](../../DESIGN.md) is
the specification (tokens, type scale, component sizes, motion, named rules). This section
says where things live and what review checks; do not copy its tables here.

### Where it lives

| Path | What is in it |
|---|---|
| `DesignSystem/Mixtape/Mixtape.swift` | `Mixtape.Palette` and the `Mixtape.*` colours, `ruleSpacing` (34 pt), `body` and `mono` fonts, `mixtapeCaps`, the `press` spring, `RuledBackground`, `HandCircle`, `InkTick`, `DrawnStroke`, `SideHeader`, `InkNote`. |
| `DesignSystem/Mixtape/MixtapeControls.swift` | The `.pen` and `.inkIcon` button styles, `LineField`, `DeckKeys` and `DeckKey`, `Keycap`. |
| `DesignSystem/Mixtape/MixtapeTape.swift` | `TapeStripe`, `TapeSegment`, `Mixtape.tapeWidths`, `TrackRow`, `WriteOn`. |
| `Screens/SettingsWindowView.swift` | The Settings kit: `SettingsTabs`, `SettingsSection`, `SettingsRow`, `SettingsChoice`, `SettingsPick`, `SettingsField`, `.settingsSwitch`, `SettingsStatus`, `SettingsMeter`, `SettingsKeycap`, `SettingsProse`, `SettingsDetail`. Words, the companion tab and Report Issue use it too. |
| `Screens/Library/LibraryScreen.swift` | `TapeNote`, the quiet empty-state note. |
| `DesignSystem/DesignTokens.swift` | `Space` (8, 12, 16), `Layout` (window sizes), `MotionPreference` (Reduce Motion and Reduce Transparency, read from AppKit). |
| `DesignSystem/Look/` | `Look.Swatch`, the four-way colour (light, dark, and each with Increase Contrast) that every Mixtape colour is built from; `Look.Motion` with `lookAnimation`; and `MarkGeometry`, the icon's bar proportions that `PillBars` uses. |
| `DesignSystem/GlassSurface.swift` | `GlassSupport` and `WindowBacking`. |
| `DesignSystem/ShapedHostingView.swift` | A hosting view that takes the mouse only where something is drawn, for the companion panel. |
| `Pill/PillWindow.swift` | `PillColor`, the pill's own inks. The pill is always chrome tape, so it does not use `Mixtape.*`. |

### Which component to reach for

| You need | Use |
|---|---|
| A button with words | `.buttonStyle(.pen())` (outline); `.pen(.fill)` for the one primary action in a group; `.pen(.ghost)` for dismissals; `.small` for 26 pt. |
| An icon-only action or a More menu | `.buttonStyle(.inkIcon)`, always with an `.accessibilityLabel`. |
| A search field | `LineField`. |
| Settings rows | `SettingsSection { SettingsRow(title, detail) { control } }`; paragraphs in `SettingsProse`. |
| On or off | `Toggle(...).toggleStyle(.settingsSwitch)`. |
| Two to four values | `SettingsChoice`. |
| A longer list of values | `SettingsPick` wrapping a `Picker` with `.pickerStyle(.inline)`. |
| Other text entry | `SettingsField`. |
| A state, a level, a key legend | `SettingsStatus`, `SettingsMeter`, `SettingsKeycap`; `Keycap` for printed shortcut hints. |
| A section title | `SideHeader` (`SettingsSection` already draws one). |
| One suggestion or setup need | `InkNote`. |
| An empty state | `TapeNote`. |
| Today's tape | `TapeStripe` with `TapeSegment`s; `TapeSegment.unkept` when Keep history is off. |
| A track | `TrackRow`, with `.modifier(WriteOn())` on the one that just arrived. |
| Hub transport keys | `DeckKeys([DeckKey(...)])`. |
| A hand mark | `DrawnStroke(HandCircle())` or `DrawnStroke(InkTick())`. |
| Ruled paper | `.background { RuledBackground() }`. |

### Rules that matter in review

**Mixtape tokens only.** Colours come from `Mixtape.*`, type from `mixtapeCaps`,
`Mixtape.body` and `Mixtape.mono`, spacing from `Space`, window sizes from `Layout`. A raw
`Color(white:)`, hex value or `.font(.system(size: 13))` in a screen is a bug, not a
shortcut: every Mixtape colour is a `Look.Swatch` that resolves in light, dark and Increase
Contrast, and a literal is right in at most one of them. The pill is the one exception, with
its own `PillColor`.

**No stock controls in the ink world.** No bordered buttons, `.switch` toggles, segmented
controls or pop-up buttons in the Library, hub, Settings or onboarding. Wrap the control in
an ink style and keep its accessibility: `.settingsSwitch` draws an ink capsule but exposes a
real `Toggle` through `accessibilityRepresentation`. The only system picker is an `.inline`
one inside a `SettingsPick` menu.

**No system accent colour.** Tint with Mixtape so nothing falls back to system blue:
`.tint(Mixtape.ink)` on Settings, onboarding and the sheets, `Mixtape.pen` on the Library,
`Mixtape.red` on fields (the red cursor).

**No glass behind paper.** The Library, hub, Settings and onboarding paint opaque
`Mixtape.paper`, `spine` or `fold`. Glass stays with the companion bubble over the desktop
(`glassEffect`, falling back to `.regularMaterial` under Reduce Transparency or before
macOS 26). `WindowBacking` still sits under the two windows `presentAuxWindow` opens (Report
Issue, What's New), and their content paints paper over it.

**Paper is flat, and rows sit on the 34 pt rules.** `Mixtape.ruleSpacing` is 34;
`RuledBackground` draws a 1 pt rule at the foot of each line and `TrackRow` is exactly one
line tall. Size new rows and text so they land on the rules. Separate surfaces with a rule,
a stock tone or a 1 pt edge, never a card or a drop shadow.

**Marks and caps are rationed.** One filled pen per group, one red stripe per surface, gold
only when the user has something to do, caps only for headings, pens, chips, deck keys and
the stripe, and numbers the eye compares in mono. DESIGN.md names each of these rules.

**Caps reach VoiceOver in caps.** `mixtapeCaps` applies `.textCase(.uppercase)` to the
source string, so a pen titled "Copy" is `COPY` to VoiceOver and to the verify skill's
`ax press`. Keep pen titles short real words, and match the caps when a test or a drive
looks one up.

**Menus open with AXShowMenu, not AXPress.** More, Library actions, the Words menus and
every `SettingsPick` are SwiftUI `Menu`s, which offer assistive tech only the show-menu
action (what VoiceOver's VO-Shift-M sends). Keep them `Menu`s rather than custom gestures,
and drive them with `ax menu`, never `ax press`.

**Every motion has a Reduce Motion path.** Read `@Environment(\.accessibilityReduceMotion)`
and make the motion instant or a short ease: `DrawnStroke` and `WriteOn` appear whole, tape
segments fade instead of growing and the recording dot stops pulsing, pens, chips and icon
buttons stop scaling on press, the switch eases over 0.15 s. Inside an `NSPanel` (the pill,
the meeting offer) read `MotionPreference.shared` instead, because SwiftUI's environment does
not reach there reliably.

**Appearance sets `NSApp.appearance` too.** The choice is System, Light or Dark
(`AppTheme`; ids saved by the old named themes map onto light or dark). `preferredColorScheme`
styles SwiftUI views but does *not* change the `NSAppearance` that dynamic `NSColor`s resolve
against, so Mixtape colours would return their light values inside a dark window.
`ThemeManager.applyAppearance()` exists for that reason, and `ThemedRoot` restyles an open
window when the choice changes.

### Seeing your change

- `UTTER_SCREEN_SNAPSHOTS=1 swift test --filter ZZMixtapeKitSnapshots` renders the kit to
  `.build/screen-snapshots/` as `<name>-light.png` and `<name>-dark.png`. The other suites are
  `ZZHubSnapshots`, `ZZMainWindowScreens`, `ZZSettingsScreens`, `ZZOnboardingSnapshots`,
  `ZZPillSnapshots`, `ZZCompanionScreenSnapshots` and `WordsSnapshots`. Without the variable
  they are skipped.
- Treat a snapshot as a preview. `SnapshotCanvas.write` draws offscreen with `cacheDisplay`,
  which drops glass and can show artefacts a real window does not; `SnapshotCanvas.capture`
  goes through the window server instead. Judge a visual change in the running app.
- The project-local [`verify` skill](../../.claude/skills/verify/SKILL.md) drives the real app
  through the Accessibility API against a scratch data folder, and keeps screenshots, AX trees
  and the JSON each action writes. It needs `bash scripts/build-app.sh --no-dmg` first and
  Accessibility for the terminal.

## Sign-in (not connected to Google yet)

The screen, the Settings row and the session are built; nothing talks to Google. `AccountSession` (UtterCore/Services/Account.swift) holds the signed-in account and keeps it in UserDefaults, so an offline launch still counts as signed in. Sign-in is required only once `AccountSession.shared.provider` is set; until then Utter runs as before. `--open-sign-in` opens the screen for a look.

To connect Google:

1. In Google Cloud Console, create an OAuth client of type **iOS** with bundle ID `utter.dictation.app`. Google requires the iOS type for macOS apps. There is no client secret. On the consent screen, choose External with scopes `openid`, `email` and `profile`, then publish.
2. Add `GoogleSignIn` 10.x with SwiftPM (`https://github.com/google/GoogleSignIn-iOS`) and run `swift package resolve`, because the build script passes `--skip-update`.
3. In the Info.plist that `scripts/build-app.sh` writes, add `GIDClientID` and a `CFBundleURLTypes` scheme set to the reversed client ID (`com.googleusercontent.apps.<id>`).
4. Write a `SignInProvider`:
   - `restore()` calls `restorePreviousSignIn`. It needs the network, so return nil when it fails offline.
   - `signIn(presenting:)` calls `signIn(withPresenting:)`. Throw `CancellationError` when the user closes the browser.
   - `signOut()` calls `signOut()`.
   - Read the account from `user.profile` (name, email, `imageURL(withDimension:)`).
5. Set `AccountSession.shared.provider` at the top of `applicationDidFinishLaunching`, before the sign-in gate.
6. Keychain: GoogleSignIn 10 stores its session in the data protection keychain. That needs a `keychain-access-groups` entitlement (`TEAMID.utter.dictation.app`) and an embedded provisioning profile. The build script signs with neither, so expect error -34018 until both are added.
7. Update the privacy copy ("Utter goes online only to download a model you choose") in Settings, onboarding and the README. Signing in will now go online too.

The button is Google's official light and dark art (`GoogleButtonArt`), drawn unchanged as the branding rules ask.

## Other conventions worth knowing before editing

**Let the window size the view, never the reverse.** `NSHostingView` publishes its content's
intrinsic size by default, and self-measuring layout (`ViewThatFits`, `GeometryReader`-driven
sizing) used that to collapse the main window to about 133 x 142 pt. Every window and panel
sets `sizingOptions = []`, and `showMainWindow` also re-asserts the size on the runloop as a
backstop. Give a new window the same.

**Nothing leaves the machine.** There is no networking outside the optional,
user-initiated speech-model download in `UtterCore/Services/ModelStore.swift`. Keep it that
way: `scripts/build-app.sh` fails the build if a `.env` appears.

**The robot costs nothing when idle.** `RobotView` precomputes every state into Core
Animation keyframes that the render server plays, so an idle robot does no main-thread work.
Its display link runs only while a gesture is live or the pointer moves near it, and stops
when that motion settles; asleep, nothing animates. `UtterCore/Services/CompanionLegacy.swift`
holds the pet-era API a few files still name. It draws nothing, so delete each block once its
last caller goes.
