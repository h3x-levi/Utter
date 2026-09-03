import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { CheckCircle2, Download, HardDrive, Zap, Cpu } from 'lucide-react';

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
    },
    {
      id: 'medium',
      name: 'Medium',
      badge: { text: 'Recommended', color: 'bg-purple-500/20 text-purple-300 border-purple-500/40' },
      description: 'Most accurate on technical terms and unusual names, but English-only. 10x faster than real time.',
      size: '514 MB',
      speed: '6s per min',
      ram: '815 MB RAM',
      downloadable: true,
    },
    {
      id: 'turbo',
      name: 'Large Turbo',
      badge: { text: '90+ languages', color: 'bg-blue-500/20 text-blue-300 border-blue-500/40' },
      description: 'State-of-the-art multilingual transcription. Handles extreme background noise and non-native accents.',
      size: '809 MB',
      speed: '8s per min',
      ram: '980 MB RAM',
      downloadable: true,
    },
  ];

  const current = models.find((m) => m.id === selectedModel);

  return (
    <div className="w-full max-w-4xl mx-auto flex flex-col items-center px-2">
      {/* Stage Header */}
      <div className="text-center mb-4">
        <span className="font-mono-sm text-[11px] font-semibold px-3 py-0.5 rounded-full bg-white/5 text-zinc-300 border border-white/10">
          Native Neural Weights · Apple Foundation & Metal
        </span>
        <h2 className="text-2xl sm:text-3xl md:text-4xl font-extrabold tracking-tight mt-2 text-white">
          Switch speech models with zero cloud dependencies.
        </h2>
        <p className="text-zinc-400 text-xs sm:text-sm max-w-xl mx-auto mt-1">
          Exact replica of the macOS settings window bundled with Utter. Click any model to test reactive states.
        </p>
      </div>

      {/* The Exact macOS Settings Window (Direct Replica of native app) */}
      <div className="w-full max-w-3xl rounded-[22px] bg-[#1e1e22]/95 backdrop-blur-2xl border border-white/10 shadow-2xl overflow-hidden text-white">
        {/* macOS Title Bar */}
        <div className="h-10 bg-[#28282d]/90 border-b border-white/10 px-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5">
              <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f56]" />
              <div className="w-2.5 h-2.5 rounded-full bg-[#ffbd2e]" />
              <div className="w-2.5 h-2.5 rounded-full bg-[#27c93f]" />
            </div>
            <div className="w-5 h-4 rounded border border-white/20 flex items-center px-0.5 gap-0.5 ml-1 opacity-60">
              <div className="w-1 h-full bg-white/40 rounded-sm" />
              <div className="flex-1 h-full bg-transparent" />
            </div>
            <span className="text-xs font-semibold text-white/90">Settings</span>
          </div>

          <span className="font-mono-sm text-[10px] text-white/40">Apple Silicon Unified Memory</span>
        </div>

        {/* Window Content */}
        <div className="p-4 sm:p-5">
          <h3 className="text-lg font-bold tracking-tight text-white mb-3">Speech</h3>

          <div className="mb-2 flex items-center justify-between">
            <span className="text-[11px] font-semibold text-white/70 uppercase tracking-wider">Model</span>
            <span className="text-[11px] text-white/40 font-mono-sm">Active: {current.name}</span>
          </div>

          {/* Model Cards List */}
          <div className="space-y-2">
            {models.map((model) => {
              const isSelected = selectedModel === model.id;
              return (
                <div
                  key={model.id}
                  onClick={() => setSelectedModel(model.id)}
                  className={`p-3 rounded-xl cursor-pointer transition-all duration-150 border text-left relative ${
                    isSelected
                      ? 'bg-[#292622] border-amber-600/70 shadow ring-1 ring-amber-500/30'
                      : 'bg-[#25252a]/70 hover:bg-[#2a2a30] border-white/5'
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className="pt-0.5">
                      {isSelected ? (
                        <div className="w-4 h-4 rounded-full bg-amber-500 flex items-center justify-center text-[#18181b] shadow">
                          <CheckCircle2 size={13} className="text-black" />
                        </div>
                      ) : (
                        <div className="w-4 h-4 rounded-full border-2 border-white/30" />
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex flex-wrap items-center gap-2 mb-0.5">
                        <span className="font-semibold text-sm text-white tracking-tight">
                          {model.name}
                        </span>
                        {model.badge && (
                          <span
                            className={`text-[10px] font-medium px-2 py-0.2 rounded-full border ${model.badge.color}`}
                          >
                            {model.badge.text}
                          </span>
                        )}
                      </div>

                      <p className="text-xs text-white/60 leading-relaxed mb-2">
                        {model.description}
                      </p>

                      <div className="flex flex-wrap items-center gap-2 text-[11px]">
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-black/30 border border-white/5 font-mono text-white/70">
                          <HardDrive size={11} className="text-amber-400" />
                          {model.size}
                        </span>

                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-black/30 border border-white/5 font-mono text-white/70">
                          <Zap size={11} className="text-emerald-400" />
                          {model.speed}
                        </span>

                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-black/30 border border-white/5 font-mono text-white/70">
                          <Cpu size={11} className="text-indigo-400" />
                          {model.ram}
                        </span>

                        {model.downloadable && !isSelected && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSelectedModel(model.id);
                            }}
                            className="ml-auto inline-flex items-center gap-1 px-2.5 py-0.5 rounded bg-white/10 hover:bg-white/20 border border-white/10 text-white text-[11px] font-medium transition-colors"
                          >
                            <Download size={11} />
                            Download
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-3 p-2.5 rounded-lg bg-black/40 border border-white/5 flex items-center justify-between text-xs">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              <span className="text-[11px] text-white/80 font-mono-sm">
                Engine: <strong className="text-white">{current.name} (Q5_1 Metal)</strong>
              </span>
            </div>
            <div className="text-[11px] font-mono text-white/50">
              Allocated RAM: <span className="text-amber-300 font-semibold">{current.ram}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
