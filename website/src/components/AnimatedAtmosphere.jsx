import React, { useEffect } from 'react';
import { motion, useScroll, useTransform, useReducedMotion, useMotionValue, useSpring } from 'framer-motion';

/**
 * AnimatedAtmosphere: Ultra-premium native macOS Sonoma/Sequoia dark glass atmosphere.
 * Replaces the old photographic hilly wallpaper with deep cosmic obsidian,
 * living chromatic aurora meshes, and flowing acoustic 3D voice wave ribbons.
 * Tuned with Apple fluid physics and GPU-accelerated compositor rendering.
 */
export default function AnimatedAtmosphere({ currentTheme = 'system-glass' }) {
  const prefersReducedMotion = useReducedMotion();
  const { scrollY } = useScroll();

  // Subtle Parallax depth for the cosmic nebula layers
  const nebulaY1 = useTransform(scrollY, [0, 4000], [0, -120]);
  const waveY = useTransform(scrollY, [0, 4000], [0, -160]);

  // High-Performance GPU Cursor Spotlight (Apple Spring Physics, Zero Layout Thrashing)
  const mouseX = useMotionValue(typeof window !== 'undefined' ? window.innerWidth * 0.5 : 500);
  const mouseY = useMotionValue(typeof window !== 'undefined' ? window.innerHeight * 0.3 : 300);

  // Apple critically damped spring: smooth, non-oscillating, 1:1 fluid tracking
  const springX = useSpring(mouseX, { stiffness: 120, damping: 22, mass: 0.8 });
  const springY = useSpring(mouseY, { stiffness: 120, damping: 22, mass: 0.8 });

  useEffect(() => {
    const handleMouseMove = (e) => {
      mouseX.set(e.clientX);
      mouseY.set(e.clientY);
    };
    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, [mouseX, mouseY]);

  return (
    <div className="fixed inset-0 z-0 pointer-events-none overflow-hidden select-none bg-[#090a10]">
      {/* 1. Deep Cosmic Obsidian Base Mesh with Radial Vignette */}
      <div
        className="absolute inset-0 bg-radial-gradient from-[#141522] via-[#0b0c14] to-[#07070b]"
        style={{
          background: 'radial-gradient(ellipse at 50% 15%, #181928 0%, #0d0e18 45%, #07070b 100%)',
        }}
      />

      {/* 2. Living Luminous Chromatic Auroras (macOS Sequoia / Sonoma Twilight Spectrum) */}
      <motion.div
        style={prefersReducedMotion ? {} : { y: nebulaY1 }}
        className="absolute inset-0 pointer-events-none"
      >
        {/* Deep Sunset Ember / Warm Glow (Top-Left / Center) */}
        <motion.div
          animate={
            prefersReducedMotion
              ? {}
              : {
                  x: [-30, 40, -30],
                  y: [-20, 25, -20],
                  scale: [1, 1.12, 1],
                  opacity: [0.35, 0.48, 0.35],
                }
          }
          transition={{ duration: 16, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute -top-24 left-[10%] w-[720px] h-[640px] rounded-full bg-gradient-to-tr from-[#f97316]/30 via-[#fb923c]/20 to-transparent blur-[140px]"
        />

        {/* Electric Indigo & Royal Purple Horizon (Top-Right) */}
        <motion.div
          animate={
            prefersReducedMotion
              ? {}
              : {
                  x: [40, -30, 40],
                  y: [20, -30, 20],
                  scale: [1.08, 0.95, 1.08],
                  opacity: [0.38, 0.52, 0.38],
                }
          }
          transition={{ duration: 20, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute top-10 -right-24 w-[780px] h-[700px] rounded-full bg-gradient-to-bl from-[#6366f1]/35 via-[#8b5cf6]/25 to-transparent blur-[150px]"
        />

        {/* Midnight Cyan Whisper Core (Center Mid-ground) */}
        <motion.div
          animate={
            prefersReducedMotion
              ? {}
              : {
                  x: [-25, 35, -25],
                  y: [30, -20, 30],
                  scale: [0.95, 1.1, 0.95],
                }
          }
          transition={{ duration: 18, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute top-1/3 left-1/4 w-[650px] h-[600px] rounded-full bg-gradient-to-tr from-[#06b6d4]/25 via-[#3b82f6]/18 to-transparent blur-[140px]"
        />

        {/* Deep Rose & Magenta Velvet Accent (Lower Right) */}
        <motion.div
          animate={
            prefersReducedMotion
              ? {}
              : {
                  x: [30, -20, 30],
                  y: [-15, 25, -15],
                  scale: [1, 1.15, 1],
                }
          }
          transition={{ duration: 22, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute bottom-20 right-[15%] w-[680px] h-[580px] rounded-full bg-gradient-to-tl from-[#ec4899]/20 via-[#a855f7]/18 to-transparent blur-[150px]"
        />
      </motion.div>

      {/* 3. Interactive Cursor Spotlight (Apple Spring Physics, GPU Compositor) */}
      <motion.div
        className="absolute top-0 left-0 w-[600px] h-[600px] rounded-full pointer-events-none blur-[130px] opacity-25 gpu-accelerate"
        style={{
          x: springX,
          y: springY,
          translateX: '-50%',
          translateY: '-50%',
          background: 'radial-gradient(circle, rgba(249,115,22,0.3) 0%, rgba(99,102,241,0.15) 50%, transparent 70%)',
        }}
      />

      {/* 4. Flowing 3D Acoustic Wave Ribbons (Speech Audio Spectrum Physics) */}
      <motion.div
        style={prefersReducedMotion ? {} : { y: waveY }}
        className="absolute inset-0 pointer-events-none opacity-40 mix-blend-screen"
      >
        <svg
          className="w-full h-full"
          xmlns="http://www.w3.org/2000/svg"
          preserveAspectRatio="none"
          viewBox="0 0 1440 900"
        >
          <defs>
            <linearGradient id="acousticWaveGrad1" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#f97316" stopOpacity="0.85" />
              <stop offset="35%" stopColor="#ec4899" stopOpacity="0.75" />
              <stop offset="70%" stopColor="#6366f1" stopOpacity="0.75" />
              <stop offset="100%" stopColor="#06b6d4" stopOpacity="0.85" />
            </linearGradient>

            <linearGradient id="acousticWaveGrad2" x1="100%" y1="0%" x2="0%" y2="0%">
              <stop offset="0%" stopColor="#3b82f6" stopOpacity="0.7" />
              <stop offset="50%" stopColor="#8b5cf6" stopOpacity="0.6" />
              <stop offset="100%" stopColor="#f59e0b" stopOpacity="0.7" />
            </linearGradient>
          </defs>

          {/* Primary Speech Ribbon */}
          <motion.path
            d="M0,380 C320,280 480,480 800,380 C1120,280 1280,420 1440,340 L1440,900 L0,900 Z"
            fill="url(#acousticWaveGrad1)"
            opacity="0.22"
            animate={
              prefersReducedMotion
                ? {}
                : {
                    d: [
                      "M0,380 C320,280 480,480 800,380 C1120,280 1280,420 1440,340 L1440,900 L0,900 Z",
                      "M0,420 C320,460 480,300 800,430 C1120,360 1280,300 1440,390 L1440,900 L0,900 Z",
                      "M0,380 C320,280 480,480 800,380 C1120,280 1280,420 1440,340 L1440,900 L0,900 Z",
                    ],
                  }
            }
            transition={{ duration: 16, repeat: Infinity, ease: 'easeInOut' }}
          />

          {/* Harmonic Counter-Wave Ribbon */}
          <motion.path
            d="M0,560 C360,480 600,660 960,540 C1200,460 1340,600 1440,530 L1440,900 L0,900 Z"
            fill="url(#acousticWaveGrad2)"
            opacity="0.18"
            animate={
              prefersReducedMotion
                ? {}
                : {
                    d: [
                      "M0,560 C360,480 600,660 960,540 C1200,460 1340,600 1440,530 L1440,900 L0,900 Z",
                      "M0,520 C360,600 600,480 960,580 C1200,530 1340,470 1440,560 L1440,900 L0,900 Z",
                      "M0,560 C360,480 600,660 960,540 C1200,460 1340,600 1440,530 L1440,900 L0,900 Z",
                    ],
                  }
            }
            transition={{ duration: 19, repeat: Infinity, ease: 'easeInOut' }}
          />
        </svg>
      </motion.div>

      {/* 5. Subtle Ultra-Fine Studio Grid & Frosted Vignette */}
      <div
        className="absolute inset-0 opacity-[0.03] pointer-events-none"
        style={{
          backgroundImage: `linear-gradient(to right, rgba(255, 255, 255, 0.25) 1px, transparent 1px), linear-gradient(to bottom, rgba(255, 255, 255, 0.25) 1px, transparent 1px)`,
          backgroundSize: '48px 48px',
        }}
      />

      {/* 6. High-Contrast Vignette for Razor-Sharp Text Readability */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#090a10]/60 via-transparent to-[#07070b]/90 pointer-events-none" />
    </div>
  );
}
