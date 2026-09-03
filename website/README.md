# 🌐 Utter Official Website & 3D Interactive Showcase

The modern, 3D animated web experience for **Utter** built with **React, Vite, Tailwind CSS, Three.js, and Framer Motion**.

---

## ✨ Features

- **3D WebGL Soundfield Sphere**: Real-time acoustic particle field responding to cursor parallax and audio simulation.
- **Interactive Dictation Simulator**: Floating Liquid Glass Pill HUD with dynamic 7-bar audio waveform meter that types code into a simulated macOS Xcode / Cursor window.
- **Interactive Pixel Pet Playground**: Desktop retro pixel cat and corgi pet sandbox with click-to-pet reactions and friendship levels.
- **Hardware Acceleration Benchmark Slider**: Real-time slider comparing on-device Apple Metal GPU latency (sub-200ms) with cloud APIs.
- **3D Bento Grid Feature Showcase**: High-craft perspective cards with authentic full-resolution macOS desktop screen captures.
- **Air-Gapped Privacy & Security Inspector**: Zero-telemetry guarantees and architecture breakdown.

---

## 🚀 Quick Start (Local Development)

```bash
cd website
npm install
npm run dev
```

Open `http://localhost:3000` in your browser.

---

## 📦 Production Build

```bash
npm run build
```

The optimized static assets will be output to the `dist/` directory, ready to deploy to any hosting provider.

---

## 🚢 Deploying

### Option 1: Vercel (Recommended)
1. Push this folder or link the repository to [Vercel](https://vercel.com).
2. Set Root Directory to `website`.
3. Framework Preset: `Vite` (automatic via `vercel.json`).
4. Click **Deploy**.

### Option 2: Netlify
1. Link to [Netlify](https://netlify.com).
2. Base directory: `website`.
3. Publish directory: `website/dist`.
4. Deploy settings are pre-configured in `netlify.toml`.

### Option 3: Cloudflare Pages
1. Connect Git repository.
2. Build command: `npm run build`.
3. Output directory: `dist`.
