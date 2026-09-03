import React from 'react';
import { motion } from 'framer-motion';
import { Download, Github, Shield, Sparkles, Cpu } from 'lucide-react';

export default function DownloadSection() {
  return (
    <section className="py-28 px-4 relative z-20 border-t border-white/10 bg-[#09090b]">
      <div className="max-w-5xl mx-auto text-center relative">
        {/* Subtle Ambient Radial Glow */}
        <div
          className="absolute inset-0 pointer-events-none opacity-20"
          style={{
            background: 'radial-gradient(ellipse 60% 50% at 50% 35%, rgba(95, 97, 237, 0.4), transparent 70%)',
          }}
        />

        <div className="relative z-10 glass-panel p-10 sm:p-16 rounded-[36px] shadow-2xl border border-white/10">
          {/* App Icon */}
          <div className="mb-8 flex justify-center">
            <img
              src="/assets/app-icon.png"
              alt="Utter Icon"
              className="w-20 h-20 rounded-2xl shadow-2xl border border-white/15"
            />
          </div>

          <h2 className="text-4xl sm:text-5xl md:text-6xl font-extrabold tracking-tight text-white mb-6">
            Ready to speak at the speed of thought?
          </h2>

          <p className="text-lg text-zinc-400 max-w-xl mx-auto mb-10 leading-relaxed">
            Download Utter for macOS today. 100% on-device, fully open source, and completely air-gapped.
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4 mb-10">
            <a
              href="https://github.com/h3x-levi/Utter/releases/latest"
              className="flex items-center gap-2.5 bg-white text-black px-9 py-4 rounded-full font-bold text-base hover:bg-zinc-200 transition-all shadow-xl active:scale-95"
            >
              <Download size={19} />
              Download for Mac
              <span className="text-xs font-mono opacity-60 ml-1">v1.1.56</span>
            </a>

            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2.5 border border-white/15 bg-white/5 text-white px-8 py-4 rounded-full font-semibold text-base hover:bg-white/10 transition-all active:scale-95 shadow-sm"
            >
              <Github size={19} />
              View Source on GitHub
            </a>
          </div>

          <div className="flex flex-wrap items-center justify-center gap-6 text-xs text-zinc-500 font-mono">
            <span className="flex items-center gap-1.5">
              <Shield size={13} className="text-emerald-400" /> Zero Telemetry
            </span>
            <span>•</span>
            <span className="flex items-center gap-1.5">
              <Cpu size={13} className="text-indigo-400" /> Apple Silicon & Intel
            </span>
            <span>•</span>
            <span>macOS 14+ Sonoma & Sequoia</span>
            <span>•</span>
            <span>MIT License</span>
          </div>
        </div>
      </div>
    </section>
  );
}
