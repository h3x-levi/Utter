import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import StageHero from './StageHero';
import StageDictationHUD from './StageDictationHUD';
import StageModelSwitcher from './StageModelSwitcher';
import StageMeetingStudio from './StageMeetingStudio';
import StageCompanionSandbox from './StageCompanionSandbox';
import StagePrivacyVault from './StagePrivacyVault';
import CurvedLoop from './CurvedLoop';
import { Mic, Zap, Cpu, Users, Heart, ShieldCheck } from 'lucide-react';

export default function PinnedStageExperience({ onStageChange }) {
  const [activeStage, setActiveStage] = useState(0);
  const containerRef = useRef(null);
  const isClickNavigating = useRef(false);

  const stages = [
    { id: 'hero', name: 'Overview', icon: <Mic size={15} /> },
    { id: 'dictation', name: 'Dictation HUD', icon: <Zap size={15} /> },
    { id: 'models', name: 'Speech Models', icon: <Cpu size={15} /> },
    { id: 'meetings', name: 'Meeting Studio', icon: <Users size={15} /> },
    { id: 'companion', name: 'Pixel Pet', icon: <Heart size={15} /> },
    { id: 'privacy', name: 'Privacy Vault', icon: <ShieldCheck size={15} /> },
  ];

  // Scroll sync: calculate active stage based on scroll depth
  useEffect(() => {
    const handleScroll = () => {
      if (isClickNavigating.current || !containerRef.current) return;
      const rect = containerRef.current.getBoundingClientRect();
      const totalScrollable = containerRef.current.offsetHeight - window.innerHeight;
      if (totalScrollable <= 0) return;

      const currentScroll = -rect.top;
      const progress = Math.min(Math.max(currentScroll / totalScrollable, 0), 1);
      const stageIndex = Math.min(Math.floor(progress * stages.length), stages.length - 1);

      setActiveStage((prev) => {
        if (prev !== stageIndex) {
          onStageChange?.(stageIndex);
          return stageIndex;
        }
        return prev;
      });
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [stages.length, onStageChange]);

  const selectStage = (index) => {
    isClickNavigating.current = true;
    setActiveStage(index);
    onStageChange?.(index);

    if (containerRef.current) {
      const totalScrollable = containerRef.current.offsetHeight - window.innerHeight;
      const targetScroll = containerRef.current.offsetTop + (index / (stages.length - 1)) * totalScrollable;
      window.scrollTo({ top: targetScroll, behavior: 'smooth' });
    }

    setTimeout(() => {
      isClickNavigating.current = false;
    }, 800);
  };

  return (
    <div ref={containerRef} className="relative h-[550vh] w-full">
      {/* Sticky Pinned Stage Viewport */}
      <div className="sticky top-0 h-screen w-full flex flex-col justify-between items-center pt-24 pb-28 px-4">

        {/* Dynamic Graphic Stage with 3D Morph Transitions */}
        <div className="w-full flex-1 flex items-center justify-center relative perspective-[1800px] z-10">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeStage}
              initial={{
                opacity: 0,
                scale: 0.92,
                rotateX: 8,
                y: 35,
                filter: 'blur(10px)',
              }}
              animate={{
                opacity: 1,
                scale: 1,
                rotateX: 0,
                y: 0,
                filter: 'blur(0px)',
              }}
              exit={{
                opacity: 0,
                scale: 0.94,
                rotateX: -8,
                y: -35,
                filter: 'blur(10px)',
              }}
              transition={{
                duration: 0.65,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="w-full flex justify-center"
            >
              {activeStage === 0 && <StageHero onExploreFeatures={() => selectStage(1)} />}
              {activeStage === 1 && <StageDictationHUD />}
              {activeStage === 2 && <StageModelSwitcher />}
              {activeStage === 3 && <StageMeetingStudio />}
              {activeStage === 4 && <StageCompanionSandbox />}
              {activeStage === 5 && <StagePrivacyVault />}
            </motion.div>
          </AnimatePresence>
        </div>

        {/* Curved Text Loop Ribbon */}
        <div className="w-full max-w-6xl mx-auto -mb-6 pointer-events-none">
          <CurvedLoop />
        </div>

        {/* Floating Glass Dock Capsule (Vengeance UI / dock.cool Pattern) */}
        <motion.div
          initial={{ y: 50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 flex items-center gap-1.5 sm:gap-2 p-2 rounded-full obsidian-glass shadow-2xl border border-white/15"
        >
          {stages.map((stage, idx) => {
            const isActive = activeStage === idx;
            return (
              <motion.button
                key={stage.id}
                onClick={() => selectStage(idx)}
                whileHover={{ scale: 1.12, y: -4 }}
                whileTap={{ scale: 0.94 }}
                transition={{ type: 'spring', stiffness: 450, damping: 25 }}
                className={`relative flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 rounded-full text-xs font-semibold transition-all duration-200 ${
                  isActive
                    ? 'bg-white text-black shadow-lg'
                    : 'text-zinc-400 hover:text-white hover:bg-white/10'
                }`}
              >
                <span className={isActive ? 'text-indigo-600' : 'text-zinc-400'}>
                  {stage.icon}
                </span>
                <span className="hidden md:inline-block tracking-tight">
                  {stage.name}
                </span>
                {isActive && (
                  <motion.div
                    layoutId="activeDockIndicator"
                    className="absolute -top-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full bg-indigo-500 shadow-sm"
                  />
                )}
              </motion.button>
            );
          })}
        </motion.div>
      </div>
    </div>
  );
}
