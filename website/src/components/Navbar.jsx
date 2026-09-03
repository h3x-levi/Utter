import React, { useState, useEffect } from 'react';
import { Download, Github, Menu, X } from 'lucide-react';

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
          ? 'bg-[#09090b]/80 backdrop-blur-2xl border-b border-white/10 py-3.5 shadow-2xl'
          : 'bg-transparent py-5'
      }`}
    >
      <div className="max-w-7xl mx-auto px-6 flex items-center justify-between">
        {/* Brand */}
        <a href="#" className="flex items-center gap-3 group">
          <img
            src="/assets/app-icon.png"
            alt="Utter Logo"
            className="w-9 h-9 rounded-xl border border-white/10 shadow-lg group-hover:scale-105 transition-transform duration-200"
          />
          <div className="flex items-center gap-2">
            <span className="text-base font-semibold tracking-tight text-white">Utter</span>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-zinc-800 text-zinc-300 border border-zinc-700">
              v1.1.56
            </span>
          </div>
        </a>

        {/* Desktop Nav */}
        <nav className="hidden xl:flex items-center gap-7 text-xs font-medium text-zinc-400">
          <a href="#features" className="hover:text-white transition-colors">Features</a>
          <a href="#workflow" className="hover:text-white transition-colors">Architecture</a>
          <a href="#pill-states" className="hover:text-white transition-colors">HUD States</a>
          <a href="#meetings" className="hover:text-white transition-colors">Meetings</a>
          <a href="#transforms" className="hover:text-white transition-colors">AI Engine</a>
          <a href="#companions" className="hover:text-white transition-colors">Desktop Pets</a>
          <a href="#models" className="hover:text-white transition-colors">Models</a>
          <a href="#hotkeys" className="hover:text-white transition-colors">Hotkeys</a>
          <a href="#benchmarks" className="hover:text-white transition-colors">Benchmarks</a>
          <a href="#comparison" className="hover:text-white transition-colors">Matrix</a>
          <a href="#faq" className="hover:text-white transition-colors">FAQ</a>
        </nav>

        {/* Action Buttons */}
        <div className="hidden sm:flex items-center gap-3">
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-medium bg-zinc-900 text-zinc-300 border border-zinc-800 hover:bg-zinc-800 hover:text-white transition-all"
          >
            <Github className="w-3.5 h-3.5" />
            GitHub
          </a>
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-2 px-4 py-1.5 rounded-lg text-xs font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all hover:scale-102 active:scale-98"
          >
            <Download className="w-3.5 h-3.5" />
            Download DMG
          </a>
        </div>

        {/* Mobile Hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="xl:hidden text-zinc-400 hover:text-white p-2"
        >
          {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
        </button>
      </div>

      {/* Mobile Menu */}
      {mobileOpen && (
        <div className="xl:hidden bg-[#0e0e11] border-b border-zinc-800 px-6 py-6 space-y-3 font-mono text-xs">
          <a href="#features" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Features</a>
          <a href="#workflow" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Architecture</a>
          <a href="#pill-states" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">HUD States</a>
          <a href="#meetings" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Meetings</a>
          <a href="#transforms" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">AI Engine</a>
          <a href="#companions" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Desktop Pets</a>
          <a href="#models" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Models</a>
          <a href="#hotkeys" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Hotkeys</a>
          <a href="#benchmarks" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Benchmarks</a>
          <a href="#comparison" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">Matrix</a>
          <a href="#faq" onClick={() => setMobileOpen(false)} className="block text-zinc-300 hover:text-white">FAQ</a>
          <div className="pt-3">
            <a
              href="https://github.com/h3x-levi/Utter/releases/latest"
              className="w-full text-center py-2.5 rounded-lg text-xs font-semibold bg-white text-black block"
            >
              Download Free DMG
            </a>
          </div>
        </div>
      )}
    </header>
  );
}
