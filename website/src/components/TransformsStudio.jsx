import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, Wand2, ArrowRight, Check, RefreshCw, Cpu, ShieldCheck } from 'lucide-react';

const PRESET_TRANSFORMS = [
  {
    id: 'concise',
    voiceCommand: 'Make this concise and punchy',
    input:
      'I was just wondering if maybe we could possibly take a look at the telemetry dashboard sometime later this afternoon whenever you happen to have a spare minute because there seem to be some strange anomalies in the data.',
    output:
      'Could we review the telemetry dashboard this afternoon? There are anomalies in the data.',
    tokensSaved: '-65%',
  },
  {
    id: 'tone',
    voiceCommand: 'Fix grammar, punctuation, and tone',
    input:
      'hey bro so like the metal shader is super fast now we tested it on m3 max and it takes 160ms pretty sick huh',
    output:
      'Hi team, the Metal Performance Shader optimization is live. Benchmarks on M3 Max confirm sub-170ms inference latency.',
    tokensSaved: 'Polished',
  },
  {
    id: 'japanese',
    voiceCommand: 'Translate into Japanese',
    input:
      'Utter delivers private, on-device voice dictation for every Mac app with zero cloud latency.',
    output:
      'Utterは、クラウド遅延ゼロで、すべてのMacアプリにプライベートなオンデバイス音声入力を提供します。',
    tokensSaved: 'Localized',
  },
  {
    id: 'action_items',
    voiceCommand: 'Extract bulleted action items',
    input:
      'In our design sprint, Alex will profile the Core ML memory footprint by Friday, Jordan needs to sign the notarized release binary, and Taylor is finalizing the Product Hunt video demo.',
    output:
      '• Alex: Profile Core ML memory footprint (Due: Friday)\n• Jordan: Sign notarized release binary\n• Taylor: Finalize Product Hunt video demo',
    tokensSaved: 'Structured',
  },
];

