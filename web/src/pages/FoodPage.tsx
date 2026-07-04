import { useState, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Search, Plus, Trash2, Utensils, Coffee, Pizza, Cookie, X, Target, Flame, Camera, ScanLine } from 'lucide-react'
import { foods } from '../data/foods'
import { useGameStore } from '../store/useGameStore'
import Card from '../components/Card'
import HpBar from '../components/HpBar'
import FoodRecognitionModal from '../components/FoodRecognitionModal'

type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack'

const mealTabs: { type: MealType; label: string; icon: typeof Utensils }[] = [
  { type: 'breakfast', label: '早餐', icon: Coffee },
  { type: 'lunch', label: '午餐', icon: Utensils },
  { type: 'dinner', label: '晚餐', icon: Pizza },
  { type: 'snack', label: '零食', icon: Cookie },
]

const dailyTarget = 2000

export default function FoodPage() {
  const { daily, dietRecords, addDietRecord, removeDietRecord, user } = useGameStore()
  const [activeMeal, setActiveMeal] = useState<MealType>('breakfast')
  const [searchQuery, setSearchQuery] = useState('')
  const [healAnimations, setHealAnimations] = useState<Array<{ id: string; value: number }>>([])
  const [showCustomFood, setShowCustomFood] = useState(false)
  const [customFood, setCustomFood] = useState({ name: '', calories: '', servingSize: '' })
  const [showRecognition, setShowRecognition] = useState(false)

  const quickFoods = useMemo(() => {
    return foods.slice(0, 12)
  }, [])

  const filteredFoods = useMemo(() => {
    if (!searchQuery.trim()) return []
    const query = searchQuery.toLowerCase()
    return foods.filter(
      (f) =>
        f.name.toLowerCase().includes(query) ||
        f.id.toLowerCase().includes(query)
    )
  }, [searchQuery])

  const todayRecords = useMemo(() => {
    const today = new Date().toDateString()
    return dietRecords.filter((r) => new Date(r.time).toDateString() === today)
  }, [dietRecords])

  const addHealAnimation = (value: number) => {
    const id = Date.now().toString() + Math.random().toString(36).slice(2, 8)
    setHealAnimations((prev) => [...prev, { id, value }])
    setTimeout(() => {
      setHealAnimations((prev) => prev.filter((a) => a.id !== id))
    }, 1000)
  }

  const handleAddFood = (food: typeof foods[0]) => {
    addDietRecord({
      name: food.name,
      calories: food.calories,
      time: Date.now(),
    })
    addHealAnimation(food.hpRestore)
  }

  const handleAddCustomFood = () => {
    if (!customFood.name || !customFood.calories) return
    const calories = parseInt(customFood.calories)
    if (isNaN(calories) || calories <= 0) return

    addDietRecord({
      name: customFood.name,
      calories,
      time: Date.now(),
    })
    addHealAnimation(Math.floor(calories * 0.05))
    setCustomFood({ name: '', calories: '', servingSize: '' })
    setShowCustomFood(false)
  }

  const handleRecognizedItems = (items: Array<{ name: string; cal: number; actualCal?: number; portion?: string }>) => {
    items.forEach(item => {
      const cal = item.actualCal || item.cal
      addDietRecord({
        name: item.name,
        calories: cal,
        time: Date.now(),
      })
      addHealAnimation(Math.floor(cal * 0.05))
    })
  }

  const targetCalories = 1800 + (user.weight - 60) * 20
  const intakePercent = Math.min(100, (daily.intake / targetCalories) * 100)

  return (
    <div className="min-h-full flex flex-col px-4 py-4 gap-4 pb-24">
      <AnimatePresence>
        {showCustomFood && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 backdrop-blur-sm"
            onClick={() => setShowCustomFood(false)}
          >
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 300 }}
              onClick={(e) => e.stopPropagation()}
              className="w-full max-w-[480px] bg-card border-t border-border rounded-t-3xl p-6"
            >
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold">添加自定义食物</h3>
                <button
                  onClick={() => setShowCustomFood(false)}
                  className="p-2 -mr-2 text-text3 hover:text-text transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="text-sm text-text2 mb-1.5 block">食物名称</label>
                  <input
                    type="text"
                    value={customFood.name}
                    onChange={(e) => setCustomFood({ ...customFood, name: e.target.value })}
                    placeholder="例如：妈妈做的红烧肉"
                    className="w-full px-4 py-3 bg-bg2 border border-border rounded-xl text-text placeholder-text3 focus:outline-none focus:border-purple transition-colors"
                  />
                </div>

                <div>
                  <label className="text-sm text-text2 mb-1.5 block">热量 (kcal)</label>
                  <input
                    type="number"
                    value={customFood.calories}
                    onChange={(e) => setCustomFood({ ...customFood, calories: e.target.value })}
                    placeholder="例如：500"
                    className="w-full px-4 py-3 bg-bg2 border border-border rounded-xl text-text placeholder-text3 focus:outline-none focus:border-purple transition-colors"
                  />
                </div>

                <div>
                  <label className="text-sm text-text2 mb-1.5 block">分量 (可选)</label>
                  <input
                    type="text"
                    value={customFood.servingSize}
                    onChange={(e) => setCustomFood({ ...customFood, servingSize: e.target.value })}
                    placeholder="例如：1碗"
                    className="w-full px-4 py-3 bg-bg2 border border-border rounded-xl text-text placeholder-text3 focus:outline-none focus:border-purple transition-colors"
                  />
                </div>

                <motion.button
                  whileTap={{ scale: 0.97 }}
                  onClick={handleAddCustomFood}
                  className="w-full py-4 bg-gradient-to-r from-purple to-purple-dark text-white font-bold rounded-xl shadow-lg shadow-purple/30"
                >
                  添加食物
                </motion.button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <Card className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Target className="w-5 h-5 text-gold" />
              <span className="font-bold">今日摄入</span>
            </div>
            <span className="text-sm text-text3">
              目标: {Math.round(targetCalories)} kcal
            </span>
          </div>

          <div className="relative">
            <HpBar
              current={daily.intake}
              max={targetCalories}
              color="gold"
              size="lg"
              showText={false}
            />
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-sm font-bold text-white drop-shadow-md">
                {Math.round(daily.intake)} kcal
              </span>
            </div>
          </div>

          <div className="flex items-center justify-between text-xs text-text3">
            <span>还可以吃 {Math.max(0, Math.round(targetCalories - daily.intake))} kcal</span>
            <span>{Math.round(intakePercent)}%</span>
          </div>
        </Card>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.1 }}
        className="flex gap-2"
      >
        {mealTabs.map((tab) => (
          <button
            key={tab.type}
            onClick={() => setActiveMeal(tab.type)}
            className={`flex-1 flex flex-col items-center gap-1 py-3 px-2 rounded-xl transition-all duration-200 ${
              activeMeal === tab.type
                ? 'bg-purple/20 border border-purple/50 text-purple'
                : 'bg-card border border-border text-text3 hover:text-text2'
            }`}
          >
            <tab.icon className="w-5 h-5" />
            <span className="text-xs font-medium">{tab.label}</span>
          </button>
        ))}
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.2 }}
        className="flex gap-2"
      >
        <button
          onClick={() => setShowRecognition(true)}
          className="flex-1 flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-purple to-purple-dark text-white rounded-xl font-medium shadow-lg shadow-purple/30"
        >
          <Camera className="w-5 h-5" />
          拍照识别
        </button>
        <button
          onClick={() => setShowRecognition(true)}
          className="flex-1 flex items-center justify-center gap-2 py-3 bg-gradient-to-r from-blue to-purple text-white rounded-xl font-medium shadow-lg shadow-blue/30"
        >
          <ScanLine className="w-5 h-5" />
          扫码添加
        </button>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.25 }}
        className="relative"
      >
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-text3" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="搜索食物..."
            className="w-full pl-12 pr-4 py-3.5 bg-card border border-border rounded-2xl text-text placeholder-text3 focus:outline-none focus:border-purple transition-colors"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-text3 hover:text-text transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>

        <AnimatePresence>
          {searchQuery && filteredFoods.length > 0 && (
            <motion.div
              initial={{ opacity: 0, y: -10, height: 0 }}
              animate={{ opacity: 1, y: 0, height: 'auto' }}
              exit={{ opacity: 0, y: -10, height: 0 }}
              className="absolute top-full left-0 right-0 mt-2 bg-card border border-border rounded-2xl overflow-hidden z-40 max-h-80 overflow-y-auto"
            >
              {filteredFoods.map((food, index) => (
                <motion.button
                  key={food.id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.03 }}
                  onClick={() => {
                    handleAddFood(food)
                    setSearchQuery('')
                  }}
                  className="w-full flex items-center gap-3 px-4 py-3 hover:bg-bg2 transition-colors border-b border-border/50 last:border-0 text-left"
                >
                  <span className="text-2xl">{food.emoji}</span>
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-text truncate">{food.name}</div>
                    <div className="text-xs text-text3">{food.servingSize}</div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-red">{food.calories}</div>
                    <div className="text-xs text-text3">kcal</div>
                  </div>
                </motion.button>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>

      {!searchQuery && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.3 }}
        >
          <h3 className="font-bold text-text mb-3 flex items-center gap-2">
            <Flame className="w-4 h-4 text-orange" />
            快捷添加
          </h3>
          <div className="grid grid-cols-4 gap-2">
            {quickFoods.map((food, index) => (
              <motion.button
                key={food.id}
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.3 + index * 0.03 }}
                whileTap={{ scale: 0.9 }}
                onClick={() => handleAddFood(food)}
                className="relative flex flex-col items-center gap-1 p-3 bg-card border border-border rounded-xl hover:border-purple/50 hover:bg-purple/5 transition-all"
              >
                <span className="text-3xl">{food.emoji}</span>
                <span className="text-xs text-text2 truncate w-full text-center">{food.name}</span>
                <span className="text-xs text-red font-medium">{food.calories}</span>
              </motion.button>
            ))}
          </div>
        </motion.div>
      )}

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3, delay: 0.4 }}
        className="flex-1"
      >
        <h3 className="font-bold text-text mb-3">今日记录</h3>

        {todayRecords.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-text3">
            <div className="text-5xl mb-3 opacity-50">🍽️</div>
            <p>还没有记录哦</p>
            <p className="text-sm">点击上方食物开始记录</p>
          </div>
        ) : (
          <div className="space-y-2">
            <AnimatePresence>
              {todayRecords.map((record, index) => (
                <motion.div
                  key={record.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: 20, height: 0 }}
                  transition={{ delay: index * 0.03 }}
                  className="flex items-center gap-3 p-3 bg-card border border-border rounded-xl"
                >
                  <div className="text-2xl">🍴</div>
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-text truncate">{record.name}</div>
                    <div className="text-xs text-text3">
                      {new Date(record.time).toLocaleTimeString('zh-CN', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </div>
                  </div>
                  <div className="text-right mr-2">
                    <div className="font-bold text-red">{record.calories}</div>
                    <div className="text-xs text-text3">kcal</div>
                  </div>
                  <button
                    onClick={() => removeDietRecord(record.id)}
                    className="p-2 text-text3 hover:text-red transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        )}
      </motion.div>

      <div className="fixed bottom-20 left-1/2 -translate-x-1/2 w-full max-w-[480px] px-4 pb-4 pointer-events-none">
        <div className="relative pointer-events-auto">
          <AnimatePresence>
            {healAnimations.map((anim) => (
              <motion.div
                key={anim.id}
                initial={{ opacity: 1, y: 0, scale: 0.5 }}
                animate={{ opacity: 0, y: -40, scale: 1.2 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 1, ease: 'easeOut' }}
                className="absolute left-1/2 -translate-x-1/2 -top-4 font-extrabold text-xl text-green drop-shadow-lg pointer-events-none z-50"
                style={{ textShadow: '0 0 10px rgba(46,204,113,0.8)' }}
              >
                +{anim.value} HP
              </motion.div>
            ))}
          </AnimatePresence>

          <motion.button
            whileTap={{ scale: 0.97 }}
            onClick={() => setShowCustomFood(true)}
            className="w-full py-4 bg-gradient-to-r from-purple to-purple-dark text-white font-bold rounded-2xl shadow-lg shadow-purple/30 flex items-center justify-center gap-2"
          >
            <Plus className="w-5 h-5" />
            添加自定义食物
          </motion.button>
        </div>
      </div>

      <FoodRecognitionModal
        open={showRecognition}
        onClose={() => setShowRecognition(false)}
        onConfirm={handleRecognizedItems}
        mealType={activeMeal}
      />
    </div>
  )
}
