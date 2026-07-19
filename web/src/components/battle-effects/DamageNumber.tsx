import { motion } from 'framer-motion';
import type { DamageNumberProps } from './types';

export function DamageNumber({ id, value, type, x = 0, y = 0 }: DamageNumberProps) {
  const colors = {
    damage: 'text-red',
    heal: 'text-green',
    critical: 'text-gold',
  };
  const scales = {
    damage: 1,
    heal: 1,
    critical: 1.5,
  };
  const texts = {
    damage: '-',
    heal: '+',
    critical: '暴击! -',
  };
  return (
    <motion.div
      key={id}
      initial={{ opacity: 1, y: 0, scale: 0.5, x }}
      animate={{ opacity: 0, y: -80, scale: scales[type], x: x + (Math.random() - 0.5) * 40 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 1, ease: 'easeOut' }}
      className={`absolute top-1/2 left-1/2 -translate-x-1/2 pointer-events-none font-black ${colors[type]}`}
      style={{
        fontSize: type === 'critical' ? '28px' : '24px',
        textShadow: type === 'critical' ? '0 0 20px rgba(255,217,61,0.8)' : '0 0 10px rgba(0,0,0,0.5)',
      }}
    >
      {texts[type]}{value}
    </motion.div>
  );
}
