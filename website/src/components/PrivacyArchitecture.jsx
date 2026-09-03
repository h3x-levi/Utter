import React from 'react';
import { ShieldCheck } from 'lucide-react';

export default function PrivacyArchitecture() {
  return (
    <section id="privacy" className="py-28 px-6 relative z-10 bg-[#0c0c0e]">
      <div className="max-w-4xl mx-auto text-center">

        <div className="w-12 h-12 rounded-2xl bg-zinc-800 border border-zinc-700 flex items-center justify-center text-white mx-auto mb-6">
          <ShieldCheck className="w-6 h-6" />
        </div>

        <h2 className="text-4xl sm:text-5xl font-bold text-white mb-4 tracking-tight">
          Air-Gapped by Architecture. Zero Telemetry.
        </h2>

        <p className="text-zinc-400 text-base sm:text-lg leading-relaxed mb-10 max-w-2xl mx-auto">
          Utter contains no analytics libraries, no tracking pixels, and no remote speech recognition endpoints. You can run Utter on an airplane with Wi-Fi disabled or behind an air-gapped enterprise firewall.
        </p>

        {/* Live Security Verification Box */}
        <div className="apple-panel rounded-xl p-6 font-mono text-xs sm:text-sm text-zinc-300 text-left max-w-xl mx-auto border border-zinc-800 shadow-2xl bg-[#121215]">
          <div className="text-zinc-500 mb-2">// Verify zero outbound network activity with lsof:</div>
          <div className="text-zinc-200 font-semibold">$ lsof -i -P | grep -i utter</div>
          <div className="text-emerald-400 mt-2 font-medium flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
            ✓ 0 outbound sockets open (100% on-device local execution)
          </div>
        </div>

      </div>
    </section>
  );
}
