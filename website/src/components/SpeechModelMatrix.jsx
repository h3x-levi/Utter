import React, { useState } from 'react';
import { Cpu, HardDrive, Zap, CheckCircle2, Sparkles, DownloadCloud } from 'lucide-react';

export default function SpeechModelMatrix() {
  const [activeModel, setActiveModel] = useState(2); // Small.en bundled default

  const models = [
    {
      name: 'Whisper Tiny.en',
      disk: '39 MB',
      ram: '75 MB',
      latency: '82 ms',
      accuracy: '92.4%',
      bestFor: 'Older Intel Macs & ultra-lightweight memory usage',
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
    <section id="models" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Local Speech Models
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Switch speech models with one click.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Bundled out of the box with zero external downloads. Swap to larger models whenever you need specialized precision.
          </p>
        </div>

        {/* Interactive Model Table Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-5 gap-4 mb-12">
          {models.map((m, idx) => (
            <button
              key={idx}
              onClick={() => setActiveModel(idx)}
              className={`p-6 rounded-2xl text-left transition-all border flex flex-col justify-between ${
                activeModel === idx
                  ? 'bg-orange-500/20 border-orange-500/50 shadow-xl shadow-orange-500/10 scale-102'
                  : 'bg-white/5 border-white/10 hover:bg-white/10'
              }`}
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  {m.bundled ? (
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                      Bundled
                    </span>
                  ) : (
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-white/10 text-slate-400">
                      1-Click Download
                    </span>
                  )}
                </div>
                <h4 className="text-base font-bold text-white mb-1">{m.name}</h4>
                <p className="text-xs text-slate-400 mb-4">{m.bestFor}</p>
              </div>

              <div className="pt-4 border-t border-white/10 space-y-1.5 text-xs font-mono">
                <div className="flex justify-between text-slate-400">
                  <span>Disk Size:</span>
                  <span className="text-white font-bold">{m.disk}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>RAM:</span>
                  <span className="text-white font-bold">{m.ram}</span>
                </div>
                <div className="flex justify-between text-slate-400">
                  <span>Latency:</span>
                  <span className="text-orange-400 font-bold">{m.latency}</span>
                </div>
              </div>
            </button>
          ))}
        </div>

        {/* Active Model Spec Detail Card */}
        <div className="glass-panel rounded-3xl p-8 sm:p-12 border border-white/10 flex flex-col lg:flex-row items-center justify-between gap-8">
          <div>
            <div className="flex items-center gap-2 text-xs font-mono text-orange-400 font-bold mb-2">
              <Sparkles className="w-4 h-4" /> Selected Model: {models[activeModel].name}
            </div>
            <h3 className="text-2xl sm:text-3xl font-bold text-white mb-2">
              {models[activeModel].bestFor}
            </h3>
            <p className="text-slate-400 text-sm max-w-xl">
              Fully optimized with Apple Metal GPU compute kernels. Supports automatic language detection, sentence-level punctuation restoration, and custom dictionary entity biasing.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-4 shrink-0">
            <div className="px-5 py-3 rounded-xl bg-white/5 border border-white/10 text-center">
              <div className="text-xl font-bold font-mono text-emerald-400">{models[activeModel].accuracy}</div>
              <div className="text-[11px] text-slate-400 font-mono">Accuracy Score</div>
            </div>
            <div className="px-5 py-3 rounded-xl bg-white/5 border border-white/10 text-center">
              <div className="text-xl font-bold font-mono text-orange-400">{models[activeModel].latency}</div>
              <div className="text-[11px] text-slate-400 font-mono">Metal Latency</div>
            </div>
          </div>
        </div>

      </div>
    </section>
  );
}
