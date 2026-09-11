import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';

export default function ThreeLiquidBackground({ currentTheme = 'system-glass' }) {
  const mountRef = useRef(null);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    let width = window.innerWidth;
    let height = window.innerHeight;

    // 1. Scene, Camera, Renderer
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(60, width / height, 0.1, 1000);
    camera.position.set(0, 8, 22);
    camera.lookAt(0, -2, 0);

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.1;
    container.appendChild(renderer.domElement);

    // 2. Theme-Specific Color Palettes
    const themeColors = {
      'system-glass': { primary: 0xf97316, secondary: 0x6366f1, ambient: 0x18181b, fog: 0x09090b },
      'dark-glass': { primary: 0x38bdf8, secondary: 0x818cf8, ambient: 0x0c1017, fog: 0x080a0f },
      'obsidian': { primary: 0xa1a1aa, secondary: 0x52525b, ambient: 0x121212, fog: 0x050505 },
      'solar-warmth': { primary: 0xfb923c, secondary: 0xe11d48, ambient: 0x1c1008, fog: 0x0c0906 },
      'nordic-frost': { primary: 0x06b6d4, secondary: 0x3b82f6, ambient: 0x0a1621, fog: 0x050b11 },
      'midnight-indigo': { primary: 0x818cf8, secondary: 0xc084fc, ambient: 0x0f0b24, fog: 0x080614 },
      'paper-white': { primary: 0x2563eb, secondary: 0x64748b, ambient: 0xe2e8f0, fog: 0xf8fafc },
    };

    const colors = themeColors[currentTheme] || themeColors['system-glass'];
    scene.fog = new THREE.FogExp2(colors.fog, 0.028);

    // 3. Lighting (Dynamic Moving Point Lights + Rim Light)
    const ambientLight = new THREE.AmbientLight(colors.ambient, 1.2);
    scene.add(ambientLight);

    const light1 = new THREE.PointLight(colors.primary, 3.5, 50);
    light1.position.set(-12, 10, 8);
    scene.add(light1);

    const light2 = new THREE.PointLight(colors.secondary, 2.8, 50);
    light2.position.set(12, 8, -5);
    scene.add(light2);

    const rimLight = new THREE.DirectionalLight(0xffffff, 0.8);
    rimLight.position.set(0, 20, -10);
    scene.add(rimLight);

    // 4. Liquid 3D Terrain Plane Geometry
    const planeWidth = 65;
    const planeHeight = 65;
    const segmentsX = 85;
    const segmentsY = 85;

    const planeGeometry = new THREE.PlaneGeometry(planeWidth, planeHeight, segmentsX, segmentsY);
    planeGeometry.rotateX(-Math.PI / 2.3);
    planeGeometry.translate(0, -6, 0);

    const posAttr = planeGeometry.attributes.position;
    const vertexCount = posAttr.count;
    const originalPositions = new Float32Array(vertexCount * 3);

    for (let i = 0; i < vertexCount * 3; i++) {
      originalPositions[i] = posAttr.array[i];
    }

    // Material: Iridescent Liquid Metal Surface with Wireframe Overlay
    const planeMaterial = new THREE.MeshStandardMaterial({
      color: 0x18181b,
      roughness: 0.35,
      metalness: 0.85,
      wireframe: false,
      flatShading: true,
    });

    const planeMesh = new THREE.Mesh(planeGeometry, planeMaterial);
    scene.add(planeMesh);

    // Wireframe Overlay for High-Tech CAD Mesh Aesthetic
    const wireframeMaterial = new THREE.MeshBasicMaterial({
      color: colors.primary,
      wireframe: true,
      transparent: true,
      opacity: 0.12,
    });
    const wireframeMesh = new THREE.Mesh(planeGeometry, wireframeMaterial);
    scene.add(wireframeMesh);

    // 5. Floating 3D Luminous Particle Field (Acoustic Star Dust)
    const particleCount = 700;
    const particleGeometry = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    const particleSpeeds = new Float32Array(particleCount);

    for (let i = 0; i < particleCount; i++) {
      particlePositions[i * 3] = (Math.random() - 0.5) * 50;
      particlePositions[i * 3 + 1] = Math.random() * 25 - 5;
      particlePositions[i * 3 + 2] = (Math.random() - 0.5) * 40;
      particleSpeeds[i] = 0.02 + Math.random() * 0.04;
    }
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));

    const particleMaterial = new THREE.PointsMaterial({
      color: colors.primary,
      size: 0.12,
      transparent: true,
      opacity: 0.65,
      blending: THREE.AdditiveBlending,
    });

    const particlePoints = new THREE.Points(particleGeometry, particleMaterial);
    scene.add(particlePoints);

    // 6. Interactive Mouse Tracking
    let mouseX = 0;
    let mouseY = 0;
    let targetMouseX = 0;
    let targetMouseY = 0;

    const handleMouseMove = (e) => {
      targetMouseX = (e.clientX / window.innerWidth - 0.5) * 2;
      targetMouseY = (e.clientY / window.innerHeight - 0.5) * 2;
    };

    const handleResize = () => {
      if (!container) return;
      width = window.innerWidth;
      height = window.innerHeight;
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    window.addEventListener('resize', handleResize);

    // 7. Animation Loop
    const clock = new THREE.Clock();
    let animId;

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const time = clock.getElapsedTime() * 0.8;

      // Mouse smoothing
      mouseX += (targetMouseX - mouseX) * 0.04;
      mouseY += (targetMouseY - mouseY) * 0.04;

      // Camera parallax
      camera.position.x = mouseX * 3.5;
      camera.position.y = 8 - mouseY * 2.0;
      camera.lookAt(0, -2, 0);

      // Light rotation
      light1.position.x = Math.sin(time * 0.5) * 16;
      light1.position.z = Math.cos(time * 0.5) * 12;
      light2.position.x = -Math.sin(time * 0.4) * 16;
      light2.position.z = -Math.cos(time * 0.4) * 12;

      // Deform 3D Liquid Terrain Vertices
      const pos = planeGeometry.attributes.position.array;
      for (let i = 0; i < vertexCount; i++) {
        const ox = originalPositions[i * 3];
        const oy = originalPositions[i * 3 + 1];
        const oz = originalPositions[i * 3 + 2];

        // Multi-frequency sinusoidal undulating wave
        const wave1 = Math.sin(ox * 0.18 + time * 1.2) * Math.cos(oz * 0.18 + time * 0.9) * 1.6;
        const wave2 = Math.sin(ox * 0.35 - time * 0.8 + oz * 0.2) * 0.8;
        const wave3 = Math.cos(Math.sqrt(ox * ox + oz * oz) * 0.25 - time * 1.4) * 0.5;

        // Apply deformation along local Y
        pos[i * 3 + 1] = oy + wave1 + wave2 + wave3;
      }
      planeGeometry.attributes.position.needsUpdate = true;
      planeGeometry.computeVertexNormals();

      // Animate floating dust particles
      const pPos = particleGeometry.attributes.position.array;
      for (let i = 0; i < particleCount; i++) {
        pPos[i * 3 + 1] += particleSpeeds[i];
        if (pPos[i * 3 + 1] > 20) {
          pPos[i * 3 + 1] = -5;
        }
      }
      particleGeometry.attributes.position.needsUpdate = true;

      renderer.render(scene, camera);
    };

    animate();

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animId);

      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }

      planeGeometry.dispose();
      planeMaterial.dispose();
      wireframeMaterial.dispose();
      particleGeometry.dispose();
      particleMaterial.dispose();
      renderer.dispose();
    };
  }, [currentTheme]);

  return (
    <div
      ref={mountRef}
      className="fixed inset-0 pointer-events-none z-0 overflow-hidden select-none"
      style={{ opacity: 0.85 }}
    />
  );
}
