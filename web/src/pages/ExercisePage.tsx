import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import { ArrowLeft, Camera, PenLine, Swords, Zap, Clock, Plus, X, Trash2 } from 'lucide-react'
import { exercises } from '../data/exercises'
import { useGameStore } from '../store/useGameStore'
import MiniMonsterCard from '../components/MiniMonsterCard'

export default function ExercisePage() {
  const navigate = useNavigate()
  const { monster, addExerciseRecord, user, customExercises, addCustomExercise, removeCustomExercise } = useGameStore()

  const [selected, setSelected] = useState<(typeof exercises)[0] | null>(null)
  const [duration, setDuration] = useState(30)
  const [damageValue, setDamageValue] = useState(0)
  const [showDamage, setShowDamage] = useState(false)
  const [showCustomForm, setShowCustomForm] = useState(false)
  const [customName, setCustomName] = useState('')
  const [customCalories, setCustomCalories] = useState('')
  const [customDamage, setCustomDamage] = useState('')

  // 合并默认运动和自定义运动
  const allExercises = [...exercises, ...customExercises]

  const estimatedCalories = selected
    ? Math.round(((selected.caloriesPerMinute / 3.5) * 3.5 * user.weight * (duration / 60)))
    : 0

  const estimatedDamage = selected
    ? Math.round(
        selected.damagePerMinute * (duration / 60) *
        (1 + (user.difficulty === 'easy' ? 0.8 : user.difficulty === 'hard' ? 1.2 : 1))
      )
    : 0

  const handleSelect = (exercise: (typeof exercises)[0]) => {
    setSelected(exercise)
    setDuration(30)
  }

  const handleAttack = () => {
    if (!selected) return

    addExerciseRecord({
      name: selected.name,
      calories: estimatedCalories,
      time: Date.now(),
      reps: duration,
    })

    // 不直接攻击怪物，只记录运动消耗的卡路里
    // 伤害由首页特效计算并触发
    setDamageValue(estimatedDamage)
    setShowDamage(true)
    setTimeout(() => setShowDamage(false), 800)
    setTimeout(() => navigate('/'), 900)
  }

  const handleAddCustomExercise = () => {
    if (!customName || !customCalories || !customDamage) return
    const cal = parseInt(customCalories)
    const dmg = parseInt(customDamage)
    if (isNaN(cal) || cal <= 0 || isNaN(dmg) || dmg <= 0) return

    const newExercise = {
      id: `custom-ex-${Date.now()}`,
      type: 'running' as const,
      name: customName,
      emoji: '🏃',
      caloriesPerMinute: cal,
      damagePerMinute: dmg,
      difficulty: 'medium' as const,
      description: '自定义运动',
    }
    addCustomExercise(newExercise)
    setCustomName('')
    setCustomCalories('')
    setCustomDamage('')
    setShowCustomForm(false)
  }

  return (
    <div className="min-h-full flex flex-col px-4 py-3 gap-3 max-w-[480px] mx-auto">
      {/* 顶部返回 + 标题 */}
      <div className="flex items-center justify-between shrink-0">
        <button
          onClick={() => navigate('/')}
          className="w-9 h-9 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors"
        >
          <ArrowLeft size={18} className="text-text" />
        </button>
        <h1 className="text-lg font-bold text-text">锻炼攻击</h1>
        <div className="w-9" />
      </div>

      {/* ========== 上 2/5：怪物区域 ========== */}
      <div className="shrink-0">
        <MiniMonsterCard
          emoji={monster.emoji}
          name={monster.name}
          level={monster.level}
          currentHp={monster.hp}
          maxHp={monster.maxHp}
        />
      </div>

      {/* ========== 中 1/5：摄像头/手动记录入口 ========== */}
      <div className="shrink-0 grid grid-cols-2 gap-3">
        <motion.button
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          onClick={() => navigate('/pose')}
          className="flex flex-col items-center justify-center gap-1.5 py-3 bg-gradient-to-br from-blue/15 to-purple/15 border-2 border-blue/30 rounded-2xl hover:border-blue/60 transition-colors"
        >
          <Camera size={24} className="text-blue" />
          <span className="font-bold text-sm text-text">摄像头检测</span>
          <span className="text-[9px] text-text3">AI 动作识别</span>
        </motion.button>

        <motion.button
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          onClick={() => setShowCustomForm(!showCustomForm)}
          className="flex flex-col items-center justify-center gap-1.5 py-3 bg-gradient-to-br from-green/15 to-green-dark/15 border-2 border-green/30 rounded-2xl hover:border-green/60 transition-colors"
        >
          <PenLine size={24} className="text-green" />
          <span className="font-bold text-sm text-text">手动记录</span>
          <span className="text-[9px] text-text3">自定义运动</span>
        </motion.button>
      </div>

      {/* ========== 下 2/5：运动列表 ========== */}
      <div className="flex-1 flex flex-col min-h-0 overflow-hidden">
        {/* 自定义运动表单 */}
        <AnimatePresence>
          {showCustomForm && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden shrink-0"
            >
              <div className="bg-card border border-border rounded-xl p-3 mb-2 flex flex-col gap-2">
                <input
                  type="text"
                  placeholder="运动名称"
                  value={customName}
                  onChange={(e) => setCustomName(e.target.value)}
                  className="px-3 py-2 bg-bg2 border border-border rounded-lg text-sm text-text placeholder-text3 focus:outline-none focus:border-green"
                />
                <div className="flex gap-2">
                  <input
                    type="number"
                    placeholder="每分钟卡路里"
                    value={customCalories}
                    onChange={(e) => setCustomCalories(e.target.value)}
                    className="flex-1 px-3 py-2 bg-bg2 border border-border rounded-lg text-sm text-text placeholder-text3 focus:outline-none focus:border-green"
                  />
                  <input
                    type="number"
                    placeholder="每分钟伤害"
                    value={customDamage}
                    onChange={(e) => setCustomDamage(e.target.value)}
                    className="flex-1 px-3 py-2 bg-bg2 border border-border rounded-lg text-sm text-text placeholder-text3 focus:outline-none focus:border-green"
                  />
                </div>
                <button
                  onClick={handleAddCustomExercise}
                  disabled={!customName || !customCalories || !customDamage}
                  className="py-2 bg-green text-white rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  添加运动
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* 已选运动的伤害预览 */}
        <AnimatePresence>
          {selected && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden shrink-0"
            >
              <div className="bg-card border border-border rounded-xl p-3 mb-2">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span className="text-xl">{selected.emoji}</span>
                    <span className="font-bold text-sm text-text">{selected.name}</span>
                  </div>
                  <button
                    onClick={() => setSelected(null)}
                    className="text-text3 hover:text-text"
                  >
                    <X size={16} />
                  </button>
                </div>

                {/* 时长滑块 */}
                <div className="flex items-center gap-3 mb-2">
                  <Clock size={14} className="text-text3 shrink-0" />
                  <input
                    type="range"
                    min={5}
                    max={120}
                    step={5}
                    value={duration}
                    onChange={(e) => setDuration(Number(e.target.value))}
                    className="flex-1 accent-green"
                  />
                  <span className="text-xs font-bold text-text w-12 text-right">{duration}分</span>
                </div>

                {/* 预览数据 */}
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-1 text-xs text-text3">
                    <Zap size={12} className="text-orange" />
                    <span>{estimatedCalories} kcal</span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Swords size={14} className="text-red" />
                    <span className="text-sm font-bold text-red">{estimatedDamage}</span>
                    <span className="text-xs text-text3">伤害</span>
                  </div>
                </div>

                {/* 攻击按钮 */}
                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={handleAttack}
                  className="w-full py-2.5 bg-gradient-to-r from-red to-red-dark text-white font-bold rounded-xl flex items-center justify-center gap-2 shadow-md shadow-red/20"
                >
                  <Swords size={18} />
                  攻击脂肪怪！
                </motion.button>

                {/* 伤害飘字 */}
                <AnimatePresence>
                  {showDamage && (
                    <motion.div
                      initial={{ opacity: 1, y: 0 }}
                      animate={{ opacity: 0, y: -40 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.8 }}
                      className="text-center mt-1"
                    >
                      <span className="text-red font-bold text-lg">-{damageValue}</span>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* 运动列表 */}
        <div className="flex items-center justify-between mb-2 shrink-0">
          <h2 className="text-sm font-bold text-text">选择运动</h2>
          <span className="text-[10px] text-text3">{allExercises.length} 个运动</span>
        </div>

        <div className="flex-1 overflow-y-auto -mx-1 px-1 scrollbar-hide">
          <div className="grid grid-cols-2 gap-2">
            {allExercises.map((exercise) => (
              <motion.button
                key={exercise.id}
                whileTap={{ scale: 0.95 }}
                onClick={() => handleSelect(exercise)}
                className={`flex items-center gap-2 p-2.5 border rounded-xl text-left transition-all ${
                  selected?.id === exercise.id
                    ? 'bg-green/10 border-green/60'
                    : 'bg-card border-border hover:border-green/40 hover:bg-bg2'
                }`}
              >
                <span className="text-xl shrink-0">{exercise.emoji}</span>
                <div className="flex-1 min-w-0">
                  <div className="text-xs font-bold text-text truncate">{exercise.name}</div>
                  <div className="text-[10px] text-text3">{exercise.damagePerMinute}/分 伤害</div>
                </div>
                {exercise.id.startsWith('custom-') && (
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      removeCustomExercise(exercise.id)
                      if (selected?.id === exercise.id) setSelected(null)
                    }}
                    className="text-text3 hover:text-red shrink-0"
                  >
                    <Trash2 size={12} />
                  </button>
                )}
              </motion.button>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
