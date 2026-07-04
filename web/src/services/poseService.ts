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

export interface PoseServiceOptions {
  exerciseType?: ExerciseType
  onResults?: (results: PoseResults) => void
  onCount?: (count: number) => void
  onStatusChange?: (status: PoseStatus) => void
  onError?: (error: Error) => void
  videoElement?: HTMLVideoElement
  canvasElement?: HTMLCanvasElement
  squatThresholdAngle?: number
  standThresholdAngle?: number
  pushupThresholdAngle?: number
  minRepInterval?: number
  userWeight?: number
}

const MEDIAPIPE_POSE_URL = 'https://cdn.jsdelivr.net/npm/@mediapipe/pose'
const DEFAULT_SQUAT_THRESHOLD = 110
const DEFAULT_STAND_THRESHOLD = 160
const DEFAULT_PUSHUP_THRESHOLD = 100
const DEFAULT_MIN_REP_INTERVAL = 600

const NOSE = 0
const LEFT_SHOULDER = 11
const RIGHT_SHOULDER = 12
const LEFT_ELBOW = 13
const RIGHT_ELBOW = 14
const LEFT_WRIST = 15
const RIGHT_WRIST = 16
const LEFT_HIP = 23
const RIGHT_HIP = 24
const LEFT_KNEE = 25
const RIGHT_KNEE = 26
const LEFT_ANKLE = 27
const RIGHT_ANKLE = 28

declare global {
  interface Window {
    Pose?: any
    Camera?: any
  }
}

export class PoseService {
  private status: PoseStatus = 'idle'
  private exerciseType: ExerciseType = 'squat'
  private pose: any = null
  private camera: any = null
  private videoElement: HTMLVideoElement | null = null
  private canvasElement: HTMLCanvasElement | null = null
  private canvasCtx: CanvasRenderingContext2D | null = null
  private onResultsCallback?: (results: PoseResults) => void
  private onCountCallback?: (count: number) => void
  private onStatusChangeCallback?: (status: PoseStatus) => void
  private onErrorCallback?: (error: Error) => void
  private scriptLoaded = false
  private boundOnResults: (results: any) => void
  private cameraFacing: 'user' | 'environment' = 'user'
  private userWeight: number = 70
  private drawX: number = 0
  private drawY: number = 0
  private drawWidth: number = 0
  private drawHeight: number = 0

