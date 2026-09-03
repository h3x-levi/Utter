import React, { useState } from 'react';
import { Heart } from 'lucide-react';
import { motion } from 'framer-motion';

export default function CompanionPlayground() {
  const [petMood, setPetMood] = useState('Happy');
  const [hearts, setHearts] = useState([]);
  const [petCount, setPetCount] = useState(14);

  const handlePet = (e) => {
    setPetCount(petCount + 1);
    setPetMood('Purring...');

    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const newHeart = { id: Date.now(), x, y };
    setHearts((prev) => [...prev, newHeart]);

    setTimeout(() => {
      setHearts((prev) => prev.filter((h) => h.id !== newHeart.id));
    }, 1000);

    setTimeout(() => {
      setPetMood('Alert & Resting');
    }, 2000);
  };

  return (
    <section id="companions" className="py-28 px-6 relative z-10 bg-[#09090b]">
      <div className="max-w-6xl mx-auto">
        <div className="apple-panel rounded-2xl p-8 sm:p-14 border border-zinc-800 relative overflow-hidden">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 items-center">

            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-md bg-zinc-800 text-zinc-300 text-xs font-mono font-medium mb-4 border border-zinc-700">
                🐾 Desktop Pixel Pets
              </div>

              <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4 leading-tight tracking-tight">
                Your new interactive desktop coding companion.
              </h2>

              <p className="text-zinc-400 text-sm sm:text-base leading-relaxed mb-6">
                Working alone at your desk shouldn’t be lonely. Utter includes an articulated retro pixel cat and corgi pet that rests on your desktop, monitors your typing cadence, reacts to voice volume, and plays with yarn while you dictate.
              </p>

              {/* Status Box */}
              <div className="p-4 rounded-xl bg-[#121215] border border-zinc-800 mb-6 space-y-2 text-xs font-mono">
                <div className="flex items-center justify-between">
                  <span className="text-zinc-400">Companion Status:</span>
                  <span className="text-zinc-200 font-semibold">{petMood}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-zinc-400">Pets Given:</span>
                  <span className="text-zinc-200 font-semibold">{petCount} Pets</span>
                </div>
              </div>

              <div className="flex flex-wrap gap-4">
                <a
                  href="https://github.com/h3x-levi/Utter/releases/latest"
                  className="px-5 py-2.5 rounded-lg text-xs font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all shadow-md"
                >
                  Adopt Pixel Pets in Utter →
                </a>
              </div>
            </div>

            {/* Pet Interactive Canvas */}
            <div
              onClick={handlePet}
              className="relative min-h-[340px] sm:min-h-[380px] rounded-xl bg-[#121215] border border-zinc-800 p-6 flex flex-col items-center justify-between overflow-hidden shadow-2xl cursor-pointer select-none"
            >
              <div className="text-xs font-mono text-zinc-400 flex items-center gap-1.5 bg-zinc-900 px-3 py-1 rounded-full border border-zinc-800">
                <Heart className="w-3.5 h-3.5 text-zinc-300 fill-zinc-300" />
                Click anywhere to pet your desktop companion
              </div>

              {/* Floating Hearts */}
              {hearts.map((h) => (
                <motion.div
                  key={h.id}
                  initial={{ opacity: 1, scale: 0.5, y: 0 }}
                  animate={{ opacity: 0, scale: 1.3, y: -40 }}
                  transition={{ duration: 0.8 }}
                  style={{ left: h.x, top: h.y }}
                  className="absolute pointer-events-none text-zinc-100 text-sm font-bold z-30"
                >
                  Purr!
                </motion.div>
              ))}

              {/* Pet Image */}
              <div className="my-auto">
                <img
                  src="/assets/screenshots/feature-companion-showcase.png"
                  alt="Pixel Companion Showcase"
                  className="w-full max-w-xs rounded-lg border border-zinc-800 shadow-xl"
                />
              </div>

              <div className="text-xs font-mono text-zinc-500">
                4 Bundled Sprite Packs (Cat, Calico, Tuxedo, Corgi)
              </div>
            </div>

          </div>
        </div>
      </div>
    </section>
  );
}
