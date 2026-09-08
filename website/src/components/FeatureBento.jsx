import React from 'react';
import { motion, useReducedMotion } from 'framer-motion';

export default function FeatureBento() {
  const shouldReduceMotion = useReducedMotion();

  const features = [
    {
      title: "Dictation Studio",
      description: "Hold any key to dictate, release to transcribe instantly",
      image: "/assets/screenshots/hero-main.png",
      colSpan: "md:col-span-4",
      bgClass: "bg-indigo-50/40",
      borderClass: "border-indigo-100"
    },
    {
      title: "Notes Studio",
      description: "Every transcription saved, searchable, and organized",
      image: "/assets/screenshots/04_notes_studio.png",
      colSpan: "md:col-span-2",
      bgClass: "bg-white",
      borderClass: "border-zinc-200"
    },
    {
      title: "AI Companion",
      description: "Customize post-processing with your personal AI assistant",
      image: "/assets/screenshots/05b_companion_customize.png",
      colSpan: "md:col-span-2",
      bgClass: "bg-emerald-50/40",
      borderClass: "border-emerald-100"
    },
    {
      title: "Model Picker",
      description: "Switch between Whisper models in one click",
      image: "/assets/screenshots/06_model_chooser.png",
      colSpan: "md:col-span-4",
      bgClass: "bg-white",
      borderClass: "border-zinc-200"
    },
    {
      title: "Dictionary Studio",
      description: "Add domain vocabulary so jargon transcribes correctly",
      image: "/assets/screenshots/08_dictionary_studio.png",
      colSpan: "md:col-span-3",
      bgClass: "bg-white",
      borderClass: "border-zinc-200"
    },
    {
      title: "Transforms Hub",
      description: "Chain AI transforms to clean up your transcriptions",
      image: "/assets/screenshots/10_transforms_hub.png",
      colSpan: "md:col-span-3",
      bgClass: "bg-amber-50/40",
      borderClass: "border-amber-100"
    }
  ];

  return (
    <section className="py-24 px-4 sm:px-8 bg-[#fafafa] w-full">
      <div className="max-w-6xl mx-auto">
        <h2 className="text-3xl md:text-4xl font-bold text-center mb-12 text-zinc-900">
          Built for how you actually work
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-6 gap-6">
          {features.map((feat, i) => {
            const entryAnimation = shouldReduceMotion 
              ? { opacity: 1, scale: 1 } 
              : { opacity: 1, scale: 1 };
              
            const initialAnimation = shouldReduceMotion
              ? { opacity: 1, scale: 1 }
              : { opacity: 0, scale: 0.95 };

            return (
              <motion.div
                key={i}
                className={`group flex flex-col rounded-2xl overflow-hidden border ${feat.borderClass} ${feat.bgClass} ${feat.colSpan} cursor-pointer active:scale-[0.97] transition-colors`}
                initial={initialAnimation}
                whileInView={entryAnimation}
                viewport={{ once: true, margin: "-50px" }}
                transition={{ 
                  duration: 0.4, 
                  delay: shouldReduceMotion ? 0 : i * 0.06,
                  ease: [0.23, 1, 0.32, 1]
                }}
                whileHover={
                  shouldReduceMotion 
                    ? {} 
                    : { 
                        scale: 1.02, 
                        transition: { type: 'spring', stiffness: 200, damping: 20 } 
                      }
                }
              >
                <div className="p-6 pb-4">
                  <h3 className="text-lg font-bold text-zinc-900 mb-1">{feat.title}</h3>
                  <p className="text-sm text-zinc-500">{feat.description}</p>
                </div>
                <div className="px-6 pb-6 pt-2 flex-grow flex items-end">
                  <div className="relative w-full rounded-xl overflow-hidden shadow-sm border border-black/5 bg-white/50">
                    <img 
                      src={feat.image} 
                      alt={feat.title}
                      className="w-full object-cover"
                      loading="lazy"
                    />
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
