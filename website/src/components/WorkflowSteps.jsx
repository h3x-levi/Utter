import React, { useState } from 'react';
import { Mic, Cpu, Sparkles, Keyboard, ArrowRight, CheckCircle2 } from 'lucide-react';
import { motion } from 'framer-motion';

export default function WorkflowSteps() {
  const [activeStep, setActiveStep] = useState(0);

  const steps = [
    {
      id: 1,
      title: 'Global Push-to-Talk Capture',
      subtitle: 'Low-latency hardware event tap',
      icon: <Mic className="w-6 h-6 text-orange-400" />,
      tag: 'Audio Engine',
      desc: 'Press and hold your configured global hotkey (Fn, Right Option, or Right Command). Utter taps your microphone with AVAudioEngine into a 16kHz float32 ring buffer with sub-millisecond start latency and adaptive silence gating.',
      code: `// Hardware Flag Monitor\nKeyMonitor.shared.onKeyDown = { [weak self] in\n    self?.audioRecorder.startCapturingStream()\n    self?.pillWindow.morph(to: .recording)\n}`,
      details: ['Sub-5ms hotkey trigger response', 'Adaptive silence threshold gating', 'Automatic background music pause'],
    },
    {
      id: 2,
      title: 'whisper.cpp on Metal GPU',
      subtitle: 'Zero-copy neural inference',
      icon: <Cpu className="w-6 h-6 text-indigo-400" />,
      tag: 'Metal Compute',
      desc: 'Audio PCM frames are fed directly to whisper.cpp accelerated via Apple Metal compute shaders. Processing happens directly in unified Apple Silicon memory without writing WAV files to disk.',
      code: `// Metal Compute Pipeline\nlet context = whisper_init_from_file_with_params(modelPath, params)\nwhisper_full_parallel(context, wparams, pcmData, nSamples, nThreads)\nlet text = whisper_full_get_segment_text(context, 0)`,
      details: ['Sub-200ms end-to-end latency', 'No disk I/O / Zero temporary files', 'Quantized Q5_1 for maximum fidelity'],
    },
    {
      id: 3,
      title: 'Context Biasing & Normalization',
      subtitle: 'Developer dictionary & grammar polish',
      icon: <Sparkles className="w-6 h-6 text-amber-400" />,
      tag: 'Entity Bias',
      desc: 'Utter injects your custom vocabulary (code variable names, internal tools, acronyms) directly into the Whisper decoder. Sentence polish removes disfluencies (um, ah) and restores precise punctuation.',
      code: `// Context Biasing & Correction\nlet biasedText = DictionaryCorrector.shared.apply(rawText)\nlet polished = SentencePolish.restorePunctuation(biasedText)\nreturn SnippetTemplates.expand(polished)`,
      details: ['100% accurate coding syntax & camelCase', 'Zero cloud dictionary leaks', 'Instant macro & snippet expansions'],
    },
    {
      id: 4,
      title: 'Direct Accessibility Injection',
      subtitle: 'Zero clipboard pollution',
      icon: <Keyboard className="w-6 h-6 text-emerald-400" />,
      tag: 'Native AppKit',
      desc: 'Transcribed text is injected directly at your active cursor via macOS Accessibility APIs and synthetic CGEvent keystrokes. Your clipboard history remains completely untouched.',
      code: `// Non-Destructive Injection\nlet focusedElement = AXUIElementCopyFocusedUIElement()\nAXUIElementSetAttributeValue(focusedElement, kAXValueAttribute, newText)\n// Clipboard history preserved 100%`,
      details: ['Works inside Cursor, Xcode, Slack, Obsidian', 'Preserves Alfred / Raycast clipboard history', 'Seamless undo/redo support'],
    },
  ];

  return (
    <section id="workflow" className="py-28 px-6 relative z-10 bg-[#090b10] border-t border-white/5">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-orange-400 font-bold">
            The Zero-Latency Pipeline
          </span>
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white mt-3 mb-6 tracking-tight">
            How voice turns into code in 168ms.
          </h2>
          <p className="text-slate-400 text-base sm:text-xl">
            A look under the hood at Utter's bi-ported Swift and C++ architecture.
          </p>
        </div>

        {/* 4 Step Navigation Tabs */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-10">
          {steps.map((step, idx) => (
            <button
              key={step.id}
              onClick={() => setActiveStep(idx)}
              className={`p-6 rounded-2xl text-left transition-all border ${
                activeStep === idx
                  ? 'bg-orange-500/15 border-orange-500/40 shadow-xl shadow-orange-500/10'
                  : 'bg-white/5 border-white/10 hover:bg-white/10'
              }`}
            >
              <div className="flex items-center justify-between mb-4">
                <span className="text-xs font-mono font-bold px-2 py-1 rounded bg-white/10 text-orange-400">
                  0{step.id}
                </span>
                <span className="text-[10px] uppercase font-mono text-slate-400">
                  {step.tag}
                </span>
              </div>
              <div className="flex items-center gap-3 mb-2">
                {step.icon}
                <h4 className="text-lg font-bold text-white tracking-tight">{step.title}</h4>
              </div>
              <p className="text-xs text-slate-400">{step.subtitle}</p>
            </button>
          ))}
        </div>

        {/* Active Step Deep-Dive Card */}
        <div className="glass-panel rounded-3xl p-8 sm:p-12 border border-white/10 grid grid-cols-1 lg:grid-cols-2 gap-10 items-center">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-orange-500/10 text-orange-400 text-xs font-mono font-bold mb-4 border border-orange-500/20">
              Step 0{steps[activeStep].id} • {steps[activeStep].tag}
            </div>

            <h3 className="text-3xl font-bold text-white mb-4">
              {steps[activeStep].title}
            </h3>

            <p className="text-slate-300 text-base sm:text-lg leading-relaxed mb-8">
              {steps[activeStep].desc}
            </p>

            <div className="space-y-3">
              {steps[activeStep].details.map((detail, i) => (
                <div key={i} className="flex items-center gap-3 text-sm text-slate-300 font-medium">
                  <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
                  <span>{detail}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Code Inspection Panel */}
          <div className="rounded-2xl bg-[#0e111a] border border-white/10 overflow-hidden shadow-2xl">
            <div className="h-10 bg-[#141824] px-4 flex items-center justify-between border-b border-white/5">
              <span className="text-xs font-mono text-slate-400">
                Sources/UtterKit/{steps[activeStep].tag}.swift
              </span>
              <span className="text-[11px] font-mono text-orange-400">Swift + C++</span>
            </div>
            <pre className="p-6 font-mono text-xs sm:text-sm text-slate-200 overflow-x-auto leading-relaxed">
              <code>{steps[activeStep].code}</code>
            </pre>
          </div>
        </div>

      </div>
    </section>
  );
}
