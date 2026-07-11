import { useState, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Heart, Utensils, Dumbbell, Sparkles } from 'lucide-react'
import MobileHeader from '../components/MobileHeader'
import { useGameStore } from '../store/useGameStore'
import {
  getCompanionStage,
  getCompanionDef,
  getMoodLabel,
  getMoodDescription,
  DEFAULT_COMPANION,
} from '../data/companion'

interface HeartParticle {
  id: string
  x: number
  delay: number
}

export default function CompanionPage() {
  const { companion, petCompanion, updateCompanionMood } = useGameStore()
  const [hearts, setHearts] = useState<HeartParticle[]>([])
  const [isPetting, setIsPetting] = useState(false)

  useEffect(() => {
    updateCompanionMood()
  }, [updateCompanionMood])

  const stage = getCompanionStage(companion.defId, companion.level)
  const def = getCompanionDef(companion.defId)

  const xpPercent = Math.min(100, Math.round((companion.xp / companion.xpToNext) * 100))
  const hungerPercent = companion.hunger
  const energyPercent = companion.energy

  const hungerColor =
    companion.hunger > 80 ? 'bg-red' : companion.hunger > 50 ? 'bg-orange' : 'bg-green'
  const energyColor =
    companion.energy < 20 ? 'bg-red' : companion.energy < 50 ? 'bg-orange' : 'bg-blue'

  const moodBorderColor =
    companion.mood === 'happy'
      ? 'border-green'
      : companion.mood === 'normal'
        ? 'border-blue'
        : companion.mood === 'tired'
          ? 'border-orange'
          : 'border-red'

  const handlePet = useCallback(() => {
    petCompanion()
    setIsPetting(true)
    const newHearts: HeartParticle[] = Array.from({ length: 5 }, (_, i) => ({
      id: `${Date.now()}-${i}`,
      x: (Math.random() - 0.5) * 80,
      delay: i * 0.1,
    }))
    setHearts((prev) => [...prev, ...newHearts])
    setTimeout(() => setIsPetting(false), 600)
    setTimeout(() => {
      setHearts((prev) => prev.filter((h) => !newHearts.find((nh) => nh.id === h.id)))
    }, 2000)
  }, [petCompanion])

  return (
    <div className="flex flex-col h-full">
      <MobileHeader title="战斗伙伴" gradient="from-purple to-pink" />

      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {/* 伙伴大图 */}
        <div className="flex flex-col items-center">
          <motion.div
            animate={
              isPetting
                ? { scale: [1, 1.2, 0.95, 1.05, 1], y: [0, -10, 0] }
                : companion.mood === 'happy'
                  ? { y: [0, -4, 0] }
                  : companion.mood === 'sad'
                    ? { x: [-2, 2, -2, 2, 0] }
                    : {}
            }
            transition={
              isPetting
                ? { duration: 0.5 }
                : { duration: 0.6, repeat: Infinity, repeatDelay: companion.mood === 'happy' ? 0.5 : 0.8 }
            }
            className={`relative flex items-center justify-center w-24 h-24 rounded-full border-4 ${moodBorderColor} bg-card shadow-lg`}
          >
            <span className="text-6xl">{companion.emoji}</span>
            <AnimatePresence>
              {hearts.map((heart) => (
                <motion.span
                  key={heart.id}
                  initial={{ opacity: 1, y: 0, x: 0, scale: 0.5 }}
                  animate={{ opacity: 0, y: -80, x: heart.x, scale: 1.2 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 1.2, delay: heart.delay, ease: 'easeOut' }}
                  className="absolute text-xl pointer-events-none"
                >
                  ❤️
                </motion.span>
              ))}
            </AnimatePresence>
          </motion.div>

          <h2 className="mt-3 text-xl font-black text-text">{companion.name}</h2>
          <p className="text-xs text-text3">{def.description}</p>
        </div>

        {/* 等级与 XP */}
        <div className="bg-card border border-border rounded-2xl p-4 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-sm font-bold text-text">等级 {companion.level}</span>
            <span className="text-xs text-text3">
              {companion.xp} / {companion.xpToNext} XP
            </span>
          </div>
          <div className="h-2.5 bg-bg2 rounded-full overflow-hidden">
            <motion.div
              className="h-full bg-gradient-to-r from-purple to-pink rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${xpPercent}%` }}
              transition={{ duration: 0.8, ease: 'easeOut' }}
            />
          </div>
          <div className="flex items-center gap-2 text-xs text-text3">
            <Sparkles size={14} className="text-gold" />
            <span>当前阶段：{stage.name}</span>
          </div>
        </div>

        {/* Hunger & Energy */}
        <div className="bg-card border border-border rounded-2xl p-4 space-y-3">
          <div>
            <div className="flex justify-between text-xs text-text3 mb-1">
              <span className="flex items-center gap-1">
                <Utensils size={12} />
                饥饿度
              </span>
              <span className={companion.hunger > 80 ? 'text-red font-bold' : ''}>{companion.hunger}/100</span>
            </div>
            <div className="h-2 bg-bg2 rounded-full overflow-hidden">
              <div
                className={`h-full ${hungerColor} rounded-full transition-all`}
                style={{ width: `${hungerPercent}%` }}
              />
            </div>
          </div>
          <div>
            <div className="flex justify-between text-xs text-text3 mb-1">
              <span className="flex items-center gap-1">
                <Dumbbell size={12} />
                活力值
              </span>
              <span className={companion.energy < 20 ? 'text-red font-bold' : ''}>{companion.energy}/100</span>
            </div>
            <div className="h-2 bg-bg2 rounded-full overflow-hidden">
              <div
                className={`h-full ${energyColor} rounded-full transition-all`}
                style={{ width: `${energyPercent}%` }}
              />
            </div>
          </div>
        </div>

        {/* 心情 */}
        <div className="bg-card border border-border rounded-2xl p-4 text-center">
          <div className="text-sm font-bold text-text mb-1">
            心情：{getMoodLabel(companion.mood)}
          </div>
          <p className="text-xs text-text3">{getMoodDescription(companion.mood)}</p>
        </div>

        {/* 累计统计 */}
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-card border border-border rounded-2xl p-3 text-center">
            <Dumbbell size={20} className="text-green mx-auto mb-1" />
            <div className="text-lg font-black text-text">{companion.totalExercises}</div>
            <div className="text-[10px] text-text3">累计运动次数</div>
          </div>
          <div className="bg-card border border-border rounded-2xl p-3 text-center">
            <Utensils size={20} className="text-red mx-auto mb-1" />
            <div className="text-lg font-black text-text">{companion.totalDiets}</div>
            <div className="text-[10px] text-text3">累计饮食记录</div>
          </div>
        </div>

        {/* 进化路线图 */}
        <div className="bg-card border border-border rounded-2xl p-4">
          <h3 className="text-sm font-bold text-text mb-3">进化路线</h3>
          <div className="flex items-center justify-between">
            {DEFAULT_COMPANION.stages.map((s, index) => {
              const isCurrent = s.minLevel <= companion.level && (index === DEFAULT_COMPANION.stages.length - 1 || DEFAULT_COMPANION.stages[index + 1].minLevel > companion.level)
              const isUnlocked = companion.level >= s.minLevel
              return (
                <div key={s.name} className="flex flex-col items-center flex-1">
                  <motion.div
                    animate={isCurrent ? { scale: [1, 1.1, 1] } : {}}
                    transition={{ duration: 0.5, repeat: Infinity, repeatDelay: 1 }}
                    className={`w-10 h-10 rounded-full flex items-center justify-center text-lg border-2 ${
                      isCurrent
                        ? 'border-gold bg-gold/20'
                        : isUnlocked
                          ? 'border-green bg-green/10'
                          : 'border-border bg-bg2 opacity-50'
                    }`}
                  >
                    {s.emoji}
                  </motion.div>
                  <span className={`text-[10px] mt-1 font-bold ${isCurrent ? 'text-gold' : isUnlocked ? 'text-text' : 'text-text3'}`}>
                    {s.name}
                  </span>
                  <span className="text-[8px] text-text3">Lv.{s.minLevel}</span>
                  {index < DEFAULT_COMPANION.stages.length - 1 && (
                    <div className="absolute right-0 top-5 w-full h-0.5 bg-border -z-10" style={{ transform: 'translateX(50%)' }} />
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* 抚摸按钮 */}
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.95 }}
          onClick={handlePet}
          className="w-full py-3 bg-gradient-to-r from-pink to-purple border border-pink/30 rounded-2xl text-white font-bold flex items-center justify-center gap-2 shadow-md"
        >
          <Heart size={18} className="fill-white" />
          抚摸咪咪
        </motion.button>

        {/* 喂食指南 */}
        <div className="bg-blue/10 border border-blue/30 rounded-xl p-3 flex items-start gap-2">
          <Sparkles size={16} className="text-blue shrink-0 mt-0.5" />
          <p className="text-xs text-blue">
            主人~ 记录饮食可以喂饱咪咪哦，运动打卡能让咪咪获得经验升级呢！
          </p>
        </div>
      </div>
    </div>
  )
}
