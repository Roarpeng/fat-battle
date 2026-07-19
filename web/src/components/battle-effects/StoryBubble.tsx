import { useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { StoryBubbleProps } from './types';

export function StoryBubble({ text, visible, type, onClose }: StoryBubbleProps) {
  const styles = {
    encounter: {
      border: 'border-blue',
      bg: 'bg-blue/10',
      text: 'text-blue',
      shadow: 'shadow-blue/20',
      icon: '🔵',
    },
    phaseChange: {
      border: 'border-purple',
      bg: 'bg-purple/10',
      text: 'text-purple',
      shadow: 'shadow-purple/20',
      icon: '✨',
    },
    enrage: {
      border: 'border-red',
      bg: 'bg-red/15',
      text: 'text-red',
      shadow: 'shadow-red/30',
      icon: '🔥',
    },
    defeat: {
      border: 'border-gold',
      bg: 'bg-gold/10',
      text: 'text-gold',
      shadow: 'shadow-gold/20',
      icon: '🎉',
    },
  };

  const s = styles[type];

  useEffect(() => {
    if (!visible) return;
    const timer = setTimeout(() => {
      onClose();
    }, 5000);
    return () => clearTimeout(timer);
  }, [visible, onClose]);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: 20, scale: 0.8 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: -20, scale: 0.8 }}
          transition={{ type: 'spring', stiffness: 400, damping: 25 }}
          className="absolute -top-4 left-1/2 -translate-x-1/2 z-40 w-[90%] max-w-xs"
          onClick={onClose}
        >
          <div
            className={`relative ${s.bg} border-2 ${s.border} ${s.shadow} rounded-2xl px-4 py-3 shadow-lg cursor-pointer`}
          >
            <div className={`text-sm font-bold ${s.text} text-center leading-snug flex items-center justify-center gap-2`}>
              <motion.span
                animate={type === 'enrage' ? { x: [-2, 2, -2, 0] } : {}}
                transition={{ duration: 0.3, repeat: Infinity }}
              >
                {s.icon}
              </motion.span>
              <span>{text}</span>
            </div>
            {/* 小三角箭头 */}
            <div className={`absolute -bottom-2 left-1/2 -translate-x-1/2 w-3 h-3 ${s.bg} border-r-2 border-b-2 ${s.border} rotate-45`} />
            {/* 闪光特效 - phaseChange */}
            {type === 'phaseChange' && (
              <motion.div
                className="absolute inset-0 rounded-2xl pointer-events-none"
                animate={{ opacity: [0, 0.5, 0] }}
                transition={{ duration: 1.5, repeat: Infinity }}
                style={{
                  boxShadow: 'inset 0 0 20px rgba(168,85,247,0.4)',
                }}
              />
            )}
            {/* 红色闪烁 - enrage */}
            {type === 'enrage' && (
              <motion.div
                className="absolute inset-0 rounded-2xl pointer-events-none"
                animate={{ opacity: [0, 0.3, 0] }}
                transition={{ duration: 0.8, repeat: Infinity }}
                style={{
                  boxShadow: 'inset 0 0 25px rgba(239,68,68,0.6)',
                }}
              />
            )}
            {/* 庆祝烟花 - defeat */}
            {type === 'defeat' && (
              <>
                {Array.from({ length: 6 }).map((_, i) => (
                  <motion.div
                    key={i}
                    className="absolute text-lg pointer-events-none"
                    initial={{ scale: 0, opacity: 1, x: 0, y: 0 }}
                    animate={{
                      scale: [0, 1, 0],
                      opacity: [1, 1, 0],
                      x: Math.cos((i * 60) * (Math.PI / 180)) * 40,
                      y: Math.sin((i * 60) * (Math.PI / 180)) * 40,
                    }}
                    transition={{ duration: 1, delay: i * 0.1, repeat: Infinity, repeatDelay: 1 }}
                    style={{ left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}
                  >
                    🎊
                  </motion.div>
                ))}
              </>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
