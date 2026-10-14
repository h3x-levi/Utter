import React, { useState, useEffect } from 'react';
import { 
  Play, Shield, Terminal, Volume2, ArrowRight, Check, Moon, Sun, Lock, Send, 
  CheckCircle2, Star, MessageSquare, ThumbsUp, ChevronLeft, ChevronRight, Sparkles 
} from 'lucide-react';

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

const INITIAL_REVIEWS = [
  {
    id: 'rev-1',
    name: 'Devon Miller',
    handle: '@devon_infra',
    role: 'Staff Infrastructure Engineer',
    platform: 'macOS (M3 Max)',
    tag: 'Performance ⚡',
    rating: 5,
    date: '2 days ago',
    likes: 34,
    avatar: 'DM',
    content: 'Injecting directly into terminal and VS Code with zero network round-trip makes dictation feel like a native keyboard feature. No cloud latency lag whatsoever.'
  },
  {
    id: 'rev-2',
    name: 'Elena Rostova',
    handle: '@elena_legal',
    role: 'Legal Tech Consultant',
    platform: 'macOS (Apple Silicon)',
    tag: 'Privacy Win 🛡️',
    rating: 5,
    date: '3 days ago',
    likes: 28,
    avatar: 'ER',
    content: 'Our compliance team strictly forbids third-party audio uploads. Utter running in-process whisper on local GPU with zero telemetry passed our air-gap security audit immediately.'
  },
  {
    id: 'rev-3',
    name: 'Marcus Thorne',
    handle: '@mthorne_dev',
    role: 'Principal Systems Architect',
    platform: 'Windows 11 Wishlist',
    tag: 'Feature Wish 💡',
    rating: 5,
    date: 'Yesterday',
    likes: 42,
    avatar: 'MT',
    content: 'Eagerly waiting for the Windows 11 build! If it brings the exact same local GPU pipeline and Fn push-to-talk to PC, it will easily replace Dragon and Whispering for engineering teams.'
  },
  {
    id: 'rev-4',
    name: 'Julian Park',
    handle: '@julianp_design',
    role: 'Product Designer',
    platform: 'macOS (M2 Pro)',
    tag: 'Loved It 🔥',
    rating: 5,
    date: '4 days ago',
    likes: 19,
    avatar: 'JP',
    content: 'The cassette J-card tape library is pure delight. Splitting my daily dictations into Side A (morning standups) and Side B (design reviews) makes reviewing notes tactile and fun.'
  },
  {
    id: 'rev-5',
    name: 'Priya Sharma',
    handle: '@priya_codes',
    role: 'Senior Full-Stack Engineer',
    platform: 'Linux Wishlist',
    tag: 'Feature Wish 💡',
    rating: 5,
    date: 'Just now',
    likes: 15,
    avatar: 'PS',
    content: 'Applied for the Linux beta. A small wish: would love custom punctuation voice macros like "wrap in backticks" or "format as json". The offline transcription accuracy is already top tier.'
  },
  {
    id: 'rev-6',
    name: 'Kenji Takahashi',
    handle: '@kenji_audio',
    role: 'Indie Hacker & Creator',
    platform: 'macOS (M1 Air)',
    tag: 'Loved It 🔥',
    rating: 5,
    date: '5 days ago',
    likes: 23,
    avatar: 'KT',
    content: 'Dual-stream meeting audio without having to invite an awkward bot to Zoom or Google Meet is worth its weight in gold. Both sides of the call transcribed in private.'
  }
];

