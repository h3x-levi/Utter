# 🚀 Utter — Product Hunt Launch Kit & Master Playbook

> **The Ultimate Launch Kit for Product Hunt, Hacker News, X (Twitter), Reddit, and Indie Hackers**

---

## 📌 1. Product Metadata & Fast Facts

| Field | Content |
| :--- | :--- |
| **Product Name** | **Utter** |
| **Tagline (Short)** | Native, zero-latency on-device voice dictation & desktop companion for macOS |
| **Alternative Tagline** | Whisper.cpp on Metal + Liquid Glass HUD + Desktop Pet. 100% private. |
| **Category** | Artificial Intelligence, Productivity, Mac, Open Source, Developer Tools |
| **Pricing** | **100% Free & Open Source** (No subscriptions, no API keys, zero cloud telemetry) |
| **Website URL** | `https://h3x-levi.github.io/Utter/` |
| **GitHub Repository** | `https://github.com/h3x-levi/Utter` |
| **Direct Download (DMG)**| `https://github.com/h3x-levi/Utter/releases/latest` |

---

## 🎯 2. Product Hunt Listing Copy

### 🏷️ Headline / Punchline
**"Type at 180 WPM anywhere on your Mac with 100% local speech recognition & zero cloud telemetry."**

---

### 📝 Short Description (Under 260 characters)
Utter is a lightning-fast, bi-ported native macOS voice dictation tool powered by whisper.cpp with Metal GPU acceleration. Features an ultra-minimalist Liquid Glass HUD, AI text transforms, meeting transcription, and an articulated desktop companion.

---

### 📖 Detailed Description / Story (Product Hunt Body)

**The Problem with Voice Dictation Today:**
1. **Cloud APIs are slow and eavesdrop on your thoughts**: Dictating confidential code, personal notes, or private messages through third-party cloud endpoints introduces latency and leaks your private voice data.
2. **Built-in macOS dictation is inaccurate and clunky**: It struggles with technical jargon, programming syntax, acronyms, and accents.
3. **Expensive monthly subscriptions**: Most modern voice AI tools charge \$15–\$30/month for simple wrappers around cloud speech APIs.

---

**Meet Utter: Fast. Private. Beautiful.**

Utter runs **100% locally on your Mac's Apple Silicon GPU / Neural Engine**. Powered by an optimized C++ `whisper.cpp` engine with Metal acceleration, it transcribes speech into text in under 180 milliseconds—completely offline.

#### ✨ Key Highlights:

* ⚡ **Hold to Talk, Release to Type**: Push-to-talk with global hotkeys (`Fn`, `Right Option`, `Right Cmd`). Dictate instantly into Xcode, Cursor, VS Code, Slack, Obsidian, Chrome, Mail, or any macOS text field.
* 🔒 **Zero Telemetry / Air-Gapped Privacy**: No accounts, no subscriptions, no tracking, and zero cloud speech endpoints. Your voice never leaves your Mac.
* 🪟 **Liquid Glass Pill HUD**: A floating, ultra-minimalist interface with real-time 7-bar audio waveform meters that stays out of your way and seamlessly adapts to your display.
* 🤖 **Local AI Transforms & Note Studio**: Clean up filler words, fix grammar, generate meeting summaries, or apply custom prompts using Apple Intelligence / local foundation models.
* 🎙️ **Dual-Stream System Audio & Meeting Taps**: Automatically detects Zoom, Google Meet, Teams, or FaceTime calls and transcribes two-way audio (microphone + incoming speakers) in real time.
* 🐾 **Articulated Desktop Companion**: An optional nostalgic, charming pixel cat or corgi pet that rests on your desktop, reacts to your typing cadence and speech amplitude, and keeps you company while you code.
* 📚 **Custom Vocabulary & Snippet Expander**: Teach Utter your company's proprietary names, code variables, medical terms, and snippet macros.

---

## 💬 3. Maker's First Comment (Pin This on Launch Day)

