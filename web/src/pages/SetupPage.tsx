import { useState, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { useNavigate } from 'react-router-dom'
import {
  User,
  Activity,
  Dumbbell,
  Flame,
  Sparkles,
  ChevronRight,
  ChevronLeft,
  Ruler,
  Scale,
  Target,
  Sun,
  Briefcase,
  Home,
  Clock,
  Heart,
  Zap,
  Cat,
  Sword,
  Wand2,
  Eye,
  Check,
  Calendar,
} from 'lucide-react'
import { useGameStore, type Difficulty } from '../store/useGameStore'

type Gender = 'male' | 'female'
type ScheduleType = 'early' | 'normal' | 'late'
type WorkType = 'office' | 'remote' | 'hybrid'
type ExerciseTime = 'morning' | 'afternoon' | 'evening'

interface SetupForm {
  height: string
  weight: string
  targetWeight: string
  gender: Gender
  schedule: ScheduleType
  workType: WorkType
  exerciseTime: ExerciseTime
  pushups: string
  runningMinutes: string
  weeklyExercise: string
  difficulty: Difficulty
  role: string
}

const initialForm: SetupForm = {
  height: '170',
  weight: '70',
  targetWeight: '60',
  gender: 'male',
  schedule: 'normal',
  workType: 'office',
  exerciseTime: 'evening',
  pushups: '10',
  runningMinutes: '20',
  weeklyExercise: '3',
  difficulty: 'normal',
  role: 'warrior',
}

const steps = [
  { title: '基本信息', icon: User },
  { title: '生活习惯', icon: Activity },
  { title: '体能评估', icon: Dumbbell },
  { title: '难度选择', icon: Flame },
  { title: '角色形象', icon: Sparkles },
]

const difficultyOptions = [
  {
    value: 'easy' as Difficulty,
    label: '简单',
    emoji: '🌱',
    desc: '轻松起步，适合新手',
    color: 'from-green to-green-dark',
    borderColor: 'border-green/50',
    bgColor: 'bg-green/10',
  },
  {
    value: 'normal' as Difficulty,
    label: '普通',
    emoji: '⚔️',
    desc: '标准挑战，均衡体验',
    color: 'from-purple to-purple-dark',
    borderColor: 'border-purple/50',
    bgColor: 'bg-purple/10',
  },
  {
    value: 'hard' as Difficulty,
    label: '困难',
    emoji: '🔥',
    desc: '极限挑战，快速见效',
    color: 'from-red to-red-dark',
    borderColor: 'border-red/50',
    bgColor: 'bg-red/10',
  },
]

const roleOptions = [
  { value: 'cat', label: '可爱萌宠', emoji: '🐱', icon: Cat, color: 'from-pink to-rose-400' },
  { value: 'warrior', label: '热血战士', emoji: '⚔️', icon: Sword, color: 'from-red to-red-dark' },
  { value: 'mage', label: '冷静法师', emoji: '🔮', icon: Wand2, color: 'from-purple to-purple-dark' },
  { value: 'assassin', label: '神秘刺客', emoji: '🗡️', icon: Eye, color: 'from-text3 to-bg3' },
]

const calculateBMI = (weight: number, height: number): number => {
  if (height <= 0) return 0
  const h = height / 100
  return Number((weight / (h * h)).toFixed(1))
}

const getBMICategory = (bmi: number): { label: string; color: string } => {
  if (bmi < 18.5) return { label: '偏瘦', color: 'text-blue' }
  if (bmi < 24) return { label: '正常', color: 'text-green' }
  if (bmi < 28) return { label: '超重', color: 'text-gold' }
  return { label: '肥胖', color: 'text-red' }
}

export default function SetupPage() {
  const navigate = useNavigate()
  const setUser = useGameStore((s) => s.setUser)
  const setDifficulty = useGameStore((s) => s.setDifficulty)

  const [currentStep, setCurrentStep] = useState(0)
  const [form, setForm] = useState<SetupForm>(initialForm)

  const bmi = useMemo(() => {
    const h = parseFloat(form.height) || 0
    const w = parseFloat(form.weight) || 0
    return calculateBMI(w, h)
  }, [form.height, form.weight])

  const bmiCategory = getBMICategory(bmi)

  const updateForm = <K extends keyof SetupForm>(key: K, value: SetupForm[K]) => {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  const isStepValid = (step: number): boolean => {
    switch (step) {
      case 0: {
        const h = parseFloat(form.height)
        const w = parseFloat(form.weight)
        const tw = parseFloat(form.targetWeight)
        return h >= 100 && h <= 250 && w >= 30 && w <= 300 && tw > 0 && tw < w
      }
      case 1:
        return !!form.schedule && !!form.workType && !!form.exerciseTime
      case 2: {
        const p = parseInt(form.pushups)
        const r = parseInt(form.runningMinutes)
        const we = parseInt(form.weeklyExercise)
        return !isNaN(p) && p >= 0 && !isNaN(r) && r >= 0 && !isNaN(we) && we >= 0 && we <= 7
      }
      case 3:
        return !!form.difficulty
      case 4:
        return !!form.role
      default:
        return true
    }
  }

  const handleNext = () => {
    if (!isStepValid(currentStep)) return
    if (currentStep < steps.length - 1) {
      setCurrentStep((prev) => prev + 1)
    } else {
      handleComplete()
    }
  }

  const handlePrev = () => {
    if (currentStep > 0) {
      setCurrentStep((prev) => prev - 1)
    } else {
      navigate('/welcome')
    }
  }

  const handleComplete = () => {
    const h = parseFloat(form.height)
    const w = parseFloat(form.weight)
    const tw = parseFloat(form.targetWeight)

    setUser({
      height: h,
      weight: w,
      targetWeight: tw,
      bmi: bmi,
      role: form.role,
      gender: form.gender,
    })
    setDifficulty(form.difficulty)

    navigate('/')
  }

  const progress = ((currentStep + 1) / steps.length) * 100

  return (
    <div className="min-h-screen w-full flex flex-col bg-gradient-to-b from-bg via-bg2 to-bg">
      <div className="w-full max-w-[480px] mx-auto flex flex-col flex-1 px-6 py-6">
        <div className="mb-6">
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-lg font-bold text-text">
              第 {currentStep + 1} 步 / {steps.length}
            </h2>
            <span className="text-text2 text-sm">{steps[currentStep].title}</span>
          </div>
          <div className="w-full h-2 bg-card rounded-full overflow-hidden">
            <motion.div
              className="h-full bg-gradient-to-r from-red via-orange to-gold rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${progress}%` }}
              transition={{ type: 'spring', stiffness: 100, damping: 20 }}
            />
          </div>
          <div className="flex justify-between mt-2">
            {steps.map((step, idx) => {
              const Icon = step.icon
              const isActive = idx === currentStep
              const isDone = idx < currentStep
              return (
                <div
                  key={idx}
                  className={`flex flex-col items-center gap-1 ${
                    isActive ? 'opacity-100' : isDone ? 'opacity-60' : 'opacity-30'
                  }`}
                >
                  <div
                    className={`w-6 h-6 rounded-full flex items-center justify-center text-xs ${
                      isDone
                        ? 'bg-green text-white'
                        : isActive
                        ? 'bg-orange-500 text-white'
                        : 'bg-card text-text3'
                    }`}
                  >
                    {isDone ? <Check className="w-4 h-4" /> : <Icon className="w-3 h-3" />}
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {currentStep === 0 && bmi > 0 && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mb-4 p-4 bg-card/60 border border-border rounded-2xl"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-text2 text-xs mb-1">当前 BMI</p>
                <p className={`text-2xl font-bold ${bmiCategory.color}`}>{bmi}</p>
              </div>
              <div className="text-right">
                <p className="text-text2 text-xs mb-1">状态</p>
                <p className={`text-lg font-semibold ${bmiCategory.color}`}>
                  {bmiCategory.label}
                </p>
              </div>
            </div>
          </motion.div>
        )}

        <div className="flex-1 overflow-y-auto">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentStep}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ type: 'spring', stiffness: 200, damping: 25 }}
            >
              {currentStep === 0 && <Step1 form={form} updateForm={updateForm} />}
              {currentStep === 1 && <Step2 form={form} updateForm={updateForm} />}
              {currentStep === 2 && <Step3 form={form} updateForm={updateForm} />}
              {currentStep === 3 && <Step4 form={form} updateForm={updateForm} />}
              {currentStep === 4 && <Step5 form={form} updateForm={updateForm} />}
            </motion.div>
          </AnimatePresence>
        </div>

        <div className="flex gap-3 mt-6">
          <button
            onClick={handlePrev}
            className="flex-1 py-3 px-6 bg-card border border-border text-text font-semibold rounded-xl flex items-center justify-center gap-2 hover:bg-bg2 transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
            {currentStep === 0 ? '返回' : '上一步'}
          </button>
          <button
            onClick={handleNext}
            disabled={!isStepValid(currentStep)}
            className={`flex-1 py-3 px-6 font-semibold rounded-xl flex items-center justify-center gap-2 transition-all ${
              isStepValid(currentStep)
                ? 'bg-gradient-to-r from-red via-orange to-gold text-white shadow-[0_4px_14px_rgba(255,107,107,0.4)] hover:shadow-[0_6px_20px_rgba(255,107,107,0.5)] hover:-translate-y-0.5'
                : 'bg-card/50 text-text3 cursor-not-allowed'
            }`}
          >
            {currentStep === steps.length - 1 ? '完成' : '下一步'}
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
  )
}

interface StepProps {
  form: SetupForm
  updateForm: <K extends keyof SetupForm>(key: K, value: SetupForm[K]) => void
}

function InputField({
  icon: Icon,
  label,
  value,
  onChange,
  type = 'text',
  placeholder,
  unit,
}: {
  icon: any
  label: string
  value: string
  onChange: (val: string) => void
  type?: string
  placeholder?: string
  unit?: string
}) {
  return (
    <div className="mb-4">
      <label className="flex items-center gap-2 text-text2 text-sm mb-2">
        <Icon className="w-4 h-4" />
        {label}
      </label>
      <div className="relative">
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full py-3 px-4 pr-12 bg-card/80 border border-border rounded-xl text-text placeholder:text-text3 focus:outline-none focus:border-orange-500/60 transition-colors"
        />
        {unit && (
          <span className="absolute right-4 top-1/2 -translate-y-1/2 text-text3 text-sm">
            {unit}
          </span>
        )}
      </div>
    </div>
  )
}

function SelectCard({
  label,
  icon: Icon,
  selected,
  onClick,
  emoji,
}: {
  label: string
  icon?: any
  selected: boolean
  onClick: () => void
  emoji?: string
}) {
  return (
    <button
      onClick={onClick}
      className={`p-4 rounded-xl border-2 transition-all flex flex-col items-center gap-2 ${
        selected
          ? 'border-gold bg-gold/10 text-gold'
          : 'border-border bg-card/50 text-text2 hover:border-text3 hover:bg-card/70'
      }`}
    >
      {emoji ? (
        <span className="text-2xl">{emoji}</span>
      ) : Icon ? (
        <Icon className="w-6 h-6" />
      ) : null}
      <span className="text-sm font-medium">{label}</span>
    </button>
  )
}

function Step1({ form, updateForm }: StepProps) {
  return (
    <div>
      <h3 className="text-xl font-bold text-text mb-6 flex items-center gap-2">
        <User className="w-6 h-6 text-red" />
        基本信息
      </h3>

      <InputField
        icon={Ruler}
        label="身高"
        value={form.height}
        onChange={(v) => updateForm('height', v)}
        type="number"
        placeholder="请输入身高"
        unit="cm"
      />

      <InputField
        icon={Scale}
        label="当前体重"
        value={form.weight}
        onChange={(v) => updateForm('weight', v)}
        type="number"
        placeholder="请输入当前体重"
        unit="kg"
      />

      <InputField
        icon={Target}
        label="目标体重"
        value={form.targetWeight}
        onChange={(v) => updateForm('targetWeight', v)}
        type="number"
        placeholder="请输入目标体重"
        unit="kg"
      />

      <div className="mb-4">
        <label className="flex items-center gap-2 text-text2 text-sm mb-2">
          <Heart className="w-4 h-4" />
          性别
        </label>
        <div className="grid grid-cols-2 gap-3">
          <SelectCard
            label="男生"
            emoji="👨"
            selected={form.gender === 'male'}
            onClick={() => updateForm('gender', 'male')}
          />
          <SelectCard
            label="女生"
            emoji="👩"
            selected={form.gender === 'female'}
            onClick={() => updateForm('gender', 'female')}
          />
        </div>
      </div>
    </div>
  )
}

function Step2({ form, updateForm }: StepProps) {
  return (
    <div>
      <h3 className="text-xl font-bold text-text mb-6 flex items-center gap-2">
        <Activity className="w-6 h-6 text-blue" />
        生活习惯
      </h3>

      <div className="mb-6">
        <label className="flex items-center gap-2 text-text2 text-sm mb-3">
          <Clock className="w-4 h-4" />
          作息类型
        </label>
        <div className="grid grid-cols-3 gap-3">
          <SelectCard
            label="早起鸟"
            emoji="🌅"
            selected={form.schedule === 'early'}
            onClick={() => updateForm('schedule', 'early')}
          />
          <SelectCard
            label="正常"
            emoji="☀️"
            selected={form.schedule === 'normal'}
            onClick={() => updateForm('schedule', 'normal')}
          />
          <SelectCard
            label="夜猫子"
            emoji="🦉"
            selected={form.schedule === 'late'}
            onClick={() => updateForm('schedule', 'late')}
          />
        </div>
      </div>

      <div className="mb-6">
        <label className="flex items-center gap-2 text-text2 text-sm mb-3">
          <Briefcase className="w-4 h-4" />
          办公方式
        </label>
        <div className="grid grid-cols-3 gap-3">
          <SelectCard
            label="办公室"
            icon={Briefcase}
            selected={form.workType === 'office'}
            onClick={() => updateForm('workType', 'office')}
          />
          <SelectCard
            label="居家"
            icon={Home}
            selected={form.workType === 'remote'}
            onClick={() => updateForm('workType', 'remote')}
          />
          <SelectCard
            label="混合"
            icon={Zap}
            selected={form.workType === 'hybrid'}
            onClick={() => updateForm('workType', 'hybrid')}
          />
        </div>
      </div>

      <div>
        <label className="flex items-center gap-2 text-text2 text-sm mb-3">
          <Sun className="w-4 h-4" />
          锻炼时间段
        </label>
        <div className="grid grid-cols-3 gap-3">
          <SelectCard
            label="早晨"
            emoji="🌅"
            selected={form.exerciseTime === 'morning'}
            onClick={() => updateForm('exerciseTime', 'morning')}
          />
          <SelectCard
            label="下午"
            emoji="🌤️"
            selected={form.exerciseTime === 'afternoon'}
            onClick={() => updateForm('exerciseTime', 'afternoon')}
          />
          <SelectCard
            label="晚上"
            emoji="🌙"
            selected={form.exerciseTime === 'evening'}
            onClick={() => updateForm('exerciseTime', 'evening')}
          />
        </div>
      </div>
    </div>
  )
}

function Step3({ form, updateForm }: StepProps) {
  return (
    <div>
      <h3 className="text-xl font-bold text-text mb-6 flex items-center gap-2">
        <Dumbbell className="w-6 h-6 text-purple" />
        体能评估
      </h3>

      <InputField
        icon={Dumbbell}
        label="俯卧撑数量（一次最多）"
        value={form.pushups}
        onChange={(v) => updateForm('pushups', v)}
        type="number"
        placeholder="请输入数量"
        unit="个"
      />

      <InputField
        icon={Activity}
        label="跑步时长（一次最多）"
        value={form.runningMinutes}
        onChange={(v) => updateForm('runningMinutes', v)}
        type="number"
        placeholder="请输入时长"
        unit="分钟"
      />

      <InputField
        icon={Calendar}
        label="每周运动次数"
        value={form.weeklyExercise}
        onChange={(v) => updateForm('weeklyExercise', v)}
        type="number"
        placeholder="请输入次数"
        unit="次"
      />

      <div className="mt-6 p-4 bg-purple/10 border border-purple/30 rounded-xl">
        <p className="text-purple text-sm flex items-start gap-2">
          <Sparkles className="w-5 h-5 flex-shrink-0 mt-0.5" />
          <span>
            这些数据将帮助我们为你定制最适合的游戏难度和训练计划。
            诚实填写才能获得最佳体验哦！
          </span>
        </p>
      </div>
    </div>
  )
}

function Step4({ form, updateForm }: StepProps) {
  return (
    <div>
      <h3 className="text-xl font-bold text-text mb-6 flex items-center gap-2">
        <Flame className="w-6 h-6 text-red" />
        难度选择
      </h3>

      <p className="text-text2 text-sm mb-6">
        选择一个适合你的难度级别，我们会根据你的选择调整游戏体验。
      </p>

      <div className="space-y-4">
        {difficultyOptions.map((option) => (
          <motion.button
            key={option.value}
            onClick={() => updateForm('difficulty', option.value)}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className={`w-full p-5 rounded-2xl border-2 transition-all text-left ${
              form.difficulty === option.value
                ? `${option.borderColor} ${option.bgColor}`
                : 'border-border bg-card/50 hover:border-text3'
            }`}
          >
            <div className="flex items-center gap-4">
              <div
                className={`w-14 h-14 rounded-xl bg-gradient-to-br ${option.color} flex items-center justify-center text-2xl shadow-lg`}
              >
                {option.emoji}
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <h4 className="font-bold text-text text-lg">{option.label}</h4>
                  {form.difficulty === option.value && (
                    <div className="w-5 h-5 rounded-full bg-green flex items-center justify-center">
                      <Check className="w-3 h-3 text-white" />
                    </div>
                  )}
                </div>
                <p className="text-text2 text-sm mt-1">{option.desc}</p>
              </div>
            </div>
          </motion.button>
        ))}
      </div>
    </div>
  )
}

function Step5({ form, updateForm }: StepProps) {
  return (
    <div>
      <h3 className="text-xl font-bold text-text mb-6 flex items-center gap-2">
        <Sparkles className="w-6 h-6 text-gold" />
        角色形象
      </h3>

      <p className="text-text2 text-sm mb-6">
        选择一个陪伴你战斗的角色，它将陪你一起打败脂肪怪！
      </p>

      <div className="grid grid-cols-2 gap-4">
        {roleOptions.map((role) => (
          <motion.button
            key={role.value}
            onClick={() => updateForm('role', role.value)}
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.97 }}
            className={`p-5 rounded-2xl border-2 transition-all flex flex-col items-center gap-3 ${
              form.role === role.value
                ? `border-gold/60 bg-gold/10`
                : 'border-border bg-card/50 hover:border-text3'
            }`}
          >
            <div
              className={`w-16 h-16 rounded-2xl bg-gradient-to-br ${role.color} flex items-center justify-center text-3xl shadow-lg`}
            >
              {role.emoji}
            </div>
            <div className="text-center">
              <h4 className="font-bold text-text">{role.label}</h4>
              {form.role === role.value && (
                <div className="mt-1">
                  <span className="text-xs text-gold font-medium">✓ 已选择</span>
                </div>
              )}
            </div>
          </motion.button>
        ))}
      </div>

      <div className="mt-8 p-4 bg-gradient-to-r from-red/10 to-gold/10 border border-red/30 rounded-xl">
        <p className="text-gold text-sm text-center font-medium">
          🎮 准备好开始你的减肥冒险了吗？
        </p>
      </div>
    </div>
  )
}
