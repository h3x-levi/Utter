import React, { useState, useEffect } from 'react';
import { Play, Shield, Terminal, Volume2, ArrowRight, Check, Moon, Sun, Lock, Send, CheckCircle2 } from 'lucide-react';

const GOOGLE_FORM_ENDPOINT = 'https://docs.google.com/forms/d/e/1FAIpQLSez9z3AlNInZ3pKbSrSr7BRswyTmoo4oxFle4ZZL4j_GBS4zQ/formResponse';

const SCREENSHOT_DATA = {
  library: {
    src: '/assets/screenshots/library.webp',
    label: 'Utter — Library (Cassette J-Card View)',
    title: 'The Daily Tape: Side A & Side B Tracklists',
    desc: 'Organizes every dictation into morning and afternoon tracks with running times, one-click re-paste, and instant copy.'
  },
  hub: {
    src: '/assets/screenshots/hub.webp',
    label: 'Utter — Menu Bar Hub Window',
    title: 'Menu Bar Hub: Instant Quick Access',
    desc: 'Lives discreetly in your menu bar. View live audio meters, access speech history, and adjust local offline models instantly.'
  },
  companion: {
    src: '/assets/screenshots/companion.webp',
    label: 'Utter — CX Robot Desktop Companion',
    title: 'Interactive Desktop Robot Companion',
    desc: 'Rendered with smooth Core Animation. Wakes up when you hold key, pulses while listening, and celebrates when typed.'
  },
  settings: {
    src: '/assets/screenshots/settings.webp',
    label: 'Utter — Preferences & Audio Tuning',
    title: 'Settings, Shortcuts & Model Tuning',
    desc: 'Choose push-to-talk keys (Fn, Right Option, Cmd), toggle system meeting audio, and manage offline model sizes.'
  },
  onboarding: {
    src: '/assets/screenshots/onboarding.webp',
    label: 'Utter — First Run Setup Guide',
    title: '60-Second Onboarding (No Accounts)',
    desc: 'Zero registration, zero password. Checks microphone accessibility and runs your first local transcription test in seconds.'
  }
};

