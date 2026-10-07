import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, Zap, Cpu, Shield, Sparkles, Terminal, MessageSquare, FileText, Code2, Play, RefreshCw, Volume2 } from 'lucide-react';

const SAMPLE_SCRIPTS = [
  {
    id: 'code',
    appName: 'Cursor / VS Code',
    appIcon: Code2,
    category: 'Engineering',
    prompt: 'Implement a zero-latency audio buffer using Metal Performance Shaders',
    spokenText: 'const audioStream = new MetalAudioBuffer({ sampleRate: 16000, channels: 1 });\n// On-device whisper.cpp tokenized in 164ms\nexport async function transcribe() {\n  return await engine.infer(audioStream);\n}',
  },
  {
    id: 'slack',
    appName: 'Slack',
    appIcon: MessageSquare,
    category: 'Communication',
    prompt: 'Quick team update on offline voice dictation',
    spokenText: "Hey @channel, we just tested Utter in an air-gapped room. Zero packets sent to any external server, and speech appears in Slack with sub-200ms delay! 🚀",
  },
  {
    id: 'notes',
    appName: 'Apple Notes',
    appIcon: FileText,
    category: 'Note Taking',
    prompt: 'Meeting notes on patent confidential architecture',
    spokenText: 'Confidential Architecture Review:\n1. CoreML Whisper engine binds directly to Apple Silicon Neural Engine.\n2. Audio streams directly in RAM; no temporary .wav files written to disk.\n3. Zero network sockets opened.',
  },
  {
    id: 'terminal',
    appName: 'macOS Terminal',
    appIcon: Terminal,
    category: 'DevOps',
    prompt: 'Git commit and push with natural voice',
    spokenText: 'git commit -m "feat(metal): achieve 168ms local dictation latency with zero cloud dependency" && git push origin main',
  },
];

