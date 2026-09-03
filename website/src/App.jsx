import React from 'react';
import Navbar from './components/Navbar';
import ThreeAudioSphere from './components/ThreeAudioSphere';
import Hero from './components/Hero';
import BentoFeatures from './components/BentoFeatures';
import CompanionPlayground from './components/CompanionPlayground';
import BenchmarkLatency from './components/BenchmarkLatency';
import PrivacyArchitecture from './components/PrivacyArchitecture';
import FAQ from './components/FAQ';
import Footer from './components/Footer';

export default function App() {
  return (
    <div className="min-h-screen bg-[#0b0d13] text-slate-100 relative selection:bg-orange-500 selection:text-white">
      {/* 3D WebGL Background Audio Particle Sphere */}
      <ThreeAudioSphere />

      {/* Navigation */}
      <Navbar />

      {/* Main Content */}
      <main className="relative z-10">
        <Hero />
        <BentoFeatures />
        <CompanionPlayground />
        <BenchmarkLatency />
        <PrivacyArchitecture />
        <FAQ />
      </main>

      {/* Footer */}
      <Footer />
    </div>
  );
}
