import React, { useState } from 'react';
import Navbar from './components/Navbar';
import DynamicBackground3D from './components/DynamicBackground3D';
import PinnedStageExperience from './components/PinnedStageExperience';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';

function App() {
  const [activeStage, setActiveStage] = useState(0);

  return (
    <div className="min-h-screen bg-[#edeceb] text-[#0d0d0d] font-sans selection:bg-[#5f61ed] selection:text-white overflow-x-hidden relative">
      {/* Live Three.js 3D WebGL Background Scene */}
      <DynamicBackground3D activeStage={activeStage} />

      {/* Floating Centered Pill Navbar */}
      <Navbar />

      {/* Main Pinned 3D Scrollytelling Stage */}
      <main className="relative z-10">
        <PinnedStageExperience onStageChange={setActiveStage} />
      </main>

      {/* High-Contrast Grounding Download CTA & Footer */}
      <div className="relative z-20 bg-[#0d0d0d] text-white">
        <DownloadSection />
        <Footer />
      </div>
    </div>
  );
}

export default App;
