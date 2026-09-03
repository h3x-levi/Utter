import React, { useEffect, useRef } from 'react';

export default function SplashCursor() {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const handleResize = () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };
    window.addEventListener('resize', handleResize);

    const particles = [];
    const maxParticles = 35;
    let mouseX = -100;
    let mouseY = -100;

    const handleMouseMove = (e) => {
      mouseX = e.clientX;
      mouseY = e.clientY;

      // Add a couple of subtle fluid particles on mouse movement
      for (let i = 0; i < 2; i++) {
        if (particles.length < maxParticles) {
          particles.push({
            x: mouseX + (Math.random() - 0.5) * 8,
            y: mouseY + (Math.random() - 0.5) * 8,
            vx: (Math.random() - 0.5) * 1.5,
            vy: (Math.random() - 0.5) * 1.5 - 0.5,
            radius: Math.random() * 18 + 12,
            alpha: 0.35,
            color: Math.random() > 0.4 ? 'rgba(95, 97, 237,' : 'rgba(255, 255, 255,',
          });
        }
      }
    };
    window.addEventListener('mousemove', handleMouseMove);

    let animId;
    const render = () => {
      ctx.clearRect(0, 0, width, height);

      for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.radius *= 0.96;
        p.alpha -= 0.012;

        if (p.alpha <= 0 || p.radius <= 0.5) {
          particles.splice(i, 1);
          continue;
        }

        const gradient = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.radius);
        gradient.addColorStop(0, `${p.color} ${p.alpha})`);
        gradient.addColorStop(1, `${p.color} 0)`);

        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fill();
      }

      animId = requestAnimationFrame(render);
    };
    render();

    return () => {
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('mousemove', handleMouseMove);
      cancelAnimationFrame(animId);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none fixed inset-0 z-50 h-full w-full"
      style={{ mixBlendMode: 'screen' }}
    />
  );
}
