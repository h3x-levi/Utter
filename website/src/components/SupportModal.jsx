import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, HelpCircle, Terminal, Search, ChevronDown, ChevronUp, Copy, Check, Shield, Sparkles } from 'lucide-react';

const FAQS = [
  {
    q: 'Does Utter require an active internet connection?',
    a: 'No. Utter is physically incapable of making outbound network requests. All Whisper speech recognition neural weights run in your Mac’s local unified RAM using whisper.cpp with Apple Metal GPU and Neural Engine acceleration. Airplane mode works 100%.',
  },
  {
    q: 'How does Utter compare to cloud dictation subscriptions?',
    a: 'Cloud dictation services charge $10 to $20 per month to stream your voice to cloud datacenters with 1,400ms lag. Utter is free, open source (Apache 2.0), runs locally with ~168ms latency, and never logs your words, code, or personal notes.',
  },
  {
    q: 'Are Intel Macs supported alongside Apple Silicon?',
    a: 'Yes. While Apple Silicon (M1, M2, M3, M4) benefits from Metal GPU and Accelerate.framework optimizations, Utter also compiles cleanly for Intel x86_64 Macs running macOS 13.3 or later using AVX2 instructions.',
  },
  {
    q: 'Where are my recordings and transcriptions stored?',
    a: 'Transcriptions, meeting notes, and custom vocabulary are stored locally on your device at ~/Library/Application Support/Utter. You can open, back up, or delete them anytime using Finder.',
  },
  {
    q: 'What is the battery impact on MacBooks?',
    a: 'Minimal. Because transcription executes in sub-200ms bursts using Apple Silicon unified memory and immediately yields execution back to macOS, CPU and GPU cores quickly return to idle low-power states.',
  },
];

const TROUBLESHOOTING = [
  {
    title: 'Microphone Permission Reset',
    desc: 'If macOS fails to prompt for microphone access, reset the TCC permission in Terminal:',
    cmd: 'tccutil reset Microphone com.hexlevi.Utter',
  },
  {
    title: 'Verify Zero Outbound Network Sockets',
    desc: 'Confirm that Utter has zero open sockets during active dictation:',
    cmd: 'sudo lsof -i -P | grep -i utter',
  },
  {
    title: 'Homebrew Reinstall or Upgrade',
    desc: 'Upgrade Utter to the latest release via Homebrew:',
    cmd: 'brew upgrade --cask utter',
  },
];

export default function SupportModal({ isOpen, onClose }) {
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedFaq, setExpandedFaq] = useState(0);
  const [copiedCmd, setCopiedCmd] = useState(null);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isOpen) onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  const handleCopy = (cmd) => {
    navigator.clipboard.writeText(cmd);
    setCopiedCmd(cmd);
    setTimeout(() => setCopiedCmd(null), 2000);
  };

  const filteredFaqs = FAQS.filter(
    (f) =>
      f.q.toLowerCase().includes(searchQuery.toLowerCase()) ||
      f.a.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/70 backdrop-blur-md"
          />

          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 15 }}
            transition={{ type: 'spring', stiffness: 420, damping: 32 }}
            className="relative liquid-glass bg-zinc-950/95 text-zinc-100 rounded-3xl border border-white/15 shadow-2xl w-full max-w-2xl max-h-[85vh] overflow-y-auto p-6 sm:p-8 z-10"
          >
            <button
              onClick={onClose}
              className="absolute top-5 right-5 p-2 rounded-full bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors"
              aria-label="Close modal"
            >
              <X size={18} />
            </button>

            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 rounded-2xl bg-orange-500/10 text-orange-400 flex items-center justify-center border border-orange-500/20">
                <HelpCircle size={20} />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">Support & Diagnostics</h3>
                <p className="text-xs text-zinc-400 font-mono">Frequently asked questions & terminal troubleshooting</p>
              </div>
            </div>

            {/* Search Input */}
            <div className="relative mb-6">
              <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-400" />
              <input
                type="text"
                placeholder="Search questions or diagnostic commands..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-zinc-900 border border-white/10 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-orange-500/60 transition-colors"
              />
            </div>

            {/* FAQs Accordion */}
            <div className="space-y-2 mb-8">
              <div className="text-xs uppercase font-mono text-zinc-400 mb-3">Frequently Asked Questions</div>
              {filteredFaqs.map((faq, idx) => {
                const isExpanded = expandedFaq === idx;
                return (
                  <div
                    key={faq.q}
                    className="rounded-xl bg-zinc-900/60 border border-white/5 overflow-hidden transition-colors"
                  >
                    <button
                      onClick={() => setExpandedFaq(isExpanded ? null : idx)}
                      className="w-full px-4 py-3 text-left flex items-center justify-between gap-3 text-xs font-semibold text-zinc-200 hover:text-white transition-colors"
                    >
                      <span>{faq.q}</span>
                      <motion.div
                        animate={{ rotate: isExpanded ? 180 : 0 }}
                        transition={{ type: 'spring', stiffness: 450, damping: 28 }}
                        className="shrink-0"
                      >
                        <ChevronDown size={14} className={isExpanded ? 'text-orange-400' : 'text-zinc-400'} />
                      </motion.div>
                    </button>
                    <AnimatePresence initial={false}>
                      {isExpanded && (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: 'auto', opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.24, ease: [0.16, 1, 0.3, 1] }}
                          className="overflow-hidden"
                        >
                          <div className="px-4 pb-3.5 pt-1 text-xs text-zinc-400 leading-relaxed border-t border-white/5 font-sans">
                            {faq.a}
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>
                );
              })}
            </div>

            {/* Terminal Troubleshooting Commands */}
            <div className="space-y-3 pt-4 border-t border-white/10">
              <div className="text-xs uppercase font-mono text-zinc-400">Terminal Diagnostics</div>
              {TROUBLESHOOTING.map((item) => (
                <div key={item.title} className="p-4 rounded-xl bg-zinc-900/90 border border-white/5">
                  <div className="text-xs font-bold text-white mb-1">{item.title}</div>
                  <div className="text-[11px] text-zinc-400 mb-2">{item.desc}</div>
                  <div className="flex items-center justify-between p-2 rounded-lg bg-zinc-950 font-mono text-[11px] text-orange-400 border border-white/5">
                    <code>{item.cmd}</code>
                    <motion.button
                      onClick={() => handleCopy(item.cmd)}
                      whileTap={{ scale: 0.9 }}
                      className="p-1 text-zinc-400 hover:text-white transition-colors"
                      title="Copy command"
                    >
                      {copiedCmd === item.cmd ? <Check size={13} className="text-emerald-400" /> : <Copy size={13} />}
                    </motion.button>
                  </div>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
