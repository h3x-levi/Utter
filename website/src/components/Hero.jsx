import React, { useRef } from 'react';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';
import { Download, Github, Zap, Shield, Cpu, Sparkles } from 'lucide-react';

const easeOutStrong = [0.23, 1, 0.32, 1];

export default function Hero() {
  const sectionRef = useRef(null);
  const reduceMotion = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end start'],
  });

  const heroOpacity = useTransform(scrollYProgress, [0, 0.7], [1, 0]);
  const heroY = useTransform(scrollYProgress, [0, 0.7], [0, -60]);
  const heroScale = useTransform(scrollYProgress, [0, 0.7], [1, 0.95]);
  const screenshotY = useTransform(scrollYProgress, [0, 0.8], [0, -40]);

  return (
    <section
      ref={sectionRef}
      className="relative min-h-[100dvh] flex items-center px-6 sm:px-10 lg:px-16 pt-24 pb-16 w-full overflow-visible"
    >
      <motion.div
        style={reduceMotion ? {} : { opacity: heroOpacity, y: heroY, scale: heroScale }}
        className="w-full max-w-[1400px] mx-auto grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-16 items-center"
      >
        {/* Left Column - Copy */}
        <div className="flex flex-col items-start text-left z-10">
          {/* Platform Badge */}
          <motion.div
            initial={reduceMotion ? false : { opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.25, ease: easeOutStrong }}
            className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/90 backdrop-blur-md border border-black/[0.08] shadow-sm text-xs font-semibold text-zinc-700 mb-5"
          >
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            macOS Sonoma & Sequoia
            <span className="text-zinc-300">|</span>
            <span className="text-indigo-600 font-bold">Apple Silicon</span>
          </motion.div>

          {/* Headline */}
          <motion.h1
            initial={reduceMotion ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.05 }}
            className="text-4xl sm:text-5xl md:text-6xl lg:text-[64px] font-black tracking-tight text-zinc-950 leading-[1.05] mb-5"
          >
            Voice dictation that{' '}
            <span className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-500 bg-clip-text text-transparent">
              stays on your Mac.
            </span>
          </motion.h1>

          {/* Subtitle - max 20 words */}
          <motion.p
            initial={reduceMotion ? false : { opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.1 }}
            className="text-base sm:text-lg text-zinc-600 max-w-[480px] mb-7 leading-relaxed"
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
              Download for Mac
            </a>
            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2.5 bg-white text-zinc-900 hover:text-black border border-black/[0.08] px-6 py-3.5 rounded-full font-semibold text-sm shadow-sm hover:bg-zinc-50 transition-transform transition-colors duration-150 ease-out active:scale-[0.97] cursor-pointer"
            >
              <Github size={16} />
              View on GitHub
            </a>
          </motion.div>

          {/* Metric Chips */}
          <motion.div
            initial={reduceMotion ? false : { opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, ease: easeOutStrong, delay: 0.2 }}
            className="flex flex-wrap items-center gap-2.5 text-xs font-semibold text-zinc-600"
          >
            {[
              { icon: Zap, color: 'text-amber-500', label: '168ms Latency' },
              { icon: Shield, color: 'text-emerald-500', label: '0 Network Sockets' },
              { icon: Cpu, color: 'text-indigo-500', label: 'whisper.cpp Metal' },
              { icon: Sparkles, color: 'text-purple-500', label: 'Free & Open Source' },
            ].map(({ icon: Icon, color, label }) => (
              <div
                key={label}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/90 backdrop-blur-md border border-black/[0.06] shadow-sm"
              >
                <Icon size={13} className={color} />
                <span>{label}</span>
              </div>
            ))}
          </motion.div>
        </div>

        {/* Right Column - Real App Screenshot */}
        <motion.div
          style={reduceMotion ? {} : { y: screenshotY }}
          initial={reduceMotion ? false : { opacity: 0, scale: 0.96, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{
            duration: 0.5,
            ease: easeOutStrong,
            delay: 0.25,
          }}
          className="relative hidden lg:block"
        >
          {/* macOS Window Frame */}
          <div className="relative rounded-2xl overflow-hidden bg-white border border-black/[0.08] shadow-2xl">
            {/* Traffic Lights */}
            <div className="flex items-center gap-2 px-4 py-3 bg-zinc-50/80 border-b border-black/[0.05]">
              <div className="w-3 h-3 rounded-full bg-red-400" />
              <div className="w-3 h-3 rounded-full bg-amber-400" />
              <div className="w-3 h-3 rounded-full bg-emerald-400" />
              <span className="ml-3 text-xs text-zinc-400 font-mono">Utter</span>
            </div>
            {/* Screenshot */}
            <img
              src="/assets/screenshots/hero-main.png"
              alt="Utter main dashboard showing voice dictation controls, transcription history, and whisper model status on macOS"
              className="w-full h-auto block"
              loading="eager"
              fetchpriority="high"
            />
          </div>

          {/* Subtle floating glow behind the screenshot */}
          <div
            className="absolute -inset-8 -z-10 rounded-3xl opacity-40 blur-3xl"
            style={{
              background:
                'radial-gradient(circle at 30% 40%, rgba(99, 102, 241, 0.15), transparent 60%), radial-gradient(circle at 70% 60%, rgba(236, 72, 153, 0.12), transparent 60%)',
            }}
          />
        </motion.div>
      </motion.div>
    </section>
  );
}
