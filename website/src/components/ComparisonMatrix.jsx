import React from 'react';
import { Check, X, Minus, ShieldCheck, Zap, Sparkles } from 'lucide-react';

export default function ComparisonMatrix() {
  const rows = [
    { feature: 'Speech Recognition Engine', utter: 'whisper.cpp on Apple Metal GPU', cloud: 'Proprietary Cloud API', apple: 'Legacy Cloud/On-Device Engine' },
    { feature: 'End-to-End Latency', utter: '168 ms (Instant)', cloud: '1,240 ms (Network delay)', apple: '890 ms' },
    { feature: 'Air-Gapped & Offline Ready', utter: true, cloud: false, apple: 'Partial' },
    { feature: 'Zero Cloud Telemetry / Privacy', utter: true, cloud: false, apple: 'Audio sent for analytics' },
    { feature: 'Monthly Subscription Cost', utter: '$0 (100% Free & Open Source)', cloud: '$15 – $30 / month', apple: '$0 (Built-in)' },
    { feature: 'Custom Developer Vocabulary & Biasing', utter: true, cloud: 'Limited', apple: false },
    { feature: 'Non-Destructive Cursor Injection', utter: true, cloud: 'Overwrites clipboard', apple: true },
    { feature: 'Two-Way Meeting Audio Transcription', utter: true, cloud: false, apple: false },
    { feature: 'Interactive Desktop Pixel Pets', utter: true, cloud: false, apple: false },
    { feature: 'Apple Silicon Metal GPU Shaders', utter: true, cloud: false, apple: false },
    { feature: 'Zero Account / API Key Setup', utter: true, cloud: false, apple: true },
    { feature: 'Memory Footprint', utter: '< 180 MB RAM', cloud: '350 – 800 MB (Electron)', apple: 'OS Managed' },
  ];

  const renderVal = (val) => {
    if (val === true) {
      return (
        <span className="inline-flex items-center gap-1.5 text-emerald-400 font-bold font-mono text-xs">
          <Check className="w-4 h-4" /> Yes
        </span>
      );
    }
    if (val === false) {
      return (
        <span className="inline-flex items-center gap-1.5 text-rose-500 font-mono text-xs">
          <X className="w-4 h-4" /> No
        </span>
      );
    }
    return <span className="font-mono text-xs text-slate-300">{val}</span>;
  };

  return (
    <section id="comparison" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-6xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Feature Breakdown
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            How Utter compares.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Why privacy-first developers, writers, and power users choose on-device Metal compute.
          </p>
        </div>

        {/* Comparison Table */}
        <div className="glass-panel rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/10 bg-[#121624]">
                  <th className="p-6 text-sm font-bold text-white">Feature / Capability</th>
                  <th className="p-6 text-sm font-bold text-orange-400 bg-orange-500/10 border-x border-orange-500/20">
                    <span className="flex items-center gap-2">
                      <Sparkles className="w-4 h-4 text-orange-400" /> Utter (On-Device)
                    </span>
                  </th>
                  <th className="p-6 text-sm font-bold text-slate-400">Cloud AI Voice Wrappers</th>
                  <th className="p-6 text-sm font-bold text-slate-400">Default macOS Dictation</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {rows.map((r, idx) => (
                  <tr key={idx} className="hover:bg-white/[0.02] transition-colors">
                    <td className="p-5 text-sm font-medium text-slate-200">{r.feature}</td>
                    <td className="p-5 bg-orange-500/[0.04] border-x border-orange-500/20">
                      {renderVal(r.utter)}
                    </td>
                    <td className="p-5 text-slate-400">{renderVal(r.cloud)}</td>
                    <td className="p-5 text-slate-400">{renderVal(r.apple)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </section>
  );
}
