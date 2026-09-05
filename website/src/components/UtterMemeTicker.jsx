import React from 'react';

export default function UtterMemeTicker() {
  const memes = [
    { text: "🐮 UDDERLY FAST", font: "font-display-heavy", color: "bg-rose-100 text-rose-950 border-rose-300" },
    { text: "🎀 VERY DEMURE, VERY MINDFUL", font: "font-serif-italic", color: "bg-pink-100 text-pink-950 border-pink-300" },
    { text: "🤯 CHAT IS THIS REAL?! 180 WPM", font: "font-display-heavy", color: "bg-amber-100 text-amber-950 border-amber-300" },
    { text: "🕶️ +10,000 AURA (AIRPLANE MODE)", font: "font-space-mono", color: "bg-emerald-100 text-emerald-950 border-emerald-300" },
    { text: "🗿 GIGACHAD LOCAL M4 INFERENCE", font: "font-mono-sm", color: "bg-zinc-200 text-zinc-900 border-zinc-400" },
    { text: "🍳 KEYBOARD IS COOKED 💀", font: "font-handwriting text-xl", color: "bg-yellow-100 text-yellow-950 border-yellow-300" },
    { text: "🔒 LOCKED IN AT 180 WPM", font: "font-display-heavy", color: "bg-indigo-100 text-indigo-950 border-indigo-300" },
    { text: "💀 Bro really thought we'd pay $15/mo", font: "font-space-mono", color: "bg-lime-100 text-lime-950 border-lime-300" },
    { text: "🤫 DON'T MUTTER, JUST UTTER", font: "font-display-heavy", color: "bg-purple-100 text-purple-950 border-purple-300" },
    { text: "“Siri could literally never” 💅", font: "font-serif-italic", color: "bg-fuchsia-100 text-fuchsia-950 border-fuchsia-300" },
    { text: "🤖 The design is very human", font: "font-space-mono", color: "bg-sky-100 text-sky-950 border-sky-300" },
    { text: "💸 $0.00 / MONTH FOREVER (MIT)", font: "font-display-heavy", color: "bg-teal-100 text-teal-950 border-teal-300" },
  ];

  const items = [...memes, ...memes];

  return (
    <div className="w-full py-5 overflow-hidden bg-white/80 border-y border-black/[0.08] backdrop-blur-md select-none relative z-10 shadow-sm">
      <div className="flex items-center gap-4 w-max animate-marquee">
        {items.map((m, idx) => (
          <div
            key={idx}
            className={`inline-flex items-center px-4 py-2 rounded-full border shadow-sm text-xs font-bold whitespace-nowrap transition-transform hover:scale-105 cursor-default ${m.color} ${m.font}`}
          >
            {m.text}
          </div>
        ))}
      </div>
    </div>
  );
}
