import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Users, Mic, Volume2, Video, Sparkles, CheckCircle2, FileText, ArrowRight } from 'lucide-react';

const MEETING_INTEGRATIONS = [
  { name: 'Zoom', status: 'Auto-Detected' },
  { name: 'Google Meet', status: 'Auto-Detected' },
  { name: 'Microsoft Teams', status: 'Auto-Detected' },
  { name: 'FaceTime', status: 'Auto-Detected' },
  { name: 'Slack Huddles', status: 'Auto-Detected' },
  { name: 'Discord', status: 'Auto-Detected' },
];

export default function DualStreamMeetingStudio() {
  const [activeSpeaker, setActiveSpeaker] = useState('both');

  return (
    <section className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-cyan-400 mb-4 border border-cyan-500/20">
          <Users size={13} />
          <span>DUAL-STREAM MEETING CAPTURE</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          Transcribe meetings with speaker separation.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          Utter captures both your microphone input and system audio output concurrently in RAM, separating your voice from meeting attendees without cloud bots joining the call.
        </p>
      </div>

      {/* Interactive Meeting Console */}
      <div className="liquid-glass rounded-3xl p-6 sm:p-10 border border-white/10 shadow-2xl relative overflow-hidden">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          {/* Left Column: Meeting Stream Visualizer (7 cols) */}
          <div className="lg:col-span-7 space-y-4">
            {/* Stream 1: Microphone (You) */}
            <div className="p-5 rounded-2xl bg-zinc-950/80 border border-orange-500/30 relative overflow-hidden">
              <div className="flex items-center justify-between text-xs font-mono mb-2">
                <span className="flex items-center gap-2 text-orange-400 font-bold">
                  <Mic size={14} />
                  <span>STREAM 1: YOU (MICROPHONE INPUT)</span>
                </span>
                <span className="text-zinc-500 text-[11px]">16kHz PCM Float</span>
              </div>
              <p className="text-zinc-200 text-xs sm:text-sm font-sans mb-3 leading-relaxed">
                "We should ensure all Whisper model weights are stored in the macOS Application Support directory so they are preserved across reboots."
              </p>
              {/* Audio waveform meter */}
              <div className="flex items-end gap-1 h-3">
                {[20, 60, 100, 75, 40, 90, 80, 50, 30, 70, 95, 45, 60, 85, 30].map((h, i) => (
                  <span
                    key={i}
                    className="w-1 bg-orange-400 rounded-full animate-pulse"
                    style={{ height: `${h}%`, animationDelay: `${i * 0.08}s` }}
                  />
                ))}
              </div>
            </div>

            {/* Stream 2: System Audio (Attendees) */}
            <div className="p-5 rounded-2xl bg-zinc-950/80 border border-cyan-500/30 relative overflow-hidden">
              <div className="flex items-center justify-between text-xs font-mono mb-2">
                <span className="flex items-center gap-2 text-cyan-400 font-bold">
                  <Volume2 size={14} />
                  <span>STREAM 2: OTHERS (SYSTEM AUDIO OUTPUT)</span>
                </span>
                <span className="text-zinc-500 text-[11px]">CoreAudio Tap</span>
              </div>
              <p className="text-zinc-200 text-xs sm:text-sm font-sans mb-3 leading-relaxed">
                "Agreed. That also ensures sandboxed updates don't require re-downloading the 181MB model checkpoint."
              </p>
              {/* Audio waveform meter */}
              <div className="flex items-end gap-1 h-3">
                {[30, 80, 50, 90, 60, 40, 75, 100, 65, 35, 80, 55, 70, 40, 25].map((h, i) => (
                  <span
                    key={i}
                    className="w-1 bg-cyan-400 rounded-full animate-pulse"
                    style={{ height: `${h}%`, animationDelay: `${i * 0.1}s` }}
                  />
                ))}
              </div>
            </div>

            {/* Markdown Auto-Summary Callout */}
            <div className="p-4 rounded-xl bg-zinc-900/60 border border-white/5 flex items-center justify-between text-xs font-mono text-zinc-300">
              <div className="flex items-center gap-2">
                <FileText size={14} className="text-emerald-400" />
                <span>Export format: Markdown with timestamps & speakers</span>
              </div>
              <span className="text-orange-400 font-bold">Ctrl+Option+N</span>
            </div>
          </div>

          {/* Right Column: Active Detection & Supported Apps (5 cols) */}
          <div className="lg:col-span-5 flex flex-col justify-between">
            <div>
              <div className="text-xs uppercase font-mono text-zinc-400 tracking-wider mb-2">
                Zero Annoying Bots
              </div>
              <h3 className="text-2xl font-bold text-white mb-3">
                No awkward bot joins your meeting.
              </h3>
              <p className="text-zinc-400 text-xs sm:text-sm leading-relaxed mb-6">
                Cloud transcription services require inviting an external bot into your meeting, announcing to everyone that they are being recorded and stored on third-party servers. Utter records silently on your Mac with zero external presence.
              </p>

              {/* Grid of supported apps */}
              <div className="text-xs font-mono text-zinc-500 uppercase mb-3">
                Proactive Meeting Presence Detection:
              </div>
              <div className="grid grid-cols-2 gap-2 mb-6">
                {MEETING_INTEGRATIONS.map((app) => (
                  <div
                    key={app.name}
                    className="p-3 rounded-xl bg-zinc-900/70 border border-white/5 flex items-center justify-between"
                  >
                    <span className="text-xs font-semibold text-zinc-200">{app.name}</span>
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  </div>
                ))}
              </div>
            </div>

            <div className="pt-4 border-t border-white/5 flex items-center gap-2 text-xs font-mono text-zinc-400">
              <CheckCircle2 size={13} className="text-emerald-400" />
              <span>Full compliance with enterprise offline security policies</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