export default function App() {
  const [isDark, setIsDark] = useState(false);
  const [pillState, setPillState] = useState('idle'); // idle | listening | thinking | typed
  const [injectedText, setInjectedText] = useState('Hold a key, say it, let go...');
  const [isSimulating, setIsSimulating] = useState(false);
  const [activeScreenshot, setActiveScreenshot] = useState('library');

  // Community Reviews State
  const [reviews, setReviews] = useState(() => {
    try {
      const saved = localStorage.getItem('utter_community_reviews');
      return saved ? JSON.parse(saved) : INITIAL_REVIEWS;
    } catch {
      return INITIAL_REVIEWS;
    }
  });
  const [activeReviewTag, setActiveReviewTag] = useState('All');
  const [carouselIndex, setCarouselIndex] = useState(0);
  const [isCarouselHovered, setIsCarouselHovered] = useState(false);
  const [upvotedIds, setUpvotedIds] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('utter_upvoted_reviews') || '[]');
    } catch {
      return [];
    }
  });

  // New Comment Form State
  const [newComment, setNewComment] = useState({
    name: '',
    handle: '',
    role: '',
    platform: 'macOS (Apple Silicon)',
    tag: 'Loved It 🔥',
    rating: 5,
    content: ''
  });
  const [isPostingComment, setIsPostingComment] = useState(false);
  const [commentSuccess, setCommentSuccess] = useState(false);

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

  // Filtered reviews for carousel
  const filteredReviews = reviews.filter(r => {
    if (activeReviewTag === 'All') return true;
    return r.tag.toLowerCase().includes(activeReviewTag.toLowerCase().slice(0, 5));
  });

  // Auto-play carousel when not hovered
  useEffect(() => {
    if (isCarouselHovered || filteredReviews.length <= 1) return;
    const interval = setInterval(() => {
      setCarouselIndex(prev => (prev + 1) % filteredReviews.length);
    }, 4500);
    return () => clearInterval(interval);
  }, [isCarouselHovered, filteredReviews.length]);

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

  const handleUpvote = (id) => {
    if (upvotedIds.includes(id)) return;
    const updated = reviews.map(r => r.id === id ? { ...r, likes: r.likes + 1 } : r);
    setReviews(updated);
    const newUpvoted = [...upvotedIds, id];
    setUpvotedIds(newUpvoted);
    try {
      localStorage.setItem('utter_community_reviews', JSON.stringify(updated));
      localStorage.setItem('utter_upvoted_reviews', JSON.stringify(newUpvoted));
    } catch {}
  };

  const handlePostComment = (e) => {
    e.preventDefault();
    if (!newComment.name || !newComment.content) return;
    setIsPostingComment(true);

    const initials = newComment.name.trim().split(' ').map(p => p[0]).join('').toUpperCase().slice(0, 2) || 'UT';
    const cleanHandle = newComment.handle ? (newComment.handle.startsWith('@') ? newComment.handle : `@${newComment.handle}`) : `@${newComment.name.toLowerCase().replace(/\s+/g, '_')}`;

    const created = {
      id: `rev-${Date.now()}`,
      name: newComment.name.trim(),
      handle: cleanHandle,
      role: newComment.role.trim() || 'Verified Builder',
      platform: newComment.platform,
      tag: newComment.tag,
      rating: newComment.rating,
      date: 'Just now',
      likes: 1,
      avatar: initials,
      content: newComment.content.trim()
    };

    const updated = [created, ...reviews];
    setReviews(updated);
    try {
      localStorage.setItem('utter_community_reviews', JSON.stringify(updated));
    } catch {}

    setNewComment({
      name: '',
      handle: '',
      role: '',
      platform: 'macOS (Apple Silicon)',
      tag: 'Loved It 🔥',
      rating: 5,
      content: ''
    });
    setIsPostingComment(false);
    setCommentSuccess(true);
    setCarouselIndex(0);
    setTimeout(() => setCommentSuccess(false), 5000);
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

  const nextSlide = () => {
    if (filteredReviews.length === 0) return;
    setCarouselIndex((carouselIndex + 1) % filteredReviews.length);
  };

  const prevSlide = () => {
    if (filteredReviews.length === 0) return;
    setCarouselIndex((carouselIndex - 1 + filteredReviews.length) % filteredReviews.length);
  };

  return (
    <div className="min-h-screen bg-[#F7F9FC] dark:bg-[#0E1118] text-[#141E3C] dark:text-[#F2F5FC] font-sans antialiased transition-colors duration-200">
      
      {/* Precision Mixtape Header Bar */}
      <header className="sticky top-0 z-50 bg-[#F7F9FC]/90 dark:bg-[#0E1118]/90 backdrop-blur-md border-b border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] px-6 sm:px-12 py-4">
        <div className="max-w-[1520px] mx-auto flex items-center justify-between">
          
          <a href="#" className="flex items-center gap-3 group">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#D83125] to-[#254EDB] flex items-center justify-center text-white font-black text-lg shadow-sm group-hover:scale-105 transition-transform">
              U
            </div>
            <div>
              <span className="font-display font-extrabold text-xl tracking-tight text-[#141E3C] dark:text-white">Utter</span>
              <span className="ml-2 font-mono text-[0.7rem] bg-[#EDF1F7] dark:bg-[#151924] text-[#254EDB] dark:text-[#5E82FF] px-2 py-0.5 rounded font-semibold border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)]">
                v1.2.0 · Private Beta
              </span>
            </div>
          </a>

          <nav className="hidden md:flex items-center gap-8 text-[0.95rem] font-medium text-[#4B587E] dark:text-[#A3AFCC]">
            <a href="#promo-video" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Promo Reel</a>
            <a href="#screenshots" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Screenshots</a>
            <a href="#library" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Mixtape Library</a>
            <a href="#privacy" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Privacy</a>
            <a href="#community" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Community</a>
            <a href="#apply" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">Apply for Beta</a>
            <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white transition-colors">GitHub</a>
          </nav>

          <div className="flex items-center gap-3.5">
            <button
              onClick={toggleTheme}
              aria-label="Toggle theme"
              className="p-2.5 rounded-lg border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] hover:border-[#254EDB] transition-all"
            >
              {isDark ? <Sun className="w-4 h-4 text-[#EDB123]" /> : <Moon className="w-4 h-4 text-[#141E3C]" />}
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
        {/* Wide Panoramic Hero Section: Pure Education First */}
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

              {/* Cross Platform Roadmap Badges */}
              <div className="flex flex-wrap items-center gap-3 text-xs font-mono text-[#6C789B] dark:text-[#7A87A6]">
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

            {/* Right Column: Live Floating Pill HUD Simulator */}
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

                {/* Simulated Floating Screen Workspace */}
                <div className="h-44 rounded-2xl bg-[#0F1219] flex flex-col items-center justify-between p-5 relative overflow-hidden mb-6 shadow-inner border border-black/40">
                  <div className="w-full flex items-center justify-between text-[0.65rem] font-mono text-[#809EFF]/60">
                    <span>Active Cursor: VS Code / Terminal</span>
                    <span>Direct Keyboard Event</span>
                  </div>

                  {/* Authentic Pill HUD */}
                  <div className="my-auto">
                    {pillState === 'idle' && (
                      <div className="w-12 h-2.5 rounded-full bg-gradient-to-r from-[#D83125] via-[#EDB123] to-[#254EDB] shadow-[0_0_12px_rgba(216,49,37,0.3)] animate-pulse"></div>
                    )}
                    {pillState === 'listening' && (
                      <div className="w-[96px] h-[32px] rounded-full bg-[#D83125] flex items-center justify-center gap-1 shadow-[0_0_24px_rgba(216,49,37,0.6)] animate-scaleIn">
                        <span className="w-1 bg-white rounded-full h-3 animate-sound-1"></span>
                        <span className="w-1 bg-white rounded-full h-5 animate-sound-2"></span>
                        <span className="w-1 bg-white rounded-full h-2 animate-sound-3"></span>
                        <span className="w-1 bg-white rounded-full h-6 animate-sound-4"></span>
                        <span className="w-1 bg-white rounded-full h-4 animate-sound-5"></span>
                        <span className="w-1 bg-white rounded-full h-2 animate-sound-6"></span>
                      </div>
                    )}
                    {pillState === 'thinking' && (
                      <div className="w-[72px] h-[30px] rounded-full bg-[#1C2A5E] flex items-center justify-center gap-1.5 shadow-[0_0_16px_rgba(37,78,219,0.5)]">
                        <span className="w-1.5 h-1.5 rounded-full bg-white/80 animate-ping"></span>
                        <span className="w-1.5 h-1.5 rounded-full bg-white/80 animate-ping delay-150"></span>
                        <span className="w-1.5 h-1.5 rounded-full bg-white/80 animate-ping delay-300"></span>
                      </div>
                    )}
                    {pillState === 'typed' && (
                      <div className="w-[56px] h-[30px] rounded-full bg-[#10B981] flex items-center justify-center shadow-[0_0_16px_rgba(16,185,129,0.5)] animate-scaleIn">
                        <Check className="w-4 h-4 text-white stroke-[3]" />
                      </div>
                    )}
                  </div>

                  <div className="font-mono text-[0.7rem] text-[#A3AFCC]">
                    {pillState === 'idle' && 'State: Resting (32×6 pt accent bar)'}
                    {pillState === 'listening' && 'State: Listening (hardware audio waveform in RAM)'}
                    {pillState === 'thinking' && 'State: Thinking (Metal GPU Whisper transcription)'}
                    {pillState === 'typed' && 'State: Injected text at cursor'}
                  </div>
                </div>

                {/* THE ACTIVE FOCUSED CURSOR WINDOW */}
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
              Your browser does not support HTML5 video.
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
              <span className="font-mono text-xs font-bold text-[#141E3C] dark:text-white">
                {SCREENSHOT_DATA[activeScreenshot].label}
              </span>
              <span className="text-xs font-mono text-[#D83125] font-semibold">100% NATIVE COCOA / SWIFTUI</span>
            </div>

            <div className="p-4 sm:p-8 flex items-center justify-center bg-[#0C0E14]">
              <img
                src={SCREENSHOT_DATA[activeScreenshot].src}
                alt={SCREENSHOT_DATA[activeScreenshot].label}
                className="w-full max-h-[640px] object-contain rounded-xl shadow-2xl border border-white/10"
              />
            </div>

            <div className="p-6 bg-white dark:bg-[#1A1F2C] border-t border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] flex flex-wrap items-center justify-between gap-4">
              <div>
                <h3 className="font-display font-extrabold text-xl text-[#141E3C] dark:text-white mb-1">
                  {SCREENSHOT_DATA[activeScreenshot].title}
                </h3>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">
                  {SCREENSHOT_DATA[activeScreenshot].desc}
                </p>
              </div>
              <a
                href="#apply"
                className="px-5 py-2.5 rounded-xl bg-[#254EDB] text-white text-sm font-bold flex items-center gap-2 hover:bg-[#1c3db5] transition-all"
              >
                <span>Request Early Access</span>
                <ArrowRight className="w-4 h-4" />
              </a>
            </div>
          </div>

          {/* 4-Card Bento Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 shadow-sm">
              <div className="w-8 h-8 rounded-lg bg-[rgba(37,78,219,0.1)] text-[#254EDB] flex items-center justify-center font-bold text-sm mb-4">
                01
              </div>
              <h4 className="font-bold text-base mb-2 font-display">In-Process Whisper</h4>
              <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed">
                Bundled model checkpoint loaded directly in RAM. No background daemons, Ollama, or third-party servers needed.
              </p>
            </div>

            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 shadow-sm">
              <div className="w-8 h-8 rounded-lg bg-[rgba(216,49,37,0.1)] text-[#D83125] flex items-center justify-center font-bold text-sm mb-4">
                02
              </div>
              <h4 className="font-bold text-base mb-2 font-display">Direct Text Injection</h4>
              <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed">
                Simulates real keyboard input directly into whichever terminal, editor, or browser input has active focus.
              </p>
            </div>

            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 shadow-sm">
              <div className="w-8 h-8 rounded-lg bg-[rgba(237,177,35,0.1)] text-[#EDB123] flex items-center justify-center font-bold text-sm mb-4">
                03
              </div>
              <h4 className="font-bold text-base mb-2 font-display">Dual-Stream Meetings</h4>
              <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed">
                Records both mic and system output into two discrete tracks with real-time transcription and speaker labels.
              </p>
            </div>

            <div className="bg-white dark:bg-[#1A1F2C] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 shadow-sm">
              <div className="w-8 h-8 rounded-lg bg-[rgba(16,185,129,0.1)] text-[#10B981] flex items-center justify-center font-bold text-sm mb-4">
                04
              </div>
              <h4 className="font-bold text-base mb-2 font-display">Plain JSON Storage</h4>
              <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC] leading-relaxed">
                Dictation notes live in plain JSON on disk. Zero proprietary lock-in. Wipe the folder to erase your entire history.
              </p>
            </div>
          </div>
        </section>

        {/* The Mixtape Library: Cassette Tape J-Card Section */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="library">
          <div className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-8 sm:p-14 shadow-xl relative overflow-hidden">
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
                      <h4 className="font-bold text-base mb-1 font-display">Full Keyboard Navigation</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">Navigate your speech library with Vim-style keys (J/K) and re-inject any past dictation with Enter.</p>
                    </div>
                  </div>

                  <div className="flex items-start gap-4">
                    <span className="font-mono text-sm font-bold text-[#D83125] w-6">06</span>
                    <div>
                      <h4 className="font-bold text-base mb-1 font-display">Zero Cloud Lock-In</h4>
                      <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">All data lives in plain JSON files on your hard drive. Export, backup, or wipe your history whenever you choose.</p>
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

        {/* COMMUNITY TAPE DECK & REVIEWS SECTION */}
        <section className="max-w-[1520px] mx-auto px-6 sm:px-12 my-28" id="community">
          <div className="flex flex-wrap items-end justify-between gap-6 mb-10">
            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-xs font-mono text-[#D83125] font-bold mb-3 shadow-sm">
                <MessageSquare className="w-3.5 h-3.5" />
                <span>COMMUNITY TAPE DECK · BUILDER NOTES</span>
              </div>
              <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight font-display text-[#141E3C] dark:text-white">
                What builders are saying.
              </h2>
            </div>
            <p className="text-base sm:text-lg text-[#4B587E] dark:text-[#A3AFCC] max-w-[560px]">
              Real impressions, speedups, and feature wishes from developers, writers, and power users dictating with Utter.
            </p>
          </div>

          {/* Filter Pills & Carousel Controls */}
          <div className="flex flex-wrap items-center justify-between gap-4 mb-8">
            <div className="flex flex-wrap items-center gap-2">
              {['All', 'Loved It', 'Feature Wish', 'Performance', 'Privacy Win'].map(tag => (
                <button
                  key={tag}
                  onClick={() => {
                    setActiveReviewTag(tag);
                    setCarouselIndex(0);
                  }}
                  className={`px-4 py-2 rounded-full text-xs font-bold font-display transition-all ${
                    activeReviewTag === tag
                      ? 'bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118] shadow-sm'
                      : 'bg-white dark:bg-[#1A1F2C] text-[#4B587E] dark:text-[#A3AFCC] border border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] hover:border-[#254EDB]'
                  }`}
                >
                  {tag === 'All' ? `All Notes (${reviews.length})` : tag}
                </button>
              ))}
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={prevSlide}
                aria-label="Previous review"
                className="w-10 h-10 rounded-full border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] flex items-center justify-center hover:border-[#254EDB] transition-all"
              >
                <ChevronLeft className="w-5 h-5 text-[#141E3C] dark:text-white" />
              </button>
              <span className="font-mono text-xs text-[#6C789B] px-2">
                {filteredReviews.length > 0 ? `${(carouselIndex % filteredReviews.length) + 1} / ${filteredReviews.length}` : '0 / 0'}
              </span>
              <button
                onClick={nextSlide}
                aria-label="Next review"
                className="w-10 h-10 rounded-full border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] flex items-center justify-center hover:border-[#254EDB] transition-all"
              >
                <ChevronRight className="w-5 h-5 text-[#141E3C] dark:text-white" />
              </button>
            </div>
          </div>

          {/* Carousel Grid Cards */}
          <div 
            className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-12"
            onMouseEnter={() => setIsCarouselHovered(true)}
            onMouseLeave={() => setIsCarouselHovered(false)}
          >
            {filteredReviews.length === 0 ? (
              <div className="col-span-full py-12 text-center text-[#6C789B] font-mono text-sm">
                No reviews found in this category yet. Be the first to share one below!
              </div>
            ) : (
              // Display 3 responsive cards starting at carouselIndex
              [0, 1, 2].map(offset => {
                const idx = (carouselIndex + offset) % filteredReviews.length;
                const review = filteredReviews[idx];
                if (!review) return null;
                const isLiked = upvotedIds.includes(review.id);

                return (
                  <div
                    key={`${review.id}-${offset}`}
                    className="bg-white dark:bg-[#1A1F2C] border-2 border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] rounded-2xl p-6 sm:p-7 shadow-sm hover:shadow-md transition-all flex flex-col justify-between relative overflow-hidden group"
                  >
                    <div className="absolute top-0 left-0 right-0 h-1.5 bg-gradient-to-r from-[#D83125] via-[#EDB123] to-[#254EDB] opacity-80"></div>

                    <div>
                      {/* Author Header */}
                      <div className="flex items-start justify-between gap-3 mb-4 mt-1">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-xl bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.16)] flex items-center justify-center font-bold text-xs font-mono text-[#254EDB] dark:text-[#5E82FF]">
                            {review.avatar}
                          </div>
                          <div>
                            <div className="font-bold text-sm text-[#141E3C] dark:text-white font-display">
                              {review.name}
                            </div>
                            <div className="text-xs font-mono text-[#6C789B] dark:text-[#7A87A6]">
                              {review.handle} · {review.date}
                            </div>
                          </div>
                        </div>

                        {/* 5-Star Rating */}
                        <div className="flex items-center gap-0.5 text-[#EDB123]">
                          {[...Array(review.rating || 5)].map((_, i) => (
                            <Star key={i} className="w-3.5 h-3.5 fill-current" />
                          ))}
                        </div>
                      </div>

                      {/* Badges Row */}
                      <div className="flex flex-wrap items-center gap-2 mb-4">
                        <span className="font-mono text-[0.7rem] px-2.5 py-0.5 rounded-full bg-[#EDF1F7] dark:bg-[#151924] border border-[rgba(37,78,219,0.14)] text-[#141E3C] dark:text-white font-semibold">
                          {review.platform}
                        </span>
                        <span className={`font-mono text-[0.7rem] px-2.5 py-0.5 rounded-full font-bold ${
                          review.tag.includes('Loved')
                            ? 'bg-[rgba(216,49,37,0.1)] text-[#D83125]'
                            : review.tag.includes('Feature')
                            ? 'bg-[rgba(237,177,35,0.1)] text-[#EDB123]'
                            : review.tag.includes('Performance')
                            ? 'bg-[rgba(37,78,219,0.1)] text-[#254EDB] dark:text-[#5E82FF]'
                            : 'bg-[rgba(16,185,129,0.1)] text-[#10B981]'
                        }`}>
                          {review.tag}
                        </span>
                      </div>

                      {/* Content */}
                      <p className="text-sm text-[#141E3C] dark:text-white/90 leading-relaxed font-sans mb-6">
                        "{review.content}"
                      </p>
                    </div>

                    {/* Card Footer */}
                    <div className="pt-4 border-t border-dashed border-[rgba(37,78,219,0.12)] dark:border-[rgba(128,158,255,0.14)] flex items-center justify-between text-xs font-mono">
                      <span className="text-[#6C789B] dark:text-[#7A87A6]">
                        {review.role}
                      </span>
                      <button
                        onClick={() => handleUpvote(review.id)}
                        disabled={isLiked}
                        className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold transition-all ${
                          isLiked
                            ? 'bg-[rgba(16,185,129,0.1)] border-[#10B981] text-[#10B981]'
                            : 'bg-[#EDF1F7] dark:bg-[#151924] border-[rgba(37,78,219,0.16)] text-[#4B587E] dark:text-[#A3AFCC] hover:border-[#254EDB]'
                        }`}
                      >
                        <ThumbsUp className="w-3 h-3" />
                        <span>{review.likes}</span>
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Interactive "Leave a Review / Drop Feedback" Box */}
          <div className="bg-[#EDF1F7] dark:bg-[#151924] border-2 border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] rounded-3xl p-7 sm:p-10">
            <div className="max-w-3xl mx-auto">
              <div className="text-center mb-8">
                <div className="inline-flex items-center gap-1.5 font-mono text-xs font-bold text-[#D83125] uppercase tracking-wider mb-2">
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>Public Tape Deck</span>
                </div>
                <h3 className="text-2xl sm:text-3xl font-bold font-display text-[#141E3C] dark:text-white mb-2">
                  Drop your note to the community.
                </h3>
                <p className="text-sm text-[#4B587E] dark:text-[#A3AFCC]">
                  Tell others how Utter speeds up your work, or submit what you would love improved next.
                </p>
              </div>

              {commentSuccess && (
                <div className="mb-6 p-4 rounded-xl bg-[rgba(16,185,129,0.12)] border border-[#10B981] text-[#10B981] text-sm font-bold flex items-center justify-center gap-2 animate-fadeIn">
                  <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
                  <span>Your note has been posted live to the community tape deck above!</span>
                </div>
              )}

              <form onSubmit={handlePostComment} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                      Your Name / Handle <span className="text-[#D83125]">*</span>
                    </label>
                    <input
                      type="text"
                      required
                      value={newComment.name}
                      onChange={(e) => setNewComment({ ...newComment, name: e.target.value })}
                      placeholder="e.g. Liam Scott or @liam"
                      className="w-full px-4 py-2.5 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB]"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                      Your Role / Tagline
                    </label>
                    <input
                      type="text"
                      value={newComment.role}
                      onChange={(e) => setNewComment({ ...newComment, role: e.target.value })}
                      placeholder="e.g. Backend Dev / Writer"
                      className="w-full px-4 py-2.5 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB]"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                      Platform
                    </label>
                    <select
                      value={newComment.platform}
                      onChange={(e) => setNewComment({ ...newComment, platform: e.target.value })}
                      className="w-full px-4 py-2.5 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB]"
                    >
                      <option>macOS (Apple Silicon)</option>
                      <option>macOS (Intel Core)</option>
                      <option>Windows 11 Wishlist</option>
                      <option>Linux Wishlist</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                      Category Tag
                    </label>
                    <select
                      value={newComment.tag}
                      onChange={(e) => setNewComment({ ...newComment, tag: e.target.value })}
                      className="w-full px-4 py-2.5 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB]"
                    >
                      <option>Loved It 🔥</option>
                      <option>Feature Wish 💡</option>
                      <option>Performance ⚡</option>
                      <option>Privacy Win 🛡️</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                      Rating
                    </label>
                    <div className="flex items-center gap-1.5 py-2">
                      {[1, 2, 3, 4, 5].map((star) => (
                        <button
                          key={star}
                          type="button"
                          onClick={() => setNewComment({ ...newComment, rating: star })}
                          className="focus:outline-none"
                        >
                          <Star className={`w-5 h-5 ${star <= newComment.rating ? 'text-[#EDB123] fill-current' : 'text-gray-300 dark:text-gray-600'}`} />
                        </button>
                      ))}
                      <span className="font-mono text-xs font-bold ml-2 text-[#4B587E] dark:text-[#A3AFCC]">
                        {newComment.rating}/5
                      </span>
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold font-display uppercase tracking-wider text-[#141E3C] dark:text-white mb-1.5">
                    Your Note or Feature Wish <span className="text-[#D83125]">*</span>
                  </label>
                  <textarea
                    required
                    rows="3"
                    value={newComment.content}
                    onChange={(e) => setNewComment({ ...newComment, content: e.target.value })}
                    placeholder="Tell the community how you use Utter, what speedups you noticed, or what you would love built in the next update..."
                    className="w-full px-4 py-3 rounded-xl border border-[rgba(37,78,219,0.16)] dark:border-[rgba(128,158,255,0.2)] bg-white dark:bg-[#1A1F2C] text-sm text-[#141E3C] dark:text-white focus:outline-none focus:border-[#254EDB] transition-all resize-y"
                  ></textarea>
                </div>

                <div className="flex flex-wrap items-center justify-between gap-4 pt-2">
                  <div className="text-xs text-[#6C789B] dark:text-[#7A87A6]">
                    Have a technical bug to report? Please open a ticket on <a href="https://github.com/h3x-levi/Utter/issues" target="_blank" rel="noopener noreferrer" className="text-[#254EDB] hover:underline font-bold">GitHub Issues</a>.
                  </div>

                  <button
                    type="submit"
                    disabled={isPostingComment}
                    className="bg-[#141E3C] dark:bg-white text-white dark:text-[#0E1118] px-6 py-3 rounded-xl font-bold font-display text-sm hover:bg-[#254EDB] dark:hover:bg-[#E2E8F0] transition-all shadow-sm flex items-center gap-2"
                  >
                    <span>Post Community Note</span>
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </div>
              </form>
            </div>
          </div>
        </section>

        {/* THE COMPREHENSIVE EARLY ACCESS APPLICATION SECTION */}
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

              {/* Right Column: The Direct Application Form */}
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

      {/* Grounded Monospace Footer */}
      <footer className="border-t border-[rgba(37,78,219,0.14)] dark:border-[rgba(128,158,255,0.14)] bg-[#EDF1F7] dark:bg-[#151924] py-16 px-6 sm:px-12 mt-32">
        <div className="max-w-[1520px] mx-auto flex flex-wrap items-center justify-between gap-6">
          <div className="text-sm text-[#6C789B] dark:text-[#7A87A6]">
            <strong className="text-[#141E3C] dark:text-white">Utter</strong> · Open Source Apache License 2.0 · Private on-device voice dictation for macOS, Windows & Linux
          </div>
          <div className="flex gap-6 font-mono text-sm text-[#4B587E] dark:text-[#A3AFCC]">
            <a href="https://github.com/h3x-levi/Utter" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">GitHub</a>
            <a href="#community" className="hover:text-[#141E3C] dark:hover:text-white">Community</a>
            <a href="#apply" className="hover:text-[#141E3C] dark:hover:text-white">Apply for Beta</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/PRIVACY.md" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">PRIVACY.md</a>
            <a href="https://github.com/h3x-levi/Utter/blob/main/LICENSE" target="_blank" rel="noopener noreferrer" className="hover:text-[#141E3C] dark:hover:text-white">LICENSE</a>
          </div>
        </div>
      </footer>

    </div>
  );
}
