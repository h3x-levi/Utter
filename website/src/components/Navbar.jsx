import React from 'react';
import { motion } from 'framer-motion';
import { Download, Github } from 'lucide-react';

export default function Navbar({ onOpenModal }) {
  return (
    <div className="fixed top-0 left-0 right-0 z-50 flex justify-center pt-4 px-4 pointer-events-none">
      <motion.nav
        initial={{ y: -20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.25, ease: [0.23, 1, 0.32, 1] }}
        className="white-glass flex items-center justify-between px-4 sm:px-6 py-2.5 rounded-full pointer-events-auto border border-black/[0.08] shadow-lg w-full max-w-[1400px]"
        style={{ maxHeight: 64 }}
      >
        {/* Brand */}
        <a href="#" className="flex items-center gap-2.5 pl-1">
          <img src="/assets/app-icon.png" alt="Utter" className="w-7 h-7 rounded-lg shadow-sm" />
          <span className="font-bold text-sm tracking-tight text-zinc-900">Utter</span>
        </a>

        {/* Nav Links */}
        <div className="hidden md:flex items-center gap-5 text-xs font-medium text-zinc-600">
          <a href="#features" className="hover:text-zinc-900 transition-colors duration-150">Features</a>
          <a href="#privacy" className="hover:text-zinc-900 transition-colors duration-150">Privacy</a>
          <button
            onClick={() => onOpenModal('support')}
            className="hover:text-zinc-900 transition-colors duration-150 cursor-pointer"
          >
            Support
          </button>
          <button
            onClick={() => onOpenModal('connect')}
            className="hover:text-zinc-900 transition-colors duration-150 cursor-pointer"
          >
            Connect
          </button>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2">
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="hidden sm:flex items-center gap-1.5 text-xs font-semibold px-3 py-1.5 rounded-full text-zinc-700 hover:text-black hover:bg-black/5 transition-colors duration-150"
          >
            <Github size={14} />
            GitHub
          </a>

          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-1.5 bg-zinc-900 text-white hover:bg-black transition-transform transition-colors duration-150 ease-out text-xs font-bold px-4 py-2 rounded-full shadow-sm active:scale-[0.97]"
          >
            <Download size={13} />
            Download
          </a>
        </div>
      </motion.nav>
    </div>
  );
}
