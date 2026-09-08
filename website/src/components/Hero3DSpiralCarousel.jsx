import React, { useState, useRef } from 'react';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';
import { ChevronLeft, ChevronRight, Sparkles, Layers, Cpu, Bot, Mic, FileText } from 'lucide-react';

const showcaseItems = [
  {
    id: 'dictation',
    title: 'Universal Cursor Injection',
    subtitle: 'Directly at your caret in Xcode, Cursor, Slack & Obsidian',
    tag: '180 WPM · Zero Latency',
    icon: Mic,
    screenshot: '/assets/screenshots/hero-main.png',
    stat: '168ms',
    statLabel: 'Local Latency',
    badge: 'Real App View',
    desc: 'Hold a key, speak naturally, and release. Audio buffers stream directly to Metal GPU kernels in unified memory with zero clipboard contamination.',
  },
  {
    id: 'notes',
    title: 'Dual-Stream Meeting Diarization',
    subtitle: 'Microphone + system CoreAudio process taps',
    tag: 'Speaker Attribution',
    icon: FileText,
    screenshot: '/assets/screenshots/04_notes_studio.png',
    stat: 'Dual-Tap',
    statLabel: 'ScreenCaptureKit',
    badge: 'Meeting Studio',
    desc: 'Captures both sides of Zoom, Teams, and Google Meet conversations simultaneously. Generates Markdown transcripts with speaker separation.',
  },
  {
    id: 'models',
    title: 'Local Whisper Model Catalog',
    subtitle: 'From Tiny (39MB) to Large-v3-Turbo (809MB)',
    tag: 'Apple Silicon Metal',
    icon: Cpu,
    screenshot: '/assets/screenshots/06_model_chooser.png',
    stat: '39MB-809MB',
    statLabel: 'Model Options',
    badge: 'Model Chooser',
    desc: 'Bundle Small.en out of the box or swap in one click. Models run entirely on Apple Silicon Neural Engine with zero network requests.',
  },
  {
    id: 'companions',
    title: 'Articulated Desktop Pets',
    subtitle: 'Retro pixel companions that react to your voice & cadence',
    tag: '60 FPS Vector Motion',
    icon: Bot,
    screenshot: '/assets/screenshots/05b_companion_customize.png',
    stat: '60 FPS',
    statLabel: 'Live Physics',
    badge: 'Pixel Pets',
    desc: 'Quadruped walk cycles, biscuit kneading, alert ear twitches, and celebratory poses that react to your speaking and typing rhythm.',
  },
  {
    id: 'transforms',
    title: 'Apple Intelligence Text Actions',
    subtitle: 'Grammar polish, action items & Swift docstrings',
    tag: 'Foundation Models',
    icon: Sparkles,
    screenshot: '/assets/screenshots/10_transforms_hub.png',
    stat: '100% Local',
    statLabel: 'Apple Intelligence',
    badge: 'AI Transforms',
    desc: 'Harnesses on-device Apple Foundation Models on macOS 15+ to clean transcriptions, extract action items, and format markdown without cloud APIs.',
  },
  {
    id: 'dictionary',
    title: 'Developer Vocabulary Studio',
    subtitle: 'Custom regex, code snippets & technical jargon',
    tag: 'Context Biasing',
    icon: Layers,
    screenshot: '/assets/screenshots/08_dictionary_studio.png',
    stat: 'Zero Typo',
    statLabel: 'Prompt Biasing',
    badge: 'Custom Vocab',
    desc: 'Bias the Whisper decoder toward specialized framework names, Kubernetes commands, or medical terminology for flawless accuracy.',
  },
];

