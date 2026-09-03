import React, { useState } from 'react';
import { Sparkles } from 'lucide-react';

export default function SpeechModelMatrix() {
  const [activeModel, setActiveModel] = useState(2); // Small.en bundled default

  const models = [
    {
      name: 'Whisper Tiny.en',
      disk: '39 MB',
      ram: '75 MB',
      latency: '82 ms',
      accuracy: '92.4%',
      bestFor: 'Older Intel Macs & lightweight RAM usage',
      quant: 'Q5_1 Quantized',
      bundled: false,
    },
    {
      name: 'Whisper Base.en',
      disk: '74 MB',
      ram: '120 MB',
      latency: '114 ms',
      accuracy: '95.1%',
      bestFor: 'General writing, fast messaging & quick notes',
      quant: 'Q5_1 Quantized',
      bundled: false,
    },
    {
      name: 'Whisper Small.en',
      disk: '181 MB',
      ram: '240 MB',
      latency: '168 ms',
      accuracy: '98.6%',
      bestFor: 'Default • Best balance of speed, code syntax & accuracy',
      quant: 'Q5_1 Quantized',
      bundled: true,
    },
    {
      name: 'Whisper Medium.en',
      disk: '515 MB',
      ram: '650 MB',
      latency: '340 ms',
      accuracy: '99.3%',
      bestFor: 'Complex technical jargon, medical & legal terminology',
      quant: 'Q5_1 Quantized',
      bundled: false,
    },
    {
      name: 'Whisper Large-v3-Turbo',
      disk: '809 MB',
      ram: '980 MB',
      latency: '490 ms',
      accuracy: '99.8%',
      bestFor: 'Multilingual transcription & noisy environments',
      quant: 'Q5_0 Quantized',
      bundled: false,
    },
  ];

  return (
    <section id="models" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Local Speech Models
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Switch speech models with one click.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Bundled out of the box with zero external downloads. Swap to larger models whenever you need specialized precision.
          </p>
        </div>

        {/* Interactive Model Table Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-3 mb-8">
          {models.map((m, idx) => (
            <button
              key={idx}
              onClick={() => setActiveModel(idx)}
              className={`p-5 rounded-xl text-left transition-all border flex flex-col justify-between ${
                activeModel === idx
                  ? 'bg-zinc-800 border-zinc-500 text-white shadow-lg'
                  : 'bg-zinc-900/60 border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'
              }`}
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  {m.bundled ? (
                    <span className="px-2 py-0.5 rounded text-[10px] font-mono font-medium bg-zinc-800 text-zinc-200 border border-zinc-700">
                      Bundled
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 rounded text-[10px] font-mono text-zinc-500 bg-zinc-900">
                      1-Click Download
                    </span>
                  )}
                </div>
                <h4 className="text-sm font-semibold text-white mb-1">{m.name}</h4>
                <p className="text-xs text-zinc-400 mb-4">{m.bestFor}</p>
              </div>

              <div className="pt-3 border-t border-zinc-800 space-y-1 text-xs font-mono">
                <div className="flex justify-between text-zinc-400">
                  <span>Disk:</span>
                  <span className="text-white font-medium">{m.disk}</span>
                </div>
                <div className="flex justify-between text-zinc-400">
                  <span>RAM:</span>
                  <span className="text-white font-medium">{m.ram}</span>
                </div>
                <div className="flex justify-between text-zinc-400">
                  <span>Latency:</span>
                  <span className="text-white font-medium">{m.latency}</span>
                </div>
              </div>
            </button>
          ))}
        </div>

        {/* Active Model Spec Detail Card */}
        <div className="apple-panel rounded-2xl p-8 border border-zinc-800 flex flex-col lg:flex-row items-center justify-between gap-6">
          <div>
            <div className="flex items-center gap-2 text-xs font-mono text-zinc-400 font-medium mb-1">
              <Sparkles className="w-3.5 h-3.5 text-zinc-300" /> Selected Model: {models[activeModel].name}
            </div>
            <h3 className="text-xl font-bold text-white mb-1">
              {models[activeModel].bestFor}
            </h3>
            <p className="text-zinc-400 text-xs sm:text-sm max-w-xl">
              Fully optimized with Apple Metal GPU compute kernels. Supports automatic language detection, sentence-level punctuation restoration, and custom dictionary entity biasing.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3 shrink-0">
            <div className="px-4 py-2.5 rounded-lg bg-[#141418] border border-zinc-800 text-center">
              <div className="text-lg font-bold font-mono text-white">{models[activeModel].accuracy}</div>
              <div className="text-[10px] text-zinc-500 font-mono">Accuracy Score</div>
            </div>
            <div className="px-4 py-2.5 rounded-lg bg-[#141418] border border-zinc-800 text-center">
              <div className="text-lg font-bold font-mono text-zinc-200">{models[activeModel].latency}</div>
              <div className="text-[10px] text-zinc-500 font-mono">Metal Latency</div>
            </div>
          </div>
        </div>

      </div>
    </section>
  );
}
