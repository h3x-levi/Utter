import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  Check, HardDrive, Zap, Cpu, Download, Mic, Lock, Edit3, Plus, 
  Search, Copy, Share2, Trash2, Sparkles, FileText, CheckSquare, 
  Wand2, AlignLeft, Shield, CheckCircle2, ChevronDown 
} from 'lucide-react';

export default function InteractiveMacStudio() {
  const [activeTab, setActiveTab] = useState('models'); // default to user's favorite models screen
  const [selectedModel, setSelectedModel] = useState('small');
  const [pillState, setPillState] = useState('recording'); // resting, recording, handsFree, typing
  const [selectedCompanion, setSelectedCompanion] = useState('cat'); // cat, corgi, panda
  const [selectedNote, setSelectedNote] = useState('sprint');
  const [aiTransform, setAiTransform] = useState(null);

  // Tab 1: Whisper Models Data (1:1 replica of user's Settings window)
  const models = [
    {
      id: 'base',
      name: 'Base',
      badge: null,
      description: 'Fastest and smallest. Fine for everyday notes, weaker on unusual names.',
      size: '57 MB',
      speed: '<1s per min (Ultra Fast)',
      ram: '180 MB RAM',
      downloadable: true,
    },
    {
      id: 'small',
      name: 'Small',
      badge: { text: 'Active & Ready', color: 'bg-amber-100 text-amber-800 border-amber-300' },
      description: 'Fast and light, English-only. A good default on any Mac, including 8 GB machines.',
      size: '181 MB',
      speed: '2s per min',
      ram: '395 MB RAM',
      downloadable: false,
    },
    {
      id: 'medium',
      name: 'Medium',
      badge: { text: 'Recommended', color: 'bg-purple-100 text-purple-800 border-purple-300' },
      description: 'Most accurate on technical terms and unusual names, but English-only. 10x faster than real time.',
      size: '514 MB',
      speed: '6s per min',
      ram: '815 MB RAM',
      downloadable: true,
    },
    {
      id: 'turbo',
      name: 'Large Turbo',
      badge: { text: '90+ languages', color: 'bg-blue-100 text-blue-800 border-blue-300' },
      description: 'State-of-the-art multilingual transcription. Handles noisy background environments.',
      size: '809 MB',
      speed: '8s per min',
      ram: '980 MB RAM',
      downloadable: true,
    },
  ];

  const currentModel = models.find((m) => m.id === selectedModel);

  return (
    <div id="demo" className="w-full card-opaque shadow-2xl overflow-hidden border border-black/10 transition-all text-left">
      {/* macOS Window Titlebar with Segmented Tab Switcher */}
      <div className="bg-zinc-100/95 border-b border-black/[0.08] px-4 sm:px-6 py-3 flex flex-wrap items-center justify-between gap-3">
        {/* Window Controls */}
        <div className="flex items-center gap-2.5">
          <div className="w-3 h-3 rounded-full bg-[#ff5f56] border border-black/10" />
          <div className="w-3 h-3 rounded-full bg-[#ffbd2e] border border-black/10" />
          <div className="w-3 h-3 rounded-full bg-[#27c93f] border border-black/10" />
          <span className="text-xs font-semibold text-zinc-700 ml-2 hidden sm:inline">
            Utter for macOS — Production System Simulator
          </span>
        </div>

        {/* Real App Mode Switcher Tabs */}
        <div className="flex items-center gap-1 bg-zinc-200/80 p-1 rounded-xl">
          {[
            { id: 'models', label: 'Speech Models', icon: '🧠' },
            { id: 'pills', label: 'Liquid Glass Pill', icon: '💊' },
            { id: 'notes', label: 'Notes & Meetings', icon: '📝' },
            { id: 'companions', label: 'Desktop Pets', icon: '🐱' },
            { id: 'diagnostics', label: 'Diagnostics & Telemetry', icon: '🛡️' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all duration-150 flex items-center gap-1.5 ${
                activeTab === tab.id
                  ? 'bg-white text-zinc-900 shadow-sm'
                  : 'text-zinc-600 hover:text-zinc-900'
              }`}
            >
              <span>{tab.icon}</span>
              <span className="hidden md:inline">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Interactive Window Body */}
      <div className="p-5 sm:p-8 bg-white min-h-[460px]">
        {/* ============================================================== */}
        {/* TAB 1: WHISPER MODELS (Exact Replica of native Settings window) */}
        {/* ============================================================== */}
        {activeTab === 'models' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="max-w-4xl mx-auto"
          >
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-xl font-bold text-zinc-900">Speech</h3>
                <p className="text-xs text-zinc-500">Local Whisper neural weights running in Apple Silicon unified memory</p>
              </div>
              <span className="text-xs font-mono font-medium px-3 py-1 rounded-full bg-amber-50 text-amber-800 border border-amber-200">
                Active: {currentModel.name}
              </span>
            </div>

            <div className="space-y-3">
              {models.map((m) => {
                const isSelected = selectedModel === m.id;
                return (
                  <div
                    key={m.id}
                    onClick={() => setSelectedModel(m.id)}
                    className={`p-4 rounded-2xl cursor-pointer transition-all duration-150 border text-left ${
                      isSelected
                        ? 'bg-amber-50/50 border-amber-400 ring-2 ring-amber-400/20 shadow-sm'
                        : 'bg-zinc-50 hover:bg-zinc-100/80 border-black/5'
                    }`}
                  >
                    <div className="flex items-start gap-3.5">
                      <div className="pt-0.5">
                        {isSelected ? (
                          <div className="w-5 h-5 rounded-full bg-amber-500 flex items-center justify-center text-white shadow-sm">
                            <Check size={14} className="stroke-[3]" />
                          </div>
                        ) : (
                          <div className="w-5 h-5 rounded-full border-2 border-zinc-300" />
                        )}
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="flex flex-wrap items-center gap-2 mb-1">
                          <span className="font-bold text-sm text-zinc-900">{m.name}</span>
                          {m.badge && (
                            <span className={`text-[11px] font-semibold px-2 py-0.5 rounded-full border ${m.badge.color}`}>
                              {m.badge.text}
                            </span>
                          )}
                        </div>

                        <p className="text-xs text-zinc-600 mb-2.5 leading-relaxed">{m.description}</p>

                        <div className="flex flex-wrap items-center gap-2 text-xs">
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-white border border-zinc-200 text-zinc-700 font-mono text-[11px]">
                            <HardDrive size={12} className="text-amber-500" />
                            {m.size}
                          </span>

                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-white border border-zinc-200 text-zinc-700 font-mono text-[11px]">
                            <Zap size={12} className="text-emerald-500" />
                            {m.speed}
                          </span>

                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-white border border-zinc-200 text-zinc-700 font-mono text-[11px]">
                            <Cpu size={12} className="text-indigo-500" />
                            {m.ram}
                          </span>

                          {m.downloadable && !isSelected && (
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setSelectedModel(m.id);
                              }}
                              className="ml-auto inline-flex items-center gap-1 px-3 py-1 rounded-lg bg-zinc-900 hover:bg-black text-white text-xs font-semibold transition-colors shadow-sm"
                            >
                              <Download size={12} />
                              Download
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            <div className="mt-4 p-3 rounded-xl bg-zinc-50 border border-zinc-200 flex items-center justify-between text-xs text-zinc-600">
              <span className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                Selected Engine: <strong className="text-zinc-900">{currentModel.name} (Q5_1 Metal GPU)</strong>
              </span>
              <span className="font-mono text-zinc-500">RAM: <strong className="text-zinc-800">{currentModel.ram}</strong></span>
            </div>
          </motion.div>
        )}

        {/* ============================================================== */}
        {/* TAB 2: LIQUID GLASS PILL LINEUP (Exact replica of feature-pill)*/}
        {/* ============================================================== */}
        {activeTab === 'pills' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="space-y-6"
          >
            {/* Simulated IDE context behind the pill */}
            <div className="rounded-2xl bg-[#1e1e24] text-zinc-300 p-6 font-mono text-xs shadow-inner relative overflow-hidden">
              <div className="flex items-center justify-between text-zinc-500 border-b border-zinc-800 pb-3 mb-4 text-[11px]">
                <span>Sources/UtterKit/Speech/TranscriptionService.swift</span>
                <span className="text-zinc-400">UTF-8 • Swift 5.9 • Metal CoreML</span>
              </div>
              <pre className="text-zinc-400 leading-relaxed">
{`public final class TranscriptionService {
    private let whisperContext: OpaquePointer
    public func transcribe(pcmBuffer: [Float]) async -> String {
        // 100% on-device Metal accelerated local Whisper inference
        return await localWhisper.process(samples: pcmBuffer)
    }
}`}
              </pre>

              {/* Floating Pill Showcase Overlay (1:1 with app screenshot) */}
              <div className="mt-8 p-6 rounded-3xl bg-black/60 backdrop-blur-xl border border-white/10 text-center max-w-2xl mx-auto shadow-2xl">
                <h4 className="text-base font-bold text-white mb-5 tracking-tight">
                  Utter Liquid Glass Pill Lineup
                </h4>

                {/* The 4 States from app */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
                  {/* State 1: Resting */}
                  <div
                    onClick={() => setPillState('resting')}
                    className={`p-3 rounded-2xl cursor-pointer transition-all border ${
                      pillState === 'resting'
                        ? 'bg-white/20 border-white/40 ring-2 ring-white/20'
                        : 'bg-white/5 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    <div className="h-10 rounded-full bg-zinc-800/90 border border-white/20 flex items-center justify-center mb-2 mx-auto px-4 w-20">
                      <Mic size={16} className="text-white/80" />
                    </div>
                    <span className="text-[11px] font-semibold text-white/80">Resting</span>
                  </div>

                  {/* State 2: Recording */}
                  <div
                    onClick={() => setPillState('recording')}
                    className={`p-3 rounded-2xl cursor-pointer transition-all border ${
                      pillState === 'recording'
                        ? 'bg-white/20 border-white/40 ring-2 ring-white/20'
                        : 'bg-white/5 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    <div className="h-10 rounded-full bg-zinc-800/90 border border-white/20 flex items-center justify-center gap-1 mb-2 mx-auto px-4 w-24">
                      {[40, 80, 100, 60, 90].map((h, i) => (
                        <span key={i} className="w-1 bg-white rounded-full animate-pulse" style={{ height: `${h}%` }} />
                      ))}
                    </div>
                    <span className="text-[11px] font-semibold text-white/80">Recording</span>
                  </div>

                  {/* State 3: Hands-Free */}
                  <div
                    onClick={() => setPillState('handsFree')}
                    className={`p-3 rounded-2xl cursor-pointer transition-all border ${
                      pillState === 'handsFree'
                        ? 'bg-white/20 border-white/40 ring-2 ring-white/20'
                        : 'bg-white/5 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    <div className="h-10 rounded-full bg-zinc-800/90 border border-amber-500/40 flex items-center justify-center gap-1.5 mb-2 mx-auto px-4 w-24">
                      <Lock size={12} className="text-amber-400" />
                      <span className="w-1 h-3 bg-amber-400 rounded-full animate-pulse" />
                      <span className="w-1 h-4 bg-amber-400 rounded-full animate-pulse" />
                    </div>
                    <span className="text-[11px] font-semibold text-amber-300">Hands-Free</span>
                  </div>

                  {/* State 4: Typing */}
                  <div
                    onClick={() => setPillState('typing')}
                    className={`p-3 rounded-2xl cursor-pointer transition-all border ${
                      pillState === 'typing'
                        ? 'bg-white/20 border-white/40 ring-2 ring-white/20'
                        : 'bg-white/5 border-white/10 hover:bg-white/10'
                    }`}
                  >
                    <div className="h-10 rounded-full bg-zinc-800/90 border border-white/20 flex items-center justify-center mb-2 mx-auto px-4 w-20">
                      <Edit3 size={15} className="text-white/80" />
                    </div>
                    <span className="text-[11px] font-semibold text-white/80">Typing</span>
                  </div>
                </div>

                {/* Bottom Cat Banner (1:1 from app screenshot) */}
                <div className="inline-flex items-center gap-3 px-4 py-2.5 rounded-full bg-white/10 border border-white/15 text-xs text-white/90">
                  <span className="text-xl">🐱</span>
                  <span>Companion dynamically reacts to audio metering, speech flow and typing cadence</span>
                </div>
              </div>
            </div>
          </motion.div>
        )}

        {/* ============================================================== */}
        {/* TAB 3: NOTES & MEETINGS STUDIO (1:1 with 04_notes_studio.png)   */}
        {/* ============================================================== */}
        {activeTab === 'notes' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="rounded-2xl bg-zinc-950 text-white shadow-xl overflow-hidden border border-zinc-800"
          >
            {/* Real App Titlebar */}
            <div className="h-10 bg-zinc-900 border-b border-zinc-800 px-4 flex items-center justify-between text-xs text-zinc-400">
              <div className="flex items-center gap-2">
                <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f56]" />
                <div className="w-2.5 h-2.5 rounded-full bg-[#ffbd2e]" />
                <div className="w-2.5 h-2.5 rounded-full bg-[#27c93f]" />
                <span className="text-zinc-300 font-semibold ml-2">Utter Notes — Meeting Transcription & AI Notebook</span>
              </div>
              <div className="flex items-center gap-1.5 font-mono text-[11px] bg-zinc-800 px-2 py-0.5 rounded">
                <span>🎙️ Utter Active</span>
              </div>
            </div>

            {/* Main Split Interface */}
            <div className="grid grid-cols-1 md:grid-cols-12 min-h-[380px]">
              {/* Left Sidebar */}
              <div className="md:col-span-4 border-r border-zinc-800 p-4 space-y-4 bg-zinc-900/40">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-sm text-zinc-200">Notes</span>
                  <button className="w-6 h-6 rounded bg-zinc-800 hover:bg-zinc-700 flex items-center justify-center text-zinc-300 text-xs">
                    <Plus size={14} />
                  </button>
                </div>

                <button className="w-full flex items-center gap-2 px-3 py-2 rounded-xl bg-zinc-800/90 hover:bg-zinc-800 text-xs font-semibold text-zinc-200 border border-zinc-700 shadow-sm transition-colors">
                  <span className="text-rose-400 animate-pulse">●</span>
                  Record a meeting
                </button>

                <div className="relative">
                  <Search size={13} className="absolute left-2.5 top-2.5 text-zinc-500" />
                  <input
                    type="text"
                    placeholder="Search notes"
                    className="w-full bg-zinc-900 border border-zinc-800 rounded-lg pl-8 pr-3 py-1.5 text-xs text-zinc-300 placeholder:text-zinc-600 focus:outline-none"
                    readOnly
                  />
                </div>

                <div>
                  <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider block mb-2">TODAY</span>
                  <div className="space-y-1.5">
                    {[
                      { id: 'sprint', title: 'Sprint Architecture Sync', time: '2:15 PM', preview: 'Discussing local Whisper streaming buffer...' },
                      { id: 'interview', title: 'Founder Check-in', time: '11:30 AM', preview: 'Zero telemetry code verified with lsof...' },
                    ].map((n) => (
                      <div
                        key={n.id}
                        onClick={() => setSelectedNote(n.id)}
                        className={`p-2.5 rounded-xl cursor-pointer text-left transition-colors ${
                          selectedNote === n.id ? 'bg-zinc-800 text-white' : 'hover:bg-zinc-900 text-zinc-400'
                        }`}
                      >
                        <div className="flex items-center justify-between text-xs font-bold text-zinc-200 mb-0.5">
                          <span>{n.title}</span>
                          <span className="text-[10px] text-zinc-500 font-mono">{n.time}</span>
                        </div>
                        <p className="text-[11px] text-zinc-500 truncate">{n.preview}</p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Right Detail Note Area */}
              <div className="md:col-span-8 p-6 flex flex-col justify-between bg-zinc-950">
                <div>
                  {/* Note Header */}
                  <div className="flex items-center justify-between border-b border-zinc-800 pb-3 mb-4">
                    <div>
                      <h4 className="text-lg font-bold text-zinc-100">
                        {selectedNote === 'sprint' ? 'Sprint Architecture Sync' : 'Founder Check-in'}
                      </h4>
                      <div className="flex items-center gap-3 text-xs text-zinc-500 mt-1 font-mono">
                        <span>Edited Today</span>
                        <span>•</span>
                        <span>Words 184</span>
                        <span className="px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-300 text-[10px]">
                          🎙️ dictated
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 text-zinc-400">
                      <button className="p-1.5 hover:text-white"><Copy size={15} /></button>
                      <button className="p-1.5 hover:text-white"><Share2 size={15} /></button>
                      <button className="p-1.5 hover:text-rose-400"><Trash2 size={15} /></button>
                    </div>
                  </div>

                  {/* Transcript Content */}
                  <div className="space-y-3 text-xs sm:text-sm text-zinc-300 leading-relaxed font-sans">
                    <p>
                      <strong className="text-indigo-400 font-mono">[00:02 Alex - Local]:</strong> We hooked whisper.cpp directly into AVAudioEngine's tap buffer. CoreAudio is streaming 16kHz mono Float32 directly into unified memory.
                    </p>
                    <p>
                      <strong className="text-emerald-400 font-mono">[00:15 Sarah - Remote]:</strong> Confirmed. The process tap for Zoom captures incoming speaker audio cleanly without generating temporary WAV files.
                    </p>
                    {aiTransform && (
                      <div className="p-3.5 rounded-xl bg-purple-950/40 border border-purple-800/60 text-purple-200 mt-3 text-xs">
                        <span className="font-bold block mb-1">✨ Apple Intelligence Result:</span>
                        {aiTransform}
                      </div>
                    )}
                  </div>
                </div>

                {/* Bottom Action Strip (1:1 from 04_notes_studio.png) */}
                <div className="pt-4 border-t border-zinc-800">
                  <div className="flex items-center gap-1 text-[11px] text-zinc-400 font-semibold mb-2">
                    <Sparkles size={13} className="text-purple-400" />
                    <span>Apple Intelligence Actions</span>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <button
                      onClick={() => setAiTransform('• CoreAudio process tap active • whisper.cpp streaming in RAM • Latency sub-200ms')}
                      className="px-3 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-medium transition-colors flex items-center gap-1.5"
                    >
                      <FileText size={12} className="text-purple-400" />
                      Summarise
                    </button>
                    <button
                      onClick={() => setAiTransform('Action Items: 1. Deploy v1.1.56 DMG 2. Verify zero network sockets with lsof -i')}
                      className="px-3 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-medium transition-colors flex items-center gap-1.5"
                    >
                      <CheckSquare size={12} className="text-purple-400" />
                      Find action items
                    </button>
                    <button
                      onClick={() => setAiTransform('Cleaned grammar and punctuation across all 184 words with on-device LLM.')}
                      className="px-3 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-medium transition-colors flex items-center gap-1.5"
                    >
                      <Wand2 size={12} className="text-purple-400" />
                      Clean up
                    </button>
                    <button
                      onClick={() => setAiTransform('Formatted as structured Markdown engineering brief.')}
                      className="px-3 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200 text-xs font-medium transition-colors flex items-center gap-1.5"
                    >
                      <AlignLeft size={12} className="text-purple-400" />
                      Format as document
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}

        {/* ============================================================== */}
        {/* TAB 4: ARTICULATED DESKTOP PETS (1:1 with 05b_companion)       */}
        {/* ============================================================== */}
        {activeTab === 'companions' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="rounded-2xl bg-zinc-950 text-white p-6 sm:p-8 border border-zinc-800 text-center"
          >
            {/* Title from app screenshot */}
            <div className="mb-8">
              <span className="text-xs font-mono text-zinc-500 uppercase tracking-widest block mb-1">
                Utter — Articulated Quadruped Desktop Pets
              </span>
              <h3 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                4-Limb Articulated Vector Companions
              </h3>
              <p className="text-xs sm:text-sm text-zinc-400 max-w-xl mx-auto mt-1">
                Quadruped walk cycles, biscuit kneading, thinking chin-scratches & celebration poses rendered at 60 FPS
              </p>
            </div>

            {/* 3 Real App Pet Cards (1:1 from 05b_companion_customize.png) */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
              {/* Pet 1: Tabby Gray Cat */}
              <div
                onClick={() => setSelectedCompanion('cat')}
                className={`p-6 rounded-3xl cursor-pointer transition-all border text-center ${
                  selectedCompanion === 'cat'
                    ? 'bg-zinc-900 border-indigo-500/80 ring-2 ring-indigo-500/30 shadow-xl'
                    : 'bg-zinc-900/50 hover:bg-zinc-900/80 border-zinc-800'
                }`}
              >
                <div className="w-24 h-24 rounded-full bg-zinc-800 border border-zinc-700 flex items-center justify-center text-5xl mx-auto mb-4 shadow-inner">
                  🐱
                </div>
                <h4 className="font-bold text-sm text-white mb-1">Pixel Cat (Tabby Gray)</h4>
                <p className="text-xs text-zinc-400 mb-4">Walking & Kneading Biscuits</p>
                <span className="inline-block text-[10px] font-bold px-3 py-1 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30">
                  4-LEG GAIT
                </span>
              </div>

              {/* Pet 2: Corgi Dog */}
              <div
                onClick={() => setSelectedCompanion('corgi')}
                className={`p-6 rounded-3xl cursor-pointer transition-all border text-center ${
                  selectedCompanion === 'corgi'
                    ? 'bg-zinc-900 border-indigo-500/80 ring-2 ring-indigo-500/30 shadow-xl'
                    : 'bg-zinc-900/50 hover:bg-zinc-900/80 border-zinc-800'
                }`}
              >
                <div className="w-24 h-24 rounded-full bg-zinc-800 border border-zinc-700 flex items-center justify-center text-5xl mx-auto mb-4 shadow-inner">
                  🐶
                </div>
                <h4 className="font-bold text-sm text-white mb-1">Pixel Dog (Corgi)</h4>
                <p className="text-xs text-zinc-400 mb-4">Joyful 4-Leg Gallop & Wag</p>
                <span className="inline-block text-[10px] font-bold px-3 py-1 rounded-full bg-orange-500/20 text-orange-300 border border-orange-500/30">
                  SINUSOIDAL SWAY
                </span>
              </div>

              {/* Pet 3: Panda Cub */}
              <div
                onClick={() => setSelectedCompanion('panda')}
                className={`p-6 rounded-3xl cursor-pointer transition-all border text-center ${
                  selectedCompanion === 'panda'
                    ? 'bg-zinc-900 border-indigo-500/80 ring-2 ring-indigo-500/30 shadow-xl'
                    : 'bg-zinc-900/50 hover:bg-zinc-900/80 border-zinc-800'
                }`}
              >
                <div className="w-24 h-24 rounded-full bg-zinc-800 border border-zinc-700 flex items-center justify-center text-5xl mx-auto mb-4 shadow-inner">
                  🐼
                </div>
                <h4 className="font-bold text-sm text-white mb-1">Pixel Panda (Cub)</h4>
                <p className="text-xs text-zinc-400 mb-4">Thinking Chin-Scratch Tap</p>
                <span className="inline-block text-[10px] font-bold px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                  ARTICULATED ARMS
                </span>
              </div>
            </div>

            <div className="mt-8 inline-flex items-center gap-2 text-xs font-mono text-zinc-400 bg-zinc-900 px-4 py-2 rounded-full border border-zinc-800">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              Active Companion: <strong className="text-white capitalize">{selectedCompanion}</strong> rendered via Metal 60 FPS Sprite Engine
            </div>
          </motion.div>
        )}

        {/* ============================================================== */}
        {/* TAB 5: DIAGNOSTICS & TELEMETRY (1:1 with media_1788437052456)  */}
        {/* ============================================================== */}
        {activeTab === 'diagnostics' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="rounded-2xl bg-zinc-950 text-white p-6 border border-zinc-800 max-w-4xl mx-auto text-left"
          >
            {/* Header matching user's uploaded modal */}
            <div className="flex items-center justify-between border-b border-zinc-800 pb-4 mb-5">
              <div>
                <h4 className="text-base font-bold text-white">Report an Issue / Send Feedback</h4>
                <p className="text-xs text-zinc-400 mt-0.5">Utter is a native macOS app. Zero data leaves your device.</p>
              </div>
              <span className="px-2.5 py-1 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-[10px] font-mono font-bold">
                SANITIZED • ZERO TELEMETRY
              </span>
            </div>

            {/* Category Pills */}
            <div className="mb-4">
              <span className="text-xs text-zinc-400 font-semibold block mb-2">Category</span>
              <div className="flex flex-wrap gap-2">
                {['🪲 Bug / Crash', '🎙️ Audio / Mic', '⚡ Performance', '💡 Feature Idea'].map((cat, idx) => (
                  <button key={idx} className={`px-3 py-1 rounded-lg text-xs font-semibold border ${idx === 2 ? 'bg-indigo-600 text-white border-indigo-500' : 'bg-zinc-900 text-zinc-300 border-zinc-800'}`}>
                    {cat}
                  </button>
                ))}
              </div>
            </div>

            {/* Diagnostics Dump (1:1 matching user screenshot media_1788437052456.png) */}
            <div className="rounded-xl bg-zinc-900/90 border border-zinc-800 p-4 font-mono text-xs text-zinc-300 space-y-1.5 leading-relaxed">
              <div className="text-emerald-400 font-bold mb-2">### Auto-Collected System Diagnostics</div>
              <div>- **Utter Version**: 1.1.56 (Build 26A5425a)</div>
              <div>- **macOS Version**: macOS 15.0 Sequoia</div>
              <div>- **Architecture**: Apple Silicon Unified Memory (Metal Acceleration)</div>
              <div>- **Active Speech Model**: {currentModel.name}</div>
              <div>- **Configured Hotkey**: Fn (Push-To-Talk)</div>
              <div>- **Local-Only Guarantee**: 100% on-device (Zero cloud endpoints)</div>
              <div>- **Active Network Sockets**: 0 open sockets</div>
            </div>
          </motion.div>
        )}
      </div>
    </div>
  );
}
