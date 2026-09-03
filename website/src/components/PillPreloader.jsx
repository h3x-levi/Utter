import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic } from 'lucide-react';

export default function PillPreloader({ onComplete }) {
  const [progress, setProgress] = useState(0);
  const [isDone, setIsDone] = useState(false);

  useEffect(() => {
    const interval = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          clearInterval(interval);
          setIsDone(true);
          setTimeout(() => {
            onComplete?.();
          }, 600);
          return 100;
        }
        // Accelerate through loading
        const increment = prev < 50 ? 3 : prev < 85 ? 4 : 5;
        return Math.min(prev + increment, 100);
      });
    }, 35);

    return () => clearInterval(interval);
  }, [onComplete]);

  return (
    <AnimatePresence>
      {!isDone && (
        <motion.div
          initial={{ opacity: 1 }}
          exit={{ opacity: 0, scale: 1.15, filter: 'blur(20px)' }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-[#09090b] text-white"
        >
          {/* Animated Ambient Glow */}
          <div className="absolute w-96 h-96 rounded-full bg-indigo-500/15 blur-[100px] pointer-events-none" />

          {/* Centered Liquid Glass Pill */}
          <motion.div
            initial={{ scale: 0.85, opacity: 0, y: 20 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
            className="relative flex items-center justify-between gap-6 px-6 py-4 rounded-full obsidian-glass border border-white/20 shadow-2xl min-w-[320px] sm:min-w-[360px]"
          >
            {/* Mic Icon */}
            <div className="w-10 h-10 rounded-full bg-indigo-600 flex items-center justify-center text-white shadow-lg">
              <Mic size={18} className="animate-pulse" />
            </div>

            {/* Pulsing Audio Meter Bars */}
            <div className="flex items-center gap-1.5 h-6 flex-1 justify-center">
              {[40, 80, 100, 60, 90, 50, 75].map((h, i) => (
                <motion.div
                  key={i}
                  animate={{ height: [`${h * 0.25}%`, `${h}%`, `${h * 0.3}%`] }}
                  transition={{ duration: 0.4 + i * 0.08, repeat: Infinity, ease: 'easeInOut' }}
                  className="w-1 bg-white/90 rounded-full"
                />
              ))}
            </div>

            {/* Neural Weight Loading Percent */}
            <div className="font-mono-sm text-sm font-semibold tracking-wider text-white">
              {progress}%
            </div>
          </motion.div>

          {/* Subtext */}
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 0.6 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="mt-6 text-xs font-mono-sm tracking-widest text-zinc-400 uppercase"
          >
            Initializing whisper.cpp on Metal GPU...
          </motion.p>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
