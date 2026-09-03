<div align="center">

<img src="Assets/AppIconSource.png" alt="Utter App Icon" width="128" height="128" />

# Utter

**Private, zero-latency on-device voice dictation for every Mac app.**

[![macOS 13.3+](https://img.shields.io/badge/macOS-13.3%2B-black?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Engine: whisper.cpp](https://img.shields.io/badge/Engine-whisper.cpp%20Metal-blue?style=for-the-badge)](https://github.com/ggerganov/whisper.cpp)
[![Apple Intelligence](https://img.shields.io/badge/AI-Apple%20Intelligence%20Local-purple?style=for-the-badge)](https://apple.com)
[![Privacy: 100% On-Device](https://img.shields.io/badge/Privacy-100%25%20On--Device-success?style=for-the-badge)](PRIVACY.md)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue?style=for-the-badge)](LICENSE)

<br />

<p align="center">
  <a href="https://github.com/h3x-levi/Utter/releases/latest"><b>Download Latest Release (.dmg)</b></a> •
  <a href="https://h3x-levi.github.io/Utter/"><b>Live Web Showcase</b></a> •
  <a href="#quick-start"><b>Quick Start</b></a> •
  <a href="#features"><b>Features</b></a> •
  <a href="#privacy--security"><b>Privacy</b></a> •
  <a href="#building-from-source"><b>Building</b></a>
</p>

<img src="Assets/screenshots/hero-main.png" alt="Utter Native macOS App Workspace" width="100%" />

</div>

---

## 🌟 Overview

**Utter** is a native macOS application that turns your spoken voice into text wherever your cursor is focused. Hold a keycap, speak naturally, let go — and your words are instantly typed into Mail, Slack, Notes, Xcode, VS Code, Cursor, Obsidian, a terminal, or any active macOS application.

### Why Utter?

Most dictation and voice AI tools stream your audio recordings to remote third-party cloud servers. Utter is engineered with an uncompromising commitment to privacy, speed, and native macOS design:

- 🔒 **100% Local Inference**: Runs `whisper.cpp` in-process with Metal & Core ML hardware acceleration.
- ⚡ **Zero Network Latency**: Zero servers, zero telemetry, zero accounts, zero subscriptions, and zero rate limits.
- 🎯 **Context-Aware Precision**: Automatically adapts capitalization, spacing, and punctuation to code, chat, or long-form prose.
- 🎨 **Liquid Glass Design System**: Built with authentic macOS 13.3–15+ design tokens, vibrant translucency, Bento grids, and 7 bespoke themes.
- 🐾 **Articulated Desktop Companions**: Interactive pixel pets (Cat, Dog, Panda) that react to your speaking cadence and typing rhythms in real-time.

---

## ✨ Key Features

### 🎙️ Global Push-to-Talk & Hands-Free Dictation

- **Global Push-to-Talk**: Hold **`Fn`** (or Right **`⌥`**, Right **`⌘`**, Right **`⌃`**), speak your thought, and release. Utter injects clean sentences directly into your active input field.
- **Hands-Free Lock (`⌃⌥Space`)**: Latch recording mode for long-form dictation, brainstorming, or lectures. Auto-settles upon pausing or manual toggle.
- **Fluid Floating Pill**: Non-intrusive HUD capsule with live RMS waveform metering and seamless morphing transitions.

<div align="center">
  <img src="Assets/screenshots/feature-pill-lineup.png" alt="Dynamic Liquid Glass Pill Morphing" width="100%" />
</div>

---

### 📝 Note Capture Studio & Meeting Audio Transcription

- **Direct Note Dictation (`⌃⌥N`)**: Stream voice notes directly into Utter's built-in notebook with instant search, speaker separation, and Markdown export.
- **Dual-Stream Meeting Transcription**: Captures microphone input alongside system audio output, transcribing both streams locally as **You** and **Others**.
- **Proactive Meeting Presence Detection**: Automatically detects active meetings across Zoom, Microsoft Teams, Google Meet, FaceTime, Webex, Slack, and Discord.

<div align="center">
  <img src="Assets/screenshots/feature-notes.png" alt="Utter Notes Studio" width="94%" />
</div>

---

### 🧠 Apple Intelligence Voice Transforms

- **Voice Transforms**: Highlight any text in any macOS application, trigger Utter, and speak an instruction:
  - *"Make this concise and professional"*
  - *"Fix punctuation and tone"*
  - *"Translate into Japanese"*
  - *"Extract bulleted action items"*
- **On-Device Foundation Models**: Powered locally via macOS `FoundationModels` framework with fallback to offline heuristics.
- **Custom AI Commands**: Craft bespoke reusable prompt templates tailored to your personal coding or writing workflow.

<div align="center">
  <img src="Assets/screenshots/feature-transforms.png" alt="AI Voice Transforms Hub" width="94%" />
</div>

---

### 📚 Custom Vocabulary Boosting & Dynamic Snippets

- **Speech Biasing & Custom Dictionary**: Boost uncommon proper nouns, engineering jargon, medical terms, and project acronyms so Whisper never misses them.
- **Voice Snippets**: Speak trigger keywords to expand complex boilerplate templates with dynamic placeholders (`{date}`, `{time}`, `{clipboard}`).

<div align="center">
  <img src="Assets/screenshots/feature-dictionary.png" alt="Custom Dictionary" width="48%" />
  <img src="Assets/screenshots/feature-snippets.png" alt="Voice Snippets Studio" width="48%" />
</div>

---

### 🐾 Articulated Quadruped Desktop Companions

- **Desktop Pixel Pets**: An optional interactive companion (Cat, Dog, Panda) that floats on your desktop and reacts dynamically to speaking volume, transcription speed, and typing cadence.
- **Full-Body Articulated Motions**:
  - 🐾 **4-Leg Walking Cycles**: Natural diagonal limb cadence.
  - 🧶 **Biscuit Kneading**: Sinusoidal arm push gestures.
  - 🤔 **Chin-Scratch Thinking**: Arm raised to chin with thoughtful head tilts.
  - 🍞 **Loaf Mode**: Four limbs tucked cleanly underneath during resting/sleep.
  - 🎉 **Celebration Hands**: Joyful raised paws during fast speech flow.
  - 🪂 **Dangle Physics**: Limbs and tail dangle with gravity when dragged across displays.
- **60 FPS Vector Engine**: Rendered asynchronously on background CoreGraphics queues with zero main-thread CPU impact.

<div align="center">
  <img src="Assets/screenshots/feature-companion-showcase.png" alt="Full-Body Articulated Companion Pets" width="100%" />
</div>

---

### 🎛️ Speech Model Chooser & Benchmark Selection

Utter bundles the high-accuracy `ggml-small.en-q5_1.bin` model (181MB) for instant out-of-the-box operation and supports downloading specialized multilingual and quantized Whisper models directly within the app.

<div align="center">
  <img src="Assets/screenshots/feature-speech-models.png" alt="Speech Model Chooser" width="94%" />
</div>

---

### 🎨 7 Liquid Glass Themes

Crafted with pixel-perfect macOS typography, high-contrast borders, and adaptive materials:
1. **System Glass** (Dynamic Auto Light/Dark)
2. **Dark Glass** (Refined Translucent Obsidian)
3. **Obsidian** (Pure Deep Charcoal)
4. **Solar Warmth** (Warm Amber Glow)
5. **Nordic Frost** (Crisp Polar Blue)
6. **Midnight Indigo** (Rich Deep Violet)
7. **Paper White** (Clean Minimalist Editorial)

<div align="center">
  <img src="Assets/screenshots/feature-settings-general.png" alt="Settings & Appearance" width="94%" />
</div>

---

## 🔒 Privacy & Performance Matrix

| Metric / Feature | Utter | Cloud AI Dictation Apps | System Siri Dictation |
| :--- | :---: | :---: | :---: |
| **Audio Processing Location** | **100% Local (In-Process)** | Cloud Servers | Cloud / Partial Local |
| **Network Traffic** | **0 Bytes Sent** | Continuous Audio Upload | Telemetry & Logs |
| **Offline Operation** | **Full (Airplane Mode)** | Requires Active Internet | Limited |
| **Hardware Acceleration** | **Apple Silicon Metal & Core ML** | Remote GPU Fleet | Apple Neural Engine |
| **Subscription / Pricing** | **Free & Open Source** | $10–$20 / month | Free |
| **Meeting Dual-Stream Capture** | **Included** | Paid Add-on Bot | Unsupported |

---

## ⌨️ Default Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`Hold Fn`** *(or `Right ⌥`, `Right ⌘`, `Right ⌃`)* | **Push-to-Talk**: Dictate into active cursor position | Global |
| **`⌃ ⌥ Space`** | **Toggle Hands-Free Mode**: Continuous dictation | Global |
| **`⌃ ⌥ N`** | **Dictate to Notes**: Capture voice into notebook | Global |
| **`⌃ ⌥ U`** | **Open Utter Workspace**: Access settings and history | Global |
| **`Escape`** | Cancel active recording / Dismiss HUD | Global |

---

## 🚀 Quick Start

### 1. Download
Download the latest DMG release from [GitHub Releases](https://github.com/h3x-levi/Utter/releases/latest):
```bash
# Or download directly from terminal:
curl -LO https://github.com/h3x-levi/Utter/releases/download/v1.1.47/Utter-1.1.47.dmg
```

### 2. Install
1. Double-click `Utter-1.1.47.dmg`.
2. Drag **Utter.app** into your **Applications** folder.
3. Launch **Utter** from Spotlight or Applications.

### 3. Grant macOS Permissions
Upon first launch, Utter will guide you through granting two standard macOS permissions:
- **Microphone**: Required for capturing spoken audio.
- **Accessibility**: Required for detecting your chosen global push-to-talk hotkey and injecting transcribed text into active applications.

---

## 🛠️ Building from Source

### Prerequisites
- macOS 13.3 Ventura or later
- Xcode 15+ or Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later

### Clone & Build
```bash
# 1. Clone repository
git clone https://github.com/h3x-levi/Utter.git
cd Utter

# 2. Build release binary using Swift Package Manager
swift build -c release

# 3. Create styled DMG installer and application bundle
./scripts/build-app.sh --keep-permissions
```
The compiled application and installer will be located in:
- `build/Utter.app`
- `build/Utter-1.1.47.dmg`

---

## 🧩 Architecture

```mermaid
graph TD
    User([User Voice]) --> Mic[AVAudioEngine 16kHz PCM Buffer]
    SysAudio([Meeting Audio]) --> Tap[ProcessTap / CoreAudio System Stream]
    
    Mic --> Pill[Pill HUD Floating Window]
    Tap --> Meeting[Meeting Session Coordinator]
    
    Mic --> Whisper[whisper.cpp Metal / Core ML Engine]
    Tap --> Whisper
    
    Whisper --> Bias[Speech Bias & Dictionary Engine]
    Bias --> Polish[Sentence Polish & Punctuation]
    
    Polish --> Injector[Accessibility Text Injector]
    Polish --> NoteStore[Local Notes Store SQLite/JSON]
    
    Polish --> AI[Apple Intelligence Local LLM Engine]
    AI --> Injector
    
    Pill --> Companion[Articulated 60FPS Companion Pet]
```

---

## 📄 License

Utter is distributed under the **Apache License 2.0**. See [`LICENSE`](LICENSE) for complete terms.

```
Copyright 2026 Utter Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0
```