export default function TransformsStudio() {
  const [activePresetIndex, setActivePresetIndex] = useState(0);
  const [isTransforming, setIsTransforming] = useState(false);
  const [displayText, setDisplayText] = useState(PRESET_TRANSFORMS[0].output);

  const preset = PRESET_TRANSFORMS[activePresetIndex];

  const handleApplyTransform = (index) => {
    setActivePresetIndex(index);
    setIsTransforming(true);
    setDisplayText('');

    setTimeout(() => {
      setIsTransforming(false);
      setDisplayText(PRESET_TRANSFORMS[index].output);
    }, 400);
  };

  return (
    <section id="transforms" className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-purple-400 mb-4 border border-purple-500/20">
          <Sparkles size={13} />
          <span>APPLE INTELLIGENCE LOCAL TRANSFORMS</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Highlight text. Speak an instruction.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          Select any text across your Mac, trigger Utter, and speak what you want changed. Powered locally by macOS FoundationModels with zero cloud roundtrips.
        </p>
      </div>

      {/* Transform Options Selector */}
      <div className="flex items-center justify-center gap-2 sm:gap-3 flex-wrap mb-10">
        {PRESET_TRANSFORMS.map((item, idx) => {
          const isSelected = activePresetIndex === idx;
          return (
            <motion.button
              key={item.id}
              onClick={() => handleApplyTransform(idx)}
              whileTap={{ scale: 0.96 }}
              className={`relative flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-medium border transition-colors ${
                isSelected
                  ? 'text-purple-200 border-transparent font-semibold'
                  : 'text-zinc-400 border-white/5 hover:text-zinc-200 hover:border-white/10'
              }`}
            >
              {isSelected && (
                <motion.div
                  layoutId="activeTransformPill"
                  className="absolute inset-0 bg-purple-600/30 border border-purple-500/60 rounded-xl shadow-lg shadow-purple-500/20"
                  transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                />
              )}
              <Wand2 size={13} className={`relative z-10 ${isSelected ? 'text-purple-400' : 'text-zinc-500'}`} />
              <span className="relative z-10">"{item.voiceCommand}"</span>
            </motion.button>
          );
        })}
      </div>

      {/* Before / After Interactive Transformer Card */}
      <div className="liquid-glass rounded-3xl p-6 sm:p-10 border border-white/10 shadow-2xl relative overflow-hidden">
        {/* Subtle Purple / Violet Mesh Glow */}
        <div className="absolute top-0 right-0 w-96 h-96 bg-purple-500/10 blur-[120px] rounded-full pointer-events-none" />

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          {/* Left: Raw Selected Text (5 cols) */}
          <div className="lg:col-span-5 flex flex-col justify-between p-6 rounded-2xl bg-zinc-950/80 border border-white/5">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-500 pb-3 mb-3 border-b border-white/5">
                <span>ORIGINAL HIGHLIGHTED TEXT</span>
                <span className="text-zinc-400 font-medium">Input</span>
              </div>
              <p className="text-zinc-300 font-mono text-xs sm:text-sm leading-relaxed whitespace-pre-wrap">
                "{preset.input}"
              </p>
            </div>

            <div className="pt-4 mt-6 border-t border-white/5 flex items-center justify-between text-xs text-zinc-500 font-mono">
              <span>Trigger: ⌥ Space + Speak</span>
              <span className="text-orange-400">"{preset.voiceCommand}"</span>
            </div>
          </div>

          {/* Middle: Transform Flow Arrow (2 cols) */}
          <div className="lg:col-span-2 flex flex-col items-center justify-center gap-2 py-4 lg:py-0">
            <div className="w-10 h-10 rounded-full bg-purple-500/20 text-purple-400 border border-purple-500/30 flex items-center justify-center shadow-lg shadow-purple-500/20">
              <Sparkles size={18} className={isTransforming ? 'animate-spin' : ''} />
            </div>
            <span className="text-[11px] font-mono text-purple-400 text-center">
              On-Device FoundationModel
            </span>
          </div>

          {/* Right: Transformed Text (5 cols) */}
          <div className="lg:col-span-5 flex flex-col justify-between p-6 rounded-2xl bg-gradient-to-br from-purple-950/20 via-zinc-950/80 to-zinc-950/90 border border-purple-500/30 shadow-xl relative">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-purple-400 pb-3 mb-3 border-b border-white/5">
                <span className="flex items-center gap-1.5">
                  <Check size={14} className="text-emerald-400" />
                  <span>TRANSFORMED RESULT</span>
                </span>
                <span className="px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-300 text-[10px] font-bold">
                  {preset.tokensSaved}
                </span>
              </div>

              <div className="min-h-[140px] flex items-center">
                <AnimatePresence mode="wait">
                  {isTransforming ? (
                    <motion.div
                      key="transforming"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.98 }}
                      transition={{ duration: 0.15 }}
                      className="w-full flex items-center justify-center text-xs font-mono text-purple-300 animate-pulse"
                    >
                      Executing Apple FoundationModel in RAM...
                    </motion.div>
                  ) : (
                    <motion.p
                      key={preset.id}
                      initial={{ opacity: 0, y: 4, filter: 'blur(4px)' }}
                      animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
                      exit={{ opacity: 0, y: -4, filter: 'blur(4px)' }}
                      transition={{ type: 'spring', stiffness: 350, damping: 28 }}
                      className="text-white font-mono text-xs sm:text-sm leading-relaxed whitespace-pre-wrap"
                    >
                      {displayText}
                    </motion.p>
                  )}
                </AnimatePresence>
              </div>
            </div>

            <div className="pt-4 mt-6 border-t border-white/5 flex items-center justify-between text-xs text-zinc-400 font-mono">
              <span className="flex items-center gap-1.5 text-emerald-400">
                <ShieldCheck size={14} />
                <span>Zero Cloud AI API Bills</span>
              </span>
              <span className="text-zinc-500">100% Free Forever</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