export default function InteractiveDictationStage({ soundEnabled }) {
  const [selectedApp, setSelectedApp] = useState(SAMPLE_SCRIPTS[0]);
  const [stageState, setStageState] = useState('idle'); // 'idle' | 'listening' | 'processing' | 'typed'
  const [typedText, setTypedText] = useState('');
  const [latencyMs, setLatencyMs] = useState(168);
  const typingIntervalRef = useRef(null);

  // Keyboard shortcut listener: Holding Space when focused or clicking button
  const startRecording = () => {
    if (stageState === 'listening') return;
    setStageState('listening');
    setTypedText('');
  };

  const stopRecordingAndTranscribe = () => {
    if (stageState !== 'listening') return;
    setStageState('processing');

    // Simulate whisper.cpp local metal inference latency (160ms - 190ms)
    const simulatedLatency = Math.floor(160 + Math.random() * 25);
    setLatencyMs(simulatedLatency);

    setTimeout(() => {
      setStageState('typed');
      // Stream characters into the mockup window
      const fullText = selectedApp.spokenText;
      let charIndex = 0;
      clearInterval(typingIntervalRef.current);

      typingIntervalRef.current = setInterval(() => {
        if (charIndex <= fullText.length) {
          setTypedText(fullText.slice(0, charIndex));
          charIndex += 2;
        } else {
          clearInterval(typingIntervalRef.current);
        }
      }, 16);
    }, simulatedLatency);
  };

  useEffect(() => {
    return () => clearInterval(typingIntervalRef.current);
  }, []);

  // Pre-fill on initial render
  useEffect(() => {
    setTypedText(selectedApp.spokenText);
    setStageState('idle');
  }, [selectedApp]);

  return (
    <section id="playground" className="relative py-24 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-12">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-4 border border-orange-500/20">
          <Sparkles size={13} />
          <span>INTERACTIVE DICTATION PLAYGROUND</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Experience push-to-talk in real time.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          Hold the trigger button below, speak naturally, and release. Watch Utter's liquid glass HUD capture speech and inject text directly into any focused Mac app.
        </p>
      </div>

      {/* Target App Switcher Tabs */}
      <div className="flex items-center justify-center gap-2 sm:gap-3 flex-wrap mb-8">
        {SAMPLE_SCRIPTS.map((app) => {
          const Icon = app.appIcon;
          const isActive = selectedApp.id === app.id;
          return (
            <motion.button
              key={app.id}
              onClick={() => setSelectedApp(app)}
              whileTap={{ scale: 0.95 }}
              className={`relative flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-medium transition-colors border ${
                isActive
                  ? 'text-white border-transparent'
                  : 'text-zinc-400 border-white/5 hover:text-zinc-200 hover:border-white/10'
              }`}
            >
              {isActive && (
                <motion.div
                  layoutId="activeDictationAppPill"
                  className="absolute inset-0 bg-zinc-800 rounded-xl border border-orange-500/50 shadow-md shadow-orange-500/15"
                  transition={{ type: 'spring', stiffness: 450, damping: 35 }}
                />
              )}
              <Icon size={14} className={`relative z-10 transition-colors ${isActive ? 'text-orange-400' : 'text-zinc-500'}`} />
              <span className="relative z-10">{app.appName}</span>
            </motion.button>
          );
        })}
      </div>

      {/* Main Interactive Stage Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Column: Interactive Trigger & Fluid Pill HUD (5 cols) */}
        <div className="lg:col-span-5 flex flex-col gap-5">
          {/* Big Tactile Trigger Button */}
          <div className="liquid-glass rounded-3xl p-6 sm:p-8 flex flex-col items-center text-center border border-white/10 shadow-2xl relative overflow-hidden">
            <div className="text-xs uppercase font-mono tracking-wider text-zinc-400 mb-2">
              Push-to-Talk Trigger
            </div>
            <div className="text-sm font-semibold text-white mb-6">
              Press & Hold to simulate speaking
            </div>

            {/* Giant Push-to-Talk Button */}
            <motion.button
              onMouseDown={startRecording}
              onMouseUp={stopRecordingAndTranscribe}
              onTouchStart={startRecording}
              onTouchEnd={stopRecordingAndTranscribe}
              whileHover={{ scale: 1.04 }}
              whileTap={{ scale: 0.92 }}
              transition={{ type: 'spring', stiffness: 450, damping: 25 }}
              className={`w-28 h-28 sm:w-32 sm:h-32 rounded-full flex flex-col items-center justify-center gap-2 cursor-pointer select-none shadow-2xl transition-all duration-200 ${
                stageState === 'listening'
                  ? 'bg-gradient-to-tr from-orange-600 to-amber-500 text-white ring-8 ring-orange-500/30'
                  : 'bg-zinc-900 text-zinc-200 border-2 border-orange-500/40 hover:border-orange-400 hover:shadow-orange-500/20'
              }`}
            >
              <Mic size={32} className={stageState === 'listening' ? 'animate-bounce' : 'text-orange-400'} />
              <span className="text-[11px] font-bold uppercase tracking-wider">
                {stageState === 'listening' ? 'Listening...' : 'Hold to Talk'}
              </span>
            </motion.button>

            <div className="mt-6 text-xs text-zinc-400 flex items-center gap-2">
              <span className="px-2 py-0.5 rounded bg-zinc-800 text-zinc-300 font-mono text-[11px] border border-white/5">
                Fn
              </span>
              <span>or</span>
              <span className="px-2 py-0.5 rounded bg-zinc-800 text-zinc-300 font-mono text-[11px] border border-white/5">
                Right ⌥
              </span>
              <span>Global Hotkeys</span>
            </div>
          </div>

          {/* Liquid Glass HUD State Display */}
          <div className="liquid-glass rounded-2xl p-5 border border-white/10 shadow-xl">
            <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-3">
              <span>ACTIVE HUD STATE</span>
              <span className="text-orange-400 font-semibold">{stageState.toUpperCase()}</span>
            </div>

            {/* Simulated macOS Pill HUD */}
            <div className="liquid-glass-pill px-4 py-3 rounded-2xl flex items-center justify-between border border-white/15">
              <div className="flex items-center gap-3">
                <div className={`w-3 h-3 rounded-full ${
                  stageState === 'listening' ? 'bg-red-500 animate-ping' :
                  stageState === 'processing' ? 'bg-amber-400 animate-spin' : 'bg-emerald-400'
                }`} />
                <span className="text-xs font-semibold text-white">
                  {stageState === 'listening' && 'Recording audio stream (16kHz RMS)...'}
                  {stageState === 'processing' && `whisper.cpp Metal inference (${latencyMs}ms)...`}
                  {stageState === 'typed' && 'Transcription injected into input field'}
                  {stageState === 'idle' && 'Utter Idle • Ready for push-to-talk'}
                </span>
              </div>

              {/* Live Waveform Equalizer */}
              <div className="flex items-center gap-1 h-4">
                {[1, 2, 3, 4, 5, 6].map((bar) => (
                  <span
                    key={bar}
                    className={`w-1 rounded-full transition-all duration-150 ${
                      stageState === 'listening'
                        ? 'bg-orange-400 animate-pulse h-full'
                        : 'bg-zinc-700 h-2'
                    }`}
                    style={{ animationDelay: `${bar * 0.12}s` }}
                  />
                ))}
              </div>
            </div>

            {/* Performance Stats */}
            <div className="grid grid-cols-3 gap-2 mt-4 pt-4 border-t border-white/5 text-center">
              <div>
                <div className="text-[10px] font-mono text-zinc-500 uppercase">Latency</div>
                <div className="text-xs font-mono font-bold text-amber-400">{latencyMs}ms</div>
              </div>
              <div>
                <div className="text-[10px] font-mono text-zinc-500 uppercase">Network I/O</div>
                <div className="text-xs font-mono font-bold text-emerald-400">0 KB (Air-Gapped)</div>
              </div>
              <div>
                <div className="text-[10px] font-mono text-zinc-500 uppercase">Engine</div>
                <div className="text-xs font-mono font-bold text-indigo-400">Metal + CoreML</div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Authentic macOS App Window Mockup (7 cols) */}
        <div className="lg:col-span-7">
          <div className="liquid-glass rounded-3xl border border-white/10 shadow-2xl overflow-hidden">
            {/* macOS Window Titlebar */}
            <div className="px-4 py-3 bg-zinc-900/90 border-b border-white/5 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-red-500/80 inline-block" />
                <span className="w-3 h-3 rounded-full bg-yellow-500/80 inline-block" />
                <span className="w-3 h-3 rounded-full bg-emerald-500/80 inline-block" />
              </div>
              <div className="text-xs font-medium text-zinc-400 flex items-center gap-2">
                <span>{selectedApp.appName}</span>
                <span className="text-zinc-600"> - </span>
                <span className="text-zinc-500 text-[11px] font-mono">{selectedApp.category}</span>
              </div>
              <button
                onClick={() => {
                  setTypedText(selectedApp.spokenText);
                  setStageState('typed');
                }}
                className="p-1 rounded text-zinc-400 hover:text-white"
                title="Reset simulation"
              >
                <RefreshCw size={13} />
              </button>
            </div>

            {/* Window Content Area */}
            <div className="p-6 sm:p-8 min-h-[300px] sm:min-h-[360px] bg-zinc-950/70 font-mono text-sm leading-relaxed text-zinc-200 select-text whitespace-pre-wrap relative">
              {/* Spoken text prompt header */}
              <div className="mb-4 pb-3 border-b border-white/5 text-xs font-mono text-zinc-500 flex items-center justify-between">
                <span>INTENT: "{selectedApp.prompt}"</span>
                <span className="text-emerald-400 font-semibold">180 WPM</span>
              </div>

              {/* Simulated Output Body */}
              <div className="text-zinc-100 font-mono text-xs sm:text-sm">
                {typedText}
                <span className="inline-block w-2 h-4 ml-1 bg-orange-400 animate-pulse align-middle" />
              </div>

              {stageState === 'listening' && (
                <div className="absolute inset-0 bg-zinc-950/80 backdrop-blur-sm flex flex-col items-center justify-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-orange-500/20 text-orange-400 flex items-center justify-center animate-pulse">
                    <Mic size={24} />
                  </div>
                  <div className="text-sm font-semibold text-white">Listening to audio stream...</div>
                  <div className="text-xs text-zinc-400 font-mono">Release the trigger to synthesize text</div>
                </div>
              )}
            </div>

            {/* Footer Bar */}
            <div className="px-5 py-2.5 bg-zinc-900/60 border-t border-white/5 flex items-center justify-between text-xs text-zinc-400 font-mono">
              <span className="flex items-center gap-2">
                <Shield size={12} className="text-emerald-400" />
                <span>100% In-Process Memory Injection</span>
              </span>
              <span className="text-zinc-500 text-[11px]">macOS Accessibility API</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
