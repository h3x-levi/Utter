import React from 'react';
import { Check, X } from 'lucide-react';

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
        <span className="inline-flex items-center gap-1.5 text-zinc-200 font-medium font-mono text-xs">
          <Check className="w-3.5 h-3.5 text-white" /> Yes
        </span>
      );
    }
    if (val === false) {
      return (
        <span className="inline-flex items-center gap-1.5 text-zinc-600 font-mono text-xs">
          <X className="w-3.5 h-3.5" /> No
        </span>
      );
    }
    return <span className="font-mono text-xs text-zinc-400">{val}</span>;
  };

  return (
    <section id="comparison" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-6xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Feature Breakdown
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            How Utter compares.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Why privacy-first developers, writers, and power users choose on-device Metal compute.
          </p>
        </div>

        {/* Comparison Table */}
        <div className="apple-panel rounded-2xl overflow-hidden border border-zinc-800 shadow-2xl">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-zinc-800 bg-[#141418]">
                  <th className="p-5 text-xs font-bold text-zinc-300 uppercase font-mono">Feature / Capability</th>
                  <th className="p-5 text-xs font-bold text-white bg-zinc-800/80 border-x border-zinc-700 uppercase font-mono">
                    Utter (On-Device)
                  </th>
                  <th className="p-5 text-xs font-bold text-zinc-400 uppercase font-mono">Cloud Voice Apps</th>
                  <th className="p-5 text-xs font-bold text-zinc-400 uppercase font-mono">macOS Dictation</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-800/60">
                {rows.map((r, idx) => (
                  <tr key={idx} className="hover:bg-white/[0.01] transition-colors">
                    <td className="p-4 text-xs sm:text-sm font-medium text-zinc-300">{r.feature}</td>
                    <td className="p-4 bg-zinc-900/50 border-x border-zinc-800 text-white font-medium">
                      {renderVal(r.utter)}
                    </td>
                    <td className="p-4 text-zinc-400">{renderVal(r.cloud)}</td>
                    <td className="p-4 text-zinc-400">{renderVal(r.apple)}</td>
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
