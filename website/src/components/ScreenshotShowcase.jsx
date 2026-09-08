import React, { useRef, useEffect, useState } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useReducedMotion, motion } from 'framer-motion';

gsap.registerPlugin(ScrollTrigger);

const screenshots = [
  {
    id: 1,
    image: '/assets/screenshots/hero-main.png',
    title: 'Your command center',
    subtitle: 'Everything you need, right where you need it',
    alt: 'Utter command center dashboard',
  },
  {
    id: 2,
    image: '/assets/screenshots/04_notes_studio.png',
    title: 'Notes Studio',
    subtitle: 'Capture thoughts as they flow',
    alt: 'Notes Studio interface',
  },
  {
    id: 3,
    image: '/assets/screenshots/05b_companion_customize.png',
    title: 'AI Companion',
    subtitle: 'Your personal dictation assistant',
    alt: 'AI Companion customization screen',
  },
  {
    id: 4,
    image: '/assets/screenshots/06_model_chooser.png',
    title: 'Model Picker',
    subtitle: 'Choose the perfect whisper model',
    alt: 'Model Picker selection interface',
  },
  {
    id: 5,
    image: '/assets/screenshots/08_dictionary_studio.png',
    title: 'Dictionary Studio',
    subtitle: 'Custom vocabulary for your domain',
    alt: 'Dictionary Studio for custom vocabulary',
  },
  {
    id: 6,
    image: '/assets/screenshots/10_transforms_hub.png',
    title: 'Transforms Hub',
    subtitle: 'Post-process your transcriptions',
    alt: 'Transforms Hub for post-processing',
  },
];

export default function ScreenshotShowcase() {
  const containerRef = useRef(null);
  const trackRef = useRef(null);
  const prefersReducedMotion = useReducedMotion();
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => setIsMobile(window.innerWidth < 768);
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  useEffect(() => {
    if (prefersReducedMotion || isMobile) return;

    const container = containerRef.current;
    const track = trackRef.current;
    if (!container || !track) return;

    const cards = gsap.utils.toArray(track.children);
    
    // Calculate total scroll distance
    const trackWidth = track.scrollWidth;
    const viewportWidth = window.innerWidth;
    const maxScroll = trackWidth - viewportWidth;

    const ctx = gsap.context(() => {
      // Horizontal scroll
      gsap.to(track, {
        x: -maxScroll,
        ease: 'none',
        scrollTrigger: {
          trigger: container,
          pin: true,
          scrub: 1,
          start: 'top top',
          end: () => `+=${trackWidth}`,
          invalidateOnRefresh: true,
        },
      });

      // Entry animations for cards
      cards.forEach((card, i) => {
        // Skip animating the first card on load since it's already in view
        if (i > 0) {
          gsap.fromTo(card,
            { 
              opacity: 0.5,
              scale: 0.95,
            },
            {
              opacity: 1,
              scale: 1,
              ease: 'power2.out',
              scrollTrigger: {
                trigger: container,
                start: () => `top top-=${(i * maxScroll) / cards.length - viewportWidth / 1.5}`,
                end: () => `top top-=${((i + 1) * maxScroll) / cards.length}`,
                scrub: 1,
              },
            }
          );
        }
      });
    }, container);

    return () => ctx.revert();
  }, [prefersReducedMotion, isMobile]);

  if (prefersReducedMotion || isMobile) {
    return (
      <section className="py-24 px-6 max-w-4xl mx-auto flex flex-col gap-12">
        {screenshots.map((item) => (
          <motion.div
            key={item.id}
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ type: "spring", stiffness: 100, damping: 20 }}
            className="flex flex-col bg-white rounded-2xl shadow-xl border border-black/[0.08] overflow-hidden"
          >
            <div className="p-1 bg-zinc-100 border-b border-black/[0.04] flex gap-1.5 px-3">
              <div className="w-2.5 h-2.5 rounded-full bg-red-400" />
              <div className="w-2.5 h-2.5 rounded-full bg-amber-400" />
              <div className="w-2.5 h-2.5 rounded-full bg-green-400" />
            </div>
            <img 
              src={item.image} 
              alt={item.alt}
              className="w-full object-cover"
              loading="lazy"
            />
            <div className="p-6">
              <h3 className="text-2xl font-bold text-zinc-900 mb-1">{item.title}</h3>
              <p className="text-base text-zinc-500">{item.subtitle}</p>
            </div>
          </motion.div>
        ))}
      </section>
    );
  }

  return (
    <section ref={containerRef} className="relative h-screen bg-transparent overflow-hidden">
      <div 
        ref={trackRef} 
        className="flex gap-8 items-center h-[100dvh] px-[10vw] w-max"
      >
        {screenshots.map((item) => (
          <div 
            key={item.id}
            className="flex-none w-[70vw] md:w-[50vw] max-w-[800px] bg-white rounded-2xl shadow-xl border border-black/[0.08] overflow-hidden flex flex-col"
          >
            <div className="p-1.5 bg-zinc-100 border-b border-black/[0.04] flex gap-1.5 px-4 items-center h-8">
              <div className="w-2.5 h-2.5 rounded-full bg-red-400" />
              <div className="w-2.5 h-2.5 rounded-full bg-amber-400" />
              <div className="w-2.5 h-2.5 rounded-full bg-green-400" />
            </div>
            <img 
              src={item.image} 
              alt={item.alt}
              className="w-full object-cover"
              loading="lazy"
            />
            <div className="p-6 md:p-8 bg-white">
              <h3 className="text-2xl font-bold text-zinc-900 mb-2">{item.title}</h3>
              <p className="text-base text-zinc-500">{item.subtitle}</p>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
