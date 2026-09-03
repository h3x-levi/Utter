import React, { useState } from 'react';
import { Wand2, Sparkles, Check, ArrowRight, Code, ListCheck, BookOpen, Languages } from 'lucide-react';

export default function AITransformsPlayground() {
  const [activeTransform, setActiveTransform] = useState(0);

  const transforms = [
    {
      id: 0,
      name: 'Clean Disfluencies & Grammar',
      icon: <Sparkles className="w-4 h-4 text-orange-400" />,
      raw: 'Um, so basically we need to, like, refactor the audio tap because it was, uh, dropping samples when the CPU was under high load yesterday.',
      result: 'We need to refactor the audio tap to prevent sample drops during high CPU load.',
    },
    {
      id: 1,
      name: 'Extract Action Items',
      icon: <ListCheck className="w-4 h-4 text-emerald-400" />,
      raw: 'Make sure Levi fixes the menu bar opacity bug today and then John should test the Whisper small model on Intel Ventura and we can upload the build.',
      result: '• [ ] Levi: Fix menu bar icon opacity and verify template rendering.\n• [ ] John: Test Whisper Small.en model on Intel macOS 13 (Ventura).\n• [ ] Team: Package and upload DMG installer.',
    },
    {
      id: 2,
      name: 'Generate Swift Docstring',
      icon: <Code className="w-4 h-4 text-indigo-400" />,
      raw: 'Function that takes a float 32 PCM buffer and transcribes it asynchronously using the bundled small whisper model on metal.',
      result: '/// Transcribes an uncompressed 16kHz Float32 PCM audio buffer.\n/// - Parameter pcmBuffer: Monophonic audio frame buffer.\n/// - Returns: Asynchronously transcribed `SpeechTurn`.\n/// - Throws: `TranscriptionError.metalInitializationFailed`',
    },
    {
      id: 3,
      name: 'Translate to Spanish',
      icon: <Languages className="w-4 h-4 text-sky-400" />,
      raw: 'Utter is a private, zero-latency voice dictation app for macOS with 100% on-device speech recognition.',
      result: 'Utter es una aplicación de dictado por voz privada y de latencia cero para macOS con reconocimiento de voz 100% en el dispositivo.',
    },
  ];

  return (
    <section id="transforms" className="py-28 px-6 relative z-10 bg-[#0b0d13]">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-sky-400 font-bold">
            Local Foundation Models
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            Turn spoken stream into polished artifacts.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            Integrated with Apple Intelligence and local foundation models. Clean grammar, extract action items, and format code instantly.
          </p>
        </div>

        {/* Transform Selector Buttons */}
        <div className="flex flex-wrap items-center justify-center gap-3 mb-10">
          {transforms.map((t) => (
            <button
              key={t.id}
              onClick={() => setActiveTransform(t.id)}
              className={`flex items-center gap-2.5 px-5 py-3 rounded-2xl text-xs sm:text-sm font-semibold transition-all border ${
                activeTransform === t.id
                  ? 'bg-sky-500/20 text-sky-300 border-sky-500/50 shadow-lg shadow-sky-500/10 scale-102'
                  : 'bg-white/5 text-slate-300 border-white/10 hover:bg-white/10'
              }`}
            >
              {t.icon}
              {t.name}
            </button>
          ))}
        </div>

        {/* Split Comparison Window */}
        <div className="glass-panel rounded-3xl p-8 sm:p-12 border border-white/10 grid grid-cols-1 lg:grid-cols-2 gap-8 items-stretch">

          {/* Left: Raw Spoken Dictation */}
          <div className="p-6 rounded-2xl bg-[#0e111a] border border-white/10 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-slate-400 border-b border-white/10 pb-3 mb-4">
                <span className="text-orange-400 font-bold">Raw Spoken Input (Stream)</span>
                <span>Unpolished</span>
              </div>
              <p className="font-mono text-sm text-slate-300 leading-relaxed">
                "{transforms[activeTransform].raw}"
              </p>
            </div>
            <div className="mt-6 text-[11px] font-mono text-slate-500">
              Captured via Microphone (16kHz PCM Float32)
            </div>
          </div>

          {/* Right: AI Transformed Output */}
          <div className="p-6 rounded-2xl bg-[#121624] border border-sky-500/30 flex flex-col justify-between shadow-2xl shadow-sky-500/5">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-sky-400 border-b border-sky-500/20 pb-3 mb-4">
                <span className="font-bold flex items-center gap-2">
                  <Wand2 className="w-3.5 h-3.5" /> Transformed Result
                </span>
                <span className="text-emerald-400">Apple Intelligence Ready</span>
              </div>
              <pre className="font-mono text-sm text-slate-100 whitespace-pre-wrap leading-relaxed">
                {transforms[activeTransform].result}
              </pre>
            </div>
            <div className="mt-6 flex items-center justify-between text-[11px] font-mono text-slate-400">
              <span>Local On-Device Inference</span>
              <span className="text-emerald-400">Zero Cloud APIs</span>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
