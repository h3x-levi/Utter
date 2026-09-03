import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';

export default function FAQ() {
  const [openIdx, setOpenIdx] = useState(0);

  const faqs = [
    {
      q: 'How is Utter different from Apple’s built-in macOS dictation?',
      a: 'macOS dictation often times out, hallucinates technical jargon, and depends on cloud servers. Utter runs OpenAI’s Whisper model on Apple Silicon Metal GPU locally with phrase boosting and custom dictionary context biasing for programming syntax and code symbols.',
    },
    {
      q: 'Does it work with Cursor, Xcode, VS Code, and terminal emulators?',
      a: 'Yes! Utter uses native macOS accessibility APIs and synthetic key events to inject dictated text directly at your cursor in any active app without altering your clipboard history.',
    },
    {
      q: 'Which Apple Silicon and Intel Macs are supported?',
      a: 'Utter is compiled natively as a universal binary for Apple Silicon (M1/M2/M3/M4/Pro/Max/Ultra) with Metal GPU acceleration, as well as Intel Macs running macOS 13 (Ventura), macOS 14 (Sonoma), or macOS 15/26 (Sequoia).',
    },
    {
      q: 'How do I report bugs or submit feature feedback?',
      a: 'Utter includes a built-in issue reporting modal accessible from the Menu Bar dropdown (⌘I), Sidebar footer, or Diagnostics pane. It automatically compiles sanitized diagnostics and opens a 1-click pre-filled GitHub issue in your browser.',
    },
    {
      q: 'Is Utter really 100% free and open source?',
      a: 'Yes! Utter is fully open source under the MIT License. There are no paywalls, subscriptions, or API token fees.',
    },
  ];

  return (
    <section id="faq" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            Frequently Asked Questions
          </span>
          <h2 className="text-4xl sm:text-5xl font-extrabold text-white mt-3 tracking-tight">
            Everything you need to know.
          </h2>
        </div>

        <div className="space-y-4">
          {faqs.map((faq, idx) => (
            <div
              key={idx}
              onClick={() => setOpenIdx(openIdx === idx ? -1 : idx)}
              className="glass-panel rounded-2xl p-6 border border-white/10 cursor-pointer transition-colors hover:border-white/20"
            >
              <div className="font-bold text-white flex items-center justify-between text-base sm:text-lg">
                <span>{faq.q}</span>
                <ChevronDown
                  className={`w-5 h-5 text-orange-400 transition-transform duration-200 ${
                    openIdx === idx ? 'rotate-180' : ''
                  }`}
                />
              </div>
              {openIdx === idx && (
                <p className="text-slate-400 text-sm sm:text-base mt-4 leading-relaxed border-t border-white/5 pt-4">
                  {faq.a}
                </p>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
