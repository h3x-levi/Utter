import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Github, MessageCircle, Twitter, Heart, Sparkles, Terminal, Bell, CheckCircle2, ArrowUpRight, Share2, Code } from 'lucide-react';

export default function ConnectModal({ isOpen, onClose }) {
  const [emailSubscribed, setEmailSubscribed] = useState(false);
  const [subEmail, setSubEmail] = useState('');

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  const handleSubscribe = (e) => {
    e.preventDefault();
    if (!subEmail) return;
    setEmailSubscribed(true);
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 overflow-y-auto">
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={onClose}
          className="fixed inset-0 bg-black/40 backdrop-blur-sm"
        />

        {/* Modal Window */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 15 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 15 }}
          transition={{ duration: 0.2, ease: 'easeOut' }}
          className="relative w-full max-w-2xl bg-white rounded-3xl shadow-2xl border border-black/10 overflow-hidden z-10 my-8"
        >
          {/* Window Header */}
          <div className="h-12 bg-zinc-100/90 border-b border-black/5 px-5 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#ff5f56] border border-black/10" />
              <div className="w-3 h-3 rounded-full bg-[#ffbd2e] border border-black/10" />
              <div className="w-3 h-3 rounded-full bg-[#27c93f] border border-black/10" />
              <span className="text-xs font-semibold text-zinc-700 ml-2">Connect with Utter Community</span>
            </div>
            <button
              onClick={onClose}
              aria-label="Close modal"
              className="w-7 h-7 rounded-full bg-zinc-200/80 hover:bg-zinc-300 text-zinc-700 flex items-center justify-center transition-colors cursor-pointer"
            >
              <X size={15} />
            </button>
          </div>

          <div className="p-6 sm:p-8 space-y-6">
            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-50 border border-indigo-200 text-indigo-700 text-xs font-mono font-bold mb-2">
                <Sparkles size={12} className="text-indigo-600" />
                Community & Developer Ecosystem
              </div>
              <h2 className="text-2xl sm:text-3xl font-extrabold text-zinc-900 tracking-tight">
                Join the local AI voice movement.
              </h2>
              <p className="text-xs sm:text-sm text-zinc-500 mt-1">
                Utter is built openly with developers, researchers, and writers around the globe. Join discussions, share companion packs, and request features.
              </p>
            </div>

            {/* Connection Cards Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* GitHub */}
              <a
                href="https://github.com/h3x-levi/Utter"
                target="_blank"
                rel="noopener noreferrer"
                className="card-opaque-sm p-4 hover:border-black/30 transition-all group flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="w-9 h-9 rounded-xl bg-zinc-900 text-white flex items-center justify-center">
                      <Github size={18} />
                    </div>
                    <ArrowUpRight size={16} className="text-zinc-400 group-hover:text-zinc-900 transition-colors" />
                  </div>
                  <h3 className="font-bold text-sm text-zinc-900 mb-1">GitHub Repository</h3>
                  <p className="text-xs text-zinc-500 leading-relaxed">
                    Fork the codebase, explore whisper.cpp C-FFI bridges, submit pull requests, or star the project.
                  </p>
                </div>
                <span className="text-[11px] font-mono text-zinc-400 mt-3 block">h3x-levi/Utter</span>
              </a>

              {/* Discord */}
              <a
                href="https://discord.gg"
                target="_blank"
                rel="noopener noreferrer"
                className="card-opaque-sm p-4 hover:border-indigo-300 transition-all group flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="w-9 h-9 rounded-xl bg-indigo-600 text-white flex items-center justify-center">
                      <MessageCircle size={18} />
                    </div>
                    <ArrowUpRight size={16} className="text-zinc-400 group-hover:text-indigo-600 transition-colors" />
                  </div>
                  <h3 className="font-bold text-sm text-zinc-900 mb-1">Discord Community</h3>
                  <p className="text-xs text-zinc-500 leading-relaxed">
                    Chat with macOS engineers, share custom pixel pet sprite packs, and discover custom whisper prompts.
                  </p>
                </div>
                <span className="text-[11px] font-mono text-indigo-600 mt-3 block">discord.gg/utter</span>
              </a>

              {/* X / Twitter */}
              <a
                href="https://twitter.com"
                target="_blank"
                rel="noopener noreferrer"
                className="card-opaque-sm p-4 hover:border-zinc-400 transition-all group flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="w-9 h-9 rounded-xl bg-zinc-100 text-zinc-900 border border-zinc-200 flex items-center justify-center">
                      <Twitter size={18} />
                    </div>
                    <ArrowUpRight size={16} className="text-zinc-400 group-hover:text-zinc-900 transition-colors" />
                  </div>
                  <h3 className="font-bold text-sm text-zinc-900 mb-1">X / Twitter Updates</h3>
                  <p className="text-xs text-zinc-500 leading-relaxed">
                    Follow release drops, preview benchmarks against cloud dictation, and feature demos.
                  </p>
                </div>
                <span className="text-[11px] font-mono text-zinc-500 mt-3 block">@utter_macos</span>
              </a>

              {/* Open Source Specs */}
              <div className="card-opaque-sm p-4 bg-zinc-50 border-zinc-200/80 flex flex-col justify-between">
                <div>
                  <div className="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center mb-2">
                    <Code size={18} />
                  </div>
                  <h3 className="font-bold text-sm text-zinc-900 mb-1">MIT Open Source</h3>
                  <p className="text-xs text-zinc-500 leading-relaxed">
                    100% free software forever. No proprietary cloud backends. No lock-in or telemetry.
                  </p>
                </div>
                <span className="text-[11px] font-mono text-emerald-700 font-bold mt-3 block">Pure Swift & C++</span>
              </div>
            </div>

            {/* Newsletter / Release Notification */}
            <div className="p-5 rounded-2xl bg-zinc-900 text-white shadow-lg">
              <div className="flex items-center gap-2 mb-2">
                <Bell size={16} className="text-amber-400" />
                <h4 className="font-bold text-sm">Release Notifications</h4>
              </div>
              <p className="text-xs text-zinc-400 mb-3 leading-relaxed">
                Receive notifications when new native DMG updates, CoreML models, or companion packs release. Zero spam.
              </p>

              {emailSubscribed ? (
                <div className="flex items-center gap-2 text-xs font-bold text-emerald-400 bg-emerald-950/60 p-2.5 rounded-xl border border-emerald-800">
                  <CheckCircle2 size={16} />
                  <span>Subscribed! You will receive new version alerts.</span>
                </div>
              ) : (
                <form onSubmit={handleSubscribe} className="flex gap-2">
                  <input
                    type="email"
                    required
                    placeholder="dev@macbook.local"
                    value={subEmail}
                    onChange={(e) => setSubEmail(e.target.value)}
                    className="flex-1 px-3.5 py-2 rounded-xl text-xs bg-zinc-800 border border-zinc-700 text-white placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-white"
                  />
                  <button
                    type="submit"
                    className="px-5 py-2 rounded-xl bg-white text-zinc-900 font-bold text-xs hover:bg-zinc-200 transition-colors shrink-0 cursor-pointer"
                  >
                    Notify Me
                  </button>
                </form>
              )}
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
