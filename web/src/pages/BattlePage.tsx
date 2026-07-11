import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate, useLocation } from 'react-router-dom'
import { Coins, Flame, Utensils, Dumbbell, Target, Settings, Shield, Trophy, Zap, AlertTriangle, BookOpen, X, Scroll } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import HpBar from '../components/HpBar'
import CompanionAvatar from '../components/CompanionAvatar'
import { DamageNumber, FloatingText, AttackEffect, MonsterAnimation, EnergyShield, StoryBubble } from '../components/BattleEffects'
import { getRandomTaunt, getTauntByTrigger } from '../data/monsterTaunts'
import { getMonsterStory } from '../data/monsterStories'
import { getRandomEncouragement } from '../data/encouragements'
import { getWeaknessLabel, getTierName, getCategoryEmoji } from '../data/monsters'
import { TAP_SCALE, HOVER_SCALE, dialogTransition } from '../lib/interaction'

type AttackType = 'missile' | 'knife' | 'punch' | 'fireball' | 'lightning' | 'grease' | 'bomb'

interface AttackEffectState {
  id: string
  type: AttackType
  damage: number
  isOvereat: boolean
}

interface StoryBubbleState {
  text: string
  type: 'encounter' | 'phaseChange' | 'enrage' | 'defeat'
  visible: boolean
}

