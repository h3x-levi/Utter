import React, { useState, useEffect } from 'react';
import { Download, Github, Menu, X, Sparkles } from 'lucide-react';

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'bg-[#0c0e14]/85 backdrop-blur-2xl border-b border-white/10 py-3.5 shadow-2xl shadow-black/60'
          : 'bg-transparent py-5'
      }`}
    >
      <div className="max-w-7xl mx-auto px-6 flex items-center justify-between">
        {/* Brand */}
        <a href="#" className="flex items-center gap-3.5 group">
          <img
            src="/assets/app-icon.png"
            alt="Utter Logo"
            className="w-10 h-10 rounded-xl shadow-lg shadow-black/60 border border-white/10 group-hover:scale-105 transition-transform duration-200"
          />
          <div className="flex flex-col">
            <div className="flex items-center gap-2">
              <span className="text-xl font-bold tracking-tight text-white">Utter</span>
              <span className="text-[10px] uppercase font-mono px-2 py-0.5 rounded-full bg-orange-500/20 text-orange-400 border border-orange-500/30">
                v1.1.56
              </span>
            </div>
            <span className="text-[11px] text-slate-400 font-medium">On-Device Dictation for macOS</span>
          </div>
        </a>

        {/* Desktop Nav Links */}
        <nav className="hidden xl:flex items-center gap-6 text-xs font-semibold text-slate-300">
          <a href="#features" className="hover:text-orange-400 transition-colors">Features</a>
          <a href="#workflow" className="hover:text-orange-400 transition-colors">Pipeline</a>
          <a href="#pill-states" className="hover:text-orange-400 transition-colors">Pill HUD</a>
          <a href="#meetings" className="hover:text-orange-400 transition-colors">Meetings</a>
          <a href="#transforms" className="hover:text-orange-400 transition-colors">AI Transforms</a>
          <a href="#companions" className="hover:text-orange-400 transition-colors">Pixel Pets</a>
          <a href="#models" className="hover:text-orange-400 transition-colors">Speech Models</a>
          <a href="#hotkeys" className="hover:text-orange-400 transition-colors">Hotkeys</a>
          <a href="#benchmarks" className="hover:text-orange-400 transition-colors">Benchmarks</a>
          <a href="#comparison" className="hover:text-orange-400 transition-colors">Comparison</a>
          <a href="#faq" className="hover:text-orange-400 transition-colors">FAQ</a>
        </nav>

        {/* Action Buttons */}
        <div className="hidden sm:flex items-center gap-3">
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-semibold bg-white/5 hover:bg-white/10 text-slate-200 border border-white/10 transition-all hover:scale-102"
          >
            <Github className="w-4 h-4" />
            GitHub
          </a>
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-2 px-5 py-2 rounded-xl text-xs font-bold bg-gradient-to-r from-orange-500 to-amber-500 hover:from-orange-600 hover:to-amber-600 text-white shadow-lg shadow-orange-500/25 transition-all hover:scale-105 active:scale-95 border border-orange-400/30"
          >
            <Download className="w-4 h-4" />
            Download DMG
          </a>
        </div>

        {/* Mobile Hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="xl:hidden text-slate-300 hover:text-white p-2"
        >
          {mobileOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* Mobile Drawer */}
      {mobileOpen && (
        <div className="xl:hidden bg-[#0e111a] border-b border-white/10 px-6 py-6 space-y-3.5 max-h-[80vh] overflow-y-auto font-mono text-sm">
          <a href="#features" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Features</a>
          <a href="#workflow" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Pipeline (How it works)</a>
          <a href="#pill-states" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Liquid Glass Pill HUD</a>
          <a href="#meetings" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Meeting Studio</a>
          <a href="#transforms" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Local AI Transforms</a>
          <a href="#companions" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Pixel Pet Companions</a>
          <a href="#models" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Speech Models Matrix</a>
          <a href="#hotkeys" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Hotkey Configuration</a>
          <a href="#benchmarks" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Hardware Benchmarks</a>
          <a href="#comparison" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Feature Matrix</a>
          <a href="#install" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">Terminal Install</a>
          <a href="#faq" onClick={() => setMobileOpen(false)} className="block text-slate-300 hover:text-orange-400">FAQ</a>
          <div className="pt-4">
            <a
              href="https://github.com/h3x-levi/Utter/releases/latest"
              className="w-full text-center py-3 rounded-xl text-sm font-bold bg-orange-500 text-white block"
            >
              Download Free DMG
            </a>
          </div>
        </div>
      )}
    </header>
  );
}
