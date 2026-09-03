import React from 'react';
import { ShieldCheck, Lock, WifiOff, Terminal, FileCode, Check } from 'lucide-react';

export default function PrivacySection() {
  return (
    <section id="privacy" className="py-24 px-4 bg-zinc-50 border-t border-black/[0.06]">
      <div className="max-w-5xl mx-auto">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-50 text-emerald-800 border border-emerald-200 text-xs font-mono font-bold mb-3">
            <ShieldCheck size={14} className="text-emerald-600" />
            Zero Telemetry · Zero Cloud
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight text-zinc-900 mb-4">
            Air-gapped by architecture.
          </h2>
          <p className="text-base text-zinc-600 leading-relaxed">
            Unlike cloud dictation tools, Utter physically lacks the code to transmit your voice. No audio leaves your Mac, no subscriptions, and no tracking.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          {/* Left Feature List */}
          <div className="lg:col-span-6 space-y-4">
            {[
              { title: "Zero Network Entitlements", desc: "Utter's macOS codesign sandbox profile has no network client entitlement. The OS kernel forbids outbound socket creation." },
              { title: "No Analytics or Telemetry SDKs", desc: "No Sentry, no Mixpanel, no PostHog, no Google Analytics. Grep the compiled binary yourself." },
              { title: "Offline Model Execution", desc: "Whisper neural weights run on your Apple Silicon Neural Engine & GPU in unified memory. Airplane mode works 100%." },
              { title: "Local Note Storage", desc: "Transcriptions and meeting records save directly to your ~/Library/Application Support/Utter in plain Markdown." },
            ].map((item, idx) => (
              <div key={idx} className="card-opaque-sm p-4 flex items-start gap-3.5">
                <div className="w-6 h-6 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center shrink-0 mt-0.5">
                  <Check size={14} className="stroke-[3]" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-zinc-900">{item.title}</h3>
                  <p className="text-xs text-zinc-600 mt-0.5 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Right Terminal Verification Box */}
          <div className="lg:col-span-6">
            <div className="rounded-3xl bg-zinc-900 text-zinc-100 shadow-2xl overflow-hidden border border-black/10">
              <div className="h-10 bg-zinc-800/80 px-4 flex items-center justify-between border-b border-zinc-700">
                <div className="flex items-center gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
                  <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
                  <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
                  <span className="text-[11px] font-mono text-zinc-400 ml-2">Terminal — Security Audit</span>
                </div>
                <span className="text-[10px] font-mono text-emerald-400 font-bold">100% AIR-GAPPED</span>
              </div>

              <div className="p-5 font-mono text-xs space-y-4 text-zinc-300">
                <div>
                  <p className="text-zinc-500"># Verify open sockets while dictating:</p>
                  <p className="text-emerald-300 font-bold">$ lsof -i -P | grep -i utter</p>
                  <p className="text-zinc-500 italic"># (no output — 0 open network sockets)</p>
                </div>

                <div>
                  <p className="text-zinc-500"># Check sandbox entitlements:</p>
                  <p className="text-emerald-300 font-bold">$ codesign -d --entitlements :- /Applications/Utter.app</p>
                  <p className="text-zinc-400">{`<key>com.apple.security.network.client</key>`} <strong className="text-rose-400">NO</strong></p>
                </div>

                <div className="pt-2 border-t border-zinc-800 flex items-center justify-between text-[11px]">
                  <span className="text-zinc-500">Binary Integrity:</span>
                  <span className="text-emerald-400 font-mono font-bold">SHA-256 Verified Clean</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
