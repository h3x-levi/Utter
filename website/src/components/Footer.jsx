import React from 'react';

const Footer = () => {
  return (
    <footer className="py-12 px-4 text-center border-t border-white/10 bg-[#0d0d0d]">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-center gap-8 text-sm text-white/50 mb-4">
          <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
            GitHub
          </a>
          <a href="https://github.com/h3x-levi/Utter/releases" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
            Releases
          </a>
          <a href="https://github.com/h3x-levi/Utter/issues" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
            Issues
          </a>
          <a href="https://github.com/h3x-levi/Utter/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
            MIT License
          </a>
        </div>
        <p className="font-mono-sm text-xs text-white/30">
          Crafted with Swift, C++, whisper.cpp & Metal GPU · © 2026 Utter · Air-Gapped Voice Engine
        </p>
      </div>
    </footer>
  );
};

export default Footer;
