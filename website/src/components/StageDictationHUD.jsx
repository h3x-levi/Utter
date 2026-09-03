import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, Terminal, Sparkles, Zap, Check, Copy } from 'lucide-react';

export default function StageDictationHUD() {
  const [isDictating, setIsDictating] = useState(true);
  const [typedText, setTypedText] = useState('');

  const fullSample = `// Dictated via Utter with sub-200ms latency\nfunc transcribeAudioStream(buffer: AVAudioPCMBuffer) async throws -> String {\n    let whisperContext = try await LocalWhisperProvider.shared.context()\n    let tokens = whisperContext.process(samples: buffer.floatChannelData![0])\n    return tokens.joined(separator: " ")\n}`;

  useEffect(() => {
    let index = 0;
    setTypedText('');
    const interval = setInterval(() => {
      if (index < fullSample.length) {
        setTypedText(fullSample.slice(0, index + 1));
        index++;
      } else {
        clearInterval(interval);
      }
    }, 28);
    return () => clearInterval(interval);
  }, [isDictating]);

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center">
      <div className="text-center mb-8">
        <span className="font-mono-sm text-xs font-semibold px-3 py-1 rounded-full bg-black/5 text-black/60 border border-black/10">
          Push-To-Talk · Liquid Glass HUD
        </span>
        <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight mt-3 text-[#0d0d0d]">
          Dictate into any app without touching your clipboard.
        </h2>
        <p className="text-black/60 text-base sm:text-lg max-w-2xl mx-auto mt-2">
          Hold Fn or Right Option anywhere in macOS. Audio is fed into local whisper.cpp on Metal GPU, and clean text appears at your cursor.
        </p>
      </div>

      {/* Main Interactive Stage Container */}
      <div className="w-full max-w-4xl relative">
        {/* Simulated Cursor / IDE Window */}
        <div className="rounded-[24px] bg-[#1a1a1e] border border-white/10 shadow-2xl overflow-hidden text-white font-mono text-sm">
          {/* Editor Titlebar */}
          <div className="h-11 bg-[#232328] border-b border-white/10 px-5 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
              <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
              <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
              <span className="text-xs text-white/50 ml-3">TranscriptionService.swift — Xcode / Cursor</span>
            </div>
            <button
              onClick={() => setIsDictating(!isDictating)}
              className="text-xs font-sans px-3 py-1 rounded-full bg-indigo-600/80 hover:bg-indigo-600 text-white transition-colors"
            >
              Restart Simulation
            </button>
          </div>

          {/* Editor Body with Live Typing */}
          <div className="p-6 sm:p-8 min-h-[220px] sm:min-h-[260px] relative font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-emerald-300">
            <pre className="whitespace-pre-wrap">{typedText}</pre>
            <span className="inline-block w-2 h-4 bg-white animate-pulse ml-0.5 align-middle" />
          </div>
        </div>

        {/* Floating Liquid Glass Dictation Pill (Overlayed on the Editor) */}
        <motion.div
          animate={{ y: [0, -6, 0] }}
          transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute -bottom-8 left-1/2 -translate-x-1/2 z-20 w-[90%] sm:w-[540px] p-4 rounded-full nav-pill shadow-2xl border border-white/20 flex items-center justify-between gap-4"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-indigo-600 flex items-center justify-center text-white shadow-lg">
              <Mic size={18} className="animate-pulse" />
            </div>
            <div>
              <p className="text-[11px] font-mono-sm text-white/60 uppercase tracking-wider">Listening (Fn pressed)</p>
              <p className="text-sm font-semibold text-white">188 WPM · Metal Neural Engine</p>
            </div>
          </div>

          {/* Live Waveform Spectrum */}
          <div className="flex items-center gap-1 h-7 px-2">
            {[45, 80, 100, 60, 95, 75, 40, 90, 65, 85].map((h, i) => (
              <motion.div
                key={i}
                animate={{ height: [`${h * 0.3}%`, `${h}%`, `${h * 0.4}%`] }}
                transition={{ duration: 0.3 + (i % 4) * 0.08, repeat: Infinity, ease: 'easeInOut' }}
                className="w-1 bg-white rounded-full"
              />
            ))}
          </div>

          <span className="text-[10px] font-mono font-bold px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
            0% CLOUD
          </span>
        </motion.div>
      </div>
    </div>
  );
}
