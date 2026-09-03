import React, { useState } from 'react';
import { Keyboard, Volume2, Sparkles, Check } from 'lucide-react';

export default function KeyboardStudio() {
  const [activeHotkey, setActiveHotkey] = useState('Fn');
  const [playedSound, setPlayedSound] = useState(null);

  const hotkeys = [
    { name: 'Fn (Globe)', key: 'Fn', type: 'Push-to-Talk', desc: 'Hold down the Fn / Globe key in the bottom-left corner of your MacBook or Magic Keyboard.' },
    { name: 'Right Option', key: '⌥ Right', type: 'Push-to-Talk', desc: 'Ideal for right-hand resting position. Hold down Right Option while speaking.' },
    { name: 'Right Command', key: '⌘ Right', type: 'Push-to-Talk', desc: 'Ergonomic right-thumb hotkey. Dictate with natural hand placement.' },
    { name: 'Ctrl + Opt + Space', key: '⌃⌥␣', type: 'Toggle / Chord', desc: 'Hands-free toggle mode. Press once to start dictating, press again to stop.' },
  ];

  const handleKeyClick = (keyName) => {
    setActiveHotkey(keyName);
    setPlayedSound(keyName);
    setTimeout(() => setPlayedSound(null), 1000);
  };

  return (
    <section id="hotkeys" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-6xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Ergonomic Input Architecture
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Pick your perfect global hotkey.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Tapped directly through macOS IOKit and CGEventTap for zero-latency response.
          </p>
        </div>

        {/* Interactive Keyboard Canvas */}
        <div className="glass-panel rounded-3xl p-8 sm:p-14 border border-white/10">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
            {hotkeys.map((h, idx) => (
              <button
                key={idx}
                onClick={() => handleKeyClick(h.key)}
                className={`p-6 rounded-2xl text-left transition-all border flex flex-col justify-between ${
                  activeHotkey === h.key
                    ? 'bg-orange-500/20 border-orange-500/50 shadow-xl shadow-orange-500/10 scale-102'
                    : 'bg-white/5 border-white/10 hover:bg-white/10'
                }`}
              >
                <div>
                  <div className="w-12 h-12 rounded-xl bg-white/10 border border-white/15 flex items-center justify-center font-mono font-bold text-white text-lg mb-4 shadow-lg">
                    {h.key}
                  </div>
                  <h4 className="text-base font-bold text-white mb-1">{h.name}</h4>
                  <span className="text-[10px] uppercase font-mono text-orange-400 font-bold">{h.type}</span>
                </div>
                <p className="text-xs text-slate-400 mt-4 leading-relaxed">{h.desc}</p>
              </button>
            ))}
          </div>

          {/* Key Visualizer Feedback Bar */}
          <div className="p-6 rounded-2xl bg-[#0e111a] border border-white/10 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-orange-500/20 text-orange-400 flex items-center justify-center font-mono font-bold text-lg">
                {activeHotkey}
              </div>
              <div>
                <span className="text-xs font-mono text-slate-400">Active Dictation Trigger:</span>
                <div className="text-sm font-bold text-white font-mono">
                  Hold <span className="text-orange-400">{activeHotkey}</span> to record • Release to type
                </div>
              </div>
            </div>

            <div className="flex items-center gap-2 text-xs font-mono text-emerald-400">
              <Check className="w-4 h-4" />
              <span>Sub-5ms hardware event tap</span>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
