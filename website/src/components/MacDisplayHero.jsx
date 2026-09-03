import React, { useState, useEffect, useRef } from 'react';
import { Download, Mic, Terminal, Volume2, Sparkles, Wifi, Battery, Play, FileText, Cpu, Heart, Check } from 'lucide-react';
import { motion } from 'framer-motion';
import { animate as animeAnimate, stagger } from 'animejs';

export default function MacDisplayHero() {
  const [isRecording, setIsRecording] = useState(false);
  const [currentTime, setCurrentTime] = useState('');
  const [typedText, setTypedText] = useState('');
  const [activeTab, setActiveTab] = useState('code');
  const [petHappy, setPetHappy] = useState(false);
  const typingTimerRef = useRef(null);
  const titleRef = useRef(null);

  // Clock
  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setCurrentTime(now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }));
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  // Anime.js Title Reveal
  useEffect(() => {
    if (titleRef.current) {
      const chars = titleRef.current.querySelectorAll('.hero-letter');
      if (chars.length > 0) {
        animeAnimate(chars, {
          translateY: [28, 0],
          opacity: [0, 1],
          delay: stagger(14, { start: 150 }),
          duration: 700,
        });
      }
    }
  }, []);

  const demos = {
    code: {
      title: 'Xcode / Cursor Dictation',
      tag: 'Swift Metal Stream',
      text: 'func transcribeAudio(pcmBuffer: CMSampleBuffer) async throws -> SpeechTurn {\n    let audioFrames = try audioConverter.convert(pcmBuffer)\n    return try await whisperEngine.transcribe(audioFrames, language: .en)\n}',
      stats: '188 WPM • 0.16s latency • Metal GPU',
    },
    meeting: {
      title: 'Meeting Transcript & Diarization',
      tag: 'CoreAudio Two-Way',
      text: '• You (10:02 AM): "Reviewing Whisper Small.en benchmarks on M3 Max chip."\n• Lead (10:03 AM): "Sub-200ms latency confirmed with zero audio sample drops."\n• Summary: Release DMG approved for immediate distribution.',
      stats: '4 Speakers • ScreenCaptureKit',
    },
    transform: {
      title: 'Local AI Text Cleanup',
      tag: 'Apple Intelligence',
      text: 'Summary: Utter converts spoken stream-of-consciousness into structured Swift documentation and meeting action items directly on-device without cloud network latency.',
      stats: 'On-Device Foundation Model',
    },
  };

  const startDictation = (tabKey = activeTab) => {
    if (isRecording) return;
    setIsRecording(true);
    setTypedText('');
    clearInterval(typingTimerRef.current);

    animeAnimate('.interactive-hud-pill', {
      scale: [1, 1.04, 1],
      duration: 300,
    });

    const targetText = demos[tabKey].text;

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
      }, 12);
    }, 450);
  };

  const headline = "Zero-latency voice dictation for macOS.".split(" ");

  return (
    <section className="relative z-10 pt-36 pb-24 px-4 sm:px-6 overflow-hidden">
      <div className="max-w-6xl mx-auto text-center">

        {/* Top Floating Badge */}
        <div className="inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs font-mono font-medium text-zinc-300 mb-8 backdrop-blur-xl shadow-lg">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
          whisper.cpp on Metal GPU • 100% On-Device • Zero Telemetry
        </div>

        {/* Editorial Headline */}
        <h1
          ref={titleRef}
          className="text-4xl sm:text-6xl lg:text-7xl font-bold tracking-tight text-white leading-[1.08] mb-6 max-w-4xl mx-auto"
        >
          {headline.map((word, wIdx) => (
            <span key={wIdx} className="inline-block mr-3 sm:mr-4 whitespace-nowrap">
              {word.split("").map((c, cIdx) => (
                <span key={cIdx} className="hero-letter inline-block opacity-0">
                  {c}
                </span>
              ))}
            </span>
          ))}
        </h1>

        <p className="text-base sm:text-xl text-zinc-400 max-w-2xl mx-auto leading-relaxed mb-10 font-normal">
          Hold a key, speak your mind, let go—your words appear instantly in Cursor, Xcode, Slack, or Obsidian at 180 WPM with air-gapped privacy.
        </p>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-3.5 mb-16">
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 px-7 py-3.5 rounded-xl text-sm font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all shadow-xl active:scale-98"
          >
            <Download className="w-4 h-4" />
            Download for Mac (Free DMG)
          </a>
          <button
            onClick={() => startDictation(activeTab)}
            className="w-full sm:w-auto flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl text-sm font-medium bg-zinc-900 text-zinc-200 border border-zinc-800 hover:bg-zinc-800 transition-all active:scale-98"
          >
            <Play className="w-4 h-4 text-zinc-400" />
            Try Live Dictation
          </button>
        </div>

        {/* ========================================================= */}
        {/* 3D SIMULATED MACOS GLASS DISPLAY (cooldock / Apple style) */}
        {/* ========================================================= */}
        <div className="relative max-w-5xl mx-auto rounded-[32px] p-2 sm:p-3.5 bg-gradient-to-b from-zinc-700/40 via-zinc-800/20 to-zinc-900/60 border border-zinc-700/60 shadow-[0_30px_100px_rgba(0,0,0,0.8)] backdrop-blur-2xl">
          <div className="rounded-[24px] overflow-hidden bg-[#0e0e12] border border-zinc-800/80 relative text-left">

            {/* macOS Menu Bar */}
            <div className="h-8 bg-[#16161b]/90 backdrop-blur-md px-4 flex items-center justify-between border-b border-zinc-800/80 text-[11px] font-mono text-zinc-400 select-none">
              <div className="flex items-center gap-4">
                <span className="font-bold text-white text-xs"></span>
                <span className="font-semibold text-zinc-200">Utter</span>
                <span className="hidden sm:inline hover:text-zinc-200 cursor-pointer">File</span>
                <span className="hidden sm:inline hover:text-zinc-200 cursor-pointer">Edit</span>
                <span className="hidden sm:inline hover:text-zinc-200 cursor-pointer">Speech</span>
                <span className="hidden sm:inline hover:text-zinc-200 cursor-pointer">Companions</span>
                <span className="hidden sm:inline hover:text-zinc-200 cursor-pointer">Window</span>
              </div>
              <div className="flex items-center gap-3">
                <span className="px-1.5 py-0.5 rounded bg-zinc-800 text-[10px] text-zinc-300">100% Offline</span>
                <Wifi className="w-3 h-3 text-zinc-400" />
                <Battery className="w-3.5 h-3.5 text-zinc-400" />
                <span className="text-zinc-300">{currentTime || '10:42 AM'}</span>
              </div>
            </div>

            {/* Simulated macOS Desktop Body */}
            <div className="relative min-h-[460px] sm:min-h-[520px] p-6 sm:p-10 flex flex-col justify-between bg-gradient-to-b from-[#121217] via-[#0d0d11] to-[#09090c] overflow-hidden">

              {/* Centered Floating Utter Liquid Glass HUD */}
              <div className="flex flex-col items-center justify-center my-auto z-20">
                <div
                  onClick={() => startDictation(activeTab)}
                  className={`interactive-hud-pill cursor-pointer select-none rounded-full px-6 py-3.5 flex items-center gap-4 border transition-all duration-300 ${
                    isRecording
                      ? 'bg-zinc-800 border-white text-white shadow-2xl scale-105'
                      : 'bg-zinc-900/90 border-zinc-700/80 text-zinc-300 hover:border-zinc-500 shadow-xl'
                  }`}
                >
                  <div className={`w-7 h-7 rounded-full flex items-center justify-center ${
                    isRecording ? 'bg-white text-black' : 'bg-zinc-800 text-zinc-300'
                  }`}>
                    <Mic className="w-3.5 h-3.5" />
                  </div>

                  {/* 7-Bar Acoustic Equalizer */}
                  <div className="flex items-center gap-1.5 h-5">
                    {[10, 16, 22, 26, 22, 16, 10].map((h, i) => (
                      <div
                        key={i}
                        className={`w-1 rounded-full transition-all duration-150 ${
                          isRecording ? 'bg-white animate-wave-bar' : 'bg-zinc-600'
                        }`}
                        style={{
                          height: isRecording ? `${h}px` : '5px',
                          animationDelay: `${i * 0.1}s`,
                        }}
                      />
                    ))}
                  </div>

                  <span className="text-xs font-mono font-medium">
                    {isRecording ? 'Listening (Metal GPU Shaders)...' : 'Hold Spacebar or Click to Dictate'}
                  </span>
                </div>

                {/* Target App Simulation Window */}
                <div className="w-full max-w-2xl rounded-2xl bg-[#141418]/90 border border-zinc-800 p-6 shadow-2xl mt-6 backdrop-blur-xl">
                  <div className="flex items-center justify-between text-xs font-mono text-zinc-400 border-b border-zinc-800/80 pb-2.5 mb-3">
                    <span className="flex items-center gap-2">
                      <Terminal className="w-3.5 h-3.5 text-zinc-400" />
                      Target: <strong className="text-zinc-200">{demos[activeTab].title}</strong>
                    </span>
                    <span className="text-zinc-300 font-medium">{demos[activeTab].stats}</span>
                  </div>
                  <pre className="font-mono text-xs sm:text-sm text-zinc-200 min-h-[90px] whitespace-pre-wrap leading-relaxed">
                    {typedText || (
                      <span className="text-zinc-500">
                        // Speak naturally. Your words appear here in 168ms without touching clipboard history...
                      </span>
                    )}
                    {isRecording && <span className="inline-block w-1.5 h-4 bg-white ml-1 animate-pulse" />}
                  </pre>
                </div>

                {/* Tab Preset Switchers */}
                <div className="flex flex-wrap items-center justify-center gap-2 mt-4">
                  {Object.keys(demos).map((key) => (
                    <button
                      key={key}
                      onClick={() => {
                        setActiveTab(key);
                        startDictation(key);
                      }}
                      className={`px-3 py-1.5 rounded-lg text-xs font-mono transition-all border ${
                        activeTab === key
                          ? 'bg-zinc-800 text-white border-zinc-600 shadow-sm'
                          : 'bg-zinc-900/60 text-zinc-400 border-zinc-800 hover:text-zinc-200'
                      }`}
                    >
                      {demos[key].tag}
                    </button>
                  ))}
                </div>
              </div>

              {/* Bottom Desktop Dock / Companion Widget */}
              <div className="z-20 pt-4 flex items-center justify-between text-xs font-mono text-zinc-500 border-t border-zinc-800/60">
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
                  <span>Metal GPU Core: Active</span>
                </div>
                <div
                  onClick={() => setPetHappy(true)}
                  className="cursor-pointer flex items-center gap-2 text-zinc-400 hover:text-white transition-colors"
                >
                  <Heart className={`w-3.5 h-3.5 ${petHappy ? 'text-rose-400 fill-rose-400' : 'text-zinc-500'}`} />
                  <span>Desktop Companion: {petHappy ? 'Purring ❤️' : 'Pixel Cat (Resting)'}</span>
                </div>
                <div>RAM: 181 MB (Small.en)</div>
              </div>

            </div>
          </div>
        </div>

      </div>
    </section>
  );
}
