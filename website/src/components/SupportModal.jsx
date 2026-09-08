import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, HelpCircle, Terminal, Search, ChevronDown, ChevronUp, Copy, Check, AlertCircle, Wrench, Shield, Sparkles } from 'lucide-react';

const faqs = [
  {
    q: 'Does Utter require an active internet connection?',
    a: 'No. Utter is physically incapable of making outbound network requests. All Whisper speech recognition neural weights run in your Mac’s local unified RAM using whisper.cpp with Apple Metal GPU and Neural Engine acceleration. Airplane mode works 100%.',
  },
  {
    q: 'How does Utter compare to cloud dictation subscriptions?',
    a: 'Cloud dictation services charge $8 to $15 per month to upload your voice to cloud servers with 1,400ms lag. Utter is free, open source (MIT License), runs locally with ~168ms latency, and never logs your words or code.',
  },
  {
    q: 'Are Intel Macs supported alongside Apple Silicon?',
    a: 'Yes. While Apple Silicon (M1, M2, M3, M4) benefits from Metal GPU and Accelerate.framework optimizations, Utter also compiles cleanly for Intel x86_64 Macs running macOS 14 Sonoma or later using AVX2 instructions.',
  },
  {
    q: 'Where are my recordings and transcriptions stored?',
    a: 'Transcriptions, meeting diarizations, and custom vocabulary are stored locally in plain Markdown format at ~/Library/Application Support/Utter. You can open, back up, or delete them anytime using Finder.',
  },
  {
    q: 'What is the battery impact on MacBooks?',
    a: 'Minimal. Because transcription executes in bursts using Apple Silicon unified memory and immediately yields execution back to the OS, CPU and GPU cores quickly return to idle low-power states.',
  },
];

const troubleshootingGuides = [
  {
    title: 'Microphone Permission Reset',
    desc: 'If macOS fails to detect microphone access after a system update, reset the TCC permission:',
    cmd: 'tccutil reset Microphone com.h3x.Utter',
  },
  {
    title: 'Verify Zero Outbound Network Sockets',
    desc: 'Confirm that Utter has zero open sockets during active dictation:',
    cmd: 'lsof -i -P | grep -i utter',
  },
  {
    title: 'Clear Local Whisper Model Cache',
    desc: 'Remove cached model weights to perform a fresh bundle sync:',
    cmd: 'rm -rf ~/Library/Application\\ Support/Utter/Models/*',
  },
];

export default function SupportModal({ isOpen, onClose }) {
  const [searchQuery, setSearchQuery] = useState('');
  const [expandedFaq, setExpandedFaq] = useState(0);
  const [copiedCmd, setCopiedCmd] = useState(null);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  const handleCopy = (cmd) => {
    navigator.clipboard.writeText(cmd);
    setCopiedCmd(cmd);
    setTimeout(() => setCopiedCmd(null), 2000);
  };

  if (!isOpen) return null;

  const filteredFaqs = faqs.filter(
    (f) =>
      f.q.toLowerCase().includes(searchQuery.toLowerCase()) ||
      f.a.toLowerCase().includes(searchQuery.toLowerCase())
  );

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
          className="relative w-full max-w-3xl bg-white rounded-3xl shadow-2xl border border-black/10 overflow-hidden z-10 my-8 max-h-[90vh] flex flex-col"
        >
          {/* Window Header */}
          <div className="h-12 bg-zinc-100/90 border-b border-black/5 px-5 flex items-center justify-between shrink-0">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#ff5f56] border border-black/10" />
              <div className="w-3 h-3 rounded-full bg-[#ffbd2e] border border-black/10" />
              <div className="w-3 h-3 rounded-full bg-[#27c93f] border border-black/10" />
              <span className="text-xs font-semibold text-zinc-700 ml-2">Utter Support & Documentation Hub</span>
            </div>
            <button
              onClick={onClose}
              aria-label="Close modal"
              className="w-7 h-7 rounded-full bg-zinc-200/80 hover:bg-zinc-300 text-zinc-700 flex items-center justify-center transition-colors cursor-pointer"
            >
              <X size={15} />
            </button>
          </div>

          {/* Scrollable Content */}
          <div className="p-6 sm:p-8 overflow-y-auto space-y-8">
            <div>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-mono font-bold mb-2">
                <Wrench size={13} className="text-emerald-600" />
                Knowledge Base & Self-Service Help
              </div>
              <h2 className="text-2xl sm:text-3xl font-extrabold text-zinc-900 tracking-tight">
                How can we help you dictate?
              </h2>
              <p className="text-xs sm:text-sm text-zinc-500 mt-1">
                Explore common questions, macOS security permission setup, and one-click diagnostic commands.
              </p>
            </div>

            {/* Search Input */}
            <div className="relative">
              <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search troubleshooting guides, Whisper questions, or shortcuts..."
                className="w-full pl-10 pr-4 py-2.5 rounded-2xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 bg-zinc-50/50"
              />
            </div>

            {/* Quick Terminal Fixes */}
            <div>
              <h3 className="text-sm font-bold text-zinc-900 uppercase tracking-wider mb-3 flex items-center gap-2">
                <Terminal size={15} className="text-zinc-700" />
                Quick Terminal Diagnostics
              </h3>
              <div className="space-y-3">
                {troubleshootingGuides.map((guide, idx) => (
                  <div key={idx} className="p-3.5 rounded-2xl bg-zinc-900 text-zinc-200 text-xs font-mono">
                    <div className="flex items-center justify-between mb-1.5 font-sans">
                      <span className="font-bold text-white text-xs">{guide.title}</span>
                      <button
                        onClick={() => handleCopy(guide.cmd)}
                        className="flex items-center gap-1 text-[11px] text-zinc-400 hover:text-white px-2 py-0.5 rounded bg-zinc-800 transition-colors cursor-pointer"
                      >
                        {copiedCmd === guide.cmd ? (
                          <>
                            <Check size={12} className="text-emerald-400" />
                            <span className="text-emerald-400 font-bold">Copied</span>
                          </>
                        ) : (
                          <>
                            <Copy size={12} />
                            <span>Copy</span>
                          </>
                        )}
                      </button>
                    </div>
                    <p className="font-sans text-[11px] text-zinc-400 mb-2">{guide.desc}</p>
                    <div className="bg-black/50 p-2 rounded-lg text-emerald-400 overflow-x-auto text-[11px]">
                      $ {guide.cmd}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* FAQ Accordion */}
            <div>
              <h3 className="text-sm font-bold text-zinc-900 uppercase tracking-wider mb-3 flex items-center gap-2">
                <HelpCircle size={15} className="text-zinc-700" />
                Frequently Asked Questions
              </h3>
              <div className="space-y-2.5">
                {filteredFaqs.map((faq, idx) => {
                  const isExpanded = expandedFaq === idx;
                  return (
                    <div
                      key={idx}
                      className="border border-zinc-200 rounded-2xl overflow-hidden transition-all bg-zinc-50/50"
                    >
                      <button
                        onClick={() => setExpandedFaq(isExpanded ? null : idx)}
                        className="w-full p-4 text-left flex items-center justify-between text-xs font-bold text-zinc-900 hover:bg-zinc-100/60 transition-colors cursor-pointer"
                      >
                        <span>{faq.q}</span>
                        {isExpanded ? <ChevronUp size={16} className="text-zinc-500 shrink-0" /> : <ChevronDown size={16} className="text-zinc-500 shrink-0" />}
                      </button>
                      {isExpanded && (
                        <div className="px-4 pb-4 text-xs text-zinc-600 leading-relaxed border-t border-zinc-100 pt-3">
                          {faq.a}
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
