import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Dumbbell,
  Camera,
  Bluetooth,
  Flame,
  Swords,
  Clock,
  Zap,
  X,
  Trash2,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { exercises } from '../data/exercises'
import { useGameStore } from '../store/useGameStore'
import Card from '../components/Card'
import Button from '../components/Button'
import DamageNumber from '../components/DamageNumber'

type Mode = 'manual' | 'camera' | 'bluetooth'

export default function ExercisePage() {
  const navigate = useNavigate()
  const [mode, setMode] = useState<Mode>('manual')
  const [selectedExercise, setSelectedExercise] = useState<string | null>(null)
  const [duration, setDuration] = useState(30)
  const [showDamage, setShowDamage] = useState(false)
  const [damageValue, setDamageValue] = useState(0)

  const {
    user,
    daily,
    exerciseRecords,
    addExerciseRecord,
    attackMonster,
    removeExerciseRecord,
  } = useGameStore()

  const selected = exercises.find((e) => e.id === selectedExercise)

  const estimatedCalories = selected
    ? Math.round(
        ((selected.caloriesPerMinute / 3.5) * 3.5 * user.weight * duration) / 200
      )
    : 0

  const estimatedDamage = selected
    ? Math.round(selected.damagePerMinute * duration * (1 + (user.difficulty === 'easy' ? 0.8 : user.difficulty === 'hard' ? 1.2 : 1)))
    : 0

  const handleAttack = () => {
    if (!selected) return

    addExerciseRecord({
      name: selected.name,
      calories: estimatedCalories,
      time: Date.now(),
      reps: duration,
    })

    attackMonster(estimatedDamage)

    setDamageValue(estimatedDamage)
    setShowDamage(true)
    setTimeout(() => setShowDamage(false), 800)
  }

  const todayRecords = exerciseRecords.filter((r) => {
    const recordDate = new Date(r.time).toDateString()
    return recordDate === new Date().toDateString()
  })

  const tabs = [
    { id: 'manual' as Mode, label: '手动', icon: Dumbbell },
    { id: 'camera' as Mode, label: '摄像头', icon: Camera },
    { id: 'bluetooth' as Mode, label: '蓝牙IMU', icon: Bluetooth },
  ]

  return (
    <div className="min-h-full p-4 pb-6">
      <div className="relative">
        <AnimatePresence>
          {showDamage && (
            <DamageNumber value={damageValue} type="damage" />
          )}
        </AnimatePresence>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        <h1 className="text-2xl font-black mb-4 bg-gradient-to-r from-purple to-blue bg-clip-text text-transparent">
          锻炼攻击
        </h1>

        <Card className="mb-4 p-1.5">
          <div className="flex gap-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setMode(tab.id)}
                className={`flex-1 flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl font-bold text-sm transition-all duration-200 ${
                  mode === tab.id
                    ? 'bg-gradient-to-r from-purple to-purple-dark text-white shadow-lg'
                    : 'text-text2 hover:text-text hover:bg-bg2'
                }`}
              >
                <tab.icon size={16} />
                {tab.label}
              </button>
            ))}
          </div>
        </Card>

        <AnimatePresence mode="wait">
          {mode === 'manual' && (
            <motion.div
              key="manual"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              transition={{ duration: 0.25 }}
            >
              <Card className="mb-4">
                <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
                  <Flame className="text-orange" size={20} />
                  选择运动类型
                </h2>
                <div className="grid grid-cols-2 gap-2.5">
                  {exercises.map((exercise, index) => (
                    <motion.button
                      key={exercise.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: index * 0.05 }}
                      whileTap={{ scale: 0.96 }}
                      onClick={() => setSelectedExercise(exercise.id)}
                      className={`p-3 rounded-xl text-left transition-all duration-200 border ${
                        selectedExercise === exercise.id
                          ? 'bg-gradient-to-br from-purple/20 to-blue/20 border-purple shadow-[0_0_15px_rgba(102,126,234,0.3)]'
                          : 'bg-bg2 border-border hover:border-text3'
                      }`}
                    >
                      <div className="text-3xl mb-1.5">{exercise.emoji}</div>
                      <div className="font-bold text-sm text-text">
                        {exercise.name}
                      </div>
                      <div className="text-xs text-text3 mt-0.5 flex items-center gap-1">
                        <Flame size={10} className="text-orange" />
                        {exercise.caloriesPerMinute}卡/分钟
                      </div>
                      <div
                        className={`text-xs mt-1 px-1.5 py-0.5 rounded inline-block ${
                          exercise.difficulty === 'easy'
                            ? 'bg-green/20 text-green'
                            : exercise.difficulty === 'medium'
                            ? 'bg-gold/20 text-gold'
                            : 'bg-red/20 text-red'
                        }`}
                      >
                        {exercise.difficulty === 'easy'
                          ? '简单'
                          : exercise.difficulty === 'medium'
                          ? '中等'
                          : '困难'}
                      </div>
                    </motion.button>
                  ))}
                </div>
              </Card>

              <Card className="mb-4">
                <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
                  <Clock className="text-blue" size={20} />
                  运动时长
                </h2>
                <div className="text-center mb-3">
                  <span className="text-4xl font-black bg-gradient-to-r from-blue to-purple bg-clip-text text-transparent">
                    {duration}
                  </span>
                  <span className="text-text2 ml-1">分钟</span>
                </div>
                <input
                  type="range"
                  min={5}
                  max={60}
                  step={5}
                  value={duration}
                  onChange={(e) => setDuration(Number(e.target.value))}
                  className="w-full h-2 bg-bg2 rounded-full appearance-none cursor-pointer accent-purple"
                />
                <div className="flex justify-between text-xs text-text3 mt-2">
                  <span>5分钟</span>
                  <span>30分钟</span>
                  <span>60分钟</span>
                </div>
              </Card>

              {selected && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  exit={{ opacity: 0, height: 0 }}
                >
                  <Card className="mb-4 bg-gradient-to-br from-purple/10 to-blue/10">
                    <h2 className="font-bold text-lg mb-3 flex items-center gap-2">
                      <Zap className="text-gold" size={20} />
                      预计效果
                    </h2>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-bg2/80 rounded-xl p-3 text-center">
                        <div className="text-2xl font-black text-orange">
                          {estimatedCalories}
                        </div>
                        <div className="text-xs text-text3 mt-1">消耗卡路里</div>
                      </div>
                      <div className="bg-bg2/80 rounded-xl p-3 text-center">
                        <div className="text-2xl font-black text-red">
                          {estimatedDamage}
                        </div>
                        <div className="text-xs text-text3 mt-1">造成伤害</div>
                      </div>
                    </div>
                  </Card>

                  <Button
                    variant="purple"
                    size="lg"
                    fullWidth
                    icon={<Swords size={20} />}
                    onClick={handleAttack}
                  >
                    开始攻击！
                  </Button>
                </motion.div>
              )}
            </motion.div>
          )}

          {mode === 'camera' && (
            <motion.div
              key="camera"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              transition={{ duration: 0.25 }}
            >
              <Card className="text-center py-10">
                <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-gradient-to-br from-blue to-purple flex items-center justify-center">
                  <Camera size={40} className="text-white" />
                </div>
                <h2 className="text-xl font-bold mb-2">姿态检测模式</h2>
                <p className="text-text2 text-sm mb-6">
                  通过摄像头识别你的动作，
                  <br />
                  自动计数并计算消耗
                </p>
                <Button
                  variant="primary"
                  icon={<Camera size={18} />}
                  onClick={() => navigate('/pose')}
                >
                  开启摄像头
                </Button>
                <p className="text-xs text-text3 mt-4">
                  支持：深蹲、俯卧撑、开合跳等动作
                </p>
              </Card>
            </motion.div>
          )}

          {mode === 'bluetooth' && (
            <motion.div
              key="bluetooth"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              transition={{ duration: 0.25 }}
            >
              <Card className="text-center py-10">
                <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-gradient-to-br from-blue to-green flex items-center justify-center animate-pulse">
                  <Bluetooth size={40} className="text-white" />
                </div>
                <h2 className="text-xl font-bold mb-2">蓝牙IMU模式</h2>
                <p className="text-text2 text-sm mb-6">
                  连接ESP32 IMU设备，
                  <br />
                  精准追踪运动数据
                </p>
                <Button
                  variant="green"
                  icon={<Bluetooth size={18} />}
                  onClick={() => navigate('/bluetooth')}
                >
                  搜索设备
                </Button>
                <p className="text-xs text-text3 mt-4">
                  需要配备ESP32运动传感器
                </p>
              </Card>
            </motion.div>
          )}
        </AnimatePresence>

        <Card className="mt-4">
          <h2 className="font-bold text-lg mb-3 flex items-center justify-between">
            <span className="flex items-center gap-2">
              <Flame className="text-orange" size={20} />
              今日锻炼记录
            </span>
            <span className="text-sm font-normal text-text2">
              {todayRecords.length} 项
            </span>
          </h2>

          {todayRecords.length === 0 ? (
            <div className="text-center py-8 text-text3">
              <Dumbbell size={40} className="mx-auto mb-2 opacity-30" />
              <p className="text-sm">今天还没有锻炼记录</p>
              <p className="text-xs mt-1">快去运动击败怪物吧！</p>
            </div>
          ) : (
            <div className="space-y-2">
              {todayRecords.map((record, index) => (
                <motion.div
                  key={record.id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.05 }}
                  className="flex items-center gap-3 p-3 bg-bg2 rounded-xl"
                >
                  <div className="w-10 h-10 rounded-lg bg-purple/20 flex items-center justify-center text-xl">
                    💪
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-bold text-sm truncate">
                      {record.name}
                    </div>
                    <div className="text-xs text-text3">
                      {new Date(record.time).toLocaleTimeString('zh-CN', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                      {record.reps && ` · ${record.reps}分钟`}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-orange text-sm">
                      -{record.calories} 卡
                    </div>
                  </div>
                  <button
                    onClick={() => removeExerciseRecord(record.id)}
                    className="p-1.5 text-text3 hover:text-red transition-colors"
                  >
                    <Trash2 size={16} />
                  </button>
                </motion.div>
              ))}
            </div>
          )}

          {todayRecords.length > 0 && (
            <div className="mt-3 pt-3 border-t border-border grid grid-cols-2 gap-3">
              <div className="text-center">
                <div className="text-lg font-black text-orange">
                  {daily.exerciseBurn}
                </div>
                <div className="text-xs text-text3">今日消耗(卡)</div>
              </div>
              <div className="text-center">
                <div className="text-lg font-black text-red">
                  {daily.damage}
                </div>
                <div className="text-xs text-text3">今日伤害</div>
              </div>
            </div>
          )}
        </Card>
      </motion.div>
    </div>
  )
}
