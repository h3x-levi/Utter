import React, { useState, useEffect } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { Mic, Volume2, Sparkles, Cpu, BookOpen, Layers, Check, Play, Pause, Heart, Terminal } from 'lucide-react';
import CodeCompanionCanvas from './CodeCompanionCanvas';

export default function FeatureBento() {
  const shouldReduceMotion = useReducedMotion();

  // State for interactive features
  const [isTypingActive, setIsTypingActive] = useState(false);
  const [typedText, setTypedText] = useState('');
  const [selectedModel, setSelectedModel] = useState('small');
  const [catState, setCatState] = useState('idle'); // idle, happy, listening, sleeping
  const [activeTransform, setActiveTransform] = useState('clean');

  // Keystroke typing simulation for Dictation card
  const demoSentence = 'struct SpeechPipeline: MetalAccelerated { func transcribeLocal() -> Text { ... } }';
  
  useEffect(() => {
    if (!isTypingActive) {
      setTypedText('Press Simulate to test 180 WPM stream...');
      return;
    }
    setTypedText('');
    let idx = 0;
    const interval = setInterval(() => {
      if (idx < demoSentence.length) {
        setTypedText(demoSentence.slice(0, idx + 1));
        idx++;
      } else {
        clearInterval(interval);
      }
    }, 28);
    return () => clearInterval(interval);
  }, [isTypingActive]);

  const modelsData = {
    tiny: { size: '39 MB', speed: '48ms', ram: '< 90 MB', desc: 'Ultra-light, best for quick hotkey snippets' },
    small: { size: '466 MB', speed: '168ms', ram: '< 180 MB', desc: 'Bundled default: 99.2% accuracy on English' },
    large: { size: '809 MB', speed: '240ms', ram: '< 340 MB', desc: 'Large-v3-Turbo: maximum multilingual precision' },
  };

  return (
    <section className="py-24 px-4 sm:px-8 w-full relative z-10">
      <div className="max-w-7xl mx-auto">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/80 backdrop-blur-md border border-black/[0.08] shadow-xs text-xs font-semibold text-zinc-800 mb-4">
            <Sparkles size={13} className="text-indigo-600" />
            <span>Interactive macOS Experience</span>
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight text-zinc-950 mb-4">
            Crafted for speed. Built for macOS.
          </h2>
          <p className="text-base sm:text-lg text-zinc-600 leading-relaxed">
            Every feature runs in unified memory on Apple Silicon. Zero network hops, zero subscriptions, pure tactile power.
          </p>
        </div>

        {/* Bento Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Card 1: Universal Dictation + Live Keystroke Stream (8 cols) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1] }}
            className="lg:col-span-8 frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
          >
            <div>
              <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-2xl bg-indigo-500/10 flex items-center justify-center text-indigo-600 border border-indigo-200/50">
                    <Mic size={20} />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-zinc-950">Universal Dictation Anywhere</h3>
                    <p className="text-xs sm:text-sm text-zinc-500">Dictate into Cursor, Xcode, Slack, or Obsidian</p>
                  </div>
                </div>

                <button
                  onClick={() => setIsTypingActive(!isTypingActive)}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-zinc-950 text-white text-xs font-bold hover:bg-black transition-transform duration-150 active:scale-[0.97] cursor-pointer shadow-sm"
                >
                  {isTypingActive ? <Pause size={13} /> : <Play size={13} />}
                  <span>{isTypingActive ? 'Pause Stream' : 'Simulate 180 WPM'}</span>
                </button>
              </div>

              {/* Simulated Code Editor */}
              <div className="rounded-2xl overflow-hidden bg-zinc-950 border border-zinc-800/80 shadow-inner p-4 font-mono text-xs mb-6 text-zinc-200">
                <div className="flex items-center gap-1.5 pb-3 border-b border-zinc-800 text-zinc-500 text-[11px]">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-500/80 inline-block" />
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500/80 inline-block" />
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500/80 inline-block" />
                  <span className="ml-2 text-zinc-400">SpeechEngine.swift (Cursor)</span>
                  <span className="ml-auto text-emerald-400 font-bold">180 WPM Stream</span>
                </div>
                <div className="pt-3 min-h-[56px] flex items-center text-indigo-300">
                  <span>{typedText}</span>
                  <span className="w-2 h-4 bg-indigo-400 ml-1 inline-block animate-pulse" />
                </div>
              </div>
            </div>

            {/* App Window Screenshot Preview */}
            <div className="rounded-xl overflow-hidden border border-black/[0.06] shadow-sm bg-white/70">
              <img
                src="/assets/screenshots/hero-main.png"
                alt="Utter main dictation workspace"
                className="w-full h-auto object-cover object-top max-h-72"
                loading="lazy"
              />
            </div>
          </motion.div>

          {/* Card 2: Whisper Model Switcher (4 cols) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1], delay: 0.08 }}
            className="lg:col-span-4 frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-2xl bg-amber-500/10 flex items-center justify-center text-amber-600 border border-amber-200/50">
                  <Cpu size={20} />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-zinc-950">Whisper Local Engine</h3>
                  <p className="text-xs sm:text-sm text-zinc-500">Apple Silicon Metal Acceleration</p>
                </div>
              </div>

              <p className="text-xs sm:text-sm text-zinc-600 mb-6 leading-relaxed">
                Choose the exact weights for your workload. Bundled Small.en provides instant voice dictation with zero setup.
              </p>

              {/* Model Picker Selector */}
              <div className="space-y-2.5 mb-6">
                {Object.entries(modelsData).map(([key, data]) => (
                  <button
                    key={key}
                    onClick={() => setSelectedModel(key)}
                    className={`w-full text-left p-3 rounded-2xl border transition-all duration-150 cursor-pointer flex items-center justify-between ${
                      selectedModel === key
                        ? 'bg-white/95 border-indigo-400 shadow-sm'
                        : 'bg-white/50 border-black/[0.06] hover:bg-white/75'
                    }`}
                  >
                    <div>
                      <div className="font-bold text-xs capitalize text-zinc-900 flex items-center gap-2">
                        <span>{key}</span>
                        {key === 'small' && (
                          <span className="px-1.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-[10px] font-bold">
                            Default
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] text-zinc-500">{data.desc}</div>
                    </div>
                    <div className="text-right font-mono text-xs">
                      <div className="font-bold text-indigo-600">{data.speed}</div>
                      <div className="text-[10px] text-zinc-400">{data.size}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            <div className="rounded-xl overflow-hidden border border-black/[0.06] bg-white/70">
              <img
                src="/assets/screenshots/06_model_chooser.png"
                alt="Utter Model Chooser"
                className="w-full h-32 object-cover object-top"
                loading="lazy"
              />
            </div>
          </motion.div>

          {/* Card 3: Meeting Transcription & Diarization (5 cols) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1], delay: 0.12 }}
            className="lg:col-span-5 frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-600 border border-emerald-200/50">
                  <Volume2 size={20} />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-zinc-950">Dual-Channel Notes Studio</h3>
                  <p className="text-xs sm:text-sm text-zinc-500">Zoom, Teams, & Google Meet</p>
                </div>
              </div>

              <p className="text-xs sm:text-sm text-zinc-600 mb-6 leading-relaxed">
                CoreAudio Process Taps separate your microphone from remote call audio, creating structured transcripts with speaker turns.
              </p>

              {/* Speaker Diarization Mock Strip */}
              <div className="space-y-2 mb-6 text-xs">
                <div className="p-2.5 rounded-xl bg-emerald-50/80 border border-emerald-200/60 flex items-start gap-2">
                  <span className="font-bold text-emerald-800 text-[10px] px-1.5 py-0.5 rounded-md bg-emerald-200/60">YOU</span>
                  <span className="text-zinc-700">Let us ship the whisper.cpp Metal CoreML pipeline today.</span>
                </div>
                <div className="p-2.5 rounded-xl bg-indigo-50/80 border border-indigo-200/60 flex items-start gap-2">
                  <span className="font-bold text-indigo-800 text-[10px] px-1.5 py-0.5 rounded-md bg-indigo-200/60">OTHERS</span>
                  <span className="text-zinc-700">Agreed, zero cloud latency is a massive differentiator.</span>
                </div>
              </div>
            </div>

            <div className="rounded-xl overflow-hidden border border-black/[0.06] bg-white/70">
              <img
                src="/assets/screenshots/04_notes_studio.png"
                alt="Utter Notes Studio with Meeting Transcription"
                className="w-full h-40 object-cover object-top"
                loading="lazy"
              />
            </div>
          </motion.div>

          {/* Card 4: Retro Pixel Pet Companion (3 cols) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1], delay: 0.16 }}
            className="lg:col-span-3 frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-2xl bg-pink-500/10 flex items-center justify-center text-pink-600 border border-pink-200/50">
                  <Heart size={20} />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-zinc-950">Pixel Cat Pet</h3>
                  <p className="text-xs sm:text-sm text-zinc-500">Desktop Companion</p>
                </div>
              </div>

              <p className="text-xs sm:text-sm text-zinc-600 mb-5 leading-relaxed">
                A retro desk pet that reacts to mic amplitude, sleeps during silence, and purrs as you dictate.
              </p>

              {/* Interactive Cat Simulator */}
              <div className="p-4 rounded-2xl bg-white/80 border border-black/[0.06] text-center mb-6">
                <div className="text-4xl mb-2 select-none">
                  {catState === 'sleeping' ? '😴' : catState === 'happy' ? '😻' : catState === 'listening' ? '🐱🎙️' : '🐱'}
                </div>
                <div className="text-xs font-bold text-zinc-800 capitalize mb-3">
                  Mood: {catState}
                </div>
                <div className="flex justify-center gap-2">
                  <button
                    onClick={() => setCatState('happy')}
                    className="px-2.5 py-1 rounded-full bg-pink-50 text-pink-700 text-[11px] font-bold hover:bg-pink-100 cursor-pointer active:scale-95"
                  >
                    Pet Cat
                  </button>
                  <button
                    onClick={() => setCatState(catState === 'listening' ? 'idle' : 'listening')}
                    className="px-2.5 py-1 rounded-full bg-indigo-50 text-indigo-700 text-[11px] font-bold hover:bg-indigo-100 cursor-pointer active:scale-95"
                  >
                    Speak
                  </button>
                  <button
                    onClick={() => setCatState(catState === 'sleeping' ? 'idle' : 'sleeping')}
                    className="px-2.5 py-1 rounded-full bg-zinc-100 text-zinc-700 text-[11px] font-bold hover:bg-zinc-200 cursor-pointer active:scale-95"
                  >
                    Sleep
                  </button>
                </div>
              </div>
            </div>

            <div className="rounded-xl overflow-hidden border border-black/[0.06] bg-zinc-950/80 flex items-center justify-center p-2">
              <CodeCompanionCanvas species="cat" isGinger={true} action={companionState === 'resting' ? 'loaf' : companionState === 'typing' ? 'knead' : 'delighted'} width={130} height={130} />
            </div>
          </motion.div>

          {/* Card 5: Dictionary & AI Transforms (4 cols) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1], delay: 0.2 }}
            className="lg:col-span-4 frosted-glass-card p-6 sm:p-8 flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-2xl bg-purple-500/10 flex items-center justify-center text-purple-600 border border-purple-200/50">
                  <BookOpen size={20} />
                </div>
                <div>
                  <h3 className="text-xl font-bold text-zinc-950">Dictionary & Transforms</h3>
                  <p className="text-xs sm:text-sm text-zinc-500">Developer Jargon Bias</p>
                </div>
              </div>

              <p className="text-xs sm:text-sm text-zinc-600 mb-5 leading-relaxed">
                Add custom technical vocabulary so domain terms like Kubernetes, PyTorch, or SwiftUI never get mistranscribed.
              </p>

              {/* Interactive Vocabulary Chips */}
              <div className="flex flex-wrap gap-1.5 mb-6">
                {['whisper.cpp', 'AVAudioEngine', 'CoreAudio', 'PyTorch', 'ScreenCaptureKit', 'Tailwind'].map((tag) => (
                  <span
                    key={tag}
                    className="px-2.5 py-1 rounded-full bg-white/90 border border-black/[0.08] text-zinc-800 text-xs font-mono font-medium shadow-2xs"
                  >
                    +{tag}
                  </span>
                ))}
              </div>
            </div>

            <div className="rounded-xl overflow-hidden border border-black/[0.06] bg-white/70">
              <img
                src="/assets/screenshots/08_dictionary_studio.png"
                alt="Utter Dictionary Studio"
                className="w-full h-32 object-cover object-top"
                loading="lazy"
              />
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
