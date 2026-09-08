import { useRef, useEffect } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { useReducedMotion } from 'framer-motion';
import { Shield, Wifi, Eye } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const cards = [
  {
    title: 'Zero Cloud',
    icon: Shield,
    iconColor: 'text-emerald-500',
    bgColor: 'bg-emerald-50/60',
    desc: 'Your voice data never leaves your Mac. Every transcription runs locally through whisper.cpp on Apple Silicon Metal GPU. No server, no upload, no exceptions.'
  },
  {
    title: 'Zero Telemetry',
    icon: Eye,
    iconColor: 'text-indigo-500',
    bgColor: 'bg-indigo-50/60',
    desc: 'Utter collects exactly zero usage analytics. No crash reports phoned home, no feature tracking, no A/B testing on your workflow. What you say stays between you and your Mac.'
  },
  {
    title: 'Zero Network',
    icon: Wifi,
    iconColor: 'text-amber-500',
    bgColor: 'bg-amber-50/60',
    desc: 'During transcription, Utter opens exactly 0 network sockets. Verify it yourself in Activity Monitor. The app works fully offline, always.'
  }
];

export default function PrivacySection() {
  const containerRef = useRef(null);
  const shouldReduceMotion = useReducedMotion();

  useEffect(() => {
    if (shouldReduceMotion) return;
    
    const mm = gsap.matchMedia();
    
    mm.add('(min-width: 768px)', () => {
      const cardElements = gsap.utils.toArray('.privacy-card');
      
      cardElements.forEach((card, i) => {
        if (i === cardElements.length - 1) return;
        
        const nextCard = cardElements[i + 1];
        const cardInner = card.querySelector('.privacy-card-inner');
        
        ScrollTrigger.create({
          trigger: card,
          start: 'top top',
          endTrigger: nextCard,
          end: 'top top',
          pin: true,
          pinSpacing: false,
        });

        gsap.to(cardInner, {
          scale: 0.92,
          opacity: 0.55,
          ease: 'none',
          scrollTrigger: {
            trigger: nextCard,
            start: 'top bottom',
            end: 'top top',
            scrub: true,
          }
        });
      });
    });
    
    return () => mm.revert();
  }, [shouldReduceMotion]);

  return (
    <div ref={containerRef} className="w-full bg-[#fafafa]">
      {cards.map((card, i) => {
        const Icon = card.icon;
        return (
          <section
            key={i}
            className={`privacy-card w-full ${
              shouldReduceMotion 
                ? 'py-20 flex flex-col items-center justify-center p-6' 
                : 'md:sticky md:top-0 md:min-h-[100dvh] flex items-center justify-center p-6 md:p-0 mb-8 md:mb-0'
            }`}
          >
            <div className={`privacy-card-inner w-full max-w-4xl mx-auto rounded-3xl p-10 md:p-16 shadow-lg border border-zinc-200/50 ${card.bgColor} flex flex-col items-center justify-center text-center backdrop-blur-sm`}>
              <div className={`p-4 rounded-2xl bg-white shadow-sm mb-8 ${card.iconColor}`}>
                <Icon size={48} strokeWidth={1.5} />
              </div>
              <h2 className="text-4xl md:text-5xl font-bold text-zinc-900 mb-6 tracking-tight">
                {card.title}
              </h2>
              <p className="text-lg text-zinc-600 max-w-2xl leading-relaxed">
                {card.desc}
              </p>
            </div>
          </section>
        );
      })}
    </div>
  );
}
