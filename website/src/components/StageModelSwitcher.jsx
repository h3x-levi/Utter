import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle2, Download, HardDrive, Zap, Cpu, ArrowDownCircle, Sparkles, Layers } from 'lucide-react';

export default function StageModelSwitcher() {
  const [selectedModel, setSelectedModel] = useState('small');

  const models = [
    {
      id: 'base',
      name: 'Base',
      badge: null,
      description: 'Fastest and smallest. Fine for everyday notes, weaker on unusual names.',
      size: '57 MB',
      speed: '<1s per min (Ultra Fast)',
      ram: '180 MB RAM',
      downloadable: true,
      ready: false,
    },
    {
      id: 'small',
      name: 'Small',
      badge: { text: 'Active & Ready', color: 'bg-amber-500/20 text-amber-300 border-amber-500/40' },
      description: 'Fast and light, English-only. A good default on any Mac, including 8 GB machines.',
      size: '181 MB',
      speed: '2s per min',
      ram: '395 MB RAM',
      downloadable: false,
      ready: true,
    },
    {
      id: 'medium',
      name: 'Medium',
      badge: { text: 'Recommended', color: 'bg-purple-500/20 text-purple-300 border-purple-500/40' },
      description: 'Most accurate on technical terms and unusual names, but English-only — it can struggle with strong or non-native accents. 10x faster than real time.',
      size: '514 MB',
      speed: '6s per min',
      ram: '815 MB RAM',
      downloadable: true,
      ready: false,
    },
    {
      id: 'turbo',
      name: 'Large Turbo',
      badge: { text: '90+ languages', color: 'bg-blue-500/20 text-blue-300 border-blue-500/40' },
      description: 'State-of-the-art multilingual transcription. Handles extreme background noise and non-native accents with near-zero error rate.',
      size: '809 MB',
      speed: '8s per min',
      ram: '980 MB RAM',
      downloadable: true,
      ready: false,
    },
  ];

  const current = models.find((m) => m.id === selectedModel);

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center">
      {/* Stage Header */}
      <div className="text-center mb-8">
        <span className="font-mono-sm text-xs font-semibold px-3 py-1 rounded-full bg-black/5 text-black/60 border border-black/10">
          Native Neural Weights · Apple Foundation & Metal
        </span>
        <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight mt-3 text-[#0d0d0d]">
          Switch speech models with zero cloud dependencies.
        </h2>
        <p className="text-black/60 text-base sm:text-lg max-w-2xl mx-auto mt-2">
          Click below to test the exact macOS settings window bundled with Utter. Swap to larger models whenever you need specialized vocabulary.
        </p>
      </div>

      {/* The Exact macOS Settings Window (Direct Replica of native app) */}
      <div className="w-full max-w-4xl rounded-[24px] bg-[#222225]/95 backdrop-blur-2xl border border-white/10 shadow-2xl overflow-hidden text-white">
        {/* macOS Title Bar */}
        <div className="h-12 bg-[#2d2d31]/90 border-b border-white/10 px-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
              <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
              <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
            </div>
            {/* Sidebar toggle icon replica */}
            <div className="w-6 h-5 rounded border border-white/20 flex items-center px-1 gap-0.5 ml-2 opacity-60">
              <div className="w-1.5 h-full bg-white/40 rounded-sm" />
              <div className="flex-1 h-full bg-transparent" />
            </div>
            <span className="text-xs font-semibold text-white/90">Settings</span>
          </div>

          <span className="font-mono-sm text-[11px] text-white/40">Apple Silicon Unified Memory</span>
        </div>

        {/* Window Content */}
        <div className="p-6 sm:p-8">
          <h3 className="text-2xl font-bold tracking-tight text-white mb-6">Speech</h3>

          <div className="mb-3 flex items-center justify-between">
            <span className="text-xs font-semibold text-white/70 uppercase tracking-wider">Model</span>
            <span className="text-xs text-white/40 font-mono-sm">Active Model: {current.name}</span>
          </div>

          {/* Model Cards List */}
          <div className="space-y-3.5">
            {models.map((model) => {
              const isSelected = selectedModel === model.id;
              return (
                <motion.div
                  key={model.id}
                  onClick={() => setSelectedModel(model.id)}
                  whileHover={{ scale: 1.008 }}
                  whileTap={{ scale: 0.995 }}
                  className={`p-4 sm:p-5 rounded-2xl cursor-pointer transition-all duration-200 border text-left relative ${
                    isSelected
                      ? 'bg-[#2a2724] border-amber-600/60 shadow-lg ring-1 ring-amber-500/20'
                      : 'bg-[#29292d]/70 hover:bg-[#2e2e33] border-white/5'
                  }`}
                >
                  <div className="flex items-start gap-4">
                    {/* Radio circle / checkmark */}
                    <div className="pt-0.5">
                      {isSelected ? (
                        <div className="w-5 h-5 rounded-full bg-amber-500 flex items-center justify-center text-[#18181b] shadow">
                          <CheckCircle2 size={16} className="text-black" />
                        </div>
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-white/30" />
                      )}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-2 mb-1.5">
                        <span className="font-semibold text-base text-white tracking-tight">
                          {model.name}
                        </span>
                        {model.badge && (
                          <span
                            className={`text-[11px] font-medium px-2 py-0.5 rounded-full border ${model.badge.color}`}
                          >
                            {model.badge.text}
                          </span>
                        )}
                      </div>

                      <p className="text-xs sm:text-sm text-white/60 leading-relaxed mb-3">
                        {model.description}
                      </p>

                      {/* Hardware Telemetry Chips */}
                      <div className="flex flex-wrap items-center gap-2 text-xs">
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-black/30 border border-white/5 font-mono text-white/70">
                          <HardDrive size={12} className="text-amber-400" />
                          {model.size}
                        </span>

                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-black/30 border border-white/5 font-mono text-white/70">
                          <Zap size={12} className="text-emerald-400" />
                          {model.speed}
                        </span>

                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-black/30 border border-white/5 font-mono text-white/70">
                          <Cpu size={12} className="text-indigo-400" />
                          {model.ram}
                        </span>

                        {model.downloadable && !isSelected && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedModel(model.id);
                            }}
                            className="ml-auto inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 hover:bg-white/20 border border-white/10 text-white text-xs font-medium transition-colors"
                          >
                            <Download size={13} />
                            Download
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>

          {/* Active Model Performance Inspector */}
          <div className="mt-6 p-4 rounded-xl bg-black/40 border border-white/5 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-ping" />
              <span className="text-xs text-white/80 font-mono-sm">
                Active Inference Engine: <strong className="text-white">{current.name} (Q5_1 Metal Accelerated)</strong>
              </span>
            </div>
            <div className="text-xs font-mono text-white/50">
              Allocated RAM: <span className="text-amber-300 font-semibold">{current.ram}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
