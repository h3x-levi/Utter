import React from 'react';
import { Github, Heart } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="py-12 px-4 sm:px-8 bg-white/85 backdrop-blur-md border-t border-black/[0.06] text-xs text-zinc-500 relative z-10 w-full">
      <div className="w-full max-w-[94vw] 2xl:max-w-[1700px] mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <img src="/assets/app-icon.png" alt="Utter" className="w-5 h-5 rounded-md" />
          <span className="font-bold text-zinc-800">Utter for macOS</span>
          <span>© {new Date().getFullYear()}</span>
          <span>•</span>
          <span>MIT License</span>
        </div>

        <div className="flex items-center gap-6">
          <a href="#demo" className="hover:text-zinc-900 transition-colors">Demo</a>
          <a href="#models" className="hover:text-zinc-900 transition-colors">Speech Models</a>
          <a href="#features" className="hover:text-zinc-900 transition-colors">Features</a>
          <a href="#privacy" className="hover:text-zinc-900 transition-colors">Privacy</a>
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 hover:text-zinc-900 transition-colors"
          >
            <Github size={13} />
            GitHub
          </a>
        </div>
      </div>
    </footer>
  );
}
