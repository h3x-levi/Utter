import React, { useState } from 'react';
import { Mic, Lock, Loader2, FileText, Bug, Eye, Sparkles } from 'lucide-react';
import { motion } from 'framer-motion';

export default function PillStateShowcase() {
  const [selectedState, setSelectedState] = useState(1);

  const states = [
    {
      id: 0,
      name: 'Idle Notch',
      tag: 'Resting State',
      icon: <Eye className="w-4 h-4 text-slate-400" />,
      desc: 'Floating minimally in the menu bar or desktop margin. Zero CPU usage until triggered.',
      pillUI: (
        <div className="glass-pill rounded-full px-5 py-2.5 flex items-center gap-3 border border-white/15 shadow-2xl">
          <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center text-slate-300">
            <Mic className="w-3.5 h-3.5" />
          </div>
          <span className="text-xs font-mono text-slate-400">Ready • Hold Fn</span>
        </div>
      ),
    },
    {
      id: 1,
      name: 'Live 7-Bar Waveform',
      tag: 'Active Dictation',
      icon: <Mic className="w-4 h-4 text-orange-400" />,
      desc: 'Fluid dynamic 7-bar audio spectrum responding in real time to microphone amplitude.',
      pillUI: (
        <div className="glass-pill rounded-full px-6 py-3 flex items-center gap-4 border border-orange-500 bg-orange-950/40 shadow-2xl shadow-orange-500/20">
          <div className="w-7 h-7 rounded-full bg-orange-500 flex items-center justify-center text-white">
            <Mic className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-center gap-1.5 h-6">
            {[10, 16, 22, 26, 22, 16, 10].map((h, i) => (
              <div
                key={i}
                className="w-1.5 bg-orange-400 rounded-full animate-wave-bar"
                style={{ height: `${h}px`, animationDelay: `${i * 0.1}s` }}
              />
            ))}
          </div>
          <span className="text-xs font-mono font-semibold text-orange-400">Listening (16kHz PCM)...</span>
        </div>
      ),
    },
    {
      id: 2,
      name: 'Hands-Free Lock',
      tag: 'Continuous Dictation',
      icon: <Lock className="w-4 h-4 text-amber-400" />,
      desc: 'Double-tap hotkey or toggle hands-free mode for continuous stream-of-consciousness dictation without holding down keys.',
      pillUI: (
        <div className="glass-pill rounded-full px-6 py-3 flex items-center gap-4 border border-amber-500/50 bg-amber-950/30 shadow-2xl">
          <div className="w-7 h-7 rounded-full bg-amber-500 flex items-center justify-center text-white">
            <Lock className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-center gap-1 h-5">
            {[14, 18, 14, 20, 14].map((h, i) => (
              <div key={i} className="w-1.5 bg-amber-400 rounded-full animate-pulse" style={{ height: `${h}px` }} />
            ))}
          </div>
          <span className="text-xs font-mono text-amber-300 font-semibold">Hands-Free Locked • Esc to stop</span>
        </div>
      ),
    },
    {
      id: 3,
      name: 'Sub-200ms Processing',
      tag: 'Metal Compute',
      icon: <Loader2 className="w-4 h-4 text-indigo-400" />,
      desc: 'Instant whisper.cpp execution on Apple Silicon GPU shaders. Typical latency is 168ms.',
      pillUI: (
        <div className="glass-pill rounded-full px-6 py-3 flex items-center gap-3 border border-indigo-500/40 bg-indigo-950/30 shadow-2xl">
          <Loader2 className="w-5 h-5 text-indigo-400 animate-spin" />
          <span className="text-xs font-mono text-indigo-300 font-semibold">Metal GPU Processing (0.16s)...</span>
        </div>
      ),
    },
    {
      id: 4,
      name: 'Quick Note Scratchpad',
      tag: 'Morphing Capture Box',
      icon: <FileText className="w-4 h-4 text-sky-400" />,
      desc: 'Press Ctrl+Opt+N to morph the pill into a floating Markdown note capture card with instant AI actions.',
      pillUI: (
        <div className="glass-panel rounded-2xl p-5 w-80 border border-sky-500/30 shadow-2xl bg-[#121624]">
          <div className="flex items-center justify-between text-xs font-mono text-sky-400 mb-2">
            <span>📝 Quick Note</span>
            <span>Auto-Saved</span>
          </div>
          <p className="text-xs text-slate-200 font-mono leading-relaxed">
            # Architecture Review\n- Decided on Metal zero-copy ring buffers for sub-200ms audio ingest.
          </p>
        </div>
      ),
    },
    {
      id: 5,
      name: 'Issue & Feedback Reporter',
      tag: '1-Click GitHub Issues',
      icon: <Bug className="w-4 h-4 text-rose-400" />,
      desc: 'Press Cmd+I to open the in-app diagnostics and bug reporting sheet with pre-filled GitHub issue creation.',
      pillUI: (
        <div className="glass-panel rounded-2xl p-5 w-80 border border-rose-500/30 shadow-2xl bg-[#1a141a]">
          <div className="flex items-center justify-between text-xs font-mono text-rose-400 mb-2">
            <span>🐞 Report Issue (Cmd+I)</span>
            <span>Sanitized</span>
          </div>
          <p className="text-xs text-slate-300 font-mono">
            Auto-attaches sanitized macOS version, Metal GPU core count & speech model stats.
          </p>
        </div>
      ),
    },
  ];

  return (
    <section id="pill-states" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Dynamic Liquid Glass HUD
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            One floating pill. Six fluid morphing states.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Never intrusive. Utter's HUD appears when you speak and disappears the millisecond you're done.
          </p>
        </div>

        {/* State Selector Tabs */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-12">
          {states.map((st) => (
            <button
              key={st.id}
              onClick={() => setSelectedState(st.id)}
              className={`p-4 rounded-2xl text-left transition-all border flex flex-col justify-between ${
                selectedState === st.id
                  ? 'bg-orange-500/20 border-orange-500/50 shadow-lg shadow-orange-500/10 scale-102'
                  : 'bg-white/5 border-white/10 hover:bg-white/10'
              }`}
            >
              <div className="mb-3">{st.icon}</div>
              <div>
                <h5 className="text-sm font-bold text-white mb-1">{st.name}</h5>
                <span className="text-[10px] uppercase font-mono text-slate-400">{st.tag}</span>
              </div>
            </button>
          ))}
        </div>

        {/* Interactive Preview Canvas */}
        <div className="glass-panel rounded-3xl p-8 sm:p-14 border border-white/10 flex flex-col items-center justify-center min-h-[360px] relative overflow-hidden bg-gradient-to-b from-[#121520] to-[#0d0f17]">
          <div className="absolute inset-0 bg-radial-gradient from-orange-500/10 to-transparent pointer-events-none blur-2xl"></div>

          {/* Render Active Pill UI */}
          <motion.div
            key={selectedState}
            initial={{ opacity: 0, scale: 0.9, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.3 }}
            className="z-10 mb-8"
          >
            {states[selectedState].pillUI}
          </motion.div>

          <p className="text-slate-300 text-center text-sm sm:text-base max-w-lg z-10">
            {states[selectedState].desc}
          </p>
        </div>

      </div>
    </section>
  );
}
