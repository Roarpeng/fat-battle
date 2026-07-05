import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate, useLocation } from 'react-router-dom'
import { Coins, Flame, Utensils, Dumbbell, Target, Settings, Shield, Trophy } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import HpBar from '../components/HpBar'
import { DamageNumber, FloatingText, AttackEffect, MonsterAnimation, EnergyShield } from '../components/BattleEffects'
import { getRandomTaunt, getTauntByTrigger } from '../data/monsterTaunts'
import { getRandomEncouragement } from '../data/encouragements'

type AttackType = 'missile' | 'knife' | 'punch' | 'fireball' | 'lightning' | 'grease' | 'bomb'

interface AttackEffectState {
  id: string
  type: AttackType
  damage: number
  isOvereat: boolean
}

export default function BattlePage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { monster, daily, coins, days, streak, user, setPendingAttack } = useGameStore()
  const [showVictory, setShowVictory] = useState(false)
  const [prevMonsterHp, setPrevMonsterHp] = useState(monster.hp)
  const [damageNumbers, setDamageNumbers] = useState<Array<{ id: string; value: number; type: 'damage' | 'heal' | 'critical' }>>([])
  const [attackEffects, setAttackEffects] = useState<AttackEffectState[]>([])
  const [shieldEffect, setShieldEffect] = useState(false)
  const [isMonsterHit, setIsMonsterHit] = useState(false)
  const [currentTaunt, setCurrentTaunt] = useState<string | null>(null)
  const [currentEncouragement, setCurrentEncouragement] = useState<string | null>(null)
  const [tauntTimer, setTauntTimer] = useState<number | null>(null)
  const [hasPlayedEffects, setHasPlayedEffects] = useState(false)

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

  const showRandomTaunt = useCallback((trigger?: 'high_hp' | 'low_hp' | 'after_damage' | 'after_heal') => {
    if (monster.hp <= 0) return
    let taunt: string
    const monsterType = monster.type || 'slime'
    if (trigger) {
      taunt = getTauntByTrigger(monsterType, trigger)
    } else {
      const hpTrigger = hpPercentage > 0.6 ? 'high_hp' : hpPercentage > 0.3 ? 'after_damage' : 'low_hp'
      taunt = getTauntByTrigger(monsterType, hpTrigger)
    }
    setCurrentTaunt(taunt)
    if (tauntTimer) window.clearTimeout(tauntTimer)
    const timer = window.setTimeout(() => setCurrentTaunt(null), 4500)
    setTauntTimer(timer)
  }, [monster.hp, monster.type, hpPercentage, tauntTimer])

  const showEncouragement = useCallback((type: 'exercise_complete' | 'battle_progress' | 'battle_victory') => {
    const msg = getRandomEncouragement(type)
    setCurrentEncouragement(msg)
    setTimeout(() => setCurrentEncouragement(null), 3000)
  }, [])

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

  const lastNavState = useRef<string>(location.pathname)

  useEffect(() => {
    const prevPath = lastNavState.current
    lastNavState.current = location.pathname
    
    if (location.pathname === '/' && (prevPath === '/food' || prevPath === '/exercise' || prevPath === '/pose')) {
      setHasPlayedEffects(false)
      triggerAttackAnimation()
    }
  }, [location.pathname])

  const triggerAttackAnimation = () => {
    if (hasPlayedEffects) return
    setHasPlayedEffects(true)

    if (daily.pendingAttack) {
      const { pendingAttack } = daily
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

    if (overeatCalories > 0 && !daily.pendingAttack?.isOvereat) {
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

  useEffect(() => {
    if (prevMonsterHp > monster.hp && monster.hp === 0) {
      setShowVictory(true)
      showEncouragement('battle_victory')
    } else if (prevMonsterHp > monster.hp) {
      if (Math.random() > 0.3) showRandomTaunt('after_damage')
      if (hpPercentage < 0.5 && hpPercentage > 0.3) showEncouragement('battle_progress')
    } else if (prevMonsterHp < monster.hp) {
      if (Math.random() > 0.2) showRandomTaunt('after_heal')
    }
    setPrevMonsterHp(monster.hp)
  }, [monster.hp, prevMonsterHp, showRandomTaunt, showEncouragement, hpPercentage])

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
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ type: 'spring', stiffness: 200, damping: 15, delay: 0.3 }}
              className="relative z-10 bg-card border-2 border-gold rounded-3xl p-8 mx-4 max-w-sm w-full text-center"
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
                胜利！
              </motion.h2>

              <motion.p
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.6 }}
                className="text-text2 mb-6"
              >
                你击败了 {monster.name}！
              </motion.p>

              <motion.div
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.7 }}
                className="flex items-center justify-center gap-2 mb-6 py-3 px-4 bg-gold/10 rounded-xl border border-gold/30"
              >
                <Coins className="w-6 h-6 text-gold" />
                <span className="text-gold font-bold text-xl">+{monster.level * 10}</span>
              </motion.div>

              <motion.button
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.8 }}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={handleNextLevel}
                className="w-full py-4 px-6 bg-gradient-to-r from-gold to-gold-dark text-bg font-bold text-lg rounded-2xl shadow-lg shadow-gold/30"
              >
                进入下一关 →
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
            onClick={() => navigate('/settings')}
            className="w-8 h-8 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors"
          >
            <Settings size={16} className="text-text3" />
          </button>
        </div>
      </div>

      <div className="shrink-0 flex items-center gap-2 px-3 py-1.5 bg-card/60 rounded-xl border border-border/50">
        <div className="flex-1 flex items-center gap-1.5">
          <Utensils size={12} className="text-red" />
          <span className="text-[10px] text-text3">摄入</span>
          <span className="text-[10px] font-bold text-text">{Math.round(daily.intake)}</span>
          <span className="text-[10px] text-text3">/ {dailyCaloriePlan}</span>
        </div>
        <div className="w-px h-3 bg-border" />
        <div className="flex-1 flex items-center gap-1.5">
          <Dumbbell size={12} className="text-green" />
          <span className="text-[10px] text-text3">消耗</span>
          <span className="text-[10px] font-bold text-text">{Math.round(daily.exerciseBurn)}</span>
        </div>
        {overeatCalories > 0 && (
          <div className="flex items-center gap-1 px-2 py-0.5 bg-orange/20 rounded-full">
            <Shield size={10} className="text-orange" />
            <span className="text-[10px] font-bold text-orange">超量 {overeatCalories}</span>
          </div>
        )}
      </div>

      <div
        className="flex flex-col bg-card/30 border border-border/50 rounded-3xl overflow-hidden relative"
        style={{ height: '60%' }}
      >
        <div className="shrink-0 px-4 pt-3 pb-1">
          <div className="flex justify-between text-[10px] text-text3 mb-1">
            <span className="font-bold flex items-center gap-1.5">
              {monster.name} Lv.{monster.level}
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
            </span>
            <span>{monster.hp} / {monster.maxHp}</span>
          </div>
          <HpBar current={monster.hp} max={monster.maxHp} size="sm" showText={false} overeatFactor={overeatFactor} />
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

          <MonsterAnimation
            emoji={monster.emoji}
            isShaking={attackEffects.some((e) => e.isOvereat)}
            isHit={isMonsterHit}
            isDead={monster.hp <= 0}
            hpPercentage={hpPercentage}
          />

          <div className="flex items-center gap-2 mt-2">
            <span className="text-lg font-bold text-text">{monster.name}</span>
            <span className="text-[10px] px-2 py-0.5 bg-gold/20 text-gold rounded-full font-bold">
              Lv.{monster.level}
            </span>
          </div>

          <div className="absolute inset-0 pointer-events-none">
            <AnimatePresence>
              {damageNumbers.map((dn) => (
                <DamageNumber key={dn.id} id={dn.id} value={dn.value} type={dn.type} />
              ))}
            </AnimatePresence>
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-2" style={{ height: '25%' }}>
        <div className="grid grid-cols-2 gap-3 h-full">
          <motion.button
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.97 }}
            onClick={() => navigate('/food')}
            className="flex flex-col items-center justify-center gap-1 bg-gradient-to-br from-red/15 to-red-dark/15 border-2 border-red/30 rounded-2xl hover:border-red/60 transition-colors"
          >
            <Utensils size={24} className="text-red" />
            <span className="font-bold text-sm text-text">记录饮食</span>
            <span className="text-[10px] text-text3">
              已记录 {daily.intake > 0 ? Math.round(daily.intake) : 0} kcal
            </span>
          </motion.button>

          <motion.button
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.97 }}
            onClick={() => navigate('/exercise')}
            className="flex flex-col items-center justify-center gap-1 bg-gradient-to-br from-green/15 to-green-dark/15 border-2 border-green/30 rounded-2xl hover:border-green/60 transition-colors"
          >
            <Dumbbell size={24} className="text-green" />
            <span className="font-bold text-sm text-text">锻炼攻击</span>
            <span className="text-[10px] text-text3">
              已消耗 {daily.exerciseBurn > 0 ? Math.round(daily.exerciseBurn) : 0} kcal
            </span>
          </motion.button>
        </div>
      </div>
    </div>
  )
}
