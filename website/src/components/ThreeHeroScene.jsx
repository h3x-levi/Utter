import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';

export default function ThreeHeroScene({ isRecording }) {
  const mountRef = useRef(null);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    // Scene setup
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 100);
    camera.position.set(0, 0, 18);

    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: "high-performance" });
    renderer.setSize(container.clientWidth, container.clientHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.2;
    container.appendChild(renderer.domElement);

    // Studio Lighting (Apple Hardware Keylighting)
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
    scene.add(ambientLight);

    const keyLight = new THREE.DirectionalLight(0xffffff, 2.5);
    keyLight.position.set(10, 15, 12);
    scene.add(keyLight);

    const rimLight = new THREE.DirectionalLight(0x71717a, 1.8);
    rimLight.position.set(-12, -10, -8);
    scene.add(rimLight);

    const fillLight = new THREE.PointLight(0xffffff, 1.2, 30);
    fillLight.position.set(0, 0, 10);
    scene.add(fillLight);

    // 3D Titanium Waveform Sculpture Group
    const group = new THREE.Group();
    scene.add(group);

    // Material: Space Titanium PBR
    const titaniumMaterial = new THREE.MeshStandardMaterial({
      color: 0x27272a,
      roughness: 0.25,
      metalness: 0.92,
      envMapIntensity: 1.5,
    });

    const highlightMaterial = new THREE.MeshStandardMaterial({
      color: 0xfafafa,
      roughness: 0.15,
      metalness: 0.95,
    });

    // 7 Acoustic 3D Capsule Columns forming the 'U'
    const barCount = 7;
    const barMeshes = [];
    const baseHeights = [4.8, 3.2, 2.0, 1.4, 2.0, 3.2, 4.8];
    const barWidth = 0.55;
    const barSpacing = 0.95;

    for (let i = 0; i < barCount; i++) {
      const h = baseHeights[i];
      const geometry = new THREE.CylinderGeometry(barWidth / 2, barWidth / 2, h, 32, 16);
      const mesh = new THREE.Mesh(geometry, i === 0 || i === barCount - 1 ? highlightMaterial : titaniumMaterial);

      const x = (i - (barCount - 1) / 2) * barSpacing;
      mesh.position.set(x, 0, 0);
      mesh.castShadow = true;
      mesh.receiveShadow = true;

      group.add(mesh);
      barMeshes.push({ mesh, initialHeight: h, index: i });
    }

    // Connecting 3D Base Torus Arc (U-Basin)
    const arcRadius = 2.85;
    const arcGeometry = new THREE.TorusGeometry(arcRadius, 0.22, 24, 64, Math.PI);
    const arcMesh = new THREE.Mesh(arcGeometry, titaniumMaterial);
    arcMesh.rotation.z = Math.PI;
    arcMesh.position.set(0, -0.4, 0);
    group.add(arcMesh);

    // Ambient floating 3D orbital rings
    const ringGeo = new THREE.TorusGeometry(5.2, 0.04, 16, 100);
    const ringMat = new THREE.MeshBasicMaterial({ color: 0x3f3f46, transparent: true, opacity: 0.4 });
    const ringMesh = new THREE.Mesh(ringGeo, ringMat);
    ringMesh.rotation.x = Math.PI / 2.6;
    group.add(ringMesh);

    // Mouse Tracking for Parallax
    let mouseX = 0;
    let mouseY = 0;
    let targetRotX = 0;
    let targetRotY = 0;

    const handleMouseMove = (e) => {
      const rect = container.getBoundingClientRect();
      mouseX = ((e.clientX - rect.left) / rect.width - 0.5) * 2;
      mouseY = ((e.clientY - rect.top) / rect.height - 0.5) * 2;
    };
    window.addEventListener('mousemove', handleMouseMove);

    const handleResize = () => {
      if (!container) return;
      camera.aspect = container.clientWidth / container.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(container.clientWidth, container.clientHeight);
    };
    window.addEventListener('resize', handleResize);

    // Animation Loop
    let clock = new THREE.Clock();
    let animId;

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const time = clock.getElapsedTime();

      // Smooth camera / group parallax
      targetRotX += (mouseY * 0.35 - targetRotX) * 0.05;
      targetRotY += (mouseX * 0.55 - targetRotY) * 0.05;

      group.rotation.x = targetRotX + Math.sin(time * 0.8) * 0.04;
      group.rotation.y = targetRotY + time * 0.15;
      ringMesh.rotation.z = time * 0.2;

      // Acoustic wave oscillations on 3D bars
      barMeshes.forEach(({ mesh, initialHeight, index }) => {
        const oscSpeed = isRecording ? 6.0 : 2.0;
        const oscAmp = isRecording ? 0.9 : 0.25;
        const wave = Math.sin(time * oscSpeed + index * 0.8) * oscAmp;
        const scaleY = Math.max(0.3, 1 + wave / initialHeight);

        mesh.scale.set(1, scaleY, 1);
      });

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
      titaniumMaterial.dispose();
      highlightMaterial.dispose();
      ringMat.dispose();
      renderer.dispose();
    };
  }, [isRecording]);

  return (
    <div
      ref={mountRef}
      className="w-full h-[360px] sm:h-[440px] relative cursor-grab active:cursor-grabbing"
    />
  );
}
