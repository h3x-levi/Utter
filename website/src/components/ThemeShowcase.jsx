import React from 'react';
import { Palette, Sparkles, Check } from 'lucide-react';

const THEMES = [
  {
    id: 'system-glass',
    name: 'System Glass',
    description: 'Dynamic Apple auto translucency with amber acoustic accents.',
    color: '#f97316',
    previewBg: 'from-zinc-900 to-zinc-950',
  },
  {
    id: 'dark-glass',
    name: 'Dark Glass',
    description: 'Refined translucent obsidian with electric cyan accents.',
    color: '#38bdf8',
    previewBg: 'from-sky-950 to-zinc-950',
  },
  {
    id: 'obsidian',
    name: 'Obsidian',
    description: 'Pure deep carbon with crisp high-contrast monochrome tokens.',
    color: '#a1a1aa',
    previewBg: 'from-zinc-950 to-black',
  },
  {
    id: 'solar-warmth',
    name: 'Solar Warmth',
    description: 'Warm glowing amber and terracotta sunset ambiance.',
    color: '#fb923c',
    previewBg: 'from-amber-950 to-zinc-950',
  },
  {
    id: 'nordic-frost',
    name: 'Nordic Frost',
    description: 'Crisp polar blue and frosted Scandinavian ice materials.',
    color: '#06b6d4',
    previewBg: 'from-cyan-950 to-zinc-950',
  },
  {
    id: 'midnight-indigo',
    name: 'Midnight Indigo',
    description: 'Rich twilight violet engineered for late-night deep work.',
    color: '#818cf8',
    previewBg: 'from-indigo-950 to-zinc-950',
  },
  {
    id: 'paper-white',
    name: 'Paper White',
    description: 'Minimalist editorial daylight theme with crisp typography.',
    color: '#2563eb',
    previewBg: 'from-slate-100 to-slate-200',
  },
];

export default function ThemeShowcase({ currentTheme, onSelectTheme }) {
  return (
    <section className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-4 border border-orange-500/20">
          <Palette size={13} />
          <span>7 LIQUID GLASS THEMES</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Match your macOS desktop aesthetics.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          Crafted with authentic macOS 13.3–15+ design tokens, vibrant translucency, and adaptive contrast. Select any theme to preview its colorway live.
        </p>
      </div>

      {/* Theme Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {THEMES.map((theme) => {
          const isSelected = currentTheme === theme.id;
          return (
            <div
              key={theme.id}
              onClick={() => onSelectTheme(theme.id)}
              className={`p-5 rounded-2xl liquid-glass border cursor-pointer transition-all duration-200 flex flex-col justify-between ${
                isSelected
                  ? 'border-orange-400 ring-2 ring-orange-500/30 -translate-y-1 shadow-xl'
                  : 'border-white/10 hover:border-white/20 hover:bg-zinc-900/40'
              }`}
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2.5">
                    <span
                      className="w-4 h-4 rounded-full border border-white/20 shadow-sm"
                      style={{ backgroundColor: theme.color }}
                    />
                    <h3 className="font-bold text-sm text-white">{theme.name}</h3>
                  </div>
                  {isSelected && (
                    <span className="p-1 rounded-full bg-orange-500 text-zinc-950">
                      <Check size={12} strokeWidth={3} />
                    </span>
                  )}
                </div>
                <p className="text-xs text-zinc-400 leading-relaxed">
                  {theme.description}
                </p>
              </div>

              {/* Theme Pill Preview Bar */}
              <div className="mt-4 pt-3 border-t border-white/5 flex items-center justify-between">
                <span className="text-[10px] font-mono text-zinc-500 uppercase">
                  Palette: {theme.color}
                </span>
                <span className="text-[11px] font-mono text-zinc-400 hover:text-white transition-colors">
                  {isSelected ? 'Active' : 'Apply'}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