export default function Hero3DSpiralCarousel() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const [dragStartX, setDragStartX] = useState(0);
  const containerRef = useRef(null);
  const shouldReduceMotion = useReducedMotion();

  const totalCards = showcaseItems.length;
  const angleStep = 360 / totalCards;

  const handlePrev = () => {
    setActiveIndex((prev) => (prev - 1 + totalCards) % totalCards);
  };

  const handleNext = () => {
    setActiveIndex((prev) => (prev + 1) % totalCards);
  };

  const handleMouseDown = (e) => {
    setIsDragging(true);
    setDragStartX(e.clientX);
  };

  const handleMouseMove = (e) => {
    if (!isDragging) return;
    const deltaX = e.clientX - dragStartX;
    if (Math.abs(deltaX) > 50) {
      if (deltaX > 0) {
        handlePrev();
      } else {
        handleNext();
      }
      setDragStartX(e.clientX);
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const activeItem = showcaseItems[activeIndex];

  return (
    <div
      id="showcase-3d"
      ref={containerRef}
      className="relative w-full py-16 sm:py-24 overflow-hidden select-none"
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
    >
      <div className="w-full max-w-[94vw] 2xl:max-w-[1600px] mx-auto">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-10 sm:mb-14">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-indigo-50/80 border border-indigo-200/80 text-indigo-700 text-xs font-mono font-bold mb-3 shadow-xs">
            <Sparkles size={13} className="text-indigo-600" />
            Interactive 3D Spiral Showcase
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-zinc-900 mb-3">
            Real macOS architecture in 3D motion.
          </h2>
          <p className="text-base text-zinc-600 font-normal leading-relaxed">
            Rotate the cylinder to inspect actual macOS production windows: on-device Whisper, dual-tap meeting diarization, and desktop companion physics.
          </p>
        </div>

        {/* 3D Cylindrical Spiral Stage */}
        <div
          className="relative h-[480px] sm:h-[540px] md:h-[600px] w-full flex items-center justify-center"
          style={{ perspective: '1400px' }}
        >
          {/* Central 3D Rotating Cylinder */}
          <div
            className="relative w-[320px] sm:w-[480px] md:w-[620px] h-[340px] sm:h-[400px] md:h-[460px] cursor-grab active:cursor-grabbing transition-transform duration-700 ease-out"
            style={{
              transformStyle: 'preserve-3d',
              transform: shouldReduceMotion
                ? `rotateY(${-activeIndex * angleStep}deg)`
                : `rotateX(4deg) rotateY(${-activeIndex * angleStep}deg)`,
            }}
          >
            {showcaseItems.map((item, idx) => {
              const cardAngle = idx * angleStep;
              const isActive = idx === activeIndex;
              const radius = 460;
              const verticalOffset = (idx - activeIndex) * 16;

              return (
                <div
                  key={item.id}
                  onClick={() => setActiveIndex(idx)}
                  className="absolute inset-0 transition-opacity duration-500 rounded-3xl"
                  style={{
                    transform: `rotateY(${cardAngle}deg) translateZ(${radius}px) translateY(${verticalOffset}px)`,
                    transformStyle: 'preserve-3d',
                    opacity: isActive ? 1 : 0.45,
                    filter: isActive ? 'drop-shadow(0 20px 40px rgba(0,0,0,0.12))' : 'blur(0.5px) grayscale(20%)',
                    zIndex: isActive ? 40 : 10,
                  }}
                >
                  {/* macOS Window Card */}
                  <div
                    className={`w-full h-full rounded-3xl overflow-hidden border transition-all duration-300 flex flex-col bg-white shadow-2xl ${
                      isActive
                        ? 'border-indigo-500/60 ring-4 ring-indigo-500/10'
                        : 'border-black/10 hover:border-black/25'
                    }`}
                  >
                    {/* macOS Window Title Bar */}
                    <div className="h-10 bg-zinc-100/90 border-b border-black/5 px-4 flex items-center justify-between shrink-0">
                      <div className="flex items-center gap-1.5">
                        <div className="w-3 h-3 rounded-full bg-[#ff5f56] border border-black/10" />
                        <div className="w-3 h-3 rounded-full bg-[#ffbd2e] border border-black/10" />
                        <div className="w-3 h-3 rounded-full bg-[#27c93f] border border-black/10" />
                        <span className="text-[11px] font-medium text-zinc-600 ml-2 truncate max-w-[200px] sm:max-w-[300px]">
                          {item.title}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-[10px] font-mono font-bold px-2 py-0.5 rounded-full bg-zinc-200 text-zinc-700">
                          {item.badge}
                        </span>
                      </div>
                    </div>

                    {/* Screenshot Container */}
                    <div className="relative flex-1 bg-zinc-950 overflow-hidden group">
                      <img
                        src={item.screenshot}
                        alt={item.title}
                        className="w-full h-full object-cover object-top transition-transform duration-500 group-hover:scale-[1.02]"
                      />

                      {/* Stat Pill Overlay */}
                      <div className="absolute top-3 left-3 bg-black/75 backdrop-blur-md text-white px-3 py-1 rounded-full text-xs font-mono font-bold border border-white/15 flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                        <span>{item.stat}</span>
                        <span className="opacity-60 font-sans text-[10px] font-normal">{item.statLabel}</span>
                      </div>

                      {/* Floating Category Tag */}
                      <div className="absolute bottom-3 right-3 bg-white/90 backdrop-blur-md text-zinc-900 px-3 py-1 rounded-full text-xs font-bold border border-black/10 shadow-md">
                        {item.tag}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Navigation Arrows */}
          <button
            onClick={handlePrev}
            aria-label="Previous 3D Feature"
            className="absolute left-2 sm:left-6 z-50 w-11 h-11 rounded-full bg-white/90 hover:bg-white text-zinc-900 border border-black/10 shadow-lg flex items-center justify-center transition-transform active:scale-90 hover:scale-105 cursor-pointer"
          >
            <ChevronLeft size={20} />
          </button>

          <button
            onClick={handleNext}
            aria-label="Next 3D Feature"
            className="absolute right-2 sm:right-6 z-50 w-11 h-11 rounded-full bg-white/90 hover:bg-white text-zinc-900 border border-black/10 shadow-lg flex items-center justify-center transition-transform active:scale-90 hover:scale-105 cursor-pointer"
          >
            <ChevronRight size={20} />
          </button>
        </div>

        {/* Active Item Description Card */}
        <div className="mt-8 max-w-2xl mx-auto card-opaque p-6 sm:p-7 shadow-xl border border-black/10 text-center relative overflow-hidden">
          <div className="flex items-center justify-center gap-2 mb-2">
            <span className="w-2.5 h-2.5 rounded-full bg-indigo-500" />
            <h3 className="text-xl font-extrabold text-zinc-900">{activeItem.title}</h3>
          </div>
          <p className="text-xs sm:text-sm text-zinc-500 mb-2 font-medium">{activeItem.subtitle}</p>
          <p className="text-xs sm:text-sm text-zinc-700 leading-relaxed max-w-xl mx-auto mb-5">
            {activeItem.desc}
          </p>

          {/* Pagination Indicators */}
          <div className="flex items-center justify-center gap-2 pt-2 border-t border-black/5">
            {showcaseItems.map((item, idx) => (
              <button
                key={item.id}
                onClick={() => setActiveIndex(idx)}
                aria-label={`Jump to ${item.title}`}
                className={`transition-all duration-300 rounded-full cursor-pointer ${
                  idx === activeIndex
                    ? 'w-7 h-2.5 bg-zinc-900'
                    : 'w-2.5 h-2.5 bg-zinc-300 hover:bg-zinc-400'
                }`}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
