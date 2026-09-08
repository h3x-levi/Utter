import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import UtterMemeTicker from './components/UtterMemeTicker';
import ScreenshotShowcase from './components/ScreenshotShowcase';
import FeatureBento from './components/FeatureBento';
import PrivacySection from './components/PrivacySection';
import UtterMemeMatrix from './components/UtterMemeMatrix';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';
import AnimatedAtmosphere from './components/AnimatedAtmosphere';
import ConnectModal from './components/ConnectModal';
import SupportModal from './components/SupportModal';

function App() {
  const [activeModal, setActiveModal] = useState(null);

  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.toLowerCase();
      if (hash === '#connect') {
        setActiveModal('connect');
      } else if (hash === '#support') {
        setActiveModal('support');
      }
    };

    handleHashChange();
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, []);

  const handleOpenModal = (modalName) => {
    setActiveModal(modalName);
    window.history.pushState(null, '', `#${modalName}`);
  };

  const handleCloseModal = () => {
    setActiveModal(null);
    if (['#connect', '#support'].includes(window.location.hash.toLowerCase())) {
      window.history.pushState(null, '', window.location.pathname + window.location.search);
    }
  };

  return (
    <div className="min-h-screen text-zinc-900 font-sans selection:bg-indigo-500 selection:text-white relative overflow-x-hidden bg-[#fafafa]">
      {/* Immersive Background: Shader Gradient + R3F Ambient Orbs */}
      <AnimatedAtmosphere />

      {/* Floating Navbar */}
      <Navbar onOpenModal={handleOpenModal} />

      {/* Main Content Flow */}
      <main className="relative z-10">
        {/* 1. Hero - asymmetric layout with real screenshot, fades on scroll */}
        <Hero />

        {/* 2. Meme Ticker - single marquee (max 1 per page rule) */}
        <UtterMemeTicker />

        {/* 3. Screenshot Showcase - GSAP horizontal scroll-driven pan */}
        <ScreenshotShowcase />

        {/* 4. Feature Bento - asymmetric grid with real screenshots */}
        <section id="features">
          <FeatureBento />
        </section>

        {/* 5. Privacy - GSAP sticky-stack cards */}
        <section id="privacy">
          <PrivacySection />
        </section>

        {/* 6. Meme Matrix - personality section */}
        <UtterMemeMatrix />

        {/* 7. Download CTA */}
        <DownloadSection />
      </main>

      {/* Footer */}
      <Footer onOpenModal={handleOpenModal} />

      {/* Modals: Connect (merged with Contact) + Support */}
      <ConnectModal
        isOpen={activeModal === 'connect'}
        onClose={handleCloseModal}
      />
      <SupportModal
        isOpen={activeModal === 'support'}
        onClose={handleCloseModal}
      />
    </div>
  );
}

export default App;
