import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart, Sparkles, Play, Code2, Eye, Cpu } from 'lucide-react';
import CodeCompanionCanvas from './CodeCompanionCanvas';
import CompanionCharacterPicker, { CHARACTERS } from './CompanionCharacterPicker';

const COMPANIONS = [
  {
    id: 'charcoal-cat',
    aliasId: 'gray',
    name: 'Charcoal Cat',
    species: 'cat',
    isGinger: false,
    description:
      'Sleek dark obsidian coat drawn at runtime. Sits quietly beside your code editor, tracks your typing cadence, and waves cheerfully.',
    color: '#38bdf8',
    quotes: {
      waving: 'Meow! Charcoal Cat greets you at 60 FPS! 👋',
      knead: 'Stealth biscuit kneading on mechanical switches... 🧶',
      walk: 'Strolling across the window bezel in 4-leg gait... 🐾',
      loaf: 'Charcoal loaf form: low power, 0% CPU at rest. 🍞',
      thinking: 'Optimizing Metal GPU matrix multiplies... 🤔',
      delighted: 'Sub-200ms speech injection verified! Purr! 🏆',
    },
  },
  {
    id: 'ginger-cat',
    aliasId: 'orange',
    name: 'Ginger Cat',
    species: 'cat',
    isGinger: true,
    description:
      'Drawn 100% in code. Alternates front paws on mechanical keypads during dictation and tucks into a warm bread loaf when resting.',
    color: '#f97316',
    quotes: {
      waving: 'Purring hello! Waving front paw at your cursor! 👋',
      knead: 'Kneading mechanical keyboard pads at 180 WPM! 🧶',
      walk: 'Patrolling desktop display borders in 4-leg pixel gait... 🐾',
      loaf: 'Tucked cleanly into bread loaf mode. Zzz 🍞',
      thinking: 'Evaluating whisper.cpp token probabilities... 🤔',
      delighted: 'Sprint goal accomplished! Purring at 60 FPS! 🎉',
    },
  },
  {
    id: 'pixel-dog',
    aliasId: 'dog',
    name: 'Pixel Dog',
    species: 'dog',
    isGinger: false,
    description:
      'Enthusiastic companion with floppy brown ears. Wags tail with joy whenever your dictation completes with sub-200ms latency.',
    color: '#f59e0b',
    quotes: {
      waving: 'Woof! Ready to transcribe your next big brainstorm! 👋',
      knead: 'Digging for custom vocabulary boosts! 🦴',
      walk: 'Fetching speech tokens at 16,000Hz PCM! 🐕',
      loaf: 'Resting beside your Dock after meeting transcription 💤',
      thinking: 'Sniffing zero cloud network sockets... air-gapped! 🐾',
      delighted: 'Woof! Tail wagging at 60 FPS vector cadence! 🎉',
    },
  },
  {
    id: 'pixel-panda',
    aliasId: 'panda',
    name: 'Pixel Panda',
    species: 'panda',
    isGinger: false,
    description:
      'Mindful dictation monk. Keeps you calm during intense deadlines with deep breathing loafs, iconic eye patches, and zero cloud dependencies.',
    color: '#a78bfa',
    quotes: {
      waving: 'Peaceful greetings. Air-gapped on Apple Silicon. 👋',
      knead: 'Formatting clean Markdown meeting summaries 🍃',
      walk: 'Rhythmic typing cadence wins the engineering sprint 🎋',
      loaf: 'Deep slumber. Audio never leaves this Mac 😴',
      thinking: 'Meditating on local Apple FoundationModels 🧘',
      delighted: 'Zero-latency flow state unlocked! 🎊',
    },
  },
];

const ACTIONS = [
  { id: 'waving', label: 'Wave Hello', icon: '👋' },
  { id: 'knead', label: 'Knead Keypads', icon: '🧶' },
  { id: 'walk', label: '4-Leg Walk', icon: '🐾' },
  { id: 'loaf', label: 'Loaf Sleep', icon: '🍞' },
  { id: 'delighted', label: 'Delighted', icon: '🎉' },
];

