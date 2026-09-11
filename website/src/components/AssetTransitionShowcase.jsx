import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, PhoneCall, Sparkles, Cpu, BookOpen, Heart, ArrowRight, ShieldCheck, ChevronLeft, ChevronRight } from 'lucide-react';
import CodeCompanionCanvas from './CodeCompanionCanvas';

export default function AssetTransitionShowcase() {
  const [activeAssetIndex, setActiveAssetIndex] = useState(0);

  const assetModes = [
    {
      id: 'dictation',
      title: 'Voice-to-Code Dictation HUD',
      badge: 'whisper.cpp on Metal GPU',
      description: 'Hold Fn or Spacebar to dictate code, notes, or messages with sub-200ms latency. The floating Liquid Glass HUD appears smoothly, analyzes audio frames in unified memory, and injects clean text directly at your active cursor.',
      image: '/assets/screenshots/hero-main.png',
      icon: <Mic className="w-4 h-4 text-white" />,
      accentColor: '#5f61ed',
      metrics: [
        { label: 'Latency', value: '168 ms' },
        { label: 'Accuracy', value: '98.6%' },
        { label: 'Throughput', value: '188 WPM' },
      ],
      features: ['Sub-5ms hotkey response', 'Zero temporary files written to disk', 'Preserves Alfred & Raycast clipboard'],
    },
    {
      id: 'meetings',
      title: 'Two-Way Meeting Diarization',
      badge: 'CoreAudio Dual-Stream',
      description: 'Automatic active call detection for Zoom, Google Meet, Teams, Slack, and FaceTime. Taps incoming system audio and your microphone simultaneously to produce clean, speaker-attributed transcripts with 1-click Markdown export.',
      image: '/assets/screenshots/feature-notes.png',
      icon: <PhoneCall className="w-4 h-4 text-white" />,
      accentColor: '#006fff',
      metrics: [
        { label: 'Channels', value: 'Dual-Stream' },
        { label: 'Diarization', value: 'You vs Others' },
        { label: 'Format', value: 'Markdown (.md)' },
      ],
      features: ['Zero virtual audio driver setup', 'Live speaker identification', 'Instant Apple Intelligence summary'],
    },
    {
      id: 'companions',
      title: 'Procedural Desktop Pixel Pets',
      badge: 'Code-Rendered Companions',
      description: 'Nostalgic, interactive pixel companions drawn purely in code (0 PNGs) that sit on your desktop, track your cursor gaze with their eyes, monitor your typing cadence, react to speech amplitude, and celebrate milestones.',
      image: null,
      icon: <Heart className="w-4 h-4 text-white" />,
      accentColor: '#ec4899',
      metrics: [
        { label: 'Runtime', value: '100% Code' },
        { label: 'Sprites', value: '0 PNGs' },
        { label: 'Render', value: '< 0.1ms' },
      ],
      features: ['Ginger Cat, Charcoal Cat, Pixel Dog & Panda', 'Integer-pixel eye gaze tracking', 'Sub-millisecond procedural draw calls'],
    },
    {
      id: 'models',
      title: 'Local Speech Model Switcher',
      badge: 'Quantized Neural Weights',
      description: 'Choose from 5 local Whisper models (Tiny, Base, Small.en, Medium, Large-v3-Turbo). Bundled with Small.en out of the box for zero-setup execution. Swap models anytime with 1-click downloads directly to your local library.',
      image: '/assets/screenshots/feature-speech-models.png',
      icon: <Cpu className="w-4 h-4 text-white" />,
      accentColor: '#10b981',
      metrics: [
        { label: 'Bundled', value: 'Small.en (181M)' },
        { label: 'RAM Usage', value: '< 240 MB' },
        { label: 'Quantization', value: 'Q5_1' },
      ],
      features: ['Apple Metal GPU acceleration', 'Air-gapped offline execution', 'Zero API token requirements'],
    },
    {
      id: 'dictionary',
      title: 'Custom Dictionary & Context Biasing',
      badge: 'Developer Lexicon & Macros',
      description: 'Feed proprietary variable names, acronyms, medical jargon, and company terms directly into the Whisper decoder. Sentence polish removes disfluencies (um, ah) and expands snippet macros instantly.',
      image: '/assets/screenshots/feature-dictionary.png',
      icon: <BookOpen className="w-4 h-4 text-white" />,
      accentColor: '#f59e0b',
      metrics: [
        { label: 'Biasing', value: 'Entity Boosting' },
        { label: 'Disfluency', value: 'Auto-Clean' },
        { label: 'Snippets', value: 'Macro Engine' },
      ],
      features: ['100% accurate camelCase & code syntax', 'Instant custom phrase expansion', 'Zero dictionary cloud sync'],
    },
  ];

  const current = assetModes[activeAssetIndex];

  const nextAsset = () => {
    setActiveAssetIndex((prev) => (prev + 1) % assetModes.length);
  };

  const prevAsset = () => {
    setActiveAssetIndex((prev) => (prev - 1 + assetModes.length) % assetModes.length);
  };

  return (
    <section className="py-28 px-4 sm:px-6 relative z-10 bg-[#0d0d10] border-t border-zinc-800/80">
      <div className="max-w-7xl mx-auto">

        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Interactive Visual Architecture
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Seamless transitions between core tools.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Explore the five specialized surfaces inside Utter with fluid spring transitions.
          </p>
        </div>

        {/* Top Asset Mode Selector Pills (dock.cool style) */}
        <div className="flex flex-wrap items-center justify-center gap-2 mb-12">
          {assetModes.map((asset, idx) => (
            <button
              key={asset.id}
              onClick={() => setActiveAssetIndex(idx)}
              className={`px-4 py-2 rounded-full text-xs font-medium transition-all duration-300 flex items-center gap-2 border ${
                activeAssetIndex === idx
                  ? 'bg-zinc-800 text-white border-zinc-500 shadow-lg scale-105'
                  : 'bg-zinc-900/80 text-zinc-400 border-zinc-800 hover:text-zinc-200 hover:bg-zinc-800/60'
              }`}
            >
              <span className={`w-2 h-2 rounded-full transition-colors ${
                activeAssetIndex === idx ? 'bg-white' : 'bg-zinc-600'
              }`} />
              <span>{asset.title.split(' ')[0]}</span>
            </button>
          ))}
        </div>

        {/* 3D Interactive Asset Stage Card */}
        <div className="relative rounded-[32px] p-4 sm:p-10 bg-gradient-to-b from-zinc-800/50 via-zinc-900/60 to-[#0a0a0d] border border-zinc-700/60 shadow-[0_30px_90px_rgba(0,0,0,0.8)] overflow-hidden">

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-center">

            {/* Left 5 Cols: Details & Metrics */}
            <div className="lg:col-span-5 flex flex-col justify-between space-y-6">
              <AnimatePresence mode="wait">
                <motion.div
                  key={current.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20 }}
                  transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
                >
                  <div className="inline-flex items-center gap-2 px-3 py-1 rounded-md bg-zinc-800 text-zinc-300 text-xs font-mono font-medium mb-4 border border-zinc-700">
                    {current.icon}
                    <span>{current.badge}</span>
                  </div>

                  <h3 className="text-2xl sm:text-4xl font-bold text-white mb-4 tracking-tight leading-tight">
                    {current.title}
                  </h3>

                  <p className="text-zinc-400 text-sm sm:text-base leading-relaxed mb-6">
                    {current.description}
                  </p>

                  {/* 3 Metric Badges */}
                  <div className="grid grid-cols-3 gap-2.5 mb-6">
                    {current.metrics.map((m, i) => (
                      <div key={i} className="p-3 rounded-xl bg-[#141418] border border-zinc-800 text-center">
                        <div className="text-sm sm:text-base font-bold font-mono text-white">{m.value}</div>
                        <div className="text-[10px] font-mono text-zinc-500 mt-0.5">{m.label}</div>
                      </div>
                    ))}
                  </div>

                  {/* Feature Checklist */}
                  <div className="space-y-2 mb-8">
                    {current.features.map((feat, i) => (
                      <div key={i} className="flex items-center gap-2.5 text-xs text-zinc-300 font-mono">
                        <span className="w-1.5 h-1.5 rounded-full bg-white"></span>
                        <span>{feat}</span>
                      </div>
                    ))}
                  </div>

                  {/* Navigation Arrows */}
                  <div className="flex items-center gap-3 pt-4 border-t border-zinc-800">
                    <button
                      onClick={prevAsset}
                      className="p-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-white border border-zinc-700 transition-all active:scale-95"
                    >
                      <ChevronLeft className="w-4 h-4" />
                    </button>
                    <span className="text-xs font-mono text-zinc-500">
                      0{activeAssetIndex + 1} / 0{assetModes.length}
                    </span>
                    <button
                      onClick={nextAsset}
                      className="p-2.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-white border border-zinc-700 transition-all active:scale-95"
                    >
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                </motion.div>
              </AnimatePresence>
            </div>

            {/* Right 7 Cols: 3D Floating Asset Visual Frame */}
            <div className="lg:col-span-7 relative flex items-center justify-center">
              <AnimatePresence mode="wait">
                <motion.div
                  key={current.id}
                  initial={{ opacity: 0, scale: 0.94, y: 15 }}
                  animate={{ opacity: 1, scale: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.94, y: -15 }}
                  transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
                  className="w-full relative rounded-2xl overflow-hidden bg-[#101014] border border-zinc-700/80 shadow-[0_20px_60px_rgba(0,0,0,0.9)] p-2"
                >
                  {current.id === 'companions' ? (
                    <div className="w-full aspect-[16/10] flex items-center justify-center bg-zinc-950 rounded-xl">
                      <CodeCompanionCanvas species="cat" isGinger={true} action="knead" width={220} height={220} />
                    </div>
                  ) : (
                    <img
                      src={current.image}
                      alt={current.title}
                      className="w-full rounded-xl object-cover shadow-2xl"
                    />
                  )}
                  {/* Subtle rim highlight reflection */}
                  <div className="absolute inset-0 rounded-2xl pointer-events-none border border-white/10 shadow-[inset_0_1px_1px_rgba(255,255,255,0.2)]"></div>
                </motion.div>
              </AnimatePresence>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
