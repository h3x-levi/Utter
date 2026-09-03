import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Heart, Sparkles, Smile, MessageSquare, Coffee, Trophy } from 'lucide-react';

export default function StageCompanionSandbox() {
  const [petMood, setPetMood] = useState('Delighted');
  const [speechBubble, setSpeechBubble] = useState('Meow! 188 WPM dictation rate!');
  const [friendshipLevel, setFriendshipLevel] = useState(4);
  const [activeToy, setActiveToy] = useState('yarn');

  const triggerAction = (action, toy, bubble) => {
    setActiveToy(toy);
    setPetMood(action);
    setSpeechBubble(bubble);
    setFriendshipLevel((prev) => Math.min(prev + 1, 10));
  };

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center">
      <div className="text-center mb-8">
        <span className="font-mono-sm text-xs font-semibold px-3 py-1 rounded-full bg-white/5 text-zinc-400 border border-white/10">
          Articulated Sprite Engine · Sensory Companion
        </span>
        <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight mt-3 text-white">
          A desktop companion that reacts to your voice.
        </h2>
        <p className="text-zinc-400 text-base sm:text-lg max-w-2xl mx-auto mt-2">
          Retro pixel pets that sit on your window edge, track your cursor with their gaze, level up friendship, and celebrate your coding velocity.
        </p>
      </div>

      {/* Interactive Companion Sandbox Window */}
      <div className="w-full max-w-4xl rounded-[24px] bg-[#1e1e24]/95 backdrop-blur-2xl border border-white/10 shadow-2xl overflow-hidden text-white">
        <div className="h-12 bg-[#282830] border-b border-white/10 px-5 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
            <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
            <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
            <span className="text-xs font-semibold text-white/90 ml-3">Companion Workspace — Pixel Cat Sandbox</span>
          </div>

          <div className="flex items-center gap-2 text-xs font-mono text-amber-400 bg-amber-400/10 px-3 py-1 rounded-full border border-amber-400/20">
            <Trophy size={13} />
            <span>Friendship Level {friendshipLevel}/10</span>
          </div>
        </div>

        {/* Sandbox Stage */}
        <div className="p-8 sm:p-12 relative min-h-[300px] flex flex-col items-center justify-center bg-gradient-to-b from-[#24242c] to-[#1a1a20]">
          {/* Speech Bubble */}
          <AnimatePresence mode="wait">
            <motion.div
              key={speechBubble}
              initial={{ opacity: 0, y: 10, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              className="mb-4 px-4 py-2 rounded-2xl bg-white text-white font-medium text-xs sm:text-sm shadow-xl relative"
            >
              {speechBubble}
              {/* Bubble Tail */}
              <div className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-0 h-0 border-l-[6px] border-l-transparent border-r-[6px] border-r-transparent border-t-[8px] border-t-white" />
            </motion.div>
          </AnimatePresence>

          {/* Animated Pixel Cat Art */}
          <motion.div
            animate={{
              y: [0, -8, 0],
              rotate: activeToy === 'laser' ? [-3, 3, -3] : [0, 0, 0],
            }}
            transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
            className="w-28 h-28 sm:w-32 sm:h-32 rounded-3xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center relative shadow-2xl"
          >
            <div className="text-6xl sm:text-7xl select-none">
              {petMood === 'Delighted' ? '😺' : petMood === 'Playful' ? '😸' : petMood === 'Snack' ? '😻' : '🐾'}
            </div>
          </motion.div>

          {/* Status Chip */}
          <div className="mt-4 text-xs font-mono text-white/50 flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
            <span>Mood: {petMood} · Reacting to Microphone</span>
          </div>
        </div>

        {/* Interactive Action Toolbar */}
        <div className="p-4 sm:p-6 bg-black/40 border-t border-white/5 flex flex-wrap items-center justify-center gap-3">
          <button
            onClick={() => triggerAction('Playful', 'yarn', 'Playing with yarn! 🧶')}
            className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all ${
              activeToy === 'yarn' ? 'bg-indigo-600 text-white shadow-lg' : 'bg-white/10 hover:bg-white/15 text-white/80'
            }`}
          >
            🧶 Toss Yarn Ball
          </button>

          <button
            onClick={() => triggerAction('Snack', 'fish', 'Yum! Fresh fish snack! 🐟')}
            className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all ${
              activeToy === 'fish' ? 'bg-amber-600 text-white shadow-lg' : 'bg-white/10 hover:bg-white/15 text-white/80'
            }`}
          >
            🐟 Feed Snack
          </button>

          <button
            onClick={() => triggerAction('Playful', 'laser', 'Chasing the red dot! 🔴')}
            className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all ${
              activeToy === 'laser' ? 'bg-rose-600 text-white shadow-lg' : 'bg-white/10 hover:bg-white/15 text-white/80'
            }`}
          >
            🔴 Laser Pointer
          </button>

          <button
            onClick={() => triggerAction('Delighted', 'pet', '*purrrrrrrrr* ❤️')}
            className="px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold bg-white/10 hover:bg-white/15 text-white/80 transition-all flex items-center gap-1.5"
          >
            <Heart size={14} className="text-rose-400" />
            Pet Head
          </button>
        </div>
      </div>
    </div>
  );
}
