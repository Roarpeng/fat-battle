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
  Heart,
  Star,
  Trophy,
  Plus,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Card from '../components/Card'
import Button from '../components/Button'
import DamageNumber from '../components/DamageNumber'
import { useGameStore, ACHIEVEMENTS_DEF } from '../store/useGameStore'
import { getExerciseById } from '../data/exercises'
import { PoseService, createPoseService, type ExerciseType, type PoseStatus, type AvatarMode, type CartoonColor } from '../services/poseService'
import {
  useXpDrops, XpDropOverlay,
  useAchievementPopup, AchievementPopupOverlay,
  useQuestPopup, QuestCompleteOverlay,
  useLevelUpPopup, LevelUpOverlay,
} from '../components/GameFeedback'

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

// 每个动作每次 rep 的伤害值（基础值）
const EXERCISE_DAMAGE: Record<ExerciseType, number> = {
  squat: 3,
  pushup: 4,
  highknee: 2,
  jumprope: 2,
  plank: 5,
  burpee: 8,
  lunge: 4,
  mountainclimber: 3,
}

interface PlanItem {
  type: ExerciseType
  name: string
  emoji: string
  targetReps: number
  damage: number
  completed: boolean
}

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
  const [avatarMode, setAvatarMode] = useState<AvatarMode>('cartoon')
  const [cartoonColor, setCartoonColor] = useState<CartoonColor>('blue')
  const [showAvatarSelector, setShowAvatarSelector] = useState(false)
  const [capturedPhotos, setCapturedPhotos] = useState<string[]>([])
  const [showPhotoPreview, setShowPhotoPreview] = useState(false)
  const [currentPhoto, setCurrentPhoto] = useState('')

  // ========== 游戏化 HUD 状态 ==========
  const [isPaused, setIsPaused] = useState(false)
  const [prepareProgress, setPrepareProgress] = useState(0)
  const [comboCount, setComboCount] = useState(0)
  const [comboMultiplier, setComboMultiplier] = useState(1.0)
  const [stamina, setStamina] = useState(100)
  const [isBossEnraged, setIsBossEnraged] = useState(false)
  const [showComboPopup, setShowComboPopup] = useState(false)

  // ========== 自动锻炼计划 ==========
  const [exercisePlan, setExercisePlan] = useState<PlanItem[]>([])
  const [currentPlanIndex, setCurrentPlanIndex] = useState(0)
  const [showAddMore, setShowAddMore] = useState(false)
  const [planAllDone, setPlanAllDone] = useState(false)

  const {
    attackMonster, addExerciseRecord, user, coins, streak, days, monster,
    addXp, checkAchievements, updateQuestProgress, generateDailyQuests, dailyQuests, playerLevel,
    setPendingAttack,
  } = useGameStore()

  // ========== 游戏化即时反馈系统 ==========
  const { drops, spawnXp } = useXpDrops()
  const { unlocks, showUnlock } = useAchievementPopup()
  const { completes, showQuestComplete } = useQuestPopup()
  const { levelUps, showLevelUp } = useLevelUpPopup()

  const exerciseInfo = getExerciseById(selectedExercise)

  // 当前计划项的目标次数
  const currentTargetReps = exercisePlan[currentPlanIndex]?.targetReps ?? SET_REPS

  // ========== 自动生成锻炼计划 ==========
  const generatePlan = useCallback((targetHp: number) => {
    const pool: ExerciseType[] = ['squat', 'pushup', 'highknee', 'plank', 'burpee', 'lunge', 'mountainclimber', 'jumprope']
    // 随机选 2-3 个动作
    const shuffled = [...pool].sort(() => Math.random() - 0.5)
    const numExercises = targetHp > 150 ? 3 : targetHp > 80 ? 2 : 2
    const selected = shuffled.slice(0, numExercises)

    // 难度系数
    const diffMult = user.difficulty === 'easy' ? 0.8 : user.difficulty === 'hard' ? 1.2 : 1.0
    const adjustedHp = Math.ceil(targetHp / diffMult)

    // 均分伤害
    const perExerciseDamage = Math.ceil(adjustedHp / selected.length)
    const plan: PlanItem[] = selected.map((type, i) => {
      const exInfo = exercises.find((e) => e.id === type)!
      const dmgPerRep = EXERCISE_DAMAGE[type]
      const isLast = i === selected.length - 1
      const targetDmg = isLast ? adjustedHp - perExerciseDamage * (selected.length - 1) : perExerciseDamage
      const reps = Math.max(5, Math.ceil(targetDmg / dmgPerRep))
      return {
        type,
        name: exInfo.name,
        emoji: exInfo.emoji,
        targetReps: reps,
        damage: reps * dmgPerRep * diffMult,
        completed: false,
      }
    })

    setExercisePlan(plan)
    setCurrentPlanIndex(0)
    setPlanAllDone(false)
    setSelectedExercise(plan[0].type)
  }, [user.difficulty])

  // 页面加载时生成计划
  useEffect(() => {
    if (exercisePlan.length === 0 && monster.hp > 0) {
      generatePlan(monster.hp)
    }
  }, [exercisePlan.length, monster.hp, generatePlan])

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

  // Boss 狂暴模式：HP < 30% 时画面红闪
  useEffect(() => {
    setIsBossEnraged(monster.hp < 30 && monster.hp > 0)
  }, [monster.hp])

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

    let attackType: 'missile' | 'knife' | 'bomb' | 'fireball' | 'lightning'
    if (calories >= 300) {
      attackType = 'bomb'
    } else if (calories >= 150) {
      attackType = 'fireball'
    } else if (calories >= 80) {
      attackType = 'lightning'
    } else if (calories >= 40) {
      attackType = 'knife'
    } else {
      attackType = 'missile'
    }

    setPendingAttack({
      damage,
      attackType,
      isOvereat: false,
    })

    // ========== 游戏化即时反馈系统 ==========

    // 1. 完成奖励 XP
    const completionXp = 20 + finalCount * 2
    const xpResult = addXp(completionXp)
    spawnXp(completionXp, undefined, undefined, '完成奖励!')

    // 2. 伤害奖励 XP
    const damageXp = Math.floor(damage / 5)
    if (damageXp > 0) {
      addXp(damageXp)
      spawnXp(damageXp, undefined, undefined, '伤害XP!')
    }

    // 3. 更新任务进度（记录之前已完成的任务）
    const beforeCompletedIds = new Set(dailyQuests.filter((q) => q.completed).map((q) => q.id))
    updateQuestProgress('exercise_count', 1)
    updateQuestProgress('attack_damage', damage)
    if (comboCount >= 3) {
      updateQuestProgress('combo_count', 1)
    }

    // 检查新完成的任务并弹出奖励
    const updatedQuests = useGameStore.getState().dailyQuests
    updatedQuests.forEach((q) => {
      if (q.completed && !beforeCompletedIds.has(q.id)) {
        showQuestComplete({ title: q.title, rewardCoins: q.rewardCoins, rewardXp: q.rewardXp })
        const questXpResult = addXp(q.rewardXp)
        spawnXp(q.rewardXp, undefined, undefined, `${q.title}!`)
        if (questXpResult.leveledUp && questXpResult.newLevel) {
          showLevelUp(questXpResult.newLevel)
        }
      }
    })

    // 4. 检查成就
    const newAchievements = checkAchievements()
    newAchievements.forEach((ach) => {
      const def = ACHIEVEMENTS_DEF.find((a) => a.id === ach.id)
      if (def) {
        showUnlock({
          id: ach.id,
          name: def.name,
          description: def.description,
          icon: def.icon,
          rarity: def.rarity,
          reward: def.reward,
        })
        spawnXp(def.reward, undefined, undefined, '成就!')
      }
    })

    // 5. 检查升级
    if (xpResult.leveledUp && xpResult.newLevel) {
      showLevelUp(xpResult.newLevel)
    }

    setDamageValue(damage)
    setShowDamage(true)
    setTimeout(() => setShowDamage(false), 1500)

    // 标记当前计划项为已完成
    setExercisePlan((prev) => {
      const updated = [...prev]
      if (updated[currentPlanIndex]) {
        updated[currentPlanIndex] = { ...updated[currentPlanIndex], completed: true }
      }
      return updated
    })
  }, [selectedExercise, user, addExerciseRecord, stopTimer, addXp, checkAchievements, updateQuestProgress, dailyQuests, comboCount, spawnXp, showUnlock, showQuestComplete, showLevelUp, currentPlanIndex, setPendingAttack])

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
          if (mockCount >= currentTargetReps) {
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
  }, [drawMockSkeleton, handleComplete, user.weight, currentTargetReps])

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
        gender: user.gender,
        avatarMode,
        cartoonColor,
        onPhotoCapture: (photoData) => {
          setCapturedPhotos(prev => [...prev, photoData])
          setCurrentPhoto(photoData)
          setShowPhotoPreview(true)
        },
        onCount: (newCount: number) => {
          if (isCompletingRef.current) return
          setCount(newCount)

          // 每次 rep 成功即时反馈
          const xpResult = addXp(2)
          spawnXp(2)
          updateQuestProgress('exercise_reps', 1)

          if (xpResult.leveledUp && xpResult.newLevel) {
            showLevelUp(xpResult.newLevel)
          }

          if (newCount >= currentTargetReps) {
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
        // 游戏化系统回调
        onPauseChange: (paused: boolean) => {
          setIsPaused(paused)
        },
        onPrepareProgress: (progress: number) => {
          setPrepareProgress(progress)
        },
        onComboChange: (combo: number, multiplier: number) => {
          setComboCount(combo)
          setComboMultiplier(multiplier)
          if (combo > 1) {
            setShowComboPopup(true)
            setTimeout(() => setShowComboPopup(false), 800)
          }
        },
        onStaminaChange: (staminaVal: number) => {
          setStamina(staminaVal)
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

      // 生成每日任务（如果今天还没生成）
      generateDailyQuests()

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
  }, [cameraFacing, selectedExercise, startMockDetection, handleComplete, startTimer, user.weight, user.gender, isRunning, isLoading, currentTargetReps])

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

  // ========== 自动轮换：完成一组后自动切换到下一个锻炼动作 ==========
  useEffect(() => {
    if (!isCompleted || planAllDone) return

    const nextIndex = currentPlanIndex + 1
    if (nextIndex < exercisePlan.length) {
      // 自动切换到下一个动作
      const timer = setTimeout(() => {
        const nextItem = exercisePlan[nextIndex]
        setCurrentPlanIndex(nextIndex)
        setSelectedExercise(nextItem.type)
        resetSession()
        if (poseServiceRef.current) {
          poseServiceRef.current.setExerciseType(nextItem.type)
        }
        setTimeout(() => startDetection(), 300)
      }, 2000)
      return () => clearTimeout(timer)
    } else {
      // 全部完成
      setPlanAllDone(true)
      const timer = setTimeout(() => setShowNextStep(true), 1800)
      return () => clearTimeout(timer)
    }
  }, [isCompleted, planAllDone, currentPlanIndex, exercisePlan, resetSession, startDetection])

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const progress = (count / currentTargetReps) * 100

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
    <div className="flex flex-col px-3 py-2 gap-2 bg-bg max-w-[480px] mx-auto" style={{ height: 'calc(100vh - 56px)' }}>
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
            <Star className="w-3.5 h-3.5 text-purple fill-purple" />
            <span className="font-bold text-xs text-purple">Lv.{playerLevel.level}</span>
          </div>
          <div className="flex items-center gap-1 px-2 py-1 bg-card border border-border rounded-full">
            <Coins className="w-3.5 h-3.5 text-gold" />
            <span className="font-bold text-xs text-gold">{coins}</span>
          </div>
          <button
            onClick={() => setShowAvatarSelector(true)}
            className="w-8 h-8 flex items-center justify-center bg-card border border-border rounded-full hover:bg-bg2 transition-colors"
          >
            <span className="text-lg">{avatarMode === 'real' ? '👤' : (cartoonColor === 'blue' ? '🦸' : '🦹')}</span>
          </button>
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

      {/* ========== 锻炼计划进度条 ========== */}
      <Card className="p-2 bg-gradient-to-r from-purple/5 to-blue/5">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
          {exercisePlan.map((item, idx) => (
            <div
              key={idx}
              className={`flex-shrink-0 flex flex-col items-center gap-0.5 px-2.5 py-1.5 rounded-lg border-2 transition-all ${
                idx === currentPlanIndex
                  ? 'border-purple bg-purple/15 scale-105'
                  : item.completed
                    ? 'border-green/50 bg-green/10 opacity-60'
                    : 'border-border bg-card/50 opacity-50'
              }`}
            >
              <span className="text-lg">{item.completed ? '✅' : item.emoji}</span>
              <span className={`text-[9px] font-bold ${idx === currentPlanIndex ? 'text-purple' : 'text-text2'}`}>
                {item.name}
              </span>
              <span className="text-[8px] text-text3">{item.targetReps}次</span>
            </div>
          ))}
          {/* 加量按钮 */}
          <button
            onClick={() => setShowAddMore(true)}
            disabled={isRunning}
            className="flex-shrink-0 flex flex-col items-center justify-center gap-0.5 px-2.5 py-1.5 rounded-lg border-2 border-dashed border-border bg-card/30 hover:border-purple hover:bg-purple/5 transition-all disabled:opacity-40"
          >
            <Plus size={16} className="text-text2" />
            <span className="text-[9px] font-bold text-text2">加量</span>
          </button>
        </div>
      </Card>

      <Card className="p-0 overflow-hidden shadow-lg shadow-purple/10 max-w-full flex-[2] min-h-0">
        <div className="relative w-full mx-auto bg-gradient-to-br from-bg2 to-bg rounded-xl overflow-hidden h-full" style={{ minHeight: 0 }}>
          {/* video 仅作为 MediaPipe 数据源，不直接显示，画面统一由 canvas 绘制 */}
          <video
            ref={videoRef}
            className="absolute inset-0 w-full h-full opacity-0"
            playsInline
            muted
          />
          <canvas
            ref={canvasRef}
            className="absolute inset-0 w-full h-full pointer-events-none"
          />

          {/* ========== 游戏化 HUD：左侧能量条 ========== */}
          {isRunning && (
            <div className="absolute left-1.5 top-1.5 bottom-8 w-10 flex flex-col gap-1.5 z-10">
              {/* 怪物 HP 条 */}
              <div className="flex-1 bg-black/40 backdrop-blur-sm rounded-lg border border-white/10 p-1 flex flex-col items-center gap-1">
                <Swords className="w-3 h-3 text-red" />
                <div className="flex-1 w-2 bg-bg2/80 rounded-full overflow-hidden relative">
                  <motion.div
                    className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-red to-orange rounded-full"
                    initial={{ height: '100%' }}
                    animate={{ height: `${Math.max(5, monster.hp)}%` }}
                    transition={{ duration: 0.5 }}
                  />
                </div>
                <span className="text-[8px] font-bold text-red">{monster.hp}</span>
              </div>
              {/* 动作进度条 */}
              <div className="flex-1 bg-black/40 backdrop-blur-sm rounded-lg border border-white/10 p-1 flex flex-col items-center gap-1">
                <Zap className="w-3 h-3 text-gold" />
                <div className="flex-1 w-2 bg-bg2/80 rounded-full overflow-hidden relative">
                  <motion.div
                    className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-purple to-blue rounded-full"
                    initial={{ height: 0 }}
                    animate={{ height: `${Math.min(100, progress)}%` }}
                    transition={{ duration: 0.3 }}
                  />
                </div>
                <span className="text-[8px] font-bold text-gold">{count}</span>
              </div>
              {/* 体力条 */}
              <div className="h-12 bg-black/40 backdrop-blur-sm rounded-lg border border-white/10 p-1 flex flex-col items-center gap-1">
                <Heart className="w-3 h-3 text-pink" />
                <div className="flex-1 w-2 bg-bg2/80 rounded-full overflow-hidden relative">
                  <motion.div
                    className={`absolute bottom-0 left-0 right-0 rounded-full ${
                      stamina < 20 ? 'bg-red' : stamina < 50 ? 'bg-orange' : 'bg-gradient-to-t from-green to-teal'
                    }`}
                    animate={{ height: `${stamina}%` }}
                    transition={{ duration: 0.2 }}
                  />
                </div>
                <span className={`text-[8px] font-bold ${stamina < 20 ? 'text-red' : 'text-green'}`}>{stamina}</span>
              </div>
            </div>
          )}

          {/* ========== 游戏化 HUD：右侧引导面板 ========== */}
          {isRunning && (
            <div className="absolute right-1.5 top-1.5 bottom-8 w-20 z-10">
              <div className="bg-black/40 backdrop-blur-sm rounded-lg border border-white/10 p-2 flex flex-col gap-1.5 h-full">
                {/* 动作图标 + 名称 */}
                <div className="flex items-center gap-1.5">
                  <span className="text-lg">{exerciseInfo?.emoji}</span>
                  <div className="flex-1 min-w-0">
                    <div className="text-[10px] font-bold text-white truncate">{exerciseInfo?.name}</div>
                    <div className="text-[8px] text-white/60">{exerciseInfo?.caloriesPerMinute}卡/分</div>
                  </div>
                </div>
                {/* 当前阶段 */}
                <div className={`text-center py-1 rounded-md text-[10px] font-bold ${
                  currentPhase === '待机'
                    ? 'bg-bg2/60 text-text3'
                    : currentPhase === '站立' || currentPhase === '上撑' || currentPhase === '地面'
                      ? 'bg-green/20 text-green'
                      : 'bg-gold/20 text-gold animate-pulse'
                }`}>
                  {currentPhase}
                </div>
                {/* 动作要点提示 */}
                <div className="flex-1 bg-bg2/40 rounded-md p-1.5 overflow-hidden">
                  <div className="text-[8px] text-white/50 mb-0.5 flex items-center gap-0.5">
                    <Target size={8} />
                    动作要领
                  </div>
                  <p className="text-[9px] text-white/80 leading-tight">
                    {exerciseInfo?.description}
                  </p>
                </div>
                {/* 实时数据 */}
                <div className="grid grid-cols-2 gap-1">
                  <div className="bg-bg2/40 rounded-md p-1 text-center">
                    <div className="text-[8px] text-white/50">{angleDisplay.label}</div>
                    <div className="text-[10px] font-bold text-green">{angleDisplay.value}{angleDisplay.unit}</div>
                  </div>
                  <div className="bg-bg2/40 rounded-md p-1 text-center">
                    <div className="text-[8px] text-white/50">卡路里</div>
                    <div className="text-[10px] font-bold text-orange">{caloriesBurned}</div>
                  </div>
                </div>
              </div>
            </div>
          )}

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

          {/* ========== 准备姿势确认UI ========== */}
          {isRunning && prepareProgress < 1 && prepareProgress > 0 && (
            <div className="absolute inset-0 z-20 flex flex-col items-center justify-center bg-black/50 backdrop-blur-sm">
              <div className="relative w-20 h-20 mb-3">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 36 36">
                  <path className="text-white/10" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3" />
                  <path className="text-green" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3" strokeDasharray={`${prepareProgress * 100}, 100`} />
                </svg>
                <div className="absolute inset-0 flex items-center justify-center">
                  <span className="text-white text-lg font-bold">{Math.ceil((1 - prepareProgress) * 2)}</span>
                </div>
              </div>
              <p className="text-white font-bold text-sm">准备姿势确认中...</p>
              <p className="text-white/60 text-[10px] mt-1">请保持全身在画面中</p>
            </div>
          )}

          {/* ========== 连击弹窗 ========== */}
          {showComboPopup && comboCount > 1 && (
            <motion.div
              initial={{ scale: 0.5, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.5, opacity: 0, y: -20 }}
              className="absolute top-1/4 left-1/2 -translate-x-1/2 z-20 pointer-events-none"
            >
              <div className="bg-gradient-to-r from-orange to-red rounded-lg px-3 py-1.5 shadow-lg shadow-orange/30 border border-white/20">
                <div className="text-white text-xs font-bold text-center">
                  🔥 {comboCount} 连击！
                </div>
                {comboMultiplier > 1 && (
                  <div className="text-yellow text-[10px] text-center font-bold">
                    x{comboMultiplier.toFixed(1)} 伤害加成
                  </div>
                )}
              </div>
            </motion.div>
          )}

          {/* ========== Boss狂暴模式红闪 ========== */}
          {isBossEnraged && (
            <motion.div
              animate={{ opacity: [0.3, 0.6, 0.3] }}
              transition={{ duration: 1.5, repeat: Infinity }}
              className="absolute inset-0 z-10 pointer-events-none border-4 border-red/50 rounded-xl"
            />
          )}

          {/* ========== 动作进度图标网格 - 游戏化引导 */}
          {isRunning && (
            <div className="absolute bottom-1.5 left-1.5 right-1.5 flex justify-center gap-1">
              {Array.from({ length: Math.min(currentTargetReps, 10) }).map((_, i) => {
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
                你完成了 {currentTargetReps} 次{exercises.find(e => e.id === selectedExercise)?.name}
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

          {/* ========== 游戏化即时反馈 Overlay ========== */}
          <XpDropOverlay drops={drops} />
          <AchievementPopupOverlay unlocks={unlocks} />
          <QuestCompleteOverlay completes={completes} />
          <LevelUpOverlay levelUps={levelUps} />
        </div>
      </Card>

      {/* ========== 底部紧凑控制面板 ========== */}
      <div className="flex-1 flex flex-col gap-1.5 min-h-0 overflow-y-auto">
        {/* 紧凑数据条 */}
        <div className="grid grid-cols-4 gap-1">
          <div className="bg-card rounded-lg p-1.5 text-center border border-border">
            <Zap className="w-3 h-3 text-purple mx-auto mb-0.5" />
            <div className="text-sm font-bold text-text">{count}</div>
            <div className="text-[8px] text-text3">计数</div>
          </div>
          <div className="bg-card rounded-lg p-1.5 text-center border border-border">
            <Clock className="w-3 h-3 text-blue mx-auto mb-0.5" />
            <div className="text-sm font-bold text-text">{formatTime(elapsedTime)}</div>
            <div className="text-[8px] text-text3">时长</div>
          </div>
          <div className="bg-card rounded-lg p-1.5 text-center border border-border">
            <Flame className="w-3 h-3 text-orange mx-auto mb-0.5" />
            <div className="text-sm font-bold text-orange">{caloriesBurned}</div>
            <div className="text-[8px] text-text3">卡路里</div>
          </div>
          <div className="bg-card rounded-lg p-1.5 text-center border border-border">
            <Target className="w-3 h-3 text-green mx-auto mb-0.5" />
            <div className="text-sm font-bold text-green">{angleDisplay.value}</div>
            <div className="text-[8px] text-text3">{angleDisplay.label}</div>
          </div>
        </div>

        {/* 进度条 */}
        <div className="h-1.5 bg-bg2 rounded-full overflow-hidden border border-border">
          <motion.div
            className="h-full bg-gradient-to-r from-purple via-blue to-green rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${Math.min(100, progress)}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>

        {/* 完成后下一步引导 */}
        <AnimatePresence>
          {showNextStep && isCompleted && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              transition={{ type: 'spring', stiffness: 200 }}
            >
              <Card className="bg-gradient-to-br from-purple/15 to-blue/15 border-purple/30 p-2">
                <div className="flex items-center gap-2 mb-1.5">
                  <div className="w-7 h-7 rounded-full bg-gradient-to-br from-green to-green-dark flex items-center justify-center">
                    <CheckCircle2 size={16} className="text-white" />
                  </div>
                  <div className="flex-1">
                    <div className="font-bold text-xs text-text">
                      {planAllDone ? '🎉 全部完成！脂肪怪已被击败！' : `本组完成！已完成 ${completedSets} 组`}
                    </div>
                    <div className="text-[9px] text-text3">
                      {planAllDone ? '今天的锻炼目标已达成' : trainingFlow[selectedExercise].tip}
                    </div>
                  </div>
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
              </Card>
            </motion.div>
          )}
        </AnimatePresence>

        {/* 主控制按钮 */}
        <div className="mt-auto space-y-1.5">
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
              {isCompleted ? '已完成挑战' : isLoading ? '加载中...' : `开始 ${exerciseInfo?.name || '挑战'} · ${currentTargetReps}次`}
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
              icon={<Camera size={12} />}
              onClick={() => {
                const photo = poseServiceRef.current?.capturePhoto()
                if (photo) {
                  setCapturedPhotos(prev => [...prev, photo])
                  setCurrentPhoto(photo)
                  setShowPhotoPreview(true)
                }
              }}
              disabled={!isRunning}
            >
              拍照
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

      {/* ========== 加量弹窗 ========== */}
      {showAddMore && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={() => setShowAddMore(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-bg2 rounded-2xl p-4 max-w-[340px] w-[85%] border border-border"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-bold text-text mb-3 flex items-center gap-1.5">
              <Plus size={16} className="text-purple" />
              加量训练
            </h3>
            <p className="text-[10px] text-text3 mb-3">选择额外动作加入锻炼计划</p>
            <div className="grid grid-cols-4 gap-2 max-h-[240px] overflow-y-auto">
              {exercises.map((ex) => (
                <button
                  key={ex.id}
                  onClick={() => {
                    setExercisePlan((prev) => [...prev, {
                      type: ex.id,
                      name: ex.name,
                      emoji: ex.emoji,
                      targetReps: 5,
                      damage: 5 * EXERCISE_DAMAGE[ex.id],
                      completed: false,
                    }])
                    setShowAddMore(false)
                  }}
                  className="flex flex-col items-center gap-1 p-2 rounded-lg border-2 border-border hover:border-purple hover:bg-purple/5 transition-all"
                >
                  <span className="text-xl">{ex.emoji}</span>
                  <span className="text-[9px] font-bold text-text2">{ex.name}</span>
                  <span className="text-[8px] text-text3">+5次</span>
                </button>
              ))}
            </div>
            <Button variant="secondary" size="sm" fullWidth className="mt-3" onClick={() => setShowAddMore(false)}>
              取消
            </Button>
          </motion.div>
        </div>
      )}

      {showAvatarSelector && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={() => setShowAvatarSelector(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-bg2 rounded-2xl p-4 max-w-[340px] w-[85%] border border-border"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-bold text-text mb-3 flex items-center gap-1.5">
              <Sparkles size={16} className="text-purple" />
              选择形象
            </h3>
            <p className="text-[10px] text-text3 mb-3">选择你在游戏中的形象</p>
            
            <div className="grid grid-cols-2 gap-2 mb-3">
              <button
                onClick={() => {
                  setAvatarMode('real')
                  setShowAvatarSelector(false)
                  if (poseServiceRef.current) {
                    poseServiceRef.current.setAvatarMode('real')
                  }
                }}
                className={`flex flex-col items-center gap-2 p-3 rounded-xl border-2 transition-all ${
                  avatarMode === 'real' ? 'border-purple bg-purple/15' : 'border-border hover:border-purple/50'
                }`}
              >
                <span className="text-3xl">👤</span>
                <span className="text-xs font-bold text-text">真人模式</span>
                <span className="text-[8px] text-text3">显示摄像头画面</span>
              </button>
              <button
                onClick={() => {
                  setAvatarMode('cartoon')
                  setShowAvatarSelector(false)
                  if (poseServiceRef.current) {
                    poseServiceRef.current.setAvatarMode('cartoon')
                  }
                }}
                className={`flex flex-col items-center gap-2 p-3 rounded-xl border-2 transition-all ${
                  avatarMode === 'cartoon' ? 'border-purple bg-purple/15' : 'border-border hover:border-purple/50'
                }`}
              >
                <span className="text-3xl">{cartoonColor === 'blue' ? '🦸' : '🦹'}</span>
                <span className="text-xs font-bold text-text">卡通模式</span>
                <span className="text-[8px] text-text3">火柴人形象</span>
              </button>
            </div>

            {avatarMode === 'cartoon' && (
              <div className="mb-3">
                <p className="text-[10px] text-text3 mb-2">选择颜色</p>
                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      setCartoonColor('blue')
                      if (poseServiceRef.current) {
                        poseServiceRef.current.setCartoonColor('blue')
                      }
                    }}
                    className={`w-10 h-10 rounded-full border-2 transition-all ${
                      cartoonColor === 'blue' ? 'border-white scale-110' : 'border-transparent'
                    }`}
                    style={{ background: 'linear-gradient(135deg, #3498DB, #87CEEB)' }}
                  />
                  <button
                    onClick={() => {
                      setCartoonColor('pink')
                      if (poseServiceRef.current) {
                        poseServiceRef.current.setCartoonColor('pink')
                      }
                    }}
                    className={`w-10 h-10 rounded-full border-2 transition-all ${
                      cartoonColor === 'pink' ? 'border-white scale-110' : 'border-transparent'
                    }`}
                    style={{ background: 'linear-gradient(135deg, #FF69B4, #FFC0CB)' }}
                  />
                </div>
              </div>
            )}

            <Button variant="secondary" size="sm" fullWidth onClick={() => setShowAvatarSelector(false)}>
              确定
            </Button>
          </motion.div>
        </div>
      )}

      {showPhotoPreview && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm" onClick={() => setShowPhotoPreview(false)}>
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-bg2 rounded-2xl p-4 max-w-[340px] w-[85%] border border-border"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-sm font-bold text-text mb-3 flex items-center gap-1.5">
              <Camera size={16} className="text-purple" />
              照片预览
            </h3>
            
            <div className="relative bg-black rounded-xl overflow-hidden mb-3 aspect-video">
              <img src={currentPhoto} alt="Captured" className="w-full h-full object-contain" />
              <div className="absolute top-2 right-2 bg-black/60 backdrop-blur-sm rounded-full px-2 py-1">
                <span className="text-[10px] text-white font-bold">标准动作!</span>
              </div>
            </div>

            <div className="flex gap-2">
              <Button variant="secondary" size="sm" fullWidth onClick={() => setShowPhotoPreview(false)}>
                关闭
              </Button>
              <Button variant="purple" size="sm" fullWidth onClick={() => {
                const link = document.createElement('a')
                link.download = `fat-battle-${Date.now()}.png`
                link.href = currentPhoto
                link.click()
              }}>
                保存
              </Button>
            </div>

            {capturedPhotos.length > 0 && (
              <div className="mt-3">
                <p className="text-[10px] text-text3 mb-2">已捕获照片 ({capturedPhotos.length})</p>
                <div className="flex gap-2 overflow-x-auto pb-2">
                  {capturedPhotos.map((photo, idx) => (
                    <button
                      key={idx}
                      onClick={() => setCurrentPhoto(photo)}
                      className={`w-12 h-12 rounded-lg overflow-hidden border-2 flex-shrink-0 transition-all ${
                        currentPhoto === photo ? 'border-purple' : 'border-border'
                      }`}
                    >
                      <img src={photo} alt={`Photo ${idx + 1}`} className="w-full h-full object-cover" />
                    </button>
                  ))}
                </div>
              </div>
            )}
          </motion.div>
        </div>
      )}
    </div>
  )
}
