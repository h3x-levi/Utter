import React from 'react';
import { Download, Github } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="py-24 px-6 border-t border-zinc-800 bg-[#060608] relative z-10 text-center">
      <div className="max-w-4xl mx-auto">
        <img
          src="/assets/app-icon.png"
          alt="Utter Icon"
          className="w-14 h-14 rounded-2xl mx-auto mb-6 shadow-2xl border border-white/10"
        />

        <h2 className="text-3xl sm:text-4xl font-bold text-white mb-3 tracking-tight">
          Ready to speak at the speed of thought?
        </h2>

        <p className="text-zinc-400 text-sm sm:text-base max-w-lg mx-auto mb-8">
          Download Utter for macOS today. 100% local, private, and lightning fast.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 mb-12">
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="w-full sm:w-auto px-6 py-3 rounded-xl text-xs sm:text-sm font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all shadow-lg active:scale-98"
          >
            Download Free DMG (v1.1.56)
          </a>
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="w-full sm:w-auto flex items-center justify-center gap-2 px-6 py-3 rounded-xl text-xs sm:text-sm font-medium bg-zinc-900 text-zinc-300 border border-zinc-800 hover:bg-zinc-800 hover:text-white transition-all"
          >
            <Github className="w-4 h-4" />
            View Source on GitHub
          </a>
        </div>

        <p className="text-xs font-mono text-zinc-500">
          Crafted with Swift, C++, whisper.cpp & Metal • MIT License • &copy; 2026 Utter Team.
        </p>
      </div>
    </footer>
  );
}
