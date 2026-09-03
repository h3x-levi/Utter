import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import StageHero from './StageHero';
import StageDictationHUD from './StageDictationHUD';
import StageModelSwitcher from './StageModelSwitcher';
import StageMeetingStudio from './StageMeetingStudio';
import StageCompanionSandbox from './StageCompanionSandbox';
import StagePrivacyVault from './StagePrivacyVault';
import { Mic, Zap, Cpu, Users, Heart, ShieldCheck } from 'lucide-react';

export default function PinnedStageExperience({ onStageChange }) {
  const [activeStage, setActiveStage] = useState(0);
  const containerRef = useRef(null);
  const isClickNavigating = useRef(false);

  const stages = [
    { id: 'hero', name: 'Overview', icon: <Mic size={16} /> },
    { id: 'dictation', name: 'Dictation HUD', icon: <Zap size={16} /> },
    { id: 'models', name: 'Speech Models', icon: <Cpu size={16} /> },
    { id: 'meetings', name: 'Meeting Studio', icon: <Users size={16} /> },
    { id: 'companion', name: 'Pixel Pet', icon: <Heart size={16} /> },
    { id: 'privacy', name: 'Privacy Vault', icon: <ShieldCheck size={16} /> },
  ];

  // Scroll listener to smoothly transition stage based on vertical scroll distance
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
    <div ref={containerRef} className="relative h-[600vh] w-full">
      {/* Sticky Pinned Stage Viewport */}
      <div className="sticky top-0 h-screen w-full flex flex-col justify-between items-center pt-24 pb-28 px-4 overflow-hidden">

        {/* Dynamic Graphic Stage with 3D Morph Transitions */}
        <div className="w-full flex-1 flex items-center justify-center relative perspective-[1800px] z-10">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeStage}
              initial={{
                opacity: 0,
                scale: 0.9,
                rotateX: 10,
                y: 40,
                filter: 'blur(12px)',
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
                rotateX: -10,
                y: -40,
                filter: 'blur(12px)',
              }}
              transition={{
                duration: 0.65,
                ease: [0.16, 1, 0.3, 1],
              }}
              className="w-full"
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

        {/* Floating Dock Capsule Controller (dock.cool style) */}
        <motion.div
          initial={{ y: 50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.7, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 flex items-center gap-1.5 sm:gap-2.5 p-2 rounded-full obsidian-glass shadow-2xl border border-white/20"
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
                    : 'text-white/60 hover:text-white hover:bg-white/10'
                }`}
              >
                <span className={isActive ? 'text-indigo-600' : 'text-white/70'}>
                  {stage.icon}
                </span>
                <span className="hidden md:inline-block tracking-tight">
                  {stage.name}
                </span>
                {isActive && (
                  <motion.div
                    layoutId="activeDockIndicator"
                    className="absolute -top-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full bg-indigo-500"
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
