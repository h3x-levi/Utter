import React, { useState, useEffect } from 'react';
import AnimatedAtmosphere from './components/AnimatedAtmosphere';
import Navbar from './components/Navbar';
import Hero3D from './components/Hero3D';
import RealAppShowcase from './components/RealAppShowcase';
import InteractiveDictationStage from './components/InteractiveDictationStage';
import ArchitectureScrollStory from './components/ArchitectureScrollStory';
import CompanionHabitat from './components/CompanionHabitat';
import TransformsStudio from './components/TransformsStudio';
import DualStreamMeetingStudio from './components/DualStreamMeetingStudio';
import PrivacyVerificationVault from './components/PrivacyVerificationVault';
import BenchmarkMatrix from './components/BenchmarkMatrix';
import ThemeShowcase from './components/ThemeShowcase';
import DownloadHub from './components/DownloadHub';
import Footer from './components/Footer';
import ConnectModal from './components/ConnectModal';
import SupportModal from './components/SupportModal';

export default function App() {
  const [theme, setTheme] = useState('system-glass');
  const [soundEnabled, setSoundEnabled] = useState(true);
  const [activeModal, setActiveModal] = useState(null);

  // Sync theme attribute on document root
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);

  // Handle URL hash changes for modals
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
    <div className="min-h-screen text-zinc-100 font-sans selection:bg-orange-500 selection:text-white relative overflow-x-hidden transition-colors duration-400">
      {/* 1. Serene Grassy Dune Landscape, Living Colorful Auroras, and 3D Acoustic Wave Ribbons */}
      <AnimatedAtmosphere currentTheme={theme} />

      {/* 2. Floating Frosted Pill Navbar */}
      <Navbar
        onOpenModal={handleOpenModal}
        soundEnabled={soundEnabled}
        onToggleSound={() => setSoundEnabled((prev) => !prev)}
      />

      {/* Main Narrative Flow */}
      <main className="relative z-10">
        {/* 3. Hero: 3D Perspective macOS Display with Real Utter Screenshot & Interactive Floating Pill */}
        <Hero3D />

        {/* 4. Deep Dive: Real App Showcase with High-Res Screenshot Switcher */}
        <RealAppShowcase />

        {/* 5. Real-Time Push-to-Talk Interactive Playground & Target Apps */}
        <InteractiveDictationStage soundEnabled={soundEnabled} />

        {/* 6. On-Device Architecture Pipeline (Capture -> whisper.cpp Metal -> Sub-200ms Injection) */}
        <ArchitectureScrollStory />

        {/* 7. Interactive Desktop Companion Habitat (Cat, Dog, Panda with 60 FPS motions) */}
        <CompanionHabitat />

        {/* 8. Apple Intelligence Voice Transforms Studio */}
        <TransformsStudio />

        {/* 9. Dual-Stream Meeting Capture & Diarization */}
        <DualStreamMeetingStudio />

        {/* 10. Air-Gapped Privacy & Terminal Verification Vault */}
        <PrivacyVerificationVault />

        {/* 11. Benchmark Latency & Cost Matrix */}
        <BenchmarkMatrix />

        {/* 12. 7 Liquid Glass Themes Live Showcase */}
        <ThemeShowcase
          currentTheme={theme}
          onSelectTheme={(t) => setTheme(t)}
        />

        {/* 13. High-Conversion Download & Verified Source Hub */}
        <DownloadHub />
      </main>

      {/* 14. Liquid Glass Footer */}
      <Footer onOpenModal={handleOpenModal} />

      {/* Interactive Modals */}
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
