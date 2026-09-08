import React from 'react';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';

export default function AnimatedAtmosphere() {
  const prefersReducedMotion = useReducedMotion();
  const { scrollY } = useScroll();

  // Subtle natural parallax as user scrolls down the page
  const y = useTransform(scrollY, [0, 4000], [0, -160]);
  const scale = useTransform(scrollY, [0, 4000], [1, 1.06]);

  return (
    <div className="fixed inset-0 z-0 pointer-events-none overflow-hidden select-none">
      {/* 1. Serene Grassy Dune & Frosted Landscape (Cooldock luxury aesthetic) */}
      <motion.div
        style={prefersReducedMotion ? {} : { y, scale }}
        className="absolute -inset-8 w-[calc(100%+4rem)] h-[calc(100%+4rem)]"
      >
        <img
          src="/assets/hilly_bg.jpg"
          alt=""
          className="w-full h-full object-cover object-center filter brightness-[1.03] contrast-[1.02]"
          loading="eager"
        />
      </motion.div>

      {/* 2. Delicate Frosted Glass Tint - Keeps landscape visible while guaranteeing text legibility */}
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse at 50% 15%, rgba(255, 255, 255, 0.25) 0%, rgba(255, 255, 255, 0.45) 55%, rgba(250, 249, 246, 0.65) 100%)',
          backdropFilter: 'blur(1px)',
          WebkitBackdropFilter: 'blur(1px)',
        }}
      />

      {/* 3. Golden Hour Soft Ambient Glow */}
      <div
        className="absolute inset-0 opacity-30 mix-blend-soft-light pointer-events-none"
        style={{
          background:
            'radial-gradient(circle at 25% 15%, rgba(255, 237, 213, 0.9) 0%, transparent 60%), radial-gradient(circle at 80% 85%, rgba(224, 231, 255, 0.7) 0%, transparent 60%)',
        }}
      />
    </div>
  );
}
