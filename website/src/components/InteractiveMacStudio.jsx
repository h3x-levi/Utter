import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, CheckCircle2, Download, HardDrive, Zap, Cpu, Play, Pause, Sparkles, Heart, Trophy, ShieldCheck, Check } from 'lucide-react';

export default function InteractiveMacStudio() {
  const [activeTab, setActiveTab] = useState('models'); // default to user's favorite models screen
  const [selectedModel, setSelectedModel] = useState('small');
  const [isDictating, setIsDictating] = useState(true);
  const [typedCode, setTypedCode] = useState('');
  const [friendship, setFriendship] = useState(5);
  const [petMood, setPetMood] = useState('Delighted');
  const [petBubble, setPetBubble] = useState('Meow! Sub-200ms latency!');
  const [meetingPlaying, setMeetingPlaying] = useState(false);

  // Live code typing effect for dictation tab
  const sampleCode = `// Dictated via Utter with sub-200ms latency\nfunc transcribeAudio(buffer: AVAudioPCMBuffer) async throws -> String {\n    let tokens = try await LocalWhisperProvider.shared.process(buffer)\n    return tokens.joined(separator: " ")\n}`;

  useEffect(() => {
    if (activeTab !== 'dictation') return;
    let i = 0;
    setTypedCode('');
    const t = setInterval(() => {
      if (i < sampleCode.length) {
        setTypedCode(sampleCode.slice(0, i + 1));
        i++;
      } else {
        clearInterval(t);
      }
    }, 24);
    return () => clearInterval(t);
  }, [activeTab, isDictating]);

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
    <div id="demo" className="w-full max-w-4xl mx-auto card-opaque shadow-2xl overflow-hidden border border-black/10">
      {/* macOS Window Titlebar with Segmented Tab Switcher */}
      <div className="bg-zinc-100/90 border-b border-black/[0.08] px-4 py-3 flex flex-wrap items-center justify-between gap-3">
        {/* Traffic Lights */}
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-full bg-[#ff5f56] border border-black/10" />
          <div className="w-3 h-3 rounded-full bg-[#ffbd2e] border border-black/10" />
          <div className="w-3 h-3 rounded-full bg-[#27c93f] border border-black/10" />
          <span className="text-xs font-semibold text-zinc-700 ml-2 hidden sm:inline">
            Utter macOS Studio
          </span>
        </div>

        {/* Tab Controls */}
        <div className="flex items-center gap-1 bg-zinc-200/80 p-1 rounded-xl">
          {[
            { id: 'models', label: 'Whisper Models', icon: '🧠' },
            { id: 'dictation', label: 'Live HUD', icon: '🎙️' },
            { id: 'meetings', label: 'Meeting Audio', icon: '👥' },
            { id: 'companion', label: 'Pixel Pet', icon: '🐱' },
            { id: 'privacy', label: 'Zero-Cloud Audit', icon: '🛡️' },
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
              <span className="hidden sm:inline">{tab.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Interactive Tab Body */}
      <div className="p-6 sm:p-8 bg-white min-h-[420px]">
        {/* ============================== */}
        {/* TAB 1: WHISPER SPEECH MODELS   */}
        {/* ============================== */}
        {activeTab === 'models' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
          >
            <div className="flex items-center justify-between mb-4">
              <div>
                <h3 className="text-xl font-bold text-zinc-900">Speech Models</h3>
                <p className="text-xs text-zinc-500">100% offline inference on Apple Silicon Unified Memory</p>
              </div>
              <span className="text-xs font-mono font-medium px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                Active: {currentModel.name}
              </span>
            </div>

            {/* Exact replica of the user's macOS app screenshot */}
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

        {/* ============================== */}
        {/* TAB 2: LIVE DICTATION HUD      */}
        {/* ============================== */}
        {activeTab === 'dictation' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="space-y-4"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xl font-bold text-zinc-900">Push-To-Talk Dictation HUD</h3>
                <p className="text-xs text-zinc-500">Hold Fn anywhere in macOS. Text injects at active cursor.</p>
              </div>
              <button
                onClick={() => setIsDictating(!isDictating)}
                className="px-3 py-1 rounded-full bg-indigo-50 text-indigo-600 hover:bg-indigo-100 text-xs font-semibold transition-colors border border-indigo-200"
              >
                Replay Dictation
              </button>
            </div>

            {/* Simulated Editor */}
            <div className="rounded-2xl bg-zinc-900 text-zinc-100 p-5 font-mono text-xs leading-relaxed min-h-[190px] shadow-inner relative overflow-hidden">
              <div className="flex items-center justify-between border-b border-zinc-800 pb-2 mb-3 text-zinc-400 text-[11px]">
                <span>TranscriptionService.swift — Xcode / Cursor</span>
                <span className="text-emerald-400 font-mono">180 WPM</span>
              </div>
              <pre className="whitespace-pre-wrap text-emerald-300">{typedCode}</pre>
              <span className="inline-block w-2 h-4 bg-white animate-pulse ml-0.5 align-middle" />
            </div>

            {/* Floating Liquid Glass Pill */}
            <div className="p-3.5 rounded-2xl bg-zinc-50 border border-zinc-200 flex items-center justify-between shadow-sm">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-indigo-600 text-white flex items-center justify-center shadow-md">
                  <Mic size={16} className="animate-pulse" />
                </div>
                <div>
                  <div className="text-xs font-bold text-zinc-900">Listening (Fn Pressed)</div>
                  <div className="text-[11px] text-zinc-500 font-mono">168ms Latency · whisper.cpp Metal</div>
                </div>
              </div>

              {/* Spectrum Bars */}
              <div className="flex items-center gap-1 h-6">
                {[40, 80, 100, 60, 90, 75, 40, 85, 65, 95].map((h, i) => (
                  <motion.div
                    key={i}
                    animate={{ height: [`${h * 0.3}%`, `${h}%`, `${h * 0.3}%`] }}
                    transition={{ duration: 0.3 + (i % 4) * 0.08, repeat: Infinity, ease: 'easeInOut' }}
                    className="w-1 bg-indigo-600 rounded-full"
                  />
                ))}
              </div>

              <span className="text-[11px] font-mono font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">
                0% CLOUD
              </span>
            </div>
          </motion.div>
        )}

        {/* ============================== */}
        {/* TAB 3: MEETING DIARIZATION     */}
        {/* ============================== */}
        {activeTab === 'meetings' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="space-y-4"
          >
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-xl font-bold text-zinc-900">Dual-Channel Meeting Capture</h3>
                <p className="text-xs text-zinc-500">CoreAudio system output tap + microphone separated automatically</p>
              </div>
              <button
                onClick={() => setMeetingPlaying(!meetingPlaying)}
                className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-zinc-900 text-white text-xs font-semibold hover:bg-black transition-colors"
              >
                {meetingPlaying ? <Pause size={12} /> : <Play size={12} />}
                <span>{meetingPlaying ? 'Pause Audio' : 'Play Meeting'}</span>
              </button>
            </div>

            <div className="space-y-3">
              {[
                { time: '10:02 AM', speaker: 'You (Microphone)', color: 'bg-indigo-50 text-indigo-700 border-indigo-200', text: 'All Whisper neural weights run in unified RAM. Latency is sub-200ms across M1 through M4.' },
                { time: '10:03 AM', speaker: 'Sarah (Zoom System Audio)', color: 'bg-emerald-50 text-emerald-700 border-emerald-200', text: 'Confirmed. Zero packet loss, and zero temporary audio files are written to disk.' },
              ].map((t, idx) => (
                <div key={idx} className="p-4 rounded-xl bg-zinc-50 border border-zinc-200">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full border ${t.color}`}>
                      {t.speaker}
                    </span>
                    <span className="text-[11px] font-mono text-zinc-400">{t.time}</span>
                  </div>
                  <p className="text-xs sm:text-sm text-zinc-700 leading-relaxed">{t.text}</p>
                </div>
              ))}
            </div>

            <div className="p-3.5 rounded-xl bg-indigo-50/70 border border-indigo-200 flex items-center justify-between">
              <span className="flex items-center gap-2 text-xs font-bold text-indigo-900">
                <Sparkles size={14} className="text-indigo-600" />
                Apple Intelligence Action Items
              </span>
              <span className="text-xs text-indigo-700 font-medium">Export 1-Click Markdown to Obsidian</span>
            </div>
          </motion.div>
        )}

        {/* ============================== */}
        {/* TAB 4: PIXEL COMPANION         */}
        {/* ============================== */}
        {activeTab === 'companion' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="flex flex-col items-center text-center space-y-4"
          >
            <div>
              <h3 className="text-xl font-bold text-zinc-900">Desktop Coding Companions</h3>
              <p className="text-xs text-zinc-500">Retro pixel pets that react to voice amplitude and typing cadence</p>
            </div>

            {/* Speech bubble */}
            <div className="px-4 py-2 rounded-2xl bg-zinc-100 border border-zinc-200 text-zinc-800 text-xs font-semibold shadow-sm">
              {petBubble}
            </div>

            {/* Animated Cat */}
            <motion.div
              animate={{ y: [0, -6, 0] }}
              transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
              className="w-24 h-24 rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-center text-5xl shadow-sm select-none"
            >
              {petMood === 'Delighted' ? '😺' : petMood === 'Playful' ? '😸' : petMood === 'Snack' ? '😻' : '🐾'}
            </motion.div>

            {/* Friendship level */}
            <div className="inline-flex items-center gap-1.5 text-xs font-semibold text-amber-800 bg-amber-100/70 px-3 py-1 rounded-full border border-amber-200">
              <Trophy size={13} />
              Friendship Level {friendship}/10
            </div>

            {/* Toolbar */}
            <div className="flex flex-wrap items-center justify-center gap-2 pt-2">
              <button
                onClick={() => { setPetMood('Playful'); setPetBubble('Playing with yarn! 🧶'); setFriendship(f => Math.min(f + 1, 10)); }}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-zinc-100 hover:bg-zinc-200 text-zinc-800 transition-colors border border-zinc-200"
              >
                🧶 Toss Yarn
              </button>
              <button
                onClick={() => { setPetMood('Snack'); setPetBubble('Yum! Fresh fish! 🐟'); setFriendship(f => Math.min(f + 1, 10)); }}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-zinc-100 hover:bg-zinc-200 text-zinc-800 transition-colors border border-zinc-200"
              >
                🐟 Feed Snack
              </button>
              <button
                onClick={() => { setPetMood('Delighted'); setPetBubble('*purrrrrrrrrr* ❤️'); setFriendship(f => Math.min(f + 1, 10)); }}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold bg-zinc-100 hover:bg-zinc-200 text-zinc-800 transition-colors border border-zinc-200 flex items-center gap-1"
              >
                <Heart size={13} className="text-rose-500" />
                Pet Head
              </button>
            </div>
          </motion.div>
        )}

        {/* ============================== */}
        {/* TAB 5: ZERO-CLOUD SECURITY     */}
        {/* ============================== */}
        {activeTab === 'privacy' && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="space-y-4 text-left"
          >
            <div>
              <h3 className="text-xl font-bold text-zinc-900">Air-Gapped Security Verification</h3>
              <p className="text-xs text-zinc-500">Audit Utter directly from your macOS terminal</p>
            </div>

            <div className="rounded-2xl bg-zinc-900 text-zinc-100 p-5 font-mono text-xs leading-relaxed space-y-3 shadow-inner">
              <div>
                <p className="text-zinc-500"># 1. Audit active network sockets</p>
                <p className="text-emerald-400">$ lsof -i -P | grep -i utter</p>
                <p className="text-zinc-500 italic"># Result: 0 sockets open (Exit 1 - air-gapped)</p>
              </div>

              <div>
                <p className="text-zinc-500"># 2. Binary string inspection for telemetry</p>
                <p className="text-emerald-400">$ strings /Applications/Utter.app/Contents/MacOS/Utter | grep -Ei "analytics|telemetry|sentry"</p>
                <p className="text-zinc-500 italic"># Result: 0 matches found</p>
              </div>
            </div>

            <div className="p-3.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-semibold flex items-center gap-2">
              <ShieldCheck size={16} className="text-emerald-600" />
              <span>Verified: Zero network entitlements in sandbox profile. 100% private.</span>
            </div>
          </motion.div>
        )}
      </div>
    </div>
  );
}
