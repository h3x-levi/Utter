import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';

export default function DynamicBackground3D({ activeStage = 0 }) {
  const mountRef = useRef(null);
  const activeStageRef = useRef(activeStage);
  activeStageRef.current = activeStage;
  const [webglSupported, setWebglSupported] = useState(true);

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    // Verify WebGL availability safely
    try {
      const testCanvas = document.createElement('canvas');
      const gl = testCanvas.getContext('webgl2') || testCanvas.getContext('webgl') || testCanvas.getContext('experimental-webgl');
      if (!gl) {
        setWebglSupported(false);
        return;
      }
    } catch (e) {
      setWebglSupported(false);
      return;
    }

    let renderer, scene, camera, terrainMesh, particles, animId;

    try {
      // Scene & Dark Obsidian Fog
      scene = new THREE.Scene();
      scene.fog = new THREE.FogExp2(0x09090b, 0.024);

      camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);
      camera.position.set(0, 7, 20);
      camera.lookAt(0, 0, 0);

      renderer = new THREE.WebGLRenderer({
        alpha: true,
        antialias: true,
        powerPreference: 'high-performance',
      });
      renderer.setSize(window.innerWidth, window.innerHeight);
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
      renderer.toneMapping = THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure = 1.3;
      container.appendChild(renderer.domElement);

      // High-Contrast Studio & Specular Rim Lighting
      const ambientLight = new THREE.AmbientLight(0x18181b, 1.2);
      scene.add(ambientLight);

      const keyLight = new THREE.DirectionalLight(0xffffff, 2.8);
      keyLight.position.set(12, 16, 10);
      scene.add(keyLight);

      const rimLight = new THREE.DirectionalLight(0x5f61ed, 3.5);
      rimLight.position.set(-15, -6, -10);
      scene.add(rimLight);

      const fillLight = new THREE.PointLight(0x818cf8, 1.5, 30);
      fillLight.position.set(0, 10, 5);
      scene.add(fillLight);

      // Procedural Acoustic Glass Terrain Mesh
      const planeWidth = 56;
      const planeHeight = 44;
      const segX = 64;
      const segY = 56;
      const geometry = new THREE.PlaneGeometry(planeWidth, planeHeight, segX, segY);
      geometry.rotateX(-Math.PI / 2.2);

      const pos = geometry.attributes.position;
      const initialZ = new Float32Array(pos.count);
      for (let i = 0; i < pos.count; i++) {
        const x = pos.getX(i);
        const y = pos.getY(i);
        const h =
          Math.sin(x * 0.18) * 2.0 +
          Math.cos(y * 0.22) * 1.6 +
          Math.sin(x * 0.1 + y * 0.12) * 2.2 +
          Math.cos(Math.sqrt(x * x + y * y) * 0.2) * 1.4;
        pos.setZ(i, h);
        initialZ[i] = h;
      }
      geometry.computeVertexNormals();

      const material = new THREE.MeshPhysicalMaterial({
        color: 0x18181b,
        roughness: 0.18,
        metalness: 0.88,
        transmission: 0.85,
        thickness: 1.8,
        ior: 1.52,
        clearcoat: 1.0,
        clearcoatRoughness: 0.1,
        wireframe: false,
      });

      terrainMesh = new THREE.Mesh(geometry, material);
      terrainMesh.position.set(0, -3.2, -4);
      scene.add(terrainMesh);

      // Glowing Ambient Micro-Particles
      const particleCount = 140;
      const particleGeo = new THREE.BufferGeometry();
      const particlePositions = new Float32Array(particleCount * 3);
      for (let i = 0; i < particleCount * 3; i += 3) {
        particlePositions[i] = (Math.random() - 0.5) * 44;
        particlePositions[i + 1] = Math.random() * 14 - 2;
        particlePositions[i + 2] = (Math.random() - 0.5) * 28;
      }
      particleGeo.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));

      const particleMat = new THREE.PointsMaterial({
        color: 0x818cf8,
        size: 0.12,
        transparent: true,
        opacity: 0.55,
        blending: THREE.AdditiveBlending,
      });
      particles = new THREE.Points(particleGeo, particleMat);
      scene.add(particles);

      let mouseX = 0;
      let mouseY = 0;
      let targetCameraX = 0;
      let targetCameraY = 7;
      let targetCameraZ = 20;

      const handleMouseMove = (e) => {
        mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
        mouseY = (e.clientY / window.innerHeight - 0.5) * 2;
      };
      window.addEventListener('mousemove', handleMouseMove);

      const handleResize = () => {
        if (!container || !renderer || !camera) return;
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
      };
      window.addEventListener('resize', handleResize);

      const stageCameraConfigs = [
        { x: 0, y: 7, z: 20 },
        { x: -3.2, y: 6.2, z: 17 },
        { x: 3.5, y: 6.8, z: 18 },
        { x: -2.2, y: 7.8, z: 19 },
        { x: 2.0, y: 5.8, z: 16 },
        { x: 0, y: 8.5, z: 22 },
      ];

      const clock = new THREE.Clock();

      const animate = () => {
        animId = requestAnimationFrame(animate);
        const time = clock.getElapsedTime();

        const stageIdx = Math.min(Math.max(activeStageRef.current, 0), stageCameraConfigs.length - 1);
        const targetConfig = stageCameraConfigs[stageIdx];

        targetCameraX = targetConfig.x + mouseX * 1.6;
        targetCameraY = targetConfig.y - mouseY * 1.2;
        targetCameraZ = targetConfig.z;

        camera.position.x += (targetCameraX - camera.position.x) * 0.04;
        camera.position.y += (targetCameraY - camera.position.y) * 0.04;
        camera.position.z += (targetCameraZ - camera.position.z) * 0.04;
        camera.lookAt(0, 0, 0);

        if (geometry && geometry.attributes && geometry.attributes.position) {
          const posAttr = geometry.attributes.position;
          for (let i = 0; i < posAttr.count; i++) {
            const x = posAttr.getX(i);
            const y = posAttr.getY(i);
            const wave = Math.sin(time * 0.8 + x * 0.12 + y * 0.16) * 0.55;
            posAttr.setZ(i, initialZ[i] + wave);
          }
          posAttr.needsUpdate = true;
          geometry.computeVertexNormals();
        }

        if (particles) {
          particles.rotation.y = time * 0.04;
        }

        renderer.render(scene, camera);
      };
      animate();

      return () => {
        window.removeEventListener('mousemove', handleMouseMove);
        window.removeEventListener('resize', handleResize);
        if (animId) cancelAnimationFrame(animId);
        if (container && renderer && renderer.domElement && container.contains(renderer.domElement)) {
          container.removeChild(renderer.domElement);
        }
        if (geometry) geometry.dispose();
        if (material) material.dispose();
        if (particleGeo) particleGeo.dispose();
        if (particleMat) particleMat.dispose();
        if (renderer) renderer.dispose();
      };
    } catch (err) {
      console.warn('WebGL initialization failed, falling back to CSS luxury background:', err);
      setWebglSupported(false);
    }
  }, []);

  return (
    <div
      ref={mountRef}
      className="fixed inset-0 pointer-events-none z-0 overflow-hidden bg-[#09090b]"
      style={{ opacity: 0.96 }}
    >
      {/* Luxury CSS Radial & Specular Grid Fallback when WebGL is unavailable or loading */}
      {!webglSupported && (
        <div className="absolute inset-0 pointer-events-none overflow-hidden">
          <div
            className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[900px] h-[600px] rounded-full opacity-30"
            style={{
              background: 'radial-gradient(ellipse at center, rgba(95, 97, 237, 0.4) 0%, rgba(129, 140, 248, 0.1) 40%, transparent 70%)',
              filter: 'blur(80px)',
            }}
          />
          <div
            className="absolute bottom-1/4 right-1/4 w-[600px] h-[400px] rounded-full opacity-20"
            style={{
              background: 'radial-gradient(ellipse at center, rgba(147, 51, 234, 0.3) 0%, transparent 70%)',
              filter: 'blur(90px)',
            }}
          />
          {/* Subtle Cyber Glass Acoustic Grid */}
          <div
            className="absolute inset-0 opacity-[0.04]"
            style={{
              backgroundImage: 'linear-gradient(#ffffff 1px, transparent 1px), linear-gradient(90deg, #ffffff 1px, transparent 1px)',
              backgroundSize: '40px 40px',
            }}
          />
        </div>
      )}
    </div>
  );
}
