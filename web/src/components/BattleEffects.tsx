import { motion, AnimatePresence } from 'framer-motion';

interface DamageNumberProps {
  id: string;
  value: number;
  type: 'damage' | 'heal' | 'critical';
  x?: number;
  y?: number;
}

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

interface FloatingTextProps {
  id: string;
  text: string;
  type: 'encouragement' | 'taunt' | 'system';
}

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

interface AttackEffectProps {
  id: string;
  type: 'missile' | 'knife' | 'punch' | 'fireball' | 'lightning' | 'grease' | 'bomb';
  damage: number;
  isOvereat?: boolean;
}

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

interface MonsterAnimationProps {
  emoji: string;
  isShaking?: boolean;
  isHit?: boolean;
  isDead?: boolean;
  hpPercentage: number;
}

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

interface EnergyShieldProps {
  overeatCalories: number;
  maxCalories?: number;
}

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

interface VictoryEffectProps {
  onComplete?: () => void;
}

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