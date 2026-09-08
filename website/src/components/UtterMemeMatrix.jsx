import React from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { XCircle, CheckCircle2, Smile, Frown, Sparkles } from 'lucide-react';

export default function UtterMemeMatrix() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <section className="py-24 px-4 sm:px-8 w-full relative z-10">
      <div className="max-w-7xl mx-auto">
        {/* Section Header */}
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/80 backdrop-blur-md border border-black/[0.08] shadow-xs text-xs font-semibold text-zinc-800 mb-4">
            <Sparkles size={13} className="text-purple-600" />
            <span>The Reality Check</span>
          </div>
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight text-zinc-950 mb-3">
            Don't mutter. Just Utter.
          </h2>
          <p className="text-base text-zinc-600 font-normal leading-relaxed">
            The tragic comedy of paying $15/month for someone else to run open-source Whisper in a distant datacenter.
          </p>
        </div>

        {/* Side-by-Side Showdown */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-stretch">
          {/* LEFT: The Muttering Way (Cloud SaaS) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1] }}
            className="frosted-glass-card p-8 border-rose-200/80 shadow-lg relative overflow-hidden flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-rose-100 text-rose-800 text-xs font-bold border border-rose-300">
                  <Frown size={14} />
                  <span>Muttering (Cloud SaaS)</span>
                </div>
                <span className="text-xs font-mono text-zinc-500">Monthly Tax</span>
              </div>

              <h3 className="text-xl font-bold text-zinc-900 mb-6 font-display-heavy">
                The Cloud Hostage Experience
              </h3>

              <div className="space-y-4">
                {[
                  { title: "1,400ms Lag", desc: "Audio compresses, flies over HTTPS to Virginia, queues in server line, flies back." },
                  { title: "$8-15 / Month Subscription", desc: "Pay rent every single month for technology OpenAI gave away for free." },
                  { title: "Voice Telemetry", desc: "Your unreleased Swift code and whispered passwords sit in another company's logs." },
                  { title: "Dies on Airplanes", desc: "Seatbelt sign turns on, Wi-Fi drops, and your dictation app turns into an empty brick." },
                  { title: "Server 503 Outages", desc: "“We are experiencing unusually high traffic. Please type with your hands like a peasant.”" },
                ].map((item, idx) => (
                  <div key={idx} className="flex items-start gap-3">
                    <XCircle size={18} className="text-rose-500 shrink-0 mt-0.5" />
                    <div>
                      <span className="text-xs font-bold text-zinc-900 block">{item.title}</span>
                      <span className="text-[11px] text-zinc-600 leading-snug block mt-0.5">{item.desc}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-8 pt-4 border-t border-rose-200/80 text-xs font-mono text-rose-800 bg-rose-50/70 p-3.5 rounded-2xl">
              Vibe: Paying SaaS rent while your Mac M-series GPU sits idle at 2% usage.
            </div>
          </motion.div>

          {/* RIGHT: The Utter Way (Native Apple Silicon) */}
          <motion.div
            initial={shouldReduceMotion ? false : { opacity: 0, x: 20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.45, ease: [0.23, 1, 0.32, 1] }}
            className="frosted-glass-card p-8 border-emerald-300 shadow-xl relative overflow-hidden flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center justify-between mb-6">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-100 text-emerald-900 text-xs font-bold border border-emerald-300">
                  <Smile size={14} className="text-emerald-700" />
                  <span>Uttering (Native macOS)</span>
                </div>
                <span className="text-xs font-mono text-emerald-700 font-bold">100% Free Forever</span>
              </div>

              <h3 className="text-xl font-bold text-zinc-900 mb-6 font-display-heavy">
                The Apple Silicon Flex
              </h3>

              <div className="space-y-4">
                {[
                  { title: "168ms Local Latency", desc: "Whisper.cpp Metal kernels execute in unified RAM. Faster than conscious human thought." },
                  { title: "$0.00 Forever (MIT License)", desc: "Zero subscriptions. No credit card. Free, open source, yours forever." },
                  { title: "100% Air-Gapped Privacy", desc: "Zero network sockets. The audio never touches disk, let alone the internet." },
                  { title: "Works at 35,000 Feet", desc: "Type-free dictation in airplane mode on transatlantic flights without Wi-Fi." },
                  { title: "Zero Outage Anxiety", desc: "Unless someone physically steals your Mac, Utter will never fail to transcribe." },
                ].map((item, idx) => (
                  <div key={idx} className="flex items-start gap-3">
                    <CheckCircle2 size={18} className="text-emerald-600 shrink-0 mt-0.5" />
                    <div>
                      <span className="text-xs font-bold text-zinc-900 block">{item.title}</span>
                      <span className="text-[11px] text-zinc-600 leading-snug block mt-0.5">{item.desc}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-8 pt-4 border-t border-emerald-200/80 text-xs font-mono text-emerald-800 bg-emerald-50/70 p-3.5 rounded-2xl font-medium">
              Vibe: Unbothered. Speaking 180 WPM into Xcode while sipping coffee.
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  );
}
