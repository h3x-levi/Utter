import React, { useState } from 'react';
import Navbar from './components/Navbar';
import DynamicBackground3D from './components/DynamicBackground3D';
import PinnedStageExperience from './components/PinnedStageExperience';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';
import SplashCursor from './components/SplashCursor';
import PillPreloader from './components/PillPreloader';

function App() {
  const [activeStage, setActiveStage] = useState(0);
  const [isPreloaderDone, setIsPreloaderDone] = useState(false);

  return (
    <div className="min-h-screen bg-[#09090b] text-[#f4f4f5] font-sans selection:bg-indigo-600 selection:text-white relative">
      {/* Interactive Canvas Splash Cursor */}
      <SplashCursor />

      {/* Pill Loading Screen Intro Animation */}
      <PillPreloader onComplete={() => setIsPreloaderDone(true)} />

      {/* Live Three.js 3D WebGL Background Scene */}
      <DynamicBackground3D activeStage={activeStage} />

      {/* Floating Centered Spotlight Navbar */}
      <Navbar onSelectStage={setActiveStage} />

      {/* Main Pinned 3D Scrollytelling Stage */}
      <main className="relative z-10">
        <PinnedStageExperience onStageChange={setActiveStage} />
      </main>

      {/* Grounding Download Section & Footer */}
      <div className="relative z-20 bg-[#09090b]">
        <DownloadSection />
        <Footer />
      </div>
    </div>
  );
}

export default App;
