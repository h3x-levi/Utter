import React, { useEffect, useRef } from 'react';
import * as THREE from 'three';

export default function DynamicBackground3D({ activeStage = 0 }) {
  const mountRef = useRef(null);
  const activeStageRef = useRef(activeStage);
  activeStageRef.current = activeStage;

  useEffect(() => {
    const container = mountRef.current;
    if (!container) return;

    // Scene & Camera
    const scene = new THREE.Scene();
    scene.fog = new THREE.FogExp2(0xedeceb, 0.018);

    const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);
    camera.position.set(0, 8, 22);
    camera.lookAt(0, 0, 0);

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: true,
      powerPreference: 'high-performance',
    });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.1;
    container.appendChild(renderer.domElement);

    // Warm Apple Studio Lighting
    const ambientLight = new THREE.AmbientLight(0xf5f4f0, 1.4);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xfff7ed, 2.0);
    sunLight.position.set(12, 18, 10);
    scene.add(sunLight);

    const fillLight = new THREE.DirectionalLight(0xe4e4e7, 1.0);
    fillLight.position.set(-14, 10, -8);
    scene.add(fillLight);

    // Procedural Organic Hilly Terrain Mesh
    const planeWidth = 56;
    const planeHeight = 46;
    const segX = 72;
    const segY = 64;
    const geometry = new THREE.PlaneGeometry(planeWidth, planeHeight, segX, segY);
    geometry.rotateX(-Math.PI / 2.2);

    // Store base vertices for procedural wave computation
    const pos = geometry.attributes.position;
    const initialZ = new Float32Array(pos.count);
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const y = pos.getY(i);
      const h =
        Math.sin(x * 0.14) * 1.8 +
        Math.cos(y * 0.18) * 1.6 +
        Math.sin(x * 0.08 + y * 0.09) * 2.2 +
        Math.cos(Math.sqrt(x * x + y * y) * 0.15) * 1.2;
      pos.setZ(i, h);
      initialZ[i] = h;
    }
    geometry.computeVertexNormals();

    // Material: Warm velvet ceramic / translucent stone
    const material = new THREE.MeshPhysicalMaterial({
      color: 0xf3f2ef,
      roughness: 0.65,
      metalness: 0.05,
      clearcoat: 0.35,
      clearcoatRoughness: 0.25,
      wireframe: false,
    });

    const terrainMesh = new THREE.Mesh(geometry, material);
    terrainMesh.position.set(0, -3.5, -4);
    scene.add(terrainMesh);

    // Delicate floating 3D acoustic particles
    const particleCount = 140;
    const particleGeo = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(particleCount * 3);
    for (let i = 0; i < particleCount * 3; i += 3) {
      particlePositions[i] = (Math.random() - 0.5) * 40;
      particlePositions[i + 1] = Math.random() * 12 - 2;
      particlePositions[i + 2] = (Math.random() - 0.5) * 26;
    }
    particleGeo.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));

    const particleMat = new THREE.PointsMaterial({
      color: 0x9ca3af,
      size: 0.14,
      transparent: true,
      opacity: 0.45,
    });
    const particles = new THREE.Points(particleGeo, particleMat);
    scene.add(particles);

    // Mouse Tracking for Smooth 3D Parallax
    let mouseX = 0;
    let mouseY = 0;
    let targetCameraX = 0;
    let targetCameraY = 8;
    let targetCameraZ = 22;

    const handleMouseMove = (e) => {
      mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
      mouseY = (e.clientY / window.innerHeight - 0.5) * 2;
    };
    window.addEventListener('mousemove', handleMouseMove);

    const handleResize = () => {
      if (!container) return;
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    };
    window.addEventListener('resize', handleResize);

    // Stage-based camera target configurations
    const stageCameraConfigs = [
      { x: 0, y: 8, z: 22 },       // Hero: Grand view
      { x: -3.5, y: 6.8, z: 18 },  // Dictation: Tilted close
      { x: 3.5, y: 7.2, z: 19 },   // Speech Models: Shift right
      { x: -2.5, y: 8.5, z: 20 },  // Meetings: Elevated view
      { x: 2.2, y: 6.2, z: 17 },   // Companion: Close intimate
      { x: 0, y: 9.2, z: 24 },     // Privacy: Panoramic security
    ];

    // Animation Loop
    let clock = new THREE.Clock();
    let animId;

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const time = clock.getElapsedTime();

      // Current target config based on active stage
      const stageIdx = Math.min(Math.max(activeStageRef.current, 0), stageCameraConfigs.length - 1);
      const targetConfig = stageCameraConfigs[stageIdx];

      // Smooth camera interpolation
      targetCameraX = targetConfig.x + mouseX * 1.5;
      targetCameraY = targetConfig.y - mouseY * 1.2;
      targetCameraZ = targetConfig.z;

      camera.position.x += (targetCameraX - camera.position.x) * 0.04;
      camera.position.y += (targetCameraY - camera.position.y) * 0.04;
      camera.position.z += (targetCameraZ - camera.position.z) * 0.04;
      camera.lookAt(0, 0, 0);

      // Subtle organic breathing animation of the terrain
      const posAttr = geometry.attributes.position;
      for (let i = 0; i < posAttr.count; i++) {
        const x = posAttr.getX(i);
        const y = posAttr.getY(i);
        const dynamicWave = Math.sin(time * 0.6 + x * 0.1 + y * 0.15) * 0.45;
        posAttr.setZ(i, initialZ[i] + dynamicWave);
      }
      posAttr.needsUpdate = true;
      geometry.computeVertexNormals();

      // Slow particle float
      particles.rotation.y = time * 0.03;

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
      geometry.dispose();
      material.dispose();
      particleGeo.dispose();
      particleMat.dispose();
      renderer.dispose();
    };
  }, []);

  return (
    <div
      ref={mountRef}
      className="fixed inset-0 pointer-events-none z-0 overflow-hidden"
      style={{ opacity: 0.95 }}
    />
  );
}
