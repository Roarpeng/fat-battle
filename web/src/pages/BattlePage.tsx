import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate, useLocation } from 'react-router-dom'
import { Coins, Flame, Utensils, Dumbbell, Target, Settings, Shield } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import HpBar from '../components/HpBar'

// ========== 攻击特效类型 ==========
type AttackType = 'missile' | 'knife' | 'punch' | 'grease'

interface AttackEffect {
  id: string
  type: AttackType
  damage: number
  isOvereat: boolean
}

export default function BattlePage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { monster, daily, coins, days, streak, user } = useGameStore()
  const [showVictory, setShowVictory] = useState(false)
  const [prevMonsterHp, setPrevMonsterHp] = useState(monster.hp)
  const [damageNumbers, setDamageNumbers] = useState<Array<{ id: string; value: number; type: 'damage' | 'heal' }>>([])
  const [attackEffects, setAttackEffects] = useState<AttackEffect[]>([])
  const [shieldEffect, setShieldEffect] = useState(false)

  // 每日卡路里计划（根据用户BMI和难度计算）
  const dailyCaloriePlan = useMemo(() => {
    const bmr = 10 * user.weight + 6.25 * user.height - 5 * 25 + 5 // 简化BMR
    const factor = user.difficulty === 'easy' ? 1.3 : user.difficulty === 'hard' ? 1.1 : 1.2
    return Math.round(bmr * factor)
  }, [user])

  // 净卡路里 = 摄入 - 消耗
  const netCalories = daily.intake - daily.exerciseBurn
  // 超量卡路里 = 净卡路里 - 计划
  const overeatCalories = Math.max(0, netCalories - dailyCaloriePlan)
  // 运动消耗产生的攻击能量
  const exerciseDamage = Math.floor(daily.exerciseBurn * 0.3)

  // ========== 怪物嘲讽台词系统 ==========
  const [currentTaunt, setCurrentTaunt] = useState<string | null>(null)
  const [tauntTimer, setTauntTimer] = useState<number | null>(null)

  const taunts = useMemo(() => [
    '就这点本事？还不够我塞牙缝的！',
    '你吃的是饲料吗？怎么越来越胖了？',
    '来啊！打我啊！我血厚得很呢！',
    '今天的运动量还不如我翻个身...',
    '哼，你确定要吃那个？我会变得更强的！',
    '减什么肥？躺平多舒服啊~',
    '你的毅力呢？就这点程度？',
    '我感觉到你在变弱...哈哈哈！',
    '再来点甜点！让我长长个！',
    '运动？就你那三脚猫功夫？',
    '我已经在这里等了好久了，你怎么还没打败我？',
    '吃得多动得少，你的脂肪在欢呼呢！',
    '想打败我？先去跑十圈再说吧！',
    '我已经看到你在偷懒了，别装了！',
    '你越吃我越强，这个循环很美妙吧？',
  ], [])

  const showRandomTaunt = useCallback(() => {
    if (monster.hp <= 0) return
    const randomTaunt = taunts[Math.floor(Math.random() * taunts.length)]
    setCurrentTaunt(randomTaunt)
    if (tauntTimer) window.clearTimeout(tauntTimer)
    const timer = window.setTimeout(() => setCurrentTaunt(null), 4500)
    setTauntTimer(timer)
  }, [monster.hp, taunts, tauntTimer])

  useEffect(() => {
    if (monster.hp <= 0) {
      setCurrentTaunt(null)
      return
    }
    const interval = window.setInterval(() => {
      if (Math.random() > 0.3) showRandomTaunt()
    }, 8000 + Math.random() * 7000)
    return () => clearInterval(interval)
  }, [monster.hp, showRandomTaunt])

  // ========== 检测从 Food/Exercise 页面跳回 ==========
  const lastNavState = useRef<string>('')

  useEffect(() => {
    const navKey = location.pathname + Date.now()
    // 当从 /food 或 /exercise 跳回首页时，触发攻击特效
    if (lastNavState.current === '/food' || lastNavState.current === '/exercise') {
      triggerAttackAnimation()
    }
    lastNavState.current = location.pathname
  }, [location.pathname])

  const triggerAttackAnimation = () => {
    // 运动消耗 -> 攻击怪物
    if (exerciseDamage > 0) {
      const attackTypes: AttackType[] = ['missile', 'knife', 'punch']
      const randomType = attackTypes[Math.floor(Math.random() * attackTypes.length)]
      const effectId = Date.now().toString() + Math.random().toString(36).slice(2, 6)
      setAttackEffects((prev) => [...prev, { id: effectId, type: randomType, damage: exerciseDamage, isOvereat: false }])

      // 延迟后扣血
      setTimeout(() => {
        const { attackMonster } = useGameStore.getState()
        attackMonster(exerciseDamage)
        addDamageNumber(exerciseDamage, 'damage')
      }, 600)

      setTimeout(() => {
        setAttackEffects((prev) => prev.filter((e) => e.id !== effectId))
      }, 1500)
    }

    // 超量卡路里 -> 油腻泼洒加防御
    if (overeatCalories > 0) {
      const greaseId = Date.now().toString() + 'grease'
      setAttackEffects((prev) => [...prev, { id: greaseId, type: 'grease', damage: 0, isOvereat: true }])
      setShieldEffect(true)

      // 油腻增加怪物防御（临时增加maxHp的10%）
      const healAmount = Math.floor(overeatCalories * 0.05)
      if (healAmount > 0) {
        setTimeout(() => {
          const { healMonster } = useGameStore.getState()
          // 只回血，不超过maxHp
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
    } else if (prevMonsterHp > monster.hp) {
      if (Math.random() > 0.4) showRandomTaunt()
    } else if (prevMonsterHp < monster.hp) {
      if (Math.random() > 0.3) showRandomTaunt()
    }
    setPrevMonsterHp(monster.hp)
  }, [monster.hp, prevMonsterHp, showRandomTaunt])

  const addDamageNumber = (value: number, type: 'damage' | 'heal') => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 8)
    setDamageNumbers((prev) => [...prev, { id, value, type }])
    setTimeout(() => {
      setDamageNumbers((prev) => prev.filter((d) => d.id !== id))
    }, 800)
  }

  const handleNextLevel = () => {
    setShowVictory(false)
  }

  const coinRain = Array.from({ length: 20 }, (_, i) => ({
    id: i,
    left: Math.random() * 100,
    delay: Math.random() * 2,
    duration: 2 + Math.random() * 2,
    size: 20 + Math.random() * 20,
  }))

  // 攻击特效渲染
  const renderAttackEffect = (effect: AttackEffect) => {
    if (effect.type === 'grease') {
      return (
        <motion.div
          key={effect.id}
          initial={{ y: -200, opacity: 0, scale: 0.5 }}
          animate={{ y: 0, opacity: 1, scale: 1.5 }}
          exit={{ opacity: 0, scale: 2 }}
          transition={{ duration: 0.8, ease: 'easeOut' }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-6xl z-30 pointer-events-none"
        >
          🛢️
        </motion.div>
      )
    }

    const icons = { missile: '🚀', knife: '🗡️', punch: '👊' }
    const labels = { missile: '导弹出击！', knife: '飞刀连射！', punch: '重拳出击！' }

    return (
      <div key={effect.id} className="absolute inset-0 pointer-events-none z-30">
        {/* 飞行物 */}
        <motion.div
          initial={{ x: -150, y: 50, opacity: 0, rotate: -45 }}
          animate={{ x: 0, y: 0, opacity: 1, rotate: 0 }}
          exit={{ opacity: 0, scale: 2 }}
          transition={{ duration: 0.5, ease: 'easeIn' }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-5xl"
        >
          {icons[effect.type]}
        </motion.div>

        {/* 攻击标签 */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0 }}
          transition={{ delay: 0.3 }}
          className="absolute top-4 left-1/2 -translate-x-1/2 bg-red/90 text-white text-xs font-bold px-3 py-1 rounded-full whitespace-nowrap"
        >
          {labels[effect.type]} -{effect.damage}
        </motion.div>

        {/* 爆炸效果 */}
        <motion.div
          initial={{ scale: 0, opacity: 1 }}
          animate={{ scale: 3, opacity: 0 }}
          transition={{ delay: 0.5, duration: 0.4 }}
          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-20 h-20 rounded-full bg-orange/40"
        />
      </div>
    )
  }

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

      {/* 顶部栏 */}
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

      {/* 卡路里状态条 */}
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

      {/* ========== 怪物战斗区域 — 强制占 2/3 高度 ========== */}
      <div
        className="flex flex-col bg-card/30 border border-border/50 rounded-3xl overflow-hidden relative"
        style={{ height: '60%' }}
      >
        {/* 血条 + 防御标识 */}
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
          <HpBar current={monster.hp} max={monster.maxHp} size="sm" showText={false} />
        </div>

        {/* 怪物主体 — 撑满剩余空间 */}
        <div className="flex-1 flex flex-col items-center justify-center relative px-4 min-h-0">
          {/* 嘲讽气泡 */}
          <AnimatePresence>
            {currentTaunt && monster.hp > 0 && (
              <motion.div
                key={currentTaunt}
                initial={{ opacity: 0, y: 10, scale: 0.9 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -10, scale: 0.9 }}
                transition={{ type: 'spring', stiffness: 300, damping: 20 }}
                className="absolute top-2 left-1/2 -translate-x-1/2 z-20 w-[92%]"
              >
                <div className="relative bg-card border border-red/40 rounded-xl px-3 py-1.5 shadow-lg">
                  <div className="text-[11px] font-bold text-red text-center leading-snug">
                    💬 {currentTaunt}
                  </div>
                  <div className="absolute -bottom-1.5 left-1/2 -translate-x-1/2 w-3 h-3 bg-card border-r border-b border-red/40 rotate-45" />
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* 攻击特效层 */}
          {attackEffects.map(renderAttackEffect)}

          {/* 怪物 emoji — 放大 + 受击抖动 */}
          <motion.div
            animate={
              attackEffects.some((e) => !e.isOvereat)
                ? { x: [0, -8, 8, -6, 6, -3, 3, 0], scale: [1, 0.9, 1.1, 1] }
                : { y: [0, -8, 0] }
            }
            transition={
              attackEffects.some((e) => !e.isOvereat)
                ? { duration: 0.5 }
                : { duration: 2.5, repeat: Infinity, ease: 'easeInOut' }
            }
            className="text-8xl select-none"
          >
            {monster.emoji}
          </motion.div>

          {/* 名字 + 等级 */}
          <div className="flex items-center gap-2 mt-2">
            <span className="text-lg font-bold text-text">{monster.name}</span>
            <span className="text-[10px] px-2 py-0.5 bg-gold/20 text-gold rounded-full font-bold">
              Lv.{monster.level}
            </span>
          </div>

          {/* 伤害飘字 */}
          <div className="absolute inset-0 pointer-events-none">
            <AnimatePresence>
              {damageNumbers.map((dn) => (
                <motion.div
                  key={dn.id}
                  initial={{ opacity: 1, y: 0, scale: 0.5 }}
                  animate={{ opacity: 0, y: -60, scale: 1.5 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.8 }}
                  className={`absolute top-1/2 left-1/2 -translate-x-1/2 text-2xl font-black ${dn.type === 'damage' ? 'text-red' : 'text-green'}`}
                >
                  {dn.type === 'damage' ? '-' : '+'}{dn.value}
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </div>
      </div>

      {/* ========== 操作区域 — 强制占 1/3 高度 ========== */}
      <div className="flex flex-col gap-2" style={{ height: '25%' }}>
        <div className="grid grid-cols-2 gap-3 h-full">
          {/* 饮食按钮 */}
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

          {/* 锻炼按钮 */}
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
