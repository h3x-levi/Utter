import React, { useState } from 'react';
import { Mic, Cpu, Sparkles, Keyboard, CheckCircle2 } from 'lucide-react';

export default function WorkflowSteps() {
  const [activeStep, setActiveStep] = useState(0);

  const steps = [
    {
      id: 1,
      title: 'Global Push-to-Talk Capture',
      subtitle: 'Low-latency hardware event tap',
      icon: <Mic className="w-5 h-5 text-zinc-300" />,
      tag: 'Audio Engine',
      desc: 'Press and hold your configured global hotkey (Fn, Right Option, or Right Command). Utter taps your microphone with AVAudioEngine into a 16kHz float32 ring buffer with sub-millisecond start latency and adaptive silence gating.',
      code: `// Hardware Flag Monitor\nKeyMonitor.shared.onKeyDown = { [weak self] in\n    self?.audioRecorder.startCapturingStream()\n    self?.pillWindow.morph(to: .recording)\n}`,
      details: ['Sub-5ms hotkey trigger response', 'Adaptive silence threshold gating', 'Automatic background media pause'],
    },
    {
      id: 2,
      title: 'whisper.cpp on Metal GPU',
      subtitle: 'Zero-copy neural inference',
      icon: <Cpu className="w-5 h-5 text-zinc-300" />,
      tag: 'Metal Compute',
      desc: 'Audio PCM frames are fed directly to whisper.cpp accelerated via Apple Metal compute shaders. Processing happens directly in unified Apple Silicon memory without writing WAV files to disk.',
      code: `// Metal Compute Pipeline\nlet context = whisper_init_from_file_with_params(modelPath, params)\nwhisper_full_parallel(context, wparams, pcmData, nSamples, nThreads)\nlet text = whisper_full_get_segment_text(context, 0)`,
      details: ['Sub-200ms end-to-end latency', 'No disk I/O / Zero temporary files', 'Quantized Q5_1 for maximum fidelity'],
    },
    {
      id: 3,
      title: 'Context Biasing & Normalization',
      subtitle: 'Developer dictionary & grammar polish',
      icon: <Sparkles className="w-5 h-5 text-zinc-300" />,
      tag: 'Entity Bias',
      desc: 'Utter injects your custom vocabulary (code variable names, internal tools, acronyms) directly into the Whisper decoder. Sentence polish removes disfluencies (um, ah) and restores precise punctuation.',
      code: `// Context Biasing & Correction\nlet biasedText = DictionaryCorrector.shared.apply(rawText)\nlet polished = SentencePolish.restorePunctuation(biasedText)\nreturn SnippetTemplates.expand(polished)`,
      details: ['100% accurate coding syntax & camelCase', 'Zero cloud dictionary leaks', 'Instant macro & snippet expansions'],
    },
    {
      id: 4,
      title: 'Direct Accessibility Injection',
      subtitle: 'Zero clipboard pollution',
      icon: <Keyboard className="w-5 h-5 text-zinc-300" />,
      tag: 'Native AppKit',
      desc: 'Transcribed text is injected directly at your active cursor via macOS Accessibility APIs and synthetic CGEvent keystrokes. Your clipboard history remains completely untouched.',
      code: `// Non-Destructive Injection\nlet focusedElement = AXUIElementCopyFocusedUIElement()\nAXUIElementSetAttributeValue(focusedElement, kAXValueAttribute, newText)\n// Clipboard history preserved 100%`,
      details: ['Works inside Cursor, Xcode, Slack, Obsidian', 'Preserves Alfred / Raycast clipboard history', 'Seamless undo/redo support'],
    },
  ];

  return (
    <section id="workflow" className="py-28 px-6 relative z-10 bg-[#09090b] border-t border-zinc-800/80">
      <div className="max-w-7xl mx-auto">

        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            The Zero-Latency Pipeline
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            How voice turns into code in 168ms.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            A look under the hood at Utter's bi-ported Swift and C++ architecture.
          </p>
        </div>

        {/* 4 Step Navigation Tabs */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-8">
          {steps.map((step, idx) => (
            <button
              key={step.id}
              onClick={() => setActiveStep(idx)}
              className={`p-5 rounded-xl text-left transition-all border ${
                activeStep === idx
                  ? 'bg-zinc-800 border-zinc-500 text-white'
                  : 'bg-zinc-900/60 border-zinc-800 text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50'
              }`}
            >
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-mono font-bold px-2 py-0.5 rounded bg-zinc-800 text-zinc-200">
                  0{step.id}
                </span>
                <span className="text-[10px] uppercase font-mono text-zinc-500">
                  {step.tag}
                </span>
              </div>
              <div className="flex items-center gap-2.5 mb-1.5">
                {step.icon}
                <h4 className="text-sm font-semibold text-white tracking-tight">{step.title}</h4>
              </div>
              <p className="text-xs text-zinc-400">{step.subtitle}</p>
            </button>
          ))}
        </div>

        {/* Active Step Card */}
        <div className="apple-panel rounded-2xl p-8 sm:p-12 border border-zinc-800 grid grid-cols-1 lg:grid-cols-2 gap-10 items-center">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-md bg-zinc-800 text-zinc-300 text-xs font-mono font-medium mb-4 border border-zinc-700">
              Step 0{steps[activeStep].id} • {steps[activeStep].tag}
            </div>

            <h3 className="text-2xl sm:text-3xl font-bold text-white mb-4">
              {steps[activeStep].title}
            </h3>

            <p className="text-zinc-400 text-sm sm:text-base leading-relaxed mb-8">
              {steps[activeStep].desc}
            </p>

            <div className="space-y-3">
              {steps[activeStep].details.map((detail, i) => (
                <div key={i} className="flex items-center gap-3 text-sm text-zinc-300 font-medium">
                  <CheckCircle2 className="w-4 h-4 text-zinc-400 shrink-0" />
                  <span>{detail}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Code Inspection Panel */}
          <div className="rounded-xl bg-[#0c0c0e] border border-zinc-800 overflow-hidden shadow-2xl">
            <div className="h-9 bg-[#161619] px-4 flex items-center justify-between border-b border-zinc-800 text-xs font-mono text-zinc-400">
              <span>Sources/UtterKit/{steps[activeStep].tag}.swift</span>
              <span className="text-zinc-500">Swift + C++</span>
            </div>
            <pre className="p-5 font-mono text-xs text-zinc-300 overflow-x-auto leading-relaxed">
              <code>{steps[activeStep].code}</code>
            </pre>
          </div>
        </div>

      </div>
    </section>
  );
}
