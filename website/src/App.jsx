import React from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import FeatureBento from './components/FeatureBento';
import PrivacySection from './components/PrivacySection';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';

function App() {
  return (
    <div className="min-h-screen bg-[#fafafa] text-zinc-900 font-sans selection:bg-indigo-500 selection:text-white relative">
      {/* Floating Single Navbar */}
      <Navbar />

      {/* Main Content */}
      <main>
        <Hero />
        <FeatureBento />
        <PrivacySection />
        <DownloadSection />
      </main>

      {/* Footer */}
      <Footer />
    </div>
  );
}

export default App;
