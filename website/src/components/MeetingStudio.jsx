import React, { useState } from 'react';
import { PhoneCall, Mic, Volume2, Sparkles, FileText, Download, Users, Copy, Check } from 'lucide-react';

export default function MeetingStudio() {
  const [copied, setCopied] = useState(false);

  const mockTranscript = [
    { speaker: 'You', time: '10:02 AM', text: 'Let\'s review the benchmark results for the Whisper Small.en model on the M3 Max chip.' },
    { speaker: 'Engineering Lead (Zoom)', time: '10:03 AM', text: 'Latency came in at 168ms for 10-second audio buffers, which is well below our 200ms target threshold.' },
    { speaker: 'You', time: '10:03 AM', text: 'Excellent. Let\'s keep the small.en model bundled as the zero-config default in the DMG.' },
    { speaker: 'Product Lead (Zoom)', time: '10:04 AM', text: 'Agreed! Zero-telemetry and offline capability will be the primary highlights on Product Hunt.' },
  ];

  const handleCopy = () => {
    const text = mockTranscript.map(t => `**${t.speaker}** (${t.time}): ${t.text}`).join('\n\n');
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <section id="meetings" className="py-28 px-6 relative z-10 border-t border-white/5 bg-[#080a10]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-indigo-400 font-bold">
            Two-Way Audio Capture
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Transcribe calls in Zoom, Meet, Teams & FaceTime.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Dual-stream audio capture taps both your microphone and incoming speaker audio without external virtual audio drivers.
          </p>
        </div>

        {/* Studio Demo Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-stretch">

          {/* Left Column: Audio Stream Indicators */}
          <div className="glass-panel rounded-3xl p-8 border border-white/10 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 text-indigo-400 text-xs font-mono font-bold mb-6 border border-indigo-500/20 w-max">
                <Users className="w-3.5 h-3.5" /> Call Presence Detected
              </div>

              <h4 className="text-2xl font-bold text-white mb-3">
                Automatic Call Diarization
              </h4>

              <p className="text-slate-400 text-sm leading-relaxed mb-8">
                When you join a meeting, Utter automatically displays an offer panel to record and transcribe the session in real time.
              </p>

              {/* Live Audio Meter 1: Your Mic */}
              <div className="p-4 rounded-2xl bg-white/5 border border-white/10 mb-4">
                <div className="flex items-center justify-between text-xs font-mono text-slate-300 mb-2">
                  <span className="flex items-center gap-2">
                    <Mic className="w-3.5 h-3.5 text-orange-400" />
                    Channel 1: Your Microphone
                  </span>
                  <span className="text-emerald-400 font-bold">Active (48kHz)</span>
                </div>
                <div className="flex items-center gap-1 h-4">
                  {[40, 70, 90, 60, 80, 45, 65, 30].map((v, i) => (
                    <div key={i} className="flex-1 bg-orange-400/80 rounded-sm" style={{ height: `${v}%` }} />
                  ))}
                </div>
              </div>

              {/* Live Audio Meter 2: System Audio Output */}
              <div className="p-4 rounded-2xl bg-white/5 border border-white/10">
                <div className="flex items-center justify-between text-xs font-mono text-slate-300 mb-2">
                  <span className="flex items-center gap-2">
                    <Volume2 className="w-3.5 h-3.5 text-indigo-400" />
                    Channel 2: Remote Attendees
                  </span>
                  <span className="text-indigo-400 font-bold">Tapped (CoreAudio)</span>
                </div>
                <div className="flex items-center gap-1 h-4">
                  {[60, 85, 40, 95, 75, 50, 90, 70].map((v, i) => (
                    <div key={i} className="flex-1 bg-indigo-400/80 rounded-sm" style={{ height: `${v}%` }} />
                  ))}
                </div>
              </div>
            </div>

            <div className="mt-8 pt-6 border-t border-white/10 flex items-center justify-between text-xs font-mono text-slate-400">
              <span>ScreenCaptureKit / CoreAudio Tap</span>
              <span className="text-emerald-400">Zero Cloud Storage</span>
            </div>
          </div>

          {/* Right 2 Columns: Live Transcript Player */}
          <div className="glass-panel rounded-3xl p-8 border border-white/10 lg:col-span-2 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between border-b border-white/10 pb-4 mb-6">
                <div>
                  <h4 className="text-lg font-bold text-white">Live Meeting Session: Sprint Planning</h4>
                  <span className="text-xs font-mono text-slate-400">Duration: 24m 12s • 4 Speakers</span>
                </div>
                <button
                  onClick={handleCopy}
                  className="flex items-center gap-2 px-3.5 py-1.5 rounded-xl text-xs font-mono font-semibold bg-white/10 hover:bg-white/15 text-slate-200 border border-white/15 transition-all"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  {copied ? 'Copied Markdown' : 'Copy Transcript'}
                </button>
              </div>

              {/* Transcript Scroll Area */}
              <div className="space-y-4 font-mono text-xs sm:text-sm">
                {mockTranscript.map((t, idx) => (
                  <div key={idx} className="p-4 rounded-xl bg-white/5 border border-white/5 flex flex-col gap-1">
                    <div className="flex items-center justify-between">
                      <span className={`font-bold ${t.speaker === 'You' ? 'text-orange-400' : 'text-indigo-400'}`}>
                        {t.speaker}
                      </span>
                      <span className="text-[11px] text-slate-500">{t.time}</span>
                    </div>
                    <p className="text-slate-200 leading-relaxed">{t.text}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Quick AI Action Pills */}
            <div className="mt-6 pt-4 border-t border-white/10 flex flex-wrap items-center gap-3">
              <span className="text-xs font-mono text-slate-400">Apply Instant Local AI Action:</span>
              <button className="px-3 py-1 rounded-lg text-xs font-mono bg-orange-500/20 text-orange-400 border border-orange-500/30 hover:bg-orange-500/30">
                ✨ Generate Executive Summary
              </button>
              <button className="px-3 py-1 rounded-lg text-xs font-mono bg-indigo-500/20 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/30">
                ⚡ Extract Action Items
              </button>
              <button className="px-3 py-1 rounded-lg text-xs font-mono bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/30">
                📥 Export to Obsidian (.md)
              </button>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
