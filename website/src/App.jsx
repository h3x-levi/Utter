import React from 'react';
import ScrollProgress from './components/ScrollProgress';
import ThreeAudioSphere from './components/ThreeAudioSphere';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import WorkflowSteps from './components/WorkflowSteps';
import PillStateShowcase from './components/PillStateShowcase';
import BentoFeatures from './components/BentoFeatures';
import MeetingStudio from './components/MeetingStudio';
import AITransformsPlayground from './components/AITransformsPlayground';
import CompanionPlayground from './components/CompanionPlayground';
import SpeechModelMatrix from './components/SpeechModelMatrix';
import KeyboardStudio from './components/KeyboardStudio';
import BenchmarkLatency from './components/BenchmarkLatency';
import ComparisonMatrix from './components/ComparisonMatrix';
import PrivacyArchitecture from './components/PrivacyArchitecture';
import TerminalInstall from './components/TerminalInstall';
import CommunityQuotes from './components/CommunityQuotes';
import FAQ from './components/FAQ';
import Footer from './components/Footer';

export default function App() {
  return (
    <div className="min-h-screen bg-[#0b0d13] text-slate-100 relative selection:bg-orange-500 selection:text-white">
      {/* Top Scroll Indicator */}
      <ScrollProgress />

      {/* 3D WebGL Background Audio Particle Sphere */}
      <ThreeAudioSphere />

      {/* Sticky Glass Navbar */}
      <Navbar />

      {/* Rich Scrollable Multi-Section Story Flow */}
      <main className="relative z-10">
        <Hero />
        <WorkflowSteps />
        <PillStateShowcase />
        <BentoFeatures />
        <MeetingStudio />
        <AITransformsPlayground />
        <CompanionPlayground />
        <SpeechModelMatrix />
        <KeyboardStudio />
        <BenchmarkLatency />
        <ComparisonMatrix />
        <PrivacyArchitecture />
        <TerminalInstall />
        <CommunityQuotes />
        <FAQ />
      </main>

      {/* Cinematic Footer */}
      <Footer />
    </div>
  );
}
