import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import UtterMemeTicker from './components/UtterMemeTicker';
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
    <div className="min-h-screen text-zinc-900 font-sans selection:bg-indigo-500 selection:text-white relative overflow-x-hidden">
      {/* Serene Grassy Dune & Frosted Landscape Background */}
      <AnimatedAtmosphere />

      {/* Floating Frosted Pill Navbar */}
      <Navbar onOpenModal={handleOpenModal} />

      {/* Main Narrative Flow */}
      <main className="relative z-10">
        {/* 1. Hero: Asymmetric layout with real app mockup & floating Utter Pill */}
        <Hero />

        {/* 2. Single Marquee Soundbites Ticker */}
        <UtterMemeTicker />

        {/* 3. Interactive Feature Stories: Dictation, Models, Diarization, Pixel Cat, Vocabulary */}
        <section id="features">
          <FeatureBento />
        </section>

        {/* 4. Air-Gapped Privacy Architecture & Terminal Verification */}
        <section id="privacy">
          <PrivacySection />
        </section>

        {/* 5. The Cloud Hostage vs The Apple Silicon Flex */}
        <UtterMemeMatrix />

        {/* 6. High-Conversion Download CTA */}
        <DownloadSection />
      </main>

      {/* 7. Consolidated Footer */}
      <Footer onOpenModal={handleOpenModal} />

      {/* Consolidated Modals */}
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
