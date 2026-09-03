import React from 'react';
import { Cpu, PhoneCall, BookOpen, Wand2 } from 'lucide-react';
import { motion } from 'framer-motion';

export default function BentoFeatures() {
  return (
    <section id="features" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Built for Extreme Speed & Craft
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Engineered like a first-party Apple utility.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl leading-relaxed">
            Zero bloat, zero cloud latency. Designed from first principles in Swift, C++, and Metal to feel like a natural part of macOS.
          </p>
        </div>

        {/* Bento Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">

          {/* Card 1: whisper.cpp on Metal GPU */}
          <motion.div
            whileHover={{ y: -6 }}
            className="glass-panel rounded-3xl p-8 flex flex-col justify-between tilt-card md:col-span-2 border border-white/10"
          >
            <div>
              <div className="w-12 h-12 rounded-2xl bg-orange-500/10 border border-orange-500/25 flex items-center justify-center text-orange-400 mb-6">
                <Cpu className="w-6 h-6" />
              </div>
              <span className="text-xs font-mono font-bold text-orange-400 uppercase tracking-wider">
                Sub-200ms Local Inference
              </span>
              <h3 className="text-2xl sm:text-3xl font-bold text-white mt-2 mb-3">
                whisper.cpp Accelerated on Apple Metal GPU
              </h3>
              <p className="text-slate-400 text-sm sm:text-base leading-relaxed mb-6">
                Utter bridges directly to whisper.cpp with native Metal shaders. Speech chunks are processed asynchronously in memory without writing temporary audio files to disk, delivering instant typing at 180+ words per minute.
              </p>
            </div>
            <div className="rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-[#12141c]">
              <img
                src="/assets/screenshots/feature-speech-models.png"
                alt="Speech Model Switcher"
                className="w-full object-cover hover:scale-102 transition-transform duration-500"
              />
            </div>
          </motion.div>

          {/* Card 2: Two-Way Meeting Taps */}
          <motion.div
            whileHover={{ y: -6 }}
            className="glass-panel rounded-3xl p-8 flex flex-col justify-between tilt-card border border-white/10"
          >
            <div>
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/25 flex items-center justify-center text-indigo-400 mb-6">
                <PhoneCall className="w-6 h-6" />
              </div>
              <span className="text-xs font-mono font-bold text-indigo-400 uppercase tracking-wider">
                Dual-Stream Capture
              </span>
              <h3 className="text-2xl font-bold text-white mt-2 mb-3">
                Two-Way Meeting Transcription
              </h3>
              <p className="text-slate-400 text-sm leading-relaxed mb-6">
                Auto-detects active calls in Zoom, Google Meet, Microsoft Teams, FaceTime, and Slack. Taps incoming system audio and your microphone simultaneously to produce clean speaker-attributed transcripts.
              </p>
            </div>
            <div className="rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-[#12141c]">
              <img
                src="/assets/screenshots/feature-notes.png"
                alt="Notes Studio & Meeting Transcripts"
                className="w-full object-cover hover:scale-102 transition-transform duration-500"
              />
            </div>
          </motion.div>

          {/* Card 3: Custom Dictionary & Phrase Boosting */}
          <motion.div
            whileHover={{ y: -6 }}
            className="glass-panel rounded-3xl p-8 flex flex-col justify-between tilt-card border border-white/10"
          >
            <div>
              <div className="w-12 h-12 rounded-2xl bg-amber-500/10 border border-amber-500/25 flex items-center justify-center text-amber-400 mb-6">
                <BookOpen className="w-6 h-6" />
              </div>
              <span className="text-xs font-mono font-bold text-amber-400 uppercase tracking-wider">
                Zero Misspellings
              </span>
              <h3 className="text-2xl font-bold text-white mt-2 mb-3">
                Dictionary & Context Biasing
              </h3>
              <p className="text-slate-400 text-sm leading-relaxed mb-6">
                Teach Utter your company’s internal codenames, developer variable names, medical terms, and acronyms. Context biasing feeds custom vocabulary directly into the Whisper decoder.
              </p>
            </div>
            <div className="rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-[#12141c]">
              <img
                src="/assets/screenshots/feature-dictionary.png"
                alt="Custom Dictionary Studio"
                className="w-full object-cover hover:scale-102 transition-transform duration-500"
              />
            </div>
          </motion.div>

          {/* Card 4: Local AI Transforms & Formatting */}
          <motion.div
            whileHover={{ y: -6 }}
            className="glass-panel rounded-3xl p-8 flex flex-col justify-between tilt-card md:col-span-2 border border-white/10"
          >
            <div>
              <div className="w-12 h-12 rounded-2xl bg-sky-500/10 border border-sky-500/25 flex items-center justify-center text-sky-400 mb-6">
                <Wand2 className="w-6 h-6" />
              </div>
              <span className="text-xs font-mono font-bold text-sky-400 uppercase tracking-wider">
                Apple Intelligence & Foundation Models
              </span>
              <h3 className="text-2xl sm:text-3xl font-bold text-white mt-2 mb-3">
                Local AI Text Transforms & Summarization
              </h3>
              <p className="text-slate-400 text-sm sm:text-base leading-relaxed mb-6">
                Instantly transform spoken stream-of-consciousness into structured bullet points, fix filler words (`um`, `ah`), translate languages, or execute custom prompt workflows via Apple Intelligence FoundationModels.
              </p>
            </div>
            <div className="rounded-2xl overflow-hidden border border-white/10 shadow-2xl bg-[#12141c]">
              <img
                src="/assets/screenshots/feature-transforms.png"
                alt="Transforms Studio"
                className="w-full object-cover hover:scale-102 transition-transform duration-500"
              />
            </div>
          </motion.div>

        </div>

      </div>
    </section>
  );
}