export default function App() {
  const [isDark, setIsDark] = useState(false);
  const [pillState, setPillState] = useState('idle'); // idle | listening | thinking | typed
  const [injectedText, setInjectedText] = useState('Hold a key, say it, let go...');
  const [isSimulating, setIsSimulating] = useState(false);
  const [activeScreenshot, setActiveScreenshot] = useState('library');

  // Application Form State
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    os: 'macOS (Apple Silicon M1–M4)',
    useCases: ['Software Engineering & Terminal', 'Writing & Long-Form Docs'],
    reason: ''
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);

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
      setInjectedText('Hold your trigger key and speak naturally...');
    } else if (mode === 'listening') {
      setInjectedText('Speaking: "Ship the new on-device speech model to production"');
    } else if (mode === 'thinking') {
      setInjectedText('Local GPU computing whisper tokens in-process...');
    } else if (mode === 'typed') {
      setInjectedText('Ship the new on-device speech model to production.');
    }
  };

  const toggleUseCase = (useCase) => {
    setFormData(prev => {
      const exists = prev.useCases.includes(useCase);
      return {
        ...prev,
        useCases: exists ? prev.useCases.filter(u => u !== useCase) : [...prev.useCases, useCase]
      };
    });
  };

  const handleSubmitApplication = async (e) => {
    e.preventDefault();
    if (!formData.email || !formData.reason) return;
    setIsSubmitting(true);

    try {
      // Direct POST to Google Form (mode: no-cors)
      const formPayload = new FormData();
      formPayload.append('entry.691724603', formData.name);
      formPayload.append('entry.1036416450', formData.email);
      formPayload.append('entry.1633620309', formData.os);
      formData.useCases.forEach(uc => {
        formPayload.append('entry.606057482', uc);
      });
      formPayload.append('entry.991204098', formData.reason);
      formPayload.append('fvv', '1');
      formPayload.append('pageHistory', '0');

      await fetch(GOOGLE_FORM_ENDPOINT, {
        method: 'POST',
        mode: 'no-cors',
        body: formPayload
      });

      // Also persist backup in localStorage
      const submissions = JSON.parse(localStorage.getItem('utter_beta_applications') || '[]');
      submissions.push({ ...formData, submittedAt: new Date().toISOString() });
      localStorage.setItem('utter_beta_applications', JSON.stringify(submissions));

      setIsSubmitted(true);
    } catch (err) {
      console.error('Google Form submission error:', err);
      setIsSubmitted(true);
    } finally {
      setIsSubmitting(false);
    }
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
            <a href="#promo-video" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Promo Reel</a>
            <a href="#screenshots" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Screenshots</a>
            <a href="#library" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Mixtape Library</a>
            <a href="#privacy" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Privacy</a>
            <a href="#apply" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Apply for Beta</a>
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
              href="#apply"
              className="bg-[#D83125] hover:bg-[#c2281d] text-white px-4 sm:px-5 py-2 sm:py-2.5 rounded-lg text-sm font-bold flex items-center gap-2 shadow-sm transition-all hover:-translate-y-0.5"
            >
              <Send className="w-3.5 h-3.5" />
              <span>Apply for Beta</span>
            </a>
          </div>
        </div>
      </header>

      <main>
        {/* Wide Panoramic Hero Section: Pure Education First (No waitlist form in hero) */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 py-16 sm:py-20">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center">
            
            {/* Left Column: Bold Value Proposition */}
            <div className="lg:col-span-6 flex flex-col items-start">
              <div className="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-xs font-mono text-[#4B587E] dark:text-[#A3AFCC] mb-6 shadow-sm">
                <span className="w-2 h-2 rounded-full bg-[#D83125] shadow-[0_0_8px_#D83125]"></span>
                <span>CROSS-PLATFORM · ZERO TELEMETRY · 100% ON-DEVICE SPEECH</span>
              </div>

              <h1 className="text-4xl sm:text-5xl lg:text-[3.9rem] font-extrabold tracking-tight leading-[1.08] mb-6 font-display">
                Voice dictation that <span className="text-[#D83125]">never leaves your machine</span>.
              </h1>

              <p className="text-lg sm:text-xl text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed mb-8 max-w-[620px]">
                Hold a key, speak naturally, let go. Your words appear wherever the cursor is.<br />
                Powered by in-process Whisper with GPU acceleration — offline, no account, no subscription, and zero cloud delay.
              </p>

              <div className="flex flex-wrap items-center gap-4 mb-8">
                <a
                  href="#promo-video"
                  className="bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118] px-7 py-3.5 rounded-xl text-base font-bold flex items-center gap-2.5 shadow-md hover:bg-[#254EDB] dark:hover:bg-[#E2E8F0] transition-all hover:-translate-y-0.5"
                >
                  <Play className="w-4 h-4 fill-current" />
                  <span>Watch 16:9 Promo Reel</span>
                </a>

                <a
                  href="#apply"
                  className="bg-white dark:bg-[#1A1F2C] border-2 border-[#D83125] text-[#D83125] hover:bg-[#D83125] hover:text-white px-6 py-3.5 rounded-xl text-base font-bold flex items-center gap-2.5 transition-all hover:-translate-y-0.5"
                >
                  <span>Apply for Early Access</span>
                  <ArrowRight className="w-4 h-4" />
                </a>
              </div>

              {/* Platform Status Badges */}
              <div className="flex flex-wrap items-center gap-3 pt-4 border-t border-dashed border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] text-xs font-mono">
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-[#EDF1F7] dark:bg-[#151924] border border-[#10B981]/40">
                  <span className="w-2 h-2 rounded-full bg-[#10B981] shadow-[0_0_6px_#10B981]"></span>
                  <span><strong>macOS</strong> (Apple Silicon & Intel) · Ready</span>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-[#EDF1F7] dark:bg-[#151924] border border-[#EDB123]/40">
                  <span className="w-2 h-2 rounded-full bg-[#EDB123]"></span>
                  <span><strong>Windows 11</strong> · In Active Build</span>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-[#EDF1F7] dark:bg-[#151924] border border-[#EDB123]/40">
                  <span className="w-2 h-2 rounded-full bg-[#EDB123]"></span>
                  <span><strong>Linux</strong> · In Active Build</span>
                </div>
              </div>
            </div>

            {/* Right Column: Live Floating Pill HUD Simulator (Hardware Waveform, No Text Inside) */}
            <div className="lg:col-span-6">
              <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-7 sm:p-9 shadow-xl relative overflow-hidden">
                
                {/* Simulated Desktop Header */}
                <div className="flex items-center justify-between pb-5 mb-6 border-b border-dashed border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)]">
                  <div className="flex gap-2">
                    <span className="w-3 h-3 rounded-full bg-[#FF5F56]"></span>
                    <span className="w-3 h-3 rounded-full bg-[#FFBD2E]"></span>
                    <span className="w-3 h-3 rounded-full bg-[#27C93F]"></span>
                  </div>
                  <span className="font-mono text-xs text-[#6C789B] dark:text-[#7A87A6] font-semibold">
                    Floating Pill HUD · Live Feedback Simulator
                  </span>
                  <span className="font-mono text-[0.72rem] text-[#254EDB] dark:text-[#5E82FF] font-bold">
                    HARDWARE WAVEFORM
                  </span>
                </div>

                {/* State Controls */}
                <div className="flex bg-[#EDF1F7] dark:bg-[#151924] p-1 rounded-full mb-7 border border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.14)]">
                  <button
                    onClick={() => setPillMode('idle')}
                    className={`flex-1 py-1.5 px-3 rounded-full text-xs font-mono font-bold transition-all ${
                      pillState === 'idle'
                        ? 'bg-white dark:bg-[#1A1F2C] text-[#141E3C] dark:text-white shadow-sm'
                        : 'text-[#4B587E] dark:text-[#A3AFCC]'
                    }`}
                  >
                    1. Resting
                  </button>
                  <button
                    onClick={() => setPillMode('listening')}
                    className={`flex-1 py-1.5 px-3 rounded-full text-xs font-mono font-bold transition-all ${
                      pillState === 'listening'
                        ? 'bg-white dark:bg-[#1A1F2C] text-[#141E3C] dark:text-white shadow-sm'
                        : 'text-[#4B587E] dark:text-[#A3AFCC]'
                    }`}
                  >
                    2. Hold Key (Listen)
                  </button>
                  <button
                    onClick={() => setPillMode('thinking')}
                    className={`flex-1 py-1.5 px-3 rounded-full text-xs font-mono font-bold transition-all ${
                      pillState === 'thinking'
                        ? 'bg-white dark:bg-[#1A1F2C] text-[#141E3C] dark:text-white shadow-sm'
                        : 'text-[#4B587E] dark:text-[#A3AFCC]'
                    }`}
                  >
                    3. GPU Think
                  </button>
                  <button
                    onClick={() => setPillMode('typed')}
                    className={`flex-1 py-1.5 px-3 rounded-full text-xs font-mono font-bold transition-all ${
                      pillState === 'typed'
                        ? 'bg-white dark:bg-[#1A1F2C] text-[#141E3C] dark:text-white shadow-sm'
                        : 'text-[#4B587E] dark:text-[#A3AFCC]'
                    }`}
                  >
                    4. Typed
                  </button>
                </div>

                {/* THE PILL HUD (Strictly NO text inside) */}
                <div className="flex justify-center items-center min-h-[92px] mb-6 bg-gradient-to-b from-[rgba(37,78,219,0.03)] to-transparent rounded-2xl p-4">
                  <div
                    className={`h-[38px] rounded-full bg-[#0E121A] border border-white/20 shadow-[0_14px_34px_-8px_rgba(0,0,0,0.5),inset_0_1px_1px_0_rgba(255,255,255,0.22)] flex items-center justify-center transition-all duration-300 ${
                      pillState === 'idle'
                        ? 'w-[72px]'
                        : pillState === 'listening'
                        ? 'w-[148px] bg-[#180D0E] border-[#D83125]/50 shadow-[0_14px_34px_-8px_rgba(216,49,37,0.4),0_0_20px_rgba(216,49,37,0.25)]'
                        : pillState === 'thinking'
                        ? 'w-[110px] bg-[#0E1322] border-[#254EDB]/50 shadow-[0_14px_34px_-8px_rgba(37,78,219,0.4)]'
                        : 'w-[72px] bg-[#0E1815] border-[#27C93F]/50'
                    }`}
                  >
                    {pillState === 'idle' && (
                      <div className="w-8 h-1.5 rounded-full bg-gradient-to-r from-[#D83125] via-[#EDB123] to-[#254EDB]"></div>
                    )}

                    {pillState === 'listening' && (
                      <div className="flex items-center gap-1.5 h-6">
                        <span className="w-1 bg-white rounded-full animate-sound-1"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-2"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-3"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-4"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-5"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-6"></span>
                        <span className="w-1 bg-white rounded-full animate-sound-7"></span>
                      </div>
                    )}

                    {pillState === 'thinking' && (
                      <div className="flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-[#5E82FF] animate-ping"></span>
                        <span className="w-2 h-2 rounded-full bg-[#5E82FF] animate-pulse"></span>
                        <span className="w-2 h-2 rounded-full bg-[#5E82FF]"></span>
                      </div>
                    )}

                    {pillState === 'typed' && (
                      <span className="text-[#27C93F] font-black text-lg">✓</span>
                    )}
                  </div>
                </div>

                {/* THE ACTIVE FOCUSED CURSOR WINDOW (Text types HERE) */}
                <div className="bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-5 min-h-[120px] relative font-sans text-base leading-relaxed">
                  <span className="absolute -top-2.5 left-4 bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded px-2 py-0.5 font-mono text-[0.65rem] text-[#6C789B] uppercase tracking-wider">
                    Active Cursor Focus
                  </span>
                  <span className="text-[#141E3C] dark:text-white font-medium">
                    {injectedText}
                  </span>
                  <span className="blinking-caret inline-block w-[2.5px] h-[1.2em] bg-[#254EDB] align-text-bottom ml-0.5"></span>
                </div>

                <div className="flex items-center justify-between mt-5 text-xs font-mono text-[#6C789B] dark:text-[#7A87A6]">
                  <span>Trigger: <kbd className="px-2 py-1 rounded bg-[#EDF1F7] dark:bg-[#151924] border border-[#CFD7E6] dark:border-[#333B50] font-bold text-[#141E3C] dark:text-white">Fn</kbd> or <kbd className="px-2 py-1 rounded bg-[#EDF1F7] dark:bg-[#151924] border border-[#CFD7E6] dark:border-[#333B50] font-bold text-[#141E3C] dark:text-white">Right-Alt</kbd></span>
                  <span className="text-[#D83125] font-bold">Audio stays in RAM</span>
                </div>
              </div>
            </div>

          </div>
        </section>

        {/* 16:9 Promo Video Theatre Section */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-20" id="promo-video">
          <div className="bg-[#0E121A] border-2 border-white/10 rounded-3xl overflow-hidden shadow-2xl">
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
              <span>130 BPM AUDIO · SYNCHRONIZED GPU PIPELINE</span>
              <a href="#apply" className="text-[#EDB123] hover:underline font-bold">
                Apply for Beta Access Below ↓
              </a>
            </div>
          </div>
        </section>

        {/* Native App Screenshots Showcase Section */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="screenshots">
          <div className="text-center max-w-[850px] mx-auto mb-12">
            <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-2">NATIVE APP INTERFACES</div>
            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight font-display mb-4">
              Designed as if built into your OS.
            </h2>
            <p className="text-lg text-[#4B587E] dark:text-[#A3AFCC]">
              From the floating REC stripe to the cassette-tape library, every screen is rendered natively with fluid 60fps animations, keyboard shortcuts, and seamless light/dark modes.
            </p>
          </div>

          {/* Screenshot Tabs */}
          <div className="flex flex-wrap items-center justify-center gap-2.5 mb-8">
            {Object.keys(SCREENSHOT_DATA).map((key, idx) => (
              <button
                key={key}
                onClick={() => setActiveScreenshot(key)}
                className={`px-5 py-2.5 rounded-full text-sm font-bold font-display transition-all ${
                  activeScreenshot === key
                    ? 'bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118] shadow-md'
                    : 'bg-[#EDF1F7] dark:bg-[#151924] text-[#4B587E] dark:text-[#A3AFCC] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] hover:border-[#254EDB]'
                }`}
              >
                {`${idx + 1}. ${SCREENSHOT_DATA[key].title.split(':')[0]}`}
              </button>
            ))}
          </div>

          {/* Main Stage Window */}
          <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl overflow-hidden shadow-xl mb-10 transition-all">
            <div className="bg-[#EDF1F7] dark:bg-[#151924] px-6 py-3.5 flex items-center justify-between border-b border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)]">
              <div className="flex gap-2">
                <span className="w-3 h-3 rounded-full bg-[#FF5F56]"></span>
                <span className="w-3 h-3 rounded-full bg-[#FFBD2E]"></span>
                <span className="w-3 h-3 rounded-full bg-[#27C93F]"></span>
              </div>
              <span className="font-mono text-xs text-[#6C789B] dark:text-[#7A87A6] font-semibold">
                {SCREENSHOT_DATA[activeScreenshot].label}
              </span>
              <span className="font-mono text-[0.72rem] text-[#254EDB] dark:text-[#5E82FF] font-bold">
                NATIVE INTERFACE
              </span>
            </div>

            <div className="bg-[#0F1219] p-4 flex items-center justify-center">
              <img
                src={SCREENSHOT_DATA[activeScreenshot].src}
                alt={SCREENSHOT_DATA[activeScreenshot].title}
                className="w-full h-auto max-h-[720px] object-contain rounded-xl shadow-lg transition-opacity duration-200"
              />
            </div>

            <div className="p-6 sm:p-7 flex flex-wrap items-center justify-between gap-4 border-t border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)]">
              <div>
                <h4 className="text-xl font-bold font-display text-[#141E3C] dark:text-white mb-1">
                  {SCREENSHOT_DATA[activeScreenshot].title}
                </h4>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">
                  {SCREENSHOT_DATA[activeScreenshot].desc}
                </p>
              </div>
              <a
                href="#apply"
                className="bg-[#D83125] hover:bg-[#c2281d] text-white px-5 py-2.5 rounded-xl text-sm font-bold flex items-center gap-2 transition-all"
              >
                <span>Apply to Test This Build</span>
                <ArrowRight className="w-4 h-4" />
              </a>
            </div>
          </div>

          {/* 4-Card Bento Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <div
              onClick={() => setActiveScreenshot('hub')}
              className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl overflow-hidden cursor-pointer hover:-translate-y-1 hover:border-[#254EDB] transition-all shadow-sm"
            >
              <div className="h-44 bg-[#0E121A] overflow-hidden">
                <img src="/assets/screenshots/hub.webp" alt="Hub" className="w-full h-full object-cover object-top hover:scale-105 transition-transform" />
              </div>
              <div className="p-4">
                <div className="text-[0.72rem] font-mono font-bold text-[#D83125] uppercase mb-1">Always At Hand</div>
                <div className="font-bold text-base mb-1 font-display">Menu Bar Hub</div>
                <div className="text-xs text-[#4B587E] dark:text-[#A3AFCC]">Access speech history, meters, and model weights instantly.</div>
              </div>
            </div>

            <div
              onClick={() => setActiveScreenshot('companion')}
              className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl overflow-hidden cursor-pointer hover:-translate-y-1 hover:border-[#254EDB] transition-all shadow-sm"
            >
              <div className="h-44 bg-[#0E121A] overflow-hidden">
                <img src="/assets/screenshots/companion.webp" alt="Companion" className="w-full h-full object-cover object-top hover:scale-105 transition-transform" />
              </div>
              <div className="p-4">
                <div className="text-[0.72rem] font-mono font-bold text-[#D83125] uppercase mb-1">Desktop Robot</div>
                <div className="font-bold text-base mb-1 font-display">CX Companion</div>
                <div className="text-xs text-[#4B587E] dark:text-[#A3AFCC]">Core Animation avatar reacting in real-time to speech states.</div>
              </div>
            </div>

            <div
              onClick={() => setActiveScreenshot('settings')}
              className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl overflow-hidden cursor-pointer hover:-translate-y-1 hover:border-[#254EDB] transition-all shadow-sm"
            >
              <div className="h-44 bg-[#0E121A] overflow-hidden">
                <img src="/assets/screenshots/settings.webp" alt="Settings" className="w-full h-full object-cover object-top hover:scale-105 transition-transform" />
              </div>
              <div className="p-4">
                <div className="text-[0.72rem] font-mono font-bold text-[#D83125] uppercase mb-1">Deep Tuning</div>
                <div className="font-bold text-base mb-1 font-display">Keybindings & Mic</div>
                <div className="text-xs text-[#4B587E] dark:text-[#A3AFCC]">Map trigger keys, adjust input gain, and toggle dual-stream audio.</div>
              </div>
            </div>

            <div
              onClick={() => setActiveScreenshot('onboarding')}
              className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl overflow-hidden cursor-pointer hover:-translate-y-1 hover:border-[#254EDB] transition-all shadow-sm"
            >
              <div className="h-44 bg-[#0E121A] overflow-hidden">
                <img src="/assets/screenshots/onboarding.webp" alt="Onboarding" className="w-full h-full object-cover object-top hover:scale-105 transition-transform" />
              </div>
              <div className="p-4">
                <div className="text-[0.72rem] font-mono font-bold text-[#D83125] uppercase mb-1">60s Launch</div>
                <div className="font-bold text-base mb-1 font-display">Zero-Account Setup</div>
                <div className="text-xs text-[#4B587E] dark:text-[#A3AFCC]">Grants system permissions and tests your mic without cloud keys.</div>
              </div>
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
              Utter structures your speech history like a physical tape library. Ruled cardstock, Side A morning tracks, Side B afternoon tracks, and zero accounts.
            </p>
          </div>

          <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-8 sm:p-12 shadow-sm relative">
            <div className="absolute top-0 left-0 right-0 h-2 bg-[#D83125] rounded-t-3xl"></div>
            
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 sm:gap-12 mt-2">
              
              {/* Side A */}
              <div className="bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 sm:p-8">
                <div className="flex items-center justify-between pb-4 mb-6 border-b border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)]">
                  <span className="font-display font-extrabold text-xl text-[#141E3C] dark:text-white">Side A · Morning Session</span>
                  <span className="font-mono text-xs font-semibold text-[#254EDB] dark:text-[#5E82FF]">RUNNING TIME: 42 MIN</span>
                </div>

                <div className="space-y-5">
                  <div className="flex items-start gap-4 pb-4 border-b border-dashed border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.1)]">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">01</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">In-Process Whisper Engine</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Bundled speech model loaded directly into local unified memory. No Ollama, no Docker daemon required.</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4 pb-4 border-b border-dashed border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.1)]">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">02</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">Direct Text Injection via System API</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Simulates keystrokes directly into whichever window has active keyboard focus with sub-200ms latency.</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">03</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">Hands-Free Dictation Mode</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Double-tap trigger key for continuous dictation. Automatic silence detection commits sentences in real-time.</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Side B */}
              <div className="bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 sm:p-8">
                <div className="flex items-center justify-between pb-4 mb-6 border-b border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)]">
                  <span className="font-display font-extrabold text-xl text-[#141E3C] dark:text-white">Side B · Afternoon Session</span>
                  <span className="font-mono text-xs font-semibold text-[#254EDB] dark:text-[#5E82FF]">RUNNING TIME: 38 MIN</span>
                </div>

                <div className="space-y-5">
                  <div className="flex items-start gap-4 pb-4 border-b border-dashed border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.1)]">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">04</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">Dual-Stream Meeting Transcription</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Captures your microphone on track 1 and system audio (Zoom, Meet, Teams) on track 2 without cloud bots.</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4 pb-4 border-b border-dashed border-[rgba(37,78,219,0.1)] dark:border-[rgba(128,158,255,0.1)]">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">05</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">On-Device Voice Transforms</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Transform raw speech into structured bullet points, clean emails, or code snippets with local AI.</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">06</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">Desktop Robot Companion (CX-ArtLab)</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Optional visual companion rendered natively with hardware animation reacting to voice states.</p>
                    </div>
                  </div>
                </div>
              </div>

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
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">All notes live in your local machine application directory. Delete the folder to wipe everything.</p>
              </div>
            </div>
          </div>
        </section>

        {/* THE COMPREHENSIVE EARLY ACCESS APPLICATION SECTION (At the bottom, after customer learns!) */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="apply">
          <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-8 sm:p-14 shadow-xl relative overflow-hidden">
            <div className="absolute top-0 left-0 right-0 h-2 bg-gradient-to-r from-[#D83125] via-[#EDB123] to-[#254EDB]"></div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start mt-2">
              
              {/* Left Column: Context & Evaluation Criteria */}
              <div className="lg:col-span-5">
                <div className="text-xs font-mono font-bold text-[#D83125] tracking-widest uppercase mb-2">PRIVATE BETA EVALUATION</div>
                <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight font-display mb-4">
                  Apply for Early Access.
                </h2>
                <p className="text-base text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed mb-6">
                  Because Utter runs 100% on-device models with direct GPU memory allocation, we review every application manually to match hardware profiles across macOS, Windows, and Linux.
                </p>

                <div className="bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 mb-6">
                  <div className="font-mono text-xs font-bold text-[#D83125] uppercase tracking-wider mb-3">What We Look For</div>
                  <ul className="space-y-3 text-sm text-[#141E3C] dark:text-white">
                    <li className="flex items-start gap-2.5">
                      <CheckCircle2 className="w-4 h-4 text-[#10B981] flex-shrink-0 mt-0.5" />
                      <span><strong>Active Daily Workflows:</strong> Engineers, writers, and power users who dictate frequently.</span>
                    </li>
                    <li className="flex items-start gap-2.5">
                      <CheckCircle2 className="w-4 h-4 text-[#10B981] flex-shrink-0 mt-0.5" />
                      <span><strong>Hardware Variety:</strong> Apple Silicon (M1–M4), Intel Macs, Windows 11 PCs, and Linux workstations.</span>
                    </li>
                    <li className="flex items-start gap-2.5">
                      <CheckCircle2 className="w-4 h-4 text-[#10B981] flex-shrink-0 mt-0.5" />
                      <span><strong>Actionable Feedback:</strong> Willingness to report accuracy, shortcuts, or latency observations.</span>
                    </li>
                  </ul>
                </div>

                <div className="text-xs text-[#6C789B] dark:text-[#7A87A6] flex items-center gap-2">
                  <Lock className="w-4 h-4 text-[#254EDB]" />
                  <span>Your details sync securely to our private evaluation spreadsheet. We never sell or share emails.</span>
                </div>
              </div>

              {/* Right Column: The Direct Application Form (Connected to Google Sheets/Form) */}
              <div className="lg:col-span-7 bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-2xl p-6 sm:p-9">
                
                {isSubmitted ? (
                  <div className="py-10 text-center animate-fadeIn">
                    <div className="w-16 h-16 rounded-full bg-[rgba(37,78,219,0.1)] text-[#254EDB] flex items-center justify-center text-3xl mx-auto mb-5 font-bold">
                      ✓
                    </div>
                    <h3 className="text-2xl font-bold font-display text-[#141E3C] dark:text-white mb-2">
                      Application Successfully Received!
                    </h3>
                    <p className="text-base text-[#4B587E] dark:text-[#A3AFCC] max-w-md mx-auto mb-6">
                      Thank you, <strong className="text-[#141E3C] dark:text-white">{formData.name || 'there'}</strong>! Your details for <span className="text-[#254EDB] font-bold">{formData.os}</span> have been logged directly into our review spreadsheet.
                    </p>
                    <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.14)] rounded-xl p-4 max-w-sm mx-auto font-mono text-xs text-[#6C789B] mb-6">
                      Status: Under Manual Review · Invites Dispatched Weekly
                    </div>
                    <button
                      onClick={() => {
                        setIsSubmitted(false);
                        setFormData({
                          name: '',
                          email: '',
                          os: 'macOS (Apple Silicon M1–M4)',
                          useCases: ['Software Engineering & Terminal'],
                          reason: ''
                        });
                      }}
                      className="px-6 py-2.5 rounded-lg border border-[rgba(37,78,219,0.16)] bg-white dark:bg-[#1A1F2C] text-sm font-bold hover:border-[#254EDB] transition-all"
                    >
                      Submit Another Setup
                    </button>
                  </div>
                ) : (
                  <form onSubmit={handleSubmitApplication} className="space-y-6">
                    
                    {/* Name & Email Row */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-2">
                          Your Name / Handle
                        </label>
                        <input
                          type="text"
                          required
                          value={formData.name}
                          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                          placeholder="Alex Rivera or @alexr"
                          className="w-full px-4 py-3 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB] transition-all"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-2">
                          Email Address <span className="text-[#D83125]">*</span>
                        </label>
                        <input
                          type="email"
                          required
                          value={formData.email}
                          onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                          placeholder="alex@company.com"
                          className="w-full px-4 py-3 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB] transition-all"
                        />
                      </div>
                    </div>

                    {/* Operating System Pills */}
                    <div>
                      <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-2">
                        Target Operating System <span className="text-[#D83125]">*</span>
                      </label>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                        {[
                          'macOS (Apple Silicon M1–M4)',
                          'macOS (Intel Core)',
                          'Windows 11 / 10',
                          'Linux'
                        ].map((platform) => (
                          <button
                            key={platform}
                            type="button"
                            onClick={() => setFormData({ ...formData, os: platform })}
                            className={`p-3 rounded-xl text-xs font-bold font-display border text-left transition-all flex items-center justify-between ${
                              formData.os === platform
                                ? 'bg-white dark:bg-[#1A1F2C] border-[#254EDB] text-[#254EDB] shadow-sm'
                                : 'bg-white dark:bg-[#1A1F2C] border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] text-[#4B587E] dark:text-[#A3AFCC] hover:border-[#254EDB]'
                            }`}
                          >
                            <span>{platform}</span>
                            {formData.os === platform && <Check className="w-4 h-4 text-[#254EDB]" />}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Workflows Multi-Select */}
                    <div>
                      <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-2">
                        Primary Daily Workflow (Select all that apply)
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {[
                          'Software Engineering & Terminal',
                          'Writing & Long-Form Docs',
                          'Team Chat & Email (Slack, Teams)',
                          'Meeting Transcription',
                          'Accessibility / RSI Alternative'
                        ].map((useCase) => (
                          <button
                            key={useCase}
                            type="button"
                            onClick={() => toggleUseCase(useCase)}
                            className={`px-3.5 py-2 rounded-full text-xs font-semibold transition-all ${
                              formData.useCases.includes(useCase)
                                ? 'bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118]'
                                : 'bg-white dark:bg-[#1A1F2C] text-[#4B587E] dark:text-[#A3AFCC] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] hover:border-[#254EDB]'
                            }`}
                          >
                            {useCase}
                          </button>
                        ))}
                      </div>
                    </div>

                    {/* Detailed Reason */}
                    <div>
                      <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-2">
                        Why do you want early access & what is your setup? <span className="text-[#D83125]">*</span>
                      </label>
                      <textarea
                        required
                        rows="3"
                        value={formData.reason}
                        onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
                        placeholder="Tell us how you currently write or dictate, what apps you use (e.g. VS Code, Obsidian, Slack), and why on-device speech matters to you..."
                        className="w-full px-4 py-3 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB] transition-all resize-y"
                      ></textarea>
                      <div className="text-[0.75rem] text-[#6C789B] dark:text-[#7A87A6] mt-1">
                        We review every application manually to prioritize early build invitations.
                      </div>
                    </div>

                    {/* Submit Button */}
                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className="w-full bg-[#D83125] hover:bg-[#c2281d] disabled:opacity-50 text-white py-4 px-6 rounded-xl font-bold font-display text-base shadow-md hover:shadow-lg transition-all flex items-center justify-center gap-2"
                    >
                      {isSubmitting ? (
                        <span>Submitting Application...</span>
                      ) : (
                        <>
                          <span>Submit Application for Review</span>
                          <ArrowRight className="w-5 h-5" />
                        </>
                      )}
                    </button>

                    <div className="flex items-center justify-between text-xs text-[#6C789B] dark:text-[#7A87A6] pt-2 border-t border-dashed border-[rgba(37,78,219,0.16)]">
                      <span>⚡ Syncs directly to private evaluation spreadsheet</span>
                      <span>Weekly Batch Releases</span>
                    </div>

                  </form>
                )}

              </div>

            </div>
          </div>
        </section>

      </main>

      {/* Wide Footer */}
      <footer className="border-t border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] bg-[#EDF1F7] dark:bg-[#151924] py-16 px-6 sm:px-12 mt-32">
        <div className="max-w-[1520px] mx-auto flex flex-wrap items-center justify-between gap-6">
          <div className="text-sm text-[#6C789B] dark:text-[#7A87A6]">
            <strong className="text-[#141E3C] dark:text-white">Utter</strong> · Open Source Apache License 2.0 · Private on-device voice dictation for macOS, Windows & Linux
          </div>
          <div className="flex gap-6 font-mono text-sm text-[#4B587E] dark:text-[#A3AFCC]">
            <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">GitHub</a>
            <a href="#apply" className="hover:text-[#141E3C] dark:hover:text-white">Apply for Beta</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/PRIVACY.md" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">PRIVACY.md</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">LICENSE</a>
          </div>
        </div>
      </footer>

    </div>
  );
}
