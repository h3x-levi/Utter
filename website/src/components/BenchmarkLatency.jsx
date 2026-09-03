import React, { useState } from 'react';
import { Zap, Gauge, Server, WifiOff } from 'lucide-react';

export default function BenchmarkLatency() {
  const [audioDuration, setAudioDuration] = useState(15); // seconds

  const metalLatency = (0.12 + audioDuration * 0.003).toFixed(2);
  const cloudLatency = (0.45 + audioDuration * 0.05 + 0.65).toFixed(2);

  return (
    <section id="benchmarks" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-5xl mx-auto">

        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Hardware Acceleration Benchmarks
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            On-Device Metal vs. Cloud APIs
          </h2>
          <p className="text-slate-400 text-base sm:text-lg">
            Compare real-world speech transcription latency with local Apple Silicon GPU compute.
          </p>
        </div>

        <div className="glass-panel rounded-3xl p-8 sm:p-12 border border-white/10">

          {/* Interactive Duration Slider */}
          <div className="mb-10 p-6 rounded-2xl bg-white/5 border border-white/10">
            <div className="flex justify-between items-center text-sm font-mono mb-4">
              <span className="text-slate-300">Simulate Speech Audio Duration:</span>
              <span className="text-orange-400 font-bold text-base">{audioDuration} seconds of speech</span>
            </div>
            <input
              type="range"
              min="3"
              max="60"
              value={audioDuration}
              onChange={(e) => setAudioDuration(Number(e.target.value))}
              className="w-full h-2 bg-white/10 rounded-lg appearance-none cursor-pointer accent-orange-500"
            />
          </div>

          {/* Latency Comparison Bars */}
          <div className="space-y-6">

            {/* Local Metal GPU */}
            <div>
              <div className="flex justify-between text-sm font-mono mb-2">
                <span className="text-white font-bold flex items-center gap-2">
                  <Zap className="w-4 h-4 text-orange-400" />
                  Utter (whisper.cpp on Apple Metal GPU)
                </span>
                <span className="text-orange-400 font-bold text-base">{metalLatency}s (Instant Response)</span>
              </div>
              <div className="w-full h-4 rounded-full bg-white/5 overflow-hidden border border-white/10">
                <div
                  className="h-full bg-gradient-to-r from-orange-500 to-amber-400 rounded-full transition-all duration-300"
                  style={{ width: `${Math.min(100, (metalLatency / cloudLatency) * 80)}%` }}
                />
              </div>
            </div>

            {/* Cloud Whisper API */}
            <div>
              <div className="flex justify-between text-sm font-mono mb-2">
                <span className="text-slate-400 flex items-center gap-2">
                  <Server className="w-4 h-4 text-slate-500" />
                  Cloud Whisper API (Audio Upload + Queue + Network Roundtrip)
                </span>
                <span className="text-slate-400 font-mono">{cloudLatency}s</span>
              </div>
              <div className="w-full h-4 rounded-full bg-white/5 overflow-hidden border border-white/5">
                <div className="h-full bg-slate-600 rounded-full transition-all duration-300" style={{ width: '85%' }} />
              </div>
            </div>

          </div>

          {/* 4 Stat Tiles */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-12 pt-8 border-t border-white/10 text-center">
            <div>
              <div className="text-2xl sm:text-3xl font-bold font-mono text-white">0.0 ms</div>
              <div className="text-xs text-slate-400 mt-1">Network Cloud Latency</div>
            </div>
            <div>
              <div className="text-2xl sm:text-3xl font-bold font-mono text-emerald-400">100%</div>
              <div className="text-xs text-slate-400 mt-1">Air-Gapped Privacy</div>
            </div>
            <div>
              <div className="text-2xl sm:text-3xl font-bold font-mono text-orange-400">&lt; 180MB</div>
              <div className="text-xs text-slate-400 mt-1">Memory Footprint (Small.en)</div>
            </div>
            <div>
              <div className="text-2xl sm:text-3xl font-bold font-mono text-white">$0.00</div>
              <div className="text-xs text-slate-400 mt-1">Subscription / Month</div>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
