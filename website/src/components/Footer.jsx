import React from 'react';
import { Github, Heart, MessageCircle, HelpCircle, Mail, ShieldCheck, ExternalLink, Terminal } from 'lucide-react';

export default function Footer({ onOpenModal }) {
  return (
    <footer className="pt-16 pb-12 px-4 sm:px-8 bg-white/95 backdrop-blur-md border-t border-black/[0.08] text-xs text-zinc-500 relative z-10 w-full">
      <div className="w-full max-w-[94vw] 2xl:max-w-[1600px] mx-auto">
        {/* Main 4-Column Directory */}
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-8 mb-12">
          {/* Brand Col */}
          <div className="col-span-2 md:col-span-4 lg:col-span-1 space-y-3">
            <div className="flex items-center gap-2.5">
              <img src="/assets/app-icon.png" alt="Utter" className="w-7 h-7 rounded-lg shadow-xs" />
              <span className="font-bold text-base text-zinc-900 tracking-tight">Utter</span>
            </div>
            <p className="text-xs text-zinc-500 leading-relaxed max-w-xs">
              Native on-device speech dictation for macOS. 180 WPM with sub-200ms latency on Apple Silicon unified memory.
            </p>
            <div className="inline-flex items-center gap-2 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-800 text-[11px] font-mono font-bold border border-emerald-200">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span>Air-Gapped: 0 Sockets</span>
            </div>
          </div>

          {/* Col 1: Product */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Product</h4>
            <ul className="space-y-2">
              <li>
                <a href="#showcase-3d" className="hover:text-zinc-900 transition-colors">3D Spiral Showcase</a>
              </li>
              <li>
                <a href="#demo" className="hover:text-zinc-900 transition-colors">Universal Dictation</a>
              </li>
              <li>
                <a href="#demo" className="hover:text-zinc-900 transition-colors">Meeting Diarization</a>
              </li>
              <li>
                <a href="#models" className="hover:text-zinc-900 transition-colors">Whisper Neural Models</a>
              </li>
              <li>
                <a href="#features" className="hover:text-zinc-900 transition-colors">Pixel Art Companions</a>
              </li>
            </ul>
          </div>

          {/* Col 2: Resources & Architecture */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Resources</h4>
            <ul className="space-y-2">
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Documentation
                </button>
              </li>
              <li>
                <a href="#privacy" className="hover:text-zinc-900 transition-colors">Air-Gapped Verification</a>
              </li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-zinc-900 transition-colors flex items-center gap-1"
                >
                  <span>Source Code</span>
                  <ExternalLink size={11} className="opacity-60" />
                </a>
              </li>
              <li>
                <a href="#models" className="hover:text-zinc-900 transition-colors">Model Benchmarks</a>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Terminal Commands
                </button>
              </li>
            </ul>
          </div>

          {/* Col 3: Support & Help */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Support</h4>
            <ul className="space-y-2">
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Troubleshooting Wizard
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Microphone Permissions
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Frequently Asked Questions
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('contact')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Report an Issue
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('support')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  System Diagnostics
                </button>
              </li>
            </ul>
          </div>

          {/* Col 4: Connect & Community */}
          <div className="space-y-3">
            <h4 className="font-bold text-zinc-900 text-xs uppercase tracking-wider">Connect</h4>
            <ul className="space-y-2">
              <li>
                <button
                  onClick={() => onOpenModal('connect')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Community Discord
                </button>
              </li>
              <li>
                <a
                  href="https://github.com/h3x-levi/Utter"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-zinc-900 transition-colors flex items-center gap-1"
                >
                  <Github size={12} />
                  <span>GitHub Discussions</span>
                </a>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('connect')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  X / Twitter Feed
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('contact')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Contact Engineers
                </button>
              </li>
              <li>
                <button
                  onClick={() => onOpenModal('connect')}
                  className="hover:text-zinc-900 transition-colors text-left cursor-pointer"
                >
                  Release Notifications
                </button>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Metadata & System Status */}
        <div className="pt-8 border-t border-black/5 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex flex-wrap items-center gap-3 text-zinc-500 text-[11px]">
            <span>© {new Date().getFullYear()} Utter Open Source Project</span>
            <span>•</span>
            <span>Released under MIT License</span>
            <span>•</span>
            <span>No Cloud · No Telemetry</span>
          </div>

          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-zinc-100 text-zinc-700 text-[11px] font-mono border border-zinc-200">
              <span className="w-2 h-2 rounded-full bg-emerald-500" />
              <span>macOS 14 & 15 Native</span>
            </div>
            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="p-1.5 rounded-full hover:bg-zinc-100 text-zinc-600 hover:text-zinc-900 transition-colors"
              aria-label="GitHub Repository"
            >
              <Github size={16} />
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}
