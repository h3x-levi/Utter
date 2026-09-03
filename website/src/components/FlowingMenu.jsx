import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

export default function FlowingMenu({ items = [], onSelect }) {
  const [hoveredIndex, setHoveredIndex] = useState(null);

  return (
    <div className="flex items-center gap-6">
      {items.map((item, idx) => (
        <div
          key={item.label}
          className="relative cursor-pointer py-1 text-sm font-medium"
          onMouseEnter={() => setHoveredIndex(idx)}
          onMouseLeave={() => setHoveredIndex(null)}
          onClick={() => onSelect?.(idx)}
        >
          <span className="relative z-10 text-white/70 hover:text-white transition-colors duration-200">
            {item.label}
          </span>

          <AnimatePresence>
            {hoveredIndex === idx && (
              <motion.span
                layoutId="flowingMenuGlow"
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                transition={{ duration: 0.2 }}
                className="absolute inset-0 -z-10 rounded-full bg-white/10 blur-sm px-3 -mx-1"
              />
            )}
          </AnimatePresence>
        </div>
      ))}
    </div>
  );
}
