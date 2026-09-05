import React from 'react';

export default function UtterMemeTicker() {
  const memes = [
    { text: "🐮 UDDERLY ADDICTIVE", font: "font-display-heavy", color: "bg-rose-100 text-rose-900 border-rose-300" },
    { text: "🤫 DON'T MUTTER, JUST UTTER", font: "font-space-mono", color: "bg-indigo-100 text-indigo-900 border-indigo-300" },
    { text: "⚡ 180 WPM TELEPATHIC SPEED", font: "font-display-heavy", color: "bg-amber-100 text-amber-900 border-amber-300" },
    { text: "“Siri could literally never” 💅", font: "font-serif-italic", color: "bg-purple-100 text-purple-900 border-purple-300" },
    { text: "🥪 Utterly Butterly Smooth", font: "font-handwriting text-lg", color: "bg-yellow-100 text-yellow-950 border-yellow-300" },
    { text: "🗿 ZERO CLOUD, ZERO TELEMETRY", font: "font-mono-sm", color: "bg-emerald-100 text-emerald-950 border-emerald-300" },
    { text: "💸 $0/MO FOREVER (SaaS in tears)", font: "font-space-mono", color: "bg-lime-100 text-lime-950 border-lime-300" },
    { text: "⌨️ Keyboard gathering dust...", font: "font-handwriting text-lg", color: "bg-sky-100 text-sky-950 border-sky-300" },
    { text: "💥 UTTER DISRESPECT TO TYPING SPEED", font: "font-display-heavy", color: "bg-orange-100 text-orange-950 border-orange-300" },
    { text: "🐱 100% Pixel Cat Approved", font: "font-serif-italic", color: "bg-pink-100 text-pink-950 border-pink-300" },
  ];

  const items = [...memes, ...memes]; // Duplicate for seamless infinite loop

  return (
    <div className="py-6 overflow-hidden bg-white/70 border-y border-black/[0.06] backdrop-blur-sm select-none">
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
