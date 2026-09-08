import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Mail, MessageSquare, ShieldCheck, Send, CheckCircle2, Bug, Lightbulb, Building2, Lock } from 'lucide-react';

export default function ContactModal({ isOpen, onClose }) {
  const [category, setCategory] = useState('bug');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    osVersion: 'macOS 15 Sequoia',
    chipset: 'Apple Silicon (M-series)',
    message: '',
  });
  const [submitted, setSubmitted] = useState(false);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  const handleSubmit = (e) => {
    e.preventDefault();
    setSending(true);
    setTimeout(() => {
      setSending(false);
      setSubmitted(true);
    }, 800);
  };

  const handleReset = () => {
    setSubmitted(false);
    setFormData({
      name: '',
      email: '',
      osVersion: 'macOS 15 Sequoia',
      chipset: 'Apple Silicon (M-series)',
      message: '',
    });
    onClose();
  };

  if (!isOpen) return null;

  const categories = [
    { id: 'bug', label: 'Bug Report', icon: Bug },
    { id: 'feature', label: 'Feature Request', icon: Lightbulb },
    { id: 'enterprise', label: 'Team / Enterprise', icon: Building2 },
    { id: 'security', label: 'Security Advisory', icon: Lock },
  ];

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
              <span className="text-xs font-semibold text-zinc-700 ml-2">Contact Utter Engineering</span>
            </div>
            <button
              onClick={onClose}
              aria-label="Close modal"
              className="w-7 h-7 rounded-full bg-zinc-200/80 hover:bg-zinc-300 text-zinc-700 flex items-center justify-center transition-colors cursor-pointer"
            >
              <X size={15} />
            </button>
          </div>

          <div className="p-6 sm:p-8">
            {submitted ? (
              <div className="text-center py-10 space-y-4">
                <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto mb-4">
                  <CheckCircle2 size={36} />
                </div>
                <h3 className="text-2xl font-extrabold text-zinc-900">Message Received</h3>
                <p className="text-sm text-zinc-600 max-w-md mx-auto leading-relaxed">
                  Thank you for reaching out. Your transmission has been logged directly for the Utter core engineers. We typically reply within 24 hours.
                </p>
                <button
                  onClick={handleReset}
                  className="mt-6 px-6 py-2.5 bg-zinc-900 text-white rounded-full text-xs font-bold hover:bg-black transition-colors cursor-pointer"
                >
                  Close Window
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div>
                  <h2 className="text-2xl font-extrabold text-zinc-900 tracking-tight">
                    Get in touch with the builders.
                  </h2>
                  <p className="text-xs sm:text-sm text-zinc-500 mt-1">
                    Have a technical question, spotted a whisper decoding edge-case, or need enterprise deployment help?
                  </p>
                </div>

                {/* Category Pills */}
                <div>
                  <label className="block text-xs font-bold text-zinc-700 uppercase tracking-wider mb-2">
                    Topic
                  </label>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    {categories.map((cat) => {
                      const Icon = cat.icon;
                      const isSelected = category === cat.id;
                      return (
                        <button
                          key={cat.id}
                          type="button"
                          onClick={() => setCategory(cat.id)}
                          className={`flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold border transition-all cursor-pointer ${
                            isSelected
                              ? 'bg-zinc-900 text-white border-zinc-900 shadow-sm'
                              : 'bg-zinc-50 text-zinc-700 border-zinc-200 hover:bg-zinc-100'
                          }`}
                        >
                          <Icon size={14} />
                          {cat.label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Name & Email Row */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                      Your Name
                    </label>
                    <input
                      type="text"
                      required
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      placeholder="Alex Mercer"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent bg-zinc-50/50"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                      Email Address
                    </label>
                    <input
                      type="email"
                      required
                      value={formData.email}
                      onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                      placeholder="alex@company.com"
                      className="w-full px-3.5 py-2.5 rounded-xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent bg-zinc-50/50"
                    />
                  </div>
                </div>

                {/* macOS & Chipset Row */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                      macOS Version
                    </label>
                    <select
                      value={formData.osVersion}
                      onChange={(e) => setFormData({ ...formData, osVersion: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 bg-zinc-50/50 cursor-pointer"
                    >
                      <option value="macOS 15 Sequoia">macOS 15 Sequoia (Recommended)</option>
                      <option value="macOS 14 Sonoma">macOS 14 Sonoma</option>
                      <option value="macOS 13 Ventura">macOS 13 Ventura</option>
                      <option value="Other / Beta">macOS Beta / Developer Seed</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-zinc-700 mb-1">
                      Mac Architecture
                    </label>
                    <select
                      value={formData.chipset}
                      onChange={(e) => setFormData({ ...formData, chipset: e.target.value })}
                      className="w-full px-3.5 py-2.5 rounded-xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 bg-zinc-50/50 cursor-pointer"
                    >
                      <option value="Apple Silicon (M-series)">Apple Silicon (M1 / M2 / M3 / M4)</option>
                      <option value="Intel x86_64">Intel Core (x86_64)</option>
                    </select>
                  </div>
                </div>

                {/* Message Box */}
                <div>
                  <label className="block text-xs font-bold text-zinc-700 mb-1">
                    Message
                  </label>
                  <textarea
                    required
                    rows={4}
                    value={formData.message}
                    onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                    placeholder="Describe your question, issue, or deployment requirement..."
                    className="w-full px-3.5 py-2.5 rounded-xl border border-zinc-200 text-xs text-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent bg-zinc-50/50 resize-none"
                  />
                </div>

                {/* Privacy Badge & Submit Button */}
                <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-2">
                  <div className="flex items-center gap-2 text-[11px] text-zinc-500">
                    <ShieldCheck size={15} className="text-emerald-600 shrink-0" />
                    <span>Air-gapped guarantee: Zero telemetry cookies attached.</span>
                  </div>

                  <button
                    type="submit"
                    disabled={sending}
                    className="w-full sm:w-auto px-7 py-3 rounded-full bg-zinc-900 text-white font-bold text-xs hover:bg-black transition-all flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50 cursor-pointer shadow-md"
                  >
                    {sending ? (
                      <span>Sending...</span>
                    ) : (
                      <>
                        <Send size={13} />
                        <span>Send Message</span>
                      </>
                    )}
                  </button>
                </div>
              </form>
            )}
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
}
