import { motion } from 'framer-motion';
import type { VictoryEffectProps } from './types';

export function VictoryEffect({ onComplete }: VictoryEffectProps) {
  const coinRain = Array.from({ length: 30 }, (_, i) => ({
    id: i,
    left: Math.random() * 100,
    delay: Math.random() * 2,
    duration: 2 + Math.random() * 2,
    size: 20 + Math.random() * 20,
  }));
  const starBurst = Array.from({ length: 12 }, (_, i) => ({
    id: i,
    angle: (i * 30) * (Math.PI / 180),
  }));
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm"
    >
      {coinRain.map((coin) => (
        <motion.div
          key={coin.id}
          initial={{ y: -100, rotate: 0, opacity: 0 }}
          animate={{ y: '100vh', rotate: 720, opacity: 1 }}
          transition={{ duration: coin.duration, delay: coin.delay, repeat: Infinity, ease: 'linear' }}
          className="absolute text-4xl"
          style={{ left: `${coin.left}%`, fontSize: coin.size }}
        >
          🪙
        </motion.div>
      ))}

      {starBurst.map((star) => (
        <motion.div
          key={star.id}
          initial={{ scale: 0, opacity: 0, x: 0, y: 0 }}
          animate={{ scale: [0, 1.5, 0], opacity: [0, 1, 0], x: Math.cos(star.angle) * 200, y: Math.sin(star.angle) * 200 }}
          transition={{ duration: 1.5, delay: star.id * 0.1, repeat: Infinity, repeatDelay: 2 }}
          className="absolute text-2xl"
        >
          ⭐
        </motion.div>
      ))}

      <motion.div
        initial={{ scale: 0, opacity: 0, rotate: -180 }}
        animate={{ scale: 1, opacity: 1, rotate: 0 }}
        transition={{ type: 'spring', stiffness: 200, damping: 15, delay: 0.3 }}
        className="relative z-10"
      >
        <motion.div
          animate={{ rotate: [0, 10, -10, 0], scale: [1, 1.1, 1] }}
          transition={{ duration: 1, repeat: Infinity, repeatDelay: 1 }}
          className="text-8xl mb-4"
        >
          🏆
        </motion.div>

        <motion.h2
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.5 }}
          className="text-4xl font-black mb-2 bg-gradient-to-r from-gold via-orange to-gold bg-clip-text text-transparent text-center"
        >
          胜利！
        </motion.h2>

        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.6 }}
          className="text-center"
        >
          <motion.div
            animate={{ scale: [1, 1.2, 1] }}
            transition={{ duration: 0.5, repeat: Infinity }}
            className="text-6xl"
          >
            🎉
          </motion.div>
        </motion.div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: [0, 0.5, 0] }}
        transition={{ duration: 2, repeat: Infinity }}
        className="absolute inset-0 bg-gradient-radial from-gold/20 via-transparent to-transparent"
      />
    </motion.div>
  );
}
