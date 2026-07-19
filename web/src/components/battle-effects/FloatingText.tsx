import { motion } from 'framer-motion';
import type { FloatingTextProps } from './types';

export function FloatingText({ id, text, type }: FloatingTextProps) {
  const bgColors = {
    encouragement: 'bg-green/90 border-green',
    taunt: 'bg-red/90 border-red',
    system: 'bg-purple/90 border-purple',
  };
  const textColors = {
    encouragement: 'text-white',
    taunt: 'text-white',
    system: 'text-white',
  };
  const icons = {
    encouragement: '✨',
    taunt: '💬',
    system: '📢',
  };
  return (
    <motion.div
      key={id}
      initial={{ opacity: 0, y: 20, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -20, scale: 0.9 }}
      transition={{ type: 'spring', stiffness: 300, damping: 20 }}
      className="absolute z-30 w-[90%] max-w-xs"
    >
      <div className={`relative ${bgColors[type]} border-2 rounded-xl px-4 py-2 shadow-lg`}>
        <div className={`text-sm font-bold ${textColors[type]} text-center leading-snug flex items-center justify-center gap-2`}>
          <span>{icons[type]}</span>
          <span>{text}</span>
        </div>
        <div className={`absolute -bottom-2 left-1/2 -translate-x-1/2 w-4 h-4 ${bgColors[type].split('/')[0]} border-r-2 border-b-2 rotate-45`} />
      </div>
    </motion.div>
  );
}
