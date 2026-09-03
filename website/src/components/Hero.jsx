import React, { useState, useEffect, useRef } from 'react';
import { Download, Mic, Terminal, Play } from 'lucide-react';
import { animate as animeAnimate, stagger } from 'animejs';
import ThreeHeroScene from './ThreeHeroScene';

export default function Hero() {
  const [isRecording, setIsRecording] = useState(false);
  const [typedText, setTypedText] = useState('');
  const [activePreset, setActivePreset] = useState(0);
  const titleRef = useRef(null);
  const typingTimerRef = useRef(null);

  const presets = [
    {
      label: 'Swift Metal Audio Stream',
      text: 'func processAudioStream(sampleBuffer: CMSampleBuffer) async throws -> SpeechTurn {\n    let pcm16 = try audioConverter.convert(sampleBuffer)\n    return try await whisperEngine.transcribe(pcm16, language: .en)\n}',
      stats: '188 WPM • 0.16s latency • Metal GPU',
    },
    {
      label: 'Meeting Action Items',
      text: '- Levi to review Metal compute shader pipeline before release.\n- Air-gapped zero telemetry architecture verified with lsof.\n- DMG installer packaged with Small.en model bundled.',
      stats: '194 WPM • 0.18s latency • Notes Studio',
    },
    {
      label: 'Local Foundation Summary',
      text: 'Summary: Utter processes audio streams directly in unified Apple Silicon memory without temporary disk files, eliminating cloud network latency.',
      stats: 'Apple Intelligence • On-Device',
    },
  ];

  // Anime.js Headline Entrance Animation
  useEffect(() => {
    if (titleRef.current) {
      const chars = titleRef.current.querySelectorAll('.char-span');
      if (chars.length > 0) {
        animeAnimate(chars, {
          translateY: [20, 0],
          opacity: [0, 1],
          delay: stagger(15, { start: 100 }),
          duration: 600,
        });
      }
    }
  }, []);

  const startDictation = (textIndex = 0) => {
    if (isRecording) return;
    setIsRecording(true);
    setTypedText('');
    clearInterval(typingTimerRef.current);

    animeAnimate('.pill-indicator', {
      scale: [1, 1.05, 1],
      duration: 350,
    });

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
      }, 14);
    }, 500);
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

  // Split headline for Anime.js staggered reveal
  const headlineWords = "Zero-latency voice dictation engineered for macOS.".split(" ");

  return (
    <section className="relative z-10 pt-32 pb-24 px-6 overflow-hidden">
      <div className="max-w-6xl mx-auto text-center">

        {/* Apple Sub-Header Badge */}
        <div className="inline-flex items-center gap-2.5 px-3.5 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 text-xs font-mono font-medium text-zinc-300 mb-8 backdrop-blur-xl">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
          100% On-Device Whisper.cpp on Apple Silicon Metal GPU
        </div>

        {/* Editorial Headline */}
        <h1
          ref={titleRef}
          className="text-5xl sm:text-7xl lg:text-8xl font-bold tracking-tight text-white leading-[1.05] mb-8 max-w-5xl mx-auto"
        >
          {headlineWords.map((word, wIdx) => (
            <span key={wIdx} className="inline-block mr-3 sm:mr-4 whitespace-nowrap">
              {word.split("").map((char, cIdx) => (
                <span key={cIdx} className="char-span inline-block opacity-0">
                  {char}
                </span>
              ))}
            </span>
          ))}
        </h1>

        {/* Subtitle */}
        <p className="text-lg sm:text-2xl text-zinc-400 max-w-3xl mx-auto leading-relaxed mb-12 font-normal">
          Hold a key, speak naturally, release to type anywhere on your Mac. Sub-200ms local inference with zero cloud telemetry.
        </p>

        {/* Apple Action CTAs */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="w-full sm:w-auto flex items-center justify-center gap-3 px-8 py-3.5 rounded-xl text-sm font-semibold bg-white text-zinc-950 hover:bg-zinc-200 transition-all hover:scale-102 active:scale-98 shadow-xl"
          >
            <Download className="w-4 h-4" />
            Download for macOS
          </a>
          <button
            onClick={() => startDictation(activePreset)}
            className="w-full sm:w-auto flex items-center justify-center gap-2.5 px-8 py-3.5 rounded-xl text-sm font-semibold bg-zinc-900/80 hover:bg-zinc-800 text-zinc-200 border border-zinc-800 transition-all hover:scale-102 active:scale-98"
          >
            <Play className="w-4 h-4 text-zinc-400" />
            Test Live Simulation
          </button>
        </div>

        {/* 3D Three.js Interactive Sculpture */}
        <div className="max-w-4xl mx-auto -my-6">
          <ThreeHeroScene isRecording={isRecording} />
        </div>

        {/* 3D Interactive macOS Window Frame */}
        <div
          id="demo"
          className="relative max-w-5xl mx-auto rounded-2xl bg-[#121215] border border-zinc-800 shadow-2xl overflow-hidden text-left mt-8"
        >
          {/* macOS Titlebar */}
          <div className="h-10 bg-[#18181b] px-4 flex items-center justify-between border-b border-zinc-800">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#ff5f56]"></span>
              <span className="w-3 h-3 rounded-full bg-[#ffbd2e]"></span>
              <span className="w-3 h-3 rounded-full bg-[#27c93f]"></span>
            </div>
            <span className="text-xs font-mono text-zinc-400">
              Live macOS HUD Simulator — Press Spacebar or Click Mic
            </span>
            <div className="w-12"></div>
          </div>

          {/* Body Canvas */}
          <div className="p-6 sm:p-10 bg-[#0e0e11] flex flex-col items-center justify-between min-h-[460px] gap-6">

            {/* Floating Liquid Glass Pill */}
            <div
              onClick={() => startDictation(activePreset)}
              className={`pill-indicator cursor-pointer select-none rounded-full px-6 py-3 flex items-center gap-4 border transition-all duration-300 ${
                isRecording
                  ? 'bg-zinc-800 border-white text-white shadow-2xl'
                  : 'bg-zinc-900/90 border-zinc-700 text-zinc-300 hover:border-zinc-500'
              }`}
            >
              <div className={`w-7 h-7 rounded-full flex items-center justify-center ${
                isRecording ? 'bg-white text-black' : 'bg-zinc-800 text-zinc-300'
              }`}>
                <Mic className="w-3.5 h-3.5" />
              </div>

              {/* 7-Bar Acoustic Waveform */}
              <div className="flex items-center gap-1 h-5">
                {[8, 14, 20, 24, 20, 14, 8].map((h, i) => (
                  <div
                    key={i}
                    className={`w-1 rounded-full transition-all duration-150 ${
                      isRecording ? 'bg-white animate-wave-bar' : 'bg-zinc-600'
                    }`}
                    style={{
                      height: isRecording ? `${h}px` : '4px',
                      animationDelay: `${i * 0.1}s`,
                    }}
                  />
                ))}
              </div>

              <span className="text-xs font-mono font-medium">
                {isRecording ? 'Listening (Metal GPU)...' : 'Hold Space to Dictate'}
              </span>
            </div>

            {/* Target Code Editor Box */}
            <div className="w-full max-w-2xl rounded-xl bg-[#16161a] border border-zinc-800 p-6 shadow-xl">
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 border-b border-zinc-800 pb-2 mb-3">
                <span className="flex items-center gap-2">
                  <Terminal className="w-3.5 h-3.5 text-zinc-400" />
                  Target: <strong className="text-zinc-200">Xcode / Cursor (main.swift)</strong>
                </span>
                <span className="text-zinc-300 font-semibold">{presets[activePreset].stats}</span>
              </div>
              <pre className="font-mono text-xs sm:text-sm text-zinc-200 min-h-[85px] whitespace-pre-wrap leading-relaxed">
                {typedText || (
                  <span className="text-zinc-500">
                    // Hold Spacebar or click the pill above to test on-device transcription...
                  </span>
                )}
                {isRecording && <span className="inline-block w-1.5 h-4 bg-white ml-1 animate-pulse" />}
              </pre>
            </div>

            {/* Presets Switcher */}
            <div className="flex flex-wrap items-center justify-center gap-2">
              {presets.map((preset, idx) => (
                <button
                  key={idx}
                  onClick={() => {
                    setActivePreset(idx);
                    startDictation(idx);
                  }}
                  className={`px-3.5 py-1.5 rounded-lg text-xs font-mono transition-all border ${
                    activePreset === idx
                      ? 'bg-zinc-800 text-white border-zinc-600'
                      : 'bg-zinc-900 text-zinc-400 border-zinc-800 hover:text-zinc-200'
                  }`}
                >
                  {preset.label}
                </button>
              ))}
            </div>

          </div>
        </div>

      </div>
    </section>
  );
}
