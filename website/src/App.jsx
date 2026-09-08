import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import UtterMemeTicker from './components/UtterMemeTicker';
import FeatureBento from './components/FeatureBento';
import UtterMemeMatrix from './components/UtterMemeMatrix';
import PrivacySection from './components/PrivacySection';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';
import AnimatedAtmosphere from './components/AnimatedAtmosphere';
import ContactModal from './components/ContactModal';
import ConnectModal from './components/ConnectModal';
import SupportModal from './components/SupportModal';

function App() {
  const [activeModal, setActiveModal] = useState(null);

  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.toLowerCase();
      if (hash === '#contact') {
        setActiveModal('contact');
      } else if (hash === '#connect') {
        setActiveModal('connect');
      } else if (hash === '#support') {
        setActiveModal('support');
      }
    };

    // Check on initial load
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
    if (['#contact', '#connect', '#support'].includes(window.location.hash.toLowerCase())) {
      window.history.pushState(null, '', window.location.pathname + window.location.search);
    }
  };

  return (
    <div className="min-h-screen text-zinc-900 font-sans selection:bg-indigo-500 selection:text-white relative overflow-x-hidden bg-[#fafafa]/80">
      {/* 1. Serene Grassy Dune Landscape & Floating Aurora Atmosphere */}
      <AnimatedAtmosphere />

      {/* Floating Single Navbar */}
      <Navbar onOpenModal={handleOpenModal} />

      {/* Main Content Flow */}
      <main className="relative z-10">
        <Hero />
        <UtterMemeTicker />
        <FeatureBento />
        <UtterMemeMatrix />
        <PrivacySection />
        <DownloadSection />
      </main>

      {/* 4-Column Directory Footer */}
      <Footer onOpenModal={handleOpenModal} />

      {/* Dedicated Interactive Portals / Modals */}
      <ContactModal
        isOpen={activeModal === 'contact'}
        onClose={handleCloseModal}
      />
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
