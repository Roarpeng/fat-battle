import { motion } from 'framer-motion';
import type { MonsterAnimationProps } from './types';

export function MonsterAnimation({ emoji, isShaking, isHit, isDead, hpPercentage }: MonsterAnimationProps) {
  const getEmotionEmoji = () => {
    if (isDead) return '💀';
    if (hpPercentage < 0.2) return '😵';
    if (hpPercentage < 0.4) return '😫';
    if (hpPercentage < 0.6) return '😠';
    if (hpPercentage < 0.8) return '😏';
    return '😈';
  };
  return (
    <motion.div
      animate={
        isDead
          ? { scale: [1, 0.8, 0], rotate: [0, -10, 10, -90], opacity: [1, 1, 0] }
          : isHit
          ? { x: [-10, 10, -8, 8, -5, 5, 0], scale: [1, 0.9, 1.1, 1], rotate: [0, -5, 5, 0] }
          : isShaking
          ? { y: [0, -8, 0] }
          : {}
      }
      transition={
        isDead
          ? { duration: 1.5, ease: 'easeIn' }
          : isHit
          ? { duration: 0.5 }
          : isShaking
          ? { duration: 2.5, repeat: Infinity, ease: 'easeInOut' }
          : {}
      }
      className="relative"
    >
      <motion.div
        animate={{ scale: [1, 1.05, 1] }}
        transition={{ duration: 3, repeat: Infinity }}
        className="text-8xl md:text-9xl select-none"
      >
        {emoji}
      </motion.div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: isHit ? 1 : 0 }}
        transition={{ duration: 0.3 }}
        className="absolute inset-0 flex items-center justify-center pointer-events-none"
      >
        <div className="text-4xl">💥</div>
      </motion.div>

      {hpPercentage < 0.5 && (
        <motion.div
          animate={{ opacity: [0.3, 0.8, 0.3] }}
          transition={{ duration: 1, repeat: Infinity }}
          className="absolute -top-2 -right-2 text-2xl"
        >
          {getEmotionEmoji()}
        </motion.div>
      )}

      {hpPercentage < 0.3 && (
        <motion.div
          animate={{ opacity: [0.5, 1, 0.5] }}
          transition={{ duration: 0.5, repeat: Infinity }}
          className="absolute inset-0 flex items-center justify-center pointer-events-none"
        >
          <div className="text-6xl opacity-50">🩸</div>
        </motion.div>
      )}
    </motion.div>
  );
}
