import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Download, Github, Menu, X, Volume2, VolumeX, Sparkles } from 'lucide-react';

const NAV_LINKS = [
  { id: 'showcase', label: 'Showcase' },
  { id: 'playground', label: 'Playground' },
  { id: 'architecture', label: 'Architecture' },
  { id: 'companions', label: 'Companions' },
  { id: 'transforms', label: 'AI Transforms' },
  { id: 'meetings', label: 'Meetings' },
  { id: 'privacy', label: 'Privacy Vault' },
  { id: 'benchmarks', label: 'Benchmarks' },
];

export default function Navbar({ onOpenModal, soundEnabled, onToggleSound }) {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [activeSection, setActiveSection] = useState('showcase');
  const [hoveredLink, setHoveredLink] = useState(null);

  // Scroll detection for navbar background blur opacity
  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Apple-grade Active Section Spy with IntersectionObserver
  useEffect(() => {
    const observerCallback = (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && entry.intersectionRatio >= 0.25) {
          setActiveSection(entry.target.id);
        }
      });
    };

    const observer = new IntersectionObserver(observerCallback, {
      root: null,
      rootMargin: '-80px 0px -40% 0px',
      threshold: [0.25, 0.5, 0.75],
    });

    NAV_LINKS.forEach(({ id }) => {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    });

    return () => observer.disconnect();
  }, []);

  // Smooth Apple spring scroll with exact header offset
  const handleNavClick = (e, id) => {
    e.preventDefault();
    setActiveSection(id);
    setMobileMenuOpen(false);
    const element = document.getElementById(id);
    if (element) {
      const navOffset = 84;
      const elementPosition = element.getBoundingClientRect().top;
      const offsetPosition = elementPosition + window.pageYOffset - navOffset;

      window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth',
      });
      window.history.pushState(null, '', `#${id}`);
    }
  };

  return (
    <header className="fixed top-0 left-0 right-0 z-50 flex justify-center px-4 sm:px-6 py-3.5 transition-all duration-300 pointer-events-none">
      <div
        className={`pointer-events-auto flex items-center justify-between gap-3 sm:gap-4 px-4 sm:px-5 py-2 rounded-full transition-all duration-300 w-full max-w-[1260px] ${
          scrolled
            ? 'liquid-glass-pill shadow-2xl backdrop-blur-2xl bg-zinc-950/85 border-white/15'
            : 'bg-zinc-950/50 backdrop-blur-xl border border-white/10'
        }`}
      >
        {/* Brand & Version Badge */}
        <a
          href="#"
          onClick={(e) => {
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }}
          className="flex items-center gap-2.5 group cursor-pointer select-none shrink-0"
        >
          <motion.div
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.94 }}
            transition={{ type: 'spring', stiffness: 400, damping: 25 }}
            className="relative w-8 h-8 rounded-xl overflow-hidden shadow-md"
          >
            <img
              src="/assets/app-icon.png"
              alt="Utter Icon"
              className="w-full h-full object-cover"
              onError={(e) => {
                e.target.style.display = 'none';
              }}
            />
            <div className="absolute inset-0 bg-gradient-to-tr from-orange-500/20 to-transparent pointer-events-none" />
          </motion.div>
          <div className="flex items-center gap-2">
            <span className="font-bold text-base tracking-tight text-white group-hover:text-orange-400 transition-colors">
              Utter
            </span>
            <span className="hidden sm:inline-flex text-[10px] uppercase font-mono px-2 py-0.5 rounded-full bg-white/5 text-zinc-400 border border-white/10">
              macOS • v1.1.56
            </span>
          </div>
        </a>

        {/* Desktop Nav Links with Apple Sliding Spring Pill */}
        <nav
          className="hidden lg:flex items-center gap-1 text-xs font-medium text-zinc-400 p-1 rounded-full bg-black/20 border border-white/5"
          onMouseLeave={() => setHoveredLink(null)}
        >
          {NAV_LINKS.map((link) => {
            const isActive = activeSection === link.id;
            const isHovered = hoveredLink === link.id;
            return (
              <a
                key={link.id}
                href={`#${link.id}`}
                onClick={(e) => handleNavClick(e, link.id)}
                onMouseEnter={() => setHoveredLink(link.id)}
                className={`relative px-3 py-1.5 rounded-full transition-colors duration-150 z-10 select-none ${
                  isActive ? 'text-white font-semibold' : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                {/* Active Apple Segmented Highlight Pill */}
                {isActive && (
                  <motion.div
                    layoutId="navbarActivePill"
                    className="absolute inset-0 rounded-full bg-gradient-to-b from-white/15 to-white/5 border border-white/15 shadow-sm -z-10"
                    transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                  />
                )}
                {/* Soft Hover Lift */}
                {!isActive && isHovered && (
                  <motion.div
                    layoutId="navbarHoverPill"
                    className="absolute inset-0 rounded-full bg-white/5 -z-10"
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
                <span>{link.label}</span>
              </a>
            );
          })}
        </nav>

        {/* Right Action Cluster */}
        <div className="flex items-center gap-2 shrink-0">
          {/* Sound Wave FX Toggle with Spring Tap */}
          <motion.button
            whileTap={{ scale: 0.92 }}
            onClick={onToggleSound}
            className="hidden sm:flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white border border-white/10 transition-colors"
            title={soundEnabled ? 'Mute audio cues' : 'Enable audio cues'}
            aria-label="Toggle sound cues"
          >
            {soundEnabled ? <Volume2 size={14} className="text-orange-400" /> : <VolumeX size={14} />}
          </motion.button>

          {/* GitHub Stars Link with Spring Feedback */}
          <motion.a
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.96 }}
            transition={{ type: 'spring', stiffness: 400, damping: 25 }}
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium text-zinc-300 hover:text-white bg-white/5 hover:bg-white/10 border border-white/10 transition-colors"
          >
            <Github size={13} />
            <span>GitHub</span>
          </motion.a>

          {/* Direct Download CTA with Tactile Spring Press */}
          <motion.a
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.95 }}
            transition={{ type: 'spring', stiffness: 400, damping: 25 }}
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-xs font-semibold text-zinc-950 bg-gradient-to-r from-orange-400 to-amber-300 hover:from-orange-300 hover:to-amber-200 shadow-lg shadow-orange-500/20 transition-all"
          >
            <Download size={13} />
            <span className="hidden xs:inline">Download</span>
            <span className="font-mono text-[10px] opacity-80">.dmg</span>
          </motion.a>

          {/* Mobile Menu Toggle */}
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="lg:hidden p-1.5 rounded-lg text-zinc-400 hover:text-white transition-colors"
            aria-label="Toggle mobile menu"
          >
            {mobileMenuOpen ? <X size={20} /> : <Menu size={20} />}
          </motion.button>
        </div>
      </div>

      {/* Mobile Dropdown Menu with Apple Spring Sheet Physics */}
      <AnimatePresence>
        {mobileMenuOpen && (
          <motion.div
            initial={{ opacity: 0, y: -12, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -12, scale: 0.97 }}
            transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
            className="pointer-events-auto absolute top-16 left-4 right-4 liquid-glass rounded-2xl p-5 border border-white/15 shadow-2xl flex flex-col gap-2.5 lg:hidden z-50 bg-zinc-950/95 backdrop-blur-2xl"
          >
            {NAV_LINKS.map((link) => (
              <a
                key={link.id}
                href={`#${link.id}`}
                onClick={(e) => handleNavClick(e, link.id)}
                className={`text-sm font-medium py-1.5 px-3 rounded-xl transition-all ${
                  activeSection === link.id
                    ? 'bg-orange-500/15 text-orange-400 font-semibold'
                    : 'text-zinc-300 hover:text-white hover:bg-white/5'
                }`}
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
                className="text-xs text-orange-400 font-medium hover:underline"
              >
                Join Community
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}

