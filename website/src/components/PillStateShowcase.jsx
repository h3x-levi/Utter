import React, { useState } from 'react';
import { Mic, Lock, Loader2, FileText, Bug, Eye } from 'lucide-react';
import { motion } from 'framer-motion';

export default function PillStateShowcase() {
  const [selectedState, setSelectedState] = useState(1);

  const states = [
    {
      id: 0,
      name: 'Idle Notch',
      tag: 'Resting State',
      icon: <Eye className="w-4 h-4 text-zinc-400" />,
      desc: 'Floating minimally in the menu bar or desktop margin. Zero CPU usage until triggered.',
      pillUI: (
        <div className="apple-pill rounded-full px-5 py-2.5 flex items-center gap-3 border border-zinc-700 shadow-2xl">
          <div className="w-6 h-6 rounded-full bg-zinc-800 flex items-center justify-center text-zinc-300">
            <Mic className="w-3.5 h-3.5" />
          </div>
          <span className="text-xs font-mono text-zinc-400">Ready • Hold Fn</span>
        </div>
      ),
    },
    {
      id: 1,
      name: 'Live 7-Bar Waveform',
      tag: 'Active Dictation',
      icon: <Mic className="w-4 h-4 text-white" />,
      desc: 'Fluid dynamic 7-bar audio spectrum responding in real time to microphone amplitude.',
      pillUI: (
        <div className="apple-pill rounded-full px-6 py-3 flex items-center gap-4 border border-zinc-500 bg-zinc-900 shadow-2xl">
          <div className="w-7 h-7 rounded-full bg-white flex items-center justify-center text-black">
            <Mic className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-center gap-1.5 h-5">
            {[8, 14, 20, 24, 20, 14, 8].map((h, i) => (
              <div
                key={i}
                className="w-1 bg-white rounded-full animate-wave-bar"
                style={{ height: `${h}px`, animationDelay: `${i * 0.1}s` }}
              />
            ))}
          </div>
          <span className="text-xs font-mono font-medium text-white">Listening (16kHz PCM)...</span>
        </div>
      ),
    },
    {
      id: 2,
      name: 'Hands-Free Lock',
      tag: 'Continuous Dictation',
      icon: <Lock className="w-4 h-4 text-zinc-300" />,
      desc: 'Double-tap hotkey or toggle hands-free mode for continuous stream-of-consciousness dictation without holding down keys.',
      pillUI: (
        <div className="apple-pill rounded-full px-6 py-3 flex items-center gap-4 border border-zinc-600 bg-zinc-900 shadow-2xl">
          <div className="w-7 h-7 rounded-full bg-zinc-800 flex items-center justify-center text-white">
            <Lock className="w-3.5 h-3.5" />
          </div>
          <div className="flex items-center gap-1 h-4">
            {[10, 14, 10, 16, 10].map((h, i) => (
              <div key={i} className="w-1 bg-zinc-400 rounded-full animate-pulse" style={{ height: `${h}px` }} />
            ))}
          </div>
          <span className="text-xs font-mono text-zinc-300 font-medium">Hands-Free Locked • Esc to stop</span>
        </div>
      ),
    },
    {
      id: 3,
      name: 'Sub-200ms Processing',
      tag: 'Metal Compute',
      icon: <Loader2 className="w-4 h-4 text-zinc-300" />,
      desc: 'Instant whisper.cpp execution on Apple Silicon GPU shaders. Typical latency is 168ms.',
      pillUI: (
        <div className="apple-pill rounded-full px-6 py-3 flex items-center gap-3 border border-zinc-600 bg-zinc-900 shadow-2xl">
          <Loader2 className="w-4 h-4 text-white animate-spin" />
          <span className="text-xs font-mono text-white font-medium">Metal GPU Processing (0.16s)...</span>
        </div>
      ),
    },
    {
      id: 4,
      name: 'Quick Note Scratchpad',
      tag: 'Morphing Capture Box',
      icon: <FileText className="w-4 h-4 text-zinc-300" />,
      desc: 'Press Ctrl+Opt+N to morph the pill into a floating Markdown note capture card with instant AI actions.',
      pillUI: (
        <div className="apple-panel rounded-xl p-5 w-80 border border-zinc-700 shadow-2xl bg-[#141418]">
          <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-2">
            <span>📝 Quick Note</span>
            <span>Auto-Saved</span>
          </div>
          <p className="text-xs text-zinc-200 font-mono leading-relaxed">
            # Architecture Review\n- Decided on Metal zero-copy ring buffers for sub-200ms audio ingest.
          </p>
        </div>
      ),
    },
    {
      id: 5,
      name: 'Issue & Feedback Reporter',
      tag: '1-Click GitHub Issues',
      icon: <Bug className="w-4 h-4 text-zinc-300" />,
      desc: 'Press Cmd+I to open the in-app diagnostics and bug reporting sheet with pre-filled GitHub issue creation.',
      pillUI: (
        <div className="apple-panel rounded-xl p-5 w-80 border border-zinc-700 shadow-2xl bg-[#141418]">
          <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-2">
            <span>🐞 Report Issue (Cmd+I)</span>
            <span>Sanitized</span>
          </div>
          <p className="text-xs text-zinc-300 font-mono">
            Auto-attaches sanitized macOS version, Metal GPU core count & speech model stats.
          </p>
        </div>
      ),
    },
  ];

  return (
    <section id="pill-states" className="py-28 px-6 relative z-10 bg-[#0c0c0e]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Dynamic Liquid Glass HUD
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            One floating pill. Six fluid morphing states.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Never intrusive. Utter's HUD appears when you speak and disappears the millisecond you're done.
          </p>
        </div>

        {/* State Selector Tabs */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-10">
          {states.map((st) => (
            <button
              key={st.id}
              onClick={() => setSelectedState(st.id)}
              className={`p-4 rounded-xl text-left transition-all border flex flex-col justify-between ${
                selectedState === st.id
                  ? 'bg-zinc-800 border-zinc-500 text-white shadow-lg'
                  : 'bg-zinc-900/60 border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'
              }`}
            >
              <div className="mb-3">{st.icon}</div>
              <div>
                <h5 className="text-xs font-semibold text-white mb-0.5">{st.name}</h5>
                <span className="text-[10px] uppercase font-mono text-zinc-500">{st.tag}</span>
              </div>
            </button>
          ))}
        </div>

        {/* Preview Canvas */}
        <div className="apple-panel rounded-2xl p-8 sm:p-14 border border-zinc-800 flex flex-col items-center justify-center min-h-[340px] relative overflow-hidden bg-[#101013]">
          <motion.div
            key={selectedState}
            initial={{ opacity: 0, scale: 0.95, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.25 }}
            className="z-10 mb-8"
          >
            {states[selectedState].pillUI}
          </motion.div>

          <p className="text-zinc-400 text-center text-xs sm:text-sm max-w-lg z-10 font-medium">
            {states[selectedState].desc}
          </p>
        </div>

      </div>
    </section>
  );
}
