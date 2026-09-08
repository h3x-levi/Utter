import React from 'react';
import { Canvas } from '@react-three/fiber';
import { Sphere, Float } from '@react-three/drei';
import { useReducedMotion } from 'framer-motion';

const ORBS = [
  { position: [-4, 2, -10], color: '#6366f1', scale: 0.8, speed: 1.5 },
  { position: [5, -3, -15], color: '#ec4899', scale: 1.2, speed: 2 },
  { position: [-2, -4, -8], color: '#10b981', scale: 0.5, speed: 1 },
  { position: [6, 4, -12], color: '#f59e0b', scale: 0.9, speed: 2.5 },
  { position: [0, 1, -5], color: '#a855f7', scale: 0.3, speed: 1.2 },
  { position: [-6, -1, -11], color: '#3b82f6', scale: 0.7, speed: 1.8 }
];

const Orb = ({ position, color, scale, speed }) => {
  return (
    <Float speed={speed} rotationIntensity={0.5} floatIntensity={1.5}>
      <Sphere args={[1, 32, 32]} position={position} scale={scale}>
        <meshStandardMaterial
          color={color}
          transparent
          opacity={0.2}
          roughness={0.1}
          metalness={0.1}
        />
      </Sphere>
    </Float>
  );
};

const AmbientOrbsCore = React.memo(() => {
  return (
    <div className="fixed inset-0 z-10 pointer-events-none" style={{ zIndex: 1 }}>
      <Canvas camera={{ position: [0, 0, 5], fov: 75 }} gl={{ alpha: true }}>
        <ambientLight intensity={1} />
        <directionalLight position={[10, 10, 5]} intensity={1} />
        {ORBS.map((orb, index) => (
          <Orb key={index} {...orb} />
        ))}
      </Canvas>
    </div>
  );
});

AmbientOrbsCore.displayName = 'AmbientOrbsCore';

function isWebGLAvailable() {
  try {
    const canvas = document.createElement('canvas');
    return !!(window.WebGLRenderingContext && (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')));
  } catch {
    return false;
  }
}

export default function AmbientOrbs() {
  const prefersReducedMotion = useReducedMotion();
  
  if (prefersReducedMotion || !isWebGLAvailable()) {
    return null;
  }
  
  return <AmbientOrbsCore />;
}