export default function CompanionHabitat() {
  const [activePetIndex, setActivePetIndex] = useState(0); // Charcoal Cat by default
  const [activeAction, setActiveAction] = useState('waving');
  const [happiness, setHappiness] = useState(98);
  const [isPetted, setIsPetted] = useState(false);

  const pet = COMPANIONS[activePetIndex];

  const handlePet = () => {
    setIsPetted(true);
    setHappiness((prev) => Math.min(100, prev + 2));
    setTimeout(() => setIsPetted(false), 1200);
  };

  return (
    <section id="companions" className="relative py-14 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto z-10">
      <motion.div
        initial={{ opacity: 0, scale: 0.94, y: 25 }}
        whileInView={{ opacity: 1, scale: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
      >
        {/* Section Header */}
        <div className="flex flex-col items-center text-center mb-8">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-3 border border-orange-500/20">
            <Sparkles size={13} />
            <span>CODE-RENDERED COMPANION ENGINE</span>
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-2.5">
            Rendered purely in code at runtime.
          </h2>
          <p className="text-zinc-300 text-sm sm:text-base max-w-[660px]">
            Zero bundled PNG artwork. Utter draws its companions directly at runtime (<code className="text-orange-300 font-mono text-xs">CodePixelCat.swift</code>) with smooth vector curves, real-time cursor pupil tracking, and 60 FPS gait cycles.
          </p>
        </div>

        {/* Authentic macOS Native Character Picker Component (Matching User Screenshot) */}
        <div className="max-w-[760px] mx-auto mb-8">
          <CompanionCharacterPicker
            selectedId={pet.id}
            onSelect={(selectedChar) => {
              const idx = COMPANIONS.findIndex(
                (p) => p.id === selectedChar.id || p.aliasId === selectedChar.aliasId
              );
              if (idx !== -1) setActivePetIndex(idx);
            }}
          />
        </div>

        {/* Interactive Companion Habitat Stage */}
        <div className="liquid-glass rounded-3xl p-6 sm:p-8 border border-white/20 shadow-2xl relative overflow-hidden">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
            {/* Visual Interactive Canvas Stage (7 cols) */}
            <div className="lg:col-span-7 flex flex-col items-center justify-center min-h-[360px] bg-gradient-to-b from-zinc-900/90 to-zinc-950/95 rounded-2xl border border-white/10 p-6 relative overflow-hidden select-none">
              {/* Dialogue Bubble */}
              <AnimatePresence mode="wait">
                <motion.div
                  key={activeAction + pet.id}
                  initial={{ opacity: 0, y: 8, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0 }}
                  className="absolute top-4 px-4 py-2 rounded-xl bg-zinc-800/90 text-zinc-100 text-xs font-mono border border-white/15 shadow-lg max-w-[360px] text-center"
                >
                  {pet.quotes[activeAction] || pet.quotes.waving}
                </motion.div>
              </AnimatePresence>

              {/* Procedural Code Canvas Companion */}
              <div
                onClick={handlePet}
                className="relative cursor-pointer group flex flex-col items-center mt-8"
                title="Click to pet!"
              >
                {/* Floating Love Heart */}
                <AnimatePresence>
                  {isPetted && (
                    <motion.div
                      initial={{ opacity: 0, y: 0, scale: 0.5 }}
                      animate={{ opacity: 1, y: -45, scale: 1.4 }}
                      exit={{ opacity: 0 }}
                      className="absolute -top-6 text-red-400 text-xl font-bold flex items-center gap-1 z-30"
                    >
                      <Heart size={22} className="fill-red-400" />
                      <span className="text-xs font-mono text-white">+Love</span>
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Pure Code Canvas */}
                <CodeCompanionCanvas
                  species={pet.species}
                  isGinger={pet.isGinger}
                  action={activeAction}
                  width={220}
                  height={220}
                />

                <div className="mt-2 text-[11px] font-mono text-zinc-400 opacity-75 group-hover:opacity-100 transition-opacity flex items-center gap-1.5">
                  <Eye size={12} className="text-orange-400" />
                  <span>Pupil gaze tracks cursor across screen • Click to pet</span>
                </div>
              </div>

              {/* Status Bar */}
              <div className="absolute bottom-3 left-4 right-4 flex items-center justify-between text-xs font-mono text-zinc-400 border-t border-white/5 pt-2.5">
                <div className="flex items-center gap-1.5">
                  <Heart size={14} className="text-red-400 fill-red-400" />
                  <span>Affection: {happiness}%</span>
                </div>
                <div className="flex items-center gap-1 text-emerald-400 font-semibold">
                  <Cpu size={13} />
                  <span>60 FPS Vector Companion Canvas</span>
                </div>
              </div>
            </div>

            {/* Right Column: Controls & Information (5 cols) */}
            <div className="lg:col-span-5 flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2 text-xs font-mono text-orange-400 mb-1.5">
                  <span>PROCEDURAL VECTOR ENGINE</span>
                  <span>•</span>
                  <span className="text-zinc-300">{pet.name}</span>
                </div>
                <h3 className="text-2xl font-bold text-white mb-2">{pet.name}</h3>
                <p className="text-zinc-300 text-xs sm:text-sm leading-relaxed mb-5">
                  {pet.description}
                </p>

                {/* Action Trigger Buttons */}
                <div className="space-y-2 mb-5">
                  <div className="text-xs uppercase font-mono text-zinc-300 tracking-wider mb-2">
                    Trigger Interactive Motion:
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    {ACTIONS.map((act) => (
                      <button
                        key={act.id}
                        onClick={() => setActiveAction(act.id)}
                        className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium border transition-all duration-150 ${
                          activeAction === act.id
                            ? 'bg-orange-500 text-zinc-950 font-bold border-orange-400 shadow-md scale-[1.02]'
                            : 'liquid-glass text-zinc-200 border-white/10 hover:bg-zinc-800/60'
                        }`}
                      >
                        <Play size={10} className={activeAction === act.id ? 'fill-zinc-950' : 'text-orange-400'} />
                        <span>{act.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              {/* Code Vector Architecture Notice */}
              <div className="p-3.5 rounded-2xl bg-zinc-950/70 border border-white/10 text-xs text-zinc-300 font-mono space-y-1">
                <div className="text-white font-semibold flex items-center gap-1.5">
                  <Code2 size={13} className="text-orange-400" />
                  <span>Drawn in Code by Utter</span>
                </div>
                <p className="text-[11px] text-zinc-400 leading-normal">
                  Zero static PNG assets bundled. The native Swift companion engine (<code className="text-orange-300">CodePixelCat.swift</code>) executes smooth vector path math at 60 FPS with sub-millisecond draw calls.
                </p>
              </div>
            </div>
          </div>
        </div>
      </motion.div>
    </section>
  );
}
