import React from 'react';
import { motion } from 'framer-motion';
import { Mic, Zap, Users, Sparkles, BookOpen, Cat, ShieldCheck, ArrowUpRight } from 'lucide-react';

export default function FeatureBento() {
  const features = [
    {
      title: "Universal Cursor Injection",
      description: "Hold your hotkey (Fn, Right Option, or Right Cmd), speak naturally, release. Utter injects formatted text directly into Xcode, Cursor, Slack, Obsidian, or Chrome.",
      icon: <Mic size={22} className="text-indigo-600" />,
      tag: "Sub-200ms",
      tagColor: "bg-indigo-50 text-indigo-700 border-indigo-200",
      accent: "from-indigo-50 to-white",
      borderGlow: "group-hover:border-indigo-300",
    },
    {
      title: "Apple Metal GPU Acceleration",
      description: "Powered by whisper.cpp with native Metal kernels. Runs entirely in Apple Silicon unified memory (M1/M2/M3/M4) without consuming cloud bandwidth.",
      icon: <Zap size={22} className="text-amber-600" />,
      tag: "Zero Cloud",
      tagColor: "bg-amber-50 text-amber-700 border-amber-200",
      accent: "from-amber-50 to-white",
      borderGlow: "group-hover:border-amber-300",
    },
    {
      title: "Dual-Stream Meeting Diarization",
      description: "Automatically separates your microphone input from remote conference audio using macOS 14.2+ CoreAudio process taps. Perfect for Zoom and Meet.",
      icon: <Users size={22} className="text-emerald-600" />,
      tag: "Stereo Taps",
      tagColor: "bg-emerald-50 text-emerald-700 border-emerald-200",
      accent: "from-emerald-50 to-white",
      borderGlow: "group-hover:border-emerald-300",
    },
    {
      title: "On-Device Apple Intelligence",
      description: "Uses the FoundationModels framework on macOS 15 to clean grammar, strip filler words, generate Markdown tables, and format docstrings completely offline.",
      icon: <Sparkles size={22} className="text-purple-600" />,
      tag: "macOS 15 Native",
      tagColor: "bg-purple-50 text-purple-700 border-purple-200",
      accent: "from-purple-50 to-white",
      borderGlow: "group-hover:border-purple-300",
    },
    {
      title: "Developer Vocabulary & Snippets",
      description: "Feed your custom Swift APIs, Kubernetes cluster names, or medical jargon into Utter's dictionary. Zero spelling errors on esoteric technical terms.",
      icon: <BookOpen size={22} className="text-blue-600" />,
      tag: "100% Accurate",
      tagColor: "bg-blue-50 text-blue-700 border-blue-200",
      accent: "from-blue-50 to-white",
      borderGlow: "group-hover:border-blue-300",
    },
    {
      title: "Desktop Coding Companions",
      description: "Delightful pixel art companions that live on your menu bar or window edge. React in real time to your voice volume, speaking cadence, and typing speed.",
      icon: <Cat size={22} className="text-rose-600" />,
      tag: "Interactive Pets",
      tagColor: "bg-rose-50 text-rose-700 border-rose-200",
      accent: "from-rose-50 to-white",
      borderGlow: "group-hover:border-rose-300",
    },
  ];

  return (
    <section id="features" className="py-24 px-4 sm:px-8 bg-white/75 backdrop-blur-md border-t border-black/[0.06] w-full">
      <div className="w-full max-w-[94vw] 2xl:max-w-[1700px] mx-auto">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <span className="text-xs font-mono font-bold uppercase tracking-wider text-indigo-600 bg-indigo-50 border border-indigo-200/80 px-3 py-1 rounded-full">
            Engineered for macOS Power Users
          </span>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-zinc-900 mt-3 mb-4">
            Everything you need to dictate at lightspeed.
          </h2>
          <p className="text-base text-zinc-600">
            Engineered from scratch in Swift with whisper.cpp, ScreenCaptureKit, and Metal GPU shaders.
          </p>
        </div>

        {/* 6-Card Bento Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 2xl:gap-8">
          {features.map((feat, idx) => (
            <motion.div
              key={idx}
              whileHover={{ y: -4 }}
              transition={{ duration: 0.15 }}
              className={`group card-opaque p-7 flex flex-col justify-between transition-all duration-200 bg-gradient-to-b ${feat.accent} ${feat.borderGlow} relative overflow-hidden`}
            >
              <div>
                <div className="flex items-center justify-between mb-4">
                  <div className="w-12 h-12 rounded-2xl bg-white shadow-sm border border-black/[0.06] flex items-center justify-center">
                    {feat.icon}
                  </div>
                  <span className={`text-[11px] font-mono font-semibold px-2.5 py-1 rounded-full border ${feat.tagColor}`}>
                    {feat.tag}
                  </span>
                </div>

                <h3 className="text-lg font-bold text-zinc-900 mb-2 group-hover:text-black transition-colors">
                  {feat.title}
                </h3>
                <p className="text-xs sm:text-sm text-zinc-600 leading-relaxed">
                  {feat.description}
                </p>
              </div>

              <div className="mt-6 pt-4 border-t border-black/[0.04] flex items-center text-xs font-semibold text-zinc-500 group-hover:text-zinc-900 transition-colors">
                <span>Explore technical specs</span>
                <ArrowUpRight size={14} className="ml-1 opacity-60 group-hover:opacity-100 transition-opacity" />
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
