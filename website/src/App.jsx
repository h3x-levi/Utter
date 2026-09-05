import React from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import UtterMemeTicker from './components/UtterMemeTicker';
import FeatureBento from './components/FeatureBento';
import UtterMemeMatrix from './components/UtterMemeMatrix';
import PrivacySection from './components/PrivacySection';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';
import AnimatedAtmosphere from './components/AnimatedAtmosphere';

function App() {
  return (
    <div className="min-h-screen text-zinc-900 font-sans selection:bg-indigo-500 selection:text-white relative overflow-x-hidden bg-[#fafafa]/80">
      {/* 1. Serene Grassy Dune Landscape & Floating Aurora Atmosphere */}
      <AnimatedAtmosphere />

      {/* Floating Single Navbar */}
      <Navbar />

      {/* Main Content Flow */}
      <main className="relative z-10">
        <Hero />
        <UtterMemeTicker />
        <FeatureBento />
        <UtterMemeMatrix />
        <PrivacySection />
        <DownloadSection />
      </main>

      {/* Footer */}
      <Footer />
    </div>
  );
}

export default App;
