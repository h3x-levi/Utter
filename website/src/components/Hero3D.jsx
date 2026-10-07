import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence, useMotionValue, useTransform, useSpring } from 'framer-motion';
import { Download, Terminal, Copy, Check, Mic, Zap, Shield, Cpu, Sparkles, Eye } from 'lucide-react';

const PILL_STATES = [
  {
    id: 'idle',
    label: 'Idle Notch',
    status: 'Ready • Hold Fn',
    desc: 'Floats unobtrusively in your menu bar or active screen margin. 0% CPU at rest.',
  },
  {
    id: 'listening',
    label: 'Live 7-Bar Waveform',
    status: 'Listening (16kHz PCM)...',
    desc: 'Real-time RMS audio spectrum analyzer capturing raw audio in unified RAM.',
  },
  {
    id: 'processing',
    label: 'Metal Compute',
    status: 'whisper.cpp Metal (168ms)',
    desc: 'Instant Apple Silicon GPU inference with zero cloud roundtrips.',
  },
  {
    id: 'injected',
    label: 'Direct Caret Injection',
    status: 'Injected at 180 WPM',
    desc: 'Synthetic Unicode events typed directly into your focused cursor.',
  },
];

export default function Hero3D() {
  const [activePillState, setActivePillState] = useState('listening');
  const [isSimulating, setIsSimulating] = useState(false);
  const [copiedBrew, setCopiedBrew] = useState(false);
  const displayRef = useRef(null);

  // High-Performance Apple Spring Perspective Tilt (Zero React State Re-renders)
  const mouseNormX = useMotionValue(0);
  const mouseNormY = useMotionValue(0);

  const rawRotateX = useTransform(mouseNormY, [-0.5, 0.5], [7, -7]);
  const rawRotateY = useTransform(mouseNormX, [-0.5, 0.5], [-7, 7]);

  const springRotateX = useSpring(rawRotateX, { stiffness: 180, damping: 26 });
  const springRotateY = useSpring(rawRotateY, { stiffness: 180, damping: 26 });

  // Mouse 3D perspective tilt calculation without component re-renders
  const handleMouseMove = (e) => {
    if (!displayRef.current) return;
    const rect = displayRef.current.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    mouseNormX.set(x);
    mouseNormY.set(y);
  };

  const handleMouseLeave = () => {
    mouseNormX.set(0);
    mouseNormY.set(0);
  };

  const handleCopyBrew = () => {
    navigator.clipboard.writeText('brew install --cask utter');
    setCopiedBrew(true);
    setTimeout(() => setCopiedBrew(false), 2400);
  };

  // Auto cycle pill demonstration if not clicked
  useEffect(() => {
    if (isSimulating) return;
    const timer = setInterval(() => {
      setActivePillState((prev) => {
        if (prev === 'idle') return 'listening';
        if (prev === 'listening') return 'processing';
        if (prev === 'processing') return 'injected';
        return 'idle';
      });
    }, 3200);
    return () => clearInterval(timer);
  }, [isSimulating]);

  return (
    <section className="relative min-h-[92dvh] flex flex-col items-center justify-center pt-28 pb-14 px-4 sm:px-6 lg:px-12 w-full overflow-hidden z-10">
      {/* Dynamic colorful radial glow */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[750px] h-[550px] bg-gradient-to-tr from-orange-500/25 via-amber-400/20 to-indigo-500/15 blur-[140px] rounded-full pointer-events-none -z-10" />

      {/* Main Hero Header */}
      <div className="w-full max-w-[1100px] mx-auto text-center flex flex-col items-center mb-10">
        {/* Platform Status Badge */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.35 }}
          className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full liquid-glass-pill text-xs font-semibold text-zinc-100 mb-5 border border-white/20 shadow-xl"
        >
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
          <span>macOS Sonoma & Sequoia</span>
          <span className="text-zinc-500">/</span>
          <span className="text-amber-400 font-mono">whisper.cpp Metal GPU</span>
          <span className="text-zinc-500">/</span>
          <span className="text-emerald-400 font-mono">100% Local</span>
        </motion.div>

        {/* Master Headline with Rich Colorful Gradient */}
        <motion.h1
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.05 }}
          className="text-4xl sm:text-6xl md:text-7xl font-black tracking-tight leading-[1.04] mb-5 text-white max-w-[960px]"
        >
          Voice dictation that{' '}
          <span className="bg-gradient-to-r from-orange-400 via-amber-300 to-yellow-200 bg-clip-text text-transparent filter drop-shadow-sm">
            stays on your Mac.
          </span>
        </motion.h1>

        {/* Value Proposition */}
        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.1 }}
          className="text-base sm:text-xl text-zinc-200 max-w-[700px] mb-7 leading-relaxed font-normal"
        >
          Hold a keycap, speak naturally, release. Utter transcribes locally at <strong className="text-amber-300 font-semibold">180 WPM with 168ms latency</strong>. Zero cloud, zero subscriptions, zero telemetry.
        </motion.p>

        {/* Action Row: Direct DMG + Workable Homebrew Command */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.15 }}
          className="flex flex-wrap items-center justify-center gap-3.5 mb-7"
        >
          {/* Primary DMG Release Download with Tactile Spring Press */}
          <motion.a
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.95 }}
            transition={{ type: 'spring', stiffness: 400, damping: 25 }}
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="inline-flex items-center gap-2.5 px-8 py-3.5 rounded-full text-sm font-bold text-zinc-950 bg-gradient-to-r from-orange-400 via-amber-300 to-yellow-200 hover:from-orange-300 hover:to-yellow-100 shadow-2xl shadow-orange-500/30 transition-all select-none"
          >
            <Download size={17} />
            <span>Download for Mac (.dmg)</span>
            <span className="text-[11px] font-mono opacity-80 pl-1 border-l border-black/20">v1.1.56</span>
          </motion.a>

          {/* Workable Homebrew Cask Install Pill with Tactile Spring Press */}
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.96 }}
            transition={{ type: 'spring', stiffness: 400, damping: 25 }}
            onClick={handleCopyBrew}
            className="inline-flex items-center gap-2.5 px-6 py-3.5 rounded-full text-xs sm:text-sm font-mono text-zinc-200 hover:text-white bg-zinc-900/80 hover:bg-zinc-800/90 border border-white/20 shadow-xl transition-all select-none"
            title="Click to copy Homebrew install command"
          >
            <Terminal size={15} className="text-orange-400" />
            <span className="text-orange-300 font-semibold">brew install --cask utter</span>
            {copiedBrew ? (
              <span className="flex items-center gap-1 text-emerald-400 font-sans text-xs font-semibold">
                <Check size={14} /> Copied!
              </span>
            ) : (
              <Copy size={13} className="text-zinc-400" />
            )}
          </motion.button>
        </motion.div>

        {/* Metric Chips */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45, delay: 0.2 }}
          className="flex flex-wrap items-center justify-center gap-2 sm:gap-3 text-xs font-medium text-zinc-300"
        >
          {[
            { icon: Zap, label: '168ms Latency', color: 'text-amber-400' },
            { icon: Shield, label: '0 Network Sockets', color: 'text-emerald-400' },
            { icon: Cpu, label: 'whisper.cpp Metal GPU', color: 'text-indigo-400' },
            { icon: Sparkles, label: '100% Free & Apache 2.0', color: 'text-orange-400' },
          ].map(({ icon: Icon, label, color }) => (
            <div
              key={label}
              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full liquid-glass-pill text-zinc-200 border border-white/10 shadow-sm"
            >
              <Icon size={13} className={color} />
              <span>{label}</span>
            </div>
          ))}
        </motion.div>
      </div>

      {/* 3D Perspective macOS Display Stage with Real Utter Screenshot & Floating Pill */}
      <motion.div
        ref={displayRef}
        onMouseMove={handleMouseMove}
        onMouseLeave={handleMouseLeave}
        initial={{ opacity: 0, scale: 0.94, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
        style={{
          transformPerspective: 1200,
          rotateX: springRotateX,
          rotateY: springRotateY,
        }}
        className="w-full max-w-[1160px] mx-auto relative rounded-3xl p-2.5 sm:p-3.5 liquid-glass border border-white/25 shadow-2xl overflow-hidden group gpu-accelerate"
      >
        {/* macOS Window Frame Header */}
        <div className="flex items-center justify-between px-4 py-2.5 bg-zinc-900/90 rounded-t-2xl border-b border-white/10 select-none">
          <div className="flex items-center gap-2">
            <span className="w-3 h-3 rounded-full bg-[#ff5f56] inline-block shadow-inner" />
            <span className="w-3 h-3 rounded-full bg-[#ffbd2e] inline-block shadow-inner" />
            <span className="w-3 h-3 rounded-full bg-[#27c93f] inline-block shadow-inner" />
            <span className="text-xs font-mono text-zinc-300 ml-3 hidden sm:inline">
              Utter.app - Native macOS Voice Workspace
            </span>
          </div>

          {/* Interactive Pill State Switcher with Apple Sliding Spring Pill */}
          <div className="flex items-center gap-1 bg-black/60 p-1 rounded-xl border border-white/10">
            {PILL_STATES.map((st) => {
              const isSelected = activePillState === st.id;
              return (
                <button
                  key={st.id}
                  onClick={() => {
                    setActivePillState(st.id);
                    setIsSimulating(true);
                  }}
                  className={`relative px-3 py-1 rounded-lg text-[11px] font-mono transition-colors duration-150 z-10 select-none ${
                    isSelected ? 'text-zinc-950 font-bold' : 'text-zinc-400 hover:text-white'
                  }`}
                >
                  {isSelected && (
                    <motion.div
                      layoutId="heroPillTab"
                      className="absolute inset-0 bg-gradient-to-r from-orange-400 to-amber-300 rounded-lg shadow-md -z-10"
                      transition={{ type: 'spring', stiffness: 450, damping: 32 }}
                    />
                  )}
                  <span>{st.label}</span>
                </button>
              );
            })}
          </div>

          <div className="text-xs font-mono text-emerald-400 hidden md:flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span>AIR-GAPPED 168ms</span>
          </div>
        </div>

        {/* Real Native macOS App Screenshot in Studio Display */}
        <div className="relative rounded-b-2xl overflow-hidden aspect-[16/10] bg-zinc-950 shadow-inner">
          <img
            src="/assets/screenshots/hero-main.png"
            alt="Utter Native macOS App Workspace"
            className="w-full h-full object-cover object-top filter brightness-[1.02] contrast-[1.03]"
            loading="eager"
          />

          {/* Subtle Ambient Vignette */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-black/20 pointer-events-none" />

          {/* Interactive Floating Liquid Glass Pill HUD */}
          <div className="absolute top-8 left-1/2 -translate-x-1/2 z-20 pointer-events-auto">
            <motion.div
              layout
              className="liquid-glass-pill px-6 py-3 rounded-full flex items-center gap-3.5 border-2 border-orange-500/70 bg-zinc-950/95 shadow-2xl shadow-orange-500/30"
            >
              {/* State Icon */}
              <div className="w-8 h-8 rounded-full bg-orange-500 text-zinc-950 flex items-center justify-center shadow-md">
                {activePillState === 'idle' && <Eye size={16} />}
                {activePillState === 'listening' && <Mic size={16} className="animate-bounce" />}
                {activePillState === 'processing' && <Cpu size={16} className="animate-spin" />}
                {activePillState === 'injected' && <Check size={16} />}
              </div>

              {/* 7-Bar Audio Waveform Spectrum */}
              <div className="flex items-end gap-1.5 h-6">
                {[30, 65, 95, 100, 80, 50, 85].map((h, idx) => (
                  <span
                    key={idx}
                    className={`w-1.5 rounded-full transition-all duration-150 ${
                      activePillState === 'listening'
                        ? 'bg-orange-400 animate-pulse'
                        : activePillState === 'processing'
                        ? 'bg-amber-400'
                        : 'bg-zinc-600'
                    }`}
                    style={{
                      height: activePillState === 'listening' ? `${h}%` : '25%',
                      animationDelay: `${idx * 0.08}s`,
                    }}
                  />
                ))}
              </div>

              {/* State Text */}
              <div className="flex flex-col text-left">
                <span className="text-xs font-bold text-white font-mono flex items-center gap-2">
                  <span>{PILL_STATES.find((s) => s.id === activePillState)?.status}</span>
                  <span className="w-1.5 h-1.5 rounded-full bg-orange-400 animate-ping" />
                </span>
                <span className="text-[11px] text-zinc-400">
                  {PILL_STATES.find((s) => s.id === activePillState)?.desc}
                </span>
              </div>
            </motion.div>
          </div>

          {/* Bottom Live Feedback Bar inside Display */}
          <div className="absolute bottom-3 left-3 right-3 z-20 flex flex-wrap items-center justify-between p-2.5 rounded-xl bg-zinc-950/85 backdrop-blur-md border border-white/10 text-xs font-mono text-zinc-300">
            <div className="flex items-center gap-2">
              <span className="text-orange-400 font-bold">WHISPER STREAM:</span>
              <span className="text-white">"func transcribeAudio(pcmBuffer: CMSampleBuffer) async throws"</span>
            </div>
            <div className="text-emerald-400 font-semibold">0 Sockets • Unified RAM</div>
          </div>
        </div>
      </motion.div>
    </section>
  );
}
