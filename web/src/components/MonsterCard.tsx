import { motion, AnimatePresence } from 'framer-motion'
import HpBar from './HpBar'
import DamageNumber from './DamageNumber'

interface MonsterCardProps {
  emoji: string
  name: string
  level: number
  currentHp: number
  maxHp: number
  isShaking?: boolean
  damageNumbers?: Array<{ id: string; value: number; type: 'damage' | 'heal' }>
}

export default function MonsterCard({
  emoji,
  name,
  level,
  currentHp,
  maxHp,
  isShaking = false,
  damageNumbers = [],
}: MonsterCardProps) {
  return (
    <div className="relative">
      <motion.div
        animate={isShaking ? { x: [-5, 5, -5, 5, -3, 3, -2, 2, 0] } : {}}
        transition={{ duration: 0.5, ease: 'easeInOut' }}
        className="bg-card border border-border rounded-2xl p-3 flex flex-col items-center gap-1"
      >
        <div className="relative">
          <motion.div
            animate={{ y: [0, -6, 0] }}
            transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
            className="text-6xl md:text-7xl select-none"
          >
            {emoji}
          </motion.div>

          <AnimatePresence>
            {damageNumbers.map((dn) => (
              <DamageNumber
                key={dn.id}
                value={dn.value}
                type={dn.type}
              />
            ))}
          </AnimatePresence>
        </div>

        <div className="text-center w-full">
          <div className="flex items-center justify-center gap-2">
            <span className="text-base font-bold text-text">{name}</span>
            <span className="text-[10px] px-1.5 py-0.5 bg-gold/20 text-gold rounded-full font-bold">
              Lv.{level}
            </span>
          </div>
        </div>

        {/* MonsterCard 内的 HpBar 用于子页面；首页由外部控制 */}
        <div className="w-full">
          <HpBar current={currentHp} max={maxHp} size="md" color="red" />
        </div>
      </motion.div>
    </div>
  )
}
