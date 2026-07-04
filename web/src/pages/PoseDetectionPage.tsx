import { useState, useRef, useEffect, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  ArrowLeft,
  Camera,
  Play,
  Square,
  RefreshCw,
  Activity,
  Target,
  Flame,
  Swords,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Zap,
  RotateCcw,
  Dumbbell,
  Coins,
  Sparkles,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Card from '../components/Card'
import Button from '../components/Button'
import DamageNumber from '../components/DamageNumber'
import { useGameStore } from '../store/useGameStore'
import { getExerciseById } from '../data/exercises'
import { PoseService, createPoseService, type ExerciseType, type PoseStatus } from '../services/poseService'

const exercises: { id: ExerciseType; name: string; emoji: string; description: string }[] = [
  { id: 'squat', name: '深蹲', emoji: '🦵', description: '双脚与肩同宽，下蹲至大腿平行地面' },
  { id: 'pushup', name: '俯卧撑', emoji: '💪', description: '双手撑地，身体呈一条直线，屈臂下压' },
  { id: 'highknee', name: '高抬腿', emoji: '🏃', description: '原地快速抬腿，膝盖抬至髋部高度' },
  { id: 'jumprope', name: '开合跳', emoji: '⏰', description: '双脚同时跳起，手脚同时开合' },
  { id: 'plank', name: '平板支撑', emoji: '🧘', description: '前臂撑地，身体呈一条直线保持' },
  { id: 'burpee', name: '波比跳', emoji: '🔥', description: '深蹲-后跳-俯卧撑-跳起，全身燃脂' },
  { id: 'lunge', name: '弓步蹲', emoji: '🦶', description: '前后脚弓步下蹲，锻炼腿部力量' },
  { id: 'mountainclimber', name: '登山跑', emoji: '⛰️', description: '平板姿势交替提膝，快速燃脂' },
]

const SET_REPS = 5

// 训练计划：每个动作完成后推荐的下一步动作
const trainingFlow: Record<ExerciseType, { next: ExerciseType; label: string; tip: string }> = {
  squat: { next: 'plank', label: '平板支撑', tip: '深蹲完成！接下来用平板支撑拉伸核心' },
  pushup: { next: 'highknee', label: '高抬腿', tip: '俯卧撑完成！接下来高抬腿提升心率' },
  highknee: { next: 'squat', label: '深蹲', tip: '高抬腿完成！接下来深蹲锻炼腿部' },
  jumprope: { next: 'lunge', label: '弓步蹲', tip: '开合跳完成！接下来弓步蹲强化下肢' },
  plank: { next: 'burpee', label: '波比跳', tip: '平板支撑完成！接下来波比跳全身燃脂' },
  burpee: { next: 'plank', label: '平板支撑', tip: '波比跳完成！接下来平板支撑放松核心' },
  lunge: { next: 'pushup', label: '俯卧撑', tip: '弓步蹲完成！接下来俯卧撑锻炼上肢' },
  mountainclimber: { next: 'squat', label: '深蹲', tip: '登山跑完成！接下来深蹲锻炼腿部' },
}

export default function PoseDetectionPage() {
  const navigate = useNavigate()
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const poseServiceRef = useRef<PoseService | null>(null)
  const mockIntervalRef = useRef<number>(0)
  const timerIntervalRef = useRef<number>(0)
  const isCompletingRef = useRef(false)
  const elapsedTimeRef = useRef(0)

  const [selectedExercise, setSelectedExercise] = useState<ExerciseType>('squat')
  const [isRunning, setIsRunning] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [count, setCount] = useState(0)
  const [poseStatus, setPoseStatus] = useState<PoseStatus>('idle')
  const [errorMsg, setErrorMsg] = useState('')
  const [cameraFacing, setCameraFacing] = useState<'user' | 'environment'>('user')
  const [showDamage, setShowDamage] = useState(false)
  const [damageValue, setDamageValue] = useState(0)
  const [isCompleted, setIsCompleted] = useState(false)
  const [useMock, setUseMock] = useState(false)
  const [elapsedTime, setElapsedTime] = useState(0)
  const [caloriesBurned, setCaloriesBurned] = useState(0)
  const [kneeAngle, setKneeAngle] = useState(180)
  const [elbowAngle, setElbowAngle] = useState(180)
  const [currentPhase, setCurrentPhase] = useState<string>('待机')
  const [showNextStep, setShowNextStep] = useState(false)
  const [completedSets, setCompletedSets] = useState(0)

  const { attackMonster, addExerciseRecord, user, coins, streak, days, monster } = useGameStore()

  const exerciseInfo = getExerciseById(selectedExercise)

  const cleanup = useCallback(() => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current)
    }
    if (mockIntervalRef.current) {
      clearInterval(mockIntervalRef.current)
    }
    if (poseServiceRef.current) {
      poseServiceRef.current.destroy?.()
      poseServiceRef.current = null
    }
    if (videoRef.current?.srcObject) {
      const stream = videoRef.current.srcObject as MediaStream
      stream.getTracks().forEach((track) => track.stop())
      videoRef.current.srcObject = null
    }
    setIsRunning(false)
    setPoseStatus('idle')
    setElapsedTime(0)
    setCaloriesBurned(0)
  }, [])

  useEffect(() => {
    return () => {
      cleanup()
    }
  }, [cleanup])

  const startTimer = useCallback(() => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current)
    }
    timerIntervalRef.current = window.setInterval(() => {
      if (poseServiceRef.current) {
        const t = poseServiceRef.current.getElapsedTime()
        elapsedTimeRef.current = t
        setElapsedTime(t)
        setCaloriesBurned(poseServiceRef.current.getCaloriesBurned())
        if (selectedExercise === 'squat') {
          setKneeAngle(poseServiceRef.current.getKneeAngle())
        } else if (selectedExercise === 'pushup') {
          setElbowAngle(poseServiceRef.current.getElbowAngle())
        }
      }
    }, 200)
  }, [selectedExercise])

  const stopTimer = useCallback(() => {
    if (timerIntervalRef.current) {
      clearInterval(timerIntervalRef.current)
    }
  }, [])

  const drawMockSkeleton = useCallback((ctx: CanvasRenderingContext2D, width: number, height: number, angle: number, squatting: boolean) => {
    ctx.clearRect(0, 0, width, height)
    ctx.strokeStyle = '#00FF00'
    ctx.lineWidth = 3
    ctx.fillStyle = '#FF0000'

    const centerX = width / 2
    const hipY = squatting ? height * 0.55 : height * 0.4
    const kneeY = squatting ? height * 0.7 : height * 0.6
    const ankleY = height * 0.85
    const shoulderY = squatting ? height * 0.35 : height * 0.2
    const headY = squatting ? height * 0.2 : height * 0.08

    const legSpread = width * 0.15
    const leftHipX = centerX - legSpread
    const rightHipX = centerX + legSpread

    ctx.beginPath()
    ctx.moveTo(leftHipX, hipY)
    ctx.lineTo(rightHipX, hipY)
    ctx.stroke()

    const drawLeg = (hipX: number) => {
      const kneeX = hipX + (squatting ? (hipX < centerX ? -1 : 1) * 20 : 0)
      ctx.beginPath()
      ctx.moveTo(hipX, hipY)
      ctx.lineTo(kneeX, kneeY)
      ctx.lineTo(hipX, ankleY)
      ctx.stroke()

      ctx.beginPath()
      ctx.arc(hipX, hipY, 5, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(kneeX, kneeY, 5, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(hipX, ankleY, 5, 0, Math.PI * 2)
      ctx.fill()
    }

    drawLeg(leftHipX)
    drawLeg(rightHipX)

    ctx.beginPath()
    ctx.moveTo(centerX, shoulderY)
    ctx.lineTo(centerX, hipY)
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(centerX, headY, 20, 0, Math.PI * 2)
    ctx.strokeStyle = '#00FF00'
    ctx.lineWidth = 3
    ctx.stroke()
    ctx.fillStyle = '#FF0000'
    ctx.beginPath()
    ctx.arc(centerX, headY, 4, 0, Math.PI * 2)
    ctx.fill()

    const armSpread = width * 0.2
    ctx.beginPath()
    ctx.moveTo(centerX - armSpread, squatting ? shoulderY + 10 : shoulderY)
    ctx.lineTo(centerX, shoulderY)
    ctx.lineTo(centerX + armSpread, squatting ? shoulderY + 10 : shoulderY)
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(centerX, shoulderY, 5, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(centerX - armSpread, squatting ? shoulderY + 10 : shoulderY, 4, 0, Math.PI * 2)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(centerX + armSpread, squatting ? shoulderY + 10 : shoulderY, 4, 0, Math.PI * 2)
    ctx.fill()
  }, [])

  const handleComplete = useCallback((finalCount: number) => {
    if (isCompletingRef.current) return
    isCompletingRef.current = true

    stopTimer()
    if (mockIntervalRef.current) {
      clearInterval(mockIntervalRef.current)
    }
    poseServiceRef.current?.stop?.().catch(() => {})

    setIsRunning(false)
    setPoseStatus('ready')
    setIsCompleted(true)
    setCompletedSets(prev => prev + 1)

    const exercise = getExerciseById(selectedExercise)
    const durationMinutes = Math.max(1, Math.round(elapsedTimeRef.current / 60))
    const calories = exercise
      ? Math.round(((exercise.caloriesPerMinute / 3.5) * 3.5 * user.weight * durationMinutes) / 200)
      : 0
    const damage = exercise
      ? Math.round(exercise.damagePerMinute * durationMinutes * (1 + (user.difficulty === 'easy' ? 0.8 : user.difficulty === 'hard' ? 1.2 : 1)))
      : 0

    addExerciseRecord({
      name: exercise?.name || '运动',
      calories,
      time: Date.now(),
      reps: finalCount,
    })

    attackMonster(damage)

    setDamageValue(damage)
    setShowDamage(true)
    setTimeout(() => setShowDamage(false), 1500)
    // 延迟显示下一步引导
    setTimeout(() => setShowNextStep(true), 1800)
  }, [selectedExercise, user, addExerciseRecord, attackMonster, stopTimer])

  const startMockDetection = useCallback(() => {
    if (mockIntervalRef.current) {
      clearInterval(mockIntervalRef.current)
    }
    isCompletingRef.current = false
    elapsedTimeRef.current = 0
    setUseMock(true)
    setIsRunning(true)
    setPoseStatus('running')
    setIsCompleted(false)
    setCount(0)
    setKneeAngle(180)
    setElapsedTime(0)
    setCaloriesBurned(0)
    setCurrentPhase('站立')

    let mockCount = 0
    let mockAngle = 180
    let squatting = false
    let direction = -3
    let mockTime = 0

    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d')

    if (canvas && ctx) {
      const dpr = window.devicePixelRatio || 1
      const rect = canvas.getBoundingClientRect()
      canvas.width = rect.width * dpr
      canvas.height = rect.height * dpr
    }

    mockIntervalRef.current = window.setInterval(() => {
      mockAngle += direction
      mockTime += 0.05

      if (mockAngle <= 90) {
        direction = 3
        squatting = true
        setCurrentPhase('下蹲中')
      } else if (mockAngle >= 175) {
        direction = -3
        if (squatting) {
          squatting = false
          mockCount++
          setCount(mockCount)
          setCurrentPhase('站立')
          setCaloriesBurned(Math.round((5.0 * user.weight * (mockCount / 20)) / 200 * 10) / 10)
          if (mockCount >= SET_REPS) {
            elapsedTimeRef.current = Math.floor(mockTime)
            setElapsedTime(Math.floor(mockTime))
            handleComplete(mockCount)
            return
          }
        }
      }
      setKneeAngle(mockAngle)
      setElapsedTime(Math.floor(mockTime))

      if (ctx && canvas) {
        drawMockSkeleton(ctx, canvas.width, canvas.height, mockAngle, squatting)
      }
    }, 50)
  }, [drawMockSkeleton, handleComplete, user.weight])

  const startDetection = useCallback(async () => {
    if (isRunning || isLoading) return

    isCompletingRef.current = false
    elapsedTimeRef.current = 0
    setErrorMsg('')
    setIsLoading(true)
    setIsCompleted(false)
    setCount(0)
    setElapsedTime(0)
    setCaloriesBurned(0)

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      setErrorMsg('当前浏览器不支持摄像头访问，将使用模拟模式')
      setIsLoading(false)
      startMockDetection()
      return
    }

    try {
      const service = createPoseService({
        exerciseType: selectedExercise,
        videoElement: videoRef.current || undefined,
        canvasElement: canvasRef.current || undefined,
        userWeight: user.weight,
        onCount: (newCount: number) => {
          if (isCompletingRef.current) return
          setCount(newCount)
          if (newCount >= SET_REPS) {
            handleComplete(newCount)
          }
        },
        onStatusChange: (status: PoseStatus) => {
          setPoseStatus(status)
        },
        onError: (err: Error) => {
          console.error('Pose error:', err)
          setErrorMsg(err.message)
        },
      })

      poseServiceRef.current = service
      service.setCameraFacing(cameraFacing)

      const loaded = await service.load()
      if (!loaded) {
        throw new Error('姿态检测模型加载失败')
      }

      const started = await service.start()
      if (!started) {
        throw new Error('姿态检测启动失败')
      }

      setIsRunning(true)
      setUseMock(false)
      startTimer()
    } catch (err: any) {
      console.error('Camera error:', err)
      const msg = err?.message || '摄像头启动失败'

      if (msg.includes('Permission') || msg.includes('权限') || msg.includes('denied')) {
        setErrorMsg('摄像头权限被拒绝，请在浏览器设置中允许访问摄像头')
      } else if (msg.includes('NotFound') || msg.includes('找不到')) {
        setErrorMsg('未找到摄像头设备')
      } else {
        setErrorMsg(`${msg}，将使用模拟模式`)
      }

      if (videoRef.current?.srcObject) {
        const stream = videoRef.current.srcObject as MediaStream
        stream.getTracks().forEach((track) => track.stop())
        videoRef.current.srcObject = null
      }

      startMockDetection()
    } finally {
      setIsLoading(false)
    }
  }, [cameraFacing, selectedExercise, startMockDetection, handleComplete, startTimer, user.weight, isRunning, isLoading])

  const stopDetection = useCallback(async () => {
    stopTimer()
    isCompletingRef.current = false

    if (useMock) {
      if (mockIntervalRef.current) {
        clearInterval(mockIntervalRef.current)
      }
      setIsRunning(false)
      setPoseStatus('idle')
      setCurrentPhase('待机')
      setUseMock(false)
      return
    }

    try {
      await poseServiceRef.current?.stop?.()
    } catch (_) {
    }
    setIsRunning(false)
    setPoseStatus('ready')
  }, [useMock, stopTimer])

  const toggleCamera = useCallback(() => {
    const newFacing = cameraFacing === 'user' ? 'environment' : 'user'
    setCameraFacing(newFacing)
    if (isRunning) {
      stopDetection().then(() => {
        setTimeout(() => {
          startDetection()
        }, 300)
      })
    }
  }, [cameraFacing, isRunning, stopDetection, startDetection])

  const resetSession = useCallback(() => {
    isCompletingRef.current = false
    elapsedTimeRef.current = 0
    setIsCompleted(false)
    setShowNextStep(false)
    setCount(0)
    setKneeAngle(180)
    setElbowAngle(180)
    setElapsedTime(0)
    setCaloriesBurned(0)
    setCurrentPhase('待机')
    if (poseServiceRef.current) {
      poseServiceRef.current.resetCount()
    }
  }, [])

  const changeExercise = useCallback((id: ExerciseType) => {
    if (isRunning) return
    setSelectedExercise(id)
    resetSession()
    if (poseServiceRef.current) {
      poseServiceRef.current.setExerciseType(id)
    }
  }, [isRunning, resetSession])

  const goToNextExercise = useCallback(() => {
    const next = trainingFlow[selectedExercise].next
    setSelectedExercise(next)
    resetSession()
    if (poseServiceRef.current) {
      poseServiceRef.current.setExerciseType(next)
    }
    setTimeout(() => startDetection(), 200)
  }, [selectedExercise, resetSession, startDetection])

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const progress = (count / SET_REPS) * 100

  const getAngleDisplay = () => {
    if (selectedExercise === 'squat') {
      return { label: '膝关节', value: Math.round(kneeAngle), unit: '°' }
    } else if (selectedExercise === 'pushup') {
      return { label: '肘关节', value: Math.round(elbowAngle), unit: '°' }
    } else if (selectedExercise === 'plank') {
      return { label: '坚持', value: count, unit: '秒' }
    } else {
      return { label: '速率', value: count > 0 ? Math.round(count / (elapsedTime / 60 || 1)) : 0, unit: '次/分' }
    }
  }

  const angleDisplay = getAngleDisplay()

  return (
    <div className="min-h-screen flex flex-col px-3 py-3 gap-3 bg-bg">
      <AnimatePresence>
        {showDamage && (
          <DamageNumber value={damageValue} type="damage" />
        )}
      </AnimatePresence>

      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="flex items-center justify-between"
      >
        <button
          onClick={() => navigate(-1)}
          className="w-8 h-8 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors text-text"
        >
          <ArrowLeft size={16} />
        </button>

        <div className="flex items-center gap-1.5 px-2 py-1 bg-card border border-border rounded-full">
          <Target className="w-3.5 h-3.5 text-purple" />
          <span className="font-bold text-xs">Day {days}</span>
        </div>

        <div className="flex items-center gap-1">
          {streak > 0 && (
            <div className="flex items-center gap-1 px-2 py-1 bg-card border border-border rounded-full">
              <Flame className="w-3.5 h-3.5 text-orange" />
              <span className="font-bold text-xs text-orange">{streak}天</span>
            </div>
          )}
          <div className="flex items-center gap-1 px-2 py-1 bg-card border border-border rounded-full">
            <Coins className="w-3.5 h-3.5 text-gold" />
            <span className="font-bold text-xs text-gold">{coins}</span>
          </div>
        </div>
      </motion.div>

      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.3, delay: 0.1 }}
        className="text-center"
      >
        <h1 className="text-xl font-bold bg-gradient-to-r from-purple via-blue to-green bg-clip-text text-transparent">
          姿态挑战
        </h1>
        <p className="text-text2 text-xs mt-0.5">
          击败 <span className="text-text font-bold">{monster.name}</span> · Lv.{monster.level}
        </p>
      </motion.div>

      <Card className="p-1.5 bg-gradient-to-r from-purple/5 to-blue/5">
        <div className="grid grid-cols-4 gap-1.5">
          {exercises.map((ex) => (
            <button
              key={ex.id}
              onClick={() => changeExercise(ex.id)}
              disabled={isRunning}
              className={`flex flex-col items-center justify-center gap-0.5 py-2 px-1.5 rounded-lg font-bold text-xs transition-all duration-200 ${
                selectedExercise === ex.id
                  ? 'bg-gradient-to-br from-purple to-blue text-white shadow-md shadow-purple/20 scale-105'
                  : 'text-text2 hover:text-text hover:bg-white/50'
              } ${isRunning ? 'opacity-50 cursor-not-allowed scale-100' : ''}`}
            >
              <span className="text-xl">{ex.emoji}</span>
              <span className="text-[10px]">{ex.name}</span>
            </button>
          ))}
        </div>
      </Card>

      <Card className="p-0 overflow-hidden shadow-lg shadow-purple/10 max-w-full">
        <div className="relative w-full mx-auto bg-gradient-to-br from-bg2 to-bg rounded-xl overflow-hidden" style={{ aspectRatio: '3 / 2', maxWidth: '100%' }}>
          <video
            ref={videoRef}
            className="absolute inset-0 w-full h-full object-cover"
            playsInline
            muted
          />
          <canvas
            ref={canvasRef}
            className="absolute inset-0 w-full h-full pointer-events-none"
            style={{ imageRendering: 'crisp-edges' }}
          />

          {!isRunning && poseStatus === 'idle' && !useMock && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-bg2/80">
              <div className="w-12 h-12 mb-2 rounded-full bg-gradient-to-br from-blue to-purple flex items-center justify-center">
                <Camera size={24} className="text-white" />
              </div>
              <p className="text-text font-bold text-sm">点击下方按钮开始检测</p>
              <p className="text-text3 text-[10px] mt-0.5">AI实时识别运动姿态</p>
            </div>
          )}

          {isLoading && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-bg2/90">
              <div className="w-10 h-10 mb-2 border-4 border-purple/30 border-t-purple rounded-full animate-spin" />
              <p className="text-text font-bold text-sm">正在加载AI模型...</p>
              <p className="text-text3 text-[10px] mt-0.5">首次加载可能需要几秒</p>
            </div>
          )}

          {errorMsg && !isRunning && !isCompleted && (
            <div className="absolute top-2 left-2 right-2 bg-orange/20 border border-orange/50 rounded-xl p-2 flex items-start gap-1.5">
              <AlertTriangle size={14} className="text-orange shrink-0 mt-0.5" />
              <p className="text-orange text-[10px]">{errorMsg}</p>
            </div>
          )}

          {useMock && isRunning && (
            <div className="absolute top-2 right-2 bg-blue/20 border border-blue/50 rounded-lg px-1.5 py-0.5 flex items-center gap-1">
              <span className="w-1.5 h-1.5 bg-blue rounded-full animate-pulse" />
              <span className="text-blue text-[10px] font-bold">模拟模式</span>
            </div>
          )}

          {isRunning && !useMock && (
            <div className="absolute top-2 right-2 bg-green/20 border border-green/50 rounded-lg px-1.5 py-0.5 flex items-center gap-1">
              <span className="w-1.5 h-1.5 bg-green rounded-full animate-pulse" />
              <span className="text-green text-[10px] font-bold">AI检测中</span>
            </div>
          )}

          {/* 动作进度图标网格 - 游戏化引导 */}
          {isRunning && (
            <div className="absolute bottom-1.5 left-1.5 right-1.5 flex justify-center gap-1">
              {Array.from({ length: SET_REPS }).map((_, i) => {
                const isDone = i < count
                const isCurrent = i === count
                return (
                  <motion.div
                    key={i}
                    initial={{ scale: 0.8, opacity: 0.5 }}
                    animate={{
                      scale: isCurrent ? 1.1 : 1,
                      opacity: 1,
                    }}
                    transition={{ type: 'spring', stiffness: 300 }}
                    className={`w-6 h-6 rounded-md flex items-center justify-center text-xs backdrop-blur-sm border-2 ${
                      isDone
                        ? 'bg-gradient-to-br from-green to-green-dark border-green text-white shadow-md shadow-green/30'
                        : isCurrent
                          ? 'bg-gold/30 border-gold animate-pulse'
                          : 'bg-bg2/60 border-border/50 grayscale opacity-50'
                    }`}
                  >
                    {isDone ? '✓' : exercises.find(e => e.id === selectedExercise)?.emoji}
                  </motion.div>
                )
              })}
            </div>
          )}

          {isCompleted && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="absolute inset-0 flex flex-col items-center justify-center bg-black/60 backdrop-blur-sm"
            >
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ type: 'spring', delay: 0.2 }}
                className="w-12 h-12 mb-2 rounded-full bg-gradient-to-br from-green to-green-dark flex items-center justify-center"
              >
                <CheckCircle2 size={28} className="text-white" />
              </motion.div>
              <h3 className="text-lg font-bold text-white mb-0.5">挑战完成！</h3>
              <p className="text-white/80 mb-2 text-[10px]">
                你完成了 {SET_REPS} 次{exercises.find(e => e.id === selectedExercise)?.name}
              </p>
              <div className="grid grid-cols-3 gap-1.5 px-3 w-full max-w-xs">
                <div className="bg-white/10 rounded-md px-1.5 py-1 text-center">
                  <div className="text-sm font-bold text-orange">{damageValue}</div>
                  <div className="text-[9px] text-white/60">伤害</div>
                </div>
                <div className="bg-white/10 rounded-md px-1.5 py-1 text-center">
                  <div className="text-sm font-bold text-blue">{formatTime(elapsedTime)}</div>
                  <div className="text-[9px] text-white/60">用时</div>
                </div>
                <div className="bg-white/10 rounded-md px-1.5 py-1 text-center">
                  <div className="text-sm font-bold text-green">{caloriesBurned}</div>
                  <div className="text-[9px] text-white/60">卡路里</div>
                </div>
              </div>
            </motion.div>
          )}
        </div>
      </Card>

      <Card className="flex flex-col gap-2">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-sm text-text flex items-center gap-1.5">
            <Activity className="w-4 h-4 text-purple" />
            战斗数据
          </h2>
          <div className="flex items-center gap-1 px-2 py-0.5 bg-gold/10 rounded-full">
            <Target size={10} className="text-gold" />
            <span className="text-[10px] text-gold font-bold">{count}/{SET_REPS}</span>
          </div>
        </div>

        <div className="grid grid-cols-4 gap-1.5">
          <div className="bg-bg2 rounded-lg p-2 text-center">
            <div className="flex items-center justify-center gap-1 mb-0.5">
              <Zap className="w-3 h-3 text-purple" />
              <span className="text-[9px] text-text3">计数</span>
            </div>
            <div className="text-base font-bold text-text">{count}</div>
          </div>
          <div className="bg-bg2 rounded-lg p-2 text-center">
            <div className="flex items-center justify-center gap-1 mb-0.5">
              <Clock className="w-3 h-3 text-blue" />
              <span className="text-[9px] text-text3">时长</span>
            </div>
            <div className="text-base font-bold text-text">{formatTime(elapsedTime)}</div>
          </div>
          <div className="bg-bg2 rounded-lg p-2 text-center">
            <div className="flex items-center justify-center gap-1 mb-0.5">
              <Flame className="w-3 h-3 text-orange" />
              <span className="text-[9px] text-text3">卡路里</span>
            </div>
            <div className="text-base font-bold text-orange">{caloriesBurned}</div>
          </div>
          <div className="bg-bg2 rounded-lg p-2 text-center">
            <div className="flex items-center justify-center gap-1 mb-0.5">
              <Target className="w-3 h-3 text-green" />
              <span className="text-[9px] text-text3">{angleDisplay.label}</span>
            </div>
            <div className="text-base font-bold text-green">{angleDisplay.value}</div>
          </div>
        </div>

        <div>
          <div className="flex justify-between text-[10px] text-text3 mb-1">
            <span className="flex items-center gap-1">
              <Sparkles size={10} className="text-gold" />
              击败进度
            </span>
          </div>
          <div className="h-2 bg-bg2 rounded-full overflow-hidden border border-border">
            <motion.div
              className="h-full bg-gradient-to-r from-purple via-blue to-green rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${Math.min(100, progress)}%` }}
              transition={{ duration: 0.3 }}
            />
          </div>
        </div>
      </Card>

      <Card className="flex items-center gap-2">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center text-xl ${
          isRunning
            ? currentPhase === '下蹲中' || currentPhase === '下放中' || currentPhase === '跳跃中' || currentPhase === '抬腿中'
              ? 'bg-gradient-to-br from-gold to-orange animate-pulse'
              : 'bg-gradient-to-br from-green to-green-dark'
            : 'bg-bg2'
        }`}>
          {exerciseInfo?.emoji || '🏋️'}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-bold text-sm">
            {isRunning ? currentPhase : '准备就绪'}
          </div>
          <div className="text-[10px] text-text3">
            {isRunning
              ? count > 0
                ? `已完成 ${count} 个，继续加油！`
                : '请按照标准动作开始运动'
              : '点击开始按钮开启检测'
            }
          </div>
        </div>
        {isRunning && (
          <div className="flex flex-col items-center gap-0.5">
            <div className="w-2 h-2 rounded-full bg-green animate-pulse" />
            <span className="text-[9px] text-text3">检测中</span>
          </div>
        )}
      </Card>

      {/* 完成后下一步引导卡片 */}
      <AnimatePresence>
        {showNextStep && isCompleted && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            transition={{ type: 'spring', stiffness: 200 }}
          >
            <Card className="bg-gradient-to-br from-purple/15 to-blue/15 border-purple/30">
              <div className="flex flex-col gap-2">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-green to-green-dark flex items-center justify-center">
                    <CheckCircle2 size={18} className="text-white" />
                  </div>
                  <div className="flex-1">
                    <div className="font-bold text-sm text-text">本组完成！已完成 {completedSets} 组</div>
                    <div className="text-[10px] text-text3">{trainingFlow[selectedExercise].tip}</div>
                  </div>
                </div>

                <div className="flex items-center gap-2 bg-bg2/60 rounded-lg p-2">
                  <span className="text-2xl">{exercises.find(e => e.id === trainingFlow[selectedExercise].next)?.emoji}</span>
                  <div className="flex-1">
                    <div className="text-[10px] text-text3">推荐下一步</div>
                    <div className="font-bold text-sm text-text">{trainingFlow[selectedExercise].label}</div>
                  </div>
                  <Button
                    variant="purple"
                    size="sm"
                    icon={<Play size={14} />}
                    onClick={goToNextExercise}
                  >
                    继续
                  </Button>
                </div>

                <div className="flex gap-1.5">
                  <Button
                    variant="secondary"
                    size="sm"
                    fullWidth
                    icon={<RotateCcw size={12} />}
                    onClick={() => {
                      resetSession()
                      setTimeout(() => startDetection(), 100)
                    }}
                  >
                    重做本组
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    fullWidth
                    onClick={() => navigate(-1)}
                  >
                    结束训练
                  </Button>
                </div>
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="space-y-1.5">
        {!isRunning ? (
          <Button
            variant="purple"
            size="md"
            fullWidth
            icon={isLoading ? undefined : <Play size={16} />}
            loading={isLoading}
            onClick={startDetection}
            disabled={isCompleted}
          >
            {isCompleted ? '已完成挑战' : isLoading ? '加载中...' : '开始挑战'}
          </Button>
        ) : (
          <Button
            variant="primary"
            size="md"
            fullWidth
            icon={<Square size={16} />}
            onClick={stopDetection}
          >
            停止检测
          </Button>
        )}

        <div className="grid grid-cols-3 gap-1.5">
          <Button
            variant="secondary"
            size="sm"
            icon={<RotateCcw size={12} />}
            onClick={toggleCamera}
            disabled={isLoading}
          >
            切换镜头
          </Button>
          <Button
            variant="secondary"
            size="sm"
            icon={<RefreshCw size={12} />}
            onClick={resetSession}
            disabled={isRunning}
          >
            重置
          </Button>
          <Button
            variant="secondary"
            size="sm"
            icon={<Clock size={12} />}
            onClick={() => {}}
            disabled
          >
            倒计时
          </Button>
        </div>

        {isCompleted && !showNextStep && (
          <Button
            variant="purple"
            size="md"
            fullWidth
            icon={<Zap size={16} />}
            onClick={() => {
              resetSession()
              setTimeout(() => startDetection(), 100)
            }}
          >
            再来一组
          </Button>
        )}
      </div>
    </div>
  )
}
