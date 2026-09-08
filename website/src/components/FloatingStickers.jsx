import React from 'react';
import { motion, useReducedMotion } from 'framer-motion';

export default function FloatingStickers() {
  const shouldReduceMotion = useReducedMotion();
  const stickers = [
    {
      id: 'demure',
      text: (
        <span>
          <span className="text-pink-800 font-bold block text-xs uppercase tracking-wider mb-0.5">🎀 Cutesy Mode</span>
          Very demure. Very mindful. Zero cloud surveillance. 💅
        </span>
      ),
      font: 'font-serif-italic text-sm sm:text-base font-semibold text-pink-950',
      bg: 'bg-pink-100 text-pink-950 border-pink-300 shadow-pink-100',
      pos: 'top-24 left-[3%] xl:left-[6%]',
      rotation: -6,
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
      pos: 'top-28 right-[3%] xl:right-[6%]',
      rotation: 5,
      delay: 0.2,
    },
    {
      id: 'chat-real',
      text: 'Chat is this real?! 180 WPM with 0ms cloud lag 🤯🔥',
      font: 'font-display-heavy text-xs sm:text-sm tracking-tight text-amber-950',
      bg: 'bg-amber-100 text-amber-950 border-amber-300',
      pos: 'top-[42%] left-[1%] xl:left-[4%] hidden lg:block',
      rotation: -4,
      delay: 0.3,
    },
    {
      id: 'aura-points',
      text: (
        <span>
          <span className="text-emerald-700 font-bold block text-xs mb-0.5">+10,000 AURA</span>
          Dictating 2,000 lines of Swift on an airplane with Wi-Fi off ✈️🕶️
        </span>
      ),
      font: 'font-space-mono text-[11px] sm:text-xs font-bold text-emerald-950',
      bg: 'bg-emerald-100 border-emerald-300 shadow-emerald-100',
      pos: 'top-[44%] right-[1%] xl:right-[4%] hidden lg:block',
      rotation: 4,
      delay: 0.4,
    },
    {
      id: 'cooked-kb',
      text: 'My mechanical keyboard is officially cooked 💀🍳',
      font: 'font-handwriting text-xl leading-tight text-zinc-950',
      bg: 'bg-[#fef08a] border-[#fde047]',
      pos: 'bottom-8 left-[4%] xl:left-[8%] hidden xl:block',
      rotation: -3,
      delay: 0.5,
    },
    {
      id: 'gigachad-m4',
      text: (
        <span className="block font-mono text-[11px] leading-tight">
          <span className="text-rose-600 block font-bold">● Cloud APIs: ⚠️ 503 Outage</span>
          <span className="text-emerald-700 block font-bold mt-1">● Utter on Apple Silicon: 🗿🗿🗿</span>
        </span>
      ),
      font: 'font-mono-sm',
      bg: 'bg-zinc-100 text-zinc-900 border-zinc-300',
      pos: 'bottom-8 right-[4%] xl:right-[8%] hidden xl:block',
      rotation: 3,
      delay: 0.6,
    },
  ];

  return (
    <div className="absolute inset-0 pointer-events-none z-20 overflow-visible w-full">
      {stickers.map((s) => (
        <motion.div
          key={s.id}
          drag={!shouldReduceMotion}
          dragElastic={0.15}
          dragConstraints={{ left: -140, right: 140, top: -120, bottom: 120 }}
          whileHover={shouldReduceMotion ? { scale: 1.02 } : { scale: 1.08, rotate: 0, zIndex: 50 }}
          whileDrag={shouldReduceMotion ? undefined : { scale: 1.15, rotate: 0, zIndex: 60, cursor: 'grabbing' }}
          initial={{ opacity: 0, scale: 0.8, rotate: s.rotation }}
          animate={shouldReduceMotion ? {
            opacity: 1,
            scale: 1,
            rotate: s.rotation,
            y: 0,
          } : {
            opacity: 1,
            scale: 1,
            rotate: [s.rotation - 1.2, s.rotation + 1.2, s.rotation - 1.2],
            y: [0, -7, 0],
          }}
          transition={shouldReduceMotion ? {
            opacity: { duration: 0.3 },
            scale: { duration: 0.3 },
          } : {
            y: { duration: 4.5 + Math.random() * 2, repeat: Infinity, ease: 'easeInOut' },
            rotate: { duration: 5.5 + Math.random() * 2, repeat: Infinity, ease: 'easeInOut' },
            opacity: { duration: 0.4, delay: s.delay },
            scale: { duration: 0.4, delay: s.delay },
          }}
          className={`absolute ${s.pos} pointer-events-auto sticker-badge px-4 py-3 rounded-2xl border-2 shadow-lg hover:shadow-2xl transition-shadow ${s.bg} ${s.font}`}
        >
          {s.text}
          <div className="text-[9px] font-sans opacity-40 font-normal tracking-normal text-right mt-1 select-none">
            {shouldReduceMotion ? 'sticker' : 'drag me ✋'}
          </div>
        </motion.div>
      ))}
    </div>
  );
}