```markdown
Hey Product Hunt! 👋 I'm Levi, creator of Utter.

Like many developers and writers, I love dictating my thoughts, but I was deeply frustrated by the current state of voice dictation:
1. Cloud-based tools introduce noticeable lag, require constant internet access, and upload sensitive audio to third-party servers.
2. The subscription fatigue is real—paying $20/month just to convert voice to text felt unreasonable.

So I built **Utter** as a native, bi-ported macOS application built from first principles in Swift and C++.

Here is what makes Utter fundamentally different:
- 🏎️ **Ultra-Low Latency (Sub-200ms)**: Powered by whisper.cpp with native Metal GPU compute shaders. It feels instant.
- 🛡️ **Zero Cloud Telemetry**: Everything runs on-device. You can use Utter on an airplane with Wi-Fi disabled.
- 🪟 **High-Craft macOS Native UX**: Built with native macOS Liquid Glass shaders, smooth spring animations, and full accessibility support.
- 🐱 **Pixel Pet Companion**: Because working alone at your desk shouldn't be boring!

Utter is **100% Free and Open Source**. No tiers, no paywalls, no API token requirements.

Download the DMG, give it a spin, and let me know your thoughts! I'm here all day to answer your questions, take feature requests, and hear your feedback. 🚀
```

---

## 🐦 4. Social Media Copy (X / Twitter, LinkedIn, Threads)

### 🧵 Post / Launch Thread (X / Twitter)

**Post 1 (The Hook):**
> 🎙️ Introducing Utter: Native, zero-latency on-device voice dictation for macOS.
>
> ⚡ Sub-200ms transcription with whisper.cpp on Metal GPU
> 🔒 100% offline & zero cloud telemetry
> 🪟 Liquid Glass floating HUD
> 🐾 Articulated pixel desktop companion
>
> 100% Free & Open Source.
>
> 🧵👇

**Post 2 (The Speed & Privacy):**
> Hold Fn, speak your mind, let go—your words appear instantly in Cursor, Xcode, Slack, or Obsidian.
>
> Zero cloud servers. Zero data collection. Works seamlessly on airplanes and air-gapped environments. ✈️

**Post 3 (The Companion):**
> Meet your new desktop coding buddy! An interactive pixel companion that reacts to your voice volume, monitors your typing cadence, and plays with yarn while you dictate. 🐱🐾

**Post 4 (Download & Link):**
> Check out the live launch on Product Hunt and grab the free DMG:
> 🔗 Product Hunt: [Link]
> 💻 GitHub: https://github.com/h3x-levi/Utter
> 🌐 Website: https://h3x-levi.github.io/Utter

---

## ❓ 5. Anticipated FAQs & Ready Answers

**Q: How does this compare to Apple's built-in macOS dictation?**
> **A:** macOS dictation often hallucinates or cuts off after a few seconds and struggles with technical jargon. Utter uses OpenAI's Whisper model (via whisper.cpp on Metal), which offers vastly superior punctuation, accuracy across accents, and custom dictionary context biasing for code symbols and acronyms.

**Q: Does it work with Cursor, VS Code, and terminal emulators?**
> **A:** Yes! Utter uses native macOS accessibility and synthetic key events to inject text directly at your cursor in any active application without overwriting your clipboard history.

**Q: What speech models are supported?**
> **A:** Utter bundles `ggml-small.en-q5_1` (181 MB) out of the box so it works with zero setup. You can also switch to `base`, `medium`, or `large-v3-turbo` with 1-click in the Model Chooser.

**Q: Is it really free? Where's the catch?**
> **A:** No catch! Utter is fully open-source under the MIT license. There are no server costs because all compute runs locally on your Apple Silicon hardware.

---

## 📅 6. Launch Day Checklist & Strategy

- [ ] **Timing**: Schedule launch for **12:01 AM PST (Pacific Standard Time)** on a Tuesday or Wednesday for maximum global visibility.
- [ ] **Assets**: Upload 1280×720 high-res gallery images showcasing:
  1. Full macOS desktop hero view with Liquid Glass Pill HUD.
  2. Dictation in action inside code editors (Cursor/Xcode).
  3. Interactive Pixel Cat & Corgi companion showcase.
  4. Local Whisper model switcher & performance telemetry.
  5. Privacy & air-gapped architecture comparison.
- [ ] **First Hour**: Post the Maker Comment immediately after launch and reply to every single comment within 10 minutes.
- [ ] **Cross-Post**: Share on `/r/macapps`, `/r/apple`, `/r/swift`, Hacker News ("Show HN: Utter – On-Device Whisper Voice Dictation for macOS"), and X/Twitter.
