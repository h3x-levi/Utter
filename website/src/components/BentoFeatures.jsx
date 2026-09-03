import React from 'react';
import { Cpu, PhoneCall, BookOpen, Wand2 } from 'lucide-react';
import { motion } from 'framer-motion';

export default function BentoFeatures() {
  return (
    <section id="features" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Built for Extreme Speed & Craft
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Engineered like a first-party Apple utility.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg leading-relaxed">
            Zero bloat, zero cloud latency. Designed from first principles in Swift, C++, and Metal to feel like a natural part of macOS.
          </p>
        </div>

        {/* Bento Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">

          {/* Card 1: whisper.cpp on Metal GPU */}
          <div className="apple-panel apple-card rounded-2xl p-8 flex flex-col justify-between md:col-span-2 border border-zinc-800">
            <div>
              <div className="w-10 h-10 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 mb-6">
                <Cpu className="w-5 h-5" />
              </div>
              <span className="text-xs font-mono font-semibold text-zinc-400 uppercase tracking-wider">
                Sub-200ms Local Inference
              </span>
              <h3 className="text-2xl sm:text-3xl font-bold text-white mt-2 mb-3">
                whisper.cpp Accelerated on Apple Metal GPU
              </h3>
              <p className="text-zinc-400 text-sm sm:text-base leading-relaxed mb-6">
                Utter bridges directly to whisper.cpp with native Metal shaders. Speech chunks are processed asynchronously in memory without writing temporary audio files to disk, delivering instant typing at 180+ words per minute.
              </p>
            </div>
            <div className="rounded-xl overflow-hidden border border-zinc-800 shadow-2xl bg-[#121215]">
              <img
                src="/assets/screenshots/feature-speech-models.png"
                alt="Speech Model Switcher"
                className="w-full object-cover"
              />
            </div>
          </div>

          {/* Card 2: Two-Way Meeting Taps */}
          <div className="apple-panel apple-card rounded-2xl p-8 flex flex-col justify-between border border-zinc-800">
            <div>
              <div className="w-10 h-10 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 mb-6">
                <PhoneCall className="w-5 h-5" />
              </div>
              <span className="text-xs font-mono font-semibold text-zinc-400 uppercase tracking-wider">
                Dual-Stream Capture
              </span>
              <h3 className="text-2xl font-bold text-white mt-2 mb-3">
                Two-Way Meeting Audio
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed mb-6">
                Auto-detects active calls in Zoom, Google Meet, Microsoft Teams, FaceTime, and Slack. Taps incoming system audio and your microphone simultaneously.
              </p>
            </div>
            <div className="rounded-xl overflow-hidden border border-zinc-800 shadow-2xl bg-[#121215]">
              <img
                src="/assets/screenshots/feature-notes.png"
                alt="Notes Studio & Meeting Transcripts"
                className="w-full object-cover"
              />
            </div>
          </div>

          {/* Card 3: Custom Dictionary & Phrase Boosting */}
          <div className="apple-panel apple-card rounded-2xl p-8 flex flex-col justify-between border border-zinc-800">
            <div>
              <div className="w-10 h-10 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 mb-6">
                <BookOpen className="w-5 h-5" />
              </div>
              <span className="text-xs font-mono font-semibold text-zinc-400 uppercase tracking-wider">
                Zero Misspellings
              </span>
              <h3 className="text-2xl font-bold text-white mt-2 mb-3">
                Dictionary & Context Biasing
              </h3>
              <p className="text-zinc-400 text-sm leading-relaxed mb-6">
                Teach Utter your company’s internal codenames, developer variable names, medical terms, and acronyms. Context biasing feeds custom vocabulary directly into the Whisper decoder.
              </p>
            </div>
            <div className="rounded-xl overflow-hidden border border-zinc-800 shadow-2xl bg-[#121215]">
              <img
                src="/assets/screenshots/feature-dictionary.png"
                alt="Custom Dictionary Studio"
                className="w-full object-cover"
              />
            </div>
          </div>

          {/* Card 4: Local AI Transforms & Formatting */}
          <div className="apple-panel apple-card rounded-2xl p-8 flex flex-col justify-between md:col-span-2 border border-zinc-800">
            <div>
              <div className="w-10 h-10 rounded-xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-200 mb-6">
                <Wand2 className="w-5 h-5" />
              </div>
              <span className="text-xs font-mono font-semibold text-zinc-400 uppercase tracking-wider">
                Apple Intelligence & Foundation Models
              </span>
              <h3 className="text-2xl sm:text-3xl font-bold text-white mt-2 mb-3">
                Local AI Text Transforms & Summarization
              </h3>
              <p className="text-zinc-400 text-sm sm:text-base leading-relaxed mb-6">
                Instantly transform spoken stream-of-consciousness into structured bullet points, fix filler words, translate languages, or execute custom prompt workflows via Apple Intelligence.
              </p>
            </div>
            <div className="rounded-xl overflow-hidden border border-zinc-800 shadow-2xl bg-[#121215]">
              <img
                src="/assets/screenshots/feature-transforms.png"
                alt="Transforms Studio"
                className="w-full object-cover"
              />
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
