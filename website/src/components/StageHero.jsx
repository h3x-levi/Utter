import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Download, Github, Mic, Sparkles, ArrowRight, Play, Pause } from 'lucide-react';

export default function StageHero({ onExploreFeatures }) {
  const [isPlaying, setIsPlaying] = useState(false);

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center text-center">
      {/* Badge */}
      <motion.div
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="font-mono-sm text-xs font-semibold px-4 py-1.5 rounded-full border border-black/10 bg-white/60 backdrop-blur-md mb-6 text-black/70 inline-flex items-center gap-2 shadow-sm"
      >
        <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
        macOS 14 & 15 Native · Apple Silicon Metal GPU · 100% On-Device
      </motion.div>

      {/* Main Headline */}
      <motion.h1
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.1 }}
        className="text-5xl sm:text-6xl md:text-[76px] font-black leading-[1.04] tracking-tight mb-6 max-w-4xl text-[#0d0d0d]"
      >
        Voice dictation that stays on your Mac.
      </motion.h1>

      {/* Subtitle */}
      <motion.p
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.2 }}
        className="text-lg sm:text-xl text-[#0d0d0d]/65 max-w-2xl mb-8 leading-relaxed font-normal"
      >
        Hold a key, speak, let go. Utter transcribes at 180 WPM using local Whisper models in unified memory — zero cloud, zero telemetry, zero latency.
      </motion.p>

      {/* Dual CTA Buttons */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3 }}
        className="flex flex-wrap items-center justify-center gap-4 mb-10"
      >
        <motion.a
          whileHover={{ scale: 1.03, y: -2 }}
          whileTap={{ scale: 0.97 }}
          href="https://github.com/h3x-levi/Utter/releases/latest"
          className="flex items-center gap-2.5 bg-[#0d0d0d] text-white px-8 py-4 rounded-full font-semibold text-[15px] hover:bg-black/85 transition-all shadow-xl"
        >
          <Download size={18} />
          Download for Mac
          <span className="text-[11px] font-mono opacity-60 ml-1">v1.1.56</span>
        </motion.a>

        <motion.button
          whileHover={{ scale: 1.03, y: -2 }}
          whileTap={{ scale: 0.97 }}
          onClick={onExploreFeatures}
          className="flex items-center gap-2.5 border-2 border-black/15 bg-white/40 backdrop-blur-sm text-[#0d0d0d] px-7 py-4 rounded-full font-semibold text-[15px] hover:bg-white/70 transition-all shadow-sm"
        >
          <Sparkles size={17} className="text-indigo-600" />
          Interactive 3D Tour
          <ArrowRight size={16} />
        </motion.button>
      </motion.div>

      {/* Interactive 3D Acoustic Waveform HUD Preview Card */}
      <motion.div
        initial={{ opacity: 0, scale: 0.92, y: 30 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-3xl glass-panel p-6 sm:p-8 relative shadow-2xl overflow-hidden"
      >
        <div className="flex items-center justify-between border-b border-black/10 pb-4 mb-6">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
            <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
            <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
            <span className="font-mono-sm text-xs text-black/40 ml-2">Utter Liquid Glass HUD · Idle State</span>
          </div>
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="flex items-center gap-2 px-3 py-1 rounded-full bg-black/5 hover:bg-black/10 text-xs font-medium text-black/70 transition-colors"
          >
            {isPlaying ? <Pause size={12} /> : <Play size={12} />}
            <span>{isPlaying ? 'Listening...' : 'Simulate Dictation'}</span>
          </button>
        </div>

        {/* Dynamic Acoustic Frequency Visualizer */}
        <div className="flex items-center justify-center gap-1.5 sm:gap-2 h-20 sm:h-24 my-2">
          {[40, 65, 85, 95, 70, 50, 80, 100, 75, 45, 90, 60, 85, 40].map((baseH, i) => (
            <motion.div
              key={i}
              animate={{
                height: isPlaying
                  ? [`${baseH * 0.3}%`, `${baseH}%`, `${baseH * 0.4}%`]
                  : [`${baseH * 0.2}%`, `${baseH * 0.4}%`, `${baseH * 0.2}%`],
                backgroundColor: isPlaying
                  ? i === 7 ? '#5f61ed' : '#0d0d0d'
                  : '#a1a1aa',
              }}
              transition={{
                duration: isPlaying ? 0.3 + (i % 5) * 0.08 : 1.8,
                repeat: Infinity,
                ease: 'easeInOut',
              }}
              className="w-2 sm:w-2.5 rounded-full shadow-sm"
            />
          ))}
        </div>

        {/* Live Subtitle Stream */}
        <div className="mt-4 p-4 rounded-2xl bg-black/[0.03] border border-black/5 flex items-center justify-between">
          <div className="flex items-center gap-3 text-left">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center ${isPlaying ? 'bg-indigo-600 text-white' : 'bg-black/10 text-black/60'}`}>
              <Mic size={16} className={isPlaying ? 'animate-pulse' : ''} />
            </div>
            <div>
              <p className="text-xs text-black/40 font-mono-sm">LIVE RECOGNITION (whisper.cpp Metal)</p>
              <p className="text-sm font-semibold text-[#0d0d0d]">
                {isPlaying
                  ? '"func generateWaveform(samples: [Float]) -> [CGFloat] { ... }"'
                  : 'Hold Fn or Space to dictate directly into Cursor, Xcode or Slack...'}
              </p>
            </div>
          </div>
          <span className="text-[11px] font-mono font-medium px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-700 border border-emerald-500/20">
            168ms latency
          </span>
        </div>
      </motion.div>
    </div>
  );
}
