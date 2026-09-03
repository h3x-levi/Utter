import React from 'react';
import { ShieldCheck, Lock, EyeOff, Radio } from 'lucide-react';

export default function PrivacyArchitecture() {
  return (
    <section id="privacy" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-4xl mx-auto text-center">

        <div className="w-16 h-16 rounded-3xl bg-emerald-500/10 border border-emerald-500/25 flex items-center justify-center text-emerald-400 mx-auto mb-6 shadow-xl shadow-emerald-500/10">
          <ShieldCheck className="w-8 h-8" />
        </div>

        <h2 className="text-4xl sm:text-5xl font-extrabold text-white mb-6 tracking-tight">
          Air-Gapped by Architecture. Zero Telemetry.
        </h2>

        <p className="text-slate-300 text-base sm:text-lg leading-relaxed mb-10">
          Utter contains no analytics libraries, no tracking pixels, and no remote speech recognition endpoints. You can run Utter on an airplane with Wi-Fi disabled or behind an air-gapped enterprise firewall.
        </p>

        {/* Live Security Verification Box */}
        <div className="glass-panel rounded-2xl p-6 font-mono text-xs sm:text-sm text-slate-300 text-left max-w-xl mx-auto border border-white/10 shadow-2xl">
          <div className="text-slate-500 mb-2">// Verify zero outbound network activity with lsof:</div>
          <div className="text-orange-400 font-semibold">$ lsof -i -P | grep -i utter</div>
          <div className="text-emerald-400 mt-2 font-bold flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
            ✓ 0 outbound sockets open (100% on-device local execution)
          </div>
        </div>

      </div>
    </section>
  );
}
