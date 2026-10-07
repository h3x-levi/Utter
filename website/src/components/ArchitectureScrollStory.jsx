import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Cpu, Shield, Zap, Keyboard, Sparkles, Database, Layers, ArrowRight, CheckCircle2 } from 'lucide-react';

const ARCHITECTURE_STEPS = [
  {
    step: '01',
    tag: 'GLOBAL PUSH-TO-TALK CAPTURE',
    title: 'Hardware-level key press with sub-5ms activation.',
    description:
      'Holding Fn or Right Option fires a low-level macOS CGEvent tap. Utter immediately provisions a ring buffer in unified RAM, sampling microphone audio at 16,000Hz float PCM with zero disk writes.',
    icon: Keyboard,
    badge: 'Zero Polling / Sub-5ms',
    metric: '5ms',
    metricLabel: 'Hardware Capture Delay',
    details: [
      'Kernel-level CGEventTap event listener',
      'Circular RAM audio buffer (no temp files)',
      'RMS waveform calculated asynchronously',
    ],
  },
  {
    step: '02',
    tag: 'WHISPER.CPP METAL ACCELERATION',
    title: 'Neural Core ML inference directly on Apple Silicon GPU.',
    description:
      'The audio spectrogram is dispatched to whisper.cpp accelerated via Apple Metal Performance Shaders (MPS). The 181MB quantized model processes audio in real time with 0 network sockets and 0 cloud hops.',
    icon: Cpu,
    badge: '100% Apple Silicon Metal',
    metric: '168ms',
    metricLabel: 'Inference Latency',
    details: [
      'whisper.cpp in-process Metal shaders',
      'Zero cloud roundtrips (saves 1,200ms)',
      '181MB ggml quantized model in RAM',
    ],
  },
  {
    step: '03',
    tag: 'UNIVERSAL ACCESSIBILITY INJECTION',
    title: 'Direct Unicode injection into your focused cursor.',
    description:
      'Using native macOS AXUIElement APIs, Utter targets the active window element and injects your words as synthetic Unicode events. It handles code syntax, punctuation, and capital letters automatically.',
    icon: Zap,
    badge: 'Universal macOS Compatibility',
    metric: '180 WPM',
    metricLabel: 'Transcription Throughput',
    details: [
      'Works in VS Code, Slack, Xcode, Terminal',
      'Context-aware code and punctuation heuristics',
      'Zero clipboard pollution or paste delays',
    ],
  },
];

export default function ArchitectureScrollStory() {
  const [activeStep, setActiveStep] = useState(0);

  return (
    <section id="architecture" className="relative py-28 px-4 sm:px-6 lg:px-12 w-full max-w-[1360px] mx-auto">
      {/* Section Header */}
      <div className="flex flex-col items-center text-center mb-16">
        <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full liquid-glass-pill text-xs font-mono text-orange-400 mb-4 border border-orange-500/20">
          <Layers size={13} />
          <span>ON-DEVICE ARCHITECTURE</span>
        </div>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight text-white mb-4">
          The pipeline behind zero latency.
        </h2>
        <p className="text-zinc-400 text-sm sm:text-base max-w-[620px]">
          How Utter bypasses cloud servers entirely, converting your voice to text in 168ms on Apple Silicon.
        </p>
      </div>

      {/* Interactive Step Timeline Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-12">
        {ARCHITECTURE_STEPS.map((item, idx) => {
          const Icon = item.icon;
          const isSelected = activeStep === idx;
          return (
            <div
              key={item.step}
              onClick={() => setActiveStep(idx)}
              className={`liquid-glass rounded-3xl p-7 border transition-all duration-300 cursor-pointer relative overflow-hidden flex flex-col justify-between ${
                isSelected
                  ? 'border-orange-500/60 shadow-xl shadow-orange-500/10 bg-zinc-900/80 -translate-y-1'
                  : 'border-white/10 hover:border-white/20 hover:bg-zinc-900/40'
              }`}
            >
              {/* Step indicator */}
              <div>
                <div className="flex items-center justify-between mb-5">
                  <span className="text-2xl font-black font-mono text-zinc-500">
                    {item.step}
                  </span>
                  <div className={`p-2.5 rounded-xl ${isSelected ? 'bg-orange-500 text-zinc-950' : 'bg-white/5 text-zinc-400'}`}>
                    <Icon size={18} />
                  </div>
                </div>

                <div className="text-[11px] font-mono tracking-wider text-orange-400 font-semibold mb-2">
                  {item.tag}
                </div>
                <h3 className="text-lg font-bold text-white mb-3 leading-snug">
                  {item.title}
                </h3>
                <p className="text-zinc-400 text-xs sm:text-sm leading-relaxed mb-6">
                  {item.description}
                </p>
              </div>

              {/* Metric Callout */}
              <div className="pt-4 border-t border-white/5 flex items-end justify-between">
                <div>
                  <div className="text-2xl font-black font-mono text-white">{item.metric}</div>
                  <div className="text-[11px] font-mono text-zinc-500">{item.metricLabel}</div>
                </div>
                <span className="text-xs font-mono text-orange-400 font-medium flex items-center gap-1">
                  <span>Phase {item.step}</span>
                  <ArrowRight size={12} />
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Deep Dive Hardware Architecture Visualization Banner */}
      <div className="liquid-glass rounded-3xl p-8 sm:p-10 border border-white/10 relative overflow-hidden">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          <div className="lg:col-span-7">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-orange-500/10 text-orange-400 font-mono text-xs mb-4 border border-orange-500/20">
              <Shield size={13} />
              <span>AIR-GAPPED HARDWARE FLOW</span>
            </div>
            <h3 className="text-2xl sm:text-3xl font-bold text-white mb-3">
              No Cloud Servers. No DNS Queries. No Telemetry.
            </h3>
            <p className="text-zinc-400 text-sm leading-relaxed mb-6">
              When using cloud dictation tools, your spoken words are compressed, uploaded over WiFi, transcribed in a remote datacenter, and streamed back - leaking personal conversations and adding 1,200ms+ of delay. Utter keeps everything in local unified memory on your Mac.
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              {[
                'Zero Remote Logs',
                'Core ML Neural Engine',
                'Sub-200ms Latency',
              ].map((text) => (
                <div key={text} className="flex items-center gap-2 text-xs font-medium text-zinc-300">
                  <CheckCircle2 size={14} className="text-emerald-400 shrink-0" />
                  <span>{text}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="lg:col-span-5 bg-zinc-950/80 rounded-2xl p-5 border border-white/10 font-mono text-xs text-zinc-300 shadow-inner">
            <div className="flex items-center justify-between text-[11px] text-zinc-500 pb-3 mb-3 border-b border-white/10">
              <span>MACOS ACTIVITY MONITOR</span>
              <span className="text-emerald-400">STATUS: LOCAL_INFERENCE</span>
            </div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-zinc-400">Process:</span>
                <span className="text-white font-semibold">Utter.app (Native Swift)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-zinc-400">GPU Accelerator:</span>
                <span className="text-indigo-400">Metal Performance Shaders</span>
              </div>
              <div className="flex justify-between">
                <span className="text-zinc-400">Inference Engine:</span>
                <span className="text-orange-400">whisper.cpp (181MB Q5)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-zinc-400">Network Sockets:</span>
                <span className="text-emerald-400 font-bold">0 sockets open</span>
              </div>
              <div className="flex justify-between">
                <span className="text-zinc-400">Telemetry Outbound:</span>
                <span className="text-emerald-400 font-bold">0 bytes sent</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
