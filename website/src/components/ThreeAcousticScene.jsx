import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';

export default function ThreeAcousticScene({ isRecording = false, accentColor = '#f97316' }) {
  const mountRef = useRef(null);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    let width = container.clientWidth || window.innerWidth;
    let height = container.clientHeight || 500;

    // 1. Scene, Camera, Renderer
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100);
    camera.position.set(0, 0, 15);

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.25;
    container.appendChild(renderer.domElement);

    // 2. Lighting setup
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);

    const dirLight1 = new THREE.DirectionalLight(0xffffff, 2.0);
    dirLight1.position.set(12, 16, 12);
    scene.add(dirLight1);

    const dirLight2 = new THREE.DirectionalLight(new THREE.Color(accentColor), 1.6);
    dirLight2.position.set(-10, -8, 8);
    scene.add(dirLight2);

    const rootGroup = new THREE.Group();
    scene.add(rootGroup);

    // 3. Acoustic Particle Cloud (1,400 Glowing Wave Particles)
    const particleCount = 1400;
    const pGeometry = new THREE.BufferGeometry();
    const positions = new Float32Array(particleCount * 3);
    const basePositions = new Float32Array(particleCount * 3);
    const phases = new Float32Array(particleCount);
    const speeds = new Float32Array(particleCount);

    const radius = 5.2;
    for (let i = 0; i < particleCount; i++) {
      const theta = Math.random() * Math.PI * 2;
      const phi = Math.acos(Math.random() * 2 - 1);
      const r = radius * (0.88 + Math.random() * 0.24);

      const x = r * Math.sin(phi) * Math.cos(theta);
      const y = r * Math.sin(phi) * Math.sin(theta);
      const z = r * Math.cos(phi);

      positions[i * 3] = x;
      positions[i * 3 + 1] = y;
      positions[i * 3 + 2] = z;

      basePositions[i * 3] = x;
      basePositions[i * 3 + 1] = y;
      basePositions[i * 3 + 2] = z;

      phases[i] = Math.random() * Math.PI * 2;
      speeds[i] = 1.2 + Math.random() * 1.8;
    }

    pGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));

    const pMaterial = new THREE.PointsMaterial({
      color: new THREE.Color(accentColor),
      size: 0.14,
      transparent: true,
      opacity: 0.75,
      blending: THREE.AdditiveBlending,
    });

    const particlePoints = new THREE.Points(pGeometry, pMaterial);
    rootGroup.add(particlePoints);

    // 4. Central Titanium Acoustic Waveform Pillars (Utter's Core Sound Signature)
    const titaniumMaterial = new THREE.MeshStandardMaterial({
      color: 0x1f242d,
      roughness: 0.2,
      metalness: 0.95,
      envMapIntensity: 1.8,
    });

    const glowingCapMaterial = new THREE.MeshStandardMaterial({
      color: new THREE.Color(accentColor),
      roughness: 0.1,
      metalness: 0.8,
      emissive: new THREE.Color(accentColor),
      emissiveIntensity: 0.45,
    });

    const barGroup = new THREE.Group();
    rootGroup.add(barGroup);

    const barCount = 7;
    const barBars = [];
    const baseHeights = [3.6, 2.6, 1.8, 1.3, 1.8, 2.6, 3.6];
    const barWidth = 0.42;
    const barSpacing = 0.85;

    for (let i = 0; i < barCount; i++) {
      const h = baseHeights[i];
      const geom = new THREE.CylinderGeometry(barWidth / 2, barWidth / 2, h, 28, 1);
      const barMesh = new THREE.Mesh(geom, i === 0 || i === barCount - 1 ? glowingCapMaterial : titaniumMaterial);

      const x = (i - (barCount - 1) / 2) * barSpacing;
      barMesh.position.set(x, 0, 0);
      barGroup.add(barMesh);

      barBars.push({ mesh: barMesh, baseHeight: h, index: i });
    }

    // 5. Outer Orbital Sound Rings (representing whisper.cpp on-device inference)
    const ringGeo1 = new THREE.TorusGeometry(4.4, 0.035, 16, 96);
    const ringMat1 = new THREE.MeshBasicMaterial({
      color: 0x71717a,
      transparent: true,
      opacity: 0.35,
    });
    const ring1 = new THREE.Mesh(ringGeo1, ringMat1);
    ring1.rotation.x = Math.PI / 2.5;
    rootGroup.add(ring1);

    const ringGeo2 = new THREE.TorusGeometry(5.8, 0.025, 16, 96);
    const ringMat2 = new THREE.MeshBasicMaterial({
      color: new THREE.Color(accentColor),
      transparent: true,
      opacity: 0.45,
    });
    const ring2 = new THREE.Mesh(ringGeo2, ringMat2);
    ring2.rotation.x = -Math.PI / 3.2;
    ring2.rotation.y = Math.PI / 6;
    rootGroup.add(ring2);

    // 6. Interactive Mouse Parallax & Drag Rotation
    let mouseX = 0;
    let mouseY = 0;
    let targetRotX = 0;
    let targetRotY = 0;
    let isDragging = false;
    let previousMousePosition = { x: 0, y: 0 };

    const handleMouseMove = (e) => {
      const rect = container.getBoundingClientRect();
      const nx = ((e.clientX - rect.left) / rect.width - 0.5) * 2;
      const ny = ((e.clientY - rect.top) / rect.height - 0.5) * 2;

      if (isDragging) {
        const deltaX = e.clientX - previousMousePosition.x;
        const deltaY = e.clientY - previousMousePosition.y;
        rootGroup.rotation.y += deltaX * 0.01;
        rootGroup.rotation.x += deltaY * 0.01;
        previousMousePosition = { x: e.clientX, y: e.clientY };
      } else {
        mouseX = nx;
        mouseY = ny;
      }
    };

    const handleMouseDown = (e) => {
      isDragging = true;
      previousMousePosition = { x: e.clientX, y: e.clientY };
    };

    const handleMouseUp = () => {
      isDragging = false;
    };

    const handleResize = () => {
      if (!container) return;
      width = container.clientWidth;
      height = container.clientHeight;
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
    container.addEventListener('mousedown', handleMouseDown);
    window.addEventListener('resize', handleResize);

    // 7. Animation Loop
    const clock = new THREE.Clock();
    let animId;

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const time = clock.getElapsedTime();

      // Smooth damped parallax
      if (!isDragging) {
        targetRotX += (mouseY * 0.25 - targetRotX) * 0.05;
        targetRotY += (mouseX * 0.45 - targetRotY) * 0.05;

        rootGroup.rotation.x = targetRotX + Math.sin(time * 0.8) * 0.04;
        rootGroup.rotation.y = targetRotY + time * 0.12;
      }

      ring1.rotation.z = time * 0.15;
      ring2.rotation.z = -time * 0.22;

      // Dynamic Bar Wave Modulation
      const waveSpeed = isRecording ? 7.5 : 2.5;
      const waveIntensity = isRecording ? 1.2 : 0.35;

      barBars.forEach(({ mesh, baseHeight, index }) => {
        const osc = Math.sin(time * waveSpeed + index * 0.95) * waveIntensity;
        const targetScaleY = Math.max(0.2, 1 + osc / baseHeight);
        mesh.scale.y += (targetScaleY - mesh.scale.y) * 0.15;
      });

      // Particle Displacement Wave
      const posArray = pGeometry.attributes.position.array;
      const amp = isRecording ? 0.85 : 0.25;
      const freq = isRecording ? 4.0 : 1.5;

      for (let i = 0; i < particleCount; i++) {
        const bx = basePositions[i * 3];
        const by = basePositions[i * 3 + 1];
        const bz = basePositions[i * 3 + 2];
        const ph = phases[i];
        const sp = speeds[i];

        const dist = Math.sqrt(bx * bx + by * by + bz * bz);
        const wave = Math.sin(time * sp * freq + ph) * amp;

        posArray[i * 3] = bx + (bx / dist) * wave;
        posArray[i * 3 + 1] = by + (by / dist) * wave;
        posArray[i * 3 + 2] = bz + (bz / dist) * wave;
      }
      pGeometry.attributes.position.needsUpdate = true;

      renderer.render(scene, camera);
    };

    animate();

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
      if (container) {
        container.removeEventListener('mousedown', handleMouseDown);
      }
      window.removeEventListener('resize', handleResize);
      cancelAnimationFrame(animId);

      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }

      pGeometry.dispose();
      pMaterial.dispose();
      titaniumMaterial.dispose();
      glowingCapMaterial.dispose();
      ringGeo1.dispose();
      ringMat1.dispose();
      ringGeo2.dispose();
      ringMat2.dispose();
      renderer.dispose();
    };
  }, [isRecording, accentColor]);

  return (
    <div
      ref={mountRef}
      className="w-full h-full min-h-[380px] sm:min-h-[460px] lg:min-h-[540px] relative cursor-grab active:cursor-grabbing select-none"
      title="Drag to rotate 3D acoustic sculpture"
    />
  );
}
