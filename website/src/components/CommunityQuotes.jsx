import React from 'react';
import { Star, MessageSquareQuote, Shield, Cpu, Terminal } from 'lucide-react';

export default function CommunityQuotes() {
  const reviews = [
    {
      name: 'Alex Rivera',
      role: 'Staff iOS & macOS Engineer',
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      text: 'The sub-200ms latency on Apple Silicon is real. Dictating complex Swift generics and closures into Xcode without the app locking up or corrupting my clipboard is unmatched.',
      tag: 'Xcode & Swift Dev',
    },
    {
      name: 'Dr. Sarah Chen',
      role: 'Bioinformatics Researcher',
      avatar: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150&auto=format&fit=crop&q=80',
      text: 'We work with confidential genomic data where cloud speech APIs are strictly prohibited. Utter being 100% offline and air-gapped allows me to dictate research papers securely.',
      tag: 'Medical & Research',
    },
    {
      name: 'Marcus Vance',
      role: 'Senior Backend Architect',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      text: 'Having the pixel cat companion sit next to my terminal while dictating pull request summaries is the most joyful detail I didn’t know I needed. High-craft macOS software.',
      tag: 'Rust & Distributed Systems',
    },
  ];

  return (
    <section id="community" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-amber-400 font-bold">
            Built for Developers & Writers
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Loved by engineers who value privacy and speed.
          </h2>
        </div>

        {/* Reviews Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {reviews.map((r, idx) => (
            <div
              key={idx}
              className="glass-panel rounded-3xl p-8 border border-white/10 flex flex-col justify-between tilt-card"
            >
              <div>
                <div className="flex items-center gap-1 text-amber-400 mb-6">
                  {[...Array(5)].map((_, i) => (
                    <Star key={i} className="w-4 h-4 fill-amber-400" />
                  ))}
                </div>
                <p className="text-slate-300 text-sm sm:text-base leading-relaxed mb-8">
                  "{r.text}"
                </p>
              </div>

              <div className="flex items-center justify-between pt-6 border-t border-white/10">
                <div className="flex items-center gap-3">
                  <img src={r.avatar} alt={r.name} className="w-10 h-10 rounded-full object-cover border border-white/15" />
                  <div>
                    <h5 className="text-sm font-bold text-white">{r.name}</h5>
                    <p className="text-xs text-slate-400">{r.role}</p>
                  </div>
                </div>
                <span className="text-[10px] font-mono text-orange-400 bg-orange-500/10 px-2.5 py-1 rounded-full border border-orange-500/20">
                  {r.tag}
                </span>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
