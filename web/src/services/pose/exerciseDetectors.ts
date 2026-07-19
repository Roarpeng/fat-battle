// ========== 检测算法层：8种运动的检测算法 ==========
import type { ExerciseType, PoseLandmark } from '../poseTypes'
import {
  LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_ELBOW, RIGHT_ELBOW,
  LEFT_WRIST, RIGHT_WRIST, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE,
  LEFT_ANKLE, RIGHT_ANKLE,
} from '../poseTypes'
import type { ExerciseStates, DetectionThresholds } from './types'

export interface DetectionContext {
  landmarks: PoseLandmark[]
  thresholds: DetectionThresholds
  states: ExerciseStates
  userWeight: number
  /** 一次动作计数成功时调用：检查体力是否足够，更新体力与连击。返回是否应当计入计数。 */
  handleRepSuccess: () => boolean
  /** 更新已消耗卡路里总量 */
  setCalories: (calories: number) => void
  /** 触发计数回调 */
  onCount: (count: number) => void
}

export type ExerciseDetector = {
  name: ExerciseType
  detect: (ctx: DetectionContext) => void
}

// ========== 工具函数 ==========

export function calculateAngle(
  p1: PoseLandmark,
  p2: PoseLandmark,
  p3: PoseLandmark
): number {
  const v1 = { x: p1.x - p2.x, y: p1.y - p2.y }
  const v2 = { x: p3.x - p2.x, y: p3.y - p2.y }

  const dot = v1.x * v2.x + v1.y * v2.y
  const mag1 = Math.sqrt(v1.x * v1.x + v1.y * v1.y)
  const mag2 = Math.sqrt(v2.x * v2.x + v2.y * v2.y)

  if (mag1 === 0 || mag2 === 0) return 180

  const cos = Math.max(-1, Math.min(1, dot / (mag1 * mag2)))
  return (Math.acos(cos) * 180) / Math.PI
}

export function checkVisibility(landmarks: PoseLandmark[], indices: number[], threshold: number = 0.5): boolean {
  return indices.every(i => {
    const lm = landmarks[i]
    return lm && (lm.visibility ?? 0) >= threshold
  })
}

export function calculateCalories(exercise: ExerciseType, count: number, userWeight: number): number {
  const metValues: Record<ExerciseType, number> = {
    squat: 5.0,
    pushup: 4.5,
    jumprope: 10.0,
    highknee: 9.0,
    plank: 3.0,
    burpee: 8.0,
    lunge: 5.5,
    mountainclimber: 7.0,
  }

  const repsPerMinute: Record<ExerciseType, number> = {
    squat: 20,
    pushup: 25,
    jumprope: 100,
    highknee: 80,
    plank: 1,
    burpee: 10,
    lunge: 30,
    mountainclimber: 60,
  }

  const met = metValues[exercise]
  const minutes = count / repsPerMinute[exercise]
  const calories = (met * userWeight * minutes) / 200

  return Math.round(calories * 10) / 10
}

// ========== 检测算法 ==========

/** 深蹲（膝盖角度阈值） */
export function detectSquat(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.squat
  const requiredIndices = [LEFT_HIP, LEFT_KNEE, LEFT_ANKLE, RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const leftAngle = calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
  const rightAngle = calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])
  const avgAngle = (leftAngle + rightAngle) / 2

  state.kneeAngle = avgAngle

  const now = Date.now()

  if (state.phase === 'standing' && avgAngle < thresholds.squatThresholdAngle) {
    state.phase = 'squatting'
    state.isActive = true
  } else if (
    state.phase === 'squatting' &&
    avgAngle > thresholds.standThresholdAngle &&
    now - state.lastRepTime > thresholds.minRepInterval
  ) {
    state.phase = 'standing'
    state.isActive = false
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('squat', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }
}

