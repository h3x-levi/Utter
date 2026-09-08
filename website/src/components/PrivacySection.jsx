import React, { useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { Shield, Wifi, Eye, Terminal, Check, Copy } from 'lucide-react';

const cards = [
  {
    title: 'Zero Cloud Architecture',
    badge: 'Hardware Verified',
    icon: Shield,
    iconColor: 'text-emerald-600',
    iconBg: 'bg-emerald-500/10 border-emerald-200/50',
    desc: 'Your voice data never leaves your Mac. Every transcription runs strictly in local unified memory through whisper.cpp on Apple Silicon Metal GPU. No external servers, no network calls, no cloud latency.',
    details: ['100% on-device inference', 'Apple Silicon Metal acceleration', 'Zero third-party API dependencies'],
  },
  {
    title: 'Zero Telemetry & Analytics',
    badge: 'Complete Isolation',
    icon: Eye,
    iconColor: 'text-indigo-600',
    iconBg: 'bg-indigo-500/10 border-indigo-200/50',
    desc: 'Utter collects exactly zero usage metrics. No crash reports phoned home, no keystroke telemetry, no feature event tracking, no A/B testing on your workflows. What you say stays on your machine.',
    details: ['No tracking SDKs bundled', 'Zero user identification', 'Open source inspection on GitHub'],
  },
  {
    title: 'Zero Network Sockets',
    badge: 'Terminal Proof',
    icon: Wifi,
    iconColor: 'text-amber-600',
    iconBg: 'bg-amber-500/10 border-amber-200/50',
    desc: 'During active audio capture and dictation, Utter opens exactly 0 network sockets. You can audit the process yourself via Terminal or Little Snitch at any moment.',
    details: ['Works completely offline', 'Airplane mode fully supported', 'Verified with macOS audit tools'],
  },
];

export default function PrivacySection() {
  const shouldReduceMotion = useReducedMotion();
  const [copied, setCopied] = useState(false);

  const copyCommand = () => {
    navigator.clipboard.writeText('lsof -i -P | grep -i utter');
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section id="privacy" className="py-24 px-4 sm:px-8 w-full relative z-10">
      <div className="max-w-7xl mx-auto">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-emerald-50/90 backdrop-blur-md border border-emerald-200/60 shadow-xs text-xs font-semibold text-emerald-800 mb-4">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Air-Gapped Privacy Architecture</span>
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight text-zinc-950 mb-4">
            Private by architecture, not by policy.
          </h2>
          <p className="text-base sm:text-lg text-zinc-600 leading-relaxed">
            Other dictation tools send your private audio to cloud servers. Utter is physically incapable of making outbound network requests.
          </p>
        </div>

        {/* 3 Frosted Glass Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
          {cards.map((card, i) => {
            const Icon = card.icon;
            return (
              <motion.div
                key={card.title}
                initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: '-60px' }}
                transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1], delay: i * 0.08 }}
                className="frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-6">
                    <div className={`w-12 h-12 rounded-2xl ${card.iconBg} border flex items-center justify-center ${card.iconColor}`}>
                      <Icon size={24} />
                    </div>
                    <span className="text-[11px] font-mono font-semibold px-2.5 py-1 rounded-full bg-white/80 border border-black/[0.06] text-zinc-600 shadow-2xs">
                      {card.badge}
                    </span>
                  </div>

                  <h3 className="text-xl font-bold text-zinc-950 mb-3 tracking-tight">
                    {card.title}
                  </h3>
                  <p className="text-sm text-zinc-600 leading-relaxed mb-6">
                    {card.desc}
                  </p>
                </div>

                <div className="pt-6 border-t border-black/[0.06] space-y-2">
                  {card.details.map((detail) => (
                    <div key={detail} className="flex items-center gap-2 text-xs font-medium text-zinc-700">
                      <Check size={13} className="text-emerald-500 shrink-0" />
                      <span>{detail}</span>
                    </div>
                  ))}
                </div>
              </motion.div>
            );
          })}
        </div>

        {/* Terminal Verification Audit Bar */}
        <motion.div
          initial={shouldReduceMotion ? false : { opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-40px' }}
          transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1] }}
          className="max-w-3xl mx-auto frosted-glass-card p-6 border border-zinc-200/80 shadow-lg"
        >
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-zinc-900 text-zinc-100 flex items-center justify-center shrink-0">
                <Terminal size={18} />
              </div>
              <div>
                <div className="text-xs font-bold text-zinc-900">Verify Network Isolation on macOS</div>
                <div className="font-mono text-xs text-zinc-500">Confirm zero open sockets while speaking</div>
              </div>
            </div>

            <div className="flex items-center gap-2 bg-zinc-950 text-zinc-200 px-4 py-2.5 rounded-xl font-mono text-xs border border-zinc-800">
              <span className="text-emerald-400">$</span>
              <span className="select-all">lsof -i -P | grep -i utter</span>
              <button
                onClick={copyCommand}
                className="ml-2 text-zinc-400 hover:text-white transition-colors cursor-pointer"
                title="Copy terminal command"
              >
                {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
