import React from 'react';
import { motion } from 'framer-motion';
import { Download } from 'lucide-react';

const Navbar = () => {
  return (
    <div className="fixed top-0 left-0 right-0 z-50 flex justify-center pt-5 px-4 pointer-events-none">
      <motion.nav
        initial={{ y: -40, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
        className="nav-pill flex items-center justify-between px-3 py-2 rounded-full shadow-2xl pointer-events-auto"
      >
        {/* Brand */}
        <a href="#" className="flex items-center gap-2.5 px-3">
          <img src="/assets/app-icon.png" alt="Utter" className="w-6 h-6 rounded-lg" />
          <span className="font-semibold text-sm tracking-tight text-white">Utter</span>
        </a>

        {/* Links */}
        <div className="hidden md:flex items-center gap-5 px-4 text-[13px] font-medium text-white/60">
          <a href="#features" className="hover:text-white transition-colors">Features</a>
          <a href="#models" className="hover:text-white transition-colors">Models</a>
          <a href="#privacy" className="hover:text-white transition-colors">Privacy</a>
        </div>

        {/* CTA */}
        <a
          href="https://github.com/h3x-levi/Utter/releases/latest"
          className="flex items-center gap-1.5 bg-white text-black hover:bg-white/90 transition-colors text-[13px] font-semibold px-4 py-2 rounded-full"
        >
          <Download size={14} />
          Download
        </a>
      </motion.nav>
    </div>
  );
};

export default Navbar;
