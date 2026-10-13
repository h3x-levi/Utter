# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS 13.3+ app (AppKit windows and panels hosting SwiftUI). Apple's Human Interface Guidelines for macOS are the platform authority; there is no web surface in scope.

## Users

Everyday Mac users first: people who found Utter on Product Hunt or Homebrew and want to talk instead of type in Mail, Slack, Notes, browsers and editors. They are not audio or ML experts. They judge the app in the first minute: does holding a key and speaking put good text where the cursor is, and does it feel delightful and trustworthy. Power users and developers remain welcome but are not the design target.

## Product Purpose

Utter turns speech into text wherever the cursor is, privately on the Mac. Hold a key (Fn by default), speak, release, and clean text is typed into the focused app. Around that core job: hands-free dictation, a notebook for voice notes and dual-stream meeting transcription (You and Others), voice transforms that rewrite selected text on device, a personal dictionary that improves recognition, text snippets triggered by voice, a choice of local Whisper models, and an optional robot companion on the desktop. Success: a new user dictates their first sentence into another app within a minute, trusts that nothing leaves the Mac, and keeps Utter running.

## Positioning

Free, open-source and fully on device: whisper.cpp runs in-process with Metal acceleration and the bundled small English model, so audio is never uploaded, there is no account and it works offline. Transforms use Apple's on-device Foundation Models where the OS provides them. The robot companion gives it a personality that cloud dictation tools do not have.

## Operating Context

- Lives in the menu bar; the main window is opened occasionally. The floating pill is the most-seen surface and appears over every app while dictating.
- Global shortcuts: hold Fn (or Right Option, Right Command, Right Control) to talk, double-tap for hands-free, Control-Option-Space hands-free toggle, Control-Option-N dictate to notes, Control-Option-U open workspace, Escape cancels.
- Requires Microphone and Accessibility permissions, and Screen and System Audio Recording for meeting capture. Onboarding must earn these.
- Runs alongside real work for hours: idle cost, memory, energy and frame rate matter as much as looks.

## Capabilities and Constraints

- Every current feature stays available, but the owner allows cutting or merging weak features after showing the plan (2026-10-10).
- Must not change: the `utter.dictation.app` bundle identifier, the `AppDirectory.legacyNames` migration of old `Lumen` data folders, permission flows, the text-injection behaviour, and the bundled model.
- Hard performance bar from the owner: no resource leaks, no hangs or freezes, smooth 60fps everywhere.
- Swift Testing suite in `Tests/UtterKitTests` must keep passing.

## Brand Commitments

- Name: Utter. Existing app icon (`AppIcon.icns`, `Assets/AppIconSource.png`) and menu-bar mark (`MenuBarIcon/`).
- Companion: the CX-ArtLab agent-robot-avatar robot (MIT code; the character's name and identity belong to CX ArtLab, credited in THIRD_PARTY_NOTICES.md), ported natively to Core Animation.
- The owner has handed full creative authority for the redesign (visual world, motion, information architecture), with three pinned decisions (2026-10-10):
  - The main app follows Apple's design system: native sidebar, toolbar, lists, forms, SF Pro, SF Symbols, Liquid Glass on macOS 26 and system materials on 14 and 15. No custom-painted window.
  - The pill is as minimal and unobtrusive as Wispr Flow's: a 32x6 pt glass capsule at rest and about 64x20 pt while listening, showing the icon's 7 tiny bars moving with the voice, with no live words by default. On 2026-10-11 the owner removed the liquid from the pill and made it smaller. The window keeps the liquid direction and the Moonlight palette (silver light on the icon's midnight navy). Only the transcript island is large.
  - The companion is the CX-ArtLab robot, which replaces the cats, dog, panda and sprite packs.

## Evidence on Hand

- Static product previews in `Assets/screenshots/` (rendered from SwiftUI, not live captures) and Product Hunt material in `ProductHuntAssets/`, `PRODUCT_HUNT_LAUNCH.md`.
- Prior design and architecture thinking: `docs/PRODUCT_DESIGN_REBUILD.md`, `docs/ARCHITECTURE_RESEARCH_AND_REDESIGN.md`.
- Absent, do not fabricate: user counts, ratings, testimonials, benchmark numbers that were not measured on this Mac.

## Product Principles

1. The pill and the first sentence are the product; everything else is supporting.
2. Private by construction, and say so plainly without fear-mongering.
3. Delight that never costs a frame: personality through motion, never through lag.
4. One obvious next step on every screen for a non-technical user.
5. Honest about state: ready, listening, thinking, typed, failed, with recovery.

## Accessibility & Inclusion

Full keyboard access, VoiceOver labels on every control, respects Reduce Motion, Reduce Transparency and Increase Contrast, works in light and dark appearance.
