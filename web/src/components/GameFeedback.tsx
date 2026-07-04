import { useEffect, useState, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Star, Zap, Trophy, Gift, ChevronRight } from 'lucide-react'
import { getLevelTitle } from '../store/useGameStore'

// ========== 浮动 XP 掉落 ==========
interface XpDrop {
  id: string
  amount: number
  x: number
  y: number
  label?: string
}

export function useXpDrops() {
  const [drops, setDrops] = useState<XpDrop[]>([])

  const spawnXp = useCallback((amount: number, x?: number, y?: number, label?: string) => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 6)
    const drop: XpDrop = {
      id,
      amount,
      x: x ?? 30 + Math.random() * 40,
      y: y ?? 20 + Math.random() * 30,
      label,
    }
    setDrops((prev) => [...prev, drop])
    setTimeout(() => {
      setDrops((prev) => prev.filter((d) => d.id !== id))
    }, 1200)
  }, [])

  return { drops, spawnXp }
}

export function XpDropOverlay({ drops }: { drops: XpDrop[] }) {
  return (
    <div className="absolute inset-0 pointer-events-none z-30 overflow-hidden">
      <AnimatePresence>
        {drops.map((drop) => (
          <motion.div
            key={drop.id}
            initial={{ opacity: 1, y: 0, scale: 0.5 }}
            animate={{ opacity: 0, y: -60, scale: 1.2 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 1, ease: 'easeOut' }}
            className="absolute text-gold font-black text-lg drop-shadow-lg"
            style={{ left: `${drop.x}%`, top: `${drop.y}%` }}
          >
            <div className="flex items-center gap-1">
              <Zap size={16} className="text-yellow fill-yellow" />
              {drop.label || `+${drop.amount} XP`}
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

// ========== 成就解锁弹窗 ==========
interface AchievementUnlock {
  id: string
  name: string
  description: string
  icon: string
  rarity: string
  reward: number
}

export function useAchievementPopup() {
  const [unlocks, setUnlocks] = useState<AchievementUnlock[]>([])

  const showUnlock = useCallback((ach: AchievementUnlock) => {
    setUnlocks((prev) => [...prev, { ...ach, id: Date.now().toString() + Math.random().toString(36).slice(2, 6) }])
    setTimeout(() => {
      setUnlocks((prev) => prev.filter((u) => u.id !== ach.id))
    }, 3500)
  }, [])

  return { unlocks, showUnlock }
}

const rarityColors: Record<string, string> = {
  common: 'from-gray-400 to-gray-500 border-gray-400/50',
  rare: 'from-blue-400 to-blue-600 border-blue-400/50',
  epic: 'from-purple-400 to-purple-600 border-purple-400/50',
  legendary: 'from-gold to-orange border-gold/50',
}

const rarityNames: Record<string, string> = {
  common: '普通',
  rare: '稀有',
  epic: '史诗',
  legendary: '传说',
}

export function AchievementPopupOverlay({ unlocks }: { unlocks: AchievementUnlock[] }) {
  return (
    <div className="absolute inset-0 pointer-events-none z-30 flex flex-col items-center justify-start pt-8 gap-2">
      <AnimatePresence>
        {unlocks.map((u) => (
          <motion.div
            key={u.id}
            initial={{ opacity: 0, scale: 0.5, y: -30 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.8, y: -20 }}
            transition={{ type: 'spring', stiffness: 300, damping: 20 }}
            className={`bg-gradient-to-r ${rarityColors[u.rarity] || rarityColors.common} border rounded-2xl px-5 py-3 shadow-xl backdrop-blur-sm flex items-center gap-3 max-w-[90%]`}
          >
            <div className="w-12 h-12 rounded-full bg-white/20 flex items-center justify-center text-2xl shrink-0">
              {u.icon}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-1.5">
                <Trophy size={14} className="text-white" />
                <span className="text-white/80 text-[10px] font-bold">{rarityNames[u.rarity] || '普通'} 成就解锁</span>
              </div>
              <div className="text-white font-bold text-sm truncate">{u.name}</div>
              <div className="text-white/70 text-[10px] truncate">{u.description}</div>
            </div>
            <div className="flex flex-col items-end gap-0.5 shrink-0">
              <div className="flex items-center gap-1 text-gold">
                <Gift size={12} />
                <span className="text-xs font-bold">+{u.reward}</span>
              </div>
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

// ========== 任务完成提示 ==========
interface QuestComplete {
  title: string
  rewardCoins: number
  rewardXp: number
}

export function useQuestPopup() {
  const [completes, setCompletes] = useState<(QuestComplete & { id: string })[]>([])

  const showQuestComplete = useCallback((q: QuestComplete) => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 6)
    setCompletes((prev) => [...prev, { ...q, id }])
    setTimeout(() => {
      setCompletes((prev) => prev.filter((c) => c.id !== id))
    }, 3000)
  }, [])

  return { completes, showQuestComplete }
}

export function QuestCompleteOverlay({ completes }: { completes: (QuestComplete & { id: string })[] }) {
  return (
    <div className="absolute inset-0 pointer-events-none z-30 flex flex-col items-center justify-end pb-20 gap-2">
      <AnimatePresence>
        {completes.map((q) => (
          <motion.div
            key={q.id}
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 50 }}
            transition={{ type: 'spring', stiffness: 300 }}
            className="bg-gradient-to-r from-green to-green-dark border border-green/50 rounded-xl px-4 py-2 shadow-lg flex items-center gap-2 max-w-[90%]"
          >
            <Star size={16} className="text-white fill-white" />
            <div className="text-white text-xs font-bold">{q.title} 完成！</div>
            <div className="flex items-center gap-2 text-white/90 text-[10px]">
              <span className="flex items-center gap-0.5"><Gift size={10} />+{q.rewardCoins}</span>
              <span className="flex items-center gap-0.5"><Zap size={10} />+{q.rewardXp}XP</span>
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

// ========== 升级弹窗 ==========
interface LevelUpInfo {
  newLevel: number
  title: string
}

export function useLevelUpPopup() {
  const [levelUps, setLevelUps] = useState<LevelUpInfo[]>([])

  const showLevelUp = useCallback((newLevel: number) => {
    setLevelUps([{ newLevel, title: getLevelTitle(newLevel) }])
    setTimeout(() => {
      setLevelUps([])
    }, 4000)
  }, [])

  return { levelUps, showLevelUp }
}

export function LevelUpOverlay({ levelUps }: { levelUps: LevelUpInfo[] }) {
  return (
    <div className="absolute inset-0 pointer-events-none z-40 flex items-center justify-center">
      <AnimatePresence>
        {levelUps.map((lu) => (
          <motion.div
            key={lu.newLevel}
            initial={{ opacity: 0, scale: 0.3, rotate: -10 }}
            animate={{ opacity: 1, scale: 1, rotate: 0 }}
            exit={{ opacity: 0, scale: 1.5 }}
            transition={{ type: 'spring', stiffness: 200, damping: 12 }}
            className="bg-gradient-to-br from-purple via-blue to-green border border-white/30 rounded-3xl px-8 py-6 shadow-2xl text-center"
          >
            <motion.div
              animate={{ rotate: [0, 10, -10, 0] }}
              transition={{ duration: 0.5, repeat: 2 }}
              className="text-5xl mb-2"
            >
              🎉
            </motion.div>
            <div className="text-gold text-xs font-bold tracking-wider mb-1">LEVEL UP</div>
            <div className="text-white text-3xl font-black mb-1">Lv.{lu.newLevel}</div>
            <div className="text-white/80 text-sm font-bold">{lu.title}</div>
            <div className="mt-3 flex items-center justify-center gap-1 text-white/60 text-[10px]">
              新技能已解锁 <ChevronRight size={12} />
            </div>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}
