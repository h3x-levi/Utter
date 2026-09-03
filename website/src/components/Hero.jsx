import React, { useState, useEffect, useRef } from 'react';
import { Download, Mic, Sparkles, Terminal, CheckCircle2, Play, Volume2, ShieldCheck, Zap } from 'lucide-react';
import { motion } from 'framer-motion';

export default function Hero() {
  const [isRecording, setIsRecording] = useState(false);
  const [typedText, setTypedText] = useState('');
  const [activePreset, setActivePreset] = useState(0);
  const typingTimerRef = useRef(null);

  const presets = [
    {
      label: '⚡ Swift Code Refactor',
      text: 'func processAudioStream(sampleBuffer: CMSampleBuffer) async throws -> SpeechTurn {\n    let pcm16 = try audioConverter.convert(sampleBuffer)\n    return try await whisperEngine.transcribe(pcm16, language: .en)\n}',
      stats: '188 WPM • 0.16s latency • Metal GPU',
    },
    {
      label: '📅 Meeting Action Items',
      text: '- Levi to finalize Metal compute pipeline shaders before next Tuesday.\n- Team approved the zero-telemetry architecture for air-gapped deployments.\n- Release DMG installer v1.1.56 attached to GitHub Release.',
      stats: '194 WPM • 0.18s latency • Notes Studio',
    },
    {
      label: '🤖 Local AI Summary',
      text: 'Summary: Utter processes audio streams directly in unified Apple Silicon memory without temporary files, eliminating both cloud network latency and privacy leaks.',
      stats: 'Apple Intelligence • Zero Telemetry',
    },
  ];

  const startDictation = (textIndex = 0) => {
    if (isRecording) return;
    setIsRecording(true);
    setTypedText('');
    clearInterval(typingTimerRef.current);

    const targetText = presets[textIndex].text;

    setTimeout(() => {
      let idx = 0;
      typingTimerRef.current = setInterval(() => {
        if (idx < targetText.length) {
          setTypedText(targetText.substring(0, idx + 1));
          idx++;
        } else {
          clearInterval(typingTimerRef.current);
          setIsRecording(false);
        }
      }, 16);
    }, 600);
  };

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.code === 'Space' && !isRecording && e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
        e.preventDefault();
        startDictation(activePreset);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isRecording, activePreset]);

  return (
    <section className="relative z-10 pt-36 pb-28 px-6 overflow-hidden">
      <div className="max-w-6xl mx-auto text-center">

        {/* Top Feature Pill */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full bg-orange-500/10 border border-orange-500/25 text-xs font-mono font-semibold text-orange-400 mb-8 backdrop-blur-xl shadow-xl shadow-orange-500/5"
        >
          <span className="flex h-2 w-2 relative">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
            <span class="relative inline-flex rounded-full h-2 w-2 bg-orange-500"></span>
          </span>
          100% On-Device Whisper.cpp on Apple Metal • Zero Cloud Endpoints
        </motion.div>

        {/* Master Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="text-5xl sm:text-7xl lg:text-8xl font-extrabold tracking-tight text-white leading-[1.05] mb-8"
        >
          Type at <span className="text-transparent bg-clip-text bg-gradient-to-r from-orange-400 via-amber-300 to-orange-500">180 WPM</span> anywhere on macOS.
        </motion.h1>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.2 }}
          className="text-lg sm:text-2xl text-slate-300 max-w-3xl mx-auto leading-relaxed mb-12 font-normal"
        >
          Hold a key, speak naturally, let go—your words appear instantly in <strong className="text-white font-semibold">Xcode, Cursor, VS Code, Slack, or Obsidian</strong> with sub-200ms latency and 100% local privacy.
        </motion.p>

        {/* Main CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.3 }}
          className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-20"
        >
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="w-full sm:w-auto flex items-center justify-center gap-3 px-9 py-4 rounded-2xl text-base font-bold bg-gradient-to-r from-orange-500 via-amber-500 to-orange-600 hover:from-orange-600 hover:to-amber-600 text-white shadow-2xl shadow-orange-500/30 transition-all hover:scale-105 active:scale-95 border border-orange-400/30"
          >
            <Download className="w-5 h-5" />
            Download for macOS (Free DMG)
          </a>
          <button
            onClick={() => startDictation(activePreset)}
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 px-8 py-4 rounded-2xl text-base font-semibold bg-white/5 hover:bg-white/10 text-slate-200 border border-white/10 backdrop-blur-xl transition-all hover:border-white/20 hover:scale-102 active:scale-98"
          >
            <Play className="w-5 h-5 text-orange-400 fill-orange-400" />
            Try Live Dictation Demo
          </button>
        </motion.div>

        {/* Trust Badges */}
        <div className="flex flex-wrap items-center justify-center gap-8 text-xs font-semibold text-slate-400 mb-16">
          <span className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            100% Free & Open Source
          </span>
          <span className="flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            Zero Telemetry / Air-Gapped
          </span>
          <span className="flex items-center gap-2">
            <Zap className="w-4 h-4 text-emerald-400" />
            Sub-200ms Metal GPU Inference
          </span>
          <span className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
            Bundled Whisper Small.en (181M)
          </span>
        </div>

        {/* 3D Interactive Desktop Simulator Window */}
        <motion.div
          id="demo"
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="relative max-w-5xl mx-auto rounded-3xl p-3 sm:p-4 bg-gradient-to-b from-white/15 via-white/5 to-transparent border border-white/15 shadow-2xl shadow-black/90 backdrop-blur-2xl"
        >
          <div className="rounded-2xl overflow-hidden bg-[#10131c] border border-white/10 relative">

            {/* macOS Window Chrome */}
            <div className="h-10 bg-[#161922] px-4 flex items-center justify-between border-b border-white/5">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-[#ff5f56]"></span>
                <span className="w-3 h-3 rounded-full bg-[#ffbd2e]"></span>
                <span className="w-3 h-3 rounded-full bg-[#27c93f]"></span>
              </div>
              <span className="text-xs font-mono font-medium text-slate-400 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                Utter Live macOS HUD Simulator — Hold Spacebar or Click Mic
              </span>
              <div className="w-12"></div>
            </div>

            {/* Desktop Wallpaper Canvas with Real App UI Background */}
            <div
              className="relative min-h-[480px] sm:min-h-[580px] p-6 sm:p-10 flex flex-col items-center justify-between overflow-hidden bg-cover bg-center"
              style={{ backgroundImage: `url('/assets/screenshots/hero-main.png')` }}
            >
              <div className="absolute inset-0 bg-[#0c0e14]/80 backdrop-blur-[2px]"></div>

              {/* Floating Liquid Glass Pill HUD */}
              <div className="relative z-20 mt-4">
                <motion.div
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => startDictation(activePreset)}
                  className={`glass-pill rounded-full px-6 py-3.5 flex items-center gap-4 cursor-pointer select-none transition-all duration-300 border ${
                    isRecording
                      ? 'border-orange-500 bg-orange-950/50 shadow-2xl shadow-orange-500/30'
                      : 'border-white/20 hover:border-white/40'
                  }`}
                >
                  {/* Mic Glyph */}
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${
                    isRecording ? 'bg-orange-500 text-white' : 'bg-white/10 text-orange-400'
                  }`}>
                    <Mic className="w-4 h-4" />
                  </div>

                  {/* 7-Bar Dynamic Audio Waveform */}
                  <div className="flex items-center gap-1.5 h-6">
                    {[12, 18, 24, 28, 24, 18, 12].map((height, i) => (
                      <div
                        key={i}
                        className={`w-1.5 rounded-full transition-all duration-150 ${
                          isRecording
                            ? 'bg-orange-400 animate-wave-bar'
                            : 'bg-orange-400/40'
                        }`}
                        style={{
                          height: isRecording ? `${height}px` : '6px',
                          animationDelay: `${i * 0.12}s`,
                        }}
                      />
                    ))}
                  </div>

                  {/* Status Label */}
                  <span className="text-xs font-mono font-semibold text-slate-200">
                    {isRecording ? 'Listening on Metal GPU...' : 'Hold Space or Click to Dictate'}
                  </span>
                </motion.div>
              </div>

              {/* Live Target Code Editor Box */}
              <div className="relative z-20 w-full max-w-2xl glass-panel rounded-2xl p-6 text-left my-auto border border-white/10 shadow-2xl">
                <div className="flex items-center justify-between text-xs font-mono text-slate-400 mb-3 border-b border-white/5 pb-2">
                  <span className="flex items-center gap-2">
                    <Terminal className="w-4 h-4 text-orange-400" />
                    Target App: <strong className="text-white font-mono">Xcode / Cursor (main.swift)</strong>
                  </span>
                  <span className="text-emerald-400 font-semibold font-mono">
                    {presets[activePreset].stats}
                  </span>
                </div>
                <pre className="font-mono text-xs sm:text-sm text-slate-100 min-h-[90px] whitespace-pre-wrap leading-relaxed">
                  {typedText || (
                    <span className="text-slate-400">
                      // Hold the microphone pill above or press Spacebar to dictate text into any macOS app...
                    </span>
                  )}
                  {isRecording && <span className="inline-block w-2 h-4 bg-orange-400 ml-1 animate-pulse" />}
                </pre>
              </div>

              {/* Interactive Presets Switcher */}
              <div className="relative z-20 flex flex-wrap items-center justify-center gap-2.5">
                {presets.map((preset, idx) => (
                  <button
                    key={idx}
                    onClick={() => {
                      setActivePreset(idx);
                      startDictation(idx);
                    }}
                    className={`px-3.5 py-1.5 rounded-lg text-xs font-mono transition-all border ${
                      activePreset === idx
                        ? 'bg-orange-500/20 text-orange-400 border-orange-500/40 shadow-lg shadow-orange-500/10'
                        : 'bg-white/5 text-slate-300 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    {preset.label}
                  </button>
                ))}
              </div>

            </div>
          </div>
        </motion.div>

      </div>
    </section>
  );
}
