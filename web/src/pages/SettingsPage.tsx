import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Settings,
  User,
  Ruler,
  Target,
  Zap,
  Bell,
  Info,
  AlertTriangle,
  ChevronRight,
  Edit3,
  Check,
  X,
  Heart,
  Code,
  RotateCcw,
  Trophy,
  ClipboardList,
  Sparkles,
  Utensils,
  Dumbbell,
  Bluetooth,
  Trash2,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useGameStore, Difficulty } from '../store/useGameStore'
import Card from '../components/Card'
import Button from '../components/Button'
import MobileHeader from '../components/MobileHeader'

export default function SettingsPage() {
  const navigate = useNavigate()
  const {
    user, setUser, setDifficulty, resetGame, days, playerLevel, achievements, dailyQuests,
    customFoods, removeCustomFood, customExercises, removeCustomExercise,
  } = useGameStore()

  const [editing, setEditing] = useState(false)
  const [editHeight, setEditHeight] = useState(user.height)
  const [editWeight, setEditWeight] = useState(user.weight)
  const [editTarget, setEditTarget] = useState(user.targetWeight)

  const [reminderEnabled, setReminderEnabled] = useState(false)
  const [showResetConfirm, setShowResetConfirm] = useState(false)

  const difficulties: { value: Difficulty; label: string; desc: string; color: string }[] = [
    { value: 'easy', label: '简单', desc: '怪物血量低，伤害高', color: 'from-green to-green-dark' },
    { value: 'normal', label: '普通', desc: '平衡的挑战体验', color: 'from-blue to-purple' },
    { value: 'hard', label: '困难', desc: '怪物血量高，伤害低', color: 'from-red to-red-dark' },
  ]

  const handleSaveProfile = () => {
    setUser({
      height: editHeight,
      weight: editWeight,
      targetWeight: editTarget,
    })
    setEditing(false)
  }

  const handleCancelEdit = () => {
    setEditHeight(user.height)
    setEditWeight(user.weight)
    setEditTarget(user.targetWeight)
    setEditing(false)
  }

  const handleReset = () => {
    resetGame()
    setShowResetConfirm(false)
  }

  const calcBmi = (w: number, h: number) => {
    if (h <= 0) return 0
    return Number((w / ((h / 100) ** 2)).toFixed(1))
  }

  return (
    <div className="min-h-full max-w-[480px] mx-auto">
      <MobileHeader
        title="设置"
        gradient="from-purple to-pink"
        backTo="/"
      />

      <div className="p-4 pb-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3, delay: 0.1 }}
        >

        <Card className="mb-4 bg-gradient-to-br from-purple/10 to-blue/10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-bold text-lg flex items-center gap-2">
              <User className="text-purple" size={20} />
              个人信息
            </h2>
            {!editing && (
              <button
                onClick={() => setEditing(true)}
                className="p-1.5 text-text3 hover:text-text transition-colors"
              >
                <Edit3 size={16} />
              </button>
            )}
          </div>

          {editing ? (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="space-y-3"
            >
              <div>
                <label className="text-xs text-text3 mb-1.5 block">身高 (cm)</label>
                <input
                  type="number"
                  value={editHeight}
                  onChange={(e) => setEditHeight(Number(e.target.value))}
                  className="w-full px-3 py-2.5 bg-bg2 border border-border rounded-xl text-text text-sm focus:outline-none focus:border-purple transition-colors"
                />
              </div>
              <div>
                <label className="text-xs text-text3 mb-1.5 block">当前体重 (kg)</label>
                <input
                  type="number"
                  value={editWeight}
                  onChange={(e) => setEditWeight(Number(e.target.value))}
                  className="w-full px-3 py-2.5 bg-bg2 border border-border rounded-xl text-text text-sm focus:outline-none focus:border-purple transition-colors"
                />
              </div>
              <div>
                <label className="text-xs text-text3 mb-1.5 block">目标体重 (kg)</label>
                <input
                  type="number"
                  value={editTarget}
                  onChange={(e) => setEditTarget(Number(e.target.value))}
                  className="w-full px-3 py-2.5 bg-bg2 border border-border rounded-xl text-text text-sm focus:outline-none focus:border-purple transition-colors"
                />
              </div>
              <div className="text-xs text-text2 text-center py-2">
                BMI: <span className="text-purple font-bold">{calcBmi(editWeight, editHeight)}</span>
              </div>
              <div className="flex gap-2">
                <Button
                  variant="secondary"
                  size="sm"
                  fullWidth
                  icon={<X size={16} />}
                  onClick={handleCancelEdit}
                >
                  取消
                </Button>
                <Button
                  variant="purple"
                  size="sm"
                  fullWidth
                  icon={<Check size={16} />}
                  onClick={handleSaveProfile}
                >
                  保存
                </Button>
              </div>
            </motion.div>
          ) : (
            <div className="grid grid-cols-3 gap-2">
              <div className="bg-bg2/60 rounded-xl p-3 text-center">
                <Ruler size={18} className="mx-auto text-blue mb-1" />
                <div className="text-lg font-bold text-text">{user.height}</div>
                <div className="text-[10px] text-text3">身高(cm)</div>
              </div>
              <div className="bg-bg2/60 rounded-xl p-3 text-center">
                <Heart size={18} className="mx-auto text-red mb-1" />
                <div className="text-lg font-bold text-text">{user.weight}</div>
                <div className="text-[10px] text-text3">体重(kg)</div>
              </div>
              <div className="bg-bg2/60 rounded-xl p-3 text-center">
                <Target size={18} className="mx-auto text-green mb-1" />
                <div className="text-lg font-bold text-text">{user.targetWeight}</div>
                <div className="text-[10px] text-text3">目标(kg)</div>
              </div>
            </div>
          )}

          {!editing && (
            <div className="mt-3 pt-3 border-t border-border flex items-center justify-between">
              <span className="text-sm text-text2">BMI</span>
              <span className="font-bold text-purple text-lg">{user.bmi}</span>
            </div>
          )}
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Zap className="text-gold" size={20} />
            难度设置
          </h2>
          <div className="space-y-2">
            {difficulties.map((diff) => (
              <button
                key={diff.value}
                onClick={() => setDifficulty(diff.value)}
                className={`w-full p-3 rounded-xl text-left transition-all duration-200 border ${
                  user.difficulty === diff.value
                    ? `bg-gradient-to-r ${diff.color} border-transparent shadow-lg`
                    : 'bg-bg2 border-border hover:border-text3'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <div className={`font-bold text-sm ${
                      user.difficulty === diff.value ? 'text-white' : 'text-text'
                    }`}>
                      {diff.label}
                    </div>
                    <div className={`text-xs mt-0.5 ${
                      user.difficulty === diff.value ? 'text-white/80' : 'text-text3'
                    }`}>
                      {diff.desc}
                    </div>
                  </div>
                  {user.difficulty === diff.value && (
                    <Check size={18} className="text-white" />
                  )}
                </div>
              </button>
            ))}
          </div>
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Bell className="text-blue" size={20} />
            提醒设置
          </h2>
          <div className="space-y-3">
            <div className="flex items-center justify-between py-2">
              <div>
                <div className="text-sm font-medium text-text">每日提醒</div>
                <div className="text-xs text-text3">每天定时提醒运动</div>
              </div>
              <button
                onClick={() => setReminderEnabled(!reminderEnabled)}
                className={`w-12 h-7 rounded-full transition-colors duration-200 relative ${
                  reminderEnabled ? 'bg-green' : 'bg-bg3'
                }`}
              >
                <motion.div
                  animate={{ x: reminderEnabled ? 22 : 2 }}
                  transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                  className="absolute top-0.5 w-6 h-6 bg-white rounded-full shadow-md"
                />
              </button>
            </div>
          </div>
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Sparkles className="text-purple" size={20} />
            游戏中心
          </h2>
          <div className="space-y-2">
            <button
              onClick={() => navigate('/achievements')}
              className="w-full flex items-center justify-between py-2.5 px-3 bg-bg2/60 rounded-xl hover:bg-bg2 transition-colors"
            >
              <span className="flex items-center gap-2 text-sm text-text">
                <Trophy size={16} className="text-gold" />
                成就殿堂
              </span>
              <div className="flex items-center gap-1.5">
                <span className="text-[10px] text-text3">{achievements.filter((a) => a.unlocked).length} 个</span>
                <ChevronRight size={14} className="text-text3" />
              </div>
            </button>
            <button
              onClick={() => navigate('/quests')}
              className="w-full flex items-center justify-between py-2.5 px-3 bg-bg2/60 rounded-xl hover:bg-bg2 transition-colors"
            >
              <span className="flex items-center gap-2 text-sm text-text">
                <ClipboardList size={16} className="text-blue" />
                每日任务
              </span>
              <div className="flex items-center gap-1.5">
                <span className="text-[10px] text-text3">{dailyQuests.filter((q) => q.completed).length}/{dailyQuests.length} 完成</span>
                <ChevronRight size={14} className="text-text3" />
              </div>
            </button>
            <button
              onClick={() => navigate('/skills')}
              className="w-full flex items-center justify-between py-2.5 px-3 bg-bg2/60 rounded-xl hover:bg-bg2 transition-colors"
            >
              <span className="flex items-center gap-2 text-sm text-text">
                <Zap size={16} className="text-purple" />
                技能系统
              </span>
              <div className="flex items-center gap-1.5">
                <span className="text-[10px] text-text3">Lv.{playerLevel.level}</span>
                <ChevronRight size={14} className="text-text3" />
              </div>
            </button>
          </div>
        </Card>

        {/* 自定义食物库 */}
        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Utensils className="text-red" size={20} />
            我的食物库
          </h2>
          <div className="space-y-1.5">
            {customFoods.length === 0 && (
              <p className="text-text3 text-xs py-2">还没有自定义食物，在饮食页面可以添加~</p>
            )}
            {customFoods.map((food) => (
              <div
                key={food.id}
                className="flex items-center justify-between py-2 px-3 bg-bg2/60 rounded-xl"
              >
                <div className="flex items-center gap-2">
                  <span className="text-lg">{food.emoji}</span>
                  <div>
                    <div className="text-sm text-text font-bold">{food.name}</div>
                    <div className="text-[10px] text-text3">{food.calories} kcal</div>
                  </div>
                </div>
                <button
                  onClick={() => removeCustomFood(food.id)}
                  className="text-text3 hover:text-red transition-colors p-1"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        </Card>

        {/* 自定义运动库 */}
        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Dumbbell className="text-green" size={20} />
            我的运动库
          </h2>
          <div className="space-y-1.5">
            {customExercises.length === 0 && (
              <p className="text-text3 text-xs py-2">还没有自定义运动，在锻炼页面可以添加~</p>
            )}
            {customExercises.map((ex) => (
              <div
                key={ex.id}
                className="flex items-center justify-between py-2 px-3 bg-bg2/60 rounded-xl"
              >
                <div className="flex items-center gap-2">
                  <span className="text-lg">{ex.emoji}</span>
                  <div>
                    <div className="text-sm text-text font-bold">{ex.name}</div>
                    <div className="text-[10px] text-text3">{ex.caloriesPerMinute} kcal/分 · {ex.damagePerMinute} 伤害/分</div>
                  </div>
                </div>
                <button
                  onClick={() => removeCustomExercise(ex.id)}
                  className="text-text3 hover:text-red transition-colors p-1"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}
          </div>
        </Card>

        {/* 蓝牙设备 */}
        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Bluetooth className="text-blue" size={20} />
            设备连接
          </h2>
          <button
            onClick={() => navigate('/bluetooth')}
            className="w-full flex items-center justify-between py-2.5 px-3 bg-bg2/60 rounded-xl hover:bg-bg2 transition-colors"
          >
            <span className="flex items-center gap-2 text-sm text-text">
              <Bluetooth size={16} className="text-blue" />
              蓝牙设备
            </span>
            <ChevronRight size={14} className="text-text3" />
          </button>
        </Card>

        <Card className="mb-4">
          <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
            <Info className="text-text2" size={20} />
            关于项目
          </h2>
          <div className="space-y-3">
            <div className="flex items-center justify-between py-2 border-b border-border">
              <span className="text-sm text-text2">版本</span>
              <span className="text-sm text-text">v1.0.0</span>
            </div>
            <div className="flex items-center justify-between py-2 border-b border-border">
              <span className="text-sm text-text2">已坚持</span>
              <span className="text-sm text-gold font-bold">{days} 天</span>
            </div>
            <button className="w-full flex items-center justify-between py-2 text-sm text-text2 hover:text-text transition-colors">
              <span className="flex items-center gap-2">
                <Code size={16} />
                项目主页
              </span>
              <ChevronRight size={16} />
            </button>
          </div>
        </Card>

        <Card className="mb-4">
          <button
            onClick={() => setShowResetConfirm(true)}
            className="w-full flex items-center justify-center gap-2 py-3 text-red hover:bg-red/10 rounded-xl transition-colors"
          >
            <RotateCcw size={18} />
            <span className="font-bold">重置游戏数据</span>
          </button>
        </Card>
      </motion.div>
      </div>

      <AnimatePresence>
        {showResetConfirm && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-6"
            onClick={() => setShowResetConfirm(false)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              transition={{ type: 'spring', stiffness: 300, damping: 25 }}
              className="bg-card border border-border rounded-2xl p-6 w-full max-w-sm"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-red/20 flex items-center justify-center">
                <AlertTriangle size={32} className="text-red" />
              </div>
              <h3 className="text-xl font-bold text-center mb-2 text-text">
                确认重置？
              </h3>
              <p className="text-text2 text-center text-sm mb-6">
                所有游戏进度、数据、成就都将被清除，
                <br />
                此操作不可撤销！
              </p>
              <div className="flex gap-3">
                <Button
                  variant="secondary"
                  size="md"
                  fullWidth
                  onClick={() => setShowResetConfirm(false)}
                >
                  取消
                </Button>
                <Button
                  variant="primary"
                  size="md"
                  fullWidth
                  icon={<RotateCcw size={16} />}
                  onClick={handleReset}
                >
                  确认重置
                </Button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
