import { useState, useMemo, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, Camera, ScanLine, Plus, X, Trash2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { foods } from '../data/foods'
import { useGameStore } from '../store/useGameStore'
import MiniMonsterCard from '../components/MiniMonsterCard'
import FoodRecognitionModal from '../components/FoodRecognitionModal'

export default function FoodPage() {
  const navigate = useNavigate()
  const { monster, dietRecords, addDietRecord, removeDietRecord, user, customFoods, addCustomFood, removeCustomFood } = useGameStore()
  const [showRecognition, setShowRecognition] = useState(false)
  const [showCustomForm, setShowCustomForm] = useState(false)
  const [customName, setCustomName] = useState('')
  const [customCalories, setCustomCalories] = useState('')
  const [healAnimations, setHealAnimations] = useState<Array<{ id: string; value: number }>>([])

  // 统计最常吃的食物（Top 8）
  const frequentFoods = useMemo(() => {
    const counts = new Map<string, { food: typeof foods[0]; count: number }>()
    // 先加入所有默认食物，count=0
    foods.forEach((f) => counts.set(f.id, { food: f, count: 0 }))
    // 统计历史记录
    dietRecords.forEach((record) => {
      const matched = foods.find((f) => f.name === record.name)
      if (matched) {
        const entry = counts.get(matched.id)
        if (entry) entry.count++
      }
    })
    // 按频率排序，取前8
    return Array.from(counts.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 8)
      .map((e) => e.food)
  }, [dietRecords])

  const addHealAnimation = useCallback((value: number) => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 8)
    setHealAnimations((prev) => [...prev, { id, value }])
    setTimeout(() => {
      setHealAnimations((prev) => prev.filter((h) => h.id !== id))
    }, 800)
  }, [])

  const handleAddFood = (food: typeof foods[0]) => {
    addDietRecord({
      name: food.name,
      calories: food.calories,
      time: Date.now(),
    })
    // 显示卡路里增加提示（不是直接加怪物血量）
    addHealAnimation(food.calories)
    setTimeout(() => navigate('/'), 600)
  }

  const handleAddCustomFood = () => {
    if (!customName || !customCalories) return
    const calories = parseInt(customCalories)
    if (isNaN(calories) || calories <= 0) return

    // 添加到自定义食物库
    const newFood = {
      id: `custom-${Date.now()}`,
      name: customName,
      calories,
      protein: 0,
      carbs: 0,
      fat: 0,
      servingSize: '自定义',
      emoji: '🍽️',
      category: 'snack' as const,
      hpRestore: Math.floor(calories * 0.05),
    }
    addCustomFood(newFood)

    // 添加到饮食记录
    addDietRecord({
      name: customName,
      calories,
      time: Date.now(),
    })
    addHealAnimation(calories)
    setCustomName('')
    setCustomCalories('')
    setShowCustomForm(false)
    setTimeout(() => navigate('/'), 600)
  }

  const handleRecognizedItems = (items: Array<{ name: string; cal: number; actualCal?: number; portion?: string }>) => {
    items.forEach((item) => {
      const cal = item.actualCal || item.cal
      addDietRecord({
        name: item.name,
        calories: cal,
        time: Date.now(),
      })
      addHealAnimation(cal)
    })
    setTimeout(() => navigate('/'), 600)
  }

  const playerMaxHp = 100 + (user.weight - user.targetWeight) * 2
  const playerCurrentHp = Math.max(0, playerMaxHp - monster.hp * 0.5)

  // 今日已记录的食物
  const todayRecords = dietRecords.slice(-5)

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
        <h1 className="text-lg font-bold text-text">记录饮食</h1>
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
        {/* 治疗飘字 */}
        <div className="relative h-0">
          <AnimatePresence>
            {healAnimations.map((anim) => (
              <motion.div
                key={anim.id}
                initial={{ opacity: 1, y: 0 }}
                animate={{ opacity: 0, y: -40 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.8 }}
                className="absolute left-1/2 -translate-x-1/2 text-green font-bold text-lg pointer-events-none"
              >
                +{anim.value} kcal
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      </div>

      {/* ========== 中 1/5：拍照识别入口 ========== */}
      <motion.button
        whileHover={{ scale: 1.02 }}
        whileTap={{ scale: 0.98 }}
        onClick={() => setShowRecognition(true)}
        className="shrink-0 flex items-center justify-center gap-3 py-4 bg-gradient-to-r from-purple/15 to-blue/15 border-2 border-purple/30 rounded-2xl hover:border-purple/60 transition-colors"
      >
        <div className="w-10 h-10 rounded-full bg-purple/20 flex items-center justify-center">
          <Camera size={20} className="text-purple" />
        </div>
        <div className="text-left">
          <div className="font-bold text-sm text-text">拍照识别食物</div>
          <div className="text-[10px] text-text3">AI 自动识别卡路里</div>
        </div>
        <ScanLine size={18} className="text-purple ml-2" />
      </motion.button>

      {/* ========== 下 2/5：经常吃的食物 ========== */}
      <div className="flex-1 flex flex-col min-h-0 overflow-hidden">
        <div className="flex items-center justify-between mb-2 shrink-0">
          <h2 className="text-sm font-bold text-text">经常吃的食物</h2>
          <button
            onClick={() => setShowCustomForm(!showCustomForm)}
            className="flex items-center gap-1 text-[10px] text-purple font-bold px-2 py-1 bg-purple/10 rounded-full hover:bg-purple/20 transition-colors"
          >
            {showCustomForm ? <X size={10} /> : <Plus size={10} />}
            {showCustomForm ? '取消' : '自定义'}
          </button>
        </div>

        {/* 自定义食物表单 */}
        <AnimatePresence>
          {showCustomForm && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="overflow-hidden shrink-0"
            >
              <div className="bg-card border border-border rounded-xl p-3 mb-2 flex gap-2">
                <input
                  type="text"
                  placeholder="食物名称"
                  value={customName}
                  onChange={(e) => setCustomName(e.target.value)}
                  className="flex-1 min-w-0 px-3 py-2 bg-bg2 border border-border rounded-lg text-sm text-text placeholder-text3 focus:outline-none focus:border-purple"
                />
                <input
                  type="number"
                  placeholder="卡路里"
                  value={customCalories}
                  onChange={(e) => setCustomCalories(e.target.value)}
                  className="w-24 px-3 py-2 bg-bg2 border border-border rounded-lg text-sm text-text placeholder-text3 focus:outline-none focus:border-purple"
                />
                <button
                  onClick={handleAddCustomFood}
                  disabled={!customName || !customCalories}
                  className="px-3 py-2 bg-purple text-white rounded-lg text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  添加
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* 食物网格 */}
        <div className="flex-1 overflow-y-auto -mx-1 px-1 scrollbar-hide">
          <div className="grid grid-cols-2 gap-2">
            {frequentFoods.map((food) => (
              <motion.button
                key={food.id}
                whileTap={{ scale: 0.95 }}
                onClick={() => handleAddFood(food)}
                className="flex items-center gap-2 p-2.5 bg-card border border-border rounded-xl hover:border-purple/40 hover:bg-bg2 transition-all text-left"
              >
                <span className="text-xl shrink-0">{food.emoji}</span>
                <div className="flex-1 min-w-0">
                  <div className="text-xs font-bold text-text truncate">{food.name}</div>
                  <div className="text-[10px] text-text3">{food.calories} kcal</div>
                </div>
                <Plus size={14} className="text-purple shrink-0" />
              </motion.button>
            ))}
          </div>

          {/* 今日已记录 */}
          {todayRecords.length > 0 && (
            <div className="mt-3">
              <h3 className="text-[10px] text-text3 mb-1.5">今日已记录</h3>
              <div className="space-y-1.5">
                {todayRecords.map((record) => (
                  <div
                    key={record.id}
                    className="flex items-center justify-between px-3 py-2 bg-bg2/60 rounded-lg"
                  >
                    <span className="text-xs text-text">{record.name}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-text3">{record.calories} kcal</span>
                      <button
                        onClick={() => removeDietRecord(record.id)}
                        className="text-text3 hover:text-red transition-colors"
                      >
                        <Trash2 size={12} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* 食物识别弹窗 */}
      <FoodRecognitionModal
        open={showRecognition}
        onClose={() => setShowRecognition(false)}
        onConfirm={handleRecognizedItems}
        mealType="snack"
      />
    </div>
  )
}
