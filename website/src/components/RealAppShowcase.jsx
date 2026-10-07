import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Layers, Mic, FileText, Heart, Cpu, Sparkles, BookOpen, Settings, ChevronRight, Check, Eye } from 'lucide-react';
import CodeCompanionCanvas from './CodeCompanionCanvas';
import CompanionCharacterPicker from './CompanionCharacterPicker';

const COMPANION_PRESETS = [
  { id: 'gray', aliasId: 'charcoal-cat', name: 'Charcoal Cat', species: 'cat', isGinger: false, color: '#38bdf8' },
  { id: 'orange', aliasId: 'ginger-cat', name: 'Ginger Cat', species: 'cat', isGinger: true, color: '#f97316' },
  { id: 'dog', aliasId: 'pixel-dog', name: 'Pixel Dog', species: 'dog', isGinger: false, color: '#f59e0b' },
  { id: 'panda', aliasId: 'pixel-panda', name: 'Pixel Panda', species: 'panda', isGinger: false, color: '#a78bfa' },
];

const COMPANION_ACTIONS = [
  { id: 'waving', label: 'Wave Hello', icon: '👋' },
  { id: 'knead', label: 'Knead Keypads', icon: '🧶' },
  { id: 'walk', label: '4-Leg Walk', icon: '🐾' },
  { id: 'loaf', label: 'Loaf Sleep', icon: '🍞' },
  { id: 'delighted', label: 'Delighted', icon: '🎉' },
];

const APP_FEATURES = [
  {
    id: 'pill',
    title: 'Dynamic Liquid Glass Pill',
    badge: 'Non-Intrusive macOS HUD',
    icon: Mic,
    image: '/assets/screenshots/feature-pill-lineup.png',
    description:
      'Utter lives as a fluid HUD capsule hovering over your screen margins or menu bar. It morphs smoothly across 7 distinct states with live RMS waveforms and sub-200ms processing feedback.',
    highlights: [
      'Sub-5ms global push-to-talk activation via Fn or ⌥',
      'Double-tap Fn (or ⌃⌥Space) for continuous hands-free dictation',
      'Zero screen obstruction - adapts to active app windows',
    ],
  },
  {
    id: 'notes',
    title: 'Notes & Dual-Stream Meeting Studio',
    badge: 'CoreAudio Two-Way',
    icon: FileText,
    image: '/assets/screenshots/feature-notes.png',
    description:
      'Transcribe active meetings across Zoom, Microsoft Teams, Google Meet, and FaceTime. Utter separates your voice from attendees locally and saves clean Markdown notes directly to your disk.',
    highlights: [
      'Simultaneous microphone + system audio capture in RAM',
      'Automatic speaker attribution (You vs Others)',
      '1-click Markdown export with timestamps',
    ],
  },
  {
    id: 'companions',
    title: 'Procedural Vector Companions',
    badge: 'Hardware Accelerated · 0 PNGs',
    icon: Heart,
    image: null, // Interactive Procedural Vector Studio
    description:
      'Optional vector companions (Charcoal Cat, Ginger Cat, Pixel Dog, Pixel Panda) drawn procedurally in code at 60 FPS. They watch your pointer with real-time gaze tracking, knead mechanical keypads while you dictate, and celebrate coding streaks with 0 bundled artwork.',
    highlights: [
      '100% Procedural code rendering (CodePixelCat.swift) - 0 PNG assets',
      'Real-time smooth gaze tracking follows your cursor anywhere',
      'Whisper-reactive moods: Waving, Kneading, Walking, Loaf Sleep & Celebration',
    ],
  },
  {
    id: 'models',
    title: 'Speech Model Chooser & Benchmarks',
    badge: 'whisper.cpp Quantized Models',
    icon: Cpu,
    image: '/assets/screenshots/feature-speech-models.png',
    description:
      'Bundles the high-accuracy ggml-small.en-q5_1.bin model (181MB) for instant out-of-the-box operation, with 1-click downloads for multilingual and quantized Whisper models.',
    highlights: [
      'Preloaded ggml-small.en-q5_1.bin (181MB) for instant zero-config accuracy',
      'Multi-model switcher: Tiny, Base, Small, Distil-Whisper, and Large-v3-Turbo',
      'In-app benchmarking measuring real real-time factor (RTF) on your M-chip',
    ],
  },
  {
    id: 'transforms',
    title: 'Instant Voice Transforms & LLM Studio',
    badge: 'Local Ollama & OpenRouter',
    icon: Sparkles,
    image: '/assets/screenshots/feature-transforms.png',
    description:
      'Transform messy spoken rambling into executive summaries, pull request descriptions, polished emails, or bug reports with a single keystroke.',
    highlights: [
      'Air-gapped local LLMs via Ollama or private API keys (OpenRouter/Anthropic)',
      'Custom transform prompt templates with {{selection}} variables',
      'Replaces highlighted text in place or appends to active notes',
    ],
  },
  {
    id: 'dictionary',
    title: 'Phonetic Dictionary & Acronym Boosts',
    badge: 'Speech Bias Engine',
    icon: BookOpen,
    image: '/assets/screenshots/feature-dictionary.png',
    description:
      'Prevent Whisper from misinterpreting internal acronyms, proprietary APIs, foreign names, and dev tools with contextual speech biasing.',
    highlights: [
      'Contextual token prompt weighting directly injected into Whisper decoder',
      'Custom phonetic replacement mappings (e.g. "Kubernetes" -> "k8s")',
      'Import/export team dictionary presets via clean JSON',
    ],
  },
  {
    id: 'settings',
    title: 'Engine Preferences & Audio Pipeline',
    badge: 'Native macOS Settings',
    icon: Settings,
    image: '/assets/screenshots/feature-settings-general.png',
    description:
      'Fine-tune audio input devices, hotkey bindings, whisper hallucination filters, VAD sensitivity, and visual themes to match your personal workflow.',
    highlights: [
      'Hardware-level CoreAudio device selection and gain normalization',
      'Silero VAD threshold tuning to prevent background noise capture',
      'Customizable global hotkeys with macOS Accessibility integration',
    ],
  },
];

