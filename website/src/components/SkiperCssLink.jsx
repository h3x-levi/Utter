import React from 'react';

export default function SkiperCssLink({ children, href = "#", className = "", target, rel, onClick }) {
  return (
    <a
      href={href}
      target={target}
      rel={rel}
      onClick={onClick}
      className={`group relative inline-flex items-center text-white/70 hover:text-white transition-colors duration-300 font-medium ${className}`}
    >
      <span className="relative z-10">{children}</span>
      <span className="absolute -bottom-0.5 left-0 h-[1px] w-0 bg-indigo-400 transition-all duration-300 ease-out group-hover:w-full" />
    </a>
  );
}
