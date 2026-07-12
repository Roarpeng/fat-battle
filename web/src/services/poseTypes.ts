export type PoseStatus = 'idle' | 'loading' | 'ready' | 'running' | 'error'
export type ExerciseType = 'squat' | 'pushup' | 'jumprope' | 'highknee' | 'plank' | 'burpee' | 'lunge' | 'mountainclimber'

export interface PoseLandmark {
  x: number
  y: number
  z: number
  visibility?: number
}

export interface PoseResults {
  landmarks: PoseLandmark[]
  timestamp: number
}

export interface ExerciseState {
  isActive: boolean
  count: number
  lastRepTime: number
}

export type AvatarMode = 'real' | 'cartoon'
export type CartoonColor = 'orange' | 'mint' | 'pink' | 'lavender'

export interface PoseServiceOptions {
  exerciseType?: ExerciseType
  onResults?: (results: PoseResults) => void
  onCount?: (count: number) => void
  onStatusChange?: (status: PoseStatus) => void
  onError?: (error: Error) => void
  onPauseChange?: (paused: boolean) => void
  onPrepareProgress?: (progress: number) => void
  onComboChange?: (combo: number, multiplier: number) => void
  onStaminaChange?: (stamina: number) => void
  onPhotoCapture?: (photoData: string) => void
  videoElement?: HTMLVideoElement
  canvasElement?: HTMLCanvasElement
  squatThresholdAngle?: number
  standThresholdAngle?: number
  pushupThresholdAngle?: number
  minRepInterval?: number
  userWeight?: number
  gender?: 'male' | 'female'
  avatarMode?: AvatarMode
  cartoonColor?: CartoonColor
}

export const MEDIAPIPE_POSE_URL = 'https://cdn.jsdelivr.net/npm/@mediapipe/pose'
export const DEFAULT_SQUAT_THRESHOLD = 110
export const DEFAULT_STAND_THRESHOLD = 160
export const DEFAULT_PUSHUP_THRESHOLD = 100
export const DEFAULT_MIN_REP_INTERVAL = 600

export const NOSE = 0
export const LEFT_SHOULDER = 11
export const RIGHT_SHOULDER = 12
export const LEFT_ELBOW = 13
export const RIGHT_ELBOW = 14
export const LEFT_WRIST = 15
export const RIGHT_WRIST = 16
export const LEFT_HIP = 23
export const RIGHT_HIP = 24
export const LEFT_KNEE = 25
export const RIGHT_KNEE = 26
export const LEFT_ANKLE = 27
export const RIGHT_ANKLE = 28

declare global {
  interface Window {
    Pose?: any
    Camera?: any
  }
}
