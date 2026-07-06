import { useState, useMemo, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ArrowLeft, Camera, ScanLine, Plus, X, Trash2, Check } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { foods } from '../data/foods'
import { useGameStore } from '../store/useGameStore'
import MiniMonsterCard from '../components/MiniMonsterCard'
import FoodRecognitionModal from '../components/FoodRecognitionModal'
import { getRandomEncouragement } from '../data/encouragements'

export default function FoodPage() {
  const navigate = useNavigate()
  const { monster, dietRecords, addDietRecord, removeDietRecord, user, customFoods, addCustomFood, removeCustomFood, setPendingAttack, setOvereatCalories, daily } = useGameStore()
  const [showRecognition, setShowRecognition] = useState(false)
  const [showCustomForm, setShowCustomForm] = useState(false)
  const [customName, setCustomName] = useState('')
  const [customCalories, setCustomCalories] = useState('')
  const [healAnimations, setHealAnimations] = useState<Array<{ id: string; value: number }>>([])
  const [currentEncouragement, setCurrentEncouragement] = useState<{ id: string; message: string; type: 'good' | 'warning' } | null>(null)
  const [selectedFoods, setSelectedFoods] = useState<Array<typeof foods[0]>>([])

  const dailyCaloriePlan = useMemo(() => {
    const bmr = 10 * user.weight + 6.25 * user.height - 5 * 25 + 5
    const factor = user.difficulty === 'easy' ? 1.3 : user.difficulty === 'hard' ? 1.1 : 1.2
    return Math.round(bmr * factor)
  }, [user])

  const totalSelectedCalories = useMemo(() => {
    return selectedFoods.reduce((sum, food) => sum + food.calories, 0)
  }, [selectedFoods])

  const totalIntakeWithSelection = daily.intake + totalSelectedCalories
  const currentOvereatCalories = Math.max(0, totalIntakeWithSelection - daily.exerciseBurn - dailyCaloriePlan)

  const frequentFoods = useMemo(() => {
    const counts = new Map<string, { food: typeof foods[0]; count: number }>()
    foods.forEach((f) => counts.set(f.id, { food: f, count: 0 }))
    dietRecords.forEach((record) => {
      const matched = foods.find((f) => f.name === record.name)
      if (matched) {
        const entry = counts.get(matched.id)
        if (entry) entry.count++
      }
    })
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

  const showFoodEncouragement = useCallback((calories: number) => {
    const type = calories <= 150 ? 'food_good' : calories <= 300 ? 'food_good' : 'food_warning'
    const message = getRandomEncouragement(type)
    const id = Date.now().toString()
    setCurrentEncouragement({ id, message, type: type === 'food_good' ? 'good' : 'warning' })
    setTimeout(() => setCurrentEncouragement(null), 2500)
  }, [])

  const toggleFoodSelection = (food: typeof foods[0]) => {
    setSelectedFoods((prev) => {
      const exists = prev.find((f) => f.id === food.id)
      if (exists) {
        return prev.filter((f) => f.id !== food.id)
      } else {
        return [...prev, food]
      }
    })
  }

  const handleSubmitSelection = () => {
    if (selectedFoods.length === 0) return

    selectedFoods.forEach((food) => {
      addDietRecord({
        name: food.name,
        calories: food.calories,
        time: Date.now(),
      })
      addHealAnimation(food.calories)
    })

    if (currentOvereatCalories > 0) {
      setOvereatCalories(currentOvereatCalories)
      setPendingAttack({
        damage: 0,
        attackType: 'grease',
        isOvereat: true,
        overeatCalories: currentOvereatCalories,
      })
    }

    showFoodEncouragement(totalSelectedCalories)
    setSelectedFoods([])
    setTimeout(() => navigate('/'), 800)
  }

  const handleAddCustomFood = () => {
    if (!customName || !customCalories) return
    const calories = parseInt(customCalories)
    if (isNaN(calories) || calories <= 0) return

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

    addDietRecord({
      name: customName,
      calories,
      time: Date.now(),
    })

    const newOvereat = Math.max(0, daily.intake + calories - daily.exerciseBurn - dailyCaloriePlan)
    if (newOvereat > 0) {
      setOvereatCalories(newOvereat)
      setPendingAttack({
        damage: 0,
        attackType: 'grease',
        isOvereat: true,
        overeatCalories: newOvereat,
      })
    }

    addHealAnimation(calories)
    showFoodEncouragement(calories)
    setCustomName('')
    setCustomCalories('')
    setShowCustomForm(false)
    setTimeout(() => navigate('/'), 800)
  }

  const handleRecognizedItems = (items: Array<{ name: string; cal: number; actualCal?: number; portion?: string }>) => {
    let totalCalories = 0
    items.forEach((item) => {
      const cal = item.actualCal || item.cal
      totalCalories += cal
      addDietRecord({
        name: item.name,
        calories: cal,
        time: Date.now(),
      })
      addHealAnimation(cal)
    })

    const newOvereat = Math.max(0, daily.intake + totalCalories - daily.exerciseBurn - dailyCaloriePlan)
    if (newOvereat > 0) {
      setOvereatCalories(newOvereat)
      setPendingAttack({
        damage: 0,
        attackType: 'grease',
        isOvereat: true,
        overeatCalories: newOvereat,
      })
    }

    showFoodEncouragement(totalCalories)
    setTimeout(() => navigate('/'), 800)
  }

  const todayRecords = dietRecords.slice(-5)

  return (
    <div className="min-h-full flex flex-col px-4 py-3 gap-3 max-w-[480px] mx-auto">
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

      <div className="shrink-0 relative">
        <MiniMonsterCard
          emoji={monster.emoji}
          name={monster.name}
          level={monster.level}
          currentHp={monster.hp}
          maxHp={monster.maxHp}
          overeatCalories={currentOvereatCalories}
          maxOvereat={dailyCaloriePlan}
        />

        <AnimatePresence>
          {currentEncouragement && (
            <motion.div
              key={currentEncouragement.id}
              initial={{ opacity: 0, y: 20, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -10, scale: 0.9 }}
              transition={{ type: 'spring', stiffness: 300, damping: 20 }}
              className={`absolute -bottom-8 left-1/2 -translate-x-1/2 z-10 px-4 py-2 rounded-xl shadow-lg border-2 ${
                currentEncouragement.type === 'good' 
                  ? 'bg-green/90 border-green text-white' 
                  : 'bg-orange/90 border-orange text-white'
              }`}
            >
              <span className="text-xs font-bold">
                {currentEncouragement.type === 'good' ? '✨' : '⚠️'} {currentEncouragement.message}
              </span>
            </motion.div>
          )}
        </AnimatePresence>

        <div className="relative h-0 mt-8">
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

      <AnimatePresence>
        {selectedFoods.length > 0 && (
          <motion.div
            key="selection-bar"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="shrink-0 overflow-hidden"
          >
            <div className="bg-card border-2 border-purple/50 rounded-xl p-3">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-bold text-text">已选择 {selectedFoods.length} 项</span>
                <button
                  onClick={() => setSelectedFoods([])}
                  className="text-text3 hover:text-text text-xs flex items-center gap-1"
                >
                  <X size={12} /> 清空
                </button>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xs text-text3">总卡路里:</span>
                  <span className={`text-lg font-bold ${totalSelectedCalories > 300 ? 'text-red' : totalSelectedCalories > 150 ? 'text-yellow' : 'text-green'}`}>
                    {totalSelectedCalories} kcal
                  </span>
                </div>
                {currentOvereatCalories > 0 && (
                  <span className="text-xs text-orange font-bold">
                    ⚠️ 超量 {currentOvereatCalories} kcal
                  </span>
                )}
              </div>
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={handleSubmitSelection}
                className="w-full mt-3 py-2.5 bg-gradient-to-r from-purple to-purple-dark text-white font-bold rounded-xl flex items-center justify-center gap-2"
              >
                <Check size={16} />
                确认提交
              </motion.button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

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

        <div className="flex-1 overflow-y-auto -mx-1 px-1 scrollbar-hide">
          <div className="grid grid-cols-2 gap-2">
            {frequentFoods.map((food) => {
              const isSelected = selectedFoods.some((f) => f.id === food.id)
              return (
                <motion.button
                  key={food.id}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => toggleFoodSelection(food)}
                  className={`flex items-center gap-2 p-2.5 border rounded-xl hover:bg-bg2 transition-all text-left relative ${
                    isSelected
                      ? 'border-purple/60 bg-purple/10'
                      : food.calories > 300 
                        ? 'border-red/30 hover:border-red/50' 
                        : food.calories > 150 
                          ? 'border-yellow/30 hover:border-yellow/50' 
                          : 'border-green/30 hover:border-green/50'
                  }`}
                >
                  {isSelected && (
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      className="absolute top-1 right-1 w-4 h-4 bg-purple rounded-full flex items-center justify-center"
                    >
                      <Check size={8} className="text-white" />
                    </motion.div>
                  )}
                  <span className="text-xl shrink-0">{food.emoji}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs font-bold text-text truncate">{food.name}</div>
                    <div className={`text-[10px] font-bold ${
                      food.calories > 300 ? 'text-red' : food.calories > 150 ? 'text-yellow' : 'text-green'
                    }`}>
                      {food.calories} kcal
                    </div>
                  </div>
                  <Plus size={14} className={`shrink-0 ${isSelected ? 'text-purple' : 'text-text3'}`} />
                </motion.button>
              )
            })}
          </div>

          {todayRecords.length > 0 && (
            <div className="mt-3">
              <h3 className="text-[10px] text-text3 mb-1.5">今日已记录</h3>
              <div className="space-y-1.5">
                {todayRecords.map((record) => (
                  <motion.div
                    key={record.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="flex items-center justify-between px-3 py-2 bg-bg2/60 rounded-lg"
                  >
                    <span className="text-xs text-text">{record.name}</span>
                    <div className="flex items-center gap-2">
                      <span className="text-xs text-text3">{record.calories} kcal</span>
                      <motion.button
                        whileTap={{ scale: 0.9 }}
                        onClick={() => removeDietRecord(record.id)}
                        className="text-text3 hover:text-red transition-colors"
                      >
                        <Trash2 size={12} />
                      </motion.button>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      <FoodRecognitionModal
        open={showRecognition}
        onClose={() => setShowRecognition(false)}
        onConfirm={handleRecognizedItems}
        mealType="snack"
      />
    </div>
  )
}
