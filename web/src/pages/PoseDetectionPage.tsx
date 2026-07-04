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

const TARGET_REPS = 15

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
      canvas.width = 640
      canvas.height = 480
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
          if (mockCount >= TARGET_REPS) {
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
          if (newCount >= TARGET_REPS) {
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

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const progress = (count / TARGET_REPS) * 100

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
    <div className="min-h-full flex flex-col px-4 py-4 gap-4">
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
          className="w-9 h-9 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors text-text"
        >
          <ArrowLeft size={18} />
        </button>

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
        className="text-center"
      >
        <h1 className="text-2xl font-black bg-gradient-to-r from-purple via-blue to-green bg-clip-text text-transparent">
          姿态挑战
        </h1>
        <p className="text-text2 text-sm mt-1">
          击败 <span className="text-text font-bold">{monster.name}</span> · Lv.{monster.level}
        </p>
      </motion.div>

      <Card className="p-2 bg-gradient-to-r from-purple/5 to-blue/5">
        <div className="grid grid-cols-4 gap-2">
          {exercises.map((ex) => (
            <button
              key={ex.id}
              onClick={() => changeExercise(ex.id)}
              disabled={isRunning}
              className={`flex flex-col items-center justify-center gap-1 py-3 px-2 rounded-xl font-bold text-sm transition-all duration-200 ${
                selectedExercise === ex.id
                  ? 'bg-gradient-to-br from-purple to-blue text-white shadow-md shadow-purple/20 scale-105'
                  : 'text-text2 hover:text-text hover:bg-white/50'
              } ${isRunning ? 'opacity-50 cursor-not-allowed scale-100' : ''}`}
            >
              <span className="text-2xl">{ex.emoji}</span>
              <span className="text-xs">{ex.name}</span>
            </button>
          ))}
        </div>
      </Card>

      <Card className="p-0 overflow-hidden shadow-lg shadow-purple/10">
        <div className="relative aspect-video bg-gradient-to-br from-bg2 to-bg">
          <video
            ref={videoRef}
            className="absolute inset-0 w-full h-full object-cover"
            playsInline
            muted
            style={{ transform: cameraFacing === 'user' ? 'scaleX(-1)' : 'none' }}
          />
          <canvas
            ref={canvasRef}
            className="absolute inset-0 w-full h-full object-cover"
            style={{ transform: cameraFacing === 'user' ? 'scaleX(-1)' : 'none' }}
          />

          {!isRunning && poseStatus === 'idle' && !useMock && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-bg2/80">
              <div className="w-16 h-16 mb-3 rounded-full bg-gradient-to-br from-blue to-purple flex items-center justify-center">
                <Camera size={32} className="text-white" />
              </div>
              <p className="text-text font-bold">点击下方按钮开始检测</p>
              <p className="text-text3 text-xs mt-1">AI实时识别运动姿态</p>
            </div>
          )}

          {isLoading && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-bg2/90">
              <div className="w-12 h-12 mb-3 border-4 border-purple/30 border-t-purple rounded-full animate-spin" />
              <p className="text-text font-bold">正在加载AI模型...</p>
              <p className="text-text3 text-xs mt-1">首次加载可能需要几秒</p>
            </div>
          )}

          {errorMsg && !isRunning && !isCompleted && (
            <div className="absolute top-3 left-3 right-3 bg-orange/20 border border-orange/50 rounded-xl p-3 flex items-start gap-2">
              <AlertTriangle size={18} className="text-orange shrink-0 mt-0.5" />
              <p className="text-orange text-xs">{errorMsg}</p>
            </div>
          )}

          {useMock && isRunning && (
            <div className="absolute top-3 right-3 bg-blue/20 border border-blue/50 rounded-lg px-2 py-1 flex items-center gap-1.5">
              <span className="w-2 h-2 bg-blue rounded-full animate-pulse" />
              <span className="text-blue text-xs font-bold">模拟模式</span>
            </div>
          )}

          {isRunning && !useMock && (
            <div className="absolute top-3 right-3 bg-green/20 border border-green/50 rounded-lg px-2 py-1 flex items-center gap-1.5">
              <span className="w-2 h-2 bg-green rounded-full animate-pulse" />
              <span className="text-green text-xs font-bold">AI检测中</span>
            </div>
          )}

          {isCompleted && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="absolute inset-0 flex flex-col items-center justify-center bg-black/70 backdrop-blur-sm"
            >
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ type: 'spring', delay: 0.2 }}
                className="w-20 h-20 mb-4 rounded-full bg-gradient-to-br from-green to-green-dark flex items-center justify-center"
              >
                <CheckCircle2 size={48} className="text-white" />
              </motion.div>
              <h3 className="text-2xl font-black text-white mb-1">挑战完成！</h3>
              <p className="text-white/80 mb-4 text-sm">
                你完成了 {TARGET_REPS} 次{exercises.find(e => e.id === selectedExercise)?.name}
              </p>
              <div className="grid grid-cols-3 gap-2 px-4 w-full max-w-xs">
                <div className="bg-white/10 rounded-xl px-3 py-2 text-center">
                  <div className="text-lg font-black text-orange">{damageValue}</div>
                  <div className="text-[10px] text-white/60">造成伤害</div>
                </div>
                <div className="bg-white/10 rounded-xl px-3 py-2 text-center">
                  <div className="text-lg font-black text-blue">{formatTime(elapsedTime)}</div>
                  <div className="text-[10px] text-white/60">用时</div>
                </div>
                <div className="bg-white/10 rounded-xl px-3 py-2 text-center">
                  <div className="text-lg font-black text-green">{caloriesBurned}</div>
                  <div className="text-[10px] text-white/60">消耗卡路里</div>
                </div>
              </div>
            </motion.div>
          )}
        </div>
      </Card>

      <Card className="flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-text flex items-center gap-2">
            <Activity className="w-5 h-5 text-purple" />
            战斗数据
          </h2>
          <div className="flex items-center gap-1.5 px-3 py-1 bg-gold/10 rounded-full">
            <Target size={12} className="text-gold" />
            <span className="text-xs text-gold font-bold">目标 {TARGET_REPS}次</span>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="bg-bg2 rounded-xl p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <Zap className="w-4 h-4 text-purple" />
              <span className="text-xs text-text3">动作计数</span>
            </div>
            <div className="text-xl font-bold text-text">{count}<span className="text-xs font-normal text-text3 ml-1">次</span></div>
          </div>
          <div className="bg-bg2 rounded-xl p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <Clock className="w-4 h-4 text-blue" />
              <span className="text-xs text-text3">运动时长</span>
            </div>
            <div className="text-xl font-bold text-text">{formatTime(elapsedTime)}</div>
          </div>
          <div className="bg-bg2 rounded-xl p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <Flame className="w-4 h-4 text-orange" />
              <span className="text-xs text-text3">消耗卡路里</span>
            </div>
            <div className="text-xl font-bold text-orange">{caloriesBurned}<span className="text-xs font-normal text-text3 ml-1">kcal</span></div>
          </div>
          <div className="bg-bg2 rounded-xl p-3">
            <div className="flex items-center gap-1.5 mb-1">
              <Target className="w-4 h-4 text-green" />
              <span className="text-xs text-text3">{angleDisplay.label}</span>
            </div>
            <div className="text-xl font-bold text-green">{angleDisplay.value}<span className="text-xs font-normal text-text3 ml-1">{angleDisplay.unit}</span></div>
          </div>
        </div>

        <div>
          <div className="flex justify-between text-xs text-text3 mb-2">
            <span className="flex items-center gap-1.5">
              <Sparkles size={12} className="text-gold" />
              击败进度
            </span>
            <span className="font-bold text-text">{count} / {TARGET_REPS}</span>
          </div>
          <div className="h-3 bg-bg2 rounded-full overflow-hidden border border-border">
            <motion.div
              className="h-full bg-gradient-to-r from-purple via-blue to-green rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${Math.min(100, progress)}%` }}
              transition={{ duration: 0.3 }}
            />
          </div>
        </div>
      </Card>

      <Card className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <Activity className="text-gold" size={20} />
          <h2 className="font-bold text-text">动作状态</h2>
        </div>
        <div className="flex items-center gap-3">
          <div className={`w-14 h-14 rounded-xl flex items-center justify-center text-2xl ${
            isRunning
              ? currentPhase === '下蹲中' || currentPhase === '下放中' || currentPhase === '跳跃中' || currentPhase === '抬腿中'
                ? 'bg-gradient-to-br from-gold to-orange animate-pulse'
                : 'bg-gradient-to-br from-green to-green-dark'
              : 'bg-bg2'
          }`}>
            {exerciseInfo?.emoji || '🏋️'}
          </div>
          <div className="flex-1 min-w-0">
            <div className="font-bold text-lg">
              {isRunning ? currentPhase : '准备就绪'}
            </div>
            <div className="text-xs text-text3 mt-1">
              {isRunning
                ? count > 0
                  ? `已完成 ${count} 个动作，继续加油！`
                  : '请按照标准动作开始运动'
                : '点击开始按钮开启姿态检测'
              }
            </div>
          </div>
          {isRunning && (
            <div className="flex flex-col items-center gap-1">
              <div className="w-2.5 h-2.5 rounded-full bg-green animate-pulse" />
              <span className="text-[10px] text-text3">检测中</span>
            </div>
          )}
        </div>
      </Card>

      {exerciseInfo && (
        <Card className="bg-gradient-to-br from-purple/10 to-blue/10">
          <div className="flex items-center gap-3">
            <div className="text-3xl">{exerciseInfo.emoji}</div>
            <div className="flex-1 min-w-0">
              <div className="font-bold text-base text-text">{exerciseInfo.name}</div>
              <div className="text-xs text-text3 mt-1 flex items-center gap-3">
                <span className="flex items-center gap-1">
                  <Flame size={12} className="text-orange" />
                  {exerciseInfo.caloriesPerMinute}卡/分
                </span>
                <span className="flex items-center gap-1">
                  <Swords size={12} className="text-red" />
                  {exerciseInfo.damagePerMinute}伤/分
                </span>
              </div>
            </div>
            <div className="bg-white/50 rounded-xl px-3 py-2 text-center">
              <div className="text-[10px] text-text3">预计伤害</div>
              <div className="font-bold text-red text-lg">
                ~{Math.round(exerciseInfo.damagePerMinute * Math.max(1, Math.round(TARGET_REPS / 20 / 60)))}
              </div>
            </div>
          </div>
        </Card>
      )}

      <Card className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <Dumbbell className="text-blue" size={20} />
          <h2 className="font-bold text-text">设备状态</h2>
        </div>
        <div className="space-y-2">
          <div className="bg-bg2 rounded-xl p-3 flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-blue/20 flex items-center justify-center">
              <Camera size={18} className="text-blue" />
            </div>
            <div className="flex-1">
              <div className="font-bold text-sm text-text">
                {isRunning ? '摄像头已开启' : '摄像头未连接'}
              </div>
              <div className="text-xs text-text3">
                {cameraFacing === 'user' ? '前置摄像头' : '后置摄像头'}
              </div>
            </div>
            <div className={`w-2.5 h-2.5 rounded-full ${isRunning ? 'bg-green animate-pulse' : 'bg-text3'}`} />
          </div>
          <div className="bg-bg2 rounded-xl p-3 flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-purple/20 flex items-center justify-center">
              <Zap size={18} className="text-purple" />
            </div>
            <div className="flex-1">
              <div className="font-bold text-sm text-text">
                {poseStatus === 'running' ? 'AI识别运行中' : 'AI模型未启动'}
              </div>
              <div className="text-xs text-text3">
                MediaPipe Pose
              </div>
            </div>
            <div className={`w-2.5 h-2.5 rounded-full ${poseStatus === 'running' ? 'bg-green animate-pulse' : 'bg-text3'}`} />
          </div>
        </div>
      </Card>

      <div className="space-y-2">
        {!isRunning ? (
          <Button
            variant="purple"
            size="lg"
            fullWidth
            icon={isLoading ? undefined : <Play size={20} />}
            loading={isLoading}
            onClick={startDetection}
            disabled={isCompleted}
          >
            {isCompleted ? '已完成挑战' : isLoading ? '加载中...' : '开始挑战'}
          </Button>
        ) : (
          <Button
            variant="primary"
            size="lg"
            fullWidth
            icon={<Square size={20} />}
            onClick={stopDetection}
          >
            停止检测
          </Button>
        )}

        <div className="grid grid-cols-3 gap-2">
          <Button
            variant="secondary"
            icon={<RotateCcw size={16} />}
            onClick={toggleCamera}
            disabled={isLoading}
          >
            切换镜头
          </Button>
          <Button
            variant="secondary"
            icon={<RefreshCw size={16} />}
            onClick={resetSession}
            disabled={isRunning}
          >
            重置
          </Button>
          <Button
            variant="secondary"
            icon={<Clock size={16} />}
            onClick={() => {}}
            disabled
          >
            倒计时
          </Button>
        </div>

        {isCompleted && (
          <Button
            variant="purple"
            size="lg"
            fullWidth
            icon={<Zap size={20} />}
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
