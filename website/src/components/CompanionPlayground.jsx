import React, { useState } from 'react';
import { Heart, Sparkles, Smile, Gamepad2, Award } from 'lucide-react';
import { motion } from 'framer-motion';

export default function CompanionPlayground() {
  const [petMood, setPetMood] = useState('Happy');
  const [hearts, setHearts] = useState([]);
  const [petCount, setPetCount] = useState(14);

  const handlePet = (e) => {
    setPetCount(petCount + 1);
    setPetMood('Delighted! Purring...');

    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const newHeart = { id: Date.now(), x, y };
    setHearts((prev) => [...prev, newHeart]);

    setTimeout(() => {
      setHearts((prev) => prev.filter((h) => h.id !== newHeart.id));
    }, 1200);

    setTimeout(() => {
      setPetMood('Alert & Listening');
    }, 2500);
  };

  return (
    <section id="companions" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-6xl mx-auto">
        <div className="glass-panel rounded-3xl p-8 sm:p-14 border border-orange-500/20 relative overflow-hidden">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">

            <div>
              <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-orange-500/10 text-orange-400 text-xs font-mono font-bold mb-6 border border-orange-500/25">
                🐾 Nostalgic Desktop Pixel Pets
              </div>

              <h2 className="text-3xl sm:text-5xl font-extrabold text-white mb-6 leading-tight tracking-tight">
                Your new interactive desktop coding buddy.
              </h2>

              <p className="text-slate-300 text-base sm:text-lg leading-relaxed mb-8">
                Working alone at your desk shouldn’t be lonely. Utter includes an articulated retro pixel cat and corgi pet that rests on your desktop, monitors your typing cadence, reacts to voice volume, and plays with yarn while you dictate.
              </p>

              {/* Interactive Pet Sandbox Controls */}
              <div className="p-4 rounded-2xl bg-white/5 border border-white/10 mb-8 space-y-3">
                <div className="flex items-center justify-between text-xs font-mono">
                  <span className="text-slate-400">Current Companion Status:</span>
                  <span className="text-orange-400 font-bold flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-orange-400 animate-ping"></span>
                    {petMood}
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs font-mono">
                  <span className="text-slate-400">Friendship / Pets Given:</span>
                  <span className="text-emerald-400 font-bold">{petCount} Pets</span>
                </div>
              </div>

              <div className="flex flex-wrap gap-4">
                <a
                  href="https://github.com/h3x-levi/Utter/releases/latest"
                  className="px-6 py-3.5 rounded-xl text-sm font-bold bg-orange-500 hover:bg-orange-600 text-white shadow-lg shadow-orange-500/25 transition-all hover:scale-105 active:scale-95"
                >
                  Adopt Pixel Pets in Utter →
                </a>
              </div>
            </div>

            {/* Interactive Pet Sandbox Display */}
            <div
              onClick={handlePet}
              className="relative min-h-[380px] sm:min-h-[440px] rounded-2xl bg-[#121520] border border-white/15 p-8 flex flex-col items-center justify-between overflow-hidden shadow-2xl cursor-pointer select-none group"
            >
              {/* Top Hint */}
              <div className="text-xs font-mono text-slate-400 flex items-center gap-2 bg-black/40 px-3 py-1.5 rounded-full border border-white/10">
                <Heart className="w-3.5 h-3.5 text-rose-500 fill-rose-500" />
                Click anywhere to pet your desktop companion!
              </div>

              {/* Floating Hearts */}
              {hearts.map((h) => (
                <motion.div
                  key={h.id}
                  initial={{ opacity: 1, scale: 0.5, y: 0 }}
                  animate={{ opacity: 0, scale: 1.5, y: -60 }}
                  transition={{ duration: 1 }}
                  style={{ left: h.x, top: h.y }}
                  className="absolute pointer-events-none text-rose-500 text-xl font-bold z-30"
                >
                  ❤️ Purr!
                </motion.div>
              ))}

              {/* Pet Image Showcase */}
              <div className="my-auto relative">
                <div className="absolute inset-0 rounded-full bg-orange-500/20 blur-3xl group-hover:scale-125 transition-transform duration-500"></div>
                <img
                  src="/assets/screenshots/feature-companion-showcase.png"
                  alt="Pixel Companion Showcase"
                  className="relative z-10 w-full max-w-sm rounded-xl border border-white/10 shadow-2xl group-hover:scale-105 transition-transform duration-300"
                />
              </div>

              {/* Bottom Mood Status */}
              <div className="text-xs font-mono text-slate-300 flex items-center gap-3">
                <span className="px-2.5 py-1 rounded-md bg-white/10 text-orange-400">4 Companion Packs</span>
                <span className="px-2.5 py-1 rounded-md bg-white/10 text-slate-300">Cat • Calico • Tuxedo • Corgi</span>
              </div>
            </div>

          </div>
        </div>
      </div>
    </section>
  );
}
