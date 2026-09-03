import React from 'react';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import FeatureShowcase from './components/FeatureShowcase';
import PrivacySection from './components/PrivacySection';
import DownloadSection from './components/DownloadSection';
import Footer from './components/Footer';

function App() {
  return (
    <div className="min-h-screen bg-[#edeceb] text-[#0d0d0d] font-sans selection:bg-[#5f61ed] selection:text-white overflow-x-hidden">
      <Navbar />
      <main>
        <Hero />
        <FeatureShowcase />
        <PrivacySection />
      </main>
      <DownloadSection />
      <Footer />
    </div>
  );
}

export default App;