export default function RealAppShowcase() {
  const [activeTab, setActiveTab] = useState(0);
  const [companionPetIndex, setCompanionPetIndex] = useState(0);
  const [companionAction, setCompanionAction] = useState('waving');

  const current = APP_FEATURES[activeTab];
  const activeCompanion = COMPANION_PRESETS[companionPetIndex];

  return (
    <section id="showcase" className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto z-10">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-4 border border-orange-500/20">
          <Layers size={13} />
          <span>AUTHENTIC MACOS APP WORKSPACE</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Engineered exclusively for macOS.
        </h2>
        <p className="text-zinc-300 text-base sm:text-lg max-w-[640px]">
          Explore the real, native Swift application. Built with authentic macOS design tokens, Apple Silicon Metal acceleration, and zero compromise.
        </p>
      </div>

      {/* Feature Tab Navigation with Apple Sliding Spring Pill */}
      <div className="flex items-center justify-center gap-1.5 sm:gap-2 flex-wrap mb-10 p-1.5 rounded-3xl bg-black/40 border border-white/10 backdrop-blur-xl max-w-fit mx-auto">
        {APP_FEATURES.map((feature, idx) => {
          const Icon = feature.icon;
          const isSelected = activeTab === idx;
          return (
            <button
              key={feature.id}
              onClick={() => setActiveTab(idx)}
              className={`relative flex items-center gap-2 px-3.5 sm:px-4 py-2 rounded-2xl text-xs sm:text-sm font-medium transition-colors duration-150 select-none z-10 ${
                isSelected
                  ? 'text-zinc-950 font-bold'
                  : 'text-zinc-300 hover:text-white'
              }`}
            >
              {isSelected && (
                <motion.div
                  layoutId="activeFeaturePill"
                  className="absolute inset-0 bg-gradient-to-r from-orange-400 via-amber-300 to-yellow-200 rounded-2xl shadow-lg shadow-orange-500/25 -z-10"
                  transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                />
              )}
              <Icon size={15} />
              <span>{feature.title}</span>
            </button>
          );
        })}
      </div>

      {/* Main Feature Viewport Card */}
      <div className="liquid-glass rounded-3xl p-6 sm:p-10 border border-white/15 shadow-2xl overflow-hidden relative">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          {/* Left Column: Viewport Stage (7 cols) */}
          <div className="lg:col-span-7 relative rounded-2xl overflow-hidden min-h-[440px] bg-zinc-950 border border-white/10 shadow-2xl flex flex-col justify-between">
            {current.id === 'companions' ? (
              /* Interactive Procedural Vector Companion Stage with Authentic macOS Character Picker */
              <div className="w-full h-full flex flex-col justify-between p-4 sm:p-6 bg-gradient-to-b from-[#181517] to-[#0d0c0e] select-none">
                {/* macOS Window Header */}
                <div className="flex items-center justify-between border-b border-white/10 pb-3 mb-3">
                  <div className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
                    <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
                    <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
                    <span className="text-xs font-mono font-semibold text-zinc-300 ml-2">
                      Companion Settings - CodePixelCat.swift
                    </span>
                  </div>
                  <div className="flex items-center gap-1.5 px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-[10px] font-mono">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                    <span>0 Bundled PNGs</span>
                  </div>
                </div>

                {/* Authentic Character Picker Component */}
                <CompanionCharacterPicker
                  selectedId={activeCompanion.id}
                  onSelect={(c) => {
                    const idx = COMPANION_PRESETS.findIndex(
                      (p) => p.id === c.id || p.aliasId === c.id || p.id === c.aliasId
                    );
                    if (idx !== -1) setCompanionPetIndex(idx);
                  }}
                  className="mb-2"
                />

                {/* Live Vector Companion Canvas */}
                <div className="flex-1 flex flex-col items-center justify-center relative my-2">
                  <CodeCompanionCanvas
                    species={activeCompanion.species}
                    isGinger={activeCompanion.isGinger}
                    action={companionAction}
                    width={160}
                    height={160}
                  />

                  {/* Real-Time Cursor Eye Tracking Feedback */}
                  <div className="flex items-center gap-1.5 text-[10px] font-mono text-zinc-400 mt-2 bg-black/40 px-2.5 py-1 rounded-full border border-white/5">
                    <Eye size={11} className="text-orange-400" />
                    <span>Pupil gaze actively tracks pointer across screen</span>
                  </div>
                </div>

                {/* Action Trigger Bar with Spring Indicator */}
                <div className="flex items-center justify-between pt-3 border-t border-white/10 flex-wrap gap-2">
                  <div className="flex items-center gap-1.5 p-1 rounded-xl bg-black/40 border border-white/5">
                    {COMPANION_ACTIONS.map((act) => {
                      const isActSelected = companionAction === act.id;
                      return (
                        <button
                          key={act.id}
                          onClick={() => setCompanionAction(act.id)}
                          className={`relative px-2.5 py-1 rounded-lg text-[11px] font-mono transition-colors duration-150 z-10 select-none ${
                            isActSelected
                              ? 'text-zinc-950 font-bold'
                              : 'text-zinc-400 hover:text-white'
                          }`}
                        >
                          {isActSelected && (
                            <motion.div
                              layoutId="activeCompanionActionPill"
                              className="absolute inset-0 bg-orange-500 rounded-lg shadow-sm -z-10"
                              transition={{ type: 'spring', stiffness: 450, damping: 32 }}
                            />
                          )}
                          <span>{act.icon} {act.label}</span>
                        </button>
                      );
                    })}
                  </div>

                  <div className="text-[10px] font-mono text-amber-400/90 hidden sm:block">
                    100% Vector Procedural Math
                  </div>
                </div>
              </div>
            ) : (
              /* Real Native macOS App Screenshot with Fluid Apple Crossfade */
              <div className="relative w-full h-full min-h-[440px]">
                <AnimatePresence>
                  <motion.img
                    key={current.image}
                    src={current.image}
                    alt={current.title}
                    initial={{ opacity: 0, scale: 0.98 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.98 }}
                    transition={{ duration: 0.25, ease: [0.16, 1, 0.3, 1] }}
                    className="w-full h-full object-cover object-top filter brightness-[1.02] contrast-[1.02] rounded-2xl"
                  />
                </AnimatePresence>
                {/* Subtle overlay pill */}
                <div className="absolute top-4 left-4 px-3 py-1.5 rounded-full bg-zinc-950/80 backdrop-blur-md border border-white/15 text-[11px] font-mono text-zinc-300">
                  macOS Sonoma & Sequoia Native
                </div>
              </div>
            )}
          </div>

          {/* Right Column: Feature Details & Highlights (5 cols) */}
          <div className="lg:col-span-5 flex flex-col justify-between">
            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-orange-500/10 text-orange-400 font-mono text-xs mb-3 border border-orange-500/20">
                <span>{current.badge}</span>
              </div>
              <h3 className="text-2xl sm:text-3xl font-bold text-white mb-3 leading-snug">
                {current.title}
              </h3>
              <p className="text-zinc-300 text-sm leading-relaxed mb-6">
                {current.description}
              </p>

              {/* Bulleted Highlights */}
              <div className="space-y-3 mb-6">
                {current.highlights.map((item, i) => (
                  <div key={i} className="flex items-start gap-2.5 text-xs sm:text-sm text-zinc-200">
                    <div className="p-0.5 rounded-full bg-emerald-500/20 text-emerald-400 mt-0.5 shrink-0">
                      <Check size={13} strokeWidth={3} />
                    </div>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Download CTA Link */}
            <div className="pt-6 border-t border-white/10 flex items-center justify-between">
              <span className="text-xs font-mono text-zinc-400">Included in Utter v1.1.56</span>
              <a
                href="https://github.com/h3x-levi/Utter/releases/latest"
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-orange-400 hover:text-orange-300 transition-colors"
              >
                <span>Download DMG</span>
                <ChevronRight size={14} />
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