  private squatState: ExerciseState & { kneeAngle: number; phase: 'standing' | 'squatting' } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    kneeAngle: 180,
    phase: 'standing',
  }
  private pushupState: ExerciseState & { elbowAngle: number; phase: 'up' | 'down' } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    elbowAngle: 180,
    phase: 'up',
  }
  private jumpState: ExerciseState & { lastHipY: number; phase: 'ground' | 'air' } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    lastHipY: 0,
    phase: 'ground',
  }
  private highKneeState: ExerciseState & { kneeHeight: number; phase: 'down' | 'up' } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    kneeHeight: 0,
    phase: 'down',
  }
  private plankState: ExerciseState & { holdTime: number; isPlanking: boolean; startTime: number } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    holdTime: 0,
    isPlanking: false,
    startTime: 0,
  }
  private burpeeState: ExerciseState & { phase: 'stand' | 'squat' | 'plank' | 'pushup' | 'jump'; squatDepth: number } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    phase: 'stand',
    squatDepth: 0,
  }
  private lungeState: ExerciseState & { kneeAngle: number; phase: 'up' | 'down' } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    kneeAngle: 180,
    phase: 'up',
  }
  private mountainClimberState: ExerciseState & { phase: 'left' | 'right'; lastSwitchTime: number } = {
    isActive: false,
    count: 0,
    lastRepTime: 0,
    phase: 'left',
    lastSwitchTime: 0,
  }

  private squatThresholdAngle: number
  private standThresholdAngle: number
  private pushupThresholdAngle: number
  private minRepInterval: number

  private startTime: number = 0
  private caloriesBurned: number = 0

  constructor(options: PoseServiceOptions = {}) {
    this.exerciseType = options.exerciseType || 'squat'
    this.videoElement = options.videoElement || null
    this.canvasElement = options.canvasElement || null
    if (this.canvasElement) {
      this.canvasCtx = this.canvasElement.getContext('2d')
      if (this.canvasElement.width === 0) {
        this.canvasElement.width = 640
      }
      if (this.canvasElement.height === 0) {
        this.canvasElement.height = 480
      }
    }
    this.onResultsCallback = options.onResults
    this.onCountCallback = options.onCount
    this.onStatusChangeCallback = options.onStatusChange
    this.onErrorCallback = options.onError
    this.squatThresholdAngle = options.squatThresholdAngle ?? DEFAULT_SQUAT_THRESHOLD
    this.standThresholdAngle = options.standThresholdAngle ?? DEFAULT_STAND_THRESHOLD
    this.pushupThresholdAngle = options.pushupThresholdAngle ?? DEFAULT_PUSHUP_THRESHOLD
    this.minRepInterval = options.minRepInterval ?? DEFAULT_MIN_REP_INTERVAL
    this.userWeight = options.userWeight ?? 70
    this.boundOnResults = this.onResults.bind(this)
  }

  getStatus(): PoseStatus {
    return this.status
  }

  getCount(): number {
    switch (this.exerciseType) {
      case 'squat': return this.squatState.count
      case 'pushup': return this.pushupState.count
      case 'jumprope': return this.jumpState.count
      case 'highknee': return this.highKneeState.count
      case 'plank': return this.plankState.count
      case 'burpee': return this.burpeeState.count
      case 'lunge': return this.lungeState.count
      case 'mountainclimber': return this.mountainClimberState.count
      default: return 0
    }
  }

  getExerciseType(): ExerciseType {
    return this.exerciseType
  }

  setExerciseType(type: ExerciseType): void {
    this.exerciseType = type
    this.resetCount()
  }

  setUserWeight(weight: number): void {
    this.userWeight = weight
  }

  getCaloriesBurned(): number {
    return this.caloriesBurned
  }

  getElapsedTime(): number {
    if (this.startTime === 0) return 0
    return Math.floor((Date.now() - this.startTime) / 1000)
  }

  getKneeAngle(): number {
    return this.squatState.kneeAngle
  }

  getElbowAngle(): number {
    return this.pushupState.elbowAngle
  }

  setOnResults(callback: (results: PoseResults) => void): void {
    this.onResultsCallback = callback
  }

  setOnCount(callback: (count: number) => void): void {
    this.onCountCallback = callback
  }

  setOnStatusChange(callback: (status: PoseStatus) => void): void {
    this.onStatusChangeCallback = callback
  }

  setOnError(callback: (error: Error) => void): void {
    this.onErrorCallback = callback
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.videoElement = video
  }

  setCanvasElement(canvas: HTMLCanvasElement): void {
    this.canvasElement = canvas
    this.canvasCtx = canvas.getContext('2d')
    this.resizeCanvas()
  }

  private resizeCanvas(): void {
    if (!this.canvasElement) return
    
    const rect = this.canvasElement.getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1
    
    const newWidth = Math.round(rect.width * dpr)
    const newHeight = Math.round(rect.height * dpr)
    
    if (this.canvasElement.width !== newWidth || this.canvasElement.height !== newHeight) {
      this.canvasElement.width = newWidth
      this.canvasElement.height = newHeight
    }
  }

  setCameraFacing(facing: 'user' | 'environment'): void {
    this.cameraFacing = facing
  }

  resetCount(): void {
    this.squatState = { isActive: false, count: 0, lastRepTime: 0, kneeAngle: 180, phase: 'standing' }
    this.pushupState = { isActive: false, count: 0, lastRepTime: 0, elbowAngle: 180, phase: 'up' }
    this.jumpState = { isActive: false, count: 0, lastRepTime: 0, lastHipY: 0, phase: 'ground' }
    this.highKneeState = { isActive: false, count: 0, lastRepTime: 0, kneeHeight: 0, phase: 'down' }
    this.plankState = { isActive: false, count: 0, lastRepTime: 0, holdTime: 0, isPlanking: false, startTime: 0 }
    this.burpeeState = { isActive: false, count: 0, lastRepTime: 0, phase: 'stand', squatDepth: 0 }
    this.lungeState = { isActive: false, count: 0, lastRepTime: 0, kneeAngle: 180, phase: 'up' }
    this.mountainClimberState = { isActive: false, count: 0, lastRepTime: 0, phase: 'left', lastSwitchTime: 0 }
    this.caloriesBurned = 0
    this.startTime = 0
  }

  private setStatus(status: PoseStatus): void {
    if (this.status !== status) {
      this.status = status
      this.onStatusChangeCallback?.(status)
    }
  }

  private emitError(error: Error): void {
    this.onErrorCallback?.(error)
  }

  private async loadScript(src: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src="${src}"]`)
      if (existing) {
        resolve()
        return
      }
      const script = document.createElement('script')
      script.src = src
      script.crossOrigin = 'anonymous'
      script.onload = () => resolve()
      script.onerror = () => reject(new Error(`脚本加载失败: ${src}`))
      document.head.appendChild(script)
    })
  }

  async load(): Promise<boolean> {
    if (this.status === 'loading' || this.status === 'ready' || this.status === 'running') {
      return this.status === 'ready' || this.status === 'running'
    }

    try {
      this.setStatus('loading')

      if (!this.scriptLoaded) {
        await this.loadScript(`${MEDIAPIPE_POSE_URL}/pose.js`)
        this.scriptLoaded = true
      }

      if (!window.Pose) {
        throw new Error('MediaPipe Pose 加载失败')
      }

      this.pose = new window.Pose({
        locateFile: (file: string) => `${MEDIAPIPE_POSE_URL}/${file}`,
      })

      this.pose.setOptions({
        modelComplexity: 1,
        smoothLandmarks: true,
        enableSegmentation: false,
        smoothSegmentation: false,
        minDetectionConfidence: 0.5,
        minTrackingConfidence: 0.5,
      })

      this.pose.onResults(this.boundOnResults)

      this.setStatus('ready')
      return true
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      this.setStatus('error')
      this.emitError(error)
      return false
    }
  }

  async start(): Promise<boolean> {
    try {
      if (this.status === 'running') return true

      if (this.status === 'idle' || this.status === 'error') {
        const loaded = await this.load()
        if (!loaded) return false
      }

      if (!this.videoElement) {
        throw new Error('未设置 video 元素')
      }

      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('当前浏览器不支持摄像头访问')
      }

      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('摄像头连接超时')), 5000)
      })

      const streamPromise = navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 640 },
          height: { ideal: 480 },
          facingMode: this.cameraFacing,
        },
        audio: false,
      })

      const stream = await Promise.race([streamPromise, timeoutPromise])

      this.videoElement.srcObject = stream
      await this.videoElement.play()

      if (window.Camera) {
        this.camera = new window.Camera(this.videoElement, {
          onFrame: async () => {
            if (this.pose && this.status === 'running') {
              await this.pose.send({ image: this.videoElement })
            }
          },
          width: 640,
          height: 480,
        })
        await this.camera.start()
      } else {
        this.startFrameLoop()
      }

      this.startTime = Date.now()
      this.setStatus('running')
      return true
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      this.stopCamera()
      this.setStatus('error')
      this.emitError(error)
      return false
    }
  }

  private stopCamera(): void {
    try {
      if (this.videoElement?.srcObject) {
        const stream = this.videoElement.srcObject as MediaStream
        stream.getTracks().forEach((track) => track.stop())
        this.videoElement.srcObject = null
      }
    } catch (_) {
    }
  }

  private startFrameLoop(): void {
    const loop = async () => {
      if (this.status !== 'running') return
      if (this.pose && this.videoElement && this.videoElement.readyState >= 2) {
        try {
          await this.pose.send({ image: this.videoElement })
        } catch (_) {
          // ignore
        }
      }
      requestAnimationFrame(loop)
    }
    requestAnimationFrame(loop)
  }

  async stop(): Promise<void> {
    try {
      if (this.camera) {
        this.camera.stop?.()
        this.camera = null
      }

      this.stopCamera()
      this.setStatus('ready')
    } catch (err) {
      const error = err instanceof Error ? err : new Error(String(err))
      this.emitError(error)
    }
  }

  async restart(): Promise<boolean> {
    await this.stop()
    this.resetCount()
    return this.start()
  }

  private calculateAngle(
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

  private checkVisibility(landmarks: PoseLandmark[], indices: number[], threshold: number = 0.5): boolean {
    return indices.every(i => {
      const lm = landmarks[i]
      return lm && (lm.visibility ?? 0) >= threshold
    })
  }

  private detectSquat(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_HIP, LEFT_KNEE, LEFT_ANKLE, RIGHT_HIP, RIGHT_KNEE, RIGHT_ANKLE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const leftAngle = this.calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
    const rightAngle = this.calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])
    const avgAngle = (leftAngle + rightAngle) / 2

    this.squatState.kneeAngle = avgAngle

    const now = Date.now()

    if (this.squatState.phase === 'standing' && avgAngle < this.squatThresholdAngle) {
      this.squatState.phase = 'squatting'
      this.squatState.isActive = true
    } else if (
      this.squatState.phase === 'squatting' &&
      avgAngle > this.standThresholdAngle &&
      now - this.squatState.lastRepTime > this.minRepInterval
    ) {
      this.squatState.phase = 'standing'
      this.squatState.isActive = false
      this.squatState.count += 1
      this.squatState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('squat', this.squatState.count)
      this.onCountCallback?.(this.squatState.count)
    }
  }

  private detectPushup(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST, RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const leftAngle = this.calculateAngle(landmarks[LEFT_SHOULDER], landmarks[LEFT_ELBOW], landmarks[LEFT_WRIST])
    const rightAngle = this.calculateAngle(landmarks[RIGHT_SHOULDER], landmarks[RIGHT_ELBOW], landmarks[RIGHT_WRIST])
    const avgAngle = (leftAngle + rightAngle) / 2

    this.pushupState.elbowAngle = avgAngle

    const now = Date.now()

    if (this.pushupState.phase === 'up' && avgAngle < this.pushupThresholdAngle) {
      this.pushupState.phase = 'down'
      this.pushupState.isActive = true
    } else if (
      this.pushupState.phase === 'down' &&
      avgAngle > 150 &&
      now - this.pushupState.lastRepTime > this.minRepInterval
    ) {
      this.pushupState.phase = 'up'
      this.pushupState.isActive = false
      this.pushupState.count += 1
      this.pushupState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('pushup', this.pushupState.count)
      this.onCountCallback?.(this.pushupState.count)
    }
  }

  private detectJumpRope(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_HIP, RIGHT_HIP]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
    const now = Date.now()

    if (this.jumpState.lastHipY > 0) {
      const hipDiff = this.jumpState.lastHipY - hipY

      if (this.jumpState.phase === 'ground' && hipDiff > 0.05 && now - this.jumpState.lastRepTime > this.minRepInterval) {
        this.jumpState.phase = 'air'
        this.jumpState.isActive = true
      } else if (this.jumpState.phase === 'air' && hipDiff < -0.03) {
        this.jumpState.phase = 'ground'
        this.jumpState.isActive = false
        this.jumpState.count += 1
        this.jumpState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('jumprope', this.jumpState.count)
        this.onCountCallback?.(this.jumpState.count)
      }
    }

    this.jumpState.lastHipY = hipY
  }

  private detectHighKnee(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
    const leftKneeY = landmarks[LEFT_KNEE].y
    const rightKneeY = landmarks[RIGHT_KNEE].y
    const higherKneeY = Math.min(leftKneeY, rightKneeY)
    const kneeHeightRatio = hipY - higherKneeY

    this.highKneeState.kneeHeight = Math.max(0, kneeHeightRatio)

    const now = Date.now()

    if (this.highKneeState.phase === 'down' && kneeHeightRatio > 0.2 && now - this.highKneeState.lastRepTime > this.minRepInterval) {
      this.highKneeState.phase = 'up'
      this.highKneeState.isActive = true
    } else if (this.highKneeState.phase === 'up' && kneeHeightRatio < 0.05) {
      this.highKneeState.phase = 'down'
      this.highKneeState.isActive = false
      this.highKneeState.count += 1
      this.highKneeState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('highknee', this.highKneeState.count)
      this.onCountCallback?.(this.highKneeState.count)
    }
  }

  private detectPlank(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_ANKLE, RIGHT_ANKLE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const shoulderY = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2
    const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
    const ankleY = (landmarks[LEFT_ANKLE].y + landmarks[RIGHT_ANKLE].y) / 2

    const shoulderHipDiff = Math.abs(shoulderY - hipY)
    const hipAnkleDiff = Math.abs(hipY - ankleY)

    const isPlankForm = shoulderHipDiff < 0.08 && hipAnkleDiff > 0.1

    const now = Date.now()

    if (isPlankForm) {
      if (!this.plankState.isPlanking) {
        this.plankState.isPlanking = true
        this.plankState.startTime = now
        this.plankState.isActive = true
      } else {
        const currentHold = Math.floor((now - this.plankState.startTime) / 1000)
        if (currentHold > this.plankState.count) {
          this.plankState.count = currentHold
          this.plankState.holdTime = currentHold
          this.caloriesBurned = this.calculateCalories('plank', this.plankState.count / 60)
          this.onCountCallback?.(this.plankState.count)
        }
      }
    } else {
      if (this.plankState.isPlanking) {
        this.plankState.isPlanking = false
        this.plankState.isActive = false
      }
    }
  }

  private detectBurpee(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const shoulderY = (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2
    const hipY = (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2
    const kneeY = (landmarks[LEFT_KNEE].y + landmarks[RIGHT_KNEE].y) / 2
    const ankleY = (landmarks[LEFT_ANKLE].y + landmarks[RIGHT_ANKLE].y) / 2

    const leftKneeAngle = this.calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
    const rightKneeAngle = this.calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])
    const avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2

    const shoulderHipDiff = Math.abs(shoulderY - hipY)
    const hipKneeDiff = Math.abs(hipY - kneeY)

    const isStanding = avgKneeAngle > 160 && hipY < kneeY - 0.05
    const isSquatting = avgKneeAngle < 130 && hipKneeDiff < 0.15
    const isPlankPos = shoulderHipDiff < 0.1 && hipY > ankleY - 0.1

    const now = Date.now()

    if (this.burpeeState.phase === 'stand' && isSquatting) {
      this.burpeeState.phase = 'squat'
      this.burpeeState.isActive = true
    } else if (this.burpeeState.phase === 'squat' && isPlankPos) {
      this.burpeeState.phase = 'plank'
    } else if (this.burpeeState.phase === 'plank' && isSquatting) {
      this.burpeeState.phase = 'jump'
    } else if (this.burpeeState.phase === 'jump' && isStanding && now - this.burpeeState.lastRepTime > this.minRepInterval * 1.5) {
      this.burpeeState.phase = 'stand'
      this.burpeeState.isActive = false
      this.burpeeState.count += 1
      this.burpeeState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('burpee', this.burpeeState.count)
      this.onCountCallback?.(this.burpeeState.count)
    }

    this.burpeeState.squatDepth = Math.max(0, 180 - avgKneeAngle)
  }

  private detectLunge(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

    const leftKneeAngle = this.calculateAngle(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE])
    const rightKneeAngle = this.calculateAngle(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE])

    const minKneeAngle = Math.min(leftKneeAngle, rightKneeAngle)
    const maxKneeAngle = Math.max(leftKneeAngle, rightKneeAngle)
    const angleDiff = Math.abs(leftKneeAngle - rightKneeAngle)

    const leftAnkleX = landmarks[LEFT_ANKLE].x
    const rightAnkleX = landmarks[RIGHT_ANKLE].x
    const ankleSpread = Math.abs(leftAnkleX - rightAnkleX)

    const isLungeDown = angleDiff > 30 && minKneeAngle < 120 && ankleSpread > 0.1
    const isStandingUp = maxKneeAngle > 160 && angleDiff < 20

    this.lungeState.kneeAngle = minKneeAngle

    const now = Date.now()

    if (this.lungeState.phase === 'up' && isLungeDown) {
      this.lungeState.phase = 'down'
      this.lungeState.isActive = true
    } else if (this.lungeState.phase === 'down' && isStandingUp && now - this.lungeState.lastRepTime > this.minRepInterval) {
      this.lungeState.phase = 'up'
      this.lungeState.isActive = false
      this.lungeState.count += 1
      this.lungeState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('lunge', this.lungeState.count)
      this.onCountCallback?.(this.lungeState.count)
    }
  }

  private detectMountainClimber(landmarks: PoseLandmark[]): void {
    const requiredIndices = [LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE]
    if (!this.checkVisibility(landmarks, requiredIndices)) return

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

    if (this.mountainClimberState.phase === 'left' && rightKneeForward && now - this.mountainClimberState.lastSwitchTime > 200) {
      this.mountainClimberState.phase = 'right'
      this.mountainClimberState.lastSwitchTime = now
      this.mountainClimberState.isActive = true
    } else if (this.mountainClimberState.phase === 'right' && leftKneeForward && now - this.mountainClimberState.lastSwitchTime > 200) {
      this.mountainClimberState.phase = 'left'
      this.mountainClimberState.lastSwitchTime = now
      this.mountainClimberState.isActive = true
      this.mountainClimberState.count += 1
      this.mountainClimberState.lastRepTime = now
      this.caloriesBurned = this.calculateCalories('mountainclimber', this.mountainClimberState.count)
      this.onCountCallback?.(this.mountainClimberState.count)
    }
  }

  private calculateCalories(exercise: ExerciseType, count: number): number {
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
    const calories = (met * this.userWeight * minutes) / 200

    return Math.round(calories * 10) / 10
  }

  private onResults(results: any): void {
    this.drawBackground(results)

    if (!results.poseLandmarks) {
      return
    }

    const landmarks: PoseLandmark[] = results.poseLandmarks.map((lm: any) => ({
      x: lm.x,
      y: lm.y,
      z: lm.z,
      visibility: lm.visibility,
    }))

    const poseResults: PoseResults = {
      landmarks,
      timestamp: Date.now(),
    }

    switch (this.exerciseType) {
      case 'squat':
        this.detectSquat(landmarks)
        break
      case 'pushup':
        this.detectPushup(landmarks)
        break
      case 'jumprope':
        this.detectJumpRope(landmarks)
        break
      case 'highknee':
        this.detectHighKnee(landmarks)
        break
      case 'plank':
        this.detectPlank(landmarks)
        break
      case 'burpee':
        this.detectBurpee(landmarks)
        break
      case 'lunge':
        this.detectLunge(landmarks)
        break
      case 'mountainclimber':
        this.detectMountainClimber(landmarks)
        break
    }

    this.drawLandmarks(results)
    this.onResultsCallback?.(poseResults)
  }

  private drawBackground(results: any): void {
    if (!this.canvasElement || !this.canvasCtx || !results.image) {
      return
    }

    const ctx = this.canvasCtx
    const canvasWidth = this.canvasElement.width
    const canvasHeight = this.canvasElement.height
    const dpr = window.devicePixelRatio || 1

    ctx.save()
    ctx.clearRect(0, 0, canvasWidth, canvasHeight)

    if (this.cameraFacing === 'user') {
      ctx.translate(canvasWidth, 0)
      ctx.scale(-1, 1)
    }

    const image = results.image
    const imageWidth = image.width || image.videoWidth || 640
    const imageHeight = image.height || image.videoHeight || 480
    const imageRatio = imageWidth / imageHeight
    const canvasRatio = canvasWidth / canvasHeight

    let drawWidth: number
    let drawHeight: number
    let drawX: number
    let drawY: number

    if (imageRatio > canvasRatio) {
      drawWidth = canvasWidth
      drawHeight = canvasWidth / imageRatio
      drawX = 0
      drawY = (canvasHeight - drawHeight) / 2
    } else {
      drawHeight = canvasHeight
      drawWidth = canvasHeight * imageRatio
      drawX = (canvasWidth - drawWidth) / 2
      drawY = 0
    }

    ctx.drawImage(image, drawX, drawY, drawWidth, drawHeight)

    this.drawX = drawX
    this.drawY = drawY
    this.drawWidth = drawWidth
    this.drawHeight = drawHeight

    if (!results.poseLandmarks) {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)'
      ctx.fillRect(drawX, drawY, drawWidth, drawHeight)
      ctx.fillStyle = '#ffffff'
      ctx.font = `bold ${20 * dpr}px Arial`
      ctx.textAlign = 'center'
      ctx.fillText('请将身体对准摄像头', canvasWidth / 2, canvasHeight / 2 - 10 * dpr)
      ctx.font = `${14 * dpr}px Arial`
      ctx.fillStyle = 'rgba(255, 255, 255, 0.7)'
      ctx.fillText('确保全身出现在画面中', canvasWidth / 2, canvasHeight / 2 + 20 * dpr)
      ctx.textAlign = 'left'
    }

    ctx.restore()
  }

  private drawLandmarks(results: any): void {
    if (!this.canvasElement || !this.canvasCtx || !results.poseLandmarks) {
      return
    }

    const ctx = this.canvasCtx
    const width = this.canvasElement.width
    const height = this.canvasElement.height
    const landmarks = results.poseLandmarks
    const dpr = window.devicePixelRatio || 1

    ctx.save()

    if (this.cameraFacing === 'user') {
      ctx.translate(width, 0)
      ctx.scale(-1, 1)
    }

    const shoulderMid = {
      x: (landmarks[LEFT_SHOULDER].x + landmarks[RIGHT_SHOULDER].x) / 2,
      y: (landmarks[LEFT_SHOULDER].y + landmarks[RIGHT_SHOULDER].y) / 2,
      visibility: Math.min(landmarks[LEFT_SHOULDER].visibility, landmarks[RIGHT_SHOULDER].visibility),
    }
    const hipMid = {
      x: (landmarks[LEFT_HIP].x + landmarks[RIGHT_HIP].x) / 2,
      y: (landmarks[LEFT_HIP].y + landmarks[RIGHT_HIP].y) / 2,
      visibility: Math.min(landmarks[LEFT_HIP].visibility, landmarks[RIGHT_HIP].visibility),
    }

    const boneColor = '#4ADE80'
    const jointColor = '#FFD700'
    const angleJointColor = '#FF6B6B'
    const spineColor = '#A78BFA'

    const mapX = (x: number) => this.drawX + x * this.drawWidth
    const mapY = (y: number) => this.drawY + y * this.drawHeight

    const drawLine = (p1: any, p2: any, color: string, w: number) => {
      if (!p1 || !p2 || p1.visibility < 0.5 || p2.visibility < 0.5) return
      ctx.shadowColor = color
      ctx.shadowBlur = 8 * dpr
      ctx.strokeStyle = color
      ctx.lineWidth = w * dpr
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.moveTo(mapX(p1.x), mapY(p1.y))
      ctx.lineTo(mapX(p2.x), mapY(p2.y))
      ctx.stroke()
      ctx.shadowBlur = 0
    }

    const drawPoint = (p: any, color: string, r: number) => {
      if (!p || p.visibility < 0.5) return
      ctx.shadowColor = color
      ctx.shadowBlur = 12 * dpr
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.arc(mapX(p.x), mapY(p.y), r * dpr, 0, 2 * Math.PI)
      ctx.fill()
      ctx.shadowBlur = 0
      ctx.fillStyle = '#ffffff'
      ctx.beginPath()
      ctx.arc(mapX(p.x), mapY(p.y), r * 0.35 * dpr, 0, 2 * Math.PI)
      ctx.fill()
    }

    drawLine(shoulderMid, hipMid, spineColor, 4)
    drawLine(landmarks[LEFT_SHOULDER], landmarks[RIGHT_SHOULDER], spineColor, 3)
    drawLine(landmarks[LEFT_HIP], landmarks[RIGHT_HIP], spineColor, 3)

    drawLine(landmarks[LEFT_SHOULDER], landmarks[LEFT_ELBOW], boneColor, 4)
    drawLine(landmarks[LEFT_ELBOW], landmarks[LEFT_WRIST], boneColor, 4)
    drawLine(landmarks[RIGHT_SHOULDER], landmarks[RIGHT_ELBOW], boneColor, 4)
    drawLine(landmarks[RIGHT_ELBOW], landmarks[RIGHT_WRIST], boneColor, 4)

    drawLine(landmarks[LEFT_HIP], landmarks[LEFT_KNEE], boneColor, 5)
    drawLine(landmarks[LEFT_KNEE], landmarks[LEFT_ANKLE], boneColor, 5)
    drawLine(landmarks[RIGHT_HIP], landmarks[RIGHT_KNEE], boneColor, 5)
    drawLine(landmarks[RIGHT_KNEE], landmarks[RIGHT_ANKLE], boneColor, 5)

    drawPoint(landmarks[NOSE], jointColor, 8)
    drawPoint(shoulderMid, spineColor, 5)
    drawPoint(hipMid, spineColor, 5)

    drawPoint(landmarks[LEFT_SHOULDER], jointColor, 6)
    drawPoint(landmarks[RIGHT_SHOULDER], jointColor, 6)
    drawPoint(landmarks[LEFT_HIP], jointColor, 6)
    drawPoint(landmarks[RIGHT_HIP], jointColor, 6)

    drawPoint(landmarks[LEFT_ELBOW], angleJointColor, 7)
    drawPoint(landmarks[RIGHT_ELBOW], angleJointColor, 7)
    drawPoint(landmarks[LEFT_WRIST], jointColor, 5)
    drawPoint(landmarks[RIGHT_WRIST], jointColor, 5)

    drawPoint(landmarks[LEFT_KNEE], angleJointColor, 8)
    drawPoint(landmarks[RIGHT_KNEE], angleJointColor, 8)
    drawPoint(landmarks[LEFT_ANKLE], jointColor, 6)
    drawPoint(landmarks[RIGHT_ANKLE], jointColor, 6)

    ctx.restore()

    ctx.save()
    const padding = 10 * dpr
    const boxWidth = 135 * dpr
    const boxHeight = 50 * dpr
    const boxX = width - boxWidth - padding
    const boxY = padding

    ctx.fillStyle = 'rgba(0, 0, 0, 0.5)'
    ctx.beginPath()
    ctx.roundRect(boxX, boxY, boxWidth, boxHeight, 8 * dpr)
    ctx.fill()
    ctx.fillStyle = '#ffffff'
    ctx.font = `bold ${10 * dpr}px Arial`

    const exerciseNames: Record<ExerciseType, string> = {
      squat: '深蹲',
      pushup: '俯卧撑',
      jumprope: '开合',
      highknee: '高抬腿',
      plank: '平板',
      burpee: '波比',
      lunge: '弓步',
      mountainclimber: '登山',
    }

    const countLabel = this.exerciseType === 'plank' ? 's' : ''
    ctx.fillStyle = '#66FF66'
    ctx.fillText(`${exerciseNames[this.exerciseType]} ${this.getCount()}${countLabel}`, boxX + 8 * dpr, boxY + 16 * dpr)

    if (this.exerciseType === 'squat') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${Math.round(this.squatState.kneeAngle)}°`, boxX + 8 * dpr, boxY + 32 * dpr)
    } else if (this.exerciseType === 'pushup') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${Math.round(this.pushupState.elbowAngle)}°`, boxX + 8 * dpr, boxY + 32 * dpr)
    } else if (this.exerciseType === 'highknee') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${Math.round(this.highKneeState.kneeHeight * 100)}%`, boxX + 8 * dpr, boxY + 32 * dpr)
    } else if (this.exerciseType === 'plank') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${this.plankState.count}s`, boxX + 8 * dpr, boxY + 32 * dpr)
    } else if (this.exerciseType === 'lunge') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${Math.round(this.lungeState.kneeAngle)}°`, boxX + 8 * dpr, boxY + 32 * dpr)
    } else if (this.exerciseType === 'burpee') {
      ctx.fillStyle = '#FFD700'
      ctx.fillText(`${Math.round(this.burpeeState.squatDepth)}°`, boxX + 8 * dpr, boxY + 32 * dpr)
    }

    ctx.restore()
  }

  async destroy(): Promise<void> {
    await this.stop()
    if (this.pose) {
      this.pose.close?.()
      this.pose = null
    }
    this.onResultsCallback = undefined
    this.onCountCallback = undefined
    this.onStatusChangeCallback = undefined
    this.onErrorCallback = undefined
    this.setStatus('idle')
  }
}

export const createPoseService = (options?: PoseServiceOptions): PoseService => {
  return new PoseService(options)
}
