import React, { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Download } from 'lucide-react';
import SkiperCssLink from './SkiperCssLink';

export default function Navbar({ onSelectStage }) {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [opacity, setOpacity] = useState(0);
  const navRef = useRef(null);

  const handleMouseMove = (e) => {
    if (!navRef.current) return;
    const rect = navRef.current.getBoundingClientRect();
    setPosition({ x: e.clientX - rect.left, y: e.clientY - rect.top });
  };

  return (
    <div className="fixed top-0 left-0 right-0 z-50 flex justify-center pt-5 px-4 pointer-events-none">
      <motion.nav
        ref={navRef}
        onMouseMove={handleMouseMove}
        onMouseEnter={() => setOpacity(1)}
        onMouseLeave={() => setOpacity(0)}
        initial={{ y: -40, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        className="relative obsidian-glass flex items-center justify-between px-3 py-2 rounded-full shadow-2xl pointer-events-auto border border-white/15 overflow-hidden"
      >
        {/* Radial Spotlight Tracker (Vengeance UI Pattern) */}
        <div
          className="pointer-events-none absolute -inset-px transition-opacity duration-300"
          style={{
            opacity,
            background: `radial-gradient(180px circle at ${position.x}px ${position.y}px, rgba(95, 97, 237, 0.25), transparent 70%)`,
          }}
        />

        {/* Brand */}
        <a href="#" className="flex items-center gap-2.5 px-3 relative z-10">
          <img src="/assets/app-icon.png" alt="Utter macOS" className="w-6 h-6 rounded-lg shadow-sm" />
          <span className="font-bold text-sm tracking-tight text-white">Utter</span>
          <span className="font-mono-sm text-[10px] px-1.5 py-0.5 rounded bg-white/10 text-white/60">macOS</span>
        </a>

        {/* Navigation Links with Skiper UI CssLink */}
        <div className="hidden md:flex items-center gap-6 px-4 text-xs font-medium relative z-10">
          <SkiperCssLink href="#features" onClick={() => onSelectStage?.(1)}>Features</SkiperCssLink>
          <SkiperCssLink href="#models" onClick={() => onSelectStage?.(2)}>Whisper Models</SkiperCssLink>
          <SkiperCssLink href="#meetings" onClick={() => onSelectStage?.(3)}>Meeting Studio</SkiperCssLink>
          <SkiperCssLink href="#privacy" onClick={() => onSelectStage?.(5)}>Privacy Vault</SkiperCssLink>
        </div>

        {/* Direct Download CTA */}
        <a
          href="https://github.com/h3x-levi/Utter/releases/latest"
          className="relative z-10 flex items-center gap-1.5 bg-white text-black hover:bg-zinc-200 transition-colors text-xs font-bold px-4 py-2 rounded-full shadow-md active:scale-95"
        >
          <Download size={13} />
          Download
        </a>
      </motion.nav>
    </div>
  );
}
