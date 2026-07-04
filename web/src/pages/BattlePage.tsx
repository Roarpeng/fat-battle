import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import { Coins, Flame, Utensils, Dumbbell, Zap, Target, TrendingUp, Trophy } from 'lucide-react'
import { useGameStore } from '../store/useGameStore'
import MonsterCard from '../components/MonsterCard'
import HpBar from '../components/HpBar'
import Card from '../components/Card'

export default function BattlePage() {
  const navigate = useNavigate()
  const { monster, daily, coins, days, streak, user, attackMonster } = useGameStore()
  const [showVictory, setShowVictory] = useState(false)
  const [prevMonsterHp, setPrevMonsterHp] = useState(monster.hp)
  const [damageNumbers, setDamageNumbers] = useState<Array<{ id: string; value: number; type: 'damage' | 'heal' }>>([])

  const playerMaxHp = 100 + (user.weight - user.targetWeight) * 2
  const playerCurrentHp = Math.max(0, playerMaxHp - daily.intake * 0.1 + daily.exerciseBurn * 0.2)

  const netIntake = daily.intake - daily.exerciseBurn

  useEffect(() => {
    if (prevMonsterHp > monster.hp && monster.hp === 0) {
      setShowVictory(true)
    }
    setPrevMonsterHp(monster.hp)
  }, [monster.hp, prevMonsterHp])

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

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4">
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

      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="flex items-center justify-between"
      >
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-card border border-border rounded-full">
            <Target className="w-4 h-4 text-purple" />
            <span className="font-bold text-sm">Day {days}</span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {streak > 0 && (
            <div className="flex items-center gap-1.5 px-3 py-1.5 bg-card border border-border rounded-full">
              <Flame className="w-4 h-4 text-orange" />
              <span className="font-bold text-sm text-orange">{streak}天</span>
            </div>
          )}
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-card border border-border rounded-full">
            <Coins className="w-4 h-4 text-gold" />
            <span className="font-bold text-sm text-gold">{coins}</span>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3, delay: 0.1 }}
      >
        <MonsterCard
          emoji={monster.emoji}
          name={monster.name}
          level={monster.level}
          currentHp={monster.hp}
          maxHp={monster.maxHp}
          damageNumbers={damageNumbers}
        />
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.2 }}
      >
        <Card className="flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-sm font-bold text-text2 flex items-center gap-1.5">
              <Zap className="w-4 h-4 text-green" />
              体力值
            </span>
            <span className="text-xs text-text3">
              {Math.round(playerCurrentHp)} / {Math.round(playerMaxHp)}
            </span>
          </div>
          <HpBar current={playerCurrentHp} max={playerMaxHp} color="green" size="md" showText={false} />
        </Card>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.3 }}
      >
        <Card className="flex flex-col gap-3">
          <h3 className="font-bold text-text flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-purple" />
            今日战况
          </h3>

          <div className="grid grid-cols-2 gap-3">
            <div className="bg-bg2 rounded-xl p-3">
              <div className="flex items-center gap-1.5 mb-1">
                <Utensils className="w-4 h-4 text-red" />
                <span className="text-xs text-text3">摄入</span>
              </div>
              <div className="text-xl font-bold text-text">{Math.round(daily.intake)}<span className="text-xs font-normal text-text3 ml-1">kcal</span></div>
            </div>

            <div className="bg-bg2 rounded-xl p-3">
              <div className="flex items-center gap-1.5 mb-1">
                <Dumbbell className="w-4 h-4 text-green" />
                <span className="text-xs text-text3">锻炼</span>
              </div>
              <div className="text-xl font-bold text-text">{Math.round(daily.exerciseBurn)}<span className="text-xs font-normal text-text3 ml-1">kcal</span></div>
            </div>

            <div className="bg-bg2 rounded-xl p-3">
              <div className="flex items-center gap-1.5 mb-1">
                <Flame className="w-4 h-4 text-orange" />
                <span className="text-xs text-text3">净摄入</span>
              </div>
              <div className={`text-xl font-bold ${netIntake > 0 ? 'text-red' : 'text-green'}`}>
                {netIntake > 0 ? '+' : ''}{Math.round(netIntake)}
                <span className="text-xs font-normal text-text3 ml-1">kcal</span>
              </div>
            </div>

            <div className="bg-bg2 rounded-xl p-3">
              <div className="flex items-center gap-1.5 mb-1">
                <Zap className="w-4 h-4 text-purple" />
                <span className="text-xs text-text3">伤害</span>
              </div>
              <div className="text-xl font-bold text-purple">{Math.round(daily.damage)}<span className="text-xs font-normal text-text3 ml-1">点</span></div>
            </div>
          </div>
        </Card>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.4 }}
        className="grid grid-cols-2 gap-3 mt-auto"
      >
        <motion.button
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          onClick={() => navigate('/food')}
          className="flex flex-col items-center justify-center gap-2 py-6 px-4 bg-gradient-to-br from-red/20 to-red-dark/20 border border-red/30 rounded-2xl hover:border-red/50 transition-colors"
        >
          <span className="text-4xl">🍽️</span>
          <span className="font-bold text-text">记录饮食</span>
          <span className="text-xs text-text3">怪物回血</span>
        </motion.button>

        <motion.button
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          onClick={() => navigate('/exercise')}
          className="flex flex-col items-center justify-center gap-2 py-6 px-4 bg-gradient-to-br from-green/20 to-green-dark/20 border border-green/30 rounded-2xl hover:border-green/50 transition-colors"
        >
          <span className="text-4xl">🏋️</span>
          <span className="font-bold text-text">锻炼攻击</span>
          <span className="text-xs text-text3">对怪物造成伤害</span>
        </motion.button>
      </motion.div>
    </div>
  )
}