/** 俯卧撑（手肘角度阈值） */
export function detectPushup(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.pushup
  const requiredIndices = [LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const leftAngle = calculateAngle(landmarks[LEFT_SHOULDER], landmarks[LEFT_ELBOW], landmarks[LEFT_WRIST])
  const rightAngle = calculateAngle(landmarks[RIGHT_SHOULDER], landmarks[RIGHT_ELBOW], landmarks[RIGHT_WRIST])
  const avgAngle = (leftAngle + rightAngle) / 2

  state.elbowAngle = avgAngle

  const now = Date.now()

  if (state.phase === 'up' && avgAngle < thresholds.pushupThresholdAngle) {
    state.phase = 'down'
    state.isActive = true
  } else if (
    state.phase === 'down' &&
    avgAngle > 150 &&
    now - state.lastRepTime > thresholds.minRepInterval
  ) {
    state.phase = 'up'
    state.isActive = false
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('pushup', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }
}

/** 开合跳（髋部Y坐标变化） */
export function detectJumpingJacks(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.jumprope
  const requiredIndices = [LEFT_HIP, RIGHT_HIP]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
  const now = Date.now()

  if (state.lastHipY > 0) {
    const hipDiff = state.lastHipY - hipY

    if (state.phase === 'ground' && hipDiff > 0.05 && now - state.lastRepTime > thresholds.minRepInterval) {
      state.phase = 'air'
      state.isActive = true
    } else if (state.phase === 'air' && hipDiff < -0.03) {
      state.phase = 'ground'
      state.isActive = false
      if (ctx.handleRepSuccess()) {
        state.count += 1
        state.lastRepTime = now
        ctx.setCalories(calculateCalories('jumprope', state.count, ctx.userWeight))
        ctx.onCount(state.count)
      }
    }
  }

  state.lastHipY = hipY
}

/** 高抬腿（膝盖高度比例） */
export function detectHighKnees(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.highknee
  const requiredIndices = [LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
  const leftKneeY = landmarks[LEFT_KNEE].y
  const rightKneeY = landmarks[RIGHT_KNEE].y
  const higherKneeY = Math.min(leftKneeY, rightKneeY)
  const kneeHeightRatio = hipY - higherKneeY

  state.kneeHeight = Math.max(0, kneeHeightRatio)

  const now = Date.now()

  if (state.phase === 'down' && kneeHeightRatio > 0.2 && now - state.lastRepTime > thresholds.minRepInterval) {
    state.phase = 'up'
    state.isActive = true
  } else if (state.phase === 'up' && kneeHeightRatio < 0.05) {
    state.phase = 'down'
    state.isActive = false
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('highknee', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }
}

/** 平板支撑（三点直线+时间） */
export function detectPlank(ctx: DetectionContext): void {
  const { landmarks, states } = ctx
  const state = states.plank
  const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_ANKLE, RIGHT_ANKLE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const shoulderY = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2
  const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
  const ankleY = (landmarks[LEFT_ANKLE].y + landmarks[RIGHT_ANKLE].y) / 2

  const shoulderHipDiff = Math.abs(shoulderY - hipY)
  const hipAnkleDiff = Math.abs(hipY - ankleY)

  const isPlankForm = shoulderHipDiff < 0.08 && hipAnkleDiff > 0.1

  const now = Date.now()

  if (isPlankForm) {
    if (!state.isPlanking) {
      state.isPlanking = true
      state.startTime = now
      state.isActive = true
    } else {
      const currentHold = Math.floor((now - state.startTime) / 1000)
      if (currentHold > state.count) {
        if (ctx.handleRepSuccess()) {
          state.count = currentHold
          state.holdTime = currentHold
          ctx.setCalories(calculateCalories('plank', state.count / 60, ctx.userWeight))
          ctx.onCount(state.count)
        }
      }
    }
  } else {
    if (state.isPlanking) {
      state.isPlanking = false
      state.isActive = false
    }
  }
}

/** 波比跳（四阶段状态机） */
export function detectBurpee(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.burpee
  const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const shoulderY = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2
  const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
  const kneeY = (landmarks[LEFT_KNEE].y + landmarks[RIGHT_KNEE].y) / 2
  const ankleY = (landmarks[LEFT_ANKLE].y + landmarks[RIGHT_ANKLE].y) / 2

  const leftKneeAngle = calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
  const rightKneeAngle = calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])
  const avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2

  const shoulderHipDiff = Math.abs(shoulderY - hipY)
  const hipKneeDiff = Math.abs(hipY - kneeY)

  const isStanding = avgKneeAngle > 160 && hipY < kneeY - 0.05
  const isSquatting = avgKneeAngle < 130 && hipKneeDiff < 0.15
  const isPlankPos = shoulderHipDiff < 0.1 && hipY > ankleY - 0.1

  const now = Date.now()

  if (state.phase === 'stand' && isSquatting) {
    state.phase = 'squat'
    state.isActive = true
  } else if (state.phase === 'squat' && isPlankPos) {
    state.phase = 'plank'
  } else if (state.phase === 'plank' && isSquatting) {
    state.phase = 'jump'
  } else if (state.phase === 'jump' && isStanding && now - state.lastRepTime > thresholds.minRepInterval * 1.5) {
    state.phase = 'stand'
    state.isActive = false
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('burpee', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }

  state.squatDepth = Math.max(0, 180 - avgKneeAngle)
}

/** 弓步蹲（双膝角度差） */
export function detectLunge(ctx: DetectionContext): void {
  const { landmarks, thresholds, states } = ctx
  const state = states.lunge
  const requiredIndices = [LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const leftKneeAngle = calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
  const rightKneeAngle = calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])

  const minKneeAngle = Math.min(leftKneeAngle, rightKneeAngle)
  const maxKneeAngle = Math.max(leftKneeAngle, rightKneeAngle)
  const angleDiff = Math.abs(leftKneeAngle - rightKneeAngle)

  const leftAnkleX = landmarks[LEFT_ANKLE].x
  const rightAnkleX = landmarks[RIGHT_ANKLE].x
  const ankleSpread = Math.abs(leftAnkleX - rightAnkleX)

  const isLungeDown = angleDiff > 30 && minKneeAngle < 120 && ankleSpread > 0.1
  const isStandingUp = maxKneeAngle > 160 && angleDiff < 20

  state.kneeAngle = minKneeAngle

  const now = Date.now()

  if (state.phase === 'up' && isLungeDown) {
    state.phase = 'down'
    state.isActive = true
  } else if (state.phase === 'down' && isStandingUp && now - state.lastRepTime > thresholds.minRepInterval) {
    state.phase = 'up'
    state.isActive = false
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('lunge', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }
}

/** 登山跑（平板+交替前伸） */
export function detectMountainClimber(ctx: DetectionContext): void {
  const { landmarks, states } = ctx
  const state = states.mountainclimber
  const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE]
  if (!checkVisibility(landmarks, requiredIndices)) return

  const shoulderY = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2
  const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
  const shoulderHipDiff = Math.abs(shoulderY - hipY)

  const isPlankPos = shoulderHipDiff < 0.1

  if (!isPlankPos) return

  const leftKneeX = landmarks[LEFT_KNEE].x
  const rightKneeX = landmarks[RIGHT_KNEE].x
  const hipMidX = (landmarks[LEFT_HIP].x + landmarks[RIGHT_HIP].x) / 2

  const leftKneeForward = leftKneeX > hipMidX + 0.03
  const rightKneeForward = rightKneeX < hipMidX - 0.03

  const now = Date.now()

  if (state.phase === 'left' && rightKneeForward && now - state.lastSwitchTime > 200) {
    state.phase = 'right'
    state.lastSwitchTime = now
    state.isActive = true
  } else if (state.phase === 'right' && leftKneeForward && now - state.lastSwitchTime > 200) {
    state.phase = 'left'
    state.lastSwitchTime = now
    state.isActive = true
    if (ctx.handleRepSuccess()) {
      state.count += 1
      state.lastRepTime = now
      ctx.setCalories(calculateCalories('mountainclimber', state.count, ctx.userWeight))
      ctx.onCount(state.count)
    }
  }
}

// ========== 统一调度表 ==========

export const exerciseDetectors: Record<ExerciseType, ExerciseDetector> = {
  squat: { name: 'squat', detect: detectSquat },
  pushup: { name: 'pushup', detect: detectPushup },
  jumprope: { name: 'jumprope', detect: detectJumpingJacks },
  highknee: { name: 'highknee', detect: detectHighKnees },
  plank: { name: 'plank', detect: detectPlank },
  burpee: { name: 'burpee', detect: detectBurpee },
  lunge: { name: 'lunge', detect: detectLunge },
  mountainclimber: { name: 'mountainclimber', detect: detectMountainClimber },
}
