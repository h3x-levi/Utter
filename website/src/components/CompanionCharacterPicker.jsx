import React from 'react';
import CodeCompanionCanvas from './CodeCompanionCanvas';

/**
 * CompanionCharacterPicker
 * Replicates the authentic macOS native Settings "Character" selection row
 * exactly as shown in the user's screenshot:
 *  - Title: "Character"
 *  - 4 tiles: Charcoal Cat (orange active border), Ginger Cat, Pixel Dog, Pixel Panda
 *  - Sub-millisecond code-rendered vector preview inside each tile
 *  - High-precision Apple Human Interface styling (dark glass, rounded rectangles)
 */

export const CHARACTERS = [
  {
    id: 'charcoal-cat',
    aliasId: 'gray',
    name: 'Charcoal Cat',
    species: 'cat',
    isGinger: false,
    color: '#38bdf8',
    description: 'Sleek dark obsidian coat drawn at runtime with vivid cyan eyes.',
  },
  {
    id: 'ginger-cat',
    aliasId: 'orange',
    name: 'Ginger Cat',
    species: 'cat',
    isGinger: true,
    color: '#f97316',
    description: 'Warm ginger tabby with tiger stripes and emerald green eyes.',
  },
  {
    id: 'pixel-dog',
    aliasId: 'dog',
    name: 'Pixel Dog',
    species: 'dog',
    isGinger: false,
    color: '#f59e0b',
    description: 'Enthusiastic puppy with floppy brown ears and happy wagging tail.',
  },
  {
    id: 'pixel-panda',
    aliasId: 'panda',
    name: 'Pixel Panda',
    species: 'panda',
    isGinger: false,
    color: '#a78bfa',
    description: 'Calm dictation monk with iconic black eye patches and pink toe pads.',
  },
];

export default function CompanionCharacterPicker({
  selectedId = 'charcoal-cat',
  onSelect,
  className = '',
}) {
  const isSelected = (char) =>
    selectedId === char.id || selectedId === char.aliasId;

  return (
    <div
      className={`w-full rounded-2xl bg-[#151214]/90 backdrop-blur-xl border border-white/10 p-5 sm:p-6 shadow-2xl ${className}`}
    >
      {/* Container Header matching macOS Settings screenshot */}
      <div className="text-white font-semibold text-sm sm:text-base tracking-tight mb-3.5 px-0.5">
        Character
      </div>

      {/* 4-Tile Selection Grid matching macOS Settings screenshot */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-3.5">
        {CHARACTERS.map((char) => {
          const active = isSelected(char);
          return (
            <button
              key={char.id}
              onClick={() => onSelect && onSelect(char)}
              type="button"
              className="flex flex-col items-center group cursor-pointer focus:outline-none"
              title={`${char.name} — ${char.description}`}
            >
              {/* Tile box */}
              <div
                className={`w-full aspect-[16/10] sm:h-[76px] rounded-xl flex items-center justify-center relative transition-all duration-200 ${
                  active
                    ? 'border-2 border-[#ff7828] bg-white/[0.04] shadow-lg shadow-orange-500/10 scale-[1.01]'
                    : 'border border-white/10 bg-white/[0.02] hover:bg-white/[0.05] hover:border-white/20'
                }`}
              >
                <div className="w-[58px] h-[58px] flex items-center justify-center pointer-events-none">
                  <CodeCompanionCanvas
                    species={char.species}
                    isGinger={char.isGinger}
                    action="waving"
                    width={58}
                    height={58}
                    enableTracking={false}
                  />
                </div>
              </div>

              {/* Caption Label */}
              <span
                className={`mt-2 text-xs sm:text-xs tracking-tight transition-colors duration-200 text-center select-none ${
                  active
                    ? 'text-white font-semibold'
                    : 'text-zinc-400 group-hover:text-zinc-200 font-medium'
                }`}
              >
                {char.name}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
