import React from 'react';
import { motion } from 'framer-motion';
import { Shield } from 'lucide-react';

const PrivacySection = () => {
  return (
    <section id="privacy" className="py-32 px-4 relative overflow-hidden">
      <div className="max-w-4xl mx-auto text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="flex justify-center mb-8"
        >
          <div className="w-16 h-16 rounded-full bg-black/[0.06] flex items-center justify-center">
            <Shield className="w-7 h-7 text-[#0d0d0d]" />
          </div>
        </motion.div>

        <motion.h2
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="text-4xl sm:text-5xl font-black tracking-tight mb-6 text-[#0d0d0d]"
        >
          Air-gapped by architecture.
        </motion.h2>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="text-lg sm:text-xl text-black/55 max-w-2xl mx-auto mb-14 leading-relaxed"
        >
          Utter has zero analytics libraries, zero tracking pixels, and makes zero network requests.
          Every audio frame is processed entirely in unified Apple Silicon memory. What you say never
          leaves your Mac.
        </motion.p>

        {/* Terminal verification */}
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="max-w-2xl mx-auto"
        >
          <div className="obsidian-glass p-1.5 shadow-2xl">
            <div className="bg-[#1a1a1a] rounded-[24px] p-6 text-left font-mono text-sm overflow-x-auto">
              {/* Traffic lights */}
              <div className="flex gap-2 mb-5">
                <div className="w-3 h-3 rounded-full bg-[#ff5f56]" />
                <div className="w-3 h-3 rounded-full bg-[#ffbd2e]" />
                <div className="w-3 h-3 rounded-full bg-[#27c93f]" />
              </div>

              <div className="text-white/50 text-xs mb-1 font-mono-sm">
                # Verify zero outbound network activity
              </div>
              <div className="text-white/90 mb-3">
                <span className="text-green-400">$</span> lsof -i -P | grep -i utter
              </div>
              <div className="text-white/40 italic text-xs mb-4">
                # (no output — 0 sockets open)
              </div>
              <div className="text-white/50 text-xs mb-1 font-mono-sm">
                # Confirm no analytics frameworks
              </div>
              <div className="text-white/90">
                <span className="text-green-400">$</span> strings Utter.app/Contents/MacOS/Utter | grep -i "analytics\|telemetry\|tracking"
              </div>
              <div className="text-white/40 italic text-xs mt-1">
                # (no output — zero telemetry binaries linked)
              </div>

              <div className="mt-5 text-white/90">
                <span className="text-green-400">$</span> <span className="animate-pulse inline-block w-2 h-4 bg-white/60 align-middle" />
              </div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
};

export default PrivacySection;
