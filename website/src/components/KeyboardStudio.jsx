import React, { useState } from 'react';
import { Check } from 'lucide-react';

export default function KeyboardStudio() {
  const [activeHotkey, setActiveHotkey] = useState('Fn');

  const hotkeys = [
    { name: 'Fn (Globe)', key: 'Fn', type: 'Push-to-Talk', desc: 'Hold down the Fn / Globe key in the bottom-left corner of your MacBook or Magic Keyboard.' },
    { name: 'Double-Tap Fn', key: 'Fn × 2', type: 'Hands-Free', desc: 'Double-tap your hotkey to lock continuous hands-free dictation without holding down any keys.' },
    { name: 'Right Option', key: '⌥ Right', type: 'Push-to-Talk', desc: 'Ideal for right-hand resting position. Hold down Right Option while speaking.' },
    { name: 'Right Command', key: '⌘ Right', type: 'Push-to-Talk', desc: 'Ergonomic right-thumb hotkey. Dictate with natural hand placement.' },
    { name: 'Ctrl + Opt + Space', key: '⌃⌥␣', type: 'Toggle Mode', desc: 'Hands-free toggle mode. Press once to start dictating, press again to stop.' },
  ];

  return (
    <section id="hotkeys" className="py-28 px-6 relative z-10 bg-[#0c0c0e]">
      <div className="max-w-6xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Ergonomic Input Architecture
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Pick your perfect global hotkey.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Tapped directly through macOS IOKit and CGEventTap for zero-latency response.
          </p>
        </div>

        {/* Interactive Keyboard Canvas */}
        <div className="apple-panel rounded-2xl p-8 sm:p-12 border border-zinc-800">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
            {hotkeys.map((h, idx) => (
              <button
                key={idx}
                onClick={() => setActiveHotkey(h.key)}
                className={`p-5 rounded-xl text-left transition-all border flex flex-col justify-between ${
                  activeHotkey === h.key
                    ? 'bg-zinc-800 border-zinc-500 text-white shadow-lg'
                    : 'bg-zinc-900/60 border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'
                }`}
              >
                <div>
                  <div className="w-10 h-10 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center font-mono font-bold text-white text-sm mb-3">
                    {h.key}
                  </div>
                  <h4 className="text-sm font-semibold text-white mb-0.5">{h.name}</h4>
                  <span className="text-[10px] uppercase font-mono text-zinc-500">{h.type}</span>
                </div>
                <p className="text-xs text-zinc-400 mt-3 leading-relaxed">{h.desc}</p>
              </button>
            ))}
          </div>

          {/* Key Visualizer Feedback Bar */}
          <div className="p-5 rounded-xl bg-[#09090b] border border-zinc-800 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-lg bg-zinc-800 text-white flex items-center justify-center font-mono font-bold text-sm border border-zinc-700">
                {activeHotkey}
              </div>
              <div>
                <span className="text-xs font-mono text-zinc-500">Configured Dictation Trigger:</span>
                <div className="text-xs font-semibold text-white font-mono">
                  Hold <span className="text-zinc-200">{activeHotkey}</span> to record • Release to type
                </div>
              </div>
            </div>

            <div className="flex items-center gap-2 text-xs font-mono text-zinc-400">
              <Check className="w-3.5 h-3.5 text-zinc-300" />
              <span>Sub-5ms hardware event tap</span>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
