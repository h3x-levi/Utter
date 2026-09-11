import React, { useEffect, useRef, useState } from 'react';

/**
 * CodeCompanionCanvas: Faithful JavaScript/HTML5 Canvas port of UtterKit's
 * procedural vector companion engine (`CodePixelCat.swift`).
 *
 * Built-in companions:
 *  1. Charcoal Cat (`pixel-cat-gray`): Slate-charcoal coat, white chest bib & snout, cyan eyes, waving paw.
 *  2. Ginger Cat (`pixel-cat-orange`): Warm tabby coat, white bib, emerald eyes, waving paw.
 *  3. Pixel Dog (`dog`): Golden puppy coat, floppy brown ears, cream muzzle, happy pink tongue.
 *  4. Pixel Panda (`panda`): Round black ears, iconic black eye patches, white head, pink toe pads.
 *
 * Drawn 100% procedurally in code at 60 FPS — zero PNG frames loaded or bundled.
 */

export default function CodeCompanionCanvas({
  species = 'cat',
  isGinger = false,
  styleId = null,
  action = 'waving',
  width = 180,
  height = 180,
  className = '',
  enableTracking = true,
}) {
  const canvasRef = useRef(null);
  const mousePosRef = useRef({ x: 0, y: 0 });
  const [isHovered, setIsHovered] = useState(false);

  // Normalize species & styling
  let resolvedSpecies = species;
  let resolvedIsGinger = isGinger;

  if (styleId) {
    if (styleId === 'gray' || styleId === 'pixel-cat-gray' || styleId === 'charcoal-cat') {
      resolvedSpecies = 'cat';
      resolvedIsGinger = false;
    } else if (styleId === 'orange' || styleId === 'pixel-cat-orange' || styleId === 'ginger-cat') {
      resolvedSpecies = 'cat';
      resolvedIsGinger = true;
    } else if (styleId === 'dog' || styleId === 'pixel-dog') {
      resolvedSpecies = 'dog';
      resolvedIsGinger = false;
    } else if (styleId === 'panda' || styleId === 'pixel-panda') {
      resolvedSpecies = 'panda';
      resolvedIsGinger = false;
    }
  }

  // Track cursor globally or locally
  useEffect(() => {
    if (!enableTracking) return;

    const handleMouseMove = (e) => {
      if (!canvasRef.current) return;
      const rect = canvasRef.current.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      const dx = (e.clientX - centerX) / Math.max(1, window.innerWidth / 2);
      const dy = (e.clientY - centerY) / Math.max(1, window.innerHeight / 2);
      mousePosRef.current = {
        x: Math.max(-1, Math.min(1, dx)),
        y: Math.max(-1, Math.min(1, dy)),
      };
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, [enableTracking]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animId;
    let startTime = performance.now();

    const render = (now) => {
      const elapsed = (now - startTime) / 1000;
      const dpr = window.devicePixelRatio || 1;

      // Handle retina scaling
      if (canvas.width !== width * dpr || canvas.height !== height * dpr) {
        canvas.width = width * dpr;
        canvas.height = height * dpr;
      }

      ctx.save();
      ctx.scale(dpr, dpr);
      ctx.clearRect(0, 0, width, height);

      const S = Math.min(width, height);
      const gaze = mousePosRef.current;
      const gazeX = gaze.x * (S * 0.024);
      const gazeY = gaze.y * (S * 0.024);

      // Procedural micro-motions
      const breath = Math.sin(elapsed * 2.5) * (S * 0.012);
      const wave = Math.sin(elapsed * 4.5) * (S * 0.035);
      const wag = Math.sin(elapsed * 6.0) * (S * 0.04);
      const walkCycle = Math.sin(elapsed * 5.0);

      // Ground ambient shadow
      const shadowW = S * 0.70;
      const shadowH = S * 0.11;
      ctx.beginPath();
      ctx.ellipse(S * 0.5, S * 0.86 + breath * 0.5, shadowW * 0.5, shadowH * 0.5, 0, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(0, 0, 0, 0.28)';
      ctx.fill();

      if (resolvedSpecies === 'cat') {
        drawVectorCat(ctx, S, {
          isGinger: resolvedIsGinger,
          action,
          elapsed,
          gazeX,
          gazeY,
          breath,
          wave,
          walkCycle,
          isHovered,
        });
      } else if (resolvedSpecies === 'dog') {
        drawVectorDog(ctx, S, {
          action,
          elapsed,
          gazeX,
          gazeY,
          breath,
          wag,
          walkCycle,
          isHovered,
        });
      } else if (resolvedSpecies === 'panda') {
        drawVectorPanda(ctx, S, {
          action,
          elapsed,
          gazeX,
          gazeY,
          breath,
          walkCycle,
          isHovered,
        });
      }

      ctx.restore();
      animId = requestAnimationFrame(render);
    };

    animId = requestAnimationFrame(render);
    return () => cancelAnimationFrame(animId);
  }, [resolvedSpecies, resolvedIsGinger, action, width, height, isHovered]);

  return (
    <canvas
      ref={canvasRef}
      style={{ width: `${width}px`, height: `${height}px` }}
      className={`select-none ${className}`}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    />
  );
}

/* =========================================================================
   VECTOR RENDERERS (Faithful translation of CodePixelCat.swift)
   ========================================================================= */

function drawVectorCat(ctx, S, state) {
  const { isGinger, action, gazeX, gazeY, breath, wave, walkCycle } = state;
  const isLoaf = action === 'loaf' || action === 'sleep';
  const isWalking = action === 'walk';
  const isKneading = action === 'knead';
  const isDelighted = action === 'delighted';
  const isThinking = action === 'thinking';
  const isWaving = action === 'waving' || (!isLoaf && !isWalking && !isKneading && !isDelighted && !isThinking);

  // Colors matching CodePixelCat.swift lines 664-673
  const coatColor = isGinger ? '#f97316' : '#2a2e37';
  const coatHighlight = isGinger ? '#fb923c' : '#475569';
  const coatShadow = isGinger ? '#c2410c' : '#1e293b';
  const creamColor = isGinger ? '#ffedd5' : '#f1f5f9';
  const stripeColor = isGinger ? '#9a3412' : '#0f172a';
  const pinkColor = '#f472b6';
  const outlineColor = isGinger ? '#431407' : '#090d16';
  const irisColor = isGinger ? '#22c55e' : '#38bdf8';
  const irisDark = isGinger ? '#15803d' : '#0284c7';

  const by = breath;

  // 1. Far Hind Haunch & Paw
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.27, S * 0.78 + by, S * 0.09, S * 0.08, 0, 0, Math.PI * 2);
    ctx.fillStyle = coatShadow;
    ctx.fill();

    ctx.beginPath();
    ctx.roundRect(S * 0.14, S * 0.81 + by, S * 0.13, S * 0.09, S * 0.045);
    ctx.fillStyle = creamColor;
    ctx.fill();
  }

  // 2. Tail
  ctx.beginPath();
  if (isLoaf) {
    ctx.moveTo(S * 0.68, S * 0.78 + by);
    ctx.quadraticCurveTo(S * 0.86, S * 0.88 + by, S * 0.28, S * 0.85 + by);
  } else {
    ctx.moveTo(S * 0.68, S * 0.74 + by);
    ctx.quadraticCurveTo(S * 0.85 + (isDelighted ? wave * 0.5 : 0), S * 0.58 + by, S * 0.90, S * 0.38 + by);
  }
  ctx.strokeStyle = coatColor;
  ctx.lineWidth = S * 0.11;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.stroke();

  // Tail cream tip
  if (!isLoaf) {
    ctx.beginPath();
    ctx.moveTo(S * 0.88, S * 0.44 + by);
    ctx.lineTo(S * 0.90, S * 0.38 + by);
    ctx.strokeStyle = creamColor;
    ctx.lineWidth = S * 0.10;
    ctx.lineCap = 'round';
    ctx.stroke();
  }

  // 3. Torso Silhouette
  ctx.beginPath();
  if (isLoaf) {
    ctx.roundRect(S * 0.20, S * 0.56 + by, S * 0.60, S * 0.30, S * 0.15);
  } else {
    ctx.moveTo(S * 0.34, S * 0.50 + by);
    ctx.lineTo(S * 0.66, S * 0.50 + by);
    ctx.quadraticCurveTo(S * 0.76, S * 0.68 + by, S * 0.74, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.50, S * 0.88 + by, S * 0.26, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.24, S * 0.68 + by, S * 0.34, S * 0.50 + by);
    ctx.closePath();
  }
  const bodyGrad = ctx.createLinearGradient(0, S * 0.48 + by, 0, S * 0.88 + by);
  bodyGrad.addColorStop(0, coatHighlight);
  bodyGrad.addColorStop(0.5, coatColor);
  bodyGrad.addColorStop(1, coatShadow);
  ctx.fillStyle = bodyGrad;
  ctx.fill();

  // Torso Flank Tabby Stripes
  if (isGinger) {
    ctx.strokeStyle = stripeColor;
    ctx.lineWidth = S * 0.026;
    ctx.lineCap = 'round';
    // Left stripes
    ctx.beginPath();
    ctx.moveTo(S * 0.29, S * 0.60 + by);
    ctx.quadraticCurveTo(S * 0.32, S * 0.62 + by, S * 0.35, S * 0.63 + by);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(S * 0.29, S * 0.70 + by);
    ctx.quadraticCurveTo(S * 0.33, S * 0.72 + by, S * 0.37, S * 0.73 + by);
    ctx.stroke();
    // Right stripes
    ctx.beginPath();
    ctx.moveTo(S * 0.71, S * 0.60 + by);
    ctx.quadraticCurveTo(S * 0.68, S * 0.62 + by, S * 0.65, S * 0.63 + by);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(S * 0.71, S * 0.70 + by);
    ctx.quadraticCurveTo(S * 0.67, S * 0.72 + by, S * 0.63, S * 0.73 + by);
    ctx.stroke();
  }

  // Cream Belly Bib
  ctx.beginPath();
  ctx.moveTo(S * 0.38, S * 0.51 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.53 + by, S * 0.62, S * 0.51 + by);
  ctx.quadraticCurveTo(S * 0.65, S * 0.67 + by, S * 0.64, S * 0.81 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.84 + by, S * 0.36, S * 0.81 + by);
  ctx.quadraticCurveTo(S * 0.35, S * 0.67 + by, S * 0.38, S * 0.51 + by);
  ctx.closePath();
  ctx.fillStyle = creamColor;
  ctx.fill();

  // 4. Near Hind Haunch & Paw
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.69, S * 0.75 + by, S * 0.11, S * 0.09, 0, 0, Math.PI * 2);
    const haunchGrad = ctx.createLinearGradient(S * 0.64, S * 0.66 + by, S * 0.76, S * 0.84 + by);
    haunchGrad.addColorStop(0, coatHighlight);
    haunchGrad.addColorStop(1, coatColor);
    ctx.fillStyle = haunchGrad;
    ctx.fill();

    ctx.beginPath();
    ctx.roundRect(S * 0.66, S * 0.80 + by, S * 0.14, S * 0.10, S * 0.05);
    ctx.fillStyle = creamColor;
    ctx.fill();
  }

  // 5. Forelimbs & Front Paws
  const pawW = S * 0.15;
  const pawH = S * 0.12;

  if (isLoaf) {
    ctx.fillStyle = creamColor;
    ctx.beginPath();
    ctx.roundRect(S * 0.36, S * 0.81 + by, pawW * 0.75, pawH * 0.65, pawH * 0.3);
    ctx.roundRect(S * 0.52, S * 0.81 + by, pawW * 0.75, pawH * 0.65, pawH * 0.3);
    ctx.fill();
  } else if (isWalking) {
    // 4-limb walking stride
    const leftWalkY = S * 0.79 + by - Math.max(0, walkCycle) * (S * 0.04);
    const rightWalkY = S * 0.79 + by - Math.max(0, -walkCycle) * (S * 0.04);

    ctx.strokeStyle = coatColor;
    ctx.lineWidth = S * 0.10;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(S * 0.38, S * 0.58 + by);
    ctx.lineTo(S * 0.38 + walkCycle * (S * 0.05), leftWalkY);
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(S * 0.60, S * 0.58 + by);
    ctx.lineTo(S * 0.60 - walkCycle * (S * 0.05), rightWalkY);
    ctx.stroke();

    ctx.fillStyle = creamColor;
    ctx.beginPath();
    ctx.roundRect(S * 0.31 + walkCycle * (S * 0.05), leftWalkY, pawW, pawH, pawH * 0.5);
    ctx.roundRect(S * 0.53 - walkCycle * (S * 0.05), rightWalkY, pawW, pawH, pawH * 0.5);
    ctx.fill();
  } else if (isKneading) {
    // Kneading alternating paws
    const kneadCycle = Math.sin(state.elapsed * 6.0);
    const leftKneadY = S * 0.78 + by + kneadCycle * (S * 0.035);
    const rightKneadY = S * 0.78 + by - kneadCycle * (S * 0.035);

    ctx.fillStyle = creamColor;
    ctx.beginPath();
    ctx.roundRect(S * 0.30, leftKneadY, pawW * 1.05, pawH, pawH * 0.5);
    ctx.roundRect(S * 0.54, rightKneadY, pawW * 1.05, pawH, pawH * 0.5);
    ctx.fill();

    // Pink toe beans
    ctx.fillStyle = pinkColor;
    ctx.beginPath();
    ctx.ellipse(S * 0.30 + pawW * 0.52, leftKneadY + pawH * 0.5, pawW * 0.22, pawH * 0.2, 0, 0, Math.PI * 2);
    ctx.ellipse(S * 0.54 + pawW * 0.52, rightKneadY + pawH * 0.5, pawW * 0.22, pawH * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();
  } else if (isDelighted) {
    // Both paws raised celebrating
    ctx.strokeStyle = coatColor;
    ctx.lineWidth = S * 0.10;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(S * 0.36, S * 0.54 + by);
    ctx.lineTo(S * 0.26, S * 0.38 + by + wave * 0.5);
    ctx.moveTo(S * 0.64, S * 0.54 + by);
    ctx.lineTo(S * 0.74, S * 0.38 + by - wave * 0.5);
    ctx.stroke();

    ctx.fillStyle = creamColor;
    ctx.beginPath();
    ctx.roundRect(S * 0.19, S * 0.32 + by + wave * 0.5, pawW, pawH, pawH * 0.5);
    ctx.roundRect(S * 0.67, S * 0.32 + by - wave * 0.5, pawW, pawH, pawH * 0.5);
    ctx.fill();

    ctx.fillStyle = pinkColor;
    ctx.beginPath();
    ctx.ellipse(S * 0.19 + pawW * 0.5, S * 0.32 + by + wave * 0.5 + pawH * 0.5, pawW * 0.22, pawH * 0.2, 0, 0, Math.PI * 2);
    ctx.ellipse(S * 0.67 + pawW * 0.5, S * 0.32 + by - wave * 0.5 + pawH * 0.5, pawW * 0.22, pawH * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();
  } else {
    // Default & Waving: Left paw seated, Right paw (viewer's right, cat's left) waving hello!
    // Left arm & paw
    ctx.strokeStyle = coatColor;
    ctx.lineWidth = S * 0.11;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(S * 0.38, S * 0.54 + by);
    ctx.lineTo(S * 0.38, S * 0.78 + by);
    ctx.stroke();

    ctx.fillStyle = creamColor;
    ctx.beginPath();
    ctx.roundRect(S * 0.31, S * 0.79 + by, pawW, pawH, pawH * 0.5);
    ctx.fill();

    // Toe dividers
    ctx.strokeStyle = 'rgba(15, 23, 42, 0.35)';
    ctx.lineWidth = S * 0.012;
    ctx.beginPath();
    ctx.moveTo(S * 0.31 + pawW * 0.33, S * 0.79 + by + pawH * 0.55);
    ctx.lineTo(S * 0.31 + pawW * 0.33, S * 0.79 + by + pawH);
    ctx.moveTo(S * 0.31 + pawW * 0.66, S * 0.79 + by + pawH * 0.55);
    ctx.lineTo(S * 0.31 + pawW * 0.66, S * 0.79 + by + pawH);
    ctx.stroke();

    // Right arm & Waving Paw (cat's left paw, viewer's right)
    if (isWaving) {
      const pawWaveY = S * 0.44 + by + wave;
      ctx.strokeStyle = coatColor;
      ctx.lineWidth = S * 0.11;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(S * 0.62, S * 0.54 + by);
      ctx.quadraticCurveTo(S * 0.74, S * 0.54 + by, S * 0.72, pawWaveY + pawH * 0.5);
      ctx.stroke();

      ctx.fillStyle = creamColor;
      ctx.beginPath();
      ctx.roundRect(S * 0.65, pawWaveY, pawW * 0.95, pawH * 0.95, pawH * 0.48);
      ctx.fill();

      // Cute pink toe bean pad on waving paw
      ctx.fillStyle = pinkColor;
      ctx.beginPath();
      ctx.ellipse(S * 0.65 + pawW * 0.47, pawWaveY + pawH * 0.47, pawW * 0.22, pawH * 0.20, 0, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // Resting right paw
      ctx.strokeStyle = coatColor;
      ctx.lineWidth = S * 0.11;
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.moveTo(S * 0.62, S * 0.54 + by);
      ctx.lineTo(S * 0.60, S * 0.78 + by);
      ctx.stroke();

      ctx.fillStyle = creamColor;
      ctx.beginPath();
      ctx.roundRect(S * 0.53, S * 0.79 + by, pawW, pawH, pawH * 0.5);
      ctx.fill();
    }
  }

  // 6. Ears
  // Left Ear
  ctx.beginPath();
  ctx.moveTo(S * 0.20, S * 0.38 + by);
  ctx.quadraticCurveTo(S * 0.18, S * 0.22 + by, S * 0.27, S * 0.10 + by);
  ctx.quadraticCurveTo(S * 0.37, S * 0.16 + by, S * 0.44, S * 0.24 + by);
  ctx.closePath();
  ctx.fillStyle = coatColor;
  ctx.fill();

  // Inner Left Pink
  ctx.beginPath();
  ctx.moveTo(S * 0.24, S * 0.34 + by);
  ctx.quadraticCurveTo(S * 0.23, S * 0.24 + by, S * 0.28, S * 0.16 + by);
  ctx.quadraticCurveTo(S * 0.36, S * 0.20 + by, S * 0.40, S * 0.26 + by);
  ctx.closePath();
  ctx.fillStyle = pinkColor;
  ctx.fill();

  // Right Ear
  ctx.beginPath();
  ctx.moveTo(S * 0.56, S * 0.24 + by);
  ctx.quadraticCurveTo(S * 0.63, S * 0.16 + by, S * 0.73, S * 0.10 + by);
  ctx.quadraticCurveTo(S * 0.82, S * 0.22 + by, S * 0.80, S * 0.38 + by);
  ctx.closePath();
  ctx.fillStyle = coatColor;
  ctx.fill();

  // Inner Right Pink
  ctx.beginPath();
  ctx.moveTo(S * 0.60, S * 0.26 + by);
  ctx.quadraticCurveTo(S * 0.64, S * 0.20 + by, S * 0.72, S * 0.16 + by);
  ctx.quadraticCurveTo(S * 0.77, S * 0.24 + by, S * 0.76, S * 0.34 + by);
  ctx.closePath();
  ctx.fillStyle = pinkColor;
  ctx.fill();

  // 7. Head
  const headRect = { x: S * 0.18, y: S * 0.20 + by, w: S * 0.64, h: S * 0.46 };
  ctx.beginPath();
  ctx.roundRect(headRect.x, headRect.y, headRect.w, headRect.h, S * 0.22);
  const headGrad = ctx.createRadialGradient(S * 0.46, S * 0.36 + by, S * 0.04, S * 0.46, S * 0.36 + by, S * 0.38);
  headGrad.addColorStop(0, coatHighlight);
  headGrad.addColorStop(0.6, coatColor);
  headGrad.addColorStop(1, coatShadow);
  ctx.fillStyle = headGrad;
  ctx.fill();

  // Tabby Forehead Markings (M crest)
  ctx.strokeStyle = stripeColor;
  ctx.lineWidth = S * 0.032;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(S * 0.40, S * 0.23 + by);
  ctx.quadraticCurveTo(S * 0.45, S * 0.25 + by, S * 0.50, S * 0.32 + by);
  ctx.quadraticCurveTo(S * 0.55, S * 0.25 + by, S * 0.60, S * 0.23 + by);
  ctx.stroke();

  ctx.lineWidth = S * 0.030;
  ctx.beginPath();
  ctx.moveTo(S * 0.50, S * 0.22 + by);
  ctx.lineTo(S * 0.50, S * 0.30 + by);
  ctx.stroke();

  // Snout & Cheeks
  ctx.beginPath();
  ctx.roundRect(S * 0.35, S * 0.43 + by, S * 0.30, S * 0.19, S * 0.095);
  ctx.fillStyle = creamColor;
  ctx.fill();

  // Nose
  const noseCenter = { x: S * 0.50, y: S * 0.47 + by };
  ctx.beginPath();
  ctx.moveTo(noseCenter.x - S * 0.03, noseCenter.y - S * 0.012);
  ctx.lineTo(noseCenter.x + S * 0.03, noseCenter.y - S * 0.012);
  ctx.lineTo(noseCenter.x, noseCenter.y + S * 0.022);
  ctx.closePath();
  ctx.fillStyle = pinkColor;
  ctx.fill();

  // Smiling mouth (ω)
  ctx.strokeStyle = outlineColor;
  ctx.lineWidth = S * 0.02;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(noseCenter.x - S * 0.055, noseCenter.y + S * 0.04);
  ctx.quadraticCurveTo(noseCenter.x - S * 0.028, noseCenter.y + S * 0.07, noseCenter.x, noseCenter.y + S * 0.04);
  ctx.quadraticCurveTo(noseCenter.x + S * 0.028, noseCenter.y + S * 0.07, noseCenter.x + S * 0.055, noseCenter.y + S * 0.04);
  ctx.stroke();

  // Whiskers
  ctx.strokeStyle = stripeColor;
  ctx.lineWidth = S * 0.012;
  ctx.globalAlpha = 0.55;
  // Left whiskers
  ctx.beginPath();
  ctx.moveTo(S * 0.37, S * 0.48 + by);
  ctx.lineTo(S * 0.22, S * 0.455 + by);
  ctx.moveTo(S * 0.37, S * 0.50 + by);
  ctx.lineTo(S * 0.22, S * 0.53 + by);
  // Right whiskers
  ctx.moveTo(S * 0.63, S * 0.48 + by);
  ctx.lineTo(S * 0.78, S * 0.455 + by);
  ctx.moveTo(S * 0.63, S * 0.50 + by);
  ctx.lineTo(S * 0.78, S * 0.53 + by);
  ctx.stroke();
  ctx.globalAlpha = 1.0;

  // 8. Glossy Soulful Eyes
  const eyeL = { x: S * 0.33, y: S * 0.39 + by };
  const eyeR = { x: S * 0.67, y: S * 0.39 + by };
  const eyeW = S * 0.15;
  const eyeH = S * 0.17;

  if (isLoaf) {
    // Closed peaceful sleeping eyes
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = S * 0.035;
    ctx.lineCap = 'round';
    [eyeL, eyeR].forEach((center) => {
      ctx.beginPath();
      ctx.moveTo(center.x - eyeW * 0.5, center.y + eyeH * 0.1);
      ctx.quadraticCurveTo(center.x, center.y - eyeH * 0.45, center.x + eyeW * 0.5, center.y + eyeH * 0.1);
      ctx.stroke();
    });
  } else {
    [eyeL, eyeR].forEach((center) => {
      // Outer dark socket / eyeliner
      ctx.beginPath();
      ctx.ellipse(center.x, center.y, eyeW * 0.5, eyeH * 0.5, 0, 0, Math.PI * 2);
      ctx.fillStyle = outlineColor;
      ctx.fill();

      // Vibrant Iris
      const irisX = center.x + gazeX * 0.4;
      const irisY = center.y + gazeY * 0.4;
      ctx.beginPath();
      ctx.ellipse(irisX, irisY, eyeW * 0.44, eyeH * 0.44, 0, 0, Math.PI * 2);
      const irisGrad = ctx.createRadialGradient(irisX, irisY, S * 0.01, irisX, irisY, eyeW * 0.44);
      irisGrad.addColorStop(0, irisColor);
      irisGrad.addColorStop(0.7, irisDark);
      irisGrad.addColorStop(1, '#000000');
      ctx.fillStyle = irisGrad;
      ctx.fill();

      // Pupil
      const pupilW = eyeW * 0.38;
      const pupilH = eyeH * 0.60;
      ctx.beginPath();
      ctx.ellipse(irisX, irisY, pupilW * 0.5, pupilH * 0.5, 0, 0, Math.PI * 2);
      ctx.fillStyle = '#000000';
      ctx.fill();

      // Specular Catchlights (Iconic glossy gleam)
      ctx.fillStyle = 'rgba(255, 255, 255, 0.95)';
      ctx.beginPath();
      ctx.ellipse(irisX - eyeW * 0.15, irisY - eyeH * 0.15, eyeW * 0.18, eyeH * 0.18, 0, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.beginPath();
      ctx.ellipse(irisX + eyeW * 0.10, irisY + eyeH * 0.12, eyeW * 0.09, eyeH * 0.09, 0, 0, Math.PI * 2);
      ctx.fill();
    });
  }
}

function drawVectorDog(ctx, S, state) {
  const { action, gazeX, gazeY, breath, wag, walkCycle } = state;
  const isLoaf = action === 'loaf' || action === 'sleep';
  const isWalking = action === 'walk';
  const isDelighted = action === 'delighted';

  const coatColor = '#f59e0b';
  const coatHighlight = '#fbbf24';
  const coatShadow = '#b45309';
  const earColor = '#92400e';
  const creamColor = '#fef3c7';
  const noseColor = '#1c1917';
  const tongueColor = '#fb7185';
  const outlineColor = '#451a03';

  const by = breath;

  // 1. Far Hind Leg
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.28, S * 0.78 + by, S * 0.10, S * 0.085, 0, 0, Math.PI * 2);
    ctx.fillStyle = coatShadow;
    ctx.fill();

    ctx.beginPath();
    ctx.roundRect(S * 0.14, S * 0.81 + by, S * 0.14, S * 0.10, S * 0.05);
    ctx.fillStyle = creamColor;
    ctx.fill();
  }

  // 2. Wagging Tail
  ctx.beginPath();
  ctx.moveTo(S * 0.68, S * 0.72 + by);
  ctx.quadraticCurveTo(S * 0.85, S * 0.60 + by, S * 0.88 + wag, S * 0.38 + by);
  ctx.strokeStyle = coatColor;
  ctx.lineWidth = S * 0.12;
  ctx.lineCap = 'round';
  ctx.stroke();

  // 3. Torso
  ctx.beginPath();
  if (isLoaf) {
    ctx.roundRect(S * 0.20, S * 0.56 + by, S * 0.60, S * 0.30, S * 0.15);
  } else {
    ctx.moveTo(S * 0.34, S * 0.50 + by);
    ctx.lineTo(S * 0.66, S * 0.50 + by);
    ctx.quadraticCurveTo(S * 0.77, S * 0.68 + by, S * 0.75, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.50, S * 0.88 + by, S * 0.25, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.23, S * 0.68 + by, S * 0.34, S * 0.50 + by);
    ctx.closePath();
  }
  const bodyGrad = ctx.createLinearGradient(0, S * 0.48 + by, 0, S * 0.88 + by);
  bodyGrad.addColorStop(0, coatHighlight);
  bodyGrad.addColorStop(0.5, coatColor);
  bodyGrad.addColorStop(1, coatShadow);
  ctx.fillStyle = bodyGrad;
  ctx.fill();

  // Cream Chest
  ctx.beginPath();
  ctx.moveTo(S * 0.38, S * 0.52 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.54 + by, S * 0.62, S * 0.52 + by);
  ctx.quadraticCurveTo(S * 0.65, S * 0.68 + by, S * 0.64, S * 0.80 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.84 + by, S * 0.36, S * 0.80 + by);
  ctx.closePath();
  ctx.fillStyle = creamColor;
  ctx.fill();

  // 4. Near Hind Haunch & Paw
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.69, S * 0.75 + by, S * 0.11, S * 0.09, 0, 0, Math.PI * 2);
    ctx.fillStyle = coatHighlight;
    ctx.fill();

    ctx.beginPath();
    ctx.roundRect(S * 0.66, S * 0.80 + by, S * 0.14, S * 0.10, S * 0.05);
    ctx.fillStyle = creamColor;
    ctx.fill();
  }

  // 5. Forelegs & Front Paws
  const pawW = S * 0.16;
  const pawH = S * 0.13;
  ctx.strokeStyle = coatColor;
  ctx.lineWidth = S * 0.11;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(S * 0.38, S * 0.54 + by);
  ctx.lineTo(S * 0.38, S * 0.78 + by);
  ctx.moveTo(S * 0.62, S * 0.54 + by);
  ctx.lineTo(S * 0.60, S * 0.78 + by);
  ctx.stroke();

  ctx.fillStyle = creamColor;
  ctx.beginPath();
  ctx.roundRect(S * 0.31, S * 0.79 + by, pawW, pawH, pawH * 0.5);
  ctx.roundRect(S * 0.53, S * 0.79 + by, pawW, pawH, pawH * 0.5);
  ctx.fill();

  // 6. Floppy Puppy Ears (hang down on both sides)
  // Left ear
  ctx.beginPath();
  ctx.moveTo(S * 0.26, S * 0.24 + by);
  ctx.quadraticCurveTo(S * 0.10, S * 0.30 + by, S * 0.12, S * 0.48 + by);
  ctx.quadraticCurveTo(S * 0.16, S * 0.56 + by, S * 0.24, S * 0.52 + by);
  ctx.quadraticCurveTo(S * 0.26, S * 0.44 + by, S * 0.28, S * 0.36 + by);
  ctx.closePath();
  ctx.fillStyle = earColor;
  ctx.fill();

  // Right ear
  ctx.beginPath();
  ctx.moveTo(S * 0.74, S * 0.24 + by);
  ctx.quadraticCurveTo(S * 0.90, S * 0.30 + by, S * 0.88, S * 0.48 + by);
  ctx.quadraticCurveTo(S * 0.84, S * 0.56 + by, S * 0.76, S * 0.52 + by);
  ctx.quadraticCurveTo(S * 0.74, S * 0.44 + by, S * 0.72, S * 0.36 + by);
  ctx.closePath();
  ctx.fillStyle = earColor;
  ctx.fill();

  // 7. Head
  ctx.beginPath();
  ctx.roundRect(S * 0.20, S * 0.19 + by, S * 0.60, S * 0.46, S * 0.22);
  const headGrad = ctx.createRadialGradient(S * 0.48, S * 0.35 + by, S * 0.04, S * 0.48, S * 0.35 + by, S * 0.36);
  headGrad.addColorStop(0, coatHighlight);
  headGrad.addColorStop(0.6, coatColor);
  headGrad.addColorStop(1, coatShadow);
  ctx.fillStyle = headGrad;
  ctx.fill();

  // Muzzle & Snout
  ctx.beginPath();
  ctx.roundRect(S * 0.34, S * 0.41 + by, S * 0.32, S * 0.21, S * 0.10);
  ctx.fillStyle = creamColor;
  ctx.fill();

  // Nose
  ctx.beginPath();
  ctx.roundRect(S * 0.45, S * 0.43 + by, S * 0.10, S * 0.07, S * 0.035);
  ctx.fillStyle = noseColor;
  ctx.fill();

  // Nose glint
  ctx.beginPath();
  ctx.ellipse(S * 0.485, S * 0.45 + by, S * 0.015, S * 0.01, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
  ctx.fill();

  // Tongue & Happy Mouth
  ctx.beginPath();
  ctx.roundRect(S * 0.47, S * 0.53 + by, S * 0.06, S * 0.07, S * 0.03);
  ctx.fillStyle = tongueColor;
  ctx.fill();

  ctx.strokeStyle = outlineColor;
  ctx.lineWidth = S * 0.02;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(S * 0.43, S * 0.51 + by);
  ctx.quadraticCurveTo(S * 0.465, S * 0.54 + by, S * 0.50, S * 0.51 + by);
  ctx.quadraticCurveTo(S * 0.535, S * 0.54 + by, S * 0.57, S * 0.51 + by);
  ctx.stroke();

  // Warm Puppy Eyes
  const eyeL = { x: S * 0.34, y: S * 0.36 + by };
  const eyeR = { x: S * 0.66, y: S * 0.36 + by };
  const eyeW = S * 0.15;
  const eyeH = S * 0.16;

  [eyeL, eyeR].forEach((center) => {
    ctx.beginPath();
    ctx.ellipse(center.x, center.y, eyeW * 0.5, eyeH * 0.5, 0, 0, Math.PI * 2);
    ctx.fillStyle = outlineColor;
    ctx.fill();

    const irisX = center.x + gazeX * 0.4;
    const irisY = center.y + gazeY * 0.4;
    ctx.beginPath();
    ctx.ellipse(irisX, irisY, eyeW * 0.44, eyeH * 0.44, 0, 0, Math.PI * 2);
    const irisGrad = ctx.createRadialGradient(irisX, irisY, S * 0.01, irisX, irisY, eyeW * 0.44);
    irisGrad.addColorStop(0, '#a16207');
    irisGrad.addColorStop(0.7, '#713f12');
    irisGrad.addColorStop(1, '#000000');
    ctx.fillStyle = irisGrad;
    ctx.fill();

    ctx.beginPath();
    ctx.ellipse(irisX, irisY, eyeW * 0.22, eyeH * 0.26, 0, 0, Math.PI * 2);
    ctx.fillStyle = '#000000';
    ctx.fill();

    // Specular Catchlights
    ctx.fillStyle = 'rgba(255, 255, 255, 0.95)';
    ctx.beginPath();
    ctx.ellipse(irisX - eyeW * 0.14, irisY - eyeH * 0.16, eyeW * 0.18, eyeH * 0.18, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
    ctx.beginPath();
    ctx.ellipse(irisX + eyeW * 0.10, irisY + eyeH * 0.12, eyeW * 0.09, eyeH * 0.09, 0, 0, Math.PI * 2);
    ctx.fill();
  });
}

function drawVectorPanda(ctx, S, state) {
  const { action, gazeX, gazeY, breath } = state;
  const isLoaf = action === 'loaf' || action === 'sleep';

  const whiteColor = '#f8fafc';
  const whiteShadow = '#cbd5e1';
  const blackColor = '#1e293b';
  const blackHighlight = '#334155';
  const pinkColor = '#f472b6';
  const outlineColor = '#0f172a';

  const by = breath;

  // 1. Far Hind Leg
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.29, S * 0.78 + by, S * 0.11, S * 0.09, 0, 0, Math.PI * 2);
    ctx.fillStyle = blackColor;
    ctx.fill();
  }

  // 2. Tail Nub
  ctx.beginPath();
  ctx.ellipse(S * 0.73, S * 0.79 + by, S * 0.055, S * 0.05, 0, 0, Math.PI * 2);
  ctx.fillStyle = blackColor;
  ctx.fill();

  // 3. Torso (Black shoulder vest + white belly)
  ctx.beginPath();
  if (isLoaf) {
    ctx.roundRect(S * 0.20, S * 0.56 + by, S * 0.60, S * 0.30, S * 0.15);
  } else {
    ctx.moveTo(S * 0.34, S * 0.50 + by);
    ctx.lineTo(S * 0.66, S * 0.50 + by);
    ctx.quadraticCurveTo(S * 0.77, S * 0.68 + by, S * 0.75, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.50, S * 0.88 + by, S * 0.25, S * 0.84 + by);
    ctx.quadraticCurveTo(S * 0.23, S * 0.68 + by, S * 0.34, S * 0.50 + by);
    ctx.closePath();
  }
  const bodyGrad = ctx.createLinearGradient(0, S * 0.48 + by, 0, S * 0.70 + by);
  bodyGrad.addColorStop(0, blackHighlight);
  bodyGrad.addColorStop(1, blackColor);
  ctx.fillStyle = bodyGrad;
  ctx.fill();

  // White belly
  ctx.beginPath();
  ctx.moveTo(S * 0.36, S * 0.60 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.58 + by, S * 0.64, S * 0.60 + by);
  ctx.quadraticCurveTo(S * 0.70, S * 0.74 + by, S * 0.68, S * 0.84 + by);
  ctx.quadraticCurveTo(S * 0.50, S * 0.88 + by, S * 0.32, S * 0.84 + by);
  ctx.closePath();
  const bellyGrad = ctx.createLinearGradient(0, S * 0.60 + by, 0, S * 0.86 + by);
  bellyGrad.addColorStop(0, whiteColor);
  bellyGrad.addColorStop(1, whiteShadow);
  ctx.fillStyle = bellyGrad;
  ctx.fill();

  // 4. Near Hind Haunch & Paw
  if (!isLoaf) {
    ctx.beginPath();
    ctx.ellipse(S * 0.69, S * 0.75 + by, S * 0.11, S * 0.09, 0, 0, Math.PI * 2);
    ctx.fillStyle = blackColor;
    ctx.fill();

    // Pink hind pad
    ctx.fillStyle = pinkColor;
    ctx.beginPath();
    ctx.ellipse(S * 0.67, S * 0.80 + by, S * 0.035, S * 0.03, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  // 5. Forelegs & Front Paws with Pink Pads
  const pawW = S * 0.17;
  const pawH = S * 0.14;

  ctx.strokeStyle = blackColor;
  ctx.lineWidth = S * 0.12;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(S * 0.38, S * 0.54 + by);
  ctx.lineTo(S * 0.36, S * 0.78 + by);
  ctx.moveTo(S * 0.62, S * 0.54 + by);
  ctx.lineTo(S * 0.60, S * 0.78 + by);
  ctx.stroke();

  ctx.fillStyle = blackColor;
  ctx.beginPath();
  ctx.roundRect(S * 0.30, S * 0.79 + by, pawW, pawH, pawH * 0.5);
  ctx.roundRect(S * 0.53, S * 0.79 + by, pawW, pawH, pawH * 0.5);
  ctx.fill();

  // Cute pink toe bean pads
  ctx.fillStyle = pinkColor;
  ctx.beginPath();
  ctx.ellipse(S * 0.30 + pawW * 0.5, S * 0.79 + by + pawH * 0.5, pawW * 0.25, pawH * 0.2, 0, 0, Math.PI * 2);
  ctx.ellipse(S * 0.53 + pawW * 0.5, S * 0.79 + by + pawH * 0.5, pawW * 0.25, pawH * 0.2, 0, 0, Math.PI * 2);
  ctx.fill();

  // 6. Round Black Ears
  ctx.fillStyle = blackColor;
  ctx.beginPath();
  ctx.ellipse(S * 0.28, S * 0.22 + by, S * 0.10, S * 0.10, 0, 0, Math.PI * 2);
  ctx.ellipse(S * 0.72, S * 0.22 + by, S * 0.10, S * 0.10, 0, 0, Math.PI * 2);
  ctx.fill();

  // 7. Head
  ctx.beginPath();
  ctx.roundRect(S * 0.18, S * 0.20 + by, S * 0.64, S * 0.46, S * 0.23);
  const headGrad = ctx.createRadialGradient(S * 0.48, S * 0.36 + by, S * 0.04, S * 0.48, S * 0.36 + by, S * 0.36);
  headGrad.addColorStop(0, whiteColor);
  headGrad.addColorStop(1, whiteShadow);
  ctx.fillStyle = headGrad;
  ctx.fill();

  // 8. Classic Panda Eye Patches (Angled soft black teardrops)
  ctx.fillStyle = blackColor;
  ctx.beginPath();
  ctx.ellipse(S * 0.35, S * 0.43 + by, S * 0.09, S * 0.11, -0.2, 0, Math.PI * 2);
  ctx.ellipse(S * 0.65, S * 0.43 + by, S * 0.09, S * 0.11, 0.2, 0, Math.PI * 2);
  ctx.fill();

  // Snout & Nose
  ctx.beginPath();
  ctx.roundRect(S * 0.45, S * 0.46 + by, S * 0.10, S * 0.07, S * 0.035);
  ctx.fillStyle = blackColor;
  ctx.fill();

  // Cute panda smile
  ctx.strokeStyle = outlineColor;
  ctx.lineWidth = S * 0.02;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(S * 0.44, S * 0.54 + by);
  ctx.quadraticCurveTo(S * 0.47, S * 0.57 + by, S * 0.50, S * 0.54 + by);
  ctx.quadraticCurveTo(S * 0.53, S * 0.57 + by, S * 0.56, S * 0.54 + by);
  ctx.stroke();

  // Sparkling Eyes inside patches
  const eyeL = { x: S * 0.35, y: S * 0.42 + by };
  const eyeR = { x: S * 0.65, y: S * 0.42 + by };
  const eyeW = S * 0.12;
  const eyeH = S * 0.13;

  [eyeL, eyeR].forEach((center) => {
    const irisX = center.x + gazeX * 0.3;
    const irisY = center.y + gazeY * 0.3;

    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.ellipse(irisX, irisY, eyeW * 0.5, eyeH * 0.5, 0, 0, Math.PI * 2);
    ctx.fill();

    // Catchlights
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.ellipse(irisX - eyeW * 0.14, irisY - eyeH * 0.16, eyeW * 0.19, eyeH * 0.19, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
    ctx.beginPath();
    ctx.ellipse(irisX + eyeW * 0.10, irisY + eyeH * 0.12, eyeW * 0.10, eyeH * 0.10, 0, 0, Math.PI * 2);
    ctx.fill();
  });
}
