import React from 'react';
import { motion } from 'framer-motion';
import { Download, Github, Sparkles, ArrowRight, Shield, Zap, Cpu } from 'lucide-react';
import InteractiveMacStudio from './InteractiveMacStudio';

export default function Hero() {
  return (
    <section className="pt-32 pb-20 px-4 relative overflow-hidden bg-colorful-mesh">
      <div className="max-w-6xl mx-auto flex flex-col items-center text-center">
        {/* Colorful Badge */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white border border-black/10 shadow-sm text-xs font-semibold text-zinc-800 mb-6"
        >
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
          <span>macOS 14+ Sonoma & Sequoia</span>
          <span className="text-zinc-300">•</span>
          <span className="text-indigo-600 font-bold">Apple Silicon Metal GPU</span>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35 }}
          className="text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-zinc-900 mb-6 max-w-4xl leading-[1.05]"
        >
          Voice dictation that{' '}
          <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 bg-clip-text text-transparent">
            stays on your Mac.
          </span>
        </motion.h1>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="text-lg sm:text-xl text-zinc-600 max-w-2xl mb-8 leading-relaxed font-normal"
        >
          Hold a key, speak naturally, release. Utter transcribes at 180 WPM using local Whisper models in unified memory — zero cloud, zero telemetry, zero latency.
        </motion.p>

        {/* Action Buttons */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45 }}
          className="flex flex-wrap items-center justify-center gap-4 mb-10"
        >
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-2.5 bg-zinc-900 text-white hover:bg-black px-8 py-4 rounded-full font-bold text-sm shadow-lg hover:shadow-xl transition-all active:scale-95"
          >
            <Download size={17} />
            Download for Mac
            <span className="text-xs font-mono opacity-60 ml-1">v1.1.56</span>
          </a>

          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2.5 bg-white text-zinc-800 hover:text-black border border-black/10 px-7 py-4 rounded-full font-semibold text-sm shadow-sm hover:bg-zinc-50 transition-all active:scale-95"
          >
            <Github size={17} />
            View on GitHub
          </a>
        </motion.div>

        {/* Key Metrics Chips */}
        <div className="flex flex-wrap items-center justify-center gap-3 sm:gap-6 text-xs font-semibold text-zinc-600 mb-14">
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-black/[0.06] shadow-sm">
            <Zap size={14} className="text-amber-500" />
            <span>168ms Latency</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-black/[0.06] shadow-sm">
            <Shield size={14} className="text-emerald-500" />
            <span>0 Network Sockets</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-black/[0.06] shadow-sm">
            <Cpu size={14} className="text-indigo-500" />
            <span>whisper.cpp Metal GPU</span>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white border border-black/[0.06] shadow-sm">
            <Sparkles size={14} className="text-purple-500" />
            <span>100% Free & Open Source</span>
          </div>
        </div>

        {/* The Interactive Centerpiece Studio */}
        <InteractiveMacStudio />
      </div>
    </section>
  );
}
