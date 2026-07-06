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
export type CartoonColor = 'blue' | 'pink'

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
  private resizeObserver: ResizeObserver | null = null
  private onResultsCallback?: (results: PoseResults) => void
  private onCountCallback?: (count: number) => void
  private onStatusChangeCallback?: (status: PoseStatus) => void
  private onErrorCallback?: (error: Error) => void
  private scriptLoaded = false
  private boundOnResults: (results: any) => void
  private cameraFacing: 'user' | 'environment' = 'user'
  private userWeight: number = 70
  private gender: 'male' | 'female' = 'male'
  private avatarMode: AvatarMode = 'cartoon'
  private cartoonColor: CartoonColor = 'blue'
  private onPhotoCaptureCallback?: (photoData: string) => void
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

  // ========== 人体离开检测 & 暂停系统 ==========
  private isPaused: boolean = false
  private personLostFrames: number = 0
  private readonly PERSON_LOST_THRESHOLD: number = 15 // 约 0.5s (30fps)
  private personReturnedFrames: number = 0
  private readonly PERSON_RETURN_THRESHOLD: number = 5 // 约 0.15s
  private onPauseChangeCallback?: (paused: boolean) => void
  private pausedTime: number = 0
  private totalPausedDuration: number = 0

  // ========== 准备姿势检测 ==========
  private isPreparing: boolean = false
  private prepareStartTime: number = 0
  private readonly PREPARE_REQUIRED_MS: number = 2000 // 2秒准备时间
  private prepareProgress: number = 0
  private onPrepareProgressCallback?: (progress: number) => void

  // ========== 连击机制 ==========
  private comboCount: number = 0
  private lastRepQuality: 'perfect' | 'good' | 'normal' = 'normal'
  private lastRepTime: number = 0
  private readonly COMBO_WINDOW_MS: number = 3000 // 3秒内连续动作算连击
  private comboMultiplier: number = 1.0
  private onComboChangeCallback?: (combo: number, multiplier: number) => void

  // ========== 体力值系统 ==========
  private stamina: number = 100
  private readonly MAX_STAMINA: number = 100
  private readonly STAMINA_COST_PER_REP: number = 8
  private readonly STAMINA_RECOVERY_RATE: number = 0.8 // 每帧恢复
  private onStaminaChangeCallback?: (stamina: number) => void

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
    this.onPauseChangeCallback = options.onPauseChange
    this.onPrepareProgressCallback = options.onPrepareProgress
    this.onComboChangeCallback = options.onComboChange
    this.onStaminaChangeCallback = options.onStaminaChange
    this.squatThresholdAngle = options.squatThresholdAngle ?? DEFAULT_SQUAT_THRESHOLD
    this.standThresholdAngle = options.standThresholdAngle ?? DEFAULT_STAND_THRESHOLD
    this.pushupThresholdAngle = options.pushupThresholdAngle ?? DEFAULT_PUSHUP_THRESHOLD
    this.minRepInterval = options.minRepInterval ?? DEFAULT_MIN_REP_INTERVAL
    this.userWeight = options.userWeight ?? 70
    this.gender = options.gender ?? 'male'
    this.avatarMode = options.avatarMode ?? 'cartoon'
    this.cartoonColor = options.cartoonColor ?? 'blue'
    this.onPhotoCaptureCallback = options.onPhotoCapture
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

  setGender(gender: 'male' | 'female'): void {
    this.gender = gender
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

  // ========== 游戏化系统 getter/setter ==========
  isGamePaused(): boolean { return this.isPaused }
  getComboCount(): number { return this.comboCount }
  getComboMultiplier(): number { return this.comboMultiplier }
  getStamina(): number { return Math.round(this.stamina) }
  isInPreparing(): boolean { return this.isPreparing }
  getPrepareProgress(): number { return this.prepareProgress }

  setOnPauseChange(callback: (paused: boolean) => void): void {
    this.onPauseChangeCallback = callback
  }
  setOnPrepareProgress(callback: (progress: number) => void): void {
    this.onPrepareProgressCallback = callback
  }
  setOnComboChange(callback: (combo: number, multiplier: number) => void): void {
    this.onComboChangeCallback = callback
  }
  setOnStaminaChange(callback: (stamina: number) => void): void {
    this.onStaminaChangeCallback = callback
  }

  setOnPhotoCapture(callback: (photoData: string) => void): void {
    this.onPhotoCaptureCallback = callback
  }

  setAvatarMode(mode: AvatarMode): void {
    this.avatarMode = mode
  }

  getAvatarMode(): AvatarMode {
    return this.avatarMode
  }

  setCartoonColor(color: CartoonColor): void {
    this.cartoonColor = color
  }

  getCartoonColor(): CartoonColor {
    return this.cartoonColor
  }

  capturePhoto(): string | null {
    if (!this.canvasElement) return null
    return this.canvasElement.toDataURL('image/png')
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.videoElement = video
  }

  setCanvasElement(canvas: HTMLCanvasElement): void {
    // 清理旧的 ResizeObserver
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }

    this.canvasElement = canvas
    this.canvasCtx = canvas.getContext('2d')
    this.resizeCanvas()

    // 监听 canvas 容器尺寸变化，自动调整内部分辨率
    if (typeof ResizeObserver !== 'undefined') {
      this.resizeObserver = new ResizeObserver(() => {
        this.resizeCanvas()
      })
      this.resizeObserver.observe(canvas)
    }
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
            if (this.pose && (this.status === 'running' || this.isPreparing)) {
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

      // 进入准备姿势检测阶段（站好2秒后才正式计时）
      this.isPreparing = true
      this.prepareStartTime = Date.now()
      this.prepareProgress = 0
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
      if (this.status !== 'running' && !this.isPreparing) return
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

  // ========== 通用计数成功处理（连击 + 体力值）==========
  private handleRepSuccess(): boolean {
    // 体力值检查
    if (this.stamina < this.STAMINA_COST_PER_REP) {
      // 体力不足，不计数
      return false
    }

    // 消耗体力
    this.stamina -= this.STAMINA_COST_PER_REP
    this.onStaminaChangeCallback?.(Math.round(this.stamina))

    // 连击逻辑
    const now = Date.now()
    if (now - this.lastRepTime <= this.COMBO_WINDOW_MS) {
      this.comboCount++
    } else {
      this.comboCount = 1
    }
    this.lastRepTime = now

    // 连击倍率：每5连击 +0.2，上限2.0
    this.comboMultiplier = Math.min(2.0, 1.0 + Math.floor(this.comboCount / 5) * 0.2)
    this.onComboChangeCallback?.(this.comboCount, this.comboMultiplier)

    return true
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
      if (this.handleRepSuccess()) {
        this.squatState.count += 1
        this.squatState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('squat', this.squatState.count)
        this.onCountCallback?.(this.squatState.count)
      }
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
      if (this.handleRepSuccess()) {
        this.pushupState.count += 1
        this.pushupState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('pushup', this.pushupState.count)
        this.onCountCallback?.(this.pushupState.count)
      }
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
        if (this.handleRepSuccess()) {
          this.jumpState.count += 1
          this.jumpState.lastRepTime = now
          this.caloriesBurned = this.calculateCalories('jumprope', this.jumpState.count)
          this.onCountCallback?.(this.jumpState.count)
        }
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
      if (this.handleRepSuccess()) {
        this.highKneeState.count += 1
        this.highKneeState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('highknee', this.highKneeState.count)
        this.onCountCallback?.(this.highKneeState.count)
      }
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
          if (this.handleRepSuccess()) {
            this.plankState.count = currentHold
            this.plankState.holdTime = currentHold
            this.caloriesBurned = this.calculateCalories('plank', this.plankState.count / 60)
            this.onCountCallback?.(this.plankState.count)
          }
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
      if (this.handleRepSuccess()) {
        this.burpeeState.count += 1
        this.burpeeState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('burpee', this.burpeeState.count)
        this.onCountCallback?.(this.burpeeState.count)
      }
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
      if (this.handleRepSuccess()) {
        this.lungeState.count += 1
        this.lungeState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('lunge', this.lungeState.count)
        this.onCountCallback?.(this.lungeState.count)
      }
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
      if (this.handleRepSuccess()) {
        this.mountainClimberState.count += 1
        this.mountainClimberState.lastRepTime = now
        this.caloriesBurned = this.calculateCalories('mountainclimber', this.mountainClimberState.count)
        this.onCountCallback?.(this.mountainClimberState.count)
      }
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

    const hasPerson = !!results.poseLandmarks && results.poseLandmarks.length > 0

    // ========== 人体离开检测 & 暂停系统 ==========
    if (!hasPerson) {
      this.personLostFrames++
      this.personReturnedFrames = Math.max(0, this.personReturnedFrames - 1)
    } else {
      this.personReturnedFrames++
      this.personLostFrames = Math.max(0, this.personLostFrames - 1)
    }

    // 人体离开超过阈值 → 触发暂停
    if (!this.isPaused && this.personLostFrames >= this.PERSON_LOST_THRESHOLD) {
      this.isPaused = true
      this.pausedTime = Date.now()
      this.onPauseChangeCallback?.(true)
    }

    // 人体返回超过阈值 → 自动恢复
    if (this.isPaused && this.personReturnedFrames >= this.PERSON_RETURN_THRESHOLD) {
      this.isPaused = false
      this.totalPausedDuration += Date.now() - this.pausedTime
      this.pausedTime = 0
      this.onPauseChangeCallback?.(false)
    }

    // 暂停中：绘制暂停提示，停止一切检测
    if (this.isPaused) {
      this.drawPauseOverlay()
      return
    }

    // 准备姿势检测阶段
    if (this.isPreparing) {
      if (hasPerson) {
        const elapsed = Date.now() - this.prepareStartTime
        this.prepareProgress = Math.min(1, elapsed / this.PREPARE_REQUIRED_MS)
        this.onPrepareProgressCallback?.(this.prepareProgress)
        if (elapsed >= this.PREPARE_REQUIRED_MS) {
          this.isPreparing = false
          this.prepareProgress = 1
          this.startTime = Date.now()
          this.onPrepareProgressCallback?.(1)
        }
      } else {
        // 准备中人体离开，重置
        this.prepareStartTime = Date.now()
        this.prepareProgress = 0
        this.onPrepareProgressCallback?.(0)
      }
      this.drawCharacter(results)
      return
    }

    if (!hasPerson) {
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

    // ========== 体力值恢复（每帧） ==========
    if (this.stamina < this.MAX_STAMINA) {
      this.stamina = Math.min(this.MAX_STAMINA, this.stamina + this.STAMINA_RECOVERY_RATE)
      this.onStaminaChangeCallback?.(Math.round(this.stamina))
    }

    // ========== 连击过期检查 ==========
    if (this.comboCount > 0 && Date.now() - this.lastRepTime > this.COMBO_WINDOW_MS) {
      this.comboCount = 0
      this.comboMultiplier = 1.0
      this.onComboChangeCallback?.(0, 1.0)
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

    this.drawCharacter(results)
    this.onResultsCallback?.(poseResults)
  }

  private drawBackground(results: any): void {
    if (!this.canvasElement || !this.canvasCtx) {
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

    if (this.avatarMode === 'real' && this.videoElement && this.videoElement.readyState >= 2) {
      ctx.drawImage(this.videoElement, 0, 0, canvasWidth, canvasHeight)
    } else {
      const gradient = ctx.createLinearGradient(0, 0, 0, canvasHeight)
      gradient.addColorStop(0, '#1a1a2e')
      gradient.addColorStop(0.5, '#16213e')
      gradient.addColorStop(1, '#0f3460')
      ctx.fillStyle = gradient
      ctx.fillRect(0, 0, canvasWidth, canvasHeight)

      ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)'
      ctx.lineWidth = 1
      const gridSpacing = 40 * dpr
      for (let y = canvasHeight * 0.65; y < canvasHeight; y += gridSpacing) {
        ctx.beginPath()
        ctx.moveTo(0, y)
        ctx.lineTo(canvasWidth, y)
        ctx.stroke()
      }
      for (let x = 0; x < canvasWidth; x += gridSpacing) {
        ctx.beginPath()
        ctx.moveTo(x, canvasHeight * 0.65)
        ctx.lineTo(x, canvasHeight)
        ctx.stroke()
      }
    }

    this.drawX = 0
    this.drawY = 0
    this.drawWidth = canvasWidth
    this.drawHeight = canvasHeight

    if (!results.poseLandmarks) {
      ctx.fillStyle = 'rgba(0, 0, 0, 0.5)'
      ctx.fillRect(0, 0, canvasWidth, canvasHeight)
      ctx.fillStyle = '#ffffff'
      ctx.font = `bold ${14 * dpr}px Arial`
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText('请将身体对准摄像头', Math.round(canvasWidth / 2), Math.round(canvasHeight / 2 - 8 * dpr))
      ctx.font = `${11 * dpr}px Arial`
      ctx.fillStyle = 'rgba(255, 255, 255, 0.7)'
      ctx.fillText('确保全身出现在画面中', Math.round(canvasWidth / 2), Math.round(canvasHeight / 2 + 14 * dpr))
      ctx.textAlign = 'left'
      ctx.textBaseline = 'alphabetic'
    }

    ctx.restore()
  }

  private drawCharacter(results: any): void {
    if (!this.canvasElement || !this.canvasCtx || !results.poseLandmarks) {
      return
    }

    const ctx = this.canvasCtx
    const canvasWidth = this.canvasElement.width
    const landmarks = results.poseLandmarks
    const dpr = window.devicePixelRatio || 1

    ctx.save()

    if (this.cameraFacing === 'user') {
      ctx.translate(canvasWidth, 0)
      ctx.scale(-1, 1)
    }

    const mapX = (x: number) => this.drawX + x * this.drawWidth
    const mapY = (y: number) => this.drawY + y * this.drawHeight

    const isValid = (p: any) => p && p.visibility >= 0.5

    if (this.avatarMode === 'real') {
      this.drawSkeleton(ctx, landmarks, mapX, mapY, isValid, dpr)
    } else {
      this.drawCartoon(ctx, landmarks, mapX, mapY, isValid, dpr)
    }

    ctx.restore()
  }

  private drawSkeleton(
    ctx: CanvasRenderingContext2D,
    landmarks: any[],
    mapX: (x: number) => number,
    mapY: (y: number) => number,
    isValid: (p: any) => boolean,
    dpr: number
  ): void {
    const colors = this.cartoonColor === 'blue'
      ? { line: '#3498DB', joint: '#87CEEB' }
      : { line: '#FF69B4', joint: '#FFC0CB' }

    const lineWidth = Math.max(3, 4 * dpr)
    const jointRadius = Math.max(4, 6 * dpr)

    ctx.strokeStyle = colors.line
    ctx.lineWidth = lineWidth
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'

    const connections = [
      [NOSE, LEFT_SHOULDER],
      [NOSE, RIGHT_SHOULDER],
      [LEFT_SHOULDER, RIGHT_SHOULDER],
      [LEFT_SHOULDER, LEFT_ELBOW],
      [RIGHT_SHOULDER, RIGHT_ELBOW],
      [LEFT_ELBOW, LEFT_WRIST],
      [RIGHT_ELBOW, RIGHT_WRIST],
      [LEFT_SHOULDER, LEFT_HIP],
      [RIGHT_SHOULDER, RIGHT_HIP],
      [LEFT_HIP, RIGHT_HIP],
      [LEFT_HIP, LEFT_KNEE],
      [RIGHT_HIP, RIGHT_KNEE],
      [LEFT_KNEE, LEFT_ANKLE],
      [RIGHT_KNEE, RIGHT_ANKLE],
    ]

    connections.forEach(([start, end]) => {
      const p1 = landmarks[start]
      const p2 = landmarks[end]
      if (isValid(p1) && isValid(p2)) {
        ctx.beginPath()
        ctx.moveTo(mapX(p1.x), mapY(p1.y))
        ctx.lineTo(mapX(p2.x), mapY(p2.y))
        ctx.stroke()
      }
    })

    ctx.fillStyle = colors.joint
    const jointIndices = [NOSE, LEFT_SHOULDER, RIGHT_SHOULDER, LEFT_ELBOW, RIGHT_ELBOW, LEFT_WRIST, RIGHT_WRIST, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE, LEFT_ANKLE, RIGHT_ANKLE]
    jointIndices.forEach((idx) => {
      const p = landmarks[idx]
      if (isValid(p)) {
        ctx.beginPath()
        ctx.arc(mapX(p.x), mapY(p.y), jointRadius, 0, 2 * Math.PI)
        ctx.fill()
      }
    })
  }

  private drawCartoon(
    ctx: CanvasRenderingContext2D,
    landmarks: any[],
    mapX: (x: number) => number,
    mapY: (y: number) => number,
    isValid: (p: any) => boolean,
    dpr: number
  ): void {
    const isMale = this.gender === 'male'
    const colors = this.cartoonColor === 'blue'
      ? {
          hair: '#1E3A5F',
          hairHighlight: '#2D5A87',
          skin: '#87CEEB',
          skinShadow: '#5BA3C7',
          outfit: '#3498DB',
          outfitDark: '#2471A3',
          pants: '#2C3E50',
          pantsDark: '#1a252f',
          shoe: '#1a1a1a',
          eye: '#1E3A5F',
          primary: '#3498DB',
          secondary: '#87CEEB',
        }
      : {
          hair: '#FF6B9D',
          hairHighlight: '#FF8FB1',
          skin: '#FFC0CB',
          skinShadow: '#FF8FA3',
          outfit: '#FF69B4',
          outfitDark: '#FF1493',
          pants: '#DB7093',
          pantsDark: '#BC5A84',
          shoe: '#8B4577',
          eye: '#FF6B9D',
          primary: '#FF69B4',
          secondary: '#FFC0CB',
        }

    const nose = landmarks[NOSE]
    const lShoulder = landmarks[LEFT_SHOULDER]
    const rShoulder = landmarks[RIGHT_SHOULDER]
    const lElbow = landmarks[LEFT_ELBOW]
    const rElbow = landmarks[RIGHT_ELBOW]
    const lWrist = landmarks[LEFT_WRIST]
    const rWrist = landmarks[RIGHT_WRIST]
    const lHip = landmarks[LEFT_HIP]
    const rHip = landmarks[RIGHT_HIP]
    const lKnee = landmarks[LEFT_KNEE]
    const rKnee = landmarks[RIGHT_KNEE]
    const lAnkle = landmarks[LEFT_ANKLE]
    const rAnkle = landmarks[RIGHT_ANKLE]

    const shoulderMid = {
      x: (lShoulder.x + rShoulder.x) / 2,
      y: (lShoulder.y + rShoulder.y) / 2,
    }
    const hipMid = {
      x: (lHip.x + rHip.x) / 2,
      y: (lHip.y + rHip.y) / 2,
    }

    const shoulderWidth = Math.abs(mapX(lShoulder.x) - mapX(rShoulder.x))
    const headR = Math.max(12 * dpr, shoulderWidth * 0.28)
    const limbWidth = Math.max(4 * dpr, shoulderWidth * 0.14)
    const torsoWidth = shoulderWidth * 0.9

    const drawLimb = (p1: any, p2: any, color: string, w: number) => {
      if (!isValid(p1) || !isValid(p2)) return
      ctx.strokeStyle = color
      ctx.lineWidth = w
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.beginPath()
      ctx.moveTo(mapX(p1.x), mapY(p1.y))
      ctx.lineTo(mapX(p2.x), mapY(p2.y))
      ctx.stroke()
    }

    const drawJoint = (p: any, r: number, color: string) => {
      if (!isValid(p)) return
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.arc(mapX(p.x), mapY(p.y), r, 0, 2 * Math.PI)
      ctx.fill()
    }

    if (isValid(lHip) && isValid(lKnee)) {
      drawLimb(lHip, lKnee, colors.pants, limbWidth * 1.1)
    }
    if (isValid(lKnee) && isValid(lAnkle)) {
      drawLimb(lKnee, lAnkle, colors.pantsDark, limbWidth * 1.0)
    }
    if (isValid(rHip) && isValid(rKnee)) {
      drawLimb(rHip, rKnee, colors.pants, limbWidth * 1.1)
    }
    if (isValid(rKnee) && isValid(rAnkle)) {
      drawLimb(rKnee, rAnkle, colors.pantsDark, limbWidth * 1.0)
    }

    const drawShoe = (ankle: any) => {
      if (!isValid(ankle)) return
      ctx.fillStyle = colors.shoe
      ctx.beginPath()
      ctx.ellipse(mapX(ankle.x), mapY(ankle.y) + limbWidth * 0.3, limbWidth * 0.8, limbWidth * 0.5, 0, 0, 2 * Math.PI)
      ctx.fill()
    }
    drawShoe(lAnkle)
    drawShoe(rAnkle)

    if (isValid(lShoulder) && isValid(rShoulder) && isValid(lHip) && isValid(rHip)) {
      ctx.fillStyle = colors.outfit
      ctx.beginPath()
      const sx = mapX(lShoulder.x)
      const sy = mapY(lShoulder.y)
      const ex = mapX(rShoulder.x)
      const ey = mapY(rShoulder.y)
      const lhx = mapX(lHip.x)
      const lhy = mapY(lHip.y)
      const rhx = mapX(rHip.x)
      const rhy = mapY(rHip.y)

      ctx.moveTo(sx, sy)
      ctx.lineTo(ex, ey)
      const waistOffset = torsoWidth * 0.1
      ctx.lineTo(rhx - waistOffset * 0.3, rhy - limbWidth * 0.2)
      ctx.lineTo(rhx, rhy)
      ctx.lineTo(lhx, lhy)
      ctx.lineTo(lhx + waistOffset * 0.3, lhy - limbWidth * 0.2)
      ctx.closePath()
      ctx.fill()

      ctx.strokeStyle = colors.outfitDark
      ctx.lineWidth = 1.5 * dpr
      ctx.beginPath()
      ctx.moveTo(mapX(shoulderMid.x), mapY(shoulderMid.y))
      ctx.lineTo(mapX(hipMid.x), mapY(hipMid.y))
      ctx.stroke()
    }

    if (isValid(lShoulder) && isValid(lElbow)) {
      drawLimb(lShoulder, lElbow, colors.outfit, limbWidth)
    }
    if (isValid(lElbow) && isValid(lWrist)) {
      drawLimb(lElbow, lWrist, colors.skin, limbWidth * 0.85)
    }
    if (isValid(rShoulder) && isValid(rElbow)) {
      drawLimb(rShoulder, rElbow, colors.outfit, limbWidth)
    }
    if (isValid(rElbow) && isValid(rWrist)) {
      drawLimb(rElbow, rWrist, colors.skin, limbWidth * 0.85)
    }

    const drawHand = (wrist: any) => {
      if (!isValid(wrist)) return
      ctx.fillStyle = colors.skin
      ctx.beginPath()
      ctx.arc(mapX(wrist.x), mapY(wrist.y), limbWidth * 0.55, 0, 2 * Math.PI)
      ctx.fill()
    }
    drawHand(lWrist)
    drawHand(rWrist)

    drawJoint(lElbow, limbWidth * 0.45, colors.outfitDark)
    drawJoint(rElbow, limbWidth * 0.45, colors.outfitDark)
    drawJoint(lKnee, limbWidth * 0.5, colors.pantsDark)
    drawJoint(rKnee, limbWidth * 0.5, colors.pantsDark)

    if (isValid(nose)) {
      const hx = mapX(nose.x)
      const hy = mapY(nose.y)

      if (!isMale) {
        ctx.fillStyle = colors.hair
        ctx.beginPath()
        ctx.ellipse(hx, hy + headR * 0.3, headR * 1.25, headR * 1.6, 0, 0, 2 * Math.PI)
        ctx.fill()
      }

      ctx.fillStyle = colors.skin
      ctx.beginPath()
      ctx.arc(hx, hy, headR, 0, 2 * Math.PI)
      ctx.fill()

      ctx.fillStyle = colors.skinShadow
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.3, headR * 0.85, 0.1 * Math.PI, 0.9 * Math.PI)
      ctx.fill()

      ctx.fillStyle = colors.hair
      if (isMale) {
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.15, headR * 1.05, Math.PI * 1.1, Math.PI * 1.9, false)
        ctx.lineTo(hx + headR * 0.8, hy - headR * 0.3)
        ctx.lineTo(hx + headR * 0.5, hy - headR * 0.7)
        ctx.lineTo(hx + headR * 0.2, hy - headR * 0.4)
        ctx.lineTo(hx, hy - headR * 0.8)
        ctx.lineTo(hx - headR * 0.2, hy - headR * 0.4)
        ctx.lineTo(hx - headR * 0.5, hy - headR * 0.7)
        ctx.lineTo(hx - headR * 0.8, hy - headR * 0.3)
        ctx.closePath()
        ctx.fill()
      } else {
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.1, headR * 1.1, Math.PI, 2 * Math.PI, false)
        ctx.lineTo(hx + headR * 1.1, hy + headR * 0.2)
        ctx.lineTo(hx + headR * 0.6, hy - headR * 0.1)
        ctx.lineTo(hx + headR * 0.3, hy + headR * 0.2)
        ctx.lineTo(hx, hy - headR * 0.2)
        ctx.lineTo(hx - headR * 0.3, hy + headR * 0.2)
        ctx.lineTo(hx - headR * 0.6, hy - headR * 0.1)
        ctx.lineTo(hx - headR * 1.1, hy + headR * 0.2)
        ctx.closePath()
        ctx.fill()
      }

      ctx.fillStyle = colors.hairHighlight
      if (isMale) {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.2, hy - headR * 0.5, headR * 0.25, headR * 0.15, -0.3, 0, 2 * Math.PI)
        ctx.fill()
      } else {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.3, hy - headR * 0.3, headR * 0.3, headR * 0.12, -0.2, 0, 2 * Math.PI)
        ctx.fill()
      }

      const eyeY = hy + headR * 0.05
      const eyeOffsetX = headR * 0.35
      const eyeR = headR * 0.13

      ctx.fillStyle = '#ffffff'
      ctx.beginPath()
      ctx.arc(hx - eyeOffsetX, eyeY, eyeR, 0, 2 * Math.PI)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(hx + eyeOffsetX, eyeY, eyeR, 0, 2 * Math.PI)
      ctx.fill()

      ctx.fillStyle = colors.eye
      ctx.beginPath()
      ctx.arc(hx - eyeOffsetX, eyeY, eyeR * 0.6, 0, 2 * Math.PI)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(hx + eyeOffsetX, eyeY, eyeR * 0.6, 0, 2 * Math.PI)
      ctx.fill()

      ctx.fillStyle = '#ffffff'
      ctx.beginPath()
      ctx.arc(hx - eyeOffsetX + eyeR * 0.2, eyeY - eyeR * 0.2, eyeR * 0.25, 0, 2 * Math.PI)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(hx + eyeOffsetX + eyeR * 0.2, eyeY - eyeR * 0.2, eyeR * 0.25, 0, 2 * Math.PI)
      ctx.fill()

      ctx.strokeStyle = '#C0392B'
      ctx.lineWidth = Math.max(1, 1.5 * dpr)
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.4, headR * 0.15, 0.15 * Math.PI, 0.85 * Math.PI)
      ctx.stroke()

      if (!isMale) {
        ctx.fillStyle = 'rgba(255, 105, 157, 0.3)'
        ctx.beginPath()
        ctx.arc(hx - headR * 0.5, hy + headR * 0.25, headR * 0.15, 0, 2 * Math.PI)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(hx + headR * 0.5, hy + headR * 0.25, headR * 0.15, 0, 2 * Math.PI)
        ctx.fill()
      }
    }
  }

  private drawPauseOverlay(): void {
    if (!this.canvasElement || !this.canvasCtx) return
    const ctx = this.canvasCtx
    const w = this.canvasElement.width
    const h = this.canvasElement.height
    const dpr = window.devicePixelRatio || 1

    ctx.save()
    ctx.fillStyle = 'rgba(15, 23, 42, 0.7)'
    ctx.fillRect(0, 0, w, h)

    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    // 暂停图标 ⏸
    ctx.fillStyle = '#ffffff'
    ctx.font = `bold ${20 * dpr}px Arial`
    ctx.fillText('⏸ 游戏暂停', w / 2, h / 2 - 20 * dpr)

    ctx.font = `${11 * dpr}px Arial`
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)'
    ctx.fillText('请回到摄像头范围内继续', w / 2, h / 2 + 8 * dpr)

    // 倒计时进度环
    const ringR = 28 * dpr
    const ringX = w / 2
    const ringY = h / 2 + 50 * dpr
    const progress = Math.min(1, this.personReturnedFrames / this.PERSON_RETURN_THRESHOLD)

    ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)'
    ctx.lineWidth = 3 * dpr
    ctx.beginPath()
    ctx.arc(ringX, ringY, ringR, 0, 2 * Math.PI)
    ctx.stroke()

    if (progress > 0) {
      ctx.strokeStyle = '#4ADE80'
      ctx.lineWidth = 3 * dpr
      ctx.beginPath()
      ctx.arc(ringX, ringY, ringR, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress)
      ctx.stroke()
    }

    ctx.font = `bold ${10 * dpr}px Arial`
    ctx.fillStyle = '#ffffff'
    ctx.fillText('等待返回...', ringX, ringY)

    ctx.textAlign = 'left'
    ctx.textBaseline = 'alphabetic'
    ctx.restore()
  }

  async destroy(): Promise<void> {
    await this.stop()
    if (this.pose) {
      this.pose.close?.()
      this.pose = null
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
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
