import React, { useState } from 'react';
import { Mic, Volume2, Users, Copy, Check } from 'lucide-react';

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
    <section id="meetings" className="py-28 px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Two-Way Audio Capture
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Transcribe calls in Zoom, Meet, Teams & FaceTime.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Dual-stream audio capture taps both your microphone and incoming speaker audio without external virtual audio drivers.
          </p>
        </div>

        {/* Studio Demo Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch">

          {/* Left Column */}
          <div className="apple-panel rounded-2xl p-8 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-2 px-3 py-1 rounded-md bg-zinc-800 text-zinc-300 text-xs font-mono font-medium mb-6 border border-zinc-700 w-max">
                <Users className="w-3.5 h-3.5" /> Call Presence Detected
              </div>

              <h4 className="text-xl font-bold text-white mb-2">
                Automatic Call Diarization
              </h4>

              <p className="text-zinc-400 text-xs sm:text-sm leading-relaxed mb-8">
                When you join a meeting, Utter automatically displays an offer panel to record and transcribe the session in real time.
              </p>

              {/* Audio Meter 1 */}
              <div className="p-4 rounded-xl bg-[#141418] border border-zinc-800 mb-3">
                <div className="flex items-center justify-between text-xs font-mono text-zinc-300 mb-2">
                  <span className="flex items-center gap-2">
                    <Mic className="w-3.5 h-3.5 text-white" />
                    Channel 1: Your Microphone
                  </span>
                  <span className="text-zinc-400">Active (48kHz)</span>
                </div>
                <div className="flex items-center gap-1 h-3.5">
                  {[40, 70, 90, 60, 80, 45, 65, 30].map((v, i) => (
                    <div key={i} className="flex-1 bg-zinc-400 rounded-sm" style={{ height: `${v}%` }} />
                  ))}
                </div>
              </div>

              {/* Audio Meter 2 */}
              <div className="p-4 rounded-xl bg-[#141418] border border-zinc-800">
                <div className="flex items-center justify-between text-xs font-mono text-zinc-300 mb-2">
                  <span className="flex items-center gap-2">
                    <Volume2 className="w-3.5 h-3.5 text-zinc-400" />
                    Channel 2: Remote Attendees
                  </span>
                  <span className="text-zinc-400">CoreAudio Tap</span>
                </div>
                <div className="flex items-center gap-1 h-3.5">
                  {[60, 85, 40, 95, 75, 50, 90, 70].map((v, i) => (
                    <div key={i} className="flex-1 bg-zinc-600 rounded-sm" style={{ height: `${v}%` }} />
                  ))}
                </div>
              </div>
            </div>

            <div className="mt-8 pt-4 border-t border-zinc-800 flex items-center justify-between text-xs font-mono text-zinc-500">
              <span>ScreenCaptureKit / CoreAudio Tap</span>
              <span className="text-zinc-400">Zero Cloud Storage</span>
            </div>
          </div>

          {/* Right Columns */}
          <div className="apple-panel rounded-2xl p-8 border border-zinc-800 lg:col-span-2 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between border-b border-zinc-800 pb-4 mb-6">
                <div>
                  <h4 className="text-base font-bold text-white">Live Meeting Session: Sprint Planning</h4>
                  <span className="text-xs font-mono text-zinc-500">Duration: 24m 12s • 4 Speakers</span>
                </div>
                <button
                  onClick={handleCopy}
                  className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-mono font-medium bg-zinc-800 hover:bg-zinc-700 text-zinc-200 border border-zinc-700 transition-all"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-white" /> : <Copy className="w-3.5 h-3.5" />}
                  {copied ? 'Copied' : 'Copy Transcript'}
                </button>
              </div>

              {/* Transcript Area */}
              <div className="space-y-3 font-mono text-xs">
                {mockTranscript.map((t, idx) => (
                  <div key={idx} className="p-3.5 rounded-lg bg-[#141418] border border-zinc-800/60 flex flex-col gap-1">
                    <div className="flex items-center justify-between">
                      <span className={`font-semibold ${t.speaker === 'You' ? 'text-white' : 'text-zinc-400'}`}>
                        {t.speaker}
                      </span>
                      <span className="text-[10px] text-zinc-500">{t.time}</span>
                    </div>
                    <p className="text-zinc-300 leading-relaxed">{t.text}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-zinc-800 flex flex-wrap items-center gap-2 text-xs font-mono">
              <span className="text-zinc-500">Local Actions:</span>
              <button className="px-2.5 py-1 rounded bg-zinc-800 text-zinc-300 hover:bg-zinc-700 border border-zinc-700">
                Summary (.md)
              </button>
              <button className="px-2.5 py-1 rounded bg-zinc-800 text-zinc-300 hover:bg-zinc-700 border border-zinc-700">
                Action Items
              </button>
              <button className="px-2.5 py-1 rounded bg-zinc-800 text-zinc-300 hover:bg-zinc-700 border border-zinc-700">
                Export to Obsidian
              </button>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
