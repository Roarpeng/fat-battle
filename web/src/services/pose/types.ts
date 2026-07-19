import type { ExerciseState } from '../poseTypes'

// ========== 各运动检测内部状态类型 ==========

export interface SquatState extends ExerciseState {
  kneeAngle: number
  phase: 'standing' | 'squatting'
}

export interface PushupState extends ExerciseState {
  elbowAngle: number
  phase: 'up' | 'down'
}

export interface JumpState extends ExerciseState {
  lastHipY: number
  phase: 'ground' | 'air'
}

export interface HighKneeState extends ExerciseState {
  kneeHeight: number
  phase: 'down' | 'up'
}

export interface PlankState extends ExerciseState {
  holdTime: number
  isPlanking: boolean
  startTime: number
}

export interface BurpeeState extends ExerciseState {
  phase: 'stand' | 'squat' | 'plank' | 'pushup' | 'jump'
  squatDepth: number
}

export interface LungeState extends ExerciseState {
  kneeAngle: number
  phase: 'up' | 'down'
}

export interface MountainClimberState extends ExerciseState {
  phase: 'left' | 'right'
  lastSwitchTime: number
}

export interface ExerciseStates {
  squat: SquatState
  pushup: PushupState
  jumprope: JumpState
  highknee: HighKneeState
  plank: PlankState
  burpee: BurpeeState
  lunge: LungeState
  mountainclimber: MountainClimberState
}

// ========== 检测阈值 ==========

export interface DetectionThresholds {
  squatThresholdAngle: number
  standThresholdAngle: number
  pushupThresholdAngle: number
  minRepInterval: number
}

// ========== 初始状态工厂 ==========

export function createInitialExerciseStates(): ExerciseStates {
  return {
    squat: { isActive: false, count: 0, lastRepTime: 0, kneeAngle: 180, phase: 'standing' },
    pushup: { isActive: false, count: 0, lastRepTime: 0, elbowAngle: 180, phase: 'up' },
    jumprope: { isActive: false, count: 0, lastRepTime: 0, lastHipY: 0, phase: 'ground' },
    highknee: { isActive: false, count: 0, lastRepTime: 0, kneeHeight: 0, phase: 'down' },
    plank: { isActive: false, count: 0, lastRepTime: 0, holdTime: 0, isPlanking: false, startTime: 0 },
    burpee: { isActive: false, count: 0, lastRepTime: 0, phase: 'stand', squatDepth: 0 },
    lunge: { isActive: false, count: 0, lastRepTime: 0, kneeAngle: 180, phase: 'up' },
    mountainclimber: { isActive: false, count: 0, lastRepTime: 0, phase: 'left', lastSwitchTime: 0 },
  }
}
