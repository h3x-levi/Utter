import React, { useState, useEffect } from 'react';
import { Download, Github, Menu, X } from 'lucide-react';

export default function NavbarPill() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header className="fixed top-5 left-1/2 -translate-x-1/2 z-50 w-[92%] max-w-5xl transition-all duration-300">
      <div className="bg-[#141418]/85 backdrop-blur-2xl border border-zinc-700/60 rounded-full px-5 py-2.5 shadow-[0_15px_35px_rgba(0,0,0,0.6)] flex items-center justify-between">
        
        {/* Brand */}
        <a href="#" className="flex items-center gap-2.5">
          <img
            src="/assets/app-icon.png"
            alt="Utter Logo"
            className="w-7 h-7 rounded-lg border border-white/10 shadow"
          />
          <span className="text-sm font-semibold tracking-tight text-white">Utter</span>
          <span className="hidden sm:inline-block text-[10px] font-mono px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-300 border border-zinc-700">
            v1.1.56
          </span>
        </a>

        {/* Desktop Navigation Links */}
        <nav className="hidden lg:flex items-center gap-6 text-xs font-medium text-zinc-400">
          <a href="#features" className="hover:text-white transition-colors">Features</a>
          <a href="#workflow" className="hover:text-white transition-colors">Architecture</a>
          <a href="#pill-states" className="hover:text-white transition-colors">HUD States</a>
          <a href="#meetings" className="hover:text-white transition-colors">Meetings</a>
          <a href="#transforms" className="hover:text-white transition-colors">AI Transforms</a>
          <a href="#companions" className="hover:text-white transition-colors">Pixel Pets</a>
          <a href="#models" className="hover:text-white transition-colors">Models</a>
          <a href="#hotkeys" className="hover:text-white transition-colors">Hotkeys</a>
          <a href="#benchmarks" className="hover:text-white transition-colors">Benchmarks</a>
          <a href="#faq" className="hover:text-white transition-colors">FAQ</a>
        </nav>

        {/* Action Buttons */}
        <div className="flex items-center gap-2">
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-zinc-900 text-zinc-300 border border-zinc-700 hover:text-white transition-all"
          >
            <Github className="w-3.5 h-3.5" />
            GitHub
          </a>
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all shadow active:scale-95"
          >
            <Download className="w-3.5 h-3.5" />
            Download
          </a>

          {/* Mobile Hamburger */}
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            className="lg:hidden text-zinc-400 hover:text-white p-1 ml-1"
          >
            {mobileOpen ? <X className="w-4 h-4" /> : <Menu className="w-4 h-4" />}
          </button>
        </div>

      </div>

      {/* Mobile Drawer */}
      {mobileOpen && (
        <div className="lg:hidden mt-2 bg-[#141418] border border-zinc-800 rounded-2xl p-5 space-y-3 font-mono text-xs shadow-2xl">
          <a href="#features" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Features</a>
          <a href="#workflow" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Architecture</a>
          <a href="#pill-states" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">HUD States</a>
          <a href="#meetings" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Meetings</a>
          <a href="#transforms" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">AI Transforms</a>
          <a href="#companions" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Pixel Pets</a>
          <a href="#models" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Models</a>
          <a href="#hotkeys" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Hotkeys</a>
          <a href="#benchmarks" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Benchmarks</a>
          <a href="#faq" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">FAQ</a>
        </div>
      )}
    </header>
  );
}
