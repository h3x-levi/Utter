import React from 'react';
import { Download, Github, Shield, Sparkles, Cpu, Check } from 'lucide-react';

export default function DownloadSection() {
  return (
    <section className="py-24 px-4 sm:px-8 bg-colorful-mesh/90 backdrop-blur-md border-t border-black/[0.06] w-full">
      <div className="w-full max-w-[94vw] 2xl:max-w-[1500px] mx-auto text-center">
        <div className="card-opaque p-10 sm:p-16 shadow-2xl relative overflow-hidden bg-white">
          {/* Subtle colorful aura */}
          <div
            className="absolute inset-0 pointer-events-none opacity-40"
            style={{
              background: 'radial-gradient(ellipse 60% 40% at 50% 15%, rgba(99, 102, 241, 0.15), transparent 70%)',
            }}
          />

          <div className="relative z-10 flex flex-col items-center">
            <img
              src="/assets/app-icon.png"
              alt="Utter App Icon"
              className="w-20 h-20 rounded-2xl shadow-lg border border-black/10 mb-6"
            />

            <h2 className="text-4xl sm:text-5xl font-extrabold tracking-tight text-zinc-900 mb-4 max-w-xl">
              Ready to speak at the speed of thought?
            </h2>

            <p className="text-base sm:text-lg text-zinc-600 max-w-lg mb-8 leading-relaxed">
              Install Utter on your Mac today. Free, open-source, and runs 100% on your device with zero monthly fees.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-3.5 mb-8">
              <a
                href="https://github.com/h3x-levi/Utter/releases/latest"
                className="flex items-center gap-2.5 bg-zinc-900 text-white hover:bg-black px-8 py-4 rounded-full font-bold text-sm shadow-lg hover:shadow-xl transition-all active:scale-95"
              >
                <Download size={18} />
                Download for Mac
                <span className="text-xs font-mono opacity-60 ml-1">v1.1.56</span>
              </a>

              <a
                href="https://github.com/h3x-levi/Utter"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2.5 bg-zinc-100 text-zinc-800 hover:text-black hover:bg-zinc-200/80 px-7 py-4 rounded-full font-semibold text-sm transition-all active:scale-95"
              >
                <Github size={18} />
                View Source on GitHub
              </a>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-semibold text-zinc-500">
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> macOS 14 & 15 Native
              </span>
              <span>•</span>
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> Apple Silicon Unified RAM
              </span>
              <span>•</span>
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> MIT License
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
