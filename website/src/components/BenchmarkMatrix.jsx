import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Zap, Shield, DollarSign, WifiOff, Check, X, Sliders, Sparkles } from 'lucide-react';

const COMPARISON_ROWS = [
  {
    feature: 'Inference Latency',
    utter: '168ms (Instant)',
    cloud: '1,400ms – 2,400ms',
    siri: '850ms',
    highlight: true,
  },
  {
    feature: 'Data Privacy & Telemetry',
    utter: '100% On-Device (0 Bytes Sent)',
    cloud: 'Cloud Servers (Audio Uploaded)',
    siri: 'Apple Servers (Cloud Logged)',
    highlight: true,
  },
  {
    feature: 'Monthly Cost',
    utter: '$0 Free & Open Source',
    cloud: '$12 – $20 / month',
    siri: 'Free with macOS',
    highlight: true,
  },
  {
    feature: 'Offline Mode (Airplanes & Vaults)',
    utter: 'Full 100% Functionality',
    cloud: 'Fails or Degraded',
    siri: 'Limited Vocabulary',
  },
  {
    feature: 'Code & Technical Jargon Biasing',
    utter: 'Custom Dictionary Boosting',
    cloud: 'Requires Pro Subscription',
    siri: 'Poor (Confuses Code Terms)',
  },
  {
    feature: 'Dual-Stream Meeting Capture',
    utter: 'Built-in (You vs Others)',
    cloud: 'Requires Invasive Bot',
    siri: 'Not Supported',
  },
  {
    feature: 'Articulated Desktop Companions',
    utter: 'Pixel Cat, Dog, Panda (60 FPS)',
    cloud: 'None',
    siri: 'None',
  },
];

export default function BenchmarkMatrix() {
  const [wordsPerDay, setWordsPerDay] = useState(1500);

  // Calculate annual savings compared to $15/mo cloud dictation app
  const annualCloudCost = 15 * 12;
  const timeSavedHoursPerYear = Math.round((wordsPerDay / 150) * 0.4 * 250);

  return (
    <section id="benchmarks" className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-amber-400 mb-4 border border-amber-500/20">
          <Zap size={13} />
          <span>PERFORMANCE BENCHMARKS</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Engineered to outpace the cloud.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          By executing whisper.cpp directly against Apple Silicon Metal cores, Utter cuts latency by over 80% while saving you hundreds of dollars in cloud subscriptions.
        </p>
      </div>

      {/* Interactive Savings & Latency Calculator */}
      <div className="liquid-glass rounded-3xl p-6 sm:p-8 border border-white/10 shadow-2xl mb-12">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          <div className="lg:col-span-6 space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-xs font-mono uppercase text-zinc-400">Daily Dictation Volume</span>
              <span className="text-sm font-bold font-mono text-orange-400">{wordsPerDay.toLocaleString()} words/day</span>
            </div>
            <input
              type="range"
              min="300"
              max="5000"
              step="100"
              value={wordsPerDay}
              onChange={(e) => setWordsPerDay(Number(e.target.value))}
              className="w-full accent-orange-500 cursor-pointer h-2 bg-zinc-800 rounded-lg"
            />
            <div className="flex justify-between text-[11px] font-mono text-zinc-500">
              <span>Light (300 words)</span>
              <span>Average (1,500 words)</span>
              <span>Heavy (5,000 words)</span>
            </div>
          </div>

          <div className="lg:col-span-6 grid grid-cols-2 gap-4">
            <motion.div
              whileHover={{ y: -2, scale: 1.02 }}
              transition={{ type: 'spring', stiffness: 400, damping: 25 }}
              className="p-4 rounded-2xl bg-zinc-950/80 border border-white/5 text-center shadow-lg"
            >
              <div className="text-2xl sm:text-3xl font-black font-mono text-emerald-400 mb-1">
                ${annualCloudCost}
              </div>
              <div className="text-xs text-zinc-400 font-mono">Saved Per Year vs Cloud Apps</div>
            </motion.div>
            <motion.div
              whileHover={{ y: -2, scale: 1.02 }}
              transition={{ type: 'spring', stiffness: 400, damping: 25 }}
              className="p-4 rounded-2xl bg-zinc-950/80 border border-white/5 text-center shadow-lg"
            >
              <div className="text-2xl sm:text-3xl font-black font-mono text-amber-400 mb-1">
                ~{timeSavedHoursPerYear} hrs
              </div>
              <div className="text-xs text-zinc-400 font-mono">Time Saved vs Typing</div>
            </motion.div>
          </div>
        </div>
      </div>

      {/* Comparison Table */}
      <div className="liquid-glass rounded-3xl border border-white/10 shadow-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs sm:text-sm">
            <thead>
              <tr className="border-b border-white/10 bg-zinc-900/60 font-mono text-xs text-zinc-400">
                <th className="py-4 px-6 font-semibold">Capability</th>
                <th className="py-4 px-6 text-orange-400 font-bold bg-orange-500/10 border-x border-orange-500/20">
                  Utter (Native Metal)
                </th>
                <th className="py-4 px-6 font-semibold">Cloud AI Dictation Apps</th>
                <th className="py-4 px-6 font-semibold">macOS Siri Dictation</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {COMPARISON_ROWS.map((row, idx) => (
                <tr
                  key={row.feature}
                  className={`transition-colors duration-150 ${row.highlight ? 'bg-white/[0.02]' : ''} hover:bg-white/[0.06]`}
                >
                  <td className="py-4 px-6 font-medium text-zinc-200">{row.feature}</td>
                  <td className="py-4 px-6 font-bold text-white bg-orange-500/5 border-x border-orange-500/20">
                    <span className="flex items-center gap-2">
                      <Check size={15} className="text-orange-400 shrink-0" />
                      <span>{row.utter}</span>
                    </span>
                  </td>
                  <td className="py-4 px-6 text-zinc-400">{row.cloud}</td>
                  <td className="py-4 px-6 text-zinc-400">{row.siri}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
