import React from 'react';

export default function CurvedLoop({
  text = "100% ON-DEVICE DICTATION · LOCAL WHISPER · APPLE METAL GPU · ZERO TELEMETRY · 180 WPM · "
}) {
  return (
    <div className="relative w-full overflow-hidden py-12 pointer-events-none opacity-40 select-none">
      <svg
        viewBox="0 0 1200 160"
        className="w-full text-white/40 fill-current"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          id="textCurve"
          d="M 0,90 Q 300,150 600,90 T 1200,90"
          fill="none"
          stroke="transparent"
        />
        <text className="font-mono text-xs sm:text-sm font-semibold tracking-[0.25em] uppercase">
          <textPath href="#textCurve" startOffset="0%">
            <animate
              attributeName="startOffset"
              from="0%"
              to="-100%"
              begin="0s"
              dur="24s"
              repeatCount="indefinite"
            />
            {text.repeat(4)}
          </textPath>
        </text>
      </svg>
    </div>
  );
}
