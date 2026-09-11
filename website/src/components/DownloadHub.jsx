import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Download, Terminal, Copy, Check, Shield, Cpu, Apple, Sparkles, Github, ArrowUpRight } from 'lucide-react';

export default function DownloadHub() {
  const [copied, setCopied] = useState(false);

  const handleCopyBrew = () => {
    navigator.clipboard.writeText('brew install --cask utter');
    setCopied(true);
    setTimeout(() => setCopied(false), 2200);
  };

  return (
    <section id="download" className="relative py-16 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto z-10">
      <motion.div
        initial={{ opacity: 0, scale: 0.94, y: 25 }}
        whileInView={{ opacity: 1, scale: 1, y: 0 }}
        viewport={{ once: true, amount: 0.2 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        className="liquid-glass rounded-3xl p-8 sm:p-12 lg:p-14 border border-white/20 shadow-2xl text-center flex flex-col items-center relative overflow-hidden"
      >
        {/* Dynamic colorful mesh glow inside the card */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[650px] h-[450px] bg-gradient-to-tr from-orange-500/25 via-amber-500/15 to-indigo-500/10 blur-[130px] rounded-full pointer-events-none -z-10" />

        {/* Release Tag */}
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-5 border border-orange-500/20">
          <Sparkles size={13} />
          <span>PRODUCTION RELEASE v1.1.56 • NOTARIZED BY APPLE</span>
        </div>

        {/* Title */}
        <h2 className="text-3xl sm:text-5xl lg:text-6xl font-black tracking-tight text-white mb-5 max-w-[820px] leading-[1.08]">
          Ready to speak at the speed of thought?
        </h2>

        {/* Subtitle */}
        <p className="text-zinc-200 text-base sm:text-lg max-w-[620px] mb-8 leading-relaxed">
          Download the signed universal build for macOS. Runs 100% on-device in unified memory with sub-200ms latency and zero cloud telemetry.
        </p>

        {/* Primary Action Buttons */}
        <div className="flex flex-wrap items-center justify-center gap-3.5 mb-8">
          {/* Direct DMG Download */}
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="inline-flex items-center gap-3 px-8 py-3.5 rounded-full text-base font-bold text-zinc-950 bg-gradient-to-r from-orange-400 via-amber-300 to-yellow-200 hover:from-orange-300 hover:to-yellow-100 shadow-2xl shadow-orange-500/25 active:scale-95 transition-all duration-150"
          >
            <Download size={18} />
            <span>Download Utter for Mac (.dmg)</span>
          </a>

          {/* GitHub Releases Link */}
          <a
            href="https://github.com/h3x-levi/Utter/releases"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3.5 rounded-full text-xs sm:text-sm font-semibold text-zinc-200 hover:text-white liquid-glass hover:bg-white/10 border border-white/15 transition-all active:scale-95"
          >
            <Github size={16} />
            <span>All Releases & Checksums</span>
            <ArrowUpRight size={13} />
          </a>
        </div>

        {/* Real Working Homebrew Command */}
        <div className="w-full max-w-[620px] mb-10">
          <div className="text-xs font-mono uppercase text-zinc-300 mb-2">Instant Terminal Install (Homebrew)</div>
          <div className="p-3.5 rounded-2xl bg-zinc-950/90 border border-white/15 flex items-center justify-between font-mono text-xs text-zinc-200 shadow-inner">
            <div className="flex items-center gap-2.5 overflow-x-auto select-all">
              <Terminal size={15} className="text-orange-400 shrink-0" />
              <code className="text-orange-300 font-bold whitespace-nowrap">brew install --cask utter</code>
            </div>
            <button
              onClick={handleCopyBrew}
              className="ml-3 p-2 rounded-xl bg-white/10 hover:bg-white/15 text-zinc-300 hover:text-white shrink-0 transition-colors flex items-center gap-1.5"
              title="Copy Homebrew command"
            >
              {copied ? (
                <>
                  <Check size={14} className="text-emerald-400" />
                  <span className="text-[11px] font-sans text-emerald-400 font-semibold">Copied!</span>
                </>
              ) : (
                <>
                  <Copy size={14} />
                  <span className="text-[11px] font-sans">Copy</span>
                </>
              )}
            </button>
          </div>
        </div>

        {/* Specs & Hardware Compatibility Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 pt-8 border-t border-white/10 w-full max-w-[900px] text-left">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-white/5 text-zinc-300 border border-white/5">
              <Apple size={18} />
            </div>
            <div>
              <div className="text-xs font-mono uppercase text-zinc-400">System Compatibility</div>
              <div className="text-sm font-semibold text-white">macOS 14 Sonoma & 15 Sequoia</div>
              <div className="text-xs text-zinc-400 mt-0.5">Compatible with macOS 13.3+</div>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-white/5 text-zinc-300 border border-white/5">
              <Cpu size={18} />
            </div>
            <div>
              <div className="text-xs font-mono uppercase text-zinc-400">Hardware Architecture</div>
              <div className="text-sm font-semibold text-white">Apple Silicon (M1 / M2 / M3 / M4)</div>
              <div className="text-xs text-zinc-400 mt-0.5">Universal Binary with Intel AVX2</div>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-white/5 text-zinc-300 border border-white/5">
              <Shield size={18} />
            </div>
            <div>
              <div className="text-xs font-mono uppercase text-zinc-400">Open Source License</div>
              <div className="text-sm font-semibold text-white">Apache 2.0 (100% Free)</div>
              <div className="text-xs text-zinc-400 mt-0.5">Zero tracking, zero DRM</div>
            </div>
          </div>
        </div>
      </motion.div>
    </section>
  );
}
