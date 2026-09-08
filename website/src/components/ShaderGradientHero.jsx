import React, { Suspense, useState, useEffect } from 'react';
import { ShaderGradientCanvas, ShaderGradient } from '@shadergradient/react';
import { motion, useScroll, useTransform, useReducedMotion } from 'framer-motion';

function ShaderGradientFallback() {
  return (
    <div
      className="fixed inset-0 z-0 pointer-events-none"
      style={{
        background: 'radial-gradient(circle at 20% 30%, rgba(99, 102, 241, 0.2) 0%, transparent 40%), radial-gradient(circle at 80% 70%, rgba(236, 72, 153, 0.2) 0%, transparent 40%), radial-gradient(circle at 50% 50%, rgba(16, 185, 129, 0.15) 0%, transparent 50%), radial-gradient(circle at 90% 10%, rgba(245, 158, 11, 0.15) 0%, transparent 40%), #fafafa'
      }}
    />
  );
}

function ShaderGradientCore() {
  const { scrollY } = useScroll();
  const opacity = useTransform(scrollY, [0, 800], [1, 0]);

  return (
    <motion.div style={{ opacity }} className="fixed inset-0 z-0 pointer-events-none">
      <ShaderGradientCanvas
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          pointerEvents: 'none'
        }}
      >
        <ShaderGradient
          control="query"
          urlString="https://www.shadergradient.co/customize?animate=on&axesHelper=off&bgColor1=%23000000&bgColor2=%23000000&brightness=1&cAzimuthAngle=180&cDistance=3.6&cPolarAngle=90&cameraZoom=1&color1=%236366f1&color2=%23ec4899&color3=%2310b981&color4=%23f59e0b&destination=onCanvas&embedMode=off&envPreset=city&format=gif&fov=45&frameRate=10&gizmoHelper=hide&grain=on&lightType=3d&pixelDensity=1.5&positionX=-1.4&positionY=0&positionZ=0&range=disabled&rangeEnd=40&rangeStart=0&reflection=0.1&rotationX=0&rotationY=10&rotationZ=50&shader=defaults&type=waterSphere&uAmplitude=0&uDensity=1.2&uFrequency=5.5&uSpeed=0.1&uStrength=1.5&uTime=0.2&wireframe=false"
        />
      </ShaderGradientCanvas>
    </motion.div>
  );
}

class ShaderErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

function isWebGLAvailable() {
  try {
    const canvas = document.createElement('canvas');
    return !!(window.WebGLRenderingContext && (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')));
  } catch {
    return false;
  }
}

export default function ShaderGradientHero() {
  const prefersReducedMotion = useReducedMotion();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) return null;

  if (prefersReducedMotion || !isWebGLAvailable()) {
    return <ShaderGradientFallback />;
  }

  return (
    <ShaderErrorBoundary fallback={<ShaderGradientFallback />}>
      <Suspense fallback={<ShaderGradientFallback />}>
        <ShaderGradientCore />
      </Suspense>
    </ShaderErrorBoundary>
  );
}
