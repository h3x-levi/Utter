import React, { useState, useEffect } from 'react';

export default function ScrollProgress() {
  const [scrollProgress, setScrollProgress] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
      if (totalHeight > 0) {
        const progress = (window.scrollY / totalHeight) * 100;
        setScrollProgress(progress);
      }
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <div className="fixed top-0 left-0 right-0 h-1 z-50 bg-white/5 pointer-events-none">
      <div
        className="h-full bg-gradient-to-r from-orange-500 via-amber-400 to-orange-600 transition-all duration-75 shadow-lg shadow-orange-500/50"
        style={{ width: `${scrollProgress}%` }}
      />
    </div>
  );
}
