import React from 'react';
import { motion } from 'framer-motion';
import { Download, Github } from 'lucide-react';

const Hero = () => {
  return (
    <section className="relative pt-40 pb-20 px-4 overflow-visible">
      {/* Atmospheric top vignette — fades hero into canvas */}
      <div
        className="absolute inset-x-0 top-0 h-[200px] pointer-events-none z-0"
        style={{ background: 'linear-gradient(#edeceb 0%, transparent 100%)' }}
      />

      <div className="max-w-5xl mx-auto text-center flex flex-col items-center relative z-10">
        {/* Badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="font-mono-sm text-xs font-medium px-4 py-1.5 rounded-full border border-black/10 bg-white/40 backdrop-blur-sm mb-8 text-black/50 inline-flex items-center gap-2"
        >
          <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
          100% On-Device · Zero Telemetry · MIT License
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.1 }}
          className="text-5xl sm:text-6xl md:text-[76px] font-black leading-[1.06] tracking-tight mb-6 max-w-4xl"
        >
          Voice dictation that stays on your Mac.
        </motion.h1>

        {/* Subtitle */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="text-lg md:text-xl text-[#0d0d0d]/60 max-w-2xl mb-10 leading-relaxed"
        >
          Hold a key, speak, let go. Utter transcribes at 180 WPM using local Whisper models
          on Apple Silicon — no cloud, no subscription, no data leaves your device.
        </motion.p>

        {/* Buttons */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.3 }}
          className="flex flex-col sm:flex-row items-center gap-4 mb-6"
        >
          <a
            href="https://github.com/h3x-levi/Utter/releases/latest"
            className="flex items-center gap-2.5 bg-[#0d0d0d] text-white px-8 py-4 rounded-full font-semibold text-[15px] hover:bg-black/80 transition-all active:scale-[0.97] shadow-lg"
          >
            <Download size={18} />
            Download for Mac
          </a>
          <a
            href="https://github.com/h3x-levi/Utter"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2.5 border-2 border-black/10 text-[#0d0d0d] px-8 py-4 rounded-full font-semibold text-[15px] hover:bg-black/5 transition-all active:scale-[0.97]"
          >
            <Github size={18} />
            View on GitHub
          </a>
        </motion.div>

        {/* Integration micro-chips */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 0.5, delay: 0.5 }}
          className="flex flex-wrap justify-center gap-4 text-[13px] text-black/40 font-medium mb-16"
        >
          {['Xcode', 'Cursor', 'VS Code', 'Slack', 'Obsidian', 'Notion', 'Terminal', 'Pages'].map((app) => (
            <span key={app}>{app}</span>
          ))}
        </motion.div>

        {/* ===================== */}
        {/* 3D GLASS DISPLAY FRAME */}
        {/* ===================== */}
        <motion.div
          initial={{ opacity: 0, y: 50 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
          className="relative w-full max-w-[948px] mx-auto z-10"
        >
          <div className="glass-panel p-2 md:p-3 relative group" style={{ aspectRatio: '16 / 9' }}>
            {/* macOS Menu Bar */}
            <div className="absolute top-4 left-0 right-0 px-5 md:px-6 flex items-center justify-between z-20 text-[11px] font-medium text-black/50">
              <div className="flex items-center gap-2">
                <div className="w-[10px] h-[10px] rounded-full bg-[#ff5f56]" />
                <div className="w-[10px] h-[10px] rounded-full bg-[#ffbd2e]" />
                <div className="w-[10px] h-[10px] rounded-full bg-[#27c93f]" />
              </div>
              <span className="font-mono-sm text-[10px] text-black/30">Utter v1.1.56</span>
            </div>

            {/* Screenshot */}
            <img
              src="/assets/screenshots/hero-main.png"
              alt="Utter — macOS Voice Dictation App"
              className="rounded-[22px] w-full h-full object-cover relative z-10"
            />
          </div>

          {/* Left floating 3D side card */}
          <motion.div
            animate={{ y: [0, -8, 0] }}
            transition={{ duration: 5, repeat: Infinity, ease: 'easeInOut' }}
            className="absolute -left-16 top-1/4 w-[220px] hidden lg:block z-20"
            style={{ transform: 'rotateY(12deg) rotateX(3deg)', transformStyle: 'preserve-3d' }}
          >
            <div className="glass-panel-sm p-1.5 shadow-2xl">
              <img src="/assets/screenshots/06_model_chooser.png" alt="Model Chooser" className="rounded-[14px] w-full" />
            </div>
          </motion.div>

          {/* Right floating 3D side card */}
          <motion.div
            animate={{ y: [0, -10, 0] }}
            transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut', delay: 1 }}
            className="absolute -right-16 bottom-1/4 w-[220px] hidden lg:block z-20"
            style={{ transform: 'rotateY(-12deg) rotateX(3deg)', transformStyle: 'preserve-3d' }}
          >
            <div className="glass-panel-sm p-1.5 shadow-2xl">
              <img src="/assets/screenshots/04_notes_studio.png" alt="Notes Studio" className="rounded-[14px] w-full" />
            </div>
          </motion.div>
        </motion.div>

        {/* Bottom atmospheric vignette */}
        <div
          className="absolute inset-x-0 bottom-0 h-[250px] pointer-events-none z-0"
          style={{ background: 'linear-gradient(transparent 0%, #edeceb 100%)' }}
        />
      </div>
    </section>
  );
};

export default Hero;
