import React from 'react';
import { motion, useReducedMotion } from 'framer-motion';

export default function AnimatedAtmosphere() {
  const shouldReduceMotion = useReducedMotion();

  return (
    <div className="fixed inset-0 pointer-events-none z-0 overflow-hidden select-none">
      {/* 1. Serene Grassy Dune / Hilly Landscape Layer */}
      <motion.div
        animate={shouldReduceMotion ? { scale: 1, y: 0 } : {
          scale: [1, 1.03, 1],
          y: [0, -10, 0],
        }}
        transition={shouldReduceMotion ? { duration: 0 } : {
          duration: 16,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="absolute inset-0 bg-cover bg-center opacity-40 mix-blend-multiply"
        style={{
          backgroundImage: "url('/assets/hilly_bg.jpg')",
        }}
      />

      {/* 2. Floating Colorful Aurora Auras */}
      {/* Warm Sunset Amber */}
      <motion.div
        animate={shouldReduceMotion ? { x: 0, y: 0, scale: 1 } : {
          x: [0, 60, -40, 0],
          y: [0, -50, 40, 0],
          scale: [1, 1.15, 0.95, 1],
        }}
        transition={shouldReduceMotion ? { duration: 0 } : {
          duration: 18,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="absolute -top-20 left-[10%] w-[650px] h-[650px] rounded-full opacity-35 filter blur-[90px]"
        style={{
          background: 'radial-gradient(circle, rgba(251, 191, 36, 0.55) 0%, rgba(245, 158, 11, 0.15) 50%, transparent 70%)',
        }}
      />

      {/* Radiant Violet / Indigo */}
      <motion.div
        animate={shouldReduceMotion ? { x: 0, y: 0, scale: 1 } : {
          x: [0, -70, 50, 0],
          y: [0, 60, -30, 0],
          scale: [1, 1.1, 0.9, 1],
        }}
        transition={shouldReduceMotion ? { duration: 0 } : {
          duration: 22,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="absolute top-1/4 right-[5%] w-[750px] h-[750px] rounded-full opacity-30 filter blur-[100px]"
        style={{
          background: 'radial-gradient(circle, rgba(129, 140, 248, 0.6) 0%, rgba(168, 85, 247, 0.2) 50%, transparent 70%)',
        }}
      />

      {/* Fresh Emerald / Sage */}
      <motion.div
        animate={shouldReduceMotion ? { x: 0, y: 0, scale: 1 } : {
          x: [0, 40, -60, 0],
          y: [0, -40, 50, 0],
          scale: [0.95, 1.12, 1, 0.95],
        }}
        transition={shouldReduceMotion ? { duration: 0 } : {
          duration: 20,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="absolute top-2/3 left-[20%] w-[700px] h-[700px] rounded-full opacity-25 filter blur-[110px]"
        style={{
          background: 'radial-gradient(circle, rgba(52, 211, 153, 0.45) 0%, rgba(16, 185, 129, 0.1) 50%, transparent 70%)',
        }}
      />

      {/* Soft Rose Pink */}
      <motion.div
        animate={shouldReduceMotion ? { x: 0, y: 0, scale: 1 } : {
          x: [0, -50, 40, 0],
          y: [0, 50, -40, 0],
          scale: [1, 0.95, 1.1, 1],
        }}
        transition={shouldReduceMotion ? { duration: 0 } : {
          duration: 24,
          repeat: Infinity,
          ease: "easeInOut",
        }}
        className="absolute -bottom-20 right-[25%] w-[600px] h-[600px] rounded-full opacity-30 filter blur-[95px]"
        style={{
          background: 'radial-gradient(circle, rgba(244, 114, 182, 0.5) 0%, rgba(236, 72, 153, 0.15) 50%, transparent 70%)',
        }}
      />

      {/* 3. Subtle Warm Ambient Overlay */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#fafafa]/50 via-[#fafafa]/20 to-[#fafafa]/60" />
    </div>
  );
}
