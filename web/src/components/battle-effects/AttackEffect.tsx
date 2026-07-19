import { motion } from 'framer-motion';
import type { AttackEffectProps } from './types';

export function AttackEffect({ id, type, damage, isOvereat }: AttackEffectProps) {
  if (type === 'grease') {
    return (
      <motion.div
        key={id}
        initial={{ y: -200, opacity: 0, scale: 0.5 }}
        animate={{ y: 0, opacity: 1, scale: 1.5 }}
        exit={{ opacity: 0, scale: 2 }}
        transition={{ duration: 0.8, ease: 'easeOut' }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-7xl z-30 pointer-events-none"
      >
        🛢️
      </motion.div>
    );
  }

  const icons: Record<string, string> = {
    missile: '🚀',
    knife: '🗡️',
    punch: '👊',
    fireball: '🔥',
    lightning: '⚡',
    bomb: '💣',
  };
  const labels: Record<string, string> = {
    missile: '导弹出击！',
    knife: '飞刀连射！',
    punch: '重拳出击！',
    fireball: '烈焰风暴！',
    lightning: '雷霆万钧！',
    bomb: '炸弹爆炸！',
  };
  const colors: Record<string, string> = {
    missile: 'bg-blue',
    knife: 'bg-gray',
    punch: 'bg-orange',
    fireball: 'bg-red',
    lightning: 'bg-yellow',
    bomb: 'bg-purple',
  };

  if (type === 'bomb') {
    return (
      <div key={id} className="absolute inset-0 pointer-events-none z-30">
        <motion.div
          initial={{ x: -150, y: 50, opacity: 0, scale: 0.5 }}
          animate={{ x: 0, y: 0, opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 2, x: 50 }}
          transition={{ duration: 0.4, ease: 'easeIn' }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-6xl"
        >
          💣
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0 }}
          transition={{ delay: 0.2 }}
          className={`absolute top-4 left-1/2 -translate-x-1/2 ${colors[type]}/90 text-white text-xs font-bold px-3 py-1 rounded-full whitespace-nowrap`}
        >
          {labels[type]} -{damage}
        </motion.div>

        <motion.div
          initial={{ scale: 0, opacity: 1 }}
          animate={{ scale: 6, opacity: 0 }}
          transition={{ delay: 0.4, duration: 0.6 }}
          className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-32 h-32 rounded-full ${colors[type]}/40 blur-xl`}
        />

        <motion.div
          initial={{ scale: 0, opacity: 1 }}
          animate={{ scale: 4, opacity: 0 }}
          transition={{ delay: 0.4, duration: 0.4 }}
          className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-20 h-20 rounded-full ${colors[type]}/60`}
        />

        {Array.from({ length: 8 }).map((_, i) => (
          <motion.div
            key={`shard-${i}`}
            initial={{ scale: 0, opacity: 1, x: 0, y: 0 }}
            animate={{
              scale: [0, 1, 0],
              opacity: [1, 1, 0],
              x: Math.cos((i * 45) * (Math.PI / 180)) * 100,
              y: Math.sin((i * 45) * (Math.PI / 180)) * 100,
            }}
            transition={{ delay: 0.35, duration: 0.5 }}
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-yellow"
          />
        ))}
      </div>
    );
  }

  return (
    <div key={id} className="absolute inset-0 pointer-events-none z-30">
      <motion.div
        initial={{ x: -150, y: 50, opacity: 0, rotate: -45, scale: 0.5 }}
        animate={{ x: 0, y: 0, opacity: 1, rotate: 0, scale: 1 }}
        exit={{ opacity: 0, scale: 2, x: 50 }}
        transition={{ duration: 0.4, ease: 'easeIn' }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-6xl"
      >
        {icons[type]}
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        transition={{ delay: 0.2 }}
        className={`absolute top-4 left-1/2 -translate-x-1/2 ${colors[type]}/90 text-white text-xs font-bold px-3 py-1 rounded-full whitespace-nowrap`}
      >
        {labels[type]} -{damage}
      </motion.div>

      <motion.div
        initial={{ scale: 0, opacity: 1 }}
        animate={{ scale: 4, opacity: 0 }}
        transition={{ delay: 0.4, duration: 0.5 }}
        className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-24 h-24 rounded-full ${colors[type]}/30 blur-lg`}
      />

      <motion.div
        initial={{ scale: 0, opacity: 1 }}
        animate={{ scale: 3, opacity: 0 }}
        transition={{ delay: 0.4, duration: 0.3 }}
        className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-16 h-16 rounded-full ${colors[type]}/50`}
      />
    </div>
  );
}
