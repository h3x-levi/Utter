import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence, useReducedMotion } from 'framer-motion';
import { X, Github, Twitter, Mail } from 'lucide-react';

export default function ConnectModal({ isOpen, onClose }) {
  const shouldReduceMotion = useReducedMotion();
  const [activeTab, setActiveTab] = useState('Community');

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
      setName('');
      setEmail('');
      setMessage('');
      setTimeout(() => {
        setIsSubmitted(false);
      }, 3000);
    }
  };

  const overlayAnim = {
    initial: { opacity: 0 },
    animate: { opacity: 1 },
    exit: { opacity: 0 }
  };

  const modalAnim = shouldReduceMotion ? {
    initial: { opacity: 0 },
    animate: { opacity: 1 },
    exit: { opacity: 0 }
  } : {
    initial: { opacity: 0, scale: 0.95 },
    animate: { opacity: 1, scale: 1 },
    exit: { opacity: 0, scale: 0.95 }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center p-4">
          <motion.div
            {...overlayAnim}
            onClick={onClose}
            className="fixed inset-0 bg-black/40 backdrop-blur-sm"
          />

          <motion.div
            {...modalAnim}
            transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }}
            className="relative bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto mt-[15vh] p-6 z-10"
          >
            <button
              onClick={onClose}
              className="absolute top-4 right-4 p-2 rounded-full hover:bg-zinc-100 text-zinc-500 transition-colors active:scale-[0.97]"
              aria-label="Close modal"
            >
              <X size={20} />
            </button>

            <div className="flex gap-6 border-b border-zinc-100 mb-6 mt-2">
              <button
                onClick={() => setActiveTab('Community')}
                className={`pb-3 text-sm transition-colors active:scale-[0.97] ${activeTab === 'Community' ? 'border-b-2 border-zinc-900 font-bold text-zinc-900' : 'text-zinc-500 hover:text-zinc-700'}`}
              >
                Community
              </button>
              <button
                onClick={() => setActiveTab('Contact')}
                className={`pb-3 text-sm transition-colors active:scale-[0.97] ${activeTab === 'Contact' ? 'border-b-2 border-zinc-900 font-bold text-zinc-900' : 'text-zinc-500 hover:text-zinc-700'}`}
              >
                Contact
              </button>
            </div>

            <div className="min-h-[250px]">
              {activeTab === 'Community' ? (
                <div className="space-y-4">
                  <a
                    href="https://github.com/h3x-levi/Utter"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-4 p-4 rounded-xl border border-zinc-200 hover:border-zinc-300 transition-colors group active:scale-[0.97]"
                  >
                    <div className="w-10 h-10 bg-zinc-100 rounded-full flex items-center justify-center text-zinc-900">
                      <Github size={20} />
                    </div>
                    <div>
                      <h3 className="font-bold text-zinc-900 text-sm">GitHub</h3>
                      <p className="text-xs text-zinc-500">View source code and contribute</p>
                    </div>
                  </a>

                  <a
                    href="https://twitter.com/utter_macos"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-4 p-4 rounded-xl border border-zinc-200 hover:border-zinc-300 transition-colors group active:scale-[0.97]"
                  >
                    <div className="w-10 h-10 bg-zinc-100 rounded-full flex items-center justify-center text-zinc-900">
                      <Twitter size={20} />
                    </div>
                    <div>
                      <h3 className="font-bold text-zinc-900 text-sm">Twitter / X</h3>
                      <p className="text-xs text-zinc-500">Follow for updates and announcements</p>
                    </div>
                  </a>

                  <a
                    href="mailto:support@utter.run"
                    className="flex items-center gap-4 p-4 rounded-xl border border-zinc-200 hover:border-zinc-300 transition-colors group active:scale-[0.97]"
                  >
                    <div className="w-10 h-10 bg-indigo-50 rounded-full flex items-center justify-center text-indigo-600">
                      <Mail size={20} />
                    </div>
                    <div>
                      <h3 className="font-bold text-zinc-900 text-sm">Email Support</h3>
                      <p className="text-xs text-zinc-500">Reach out at support@utter.run</p>
                    </div>
                  </a>
                </div>
              ) : (
                <form onSubmit={handleSubmit} className="space-y-4">
                  {isSubmitted && (
                    <div className="p-3 bg-emerald-50 text-emerald-700 rounded-xl text-sm border border-emerald-100 mb-4">
                      Message sent successfully! We will get back to you soon.
                    </div>
                  )}
                  
                  <div>
                    <input
                      type="text"
                      required
                      placeholder="Your Name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      className="w-full rounded-xl border border-zinc-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent transition-shadow"
                    />
                  </div>
                  <div>
                    <input
                      type="email"
                      required
                      placeholder="Your Email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="w-full rounded-xl border border-zinc-200 px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent transition-shadow"
                    />
                  </div>
                  <div>
                    <textarea
                      required
                      placeholder="How can we help you?"
                      rows={4}
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      className="w-full rounded-xl border border-zinc-200 px-4 py-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-zinc-900 focus:border-transparent transition-shadow"
                    />
                  </div>
                  <button
                    type="submit"
                    className="w-full bg-zinc-950 text-white rounded-full py-3 text-sm font-bold active:scale-[0.97] transition-transform hover:bg-zinc-800"
                  >
                    Send Message
                  </button>
                </form>
              )}
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
