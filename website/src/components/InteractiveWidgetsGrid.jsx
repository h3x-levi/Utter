import React, { useState } from 'react';
import { Mic, Volume2, BookOpen, FileText, PhoneCall, Cpu, Sparkles, Check } from 'lucide-react';

export default function InteractiveWidgetsGrid() {
  // Widget 1: Dictionary Context Bias
  const [customWord, setCustomWord] = useState('whisper.cpp');
  const [biasWords, setBiasWords] = useState(['whisper.cpp', 'MetalShaders', 'CoreAudio', 'AVAudioEngine', 'UtterKit']);
  const [newWordInput, setNewWordInput] = useState('');

  const addWord = (e) => {
    e.preventDefault();
    if (newWordInput.trim() && !biasWords.includes(newWordInput.trim())) {
      setBiasWords([...biasWords, newWordInput.trim()]);
      setNewWordInput('');
    }
  };

  // Widget 2: Instant Scratchpad
  const [noteContent, setNoteContent] = useState('# Morning Standup Notes\n- Metal GPU compute shader compilation optimized.\n- Bundled small.en model tested on macOS 14 & 15.\n- 0 telemetry sockets verified.');

  // Widget 3: Audio Meter Visualizer
  const [meterActive, setMeterActive] = useState(false);

  return (
    <section id="features" className="py-28 px-4 sm:px-6 relative z-10 border-t border-zinc-800/80 bg-[#09090b]">
      <div className="max-w-7xl mx-auto">

        {/* Header */}
        <div className="text-center max-w-3xl mx-auto mb-20">
          <span className="text-xs uppercase font-mono tracking-widest text-zinc-400 font-semibold">
            Interactive Modular System
          </span>
          <h2 className="text-4xl sm:text-5xl font-bold text-white mt-3 mb-4 tracking-tight">
            Six live tools. One unified architecture.
          </h2>
          <p className="text-zinc-400 text-base sm:text-lg">
            Every feature in Utter runs entirely in unified Apple Silicon memory with zero network overhead.
          </p>
        </div>

        {/* 6 Interactive Widgets Bento Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

          {/* 1. Custom Vocabulary & Bias Studio */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <BookOpen className="w-4 h-4 text-white" /> Dictionary Studio
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">Context Biasing</span>
              </div>
              <p className="text-xs text-zinc-400 mb-4">
                Add developer terms to inject them with 100% precision into the Whisper decoder.
              </p>

              {/* Tag List */}
              <div className="flex flex-wrap gap-1.5 mb-4">
                {biasWords.map((w, idx) => (
                  <span key={idx} className="px-2.5 py-1 rounded-md bg-[#16161a] border border-zinc-700 text-xs font-mono text-zinc-300">
                    {w}
                  </span>
                ))}
              </div>
            </div>

            <form onSubmit={addWord} className="flex gap-2 mt-4 pt-4 border-t border-zinc-800">
              <input
                type="text"
                value={newWordInput}
                onChange={(e) => setNewWordInput(e.target.value)}
                placeholder="Add custom keyword..."
                className="flex-1 bg-[#121215] border border-zinc-700 rounded-lg px-3 py-1.5 text-xs font-mono text-white placeholder:text-zinc-600 focus:outline-none focus:border-zinc-500"
              />
              <button
                type="submit"
                className="px-3 py-1.5 rounded-lg bg-white text-black text-xs font-medium hover:bg-zinc-200"
              >
                Add
              </button>
            </form>
          </div>

          {/* 2. Interactive Note Scratchpad */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <FileText className="w-4 h-4 text-white" /> Notes Studio (⌘N)
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">Auto-Saved</span>
              </div>
              <textarea
                value={noteContent}
                onChange={(e) => setNoteContent(e.target.value)}
                rows={5}
                className="w-full bg-[#121215] border border-zinc-800 rounded-xl p-3 text-xs font-mono text-zinc-200 focus:outline-none focus:border-zinc-600 leading-relaxed resize-none"
              />
            </div>
            <div className="mt-4 pt-3 border-t border-zinc-800 flex items-center justify-between text-[11px] font-mono text-zinc-500">
              <span>Markdown Supported</span>
              <span className="text-zinc-400">Local SQLite Storage</span>
            </div>
          </div>

          {/* 3. Realtime Audio Spectrum Meter */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <Volume2 className="w-4 h-4 text-white" /> Audio Engine (16kHz PCM)
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">AVAudioEngine</span>
              </div>
              <p className="text-xs text-zinc-400 mb-6">
                Hardware silence gating with zero buffer underruns and sub-millisecond tap response.
              </p>

              {/* Dynamic Equalizer Visualizer */}
              <div className="h-16 flex items-end gap-1 p-3 bg-[#121215] rounded-xl border border-zinc-800">
                {[30, 65, 85, 45, 95, 70, 40, 80, 60, 90, 50, 75, 35].map((val, i) => (
                  <div
                    key={i}
                    className="flex-1 bg-zinc-400 rounded-sm transition-all duration-150"
                    style={{ height: meterActive ? `${Math.min(100, val + (i % 3) * 15)}%` : `${val * 0.4}%` }}
                  />
                ))}
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-zinc-800 flex items-center justify-between">
              <button
                onClick={() => setMeterActive(!meterActive)}
                className="px-3 py-1 rounded-lg text-xs font-mono bg-zinc-800 hover:bg-zinc-700 text-zinc-200 border border-zinc-700"
              >
                {meterActive ? 'Pause Simulation' : 'Simulate Live Audio'}
              </button>
              <span className="text-[11px] font-mono text-zinc-500">0.0% CPU</span>
            </div>
          </div>

          {/* 4. Sub-200ms Metal Shaders */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <Cpu className="w-4 h-4 text-white" /> Metal GPU Shaders
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">Unified Memory</span>
              </div>
              <p className="text-xs text-zinc-400 mb-4">
                whisper.cpp neural inference compiled with native Apple Silicon compute kernels.
              </p>

              <div className="p-3 bg-[#121215] rounded-xl border border-zinc-800 font-mono text-xs text-zinc-300 space-y-1.5">
                <div className="flex justify-between"><span>Kernel:</span><span className="text-white">ggml-metal.metal</span></div>
                <div className="flex justify-between"><span>Precision:</span><span className="text-white">Q5_1 (16-bit float)</span></div>
                <div className="flex justify-between"><span>Throughput:</span><span className="text-white">188 WPM</span></div>
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-zinc-800 text-xs font-mono text-zinc-400 flex items-center justify-between">
              <span>Zero Temporary Files</span>
              <span className="text-emerald-400">✓ In-Memory Ring Buffer</span>
            </div>
          </div>

          {/* 5. Two-Way Meeting Taps */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <PhoneCall className="w-4 h-4 text-white" /> Meeting Diarization
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">CoreAudio</span>
              </div>
              <p className="text-xs text-zinc-400 mb-4">
                Dual-channel capture taps both your mic and incoming participants in Zoom, Meet, and Teams.
              </p>

              <div className="p-3 bg-[#121215] rounded-xl border border-zinc-800 font-mono text-xs space-y-1">
                <div className="text-zinc-200 font-semibold">Channel 1: Microphone (You)</div>
                <div className="text-zinc-400">Channel 2: System Audio (Remote)</div>
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-zinc-800 text-xs font-mono text-zinc-500 flex items-center justify-between">
              <span>ScreenCaptureKit</span>
              <span className="text-zinc-400">Speaker Attribution</span>
            </div>
          </div>

          {/* 6. Apple Intelligence Transforms */}
          <div className="apple-panel rounded-2xl p-6 border border-zinc-800 flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between text-xs font-mono text-zinc-400 mb-4 pb-2 border-b border-zinc-800">
                <span className="flex items-center gap-1.5 text-zinc-200 font-semibold">
                  <Sparkles className="w-4 h-4 text-white" /> Local AI Engine
                </span>
                <span className="text-[10px] bg-zinc-800 px-2 py-0.5 rounded text-zinc-400">FoundationModels</span>
              </div>
              <p className="text-xs text-zinc-400 mb-4">
                Clean filler words, summarize audio transcripts, or convert stream into bullet points.
              </p>

              <div className="p-3 bg-[#121215] rounded-xl border border-zinc-800 font-mono text-xs text-zinc-300">
                <div>• Clean Grammar</div>
                <div>• Extract Action Items</div>
                <div>• Swift / TS Docstrings</div>
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-zinc-800 text-xs font-mono text-zinc-400 flex items-center justify-between">
              <span>Zero Cloud APIs</span>
              <span className="text-emerald-400">✓ On-Device</span>
            </div>
          </div>

        </div>

      </div>
    </section>
  );
}
