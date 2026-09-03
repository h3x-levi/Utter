import React from 'react';
import { motion } from 'framer-motion';
import { Download, Github } from 'lucide-react';

const DownloadSection = () => {
  return (
    <section className="px-4 mt-8">
      <div className="bg-[#0a0a0a] text-white rounded-[40px] md:rounded-[60px] py-28 md:py-36 px-6 relative overflow-hidden">
        {/* Subtle radial glow */}
        <div
          className="absolute inset-0 pointer-events-none opacity-30"
          style={{
            background: 'radial-gradient(ellipse 60% 50% at 50% 40%, rgba(95, 97, 237, 0.15), transparent)',
          }}
        />

        <div className="max-w-4xl mx-auto text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
            className="mb-8"
          >
            <img
              src="/assets/app-icon.png"
              alt="Utter"
              className="w-16 h-16 rounded-2xl mx-auto shadow-2xl border border-white/10"
            />
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="text-4xl sm:text-5xl md:text-7xl font-black tracking-tight mb-6 leading-[1.06]"
          >
            Ready to speak at the speed of thought?
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.15 }}
            className="text-lg text-white/50 max-w-xl mx-auto mb-12"
          >
            Download Utter for macOS today. 100% free, fully open source, and completely private.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-14"
          >
            <a
              href="https://github.com/h3x-levi/Utter/releases/latest"
              className="flex items-center justify-center gap-2.5 bg-white text-black px-10 py-4.5 rounded-full font-bold text-[15px] hover:bg-gray-200 transition-all active:scale-[0.97] w-full sm:w-auto shadow-lg"
            >
              <Download size={20} />
              Download for Mac
            </a>
            <a
              href="https://github.com/h3x-levi/Utter"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2.5 border-2 border-white/15 text-white px-10 py-4.5 rounded-full font-bold text-[15px] hover:bg-white/10 transition-all active:scale-[0.97] w-full sm:w-auto"
            >
              <Github size={20} />
              View on GitHub
            </a>
          </motion.div>

          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="font-mono-sm text-xs text-white/30"
          >
            MIT License · macOS 13+ · Apple Silicon & Intel · v1.1.56
          </motion.p>
        </div>
      </div>
    </section>
  );
};

export default DownloadSection;
