import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { ShieldCheck, Lock, Terminal, CheckCircle2, WifiOff, EyeOff } from 'lucide-react';

export default function StagePrivacyVault() {
  const [activeTab, setActiveTab] = useState('sockets');

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center">
      <div className="text-center mb-8">
        <span className="font-mono-sm text-xs font-semibold px-3 py-1 rounded-full bg-black/5 text-black/60 border border-black/10">
          Air-Gapped Architecture · Zero Network Sockets
        </span>
        <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight mt-3 text-[#0d0d0d]">
          Guaranteed private. Verifiable from your terminal.
        </h2>
        <p className="text-black/60 text-base sm:text-lg max-w-2xl mx-auto mt-2">
          Utter links zero analytics SDKs, has zero network entitlements in its sandbox profile, and makes zero outbound connections.
        </p>
      </div>

      {/* Terminal Window */}
      <div className="w-full max-w-4xl rounded-[24px] bg-[#141417]/95 backdrop-blur-2xl border border-white/10 shadow-2xl overflow-hidden text-white font-mono">
        <div className="h-12 bg-[#1f1f24] border-b border-white/10 px-5 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
            <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
            <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
            <span className="text-xs text-white/50 ml-3">Terminal — Security Verification Audit</span>
          </div>

          <div className="flex items-center gap-2 text-xs">
            <button
              onClick={() => setActiveTab('sockets')}
              className={`px-3 py-1 rounded-lg transition-colors ${activeTab === 'sockets' ? 'bg-white/20 text-white' : 'text-white/40 hover:text-white'}`}
            >
              lsof -i Audit
            </button>
            <button
              onClick={() => setActiveTab('binary')}
              className={`px-3 py-1 rounded-lg transition-colors ${activeTab === 'binary' ? 'bg-white/20 text-white' : 'text-white/40 hover:text-white'}`}
            >
              Binary Strings
            </button>
            <button
              onClick={() => setActiveTab('entitlements')}
              className={`px-3 py-1 rounded-lg transition-colors ${activeTab === 'entitlements' ? 'bg-white/20 text-white' : 'text-white/40 hover:text-white'}`}
            >
              Codesign Entitlements
            </button>
          </div>
        </div>

        {/* Terminal Content */}
        <div className="p-6 sm:p-8 min-h-[260px] text-xs sm:text-sm leading-relaxed text-left">
          {activeTab === 'sockets' && (
            <div>
              <p className="text-white/40 mb-2 font-mono-sm"># Test if any open sockets belong to Utter</p>
              <p className="text-green-400 mb-4">$ lsof -i -P | grep -i utter</p>
              <p className="text-white/60 italic mb-4"># Exit code 1 (no output — 0 network sockets open)</p>
              <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 flex items-center gap-3">
                <CheckCircle2 size={18} className="shrink-0" />
                <span>Audited: Utter process has zero active connections and zero listening ports.</span>
              </div>
            </div>
          )}

          {activeTab === 'binary' && (
            <div>
              <p className="text-white/40 mb-2 font-mono-sm"># Search for telemetry or tracking strings in binary</p>
              <p className="text-green-400 mb-4">$ strings /Applications/Utter.app/Contents/MacOS/Utter | grep -Ei "analytics|telemetry|sentry|mixpanel|segment"</p>
              <p className="text-white/60 italic mb-4"># Exit code 1 (0 matches found)</p>
              <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 flex items-center gap-3">
                <CheckCircle2 size={18} className="shrink-0" />
                <span>Verified: Zero third-party telemetry libraries linked or included.</span>
              </div>
            </div>
          )}

          {activeTab === 'entitlements' && (
            <div>
              <p className="text-white/40 mb-2 font-mono-sm"># Inspect macOS sandbox entitlements</p>
              <p className="text-green-400 mb-2">$ codesign -d --entitlements :- /Applications/Utter.app</p>
              <pre className="text-white/70 text-xs bg-black/40 p-3 rounded-lg border border-white/5 overflow-x-auto">
{`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- NO com.apple.security.network.client -->
    <!-- NO com.apple.security.network.server -->
    <key>com.apple.security.device.microphone</key>
    <true/>
</dict>
</plist>`}
              </pre>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
