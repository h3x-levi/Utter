import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Github, Twitter, Mail, MessageSquare, Send, Check } from 'lucide-react';

export default function ConnectModal({ isOpen, onClose }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [isSubmitted, setIsSubmitted] = useState(false);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isOpen) onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (name && email && message) {
      setIsSubmitted(true);
      setTimeout(() => {
        setIsSubmitted(false);
        onClose();
      }, 2000);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/70 backdrop-blur-md"
          />

          {/* Modal Container */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 15 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 15 }}
            transition={{ type: 'spring', stiffness: 420, damping: 32 }}
            className="relative liquid-glass bg-zinc-950/95 text-zinc-100 rounded-3xl border border-white/15 shadow-2xl w-full max-w-lg p-6 sm:p-8 z-10"
          >
            <button
              onClick={onClose}
              className="absolute top-5 right-5 p-2 rounded-full bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors"
              aria-label="Close modal"
            >
              <X size={18} />
            </button>

            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-2xl bg-orange-500/10 text-orange-400 flex items-center justify-center border border-orange-500/20">
                <MessageSquare size={20} />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">Join the Community</h3>
                <p className="text-xs text-zinc-400 font-mono">Connect with Utter engineers & users</p>
              </div>
            </div>

            {/* Social Links */}
            <div className="grid grid-cols-2 gap-3 mb-6">
              <motion.a
                href="https://github.com/h3x-levi/Utter"
                target="_blank"
                rel="noopener noreferrer"
                whileHover={{ y: -2 }}
                whileTap={{ scale: 0.97 }}
                className="flex items-center gap-2.5 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-800/80 border border-white/10 text-xs font-semibold text-zinc-200 transition-colors"
              >
                <Github size={16} />
                <span>GitHub Repo</span>
              </motion.a>
              <motion.a
                href="https://twitter.com"
                target="_blank"
                rel="noopener noreferrer"
                whileHover={{ y: -2 }}
                whileTap={{ scale: 0.97 }}
                className="flex items-center gap-2.5 p-3 rounded-xl bg-zinc-900/80 hover:bg-zinc-800/80 border border-white/10 text-xs font-semibold text-zinc-200 transition-colors"
              >
                <Twitter size={16} className="text-sky-400" />
                <span>Follow on X</span>
              </motion.a>
            </div>

            {/* Direct Feedback Form */}
            <form onSubmit={handleSubmit} className="space-y-3.5">
              <div className="text-xs font-mono uppercase text-zinc-400">Send Direct Feedback</div>

              <input
                type="text"
                placeholder="Your Name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                className="w-full px-4 py-2.5 rounded-xl bg-zinc-900 border border-white/10 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-orange-500/60 transition-colors"
              />

              <input
                type="email"
                placeholder="Email Address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full px-4 py-2.5 rounded-xl bg-zinc-900 border border-white/10 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-orange-500/60 transition-colors"
              />

              <textarea
                placeholder="How are you using Utter? Feature ideas, bugs, or feedback..."
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                required
                rows={3}
                className="w-full px-4 py-2.5 rounded-xl bg-zinc-900 border border-white/10 text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-orange-500/60 resize-none transition-colors"
              />

              <motion.button
                type="submit"
                disabled={isSubmitted}
                whileTap={{ scale: 0.96 }}
                transition={{ type: 'spring', stiffness: 450, damping: 25 }}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-orange-400 to-amber-300 hover:from-orange-300 hover:to-amber-200 text-zinc-950 text-xs font-bold shadow-lg shadow-orange-500/20 flex items-center justify-center gap-2 transition-all cursor-pointer"
              >
                {isSubmitted ? (
                  <>
                    <Check size={14} className="text-zinc-950" />
                    <span>Message Sent! Thank you.</span>
                  </>
                ) : (
                  <>
                    <Send size={14} />
                    <span>Send Message</span>
                  </>
                )}
              </motion.button>
            </form>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
