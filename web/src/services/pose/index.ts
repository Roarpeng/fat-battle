// ========== pose 模块统一导出 ==========

// 共享类型与状态工厂
export type {
  SquatState,
  PushupState,
  JumpState,
  HighKneeState,
  PlankState,
  BurpeeState,
  LungeState,
  MountainClimberState,
  ExerciseStates,
  DetectionThresholds,
} from './types'
export { createInitialExerciseStates } from './types'

// 检测算法层
export {
  exerciseDetectors,
  detectSquat,
  detectPushup,
  detectJumpingJacks,
  detectHighKnees,
  detectPlank,
  detectBurpee,
  detectLunge,
  detectMountainClimber,
  calculateAngle,
  checkVisibility,
  calculateCalories,
} from './exerciseDetectors'
export type { DetectionContext, ExerciseDetector } from './exerciseDetectors'

// 渲染层
export { PoseRenderer } from './renderer'

// 游戏逻辑层
export { ExerciseGameLogic } from './gameLogic'
