import React, { useRef } from 'react';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';
import { Download, Github, Zap, Shield, Cpu, Sparkles, Mic } from 'lucide-react';

const easeOutStrong = [0.23, 1, 0.32, 1];

export default function Hero() {
  const sectionRef = useRef(null);
  const reduceMotion = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end start'],
  });

  const heroOpacity = useTransform(scrollYProgress, [0, 0.7], [1, 0]);
  const heroY = useTransform(scrollYProgress, [0, 0.7], [0, -50]);
  const heroScale = useTransform(scrollYProgress, [0, 0.7], [1, 0.96]);
  const screenshotY = useTransform(scrollYProgress, [0, 0.8], [0, -30]);

  return (
    <section
      ref={sectionRef}
      className="relative min-h-[100dvh] flex items-center px-6 sm:px-10 lg:px-16 pt-28 pb-16 w-full overflow-visible z-10"
    >
      <motion.div
        style={reduceMotion ? {} : { opacity: heroOpacity, y: heroY, scale: heroScale }}
        className="w-full max-w-[1400px] mx-auto grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center"
      >
        {/* Left Column - Copy & Value Proposition (5 cols) */}
        <div className="lg:col-span-6 flex flex-col items-start text-left z-10">
          {/* Platform Badge */}
          <motion.div
            initial={reduceMotion ? false : { opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25, ease: easeOutStrong }}
            className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full frosted-glass border border-white/80 shadow-xs text-xs font-semibold text-zinc-800 mb-6"
          >
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>macOS Sonoma & Sequoia</span>
            <span className="text-zinc-400">|</span>
            <span className="text-indigo-600 font-bold">Apple Silicon</span>
          </motion.div>

          {/* Headline */}
          <motion.h1
            initial={reduceMotion ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.05 }}
            className="text-4xl sm:text-5xl md:text-6xl lg:text-[62px] font-black tracking-tight text-zinc-950 leading-[1.06] mb-5"
          >
            Voice dictation that{' '}
            <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 bg-clip-text text-transparent">
              stays on your Mac.
            </span>
          </motion.h1>

          {/* Subtitle - exactly 19 words */}
          <motion.p
            initial={reduceMotion ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.1 }}
            className="text-base sm:text-lg text-zinc-600 max-w-[480px] mb-8 leading-relaxed"
          >
            Hold a key, speak naturally, release. Utter transcribes locally at 180 WPM with zero cloud, zero latency.
          </motion.p>

          {/* CTAs */}
          <motion.div
            initial={reduceMotion ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.15 }}
            className="flex flex-wrap items-center gap-3 mb-8"
          >
            <a
              href="https://github.com/h3x-levi/Utter/releases/latest"
              className="inline-flex items-center gap-2.5 bg-zinc-950 text-white hover:bg-black px-7 py-3.5 rounded-full font-bold text-sm shadow-lg hover:shadow-xl transition-transform transition-colors duration-150 ease-out active:scale-[0.97] cursor-pointer"
            >
              <Download size={16} />
              <span>Download for Mac</span>
            </a>
            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2.5 frosted-glass text-zinc-900 hover:text-black px-6 py-3.5 rounded-full font-semibold text-sm shadow-xs hover:bg-white/80 transition-transform transition-colors duration-150 ease-out active:scale-[0.97] cursor-pointer"
            >
              <Github size={16} />
              <span>View on GitHub</span>
            </a>
          </motion.div>

          {/* Metric Chips */}
          <motion.div
            initial={reduceMotion ? false : { opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.2 }}
            className="flex flex-wrap items-center gap-2.5 text-xs font-semibold text-zinc-700"
          >
            {[
              { icon: Zap, color: 'text-amber-500', label: '168ms Latency' },
              { icon: Shield, color: 'text-emerald-500', label: '0 Network Sockets' },
              { icon: Cpu, color: 'text-indigo-500', label: 'whisper.cpp Metal' },
              { icon: Sparkles, color: 'text-purple-500', label: 'Free & Open Source' },
            ].map(({ icon: Icon, color, label }) => (
              <div
                key={label}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full frosted-glass shadow-2xs border border-white/80"
              >
                <Icon size={13} className={color} />
                <span>{label}</span>
              </div>
            ))}
          </motion.div>
        </div>

        {/* Right Column - Real App Mockup with Interactive Floating Pill (7 cols) */}
        <motion.div
          style={reduceMotion ? {} : { y: screenshotY }}
          initial={reduceMotion ? false : { opacity: 0, scale: 0.96, y: 24 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.5, ease: easeOutStrong, delay: 0.2 }}
          className="lg:col-span-6 relative hidden lg:block"
        >
          {/* Frosted Frame */}
          <div className="relative rounded-3xl p-3 frosted-glass border border-white/90 shadow-2xl">
            {/* macOS Window Header */}
            <div className="relative rounded-2xl overflow-hidden bg-white/90 border border-black/[0.08] shadow-lg">
              <div className="flex items-center gap-2 px-4 py-3 bg-zinc-50/90 border-b border-black/[0.05]">
                <div className="w-3 h-3 rounded-full bg-red-400" />
                <div className="w-3 h-3 rounded-full bg-amber-400" />
                <div className="w-3 h-3 rounded-full bg-emerald-400" />
                <span className="ml-3 text-xs text-zinc-400 font-mono">Utter Dictation Workspace</span>
                <span className="ml-auto text-[11px] font-mono text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200/60 font-semibold">
                  Metal Unified Memory
                </span>
              </div>
              
              {/* App Screenshot */}
              <img
                src="/assets/screenshots/hero-main.png"
                alt="Utter main dashboard showing voice dictation controls, transcription history, and whisper model status on macOS"
                className="w-full h-auto block"
                loading="eager"
                fetchpriority="high"
              />
            </div>

            {/* Floating Live Utter Pill Widget */}
            <motion.div
              initial={reduceMotion ? false : { y: 20, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: 0.4, duration: 0.4, ease: easeOutStrong }}
              className="absolute -bottom-6 right-6 frosted-glass-card px-4 py-2.5 flex items-center gap-3 border border-white shadow-xl z-20"
            >
              {/* Pulsing Mic Indicator */}
              <div className="relative flex items-center justify-center">
                <span className="w-3 h-3 rounded-full bg-red-500 animate-ping absolute opacity-75" />
                <span className="w-2.5 h-2.5 rounded-full bg-red-500 relative" />
              </div>

              {/* Audio Wave Visualizer Bars */}
              <div className="flex items-center gap-0.5 h-4">
                <span className="w-0.5 h-3 bg-indigo-600 rounded-full animate-pulse" />
                <span className="w-0.5 h-4 bg-indigo-500 rounded-full animate-pulse delay-75" />
                <span className="w-0.5 h-2 bg-indigo-600 rounded-full animate-pulse delay-150" />
                <span className="w-0.5 h-3.5 bg-indigo-500 rounded-full animate-pulse delay-100" />
                <span className="w-0.5 h-2.5 bg-indigo-600 rounded-full animate-pulse delay-200" />
              </div>

              {/* Text */}
              <div className="flex items-center gap-1.5 text-xs font-mono font-medium text-zinc-800">
                <kbd className="px-1.5 py-0.5 rounded bg-zinc-100 border border-zinc-300 text-[10px] font-bold text-zinc-700 shadow-2xs">
                  Fn
                </kbd>
                <span>Listening at cursor...</span>
              </div>

              {/* Pixel Cat mascot badge */}
              <div className="pl-2 border-l border-black/10 text-sm select-none" title="Pixel Pet Companion">
                🐱
              </div>
            </motion.div>
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}
