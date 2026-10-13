import React, { useState, useEffect } from 'react';
import { Download, Play, Shield, Terminal, Volume2, ArrowRight, Check, Moon, Sun, Lock } from 'lucide-react';

export default function App() {
  const [isDark, setIsDark] = useState(false);
  const [pillState, setPillState] = useState('idle'); // idle | listening | thinking | typed
  const [injectedText, setInjectedText] = useState('Hold a key, say it, let go...');
  const [isSimulating, setIsSimulating] = useState(false);

  // Sync theme with document element
  useEffect(() => {
    const savedTheme = localStorage.getItem('utter_theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    if (savedTheme === 'dark' || (!savedTheme && prefersDark)) {
      setIsDark(true);
      document.documentElement.classList.add('dark');
    } else {
      setIsDark(false);
      document.documentElement.classList.remove('dark');
    }
  }, []);

  const toggleTheme = () => {
    if (isDark) {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('utter_theme', 'light');
      setIsDark(false);
    } else {
      document.documentElement.classList.add('dark');
      localStorage.setItem('utter_theme', 'dark');
      setIsDark(true);
    }
  };

  const setPillMode = (mode) => {
    setPillState(mode);
    if (mode === 'idle') {
      setInjectedText('Hold a key, say it, let go...');
    } else if (mode === 'listening') {
      setInjectedText('Listening to microphone...');
    } else if (mode === 'thinking') {
      setInjectedText('whisper.cpp transcribing on Metal GPU...');
    } else if (mode === 'typed') {
      setInjectedText('Voice dictation for the Mac that never leaves the Mac.');
    }
  };

  const cyclePill = () => {
    const sequence = ['idle', 'listening', 'thinking', 'typed'];
    const nextIdx = (sequence.indexOf(pillState) + 1) % sequence.length;
    setPillMode(sequence[nextIdx]);
  };

  const runSimulation = () => {
    if (isSimulating) return;
    setIsSimulating(true);
    setPillMode('listening');

    setTimeout(() => {
      setPillMode('thinking');
      setTimeout(() => {
        setPillMode('typed');
        setIsSimulating(false);
        setTimeout(() => {
          setPillMode('idle');
        }, 4000);
      }, 1200);
    }, 2000);
  };

  return (
    <div className="min-h-screen ruled-lines bg-[#F7F9FC] dark:bg-[#0E1118] text-[#141E3C] dark:text-[#F2F5FC] transition-colors duration-300">
      
      {/* Sticky Navigation */}
      <header className="sticky top-0 z-50 backdrop-blur-xl bg-[#F7F9FC]/90 dark:bg-[#0E1118]/90 border-b border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] transition-colors">
        <div className="max-w-[1520px] mx-auto px-6 sm:px-12 py-4 flex items-center justify-between">
          <a href="#" className="flex items-center gap-3.5 no-underline text-inherit group">
            <img 
              src="/assets/brand/AppIconSource.png" 
              alt="Utter Icon" 
              className="w-9 h-9 rounded-xl shadow-md transition-transform group-hover:scale-105"
            />
            <span className="font-extrabold text-2xl tracking-tight font-display">Utter</span>
            <div className="flex h-4 gap-0.5 ml-1">
              <span className="w-1 h-full rounded-sm bg-[#D83125]"></span>
              <span className="w-1 h-full rounded-sm bg-[#EDB123]"></span>
              <span className="w-1 h-full rounded-sm bg-[#254EDB]"></span>
            </div>
          </a>

          <nav className="hidden md:flex items-center gap-8 text-[0.95rem] font-medium text-[#4B587E] dark:text-[#A3AFCC]">
            <a href="#how-it-works" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">How It Works</a>
            <a href="#promo-video" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Promo Reel</a>
            <a href="#library" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Mixtape Library</a>
            <a href="#engines" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Speech Engines</a>
            <a href="#privacy" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Privacy</a>
            <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">GitHub</a>
          </nav>

          <div className="flex items-center gap-3.5">
            <button
              onClick={toggleTheme}
              aria-label="Toggle theme"
              className="px-3.5 py-2 rounded-lg border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-[#EDF1F7] dark:bg-[#151924] text-xs font-mono flex items-center gap-2 hover:border-[#254EDB] transition-all"
            >
              {isDark ? <Sun className="w-3.5 h-3.5 text-[#EDB123]" /> : <Moon className="w-3.5 h-3.5 text-[#254EDB]" />}
              <span>{isDark ? 'Light' : 'Dark'}</span>
            </button>

            <a
              href="https://github.com/h3x-levi/Utter/releases/download/v1.2.0/Utter-1.2.0.dmg"
              className="bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118] px-4 sm:px-5 py-2 sm:py-2.5 rounded-lg text-sm font-bold flex items-center gap-2 shadow-sm hover:bg-[#254EDB] dark:hover:bg-[#E2E8F0] transition-all hover:-translate-y-0.5"
            >
              <Download className="w-4 h-4" />
              <span>Download .dmg</span>
            </a>
          </div>
        </div>
      </header>

      <main>
        {/* Wide Panoramic Hero Section (2-Column Grid) */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 py-16 sm:py-20">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
            
            {/* Left Column: Bold Typography & Narrative */}
            <div className="lg:col-span-6 flex flex-col items-start">
              <div className="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-xs font-mono text-[#4B587E] dark:text-[#A3AFCC] mb-6 shadow-sm">
                <span className="w-2 h-2 rounded-full bg-[#D83125] shadow-[0_0_8px_#D83125]"></span>
                <span>ON-DEVICE SPEECH · ZERO TELEMETRY · APACHE 2.0</span>
              </div>

              <h1 className="text-4xl sm:text-5xl lg:text-[3.9rem] font-extrabold tracking-tight leading-[1.08] mb-6 font-display">
                Voice dictation for the Mac that <span className="text-[#D83125]">never leaves the Mac</span>.
              </h1>

              <p className="text-lg sm:text-xl text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed mb-8 max-w-[620px]">
                Hold a key, say it, let go. Your words appear wherever the cursor is.<br />
                The speech model runs in-process on Apple silicon — offline, with no account, no subscription, and zero cloud delay.
              </p>

              <div className="flex flex-wrap items-center gap-4 mb-8">
                <a
                  href="https://github.com/h3x-levi/Utter/releases/download/v1.2.0/Utter-1.2.0.dmg"
                  className="bg-[#D83125] hover:bg-[#c2281d] text-white px-7 py-3.5 rounded-xl text-base font-bold flex items-center gap-2.5 shadow-[0_8px_24px_rgba(216,49,37,0.28)] hover:shadow-[0_12px_28px_rgba(216,49,37,0.36)] transition-all hover:-translate-y-0.5"
                >
                  <Download className="w-5 h-5" />
                  <span>Download Utter 1.2.0 (.dmg)</span>
                </a>

                <a
                  href="#promo-video"
                  className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] hover:border-[#254EDB] text-[#141E3C] dark:text-white px-6 py-3.5 rounded-xl text-base font-semibold flex items-center gap-2.5 transition-all"
                >
                  <Play className="w-4 h-4 fill-current text-[#254EDB]" />
                  <span>Watch 16:9 Promo Reel</span>
                </a>
              </div>

              <div className="flex items-center gap-3 text-xs font-mono text-[#6C789B] dark:text-[#7A87A6]">
                <span>macOS 14+</span>
                <span>•</span>
                <span>Apple silicon & Intel</span>
                <span>•</span>
                <span>192 MB (Model Included)</span>
              </div>
            </div>

            {/* Right Column: Authentic Interactive Pill Simulator */}
            <div className="lg:col-span-6 bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-6 sm:p-8 shadow-[0_20px_50px_rgba(20,30,60,0.06)]" id="how-it-works">
              <div className="flex items-center justify-between border-b border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.1)] pb-4 mb-6 text-xs font-mono text-[#6C789B]">
                <div className="flex items-center gap-2.5">
                  <span className="bg-[#D83125] text-white font-extrabold text-[0.7rem] px-2 py-0.5 rounded tracking-wider">REC</span>
                  <strong className="text-[#141E3C] dark:text-white">LIVE PILL SIMULATOR</strong>
                </div>
                <span>Click pill or hold Fn below</span>
              </div>

              {/* The Interactive Board */}
              <div className="min-h-[240px] bg-[#EDF1F7] dark:bg-[#151924] border border-dashed border-[rgba(37,78,219,0.2)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl flex flex-col items-center justify-center p-6 text-center">
                
                {/* Authentic Pill HUD: Strictly no text inside the pill! */}
                <div
                  onClick={cyclePill}
                  title="Click to cycle states"
                  className={`inline-flex items-center justify-center rounded-full shadow-2xl cursor-pointer select-none transition-all duration-300 ${
                    pillState === 'idle'
                      ? 'w-12 h-2.5 bg-gradient-to-r from-[#D83125] via-[#EDB123] to-[#254EDB]'
                      : pillState === 'listening'
                      ? 'w-[90px] h-[30px] bg-[#D83125] shadow-[0_0_24px_rgba(216,49,37,0.4)]'
                      : pillState === 'thinking'
                      ? 'w-[68px] h-[28px] bg-[#1C2A5E]'
                      : 'w-[54px] h-[28px] bg-[#1C2A5E]'
                  }`}
                >
                  {/* Waveform bars for listening */}
                  {pillState === 'listening' && (
                    <div className="flex items-center gap-1 h-4">
                      <span className="w-1 bg-white rounded-sm animate-sound-1"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-2"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-3"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-4"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-5"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-6"></span>
                      <span className="w-1 bg-white rounded-sm animate-sound-7"></span>
                    </div>
                  )}

                  {/* Thinking waves */}
                  {pillState === 'thinking' && (
                    <div className="flex items-center gap-1 h-3">
                      <span className="w-1.5 h-1.5 bg-white/70 rounded-full animate-bounce"></span>
                      <span className="w-1.5 h-1.5 bg-white/70 rounded-full animate-bounce delay-100"></span>
                      <span className="w-1.5 h-1.5 bg-white/70 rounded-full animate-bounce delay-200"></span>
                    </div>
                  )}

                  {/* Typed checkmark */}
                  {pillState === 'typed' && (
                    <Check className="w-4 h-4 text-white stroke-[3]" />
                  )}
                </div>

                <div className="mt-3.5 text-xs font-mono text-[#6C789B] dark:text-[#7A87A6]">
                  {pillState === 'idle' && 'Pill status: At rest (32×6 pt stripe at screen bottom)'}
                  {pillState === 'listening' && 'Pill status: Listening (red capsule with live audio waveform bars)'}
                  {pillState === 'thinking' && 'Pill status: Thinking (whisper.cpp running on Metal GPU)'}
                  {pillState === 'typed' && 'Pill status: Typed (checkmark, text injected at cursor)'}
                </div>

                {/* Focused Application Window Simulator where text actually appears */}
                <div className="mt-5 w-full max-w-[480px] bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-xl p-3.5 text-left shadow-sm">
                  <div className="text-[0.72rem] font-mono text-[#6C789B] uppercase tracking-wider mb-1">
                    Focused Cursor (Notes.app / Slack / Xcode / Mail)
                  </div>
                  <div className="text-[1.02rem] text-[#141E3C] dark:text-white font-normal flex items-center">
                    <span>{injectedText}</span>
                    <span className="inline-block w-0.5 h-5 bg-[#254EDB] ml-1 blinking-caret"></span>
                  </div>
                </div>
              </div>

              {/* State Controls Toolbar */}
              <div className="flex flex-wrap items-center justify-center gap-2.5 mt-6">
                <button
                  onClick={runSimulation}
                  className={`px-4 py-2 rounded-lg font-mono text-xs font-semibold border flex items-center gap-2 transition-all ${
                    isSimulating 
                      ? 'bg-[#254EDB] text-white border-[#254EDB]'
                      : 'bg-[#E7ECF5] dark:bg-[#222736] border-[#CFD7E6] dark:border-[#333B50] text-[#141E3C] dark:text-white hover:border-[#254EDB]'
                  }`}
                >
                  <span>Hold</span> <strong>fn</strong>
                </button>
                <button onClick={() => setPillMode('idle')} className="px-3.5 py-2 rounded-lg font-mono text-xs bg-[#E7ECF5] dark:bg-[#222736] border border-[#CFD7E6] dark:border-[#333B50] hover:border-[#254EDB]">
                  Resting
                </button>
                <button onClick={() => setPillMode('listening')} className="px-3.5 py-2 rounded-lg font-mono text-xs bg-[#E7ECF5] dark:bg-[#222736] border border-[#CFD7E6] dark:border-[#333B50] hover:border-[#254EDB]">
                  Listening (Waveforms)
                </button>
                <button onClick={() => setPillMode('thinking')} className="px-3.5 py-2 rounded-lg font-mono text-xs bg-[#E7ECF5] dark:bg-[#222736] border border-[#CFD7E6] dark:border-[#333B50] hover:border-[#254EDB]">
                  Thinking (Metal)
                </button>
                <button onClick={() => setPillMode('typed')} className="px-3.5 py-2 rounded-lg font-mono text-xs bg-[#E7ECF5] dark:bg-[#222736] border border-[#CFD7E6] dark:border-[#333B50] hover:border-[#254EDB]">
                  Typed (Checkmark)
                </button>
              </div>
            </div>

          </div>
        </section>

        {/* Wide 16:9 Promo Video Showcase (Full Theater Deck) */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-24" id="promo-video">
          <div className="flex flex-wrap items-end justify-between gap-6 mb-8">
            <div>
              <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-1.5">HYPE REEL · 16:9 STEREO</div>
              <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight font-display">Watch Utter in 23 Seconds</h2>
            </div>
            <p className="text-base sm:text-lg text-[#4B587E] dark:text-[#A3AFCC] max-w-[540px]">
              Every cut locked to a 130 BPM analog beat grid. Experience the pill transformation, notes capture, and dual-stream meetings in action.
            </p>
          </div>

          <div className="bg-[#0F1219] rounded-3xl border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] overflow-hidden shadow-2xl">
            <video 
              controls 
              playsInline 
              preload="metadata"
              className="w-full h-auto aspect-video block"
            >
              <source src="/assets/promo/Utter-Hype-16x9.mp4" type="video/mp4" />
              Your browser does not support the video tag.
            </video>
            <div className="bg-[#141722] px-6 sm:px-8 py-4 flex flex-wrap items-center justify-between text-xs font-mono text-[#C8D3EC] border-t border-white/10 gap-3">
              <span className="text-[#D83125] font-bold">📼 promo/Utter-Hype-16x9.mp4 [1080p 16:9 Landscape]</span>
              <span>130 BPM AUDIO · SYNCHRONIZED METAL PIPELINE</span>
              <a href="/assets/promo/Utter-Hype-16x9.mp4" target="_blank" rel="noopener noreferrer" className="text-[#EDB123] hover:underline">
                Download Raw MP4 ↗
              </a>
            </div>
          </div>
        </section>

        {/* Unfolded Cassette J-Card Timeline (Side A & Side B Side-by-Side!) */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="library">
          <div className="text-center max-w-[850px] mx-auto mb-14">
            <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-2">CASSETTE J-CARD ARCHITECTURE</div>
            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight font-display mb-4">
              Every day is a tape. Side A and Side B.
            </h2>
            <p className="text-lg text-[#4B587E] dark:text-[#A3AFCC]">
              Morning dictations stay on Side A, afternoon meetings on Side B. Complete with running times and instant re-pasting at the cursor.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
            
            {/* Unfolded Tape Cards Side-by-Side */}
            <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-6">
              
              {/* Side A */}
              <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-6 shadow-sm">
                <div className="flex items-center justify-between border-b-2 border-[#D83125] pb-3 mb-5">
                  <span className="font-extrabold text-lg font-display text-[#141E3C] dark:text-white">SIDE A · MORNING</span>
                  <span className="text-xs font-mono text-[#6C789B]">18:24 MIN</span>
                </div>
                <ul className="space-y-3.5">
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">01</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"Release planning sync with the team"</b>
                      <span className="text-xs text-[#6C789B] font-mono">09:14 AM · Slack · 84 words</span>
                    </div>
                  </li>
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">02</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"Drafting API specification document"</b>
                      <span className="text-xs text-[#6C789B] font-mono">10:42 AM · Notes · 142 words</span>
                    </div>
                  </li>
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">03</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"Reviewing Swift Package dependencies"</b>
                      <span className="text-xs text-[#6C789B] font-mono">11:30 AM · Xcode · 62 words</span>
                    </div>
                  </li>
                </ul>
              </div>

              {/* Side B */}
              <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-6 shadow-sm">
                <div className="flex items-center justify-between border-b-2 border-[#D83125] pb-3 mb-5">
                  <span className="font-extrabold text-lg font-display text-[#141E3C] dark:text-white">SIDE B · AFTERNOON</span>
                  <span className="text-xs font-mono text-[#6C789B]">26:10 MIN</span>
                </div>
                <ul className="space-y-3.5">
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">04</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"Product design review with engineering"</b>
                      <span className="text-xs text-[#6C789B] font-mono">02:15 PM · Zoom Meeting · Dual-Stream</span>
                    </div>
                  </li>
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">05</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"Client reply regarding security verification"</b>
                      <span className="text-xs text-[#6C789B] font-mono">04:40 PM · Mail · 119 words</span>
                    </div>
                  </li>
                  <li className="flex items-start gap-3 p-2.5 rounded-lg bg-[#EDF1F7] dark:bg-[#151924]">
                    <span className="font-mono text-xs font-bold text-[#254EDB] bg-white dark:bg-[#1A1F2C] w-6 h-6 flex items-center justify-center rounded border border-[rgba(37,78,219,0.16)] shrink-0">06</span>
                    <div>
                      <b className="block text-sm text-[#141E3C] dark:text-white">"End of day recap notes"</b>
                      <span className="text-xs text-[#6C789B] font-mono">05:55 PM · Utter Note · 78 words</span>
                    </div>
                  </li>
                </ul>
              </div>

            </div>

            {/* Right: High-Res Real macOS Screenshot */}
            <div className="lg:col-span-5 bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-3 shadow-md">
              <img 
                src="/assets/screenshots/library.webp" 
                alt="Utter Mixtape Library Window"
                className="w-full h-auto rounded-2xl block"
              />
            </div>

          </div>
        </section>

        {/* 3 Speech Engines / Modalities */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="engines">
          <div className="text-center max-w-[800px] mx-auto mb-14">
            <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-2">LOCAL ENGINE CHOICES</div>
            <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight font-display mb-3">Two Speech Engines, Zero Cloud</h2>
            <p className="text-lg text-[#4B587E] dark:text-[#A3AFCC]">
              Switch anytime in Settings → Speech depending on whether you want maximum recognition accuracy or instantaneous typing speed.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-8 relative shadow-sm">
              <div className="absolute top-0 left-8 w-14 h-1 bg-[#D83125] rounded-b"></div>
              <h3 className="font-extrabold text-2xl font-display mt-2 mb-3 text-[#141E3C] dark:text-white">Accurate Engine</h3>
              <p className="text-[#4B587E] dark:text-[#A3AFCC] text-sm mb-6">whisper.cpp running quantized small.en with Apple Metal GPU acceleration.</p>
              <table className="w-full text-xs font-mono">
                <tbody>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Model</td><td className="text-right text-[#254EDB] font-bold">Whisper small.en (included)</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Disk footprint</td><td className="text-right text-[#254EDB] font-bold">190 MB</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Execution</td><td className="text-right text-[#254EDB] font-bold">Metal GPU / In-process</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Accuracy</td><td className="text-right text-[#254EDB] font-bold">Top punctuation & names</td></tr>
                </tbody>
              </table>
            </div>

            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-8 relative shadow-sm">
              <div className="absolute top-0 left-8 w-14 h-1 bg-[#EDB123] rounded-b"></div>
              <h3 className="font-extrabold text-2xl font-display mt-2 mb-3 text-[#141E3C] dark:text-white">Fast Engine (Whistle)</h3>
              <p className="text-[#4B587E] dark:text-[#A3AFCC] text-sm mb-6">Cactus Compute engine built for instantaneous execution on macOS 26.</p>
              <table className="w-full text-xs font-mono">
                <tbody>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Model</td><td className="text-right text-[#254EDB] font-bold">Whistle neural model</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Disk footprint</td><td className="text-right text-[#254EDB] font-bold">17 MB</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Latency</td><td className="text-right text-[#254EDB] font-bold">Sub-150ms instantaneous</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Target</td><td className="text-right text-[#254EDB] font-bold">Fast short dictations</td></tr>
                </tbody>
              </table>
            </div>

            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-8 relative shadow-sm">
              <div className="absolute top-0 left-8 w-14 h-1 bg-[#254EDB] rounded-b"></div>
              <h3 className="font-extrabold text-2xl font-display mt-2 mb-3 text-[#141E3C] dark:text-white">Apple Intelligence</h3>
              <p className="text-[#4B587E] dark:text-[#A3AFCC] text-sm mb-6">Voice transforms that rewrite, shorten, or reformat text locally.</p>
              <table className="w-full text-xs font-mono">
                <tbody>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Model</td><td className="text-right text-[#254EDB] font-bold">Apple Foundation Model</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Privacy</td><td className="text-right text-[#254EDB] font-bold">100% on-device execution</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Commands</td><td className="text-right text-[#254EDB] font-bold">'Make shorter', 'Fix punctuation'</td></tr>
                  <tr className="border-t border-[rgba(37,78,219,0.08)] dark:border-white/10"><td className="py-2.5">Cost</td><td className="text-right text-[#254EDB] font-bold">Free & built-in</td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        {/* Wide Privacy Vault Banner */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="privacy">
          <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-8 sm:p-14 shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-6">
              <div>
                <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-2">VERIFIED SECURITY</div>
                <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight font-display">Private by construction. Not by marketing.</h2>
              </div>
              <div className="font-mono text-sm text-[#254EDB] bg-[#EDF1F7] dark:bg-[#151924] px-5 py-2.5 rounded-lg border border-[rgba(37,78,219,0.16)]">
                0 open network sockets established
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8 mt-12">
              <div className="border-l-[3px] border-[#254EDB] pl-4">
                <h4 className="font-bold text-lg mb-2 font-display">No Accounts or Sign-In</h4>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">No email, no phone, no password. Launch and dictate in 5 seconds.</p>
              </div>
              <div className="border-l-[3px] border-[#254EDB] pl-4">
                <h4 className="font-bold text-lg mb-2 font-display">Zero Telemetry</h4>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">We do not track words spoken, features used, or analytics of any kind.</p>
              </div>
              <div className="border-l-[3px] border-[#254EDB] pl-4">
                <h4 className="font-bold text-lg mb-2 font-display">Audio Kept in RAM</h4>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Microphone PCM audio streams into temporary RAM buffers and is wiped after transcription.</p>
              </div>
              <div className="border-l-[3px] border-[#254EDB] pl-4">
                <h4 className="font-bold text-lg mb-2 font-display">Plain JSON Storage</h4>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">All notes live in ~/Library/Application Support/Utter. Delete the folder to remove everything.</p>
              </div>
            </div>
          </div>
        </section>

      </main>

      {/* Wide Footer */}
      <footer className="border-t border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] bg-[#EDF1F7] dark:bg-[#151924] py-16 px-6 sm:px-12 mt-32">
        <div className="max-w-[1520px] mx-auto flex flex-wrap items-center justify-between gap-6">
          <div className="text-sm text-[#6C789B] dark:text-[#7A87A6]">
            <strong className="text-[#141E3C] dark:text-white">Utter</strong> · Open Source Apache License 2.0 · Private on-device voice dictation for macOS
          </div>
          <div className="flex gap-6 font-mono text-sm text-[#4B587E] dark:text-[#A3AFCC]">
            <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">GitHub</a>
            <a href="https://github.com/h3x-levi/Utter/releases" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">Releases</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/PRIVACY.md" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">PRIVACY.md</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">LICENSE</a>
          </div>
        </div>
      </footer>

    </div>
  );
}
