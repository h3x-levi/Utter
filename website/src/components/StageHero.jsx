import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Download, Github, Mic, Sparkles, ArrowRight, Play, Pause } from 'lucide-react';

export default function StageHero({ onExploreFeatures }) {
  const [isPlaying, setIsPlaying] = useState(false);

  return (
    <div className="w-full max-w-4xl mx-auto flex flex-col items-center text-center px-2">
      {/* Badge */}
      <motion.div
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="font-mono-sm text-[11px] font-semibold px-3.5 py-1 rounded-full border border-white/10 bg-white/5 backdrop-blur-md mb-4 text-zinc-300 inline-flex items-center gap-2 shadow-sm"
      >
        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
        macOS 14 & 15 Native · Apple Silicon Metal GPU · 100% On-Device
      </motion.div>

      {/* Main Headline */}
      <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-[66px] font-black leading-[1.05] tracking-tight mb-4 max-w-3xl text-white">
        Voice dictation that stays on your Mac.
      </h1>

      {/* Subtitle */}
      <p className="text-base sm:text-lg text-zinc-400 max-w-xl mb-6 leading-relaxed font-normal">
        Hold a key, speak, let go. Utter transcribes at 180 WPM using local Whisper models in unified memory - zero cloud, zero telemetry, zero latency.
      </p>

      {/* Dual CTA Buttons */}
      <div className="flex flex-wrap items-center justify-center gap-3.5 mb-6">
        <a
          href="https://github.com/h3x-levi/Utter/releases/latest"
          className="flex items-center gap-2 bg-white text-black px-7 py-3 rounded-full font-bold text-sm hover:bg-zinc-200 transition-all shadow-xl active:scale-95"
        >
          <Download size={16} />
          Download for Mac
          <span className="text-[10px] font-mono opacity-60 ml-1">v1.1.56</span>
        </a>

        <button
          onClick={onExploreFeatures}
          className="flex items-center gap-2 border border-white/15 bg-white/5 backdrop-blur-md text-white px-6 py-3 rounded-full font-semibold text-sm hover:bg-white/10 transition-all shadow-sm active:scale-95"
        >
          <Sparkles size={15} className="text-indigo-400" />
          Interactive 3D Tour
          <ArrowRight size={14} />
        </button>
      </div>

      {/* Interactive 3D Acoustic Waveform HUD Preview Card */}
      <motion.div
        initial={{ opacity: 0, scale: 0.94 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.7, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-2xl glass-panel p-4 sm:p-6 relative shadow-2xl overflow-hidden border border-white/10"
      >
        <div className="flex items-center justify-between border-b border-white/10 pb-3 mb-4">
          <div className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f56]" />
            <div className="w-2.5 h-2.5 rounded-full bg-[#ffbd2e]" />
            <div className="w-2.5 h-2.5 rounded-full bg-[#27c93f]" />
            <span className="font-mono-sm text-[11px] text-zinc-400 ml-2">Utter Liquid Glass HUD</span>
          </div>
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/10 hover:bg-white/15 text-[11px] font-medium text-white transition-colors"
          >
            {isPlaying ? <Pause size={11} /> : <Play size={11} />}
            <span>{isPlaying ? 'Listening...' : 'Simulate Dictation'}</span>
          </button>
        </div>

        {/* Dynamic Acoustic Frequency Visualizer */}
        <div className="flex items-center justify-center gap-1.5 h-12 my-1">
          {[40, 65, 85, 95, 70, 50, 80, 100, 75, 45, 90, 60, 85, 40].map((baseH, i) => (
            <motion.div
              key={i}
              animate={{
                height: isPlaying
                  ? [`${baseH * 0.3}%`, `${baseH}%`, `${baseH * 0.4}%`]
                  : [`${baseH * 0.2}%`, `${baseH * 0.4}%`, `${baseH * 0.2}%`],
                backgroundColor: isPlaying
                  ? i === 7 ? '#818cf8' : '#ffffff'
                  : '#52525b',
              }}
              transition={{
                duration: isPlaying ? 0.3 + (i % 5) * 0.08 : 1.8,
                repeat: Infinity,
                ease: 'easeInOut',
              }}
              className="w-1.5 sm:w-2 rounded-full shadow-sm"
            />
          ))}
        </div>

        {/* Live Subtitle Stream */}
        <div className="mt-3 p-3 rounded-xl bg-black/40 border border-white/5 flex items-center justify-between">
          <div className="flex items-center gap-2.5 text-left">
            <div className={`w-7 h-7 rounded-full flex items-center justify-center ${isPlaying ? 'bg-indigo-600 text-white' : 'bg-white/10 text-white/60'}`}>
              <Mic size={14} className={isPlaying ? 'animate-pulse' : ''} />
            </div>
            <div>
              <p className="text-[10px] text-zinc-400 font-mono-sm">LIVE RECOGNITION (whisper.cpp Metal)</p>
              <p className="text-xs font-semibold text-white truncate max-w-sm">
                {isPlaying
                  ? '"func generateWaveform(samples: [Float]) -> [CGFloat]"'
                  : 'Hold Fn or Space to dictate directly into Cursor, Xcode or Slack...'}
              </p>
            </div>
          </div>
          <span className="text-[10px] font-mono font-medium px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
            168ms
          </span>
        </div>
      </motion.div>
    </div>
  );
}
