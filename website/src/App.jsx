import React from 'react';
import ScrollProgress from './components/ScrollProgress';
import NavbarPill from './components/NavbarPill';
import MacDisplayHero from './components/MacDisplayHero';
import AssetTransitionShowcase from './components/AssetTransitionShowcase';
import InteractiveWidgetsGrid from './components/InteractiveWidgetsGrid';
import WorkflowSteps from './components/WorkflowSteps';
import PillStateShowcase from './components/PillStateShowcase';
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
    <div className="min-h-screen bg-[#09090b] text-zinc-100 relative selection:bg-white selection:text-black">
      {/* Top Scroll Indicator */}
      <ScrollProgress />

      {/* Floating Centered Pill Navbar (Inspired by dock.cool) */}
      <NavbarPill />

      {/* Main Content */}
      <main className="relative z-10">
        <MacDisplayHero />
        <AssetTransitionShowcase />
        <InteractiveWidgetsGrid />
        <WorkflowSteps />
        <PillStateShowcase />
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

      {/* Clean Apple Footer */}
      <Footer />
    </div>
  );
}
