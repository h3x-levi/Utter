import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { PhoneCall, Play, Pause, Sparkles, FileText, CheckCircle2, Users, Volume2 } from 'lucide-react';

export default function StageMeetingStudio() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [activeTab, setActiveTab] = useState('transcript');

  const meetingTranscript = [
    {
      time: '10:02 AM',
      speaker: 'You (Microphone)',
      speakerColor: 'text-indigo-400 bg-indigo-500/10 border-indigo-500/20',
      text: 'Thanks everyone for joining. Let’s review the local speech pipeline before we cut the 1.1 release.',
    },
    {
      time: '10:03 AM',
      speaker: 'Sarah (Zoom System Audio)',
      speakerColor: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20',
      text: 'The Metal acceleration tests show 168ms latency on M1 through M4 chips. Small.en is performing flawlessly.',
    },
    {
      time: '10:04 AM',
      speaker: 'David (Zoom System Audio)',
      speakerColor: 'text-purple-400 bg-purple-500/10 border-purple-500/20',
      text: 'Zero memory leaks detected across 4-hour continuous dictation sessions. Memory footprint is stable at 240 MB.',
    },
  ];

  return (
    <div className="w-full max-w-5xl mx-auto flex flex-col items-center">
      <div className="text-center mb-8">
        <span className="font-mono-sm text-xs font-semibold px-3 py-1 rounded-full bg-white/5 text-zinc-400 border border-white/10">
          CoreAudio Dual-Channel Taps · Speaker Diarization
        </span>
        <h2 className="text-3xl sm:text-4xl md:text-5xl font-extrabold tracking-tight mt-3 text-white">
          Transcribe meetings with automatic speaker separation.
        </h2>
        <p className="text-zinc-400 text-base sm:text-lg max-w-2xl mx-auto mt-2">
          Utter detects active Zoom, Meet, or Teams calls and captures your microphone and incoming attendees on separate audio streams.
        </p>
      </div>

      {/* Meeting Studio Window */}
      <div className="w-full max-w-4xl rounded-[24px] bg-[#1e1e24]/95 backdrop-blur-2xl border border-white/10 shadow-2xl overflow-hidden text-white">
        {/* Title Bar */}
        <div className="h-12 bg-[#282830] border-b border-white/10 px-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
              <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
              <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
            </div>
            <span className="text-xs font-semibold text-white/90">Meeting Notes & Live Diarization</span>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => setActiveTab('transcript')}
              className={`px-3 py-1 rounded-lg text-xs font-medium transition-colors ${
                activeTab === 'transcript' ? 'bg-white/15 text-white' : 'text-white/40 hover:text-white'
              }`}
            >
              Live Transcript
            </button>
            <button
              onClick={() => setActiveTab('summary')}
              className={`px-3 py-1 rounded-lg text-xs font-medium flex items-center gap-1.5 transition-colors ${
                activeTab === 'summary' ? 'bg-indigo-600 text-white' : 'text-white/40 hover:text-white'
              }`}
            >
              <Sparkles size={12} />
              AI Summary
            </button>
          </div>
        </div>

        {/* Audio Player Scrubber Strip */}
        <div className="p-4 sm:p-5 bg-black/30 border-b border-white/5 flex items-center justify-between gap-4">
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="w-10 h-10 rounded-full bg-indigo-600 hover:bg-indigo-500 text-white flex items-center justify-center transition-colors shadow-md"
          >
            {isPlaying ? <Pause size={16} /> : <Play size={16} className="ml-0.5" />}
          </button>

          <div className="flex-1">
            <div className="flex items-center justify-between text-[11px] font-mono text-white/40 mb-1.5">
              <span>Dual-Channel CoreAudio Stream</span>
              <span>04:18 / 28:45</span>
            </div>
            {/* Visualizer bars */}
            <div className="flex items-center gap-1 h-6">
              {[30, 60, 90, 45, 80, 100, 70, 40, 85, 95, 55, 75, 35, 65, 80, 90, 50, 70, 85, 60, 40].map((h, i) => (
                <div
                  key={i}
                  style={{ height: `${h}%` }}
                  className={`flex-1 rounded-full ${i % 2 === 0 ? 'bg-indigo-400/80' : 'bg-emerald-400/80'}`}
                />
              ))}
            </div>
          </div>
        </div>

        {/* Transcript / Summary Content */}
        <div className="p-6 sm:p-8 min-h-[260px] text-left">
          {activeTab === 'transcript' ? (
            <div className="space-y-4">
              {meetingTranscript.map((turn, i) => (
                <div key={i} className="p-4 rounded-xl bg-white/[0.03] border border-white/5">
                  <div className="flex items-center justify-between mb-2">
                    <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full border ${turn.speakerColor}`}>
                      {turn.speaker}
                    </span>
                    <span className="text-[11px] font-mono text-white/40">{turn.time}</span>
                  </div>
                  <p className="text-sm text-white/80 leading-relaxed">{turn.text}</p>
                </div>
              ))}
            </div>
          ) : (
            <div className="p-5 rounded-2xl bg-indigo-950/30 border border-indigo-500/20 space-y-4">
              <div className="flex items-center gap-2 text-indigo-300 font-semibold text-sm">
                <Sparkles size={16} />
                <span>Apple Intelligence Action Items & Summary</span>
              </div>
              <ul className="space-y-2 text-sm text-white/75">
                <li className="flex items-start gap-2">
                  <CheckCircle2 size={16} className="text-emerald-400 shrink-0 mt-0.5" />
                  <span>Release 1.1 confirmed with sub-200ms latency on Apple Silicon.</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle2 size={16} className="text-emerald-400 shrink-0 mt-0.5" />
                  <span>Memory consumption verified at 240 MB across 4-hour test session.</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle2 size={16} className="text-emerald-400 shrink-0 mt-0.5" />
                  <span>Export meeting transcript to Markdown note in Obsidian.</span>
                </li>
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
