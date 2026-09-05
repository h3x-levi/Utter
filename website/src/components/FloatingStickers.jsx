import React from 'react';
import { motion } from 'framer-motion';

export default function FloatingStickers() {
  const stickers = [
    {
      id: 'postit',
      text: (
        <span>
          <span className="text-amber-800 font-bold block text-sm mb-0.5">📌 Note to self:</span>
          Hold Fn to speak. Let go to flex. 💅
        </span>
      ),
      font: 'font-handwriting text-lg sm:text-xl leading-snug',
      bg: 'bg-[#fef08a] text-zinc-900 border-[#fde047]',
      initialPos: 'top-28 left-2 lg:left-4',
      rotation: -5,
      delay: 0.1,
    },
    {
      id: 'cow-pun',
      text: (
        <span className="flex items-center gap-1.5 font-extrabold tracking-tight">
          <span className="line-through text-rose-500 decoration-2 decoration-rose-500 opacity-70">Udderly</span>
          <span className="text-zinc-950 underline decoration-indigo-500 decoration-wavy decoration-2">Utterly</span>
          <span>Fast! 🐮🥛</span>
        </span>
      ),
      font: 'font-display-heavy text-xs sm:text-sm',
      bg: 'bg-rose-100 text-rose-950 border-rose-300',
      initialPos: 'top-32 right-2 lg:right-6',
      rotation: 4,
      delay: 0.2,
    },
    {
      id: 'speed-brrr',
      text: '180 WPM go BRRRRRR 🏎️💨',
      font: 'font-space-mono text-[11px] sm:text-xs font-bold tracking-tighter',
      bg: 'bg-lime-200 text-lime-950 border-lime-400',
      initialPos: 'top-[44%] -left-2 lg:left-4 hidden md:block',
      rotation: -3,
      delay: 0.3,
    },
    {
      id: 'siri-sass',
      text: '“Siri could literally never.” ✨',
      font: 'font-serif-italic text-sm sm:text-base font-semibold text-purple-950',
      bg: 'bg-purple-100 border-purple-300 shadow-purple-100',
      initialPos: 'top-[42%] -right-2 lg:right-4 hidden md:block',
      rotation: 5,
      delay: 0.4,
    },
    {
      id: 'fbi-roast',
      text: 'Zero telemetry. The FBI agent in your webcam is bored 😴💤',
      font: 'font-handwriting text-lg leading-tight text-sky-950',
      bg: 'bg-sky-100 border-sky-300',
      initialPos: 'bottom-8 left-2 lg:left-8 hidden lg:block',
      rotation: -4,
      delay: 0.5,
    },
    {
      id: 'cloud-roast',
      text: (
        <span className="block font-mono text-[10px] leading-tight">
          <span className="text-rose-600 block font-bold">● Cloud APIs: 1400ms Lag</span>
          <span className="text-emerald-600 block font-bold mt-0.5">● Utter on Metal: 168ms 🗿</span>
        </span>
      ),
      font: 'font-mono-sm',
      bg: 'bg-zinc-100 text-zinc-900 border-zinc-300',
      initialPos: 'bottom-8 right-2 lg:right-8 hidden lg:block',
      rotation: 3,
      delay: 0.6,
    },
  ];

  return (
    <div className="absolute inset-0 pointer-events-none z-20 overflow-visible max-w-7xl mx-auto">
      {stickers.map((s) => (
        <motion.div
          key={s.id}
          drag
          dragElastic={0.15}
          dragConstraints={{ left: -100, right: 100, top: -100, bottom: 100 }}
          whileHover={{ scale: 1.08, rotate: 0, zIndex: 50 }}
          whileDrag={{ scale: 1.15, rotate: 0, zIndex: 60, cursor: 'grabbing' }}
          initial={{ opacity: 0, scale: 0.8, rotate: s.rotation }}
          animate={{
            opacity: 1,
            scale: 1,
            rotate: [s.rotation - 1.5, s.rotation + 1.5, s.rotation - 1.5],
            y: [0, -6, 0],
          }}
          transition={{
            y: { duration: 4 + Math.random() * 2, repeat: Infinity, ease: 'easeInOut' },
            rotate: { duration: 5 + Math.random() * 2, repeat: Infinity, ease: 'easeInOut' },
            opacity: { duration: 0.4, delay: s.delay },
            scale: { duration: 0.4, delay: s.delay },
          }}
          className={`absolute ${s.initialPos} pointer-events-auto sticker-badge px-3.5 py-2.5 rounded-2xl border-2 shadow-md hover:shadow-xl transition-shadow ${s.bg} ${s.font}`}
        >
          {s.text}
          <div className="text-[9px] font-sans opacity-40 font-normal tracking-normal text-right mt-0.5 select-none">
            drag me ✋
          </div>
        </motion.div>
      ))}
    </div>
  );
}
