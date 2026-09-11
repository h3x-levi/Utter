import React, { useState, useEffect } from 'react';
import { Download, Github, Sparkles, Shield, Cpu, Menu, X, Volume2, VolumeX } from 'lucide-react';

export default function Navbar({ onOpenModal, soundEnabled, onToggleSound }) {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const navLinks = [
    { label: 'Showcase', href: '#showcase' },
    { label: 'Playground', href: '#playground' },
    { label: 'Architecture', href: '#architecture' },
    { label: 'Companions', href: '#companions' },
    { label: 'AI Transforms', href: '#transforms' },
    { label: 'Privacy Vault', href: '#privacy' },
    { label: 'Benchmarks', href: '#benchmarks' },
  ];

  return (
    <header className="fixed top-0 left-0 right-0 z-50 flex justify-center px-4 sm:px-6 py-4 transition-all duration-300 pointer-events-none">
      <div
        className={`pointer-events-auto flex items-center justify-between gap-4 px-4 sm:px-6 py-2.5 rounded-full transition-all duration-300 w-full max-w-[1240px] ${
          scrolled
            ? 'liquid-glass-pill shadow-2xl backdrop-blur-2xl bg-zinc-950/80 border-white/10'
            : 'bg-zinc-950/40 backdrop-blur-xl border border-white/5'
        }`}
      >
        {/* Brand & Version Badge */}
        <a href="#" className="flex items-center gap-3 group">
          <div className="relative w-8 h-8 rounded-xl overflow-hidden shadow-md group-hover:scale-105 transition-transform duration-200">
            <img
              src="/assets/app-icon.png"
              alt="Utter Icon"
              className="w-full h-full object-cover"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
            <div className="absolute inset-0 bg-gradient-to-tr from-orange-500/20 to-transparent pointer-events-none" />
          </div>
          <div className="flex items-center gap-2">
            <span className="font-bold text-base tracking-tight text-white group-hover:text-orange-400 transition-colors">
              Utter
            </span>
            <span className="hidden sm:inline-flex text-[10px] uppercase font-mono px-2 py-0.5 rounded-full bg-white/5 text-zinc-400 border border-white/10">
              macOS • v1.1.56
            </span>
          </div>
        </a>

        {/* Desktop Nav Links */}
        <nav className="hidden md:flex items-center gap-1.5 text-xs font-medium text-zinc-400">
          {navLinks.map((link) => (
            <a
              key={link.label}
              href={link.href}
              className="px-3.5 py-1.5 rounded-full hover:text-white hover:bg-white/5 transition-all duration-150"
            >
              {link.label}
            </a>
          ))}
        </nav>

        {/* Right Actions */}
        <div className="flex items-center gap-2">
          {/* Sound Wave FX Toggle */}
          <button
            onClick={onToggleSound}
            className="hidden sm:flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white border border-white/10 transition-colors"
            title={soundEnabled ? 'Mute audio cues' : 'Enable audio cues'}
            aria-label="Toggle sound cues"
          >
            {soundEnabled ? <Volume2 size={14} className="text-orange-400" /> : <VolumeX size={14} />}
          </button>

          {/* GitHub Stars Link */}
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-zinc-300 hover:text-white bg-white/5 hover:bg-white/10 border border-white/10 transition-colors"
          >
            <Github size={13} />
            <span>GitHub</span>
          </a>

          {/* Direct Download CTA */}
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-xs font-semibold text-zinc-950 bg-gradient-to-r from-orange-400 to-amber-300 hover:from-orange-300 hover:to-amber-200 shadow-lg shadow-orange-500/20 transition-all duration-200 active:scale-95"
          >
            <Download size={13} />
            <span className="hidden xs:inline">Download</span>
            <span className="font-mono text-[10px] opacity-80">.dmg</span>
          </a>

          {/* Mobile Menu Toggle */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-1.5 rounded-lg text-zinc-400 hover:text-white"
            aria-label="Toggle mobile menu"
          >
            {mobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </div>

      {/* Mobile Dropdown Menu */}
      {mobileMenuOpen && (
        <div className="pointer-events-auto absolute top-18 left-4 right-4 liquid-glass rounded-2xl p-5 border border-white/10 shadow-2xl flex flex-col gap-3 md:hidden z-50">
          {navLinks.map((link) => (
            <a
              key={link.label}
              href={link.href}
              onClick={() => setMobileMenuOpen(false)}
              className="text-sm font-medium text-zinc-300 hover:text-orange-400 py-1"
            >
              {link.label}
            </a>
          ))}
          <div className="pt-3 border-t border-white/10 flex items-center justify-between">
            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-xs text-zinc-400 hover:text-white"
            >
              <Github size={14} />
              <span>GitHub Repository</span>
            </a>
            <button
              onClick={() => {
                setMobileMenuOpen(false);
                if (onOpenModal) onOpenModal('connect');
              }}
              className="text-xs text-orange-400 font-medium"
            >
              Join Community
            </button>
          </div>
        </div>
      )}
    </header>
  );
}