export default function BattlePage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { monster, daily, coins, days, streak, user, setPendingAttack, attackMonster, companion, updateCompanionMood } = useGameStore()
  const [showVictory, setShowVictory] = useState(false)
  const [prevMonsterHp, setPrevMonsterHp] = useState(monster.hp)
  const [damageNumbers, setDamageNumbers] = useState<Array<{ id: string; value: number; type: 'damage' | 'heal' | 'critical' }>>([])
  const [attackEffects, setAttackEffects] = useState<AttackEffectState[]>([])
  const [shieldEffect, setShieldEffect] = useState(false)
  const [isMonsterHit, setIsMonsterHit] = useState(false)
  const [currentTaunt, setCurrentTaunt] = useState<string | null>(null)
  const [currentEncouragement, setCurrentEncouragement] = useState<string | null>(null)
  const [companionCheer, setCompanionCheer] = useState<string | null>(null)
  const [tauntTimer, setTauntTimer] = useState<number | null>(null)
  const [hasPlayedEffects, setHasPlayedEffects] = useState(false)
  const pendingAttackRef = useRef(daily.pendingAttack)
  const prevPhaseIndex = useRef(monster.phaseIndex || 0)
  const prevEnraged = useRef(monster.isEnraged || false)

  // 叙事气泡状态
  const [storyBubble, setStoryBubble] = useState<StoryBubbleState>({ text: '', type: 'encounter', visible: false })
  const [showStoryModal, setShowStoryModal] = useState(false)

  // 首次遇到/击败追踪（localStorage，不修改 store）
  const [encounteredIds, setEncounteredIds] = useState<Set<string>>(() => {
    try {
      const saved = localStorage.getItem('encountered-monsters')
      return saved ? new Set(JSON.parse(saved)) : new Set<string>()
    } catch {
      return new Set<string>()
    }
  })
  const [defeatedIds, setDefeatedIds] = useState<Set<string>>(() => {
    try {
      const saved = localStorage.getItem('defeated-monsters')
      return saved ? new Set(JSON.parse(saved)) : new Set<string>()
    } catch {
      return new Set<string>()
    }
  })

  // 当前怪物是否已触发过首次遇到叙事
  const hasShownEncounter = useRef(false)

  const dailyCaloriePlan = useMemo(() => {
    const bmr = 10 * user.weight + 6.25 * user.height - 5 * 25 + 5
    const factor = user.difficulty === 'easy' ? 1.3 : user.difficulty === 'hard' ? 1.1 : 1.2
    return Math.round(bmr * factor)
  }, [user])

  const netCalories = daily.intake - daily.exerciseBurn
  const overeatCalories = Math.max(0, netCalories - dailyCaloriePlan)
  const exerciseDamage = Math.floor(daily.exerciseBurn * 0.3)
  const hpPercentage = monster.hp / monster.maxHp
  const overeatFactor = Math.min(1, overeatCalories / dailyCaloriePlan)

  const showRandomTaunt = useCallback((trigger?: 'high_hp' | 'low_hp' | 'after_damage' | 'after_heal' | 'phase_change' | 'enrage') => {
    if (monster.hp <= 0) return
    let taunt: string
    const monsterType = monster.type || monster.defId || 'slime'
    if (trigger) {
      taunt = getTauntByTrigger(monsterType, trigger)
    } else {
      // 狂暴状态优先使用狂暴嘲讽
      if (monster.isEnraged && Math.random() > 0.5) {
        taunt = getTauntByTrigger(monsterType, 'enrage')
      } else {
        const hpTrigger = hpPercentage > 0.6 ? 'high_hp' : hpPercentage > 0.3 ? 'after_damage' : 'low_hp'
        taunt = getTauntByTrigger(monsterType, hpTrigger)
      }
    }
    setCurrentTaunt(taunt)
    if (tauntTimer) window.clearTimeout(tauntTimer)
    const timer = window.setTimeout(() => setCurrentTaunt(null), 4500)
    setTauntTimer(timer)
  }, [monster.hp, monster.type, monster.defId, monster.isEnraged, hpPercentage, tauntTimer])

  const showEncouragement = useCallback((type: 'exercise_complete' | 'battle_progress' | 'battle_victory') => {
    const msg = getRandomEncouragement(type)
    setCurrentEncouragement(msg)
    setTimeout(() => setCurrentEncouragement(null), 3000)
  }, [])

  const showStoryBubble = useCallback((text: string, type: StoryBubbleState['type']) => {
    setStoryBubble({ text, type, visible: true })
  }, [])

  const hideStoryBubble = useCallback(() => {
    setStoryBubble((prev) => ({ ...prev, visible: false }))
  }, [])

  // 保存 encounteredIds / defeatedIds 到 localStorage
  useEffect(() => {
    localStorage.setItem('encountered-monsters', JSON.stringify(Array.from(encounteredIds)))
  }, [encounteredIds])

  useEffect(() => {
    localStorage.setItem('defeated-monsters', JSON.stringify(Array.from(defeatedIds)))
  }, [defeatedIds])

  useEffect(() => {
    updateCompanionMood()
  }, [updateCompanionMood])

  useEffect(() => {
    if (monster.hp <= 0) {
      setCurrentTaunt(null)
      return
    }
    const interval = window.setInterval(() => {
      if (Math.random() > 0.4) showRandomTaunt()
    }, 6000 + Math.random() * 5000)
    return () => clearInterval(interval)
  }, [monster.hp, showRandomTaunt])

  // 首次遇到怪物时显示叙事
  useEffect(() => {
    if (!monster.defId || monster.hp <= 0) return
    if (hasShownEncounter.current) return

    const story = getMonsterStory(monster.defId)
    if (!story) return

    const isFirstEncounter = !encounteredIds.has(monster.defId)
    if (isFirstEncounter) {
      setEncounteredIds((prev) => new Set(prev).add(monster.defId))
      showStoryBubble(story.firstEncounter, 'encounter')
    }
    hasShownEncounter.current = true

    return () => {
      hasShownEncounter.current = false
    }
  }, [monster.defId, monster.hp, encounteredIds, showStoryBubble])

  const lastNavState = useRef<string>(location.pathname)

  // 同步 pendingAttack 到 ref，避免闭包过期
  useEffect(() => {
    pendingAttackRef.current = daily.pendingAttack
  }, [daily.pendingAttack])

  useEffect(() => {
    const prevPath = lastNavState.current
    lastNavState.current = location.pathname
    
    if (location.pathname === '/' && (prevPath === '/food' || prevPath === '/exercise' || prevPath === '/pose')) {
      setHasPlayedEffects(false)
      triggerAttackAnimation()
    }
  }, [location.pathname])

  // 组件挂载时，如果有 pendingAttack 说明是从其他页面跳回来的（组件被重新挂载的情况）
  useEffect(() => {
    if (daily.pendingAttack && !hasPlayedEffects) {
      // 延迟一帧确保组件已完全渲染
      const timer = requestAnimationFrame(() => {
        setHasPlayedEffects(true)
        triggerAttackAnimation()
      })
      return () => cancelAnimationFrame(timer)
    }
  }, [daily.pendingAttack])

  const triggerAttackAnimation = () => {
    if (hasPlayedEffects) return
    setHasPlayedEffects(true)

    // 使用 ref 获取最新的 pendingAttack，避免闭包过期
    const currentPendingAttack = pendingAttackRef.current

    if (currentPendingAttack) {
      const { pendingAttack } = { pendingAttack: currentPendingAttack }
      const effectId = Date.now().toString() + Math.random().toString(36).slice(2, 6)

      if (!pendingAttack.isOvereat && pendingAttack.damage > 0) {
        setAttackEffects((prev) => [...prev, { id: effectId, type: pendingAttack.attackType, damage: pendingAttack.damage, isOvereat: false }])
        setIsMonsterHit(true)
        setTimeout(() => setIsMonsterHit(false), 500)

        setTimeout(() => {
          const { attackMonster } = useGameStore.getState()
          const isCritical = Math.random() > 0.85
          const finalDamage = pendingAttack.damage * (isCritical ? 1.5 : 1)
          attackMonster(finalDamage)
          addDamageNumber(finalDamage, isCritical ? 'critical' : 'damage')
          if (isCritical) showEncouragement('battle_progress')
        }, 500)

        setTimeout(() => {
          setAttackEffects((prev) => prev.filter((e) => e.id !== effectId))
          setPendingAttack(null)
        }, 1500)
      } else if (pendingAttack.isOvereat) {
        setAttackEffects((prev) => [...prev, { id: effectId, type: 'grease', damage: pendingAttack.overeatCalories || 0, isOvereat: true }])
        setShieldEffect(true)

        const healAmount = Math.floor((pendingAttack.overeatCalories || 0) * 0.05)
        if (healAmount > 0) {
          setTimeout(() => {
            addDamageNumber(healAmount, 'heal')
          }, 800)
        }

        setTimeout(() => {
          setAttackEffects((prev) => prev.filter((e) => e.id !== effectId))
          setShieldEffect(false)
          setPendingAttack(null)
        }, 2000)
      }
    } else if (exerciseDamage > 0) {
      const attackTypes: AttackType[] = ['missile', 'knife', 'punch', 'fireball', 'lightning']
      const randomType = attackTypes[Math.floor(Math.random() * attackTypes.length)]
      const effectId = Date.now().toString() + Math.random().toString(36).slice(2, 6)
      setAttackEffects((prev) => [...prev, { id: effectId, type: randomType, damage: exerciseDamage, isOvereat: false }])
      setIsMonsterHit(true)
      setTimeout(() => setIsMonsterHit(false), 500)

      setTimeout(() => {
        const { attackMonster } = useGameStore.getState()
        const isCritical = Math.random() > 0.85
        attackMonster(exerciseDamage * (isCritical ? 1.5 : 1))
        addDamageNumber(exerciseDamage * (isCritical ? 1.5 : 1), isCritical ? 'critical' : 'damage')
        if (isCritical) showEncouragement('battle_progress')
      }, 500)

      setTimeout(() => {
        setAttackEffects((prev) => prev.filter((e) => e.id !== effectId))
      }, 1500)
    }

    if (overeatCalories > 0 && !currentPendingAttack?.isOvereat) {
      const greaseId = Date.now().toString() + 'grease'
      setAttackEffects((prev) => [...prev, { id: greaseId, type: 'grease', damage: overeatCalories, isOvereat: true }])
      setShieldEffect(true)

      const healAmount = Math.floor(overeatCalories * 0.05)
      if (healAmount > 0) {
        setTimeout(() => {
          addDamageNumber(healAmount, 'heal')
        }, 800)
      }

      setTimeout(() => {
        setAttackEffects((prev) => prev.filter((e) => e.id !== greaseId))
        setShieldEffect(false)
      }, 2000)
    }
  }

  const showCompanionCheer = useCallback(() => {
    const cheers = ['主人加油！', '好厉害！', '冲呀主人！', '咪咪相信主人！']
    const msg = cheers[Math.floor(Math.random() * cheers.length)]
    setCompanionCheer(msg)
    setTimeout(() => setCompanionCheer(null), 2500)
  }, [])

  useEffect(() => {
    const story = monster.defId ? getMonsterStory(monster.defId) : undefined

    if (prevMonsterHp > monster.hp && monster.hp === 0) {
      setShowVictory(true)
      showEncouragement('battle_victory')

      // 怪物被击败叙事
      if (story && monster.defId) {
        const isFirstDefeat = !defeatedIds.has(monster.defId)
        if (isFirstDefeat) {
          setDefeatedIds((prev) => new Set(prev).add(monster.defId))
          showStoryBubble(story.firstDefeat, 'defeat')
        } else {
          const victoryLines = ['太棒啦！又打倒一个！', '胜利！主人最厉害了！', '耶！继续加油哦~']
          showStoryBubble(victoryLines[Math.floor(Math.random() * victoryLines.length)], 'defeat')
        }
      }
    } else if (prevMonsterHp > monster.hp) {
      if (Math.random() > 0.3) showRandomTaunt('after_damage')
      if (hpPercentage < 0.5 && hpPercentage > 0.3) showEncouragement('battle_progress')
      if (Math.random() > 0.5) showCompanionCheer()
    } else if (prevMonsterHp < monster.hp) {
      if (Math.random() > 0.2) showRandomTaunt('after_heal')
    }
    setPrevMonsterHp(monster.hp)

    // 检测阶段切换
    const currentPhase = monster.phaseIndex || 0
    if (currentPhase > prevPhaseIndex.current) {
      showRandomTaunt('phase_change')
      showEncouragement('battle_progress')
      if (story && story.phaseChange.length > 0) {
        const line = story.phaseChange[Math.min(currentPhase - 1, story.phaseChange.length - 1)]
        showStoryBubble(line, 'phaseChange')
      }
    }
    prevPhaseIndex.current = currentPhase

    // 检测狂暴触发
    const currentEnraged = monster.isEnraged || false
    if (currentEnraged && !prevEnraged.current) {
      showRandomTaunt('enrage')
      if (story && story.enrage.length > 0) {
        const line = story.enrage[Math.floor(Math.random() * story.enrage.length)]
        showStoryBubble(line, 'enrage')
      }
    }
    prevEnraged.current = currentEnraged
  }, [monster.hp, monster.phaseIndex, monster.isEnraged, prevMonsterHp, showRandomTaunt, showEncouragement, hpPercentage, monster.defId, defeatedIds, showStoryBubble, showCompanionCheer])

  const addDamageNumber = (value: number, type: 'damage' | 'heal' | 'critical') => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 8)
    setDamageNumbers((prev) => [...prev, { id, value: Math.floor(value), type }])
    setTimeout(() => {
      setDamageNumbers((prev) => prev.filter((d) => d.id !== id))
    }, 1000)
  }

  const handleNextLevel = () => {
    setShowVictory(false)
  }

  const coinRain = Array.from({ length: 30 }, (_, i) => ({
    id: i,
    left: Math.random() * 100,
    delay: Math.random() * 2,
    duration: 2 + Math.random() * 2,
    size: 20 + Math.random() * 20,
  }))

  return (
    <div className="flex flex-col px-4 py-2 gap-2" style={{ height: 'calc(100vh - 56px)' }}>
      <AnimatePresence>
        {showVictory && (
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
                transition={{
                  duration: coin.duration,
                  delay: coin.delay,
                  repeat: Infinity,
                  ease: 'linear',
                }}
                className="absolute text-4xl"
                style={{ left: `${coin.left}%`, fontSize: coin.size }}
              >
                🪙
              </motion.div>
            ))}

            <motion.div
              initial={dialogTransition.initial}
              animate={dialogTransition.animate}
              exit={dialogTransition.exit}
              transition={dialogTransition.transition}
              className="relative z-10 bg-card border-2 border-gold rounded-3xl p-8 mx-4 max-w-sm w-full text-center shadow-2xl"
            >
              <motion.div
                animate={{ rotate: [0, 10, -10, 0], scale: [1, 1.1, 1] }}
                transition={{ duration: 1, repeat: Infinity, repeatDelay: 1 }}
                className="text-7xl mb-4"
              >
                🏆
              </motion.div>

              <motion.h2
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.5 }}
                className="text-3xl font-black mb-2 bg-gradient-to-r from-gold to-orange bg-clip-text text-transparent"
              >
                今日作战完成！
              </motion.h2>

              <motion.p
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.6 }}
                className="text-text2 mb-6"
              >
                主人太厉害了！今日的脂肪怪已经被击退啦~ 🎉
              </motion.p>

              <motion.div
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.7 }}
                className="flex items-center justify-center gap-2 mb-6 py-3 px-4 bg-gold/10 rounded-xl border border-gold/30"
              >
                <Coins className="w-6 h-6 text-gold" />
                <span className="text-gold font-bold text-xl">+{Math.round(monster.level * 10 * (monster.coinMultiplier || 1))}</span>
              </motion.div>

              <motion.button
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.8 }}
                whileHover={{ scale: HOVER_SCALE }}
                whileTap={{ scale: TAP_SCALE }}
                onClick={handleNextLevel}
                className="w-full py-4 px-6 bg-gradient-to-r from-gold to-gold-dark text-bg font-bold text-lg rounded-2xl shadow-lg shadow-gold/30 active:bg-white/[0.12]"
              >
                收下成就 ✨
              </motion.button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="flex items-center justify-between shrink-0">
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1 bg-card border border-border rounded-full">
            <Target className="w-4 h-4 text-purple" />
            <span className="font-bold text-sm">Day {days}</span>
          </div>
          {streak > 0 && (
            <div className="flex items-center gap-1.5 px-3 py-1 bg-card border border-border rounded-full">
              <Flame className="w-4 h-4 text-orange" />
              <span className="font-bold text-sm text-orange">{streak}天</span>
            </div>
          )}
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1 bg-card border border-border rounded-full">
            <Coins className="w-4 h-4 text-gold" />
            <span className="font-bold text-sm text-gold">{coins}</span>
          </div>
          <button
            onClick={() => navigate('/codex')}
            className="flex items-center gap-1 px-2.5 py-1 bg-gradient-to-r from-purple/20 to-blue/20 border border-purple/30 rounded-full hover:border-purple/60 transition-colors"
          >
            <BookOpen size={14} className="text-purple" />
            <span className="text-xs font-bold text-purple">图鉴</span>
          </button>
          <button
            onClick={() => navigate('/settings')}
            className="w-8 h-8 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors"
          >
            <Settings size={16} className="text-text3" />
          </button>
        </div>
      </div>

      {/* 信息摘要栏 - text-[10px] -> text-xs */}
      <div className="shrink-0 flex items-center gap-2 px-3 py-2 bg-card/60 rounded-xl border border-border/50">
        <div className="flex-1 flex items-center gap-1.5">
          <Utensils size={12} className="text-red" />
          <span className="text-xs text-text3">摄入</span>
          <span className="text-xs font-bold text-text">{Math.round(daily.intake)}</span>
          <span className="text-xs text-text3">/ {dailyCaloriePlan}</span>
        </div>
        <div className="w-px h-3 bg-border" />
        <div className="flex-1 flex items-center gap-1.5">
          <Dumbbell size={12} className="text-green" />
          <span className="text-xs text-text3">消耗</span>
          <span className="text-xs font-bold text-text">{Math.round(daily.exerciseBurn)}</span>
        </div>
        {overeatCalories > 0 && (
          <div className="flex items-center gap-1 px-2 py-0.5 bg-orange/20 rounded-full">
            <Shield size={10} className="text-orange" />
            <span className="text-xs font-bold text-orange">超量 {overeatCalories}</span>
          </div>
        )}
      </div>

      {/* 战斗区域 - 增加shadow-md + 渐变呼吸背景 */}
      <motion.div
        className="flex flex-col bg-card/30 border border-border/50 rounded-3xl overflow-hidden relative shadow-md"
        style={{ height: '60%' }}
      >
        {/* 怪物区域微妙背景呼吸动画 */}
        <motion.div
          className="absolute inset-0 pointer-events-none"
          animate={{
            background: [
              'radial-gradient(ellipse at 50% 50%, rgba(255,107,107,0.03) 0%, transparent 70%)',
              'radial-gradient(ellipse at 50% 50%, rgba(255,107,107,0.08) 0%, transparent 70%)',
              'radial-gradient(ellipse at 50% 50%, rgba(255,107,107,0.03) 0%, transparent 70%)',
            ],
          }}
          transition={{
            duration: 4,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />

        <div className="shrink-0 px-4 pt-3 pb-1">
          <div className="flex justify-between items-center text-xs text-text3 mb-1">
            <span className="font-bold flex items-center gap-1.5">
              {monster.name} Lv.{monster.level}
              {/* 层级标签 */}
              <span className={`px-1.5 py-0.5 rounded-full text-[8px] font-bold ${
                monster.tier === 'finalboss' ? 'bg-purple/20 text-purple' :
                monster.tier === 'boss' ? 'bg-red/20 text-red' :
                monster.tier === 'elite' ? 'bg-orange/20 text-orange' :
                'bg-blue/20 text-blue'
              }`}>
                {getTierName(monster.tier)}
              </span>
              {/* 阶段名称 */}
              {monster.phaseName && (
                <span className="px-1.5 py-0.5 rounded-full text-[8px] bg-gold/20 text-gold font-bold">
                  {monster.phaseName}
                </span>
              )}
              {/* 狂暴状态 */}
              {monster.isEnraged && (
                <motion.span
                  animate={{ scale: [1, 1.15, 1] }}
                  transition={{ duration: 0.5, repeat: Infinity }}
                  className="flex items-center gap-0.5 text-red"
                >
                  <AlertTriangle size={10} className="fill-red text-red" />
                  <span className="text-[8px] font-bold">狂暴</span>
                </motion.span>
              )}
              {shieldEffect && (
                <motion.span
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  className="flex items-center gap-0.5 text-orange"
                >
                  <Shield size={10} className="fill-orange" />
                  <span className="text-[9px]">油腻防御</span>
                </motion.span>
              )}
              {/* AI 教练动态难度标签 */}
              {monster.hpMultiplier && monster.hpMultiplier !== 1.0 && (
                <span className={`flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[8px] font-bold ${
                  monster.hpMultiplier > 1.0
                    ? 'bg-red/20 text-red'
                    : 'bg-green/20 text-green'
                }`}>
                  {monster.hpMultiplier > 1.0 ? '🔥' : '💚'}
                  {monster.hpMultiplier > 1.0
                    ? `强化模式（怪物血量 +${Math.round((monster.hpMultiplier - 1) * 100)}%）`
                    : `轻松模式（怪物血量 -${Math.round((1 - monster.hpMultiplier) * 100)}%）`
                  }
                </span>
              )}
            </span>
            <span>{monster.hp} / {monster.maxHp}</span>
          </div>
          <HpBar current={monster.hp} max={monster.maxHp} size="sm" showText={false} overeatFactor={overeatFactor} />
          {/* 弱点提示 */}
          <div className="flex items-center gap-2 mt-1">
            <span className="flex items-center gap-0.5 text-[8px] text-text3">
              <Zap size={8} className="text-yellow" />
              弱点: <span className="text-yellow font-bold">{getCategoryEmoji(monster.weakness)} {getWeaknessLabel(monster.weakness)}</span>
            </span>
          </div>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center relative px-4 min-h-0">
          <AnimatePresence>
            {currentTaunt && monster.hp > 0 && (
              <FloatingText key={currentTaunt} id={currentTaunt} text={currentTaunt} type="taunt" />
            )}
          </AnimatePresence>

          <AnimatePresence>
            {currentEncouragement && (
              <motion.div
                key={currentEncouragement}
                initial={{ opacity: 0, y: -20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                transition={{ type: 'spring', stiffness: 300, damping: 20 }}
                className="absolute top-4 right-4 z-20"
              >
                <div className="bg-green/90 border-2 border-green rounded-xl px-3 py-1.5 shadow-lg">
                  <div className="text-xs font-bold text-white">
                    ✨ {currentEncouragement}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {attackEffects.map((effect) => (
            <AttackEffect key={effect.id} id={effect.id} type={effect.type} damage={effect.damage} isOvereat={effect.isOvereat} />
          ))}

          {overeatCalories > 0 && (
            <EnergyShield overeatCalories={overeatCalories} maxCalories={dailyCaloriePlan} />
          )}

          {/* 叙事气泡 */}
          {storyBubble.visible && (
            <StoryBubble
              text={storyBubble.text}
              type={storyBubble.type}
              visible={storyBubble.visible}
              onClose={hideStoryBubble}
            />
          )}

          <MonsterAnimation
            emoji={monster.phaseEmoji || monster.emoji}
            isShaking={attackEffects.some((e) => e.isOvereat) || monster.isEnraged}
            isHit={isMonsterHit}
            isDead={monster.hp <= 0}
            hpPercentage={hpPercentage}
          />

          <div className="flex items-center gap-2 mt-2">
            <span className="text-lg font-bold text-text">{monster.name}</span>
            <span className="text-[10px] px-2 py-0.5 bg-gold/20 text-gold rounded-full font-bold">
              Lv.{monster.level}
            </span>
            {(monster.hp <= 0 || daily.monsterDefeated) && (
              <span className="text-[10px] px-2 py-0.5 bg-green/20 text-green rounded-full font-bold">
                今日已击败
              </span>
            )}
            {monster.defId && getMonsterStory(monster.defId) && (
              <motion.button
                whileHover={{ scale: HOVER_SCALE }}
                whileTap={{ scale: TAP_SCALE }}
                onClick={() => setShowStoryModal(true)}
                className="flex items-center gap-1 px-2 py-0.5 bg-purple/10 border border-purple/30 rounded-full hover:bg-purple/20 transition-colors"
              >
                <Scroll size={10} className="text-purple" />
                <span className="text-[10px] font-bold text-purple">故事</span>
              </motion.button>
            )}
            <div className="ml-auto">
              <CompanionAvatar size={40} />
            </div>
          </div>

          <AnimatePresence>
            {companionCheer && (
              <motion.div
                key={companionCheer}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ type: 'spring', stiffness: 300, damping: 20 }}
                className="absolute bottom-16 left-4 z-20"
              >
                <div className="bg-pink/90 border-2 border-pink rounded-xl px-3 py-1.5 shadow-lg">
                  <div className="text-xs font-bold text-white">
                    {companion.emoji} {companionCheer}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="absolute inset-0 pointer-events-none">
            <AnimatePresence>
              {damageNumbers.map((dn) => (
                <DamageNumber key={dn.id} id={dn.id} value={dn.value} type={dn.type} />
              ))}
            </AnimatePresence>
          </div>
        </div>
      </motion.div>

      <div className="flex flex-col gap-2" style={{ height: '25%' }}>
        {(monster.hp <= 0 || daily.monsterDefeated) && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="shrink-0 flex items-center justify-center gap-2 px-3 py-2 bg-green/10 border border-green/30 rounded-xl"
          >
            <Trophy className="w-4 h-4 text-green" />
            <span className="text-xs font-bold text-green">
              今日脂肪怪已击退！继续记录饮食和锻炼保持健康吧~
            </span>
          </motion.div>
        )}
        <div className="grid grid-cols-2 gap-3 h-full">
          {/* 主操作按钮 - 统一 hover 1.02 / tap 0.95 + State Layer */}
          <motion.button
            whileHover={{ scale: HOVER_SCALE }}
            whileTap={{ scale: TAP_SCALE }}
            onClick={() => navigate('/food')}
            className="flex flex-col items-center justify-center gap-1 bg-gradient-to-br from-red/15 to-red-dark/15 border-2 border-red/30 rounded-2xl hover:border-red/60 active:bg-white/[0.12] transition-colors shadow-md hover:shadow-lg"
          >
            <Utensils size={24} className="text-red" />
            <span className="font-bold text-sm text-text">记录饮食</span>
            <span className="text-[10px] text-text3">
              已记录 {daily.intake > 0 ? Math.round(daily.intake) : 0} kcal
            </span>
          </motion.button>

          <motion.button
            whileHover={{ scale: HOVER_SCALE }}
            whileTap={{ scale: TAP_SCALE }}
            onClick={() => navigate('/exercise')}
            className="flex flex-col items-center justify-center gap-1 bg-gradient-to-br from-green/15 to-green-dark/15 border-2 border-green/30 rounded-2xl hover:border-green/60 active:bg-white/[0.12] transition-colors shadow-md hover:shadow-lg"
          >
            <Dumbbell size={24} className="text-green" />
            <span className="font-bold text-sm text-text">锻炼攻击</span>
            <span className="text-[10px] text-text3">
              已消耗 {daily.exerciseBurn > 0 ? Math.round(daily.exerciseBurn) : 0} kcal
            </span>
          </motion.button>
        </div>
      </div>

      {/* 怪物背景故事弹窗 */}
      <AnimatePresence>
        {showStoryModal && monster.defId && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm"
            onClick={() => setShowStoryModal(false)}
          >
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', stiffness: 300, damping: 30 }}
              className="w-full max-w-md bg-card border-t-2 border-purple/30 rounded-t-3xl p-6 max-h-[80vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-black text-text">
                  关于 {monster.name} 的故事
                </h3>
                <button
                  onClick={() => setShowStoryModal(false)}
                  className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-bg2 transition-colors"
                >
                  <X size={18} className="text-text3" />
                </button>
              </div>

              {(() => {
                const story = getMonsterStory(monster.defId!)
                if (!story) return <p className="text-text3 text-sm">暂无故事记录~</p>
                return (
                  <div className="space-y-4">
                    <div className="bg-blue/5 border border-blue/20 rounded-xl p-3">
                      <h4 className="text-xs font-bold text-blue mb-1 flex items-center gap-1">
                        <span>🌟</span> 起源
                      </h4>
                      <p className="text-sm text-text leading-relaxed">{story.origin}</p>
                    </div>
                    <div className="bg-purple/5 border border-purple/20 rounded-xl p-3">
                      <h4 className="text-xs font-bold text-purple mb-1 flex items-center gap-1">
                        <span>📖</span> 传说
                      </h4>
                      <p className="text-sm text-text leading-relaxed">{story.lore}</p>
                    </div>
                    <div className="bg-gold/5 border border-gold/20 rounded-xl p-3">
                      <h4 className="text-xs font-bold text-gold mb-1 flex items-center gap-1">
                        <span>💡</span> 冷知识
                      </h4>
                      <p className="text-sm text-text leading-relaxed">{story.funFact}</p>
                    </div>
                  </div>
                )
              })()}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
