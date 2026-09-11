import React from 'react';
import { Github, Heart, Shield, Terminal, ArrowUpRight } from 'lucide-react';

export default function Footer({ onOpenModal }) {
  return (
    <footer className="relative border-t border-white/10 bg-zinc-950/80 backdrop-blur-2xl text-zinc-400 py-16 px-4 sm:px-6 lg:px-12 w-full">
      <div className="max-w-[1360px] mx-auto grid grid-cols-1 md:grid-cols-12 gap-10 items-start">
        {/* Brand Column (5 cols) */}
        <div className="md:col-span-5 space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl overflow-hidden shadow-md">
              <img
                src="/assets/app-icon.png"
                alt="Utter Icon"
                className="w-full h-full object-cover"
                onError={(e) => {
                  e.target.style.display = 'none';
                }}
              />
            </div>
            <span className="font-bold text-lg text-white">Utter</span>
            <span className="text-xs font-mono px-2 py-0.5 rounded-full bg-white/5 text-zinc-400 border border-white/5">
              macOS
            </span>
          </div>
          <p className="text-xs sm:text-sm text-zinc-400 max-w-[400px] leading-relaxed">
            Native, zero-latency voice dictation engineered exclusively for macOS. Powered by whisper.cpp with Apple Silicon Metal acceleration and 100% on-device privacy.
          </p>
          <div className="flex items-center gap-2 text-xs text-zinc-500 font-mono">
            <span>Apache 2.0 License</span>
            <span>•</span>
            <span>100% Free & Open Source</span>
          </div>
        </div>

        {/* Navigation Links (3 cols) */}
        <div className="md:col-span-3 space-y-3">
          <div className="text-xs font-mono uppercase tracking-wider text-zinc-200">
            Product
          </div>
          <ul className="space-y-2 text-xs sm:text-sm">
            <li>
              <a href="#playground" className="hover:text-white transition-colors">
                Interactive Playground
              </a>
            </li>
            <li>
              <a href="#architecture" className="hover:text-white transition-colors">
                Zero-Latency Architecture
              </a>
            </li>
            <li>
              <a href="#companions" className="hover:text-white transition-colors">
                Desktop Pixel Pets
              </a>
            </li>
            <li>
              <a href="#transforms" className="hover:text-white transition-colors">
                Apple Intelligence Transforms
              </a>
            </li>
            <li>
              <a href="#privacy" className="hover:text-white transition-colors">
                Air-Gapped Privacy Vault
              </a>
            </li>
          </ul>
        </div>

        {/* Community & Docs (4 cols) */}
        <div className="md:col-span-4 space-y-3">
          <div className="text-xs font-mono uppercase tracking-wider text-zinc-200">
            Resources & Links
          </div>
          <ul className="space-y-2 text-xs sm:text-sm">
            <li>
              <a
                href="https://github.com/h3x-levi/Utter"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 hover:text-white transition-colors"
              >
                <span>GitHub Repository</span>
                <ArrowUpRight size={12} />
              </a>
            </li>
            <li>
              <a
                href="https://github.com/h3x-levi/Utter/releases"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 hover:text-white transition-colors"
              >
                <span>Release Notes & Checksums</span>
                <ArrowUpRight size={12} />
              </a>
            </li>
            <li>
              <button
                onClick={() => onOpenModal && onOpenModal('connect')}
                className="hover:text-white transition-colors text-left"
              >
                Join Community (Discord / X)
              </button>
            </li>
            <li>
              <button
                onClick={() => onOpenModal && onOpenModal('support')}
                className="hover:text-white transition-colors text-left"
              >
                Support & Diagnostics Guide
              </button>
            </li>
          </ul>
        </div>
      </div>

      {/* Bottom Bar */}
      <div className="max-w-[1360px] mx-auto mt-12 pt-8 border-t border-white/5 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-zinc-500 font-mono">
        <div>© 2026 Utter. Made for creators, engineers, and researchers.</div>
        <div className="flex items-center gap-1">
          <span>Crafted with native Swift & Metal</span>
        </div>
      </div>
    </footer>
  );
}
