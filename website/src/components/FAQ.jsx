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
    <section id="faq" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-4xl mx-auto">
        <div className="text-center mb-16">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Frequently Asked Questions
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 tracking-tight">
            Everything you need to know.
          </h2>
        </div>

        <div className="space-y-3">
          {faqs.map((faq, idx) => (
            <div
              key={idx}
              onClick={() => setOpenIdx(openIdx === idx ? -1 : idx)}
              className="apple-panel rounded-xl p-5 border border-zinc-800 cursor-pointer transition-colors hover:border-zinc-700"
            >
              <div className="font-semibold text-white flex items-center justify-between text-sm sm:text-base">
                <span>{faq.q}</span>
                <ChevronDown
                  className={`w-4 h-4 text-zinc-400 transition-transform duration-200 ${
                    openIdx === idx ? 'rotate-180' : ''
                  }`}
                />
              </div>
              {openIdx === idx && (
                <p className="text-zinc-400 text-xs sm:text-sm mt-3 leading-relaxed border-t border-zinc-800 pt-3">
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
