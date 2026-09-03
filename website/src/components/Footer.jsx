import React from 'react';

const Footer = () => {
  return (
    <footer className="py-10 px-4 text-center">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center justify-center gap-6 text-sm text-black/35 mb-4">
          <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-black/60 transition-colors">
            GitHub
          </a>
          <a href="https://github.com/h3x-levi/Utter/releases" target="_blank" rel="noopener noreferrer" className="hover:text-black/60 transition-colors">
            Releases
          </a>
          <a href="https://github.com/h3x-levi/Utter/issues" target="_blank" rel="noopener noreferrer" className="hover:text-black/60 transition-colors">
            Issues
          </a>
          <a href="#privacy" className="hover:text-black/60 transition-colors">
            Privacy
          </a>
        </div>
        <p className="font-mono-sm text-xs text-black/25">
          Crafted with Swift, C++, whisper.cpp & Metal · © 2026 Utter
        </p>
      </div>
    </footer>
  );
};

export default Footer;
