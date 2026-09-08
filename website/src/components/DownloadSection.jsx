import React from 'react';
import { Download, Github, Check } from 'lucide-react';

export default function DownloadSection() {
  return (
    <section className="py-24 px-4 sm:px-8 w-full relative z-10">
      <div className="max-w-5xl mx-auto text-center">
        <div className="frosted-glass-card p-10 sm:p-16 shadow-2xl relative overflow-hidden border border-white/90">
          <div className="relative z-10 flex flex-col items-center">
            <img
              src="/assets/app-icon.png"
              alt="Utter App Icon"
              className="w-20 h-20 rounded-3xl shadow-xl border border-white/80 mb-6"
            />

            <h2 className="text-4xl sm:text-5xl font-extrabold tracking-tight text-zinc-950 mb-4 max-w-xl">
              Ready to speak at the speed of thought?
            </h2>

            <p className="text-base sm:text-lg text-zinc-600 max-w-lg mb-8 leading-relaxed">
              Install Utter on your Mac today. Free, open source, and runs 100% on your device with zero monthly fees.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-3.5 mb-8">
              <a
                href="https://github.com/h3x-levi/Utter/releases/latest"
                className="flex items-center gap-2.5 bg-zinc-950 text-white hover:bg-black px-8 py-4 rounded-full font-bold text-sm shadow-xl hover:shadow-2xl transition-transform transition-colors duration-150 ease-out active:scale-[0.97] cursor-pointer"
              >
                <Download size={18} />
                <span>Download for Mac</span>
                <span className="text-xs font-mono opacity-60 ml-1">v1.1.56</span>
              </a>

              <a
                href="https://github.com/h3x-levi/Utter"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2.5 frosted-glass text-zinc-900 hover:text-black px-7 py-4 rounded-full font-semibold text-sm transition-transform transition-colors duration-150 ease-out active:scale-[0.97] cursor-pointer border border-white/80 shadow-xs"
              >
                <Github size={18} />
                <span>View Source on GitHub</span>
              </a>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-semibold text-zinc-600">
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> macOS 14 & 15 Native
              </span>
              <span>•</span>
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> Apple Silicon Unified RAM
              </span>
              <span>•</span>
              <span className="flex items-center gap-1.5">
                <Check size={14} className="text-emerald-500 stroke-[3]" /> Zero Network Calls
              </span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
