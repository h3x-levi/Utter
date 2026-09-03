import React from 'react';
import { motion } from 'framer-motion';

const features = [
  {
    id: 'dictation',
    title: 'Dictation',
    heading: 'Dictate into any app.',
    description:
      'Hold a hotkey, speak naturally, release. Text appears at your cursor in Xcode, Cursor, Slack, Obsidian — without touching your clipboard. Sub-200ms latency on Apple Silicon.',
    image: '/assets/screenshots/hero-main.png',
  },
  {
    id: 'meetings',
    title: 'Meeting Transcription',
    heading: 'Transcribe meetings with speaker attribution.',
    description:
      'Dual-channel capture for Zoom, Google Meet, and Teams. Automatically separates your microphone from the remote system audio with per-speaker timestamps.',
    image: '/assets/screenshots/04_notes_studio.png',
  },
  {
    id: 'transforms',
    title: 'AI Transforms',
    heading: 'Polish text with Apple Intelligence.',
    description:
      'Clean grammar and filler words, extract action items, generate Swift docstrings — all processed securely on-device using local Foundation Models.',
    image: '/assets/screenshots/10_transforms_hub.png',
  },
  {
    id: 'models',
    title: 'Speech Models',
    heading: 'Choose your Whisper model.',
    description:
      'From Tiny (39 MB) to Large-v3-Turbo (809 MB). Small.en is bundled out of the box — zero downloads needed. Swap models anytime with one click.',
    image: '/assets/screenshots/06_model_chooser.png',
  },
  {
    id: 'companions',
    title: 'Pixel Companions',
    heading: 'Desktop coding companions.',
    description:
      'Retro pixel pets that sit on your desktop, track your cursor, react to voice amplitude, and play with yarn while you dictate. Classic Cat, Calico, Tuxedo, and Corgi.',
    image: '/assets/screenshots/05b_companion_customize.png',
  },
  {
    id: 'dictionary',
    title: 'Dictionary & Snippets',
    heading: 'Custom developer vocabulary.',
    description:
      'Add Swift, Rust, or medical terms for 100% accurate context-biased dictation. Define custom snippet macros that expand shorthand into full code blocks.',
    image: '/assets/screenshots/08_dictionary_studio.png',
  },
];

const FeatureShowcase = () => {
  return (
    <section id="features" className="py-20 px-4">
      <div className="max-w-6xl mx-auto space-y-32">
        {features.map((feature, index) => {
          const isReversed = index % 2 !== 0;
          return (
            <div
              key={feature.id}
              className={`flex flex-col lg:flex-row items-center gap-12 lg:gap-20 ${
                isReversed ? 'lg:flex-row-reverse' : ''
              }`}
            >
              {/* Text */}
              <motion.div
                initial={{ opacity: 0, x: isReversed ? 30 : -30 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true, margin: '-80px' }}
                transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
                className="flex-1 space-y-5"
              >
                <div className="flex items-center gap-3 font-mono-sm text-xs uppercase tracking-widest text-black/35">
                  <span className="w-8 h-px bg-black/15 block" />
                  {feature.title}
                </div>
                <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-[#0d0d0d] leading-[1.1]">
                  {feature.heading}
                </h2>
                <p className="text-base lg:text-lg text-black/55 leading-relaxed max-w-md">
                  {feature.description}
                </p>
              </motion.div>

              {/* Screenshot in glass frame */}
              <motion.div
                initial={{ opacity: 0, scale: 0.85, y: 60 }}
                whileInView={{ opacity: 1, scale: 1, y: 0 }}
                viewport={{ once: true, margin: '-120px' }}
                transition={{ duration: 1.2, ease: [0.16, 1, 0.3, 1] }}
                className="flex-[1.3] w-full"
              >
                <motion.div 
                  whileHover={{ scale: 1.03 }}
                  transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  className="glass-panel p-2 overflow-hidden cursor-pointer shadow-[0_20px_50px_rgba(0,0,0,0.1)]"
                >
                  <motion.img
                    whileHover={{ scale: 1.08 }}
                    transition={{ duration: 0.6, ease: "easeOut" }}
                    src={feature.image}
                    alt={feature.heading}
                    className="w-full h-auto rounded-[22px]"
                  />
                </motion.div>
              </motion.div>
            </div>
          );
        })}
      </div>
    </section>
  );
};

export default FeatureShowcase;
