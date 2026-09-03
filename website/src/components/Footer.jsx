import React from 'react';
import { Download, Github, Heart } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="py-24 px-6 border-t border-white/10 bg-[#06080e] relative z-10 text-center">
      <div className="max-w-4xl mx-auto">
        <img
          src="/assets/app-icon.png"
          alt="Utter Icon"
          className="w-16 h-16 rounded-2xl mx-auto mb-6 shadow-2xl shadow-black/80 border border-white/10"
        />

        <h2 className="text-3xl sm:text-5xl font-extrabold text-white mb-4 tracking-tight">
          Ready to speak at the speed of thought?
        </h2>

        <p className="text-slate-400 text-base sm:text-lg max-w-xl mx-auto mb-10">
          Download Utter for macOS today. 100% local, private, and lightning fast.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-14">
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="w-full sm:w-auto px-8 py-4 rounded-xl font-bold bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white shadow-xl shadow-orange-500/25 transition-all hover:scale-105 active:scale-95"
          >
            Download Free DMG (v1.1.56)
          </a>
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="w-full sm:w-auto flex items-center justify-center gap-2 px-8 py-4 rounded-xl font-semibold bg-white/5 hover:bg-white/10 text-slate-200 border border-white/10 transition-all hover:border-white/20"
          >
            <Github className="w-5 h-5" />
            View Source on GitHub
          </a>
        </div>

        <p className="text-xs font-mono text-slate-500 flex items-center justify-center gap-1">
          Crafted with Swift, C++, whisper.cpp & Metal • MIT License • &copy; 2026 Utter Team.
        </p>
      </div>
    </footer>
  );
}
