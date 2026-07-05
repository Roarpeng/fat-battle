import { motion, AnimatePresence } from 'framer-motion'
import HpBar from './HpBar'
import { Shield } from 'lucide-react'

interface MiniMonsterCardProps {
  emoji: string
  name: string
  level: number
  currentHp: number
  maxHp: number
  overeatCalories?: number
  maxOvereat?: number
}

export default function MiniMonsterCard({
  emoji,
  name,
  level,
  currentHp,
  maxHp,
  overeatCalories = 0,
  maxOvereat = 500,
}: MiniMonsterCardProps) {
  const hpPercent = maxHp > 0 ? (currentHp / maxHp) * 100 : 0
  const overeatFactor = Math.min(1, overeatCalories / maxOvereat)

  return (
    <div className="w-full bg-card border border-border rounded-2xl p-3 flex flex-col items-center gap-2 relative overflow-hidden">
      <AnimatePresence>
        {overeatCalories > 0 && (
          <motion.div
            key="shield"
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            className="absolute inset-0 pointer-events-none"
          >
            <motion.div
              animate={{
                opacity: [0.2, 0.4, 0.2],
                scale: [1, 1.05, 1],
              }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: 'easeInOut',
              }}
              className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
              style={{
                width: '120px',
                height: '120px',
                border: `2px solid rgba(255,215,0,${0.3 + overeatFactor * 0.4})`,
                borderRadius: '50%',
                boxShadow: `0 0 15px rgba(255,215,0,${0.2 + overeatFactor * 0.3})`,
              }}
            />
            
            <motion.div
              animate={{
                rotate: 360,
              }}
              transition={{
                duration: 10,
                repeat: Infinity,
                ease: 'linear',
              }}
              className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
              style={{
                width: '110px',
                height: '110px',
              }}
            >
              {Array.from({ length: 6 }).map((_, i) => {
                const angle = (i * 60) * (Math.PI / 180)
                const x = Math.cos(angle) * 50
                const y = Math.sin(angle) * 50
                return (
                  <motion.div
                    key={i}
                    animate={{
                      scale: [0.8, 1.2, 0.8],
                      opacity: [0.4, 0.8, 0.4],
                    }}
                    transition={{
                      duration: 1.5,
                      delay: i * 0.2,
                      repeat: Infinity,
                    }}
                    className="absolute w-2 h-2 rounded-full"
                    style={{
                      left: '50%',
                      top: '50%',
                      transform: `translate(-50%, -50%) translate(${x}px, ${y}px)`,
                      background: 'rgba(255,215,0,0.6)',
                      boxShadow: '0 0 6px rgba(255,215,0,0.8)',
                    }}
                  />
                )
              })}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="flex items-center gap-2 relative z-10">
        <motion.div
          animate={{
            scale: hpPercent > 50 ? [1, 1.05, 1] : [1, 0.95, 1],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
          className="text-4xl"
        >
          {emoji}
        </motion.div>
        <div className="flex flex-col">
          <span className="font-bold text-sm text-text">{name}</span>
          <span className="text-[10px] text-text3">Lv.{level}</span>
        </div>
        <AnimatePresence>
          {overeatCalories > 0 && (
            <motion.div
              key="shield-badge"
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0, opacity: 0 }}
              className="flex items-center gap-0.5 px-1.5 py-0.5 bg-orange/20 rounded-full ml-1"
            >
              <Shield size={8} className="text-orange fill-orange" />
              <span className="text-[8px] font-bold text-orange">{overeatCalories}</span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <div className="w-full relative z-10">
        <div className="flex justify-between text-[10px] text-text3 mb-0.5">
          <span>HP</span>
          <span>
            {currentHp} / {maxHp}
          </span>
        </div>
        <HpBar current={currentHp} max={maxHp} size="sm" overeatFactor={overeatFactor} />
      </div>
    </div>
  )
}
