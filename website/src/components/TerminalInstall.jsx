import React, { useState } from 'react';
import { Terminal, Copy, Check, Download, ShieldCheck, Sparkles } from 'lucide-react';

export default function TerminalInstall() {
  const [activeTab, setActiveTab] = useState(0);
  const [copied, setCopied] = useState(false);

  const tabs = [
    {
      id: 0,
      name: 'Direct DMG Installer',
      command: 'open https://github.com/h3x-levi/Utter/releases/latest/download/Utter-1.1.56.dmg',
      desc: 'Download the signed universal DMG installer. Drag to Applications and launch instantly.',
    },
    {
      id: 1,
      name: 'Homebrew Cask',
      command: 'brew install --cask utter',
      desc: 'Install and manage Utter updates effortlessly via the Homebrew package manager.',
    },
    {
      id: 2,
      name: 'One-Line Curl Script',
      command: 'curl -fsSL https://raw.githubusercontent.com/h3x-levi/Utter/main/scripts/install.sh | bash',
      desc: 'Automated developer shell script that downloads, verifies checksums, and mounts Utter.',
    },
    {
      id: 3,
      name: 'Verify Zero Telemetry',
      command: 'lsof -i -P | grep -i utter',
      desc: 'Verify that Utter opens zero network sockets and sends zero outbound telemetry.',
    },
  ];

  const handleCopy = () => {
    navigator.clipboard.writeText(tabs[activeTab].command);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section id="install" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-4xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <span className="text-xs uppercase font-mono tracking-widest text-emerald-400 font-bold">
            Developer Quickstart
          </span>
          <h2 className="text-4xl sm:text-5xl font-extrabold text-white mt-3 mb-4 tracking-tight">
            Install Utter in 10 seconds.
          </h2>
          <p className="text-slate-400 text-base sm:text-lg">
            No accounts, no subscriptions, no credit cards required.
          </p>
        </div>

        {/* Tab Buttons */}
        <div className="flex flex-wrap items-center justify-center gap-2 mb-6">
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-mono font-semibold transition-all border ${
                activeTab === t.id
                  ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40 shadow-lg shadow-emerald-500/10'
                  : 'bg-white/5 text-slate-400 border-white/10 hover:bg-white/10 hover:text-slate-200'
              }`}
            >
              {t.name}
            </button>
          ))}
        </div>

        {/* Terminal Window Box */}
        <div className="glass-panel rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
          <div className="h-10 bg-[#121624] px-4 flex items-center justify-between border-b border-white/5">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#ff5f56]"></span>
              <span className="w-3 h-3 rounded-full bg-[#ffbd2e]"></span>
              <span className="w-3 h-3 rounded-full bg-[#27c93f]"></span>
            </div>
            <span className="text-xs font-mono text-slate-400 flex items-center gap-1.5">
              <Terminal className="w-3.5 h-3.5 text-emerald-400" /> zsh — macOS Terminal
            </span>
            <div className="w-12"></div>
          </div>

          <div className="p-8 bg-[#090c14] flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="font-mono text-xs sm:text-sm text-slate-100 flex items-center gap-3 overflow-x-auto w-full">
              <span className="text-emerald-400 font-bold select-none">$</span>
              <span className="text-orange-300 select-all">{tabs[activeTab].command}</span>
            </div>

            <button
              onClick={handleCopy}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl text-xs font-mono font-bold bg-white/10 hover:bg-white/15 text-white border border-white/15 transition-all shrink-0 hover:scale-105 active:scale-95"
            >
              {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
              {copied ? 'Copied' : 'Copy Command'}
            </button>
          </div>

          <div className="p-4 bg-[#0d101a] border-t border-white/5 text-xs text-slate-400 text-center font-mono">
            {tabs[activeTab].desc}
          </div>
        </div>

      </div>
    </section>
  );
}
