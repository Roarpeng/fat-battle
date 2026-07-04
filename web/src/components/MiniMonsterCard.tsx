import { motion } from 'framer-motion'
import HpBar from './HpBar'

interface MiniMonsterCardProps {
  emoji: string
  name: string
  level: number
  currentHp: number
  maxHp: number
}

export default function MiniMonsterCard({
  emoji,
  name,
  level,
  currentHp,
  maxHp,
}: MiniMonsterCardProps) {
  const hpPercent = maxHp > 0 ? (currentHp / maxHp) * 100 : 0

  return (
    <div className="w-full bg-card border border-border rounded-2xl p-3 flex flex-col items-center gap-2">
      {/* 怪物信息 */}
      <div className="flex items-center gap-2">
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
      </div>

      {/* 血条 */}
      <div className="w-full">
        <div className="flex justify-between text-[10px] text-text3 mb-0.5">
          <span>HP</span>
          <span>
            {currentHp} / {maxHp}
          </span>
        </div>
        <HpBar current={currentHp} max={maxHp} size="sm" />
      </div>
    </div>
  )
}
