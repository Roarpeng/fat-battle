import { motion } from 'framer-motion';
import type { EnergyShieldProps } from './types';

export function EnergyShield({ overeatCalories, maxCalories = 1000 }: EnergyShieldProps) {
  const density = Math.min(1, overeatCalories / maxCalories);
  const bubbleCount = Math.floor(density * 15) + 3;

  return (
    <div className="absolute inset-0 pointer-events-none overflow-hidden">
      {Array.from({ length: bubbleCount }).map((_, i) => {
        const size = 10 + Math.random() * 30;
        const left = 10 + Math.random() * 80;
        const delay = Math.random() * 3;
        const duration = 3 + Math.random() * 3;
        return (
          <motion.div
            key={i}
            animate={{
              y: ['110%', '-10%'],
              x: [0, (Math.random() - 0.5) * 40, 0],
              opacity: [0.3, 0.8, 0.3],
              scale: [0.8, 1.2, 0.8],
            }}
            transition={{
              duration,
              delay,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
            className="absolute rounded-full"
            style={{
              width: size,
              height: size,
              left: `${left}%`,
              background: 'radial-gradient(circle, rgba(255,215,0,0.6) 0%, rgba(193,154,107,0.3) 50%, transparent 100%)',
              boxShadow: '0 0 10px rgba(255,215,0,0.5)',
            }}
          />
        );
      })}

      <motion.div
        animate={{
          opacity: [0.2, 0.4, 0.2],
          scale: [1, 1.05, 1],
        }}
        transition={{
          duration: 3,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          width: '280px',
          height: '280px',
          border: `3px solid rgba(255,215,0,${0.3 + density * 0.4})`,
          borderRadius: '50%',
          boxShadow: `0 0 30px rgba(255,215,0,${0.2 + density * 0.3}), inset 0 0 30px rgba(255,215,0,${0.1 + density * 0.2})`,
        }}
      />

      <motion.div
        animate={{
          opacity: [0.1, 0.25, 0.1],
          scale: [1.1, 1.15, 1.1],
        }}
        transition={{
          duration: 4,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          width: '320px',
          height: '320px',
          border: `2px dashed rgba(218,165,32,${0.2 + density * 0.3})`,
          borderRadius: '50%',
        }}
      />

      <motion.div
        animate={{
          rotate: 360,
        }}
        transition={{
          duration: 20,
          repeat: Infinity,
          ease: 'linear',
        }}
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
        style={{
          width: '300px',
          height: '300px',
        }}
      >
        {Array.from({ length: 8 }).map((_, i) => {
          const angle = (i * 45) * (Math.PI / 180);
          const x = Math.cos(angle) * 140;
          const y = Math.sin(angle) * 140;
          return (
            <motion.div
              key={i}
              animate={{
                scale: [0.8, 1.2, 0.8],
                opacity: [0.4, 0.8, 0.4],
              }}
              transition={{
                duration: 2,
                delay: i * 0.25,
                repeat: Infinity,
              }}
              className="absolute w-3 h-3 rounded-full"
              style={{
                left: '50%',
                top: '50%',
                transform: `translate(-50%, -50%) translate(${x}px, ${y}px)`,
                background: 'rgba(255,215,0,0.6)',
                boxShadow: '0 0 8px rgba(255,215,0,0.8)',
              }}
            />
          );
        })}
      </motion.div>
    </div>
  );
}
