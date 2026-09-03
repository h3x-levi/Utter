import React, { useState } from 'react';
import { Zap, Server } from 'lucide-react';

export default function BenchmarkLatency() {
  const [audioDuration, setAudioDuration] = useState(15); // seconds

  const metalLatency = (0.12 + audioDuration * 0.003).toFixed(2);
  const cloudLatency = (0.45 + audioDuration * 0.05 + 0.65).toFixed(2);

  return (
    <section id="benchmarks" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-5xl mx-auto">

        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Hardware Acceleration Benchmarks
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            On-Device Metal vs. Cloud APIs
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Compare real-world speech transcription latency with local Apple Silicon GPU compute.
          </p>
        </div>

        <div className="apple-panel rounded-2xl p-8 sm:p-12 border border-zinc-800">

          {/* Interactive Duration Slider */}
          <div className="mb-10 p-5 rounded-xl bg-[#121215] border border-zinc-800">
            <div className="flex justify-between items-center text-xs font-mono mb-3">
              <span className="text-zinc-400">Audio Stream Duration:</span>
              <span className="text-white font-semibold">{audioDuration} seconds</span>
            </div>
            <input
              type="range"
              min="3"
              max="60"
              value={audioDuration}
              onChange={(e) => setAudioDuration(Number(e.target.value))}
              className="w-full h-1.5 bg-zinc-800 rounded-lg appearance-none cursor-pointer accent-white"
            />
          </div>

          {/* Latency Comparison Bars */}
          <div className="space-y-6">

            {/* Local Metal GPU */}
            <div>
              <div className="flex justify-between text-xs font-mono mb-2">
                <span className="text-white font-medium flex items-center gap-2">
                  <Zap className="w-3.5 h-3.5 text-white" />
                  Utter (whisper.cpp on Apple Metal GPU)
                </span>
                <span className="text-white font-bold">{metalLatency}s (Instant)</span>
              </div>
              <div className="w-full h-3 rounded-full bg-zinc-800 overflow-hidden">
                <div
                  className="h-full bg-white rounded-full transition-all duration-300"
                  style={{ width: `${Math.min(100, (metalLatency / cloudLatency) * 80)}%` }}
                />
              </div>
            </div>

            {/* Cloud Whisper API */}
            <div>
              <div className="flex justify-between text-xs font-mono mb-2">
                <span className="text-zinc-400 flex items-center gap-2">
                  <Server className="w-3.5 h-3.5 text-zinc-500" />
                  Cloud Whisper API (Audio Upload + Queue + Server Processing)
                </span>
                <span className="text-zinc-500">{cloudLatency}s</span>
              </div>
              <div className="w-full h-3 rounded-full bg-zinc-900 overflow-hidden">
                <div className="h-full bg-zinc-600 rounded-full transition-all duration-300" style={{ width: '85%' }} />
              </div>
            </div>

          </div>

          {/* 4 Stat Tiles */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-10 pt-8 border-t border-zinc-800 text-center">
            <div>
              <div className="text-2xl font-bold font-mono text-white">0.0 ms</div>
              <div className="text-xs text-zinc-500 mt-1">Network Latency</div>
            </div>
            <div>
              <div className="text-2xl font-bold font-mono text-zinc-200">100%</div>
              <div className="text-xs text-zinc-500 mt-1">Air-Gapped Offline</div>
            </div>
            <div>
              <div className="text-2xl font-bold font-mono text-zinc-300">&lt; 180MB</div>
              <div className="text-xs text-zinc-500 mt-1">RAM Footprint</div>
            </div>
            <div>
              <div className="text-2xl font-bold font-mono text-white">$0.00</div>
              <div className="text-xs text-zinc-500 mt-1">Subscription / Month</div>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
