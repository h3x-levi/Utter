import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Shield, Terminal, CheckCircle2, Lock, EyeOff, ServerOff, Copy, Check } from 'lucide-react';

const VERIFICATION_COMMANDS = [
  {
    id: 'lsof',
    title: 'Open Network Sockets',
    command: 'sudo lsof -i -P | grep -i utter',
    output: `➜  ~ sudo lsof -i -P | grep -i utter
# [Command exited with code 0 - Zero open network sockets found]
# Utter.app has ZERO listening ports, ZERO outbound connections, and ZERO remote TLS tunnels.`,
    status: 'VERIFIED AIR-GAPPED',
  },
  {
    id: 'nettop',
    title: 'Outbound Byte Counter',
    command: 'nettop -P -J bytes_out | grep -i utter',
    output: `➜  ~ nettop -P -J bytes_out | grep -i utter
Utter.app.48201           tcp4/6: 0 B    udp: 0 B    bytes_out: 0 B    bytes_in: 0 B
# Result: 0 bytes transferred across entire 8-hour dictation session.`,
    status: '0 BYTES TRANSMITTED',
  },
  {
    id: 'codesign',
    title: 'Apple Notarization & Entitlements',
    command: 'codesign -dv --entitlements - /Applications/Utter.app',
    output: `➜  ~ codesign -dv --entitlements - /Applications/Utter.app
Executable=/Applications/Utter.app/Contents/MacOS/Utter
Identifier=com.hexlevi.Utter
Format=app bundle with Mach-O universal (x86_64 arm64)
Authority=Developer ID Application: Hex Levi (Apple Notarized)
Entitlements:
  com.apple.security.device.audio-input: true
  com.apple.security.network.client: FALSE [No Network Access]
  com.apple.security.network.server: FALSE [No Server Sockets]`,
    status: 'NOTARIZED & SECURE',
  },
];

export default function PrivacyVerificationVault() {
  const [activeTab, setActiveTab] = useState(0);
  const [copied, setCopied] = useState(false);

  const current = VERIFICATION_COMMANDS[activeTab];

  const handleCopy = () => {
    navigator.clipboard.writeText(current.command);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section id="privacy" className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-emerald-400 mb-4 border border-emerald-500/20">
          <Lock size={13} />
          <span>PROVABLE ZERO TELEMETRY</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Verify our air-gap in your terminal.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          Don't just take our word for it. Run Little Snitch, Wireshark, or native macOS diagnostic tools to prove that Utter never opens a single network socket.
        </p>
      </div>

      {/* Interactive Terminal Vault Card */}
      <div className="liquid-glass rounded-3xl p-6 sm:p-10 border border-white/10 shadow-2xl relative overflow-hidden">
        {/* Terminal Header & Tabs */}
        <div className="flex flex-wrap items-center justify-between gap-4 pb-6 mb-6 border-b border-white/10">
          <div className="flex items-center gap-2">
            {VERIFICATION_COMMANDS.map((tab, idx) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(idx)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-mono transition-all duration-150 border ${
                  activeTab === idx
                    ? 'bg-zinc-800 text-emerald-400 border-emerald-500/30 font-semibold'
                    : 'bg-zinc-900/50 text-zinc-400 border-white/5 hover:text-zinc-200'
                }`}
              >
                {tab.title}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 text-xs font-mono text-emerald-400 font-bold px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20">
              <CheckCircle2 size={13} />
              <span>{current.status}</span>
            </span>
            <button
              onClick={handleCopy}
              className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white border border-white/5 transition-colors"
              title="Copy verification command"
            >
              {copied ? <Check size={14} className="text-emerald-400" /> : <Copy size={14} />}
            </button>
          </div>
        </div>

        {/* Live macOS Terminal Body */}
        <div className="bg-zinc-950 rounded-2xl p-6 sm:p-8 font-mono text-xs sm:text-sm text-zinc-300 border border-white/5 shadow-inner overflow-x-auto">
          <div className="flex items-center gap-2 text-zinc-500 pb-3 mb-4 border-b border-white/5 text-xs">
            <Terminal size={14} className="text-orange-400" />
            <span>zsh — darwin-arm64 — 80x24</span>
          </div>
          <div className="text-emerald-400 mb-2 font-bold select-all">
            {current.command}
          </div>
          <pre className="text-zinc-400 whitespace-pre-wrap leading-relaxed">
            {current.output}
          </pre>
        </div>

        {/* Feature Check Pillars */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mt-8 pt-8 border-t border-white/5">
          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <ServerOff size={18} />
            </div>
            <div>
              <h4 className="text-sm font-bold text-white mb-1">Zero Cloud Servers</h4>
              <p className="text-xs text-zinc-400 leading-relaxed">
                No third-party APIs, no OpenAI keys required, no analytics trackers or remote logging.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <EyeOff size={18} />
            </div>
            <div>
              <h4 className="text-sm font-bold text-white mb-1">Confidential & HIPAA Safe</h4>
              <p className="text-xs text-zinc-400 leading-relaxed">
                Safe for proprietary software codebases, legal documents, patient notes, and NDAs.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <div className="p-2.5 rounded-xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <Shield size={18} />
            </div>
            <div>
              <h4 className="text-sm font-bold text-white mb-1">Apple Notarized</h4>
              <p className="text-xs text-zinc-400 leading-relaxed">
                Cryptographically signed and notarized by Apple. Runs natively in the macOS security sandbox.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
