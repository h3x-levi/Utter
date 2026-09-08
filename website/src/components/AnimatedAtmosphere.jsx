import React, { Suspense, lazy } from 'react';
import { useReducedMotion } from 'framer-motion';

const ShaderGradientHero = lazy(() => import('./ShaderGradientHero'));
const AmbientOrbs = lazy(() => import('./AmbientOrbs'));

class ErrorBoundary extends React.Component {
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

function AtmosphereFallback() {
  return (
    <div
      className="fixed inset-0 z-0 pointer-events-none"
      style={{
        background: 'radial-gradient(circle at 20% 30%, rgba(99, 102, 241, 0.2) 0%, transparent 40%), radial-gradient(circle at 80% 70%, rgba(236, 72, 153, 0.2) 0%, transparent 40%), radial-gradient(circle at 50% 50%, rgba(16, 185, 129, 0.15) 0%, transparent 50%), radial-gradient(circle at 90% 10%, rgba(245, 158, 11, 0.15) 0%, transparent 40%), #fafafa'
      }}
    />
  );
}

export default function AnimatedAtmosphere() {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return <AtmosphereFallback />;
  }

  return (
    <>
      <ErrorBoundary fallback={<AtmosphereFallback />}>
        <Suspense fallback={<AtmosphereFallback />}>
          <ShaderGradientHero />
        </Suspense>
      </ErrorBoundary>
      
      <ErrorBoundary fallback={null}>
        <Suspense fallback={null}>
          <AmbientOrbs />
        </Suspense>
      </ErrorBoundary>
    </>
  );
}
