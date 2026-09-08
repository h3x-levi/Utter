import React from 'react';
import { Github, Heart } from 'lucide-react';

export default function Footer({ onOpenModal }) {
  return (
    <footer className="pt-16 pb-10 px-6 sm:px-10 lg:px-16 bg-white/95 backdrop-blur-md border-t border-black/[0.08] text-xs text-zinc-500 relative z-10 w-full">
      <div className="w-full max-w-[1400px] mx-auto">
        {/* 3-Column Directory + Brand */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          {/* Brand Col */}
          <div className="col-span-2 md:col-span-1 space-y-3">
            <div className="flex items-center gap-2.5">
              <img src="/assets/app-icon.png" alt="Utter" className="w-7 h-7 rounded-lg shadow-sm" />
              <span className="font-bold text-base text-zinc-900 tracking-tight">Utter</span>
            </div>
            <p className="text-xs text-zinc-500 leading-relaxed max-w-xs">
              Native on-device speech dictation for macOS. 180 WPM on Apple Silicon unified memory.
            </p>
            <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-800 text-[11px] font-mono font-bold border border-emerald-200">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              Air-Gapped: 0 Sockets
            </div>
          </div>

          {/* Product */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Product</h4>
            <ul className="space-y-2">
              <li><a href="#features" className="hover:text-zinc-900 transition-colors duration-150">Features</a></li>
              <li><a href="#privacy" className="hover:text-zinc-900 transition-colors duration-150">Privacy</a></li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter/releases/latest"
                  className="hover:text-zinc-900 transition-colors duration-150"
                >
                  Download
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-zinc-900 transition-colors duration-150 inline-flex items-center gap-1"
                >
                  <Github size={11} />
                  GitHub
                </a>
              </li>
            </ul>
          </div>

          {/* Support */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Support</h4>
            <ul className="space-y-2">
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors duration-150 cursor-pointer"
                >
                  FAQ
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors duration-150 cursor-pointer"
                >
                  Bug Report
                </button>
              </li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter/issues"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-zinc-900 transition-colors duration-150"
                >
                  Issues
                </a>
              </li>
            </ul>
          </div>

          {/* Connect */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Connect</h4>
            <ul className="space-y-2">
              <li>
                <button
                  onClick={() => onOpenModal('connect')}
                  className="hover:text-zinc-900 transition-colors duration-150 cursor-pointer"
                >
                  Contact Us
                </button>
              </li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-zinc-900 transition-colors duration-150"
                >
                  Community
                </a>
              </li>
              <li>
                <a
                  href="mailto:support@utter.run"
                  className="hover:text-zinc-900 transition-colors duration-150"
                >
                  support@utter.run
                </a>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between pt-6 border-t border-black/[0.06] gap-3">
          <p className="text-zinc-400 text-[11px]">
            &copy; {new Date().getFullYear()} Utter. Free and open source. Built with{' '}
            <Heart size={10} className="inline text-red-400" /> on macOS.
          </p>
          <p className="text-zinc-400 text-[11px] font-mono">
            whisper.cpp + Apple Silicon Metal GPU
          </p>
        </div>
      </div>
    </footer>
  );
}
