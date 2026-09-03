import React, { useState } from 'react';
import { Terminal, Copy, Check } from 'lucide-react';

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
    <section id="install" className="py-28 px-6 relative z-10 bg-[#09090b]">
      <div className="max-w-4xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Developer Quickstart
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Install Utter in 10 seconds.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            No accounts, no subscriptions, no credit cards required.
          </p>
        </div>

        {/* Tab Buttons */}
        <div className="flex flex-wrap items-center justify-center gap-2 mb-6">
          {tabs.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={`px-3.5 py-1.5 rounded-lg text-xs font-mono font-medium transition-all border ${
                activeTab === t.id
                  ? 'bg-zinc-800 text-white border-zinc-500 shadow-sm'
                  : 'bg-zinc-900/60 text-zinc-400 border-zinc-800 hover:text-zinc-200'
              }`}
            >
              {t.name}
            </button>
          ))}
        </div>

        {/* Terminal Window Box */}
        <div className="apple-panel rounded-2xl overflow-hidden border border-zinc-800 shadow-2xl">
          <div className="h-9 bg-[#161619] px-4 flex items-center justify-between border-b border-zinc-800 text-xs font-mono text-zinc-400">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#ff5f56]"></span>
              <span className="w-3 h-3 rounded-full bg-[#ffbd2e]"></span>
              <span className="w-3 h-3 rounded-full bg-[#27c93f]"></span>
            </div>
            <span className="flex items-center gap-1.5">
              <Terminal className="w-3.5 h-3.5 text-zinc-400" /> zsh — macOS Terminal
            </span>
            <div className="w-12"></div>
          </div>

          <div className="p-6 sm:p-8 bg-[#0c0c0e] flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="font-mono text-xs sm:text-sm text-zinc-200 flex items-center gap-3 overflow-x-auto w-full">
              <span className="text-zinc-500 font-bold select-none">$</span>
              <span className="text-zinc-100 select-all">{tabs[activeTab].command}</span>
            </div>

            <button
              onClick={handleCopy}
              className="flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-mono font-medium bg-zinc-800 hover:bg-zinc-700 text-white border border-zinc-700 transition-all shrink-0 active:scale-95"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-white" /> : <Copy className="w-3.5 h-3.5" />}
              {copied ? 'Copied' : 'Copy'}
            </button>
          </div>

          <div className="p-3.5 bg-[#121215] border-t border-zinc-800 text-xs text-zinc-400 text-center font-mono">
            {tabs[activeTab].desc}
          </div>
        </div>

      </div>
    </section>
  );
}
