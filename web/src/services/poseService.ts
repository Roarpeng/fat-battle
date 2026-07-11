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
  private cartoonColor: CartoonColor = 'orange'
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
    this.cartoonColor = options.cartoonColor ?? 'orange'
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
      // 温暖渐变背景 - 告别恐怖深蓝
      const gradient = ctx.createLinearGradient(0, 0, 0, canvasHeight)
      gradient.addColorStop(0, '#FFF5E6')
      gradient.addColorStop(0.4, '#FFE8D6')
      gradient.addColorStop(1, '#FFD4B8')
      ctx.fillStyle = gradient
      ctx.fillRect(0, 0, canvasWidth, canvasHeight)

      // 柔和的装饰性圆点背景
      ctx.fillStyle = 'rgba(255, 159, 67, 0.06)'
      const dotSpacing = 50 * dpr
      for (let y = 0; y < canvasHeight; y += dotSpacing) {
        for (let x = 0; x < canvasWidth; x += dotSpacing) {
          ctx.beginPath()
          ctx.arc(x, y, 2 * dpr, 0, 2 * Math.PI)
          ctx.fill()
        }
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
    const lineColorMap: Record<CartoonColor, { line: string; joint: string }> = {
      orange: { line: '#FF9F43', joint: '#FDDCB5' },
      mint: { line: '#55EFC4', joint: '#FDDCB5' },
      pink: { line: '#FF6B6B', joint: '#FFE0D0' },
      lavender: { line: '#A29BFE', joint: '#FDDCB5' },
    }
    const colors = lineColorMap[this.cartoonColor] || lineColorMap.orange

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

    // ========== 温暖可爱的配色方案（告别恐怖蓝白灰）==========
    // 核心原则：暖色肤色 + 柔和服饰 + 腮红点缀 + 立体渐变
    const palettes: Record<CartoonColor, {
      skin: string; skinLight: string; skinShadow: string; skinBlush: string;
      hair: string; hairHighlight: string;
      outfit: string; outfitLight: string; outfitDark: string;
      pants: string; pantsDark: string;
      shoe: string; shoeAccent: string;
      eye: string; eyeHighlight: string;
      outline: string;
    }> = {
      orange: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#C8956C', hairHighlight: '#DBA87A',
        outfit: '#FF9F43', outfitLight: '#FFB976', outfitDark: '#E88A2A',
        pants: '#5D4037', pantsDark: '#4E342E',
        shoe: '#E88A2A', shoeAccent: '#FF9F43',
        eye: '#5D4037', eyeHighlight: '#FFFFFF',
        outline: '#8D6E63',
      },
      mint: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#4A6741', hairHighlight: '#6B8F5B',
        outfit: '#55EFC4', outfitLight: '#81FFDB', outfitDark: '#00C9A7',
        pants: '#45B7AA', pantsDark: '#3A9E91',
        shoe: '#2D8F82', shoeAccent: '#55EFC4',
        eye: '#3E6B5E', eyeHighlight: '#FFFFFF',
        outline: '#6B8F5B',
      },
      pink: {
        skin: '#FFE0D0', skinLight: '#FFEBE5', skinShadow: '#F0C0A8', skinBlush: '#FF6B81',
        hair: '#8B4513', hairHighlight: '#A0522D',
        outfit: '#FF6B6B', outfitLight: '#FF8E8E', outfitDark: '#E85555',
        pants: '#C44569', pantsDark: '#A83858',
        shoe: '#E85555', shoeAccent: '#FF6B6B',
        eye: '#5D3A3A', eyeHighlight: '#FFFFFF',
        outline: '#C44569',
      },
      lavender: {
        skin: '#FDDCB5', skinLight: '#FFE8D6', skinShadow: '#E8B896', skinBlush: '#FF8A80',
        hair: '#6C5B7B', hairHighlight: '#8E7CA3',
        outfit: '#A29BFE', outfitLight: '#BDB6FF', outfitDark: '#7C73E6',
        pants: '#6C5CE7', pantsDark: '#5A4BD1',
        shoe: '#5A4BD1', shoeAccent: '#A29BFE',
        eye: '#5D4037', eyeHighlight: '#FFFFFF',
        outline: '#8E7CA3',
      },
    }

    const colors = palettes[this.cartoonColor] || palettes.orange

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
    // Q版比例：更大的头部、更粗的四肢
    const headR = Math.max(16 * dpr, shoulderWidth * 0.38)
    const limbWidth = Math.max(6 * dpr, shoulderWidth * 0.2)
    const torsoWidth = shoulderWidth * 1.0

    // ========== 辅助绘制函数 ==========

    // 圆润的四肢（使用渐变填充的粗线条 + 轮廓线，而非纯线条）
    const drawLimb = (p1: any, p2: any, color: string, w: number, outlineColor: string) => {
      if (!isValid(p1) || !isValid(p2)) return
      const x1 = mapX(p1.x), y1 = mapY(p1.y)
      const x2 = mapX(p2.x), y2 = mapY(p2.y)
      // 轮廓线（比填充稍宽）
      ctx.strokeStyle = outlineColor
      ctx.lineWidth = w + 2 * dpr
      ctx.lineCap = 'round'
      ctx.lineJoin = 'round'
      ctx.beginPath()
      ctx.moveTo(x1, y1)
      ctx.lineTo(x2, y2)
      ctx.stroke()
      // 主色填充
      ctx.strokeStyle = color
      ctx.lineWidth = w
      ctx.beginPath()
      ctx.moveTo(x1, y1)
      ctx.lineTo(x2, y2)
      ctx.stroke()
    }

    // 圆润关节（带轮廓）
    const drawJoint = (p: any, r: number, color: string) => {
      if (!isValid(p)) return
      const x = mapX(p.x), y = mapY(p.y)
      // 轮廓
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.arc(x, y, r + 1 * dpr, 0, 2 * Math.PI)
      ctx.fill()
      // 主体
      ctx.fillStyle = color
      ctx.beginPath()
      ctx.arc(x, y, r, 0, 2 * Math.PI)
      ctx.fill()
    }

    // 圆润鞋子（带轮廓和高光）
    const drawShoe = (ankle: any) => {
      if (!isValid(ankle)) return
      const x = mapX(ankle.x), y = mapY(ankle.y) + limbWidth * 0.3
      const sw = limbWidth * 0.9, sh = limbWidth * 0.55
      // 轮廓
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.ellipse(x, y, sw + 1 * dpr, sh + 1 * dpr, 0, 0, 2 * Math.PI)
      ctx.fill()
      // 鞋子主体
      ctx.fillStyle = colors.shoe
      ctx.beginPath()
      ctx.ellipse(x, y, sw, sh, 0, 0, 2 * Math.PI)
      ctx.fill()
      // 鞋子高光
      ctx.fillStyle = colors.shoeAccent
      ctx.beginPath()
      ctx.ellipse(x - sw * 0.2, y - sh * 0.2, sw * 0.4, sh * 0.25, -0.3, 0, 2 * Math.PI)
      ctx.fill()
    }

    // ========== 绘制腿部 ==========
    drawLimb(lHip, lKnee, colors.pants, limbWidth * 1.2, colors.outline)
    drawLimb(lKnee, lAnkle, colors.pantsDark, limbWidth * 1.1, colors.outline)
    drawLimb(rHip, rKnee, colors.pants, limbWidth * 1.2, colors.outline)
    drawLimb(rKnee, rAnkle, colors.pantsDark, limbWidth * 1.1, colors.outline)

    // 鞋子
    drawShoe(lAnkle)
    drawShoe(rAnkle)

    // ========== 绘制躯干（圆润的梯形 + 渐变 + 轮廓）==========
    if (isValid(lShoulder) && isValid(rShoulder) && isValid(lHip) && isValid(rHip)) {
      const sx = mapX(lShoulder.x), sy = mapY(lShoulder.y)
      const ex = mapX(rShoulder.x), ey = mapY(rShoulder.y)
      const lhx = mapX(lHip.x), lhy = mapY(lHip.y)
      const rhx = mapX(rHip.x), rhy = mapY(rHip.y)

      // 轮廓线
      const drawTorsoShape = (offset: number) => {
        ctx.beginPath()
        ctx.moveTo(sx - offset, sy - offset)
        ctx.lineTo(ex + offset, ey - offset)
        const waistOffset = torsoWidth * 0.08
        ctx.quadraticCurveTo(
          (ex + rhx) / 2 + waistOffset + offset, (ey + rhy) / 2 - offset,
          rhx + offset, rhy + offset
        )
        ctx.lineTo(lhx - offset, lhy + offset)
        ctx.quadraticCurveTo(
          (sx + lhx) / 2 - waistOffset - offset, (sy + lhy) / 2 - offset,
          sx - offset, sy - offset
        )
        ctx.closePath()
      }

      // 先画轮廓
      ctx.fillStyle = colors.outline
      drawTorsoShape(1.5 * dpr)
      ctx.fill()

      // 再画主体（渐变填充，增加立体感）
      const torsoGrad = ctx.createLinearGradient(
        mapX(shoulderMid.x), sy, mapX(hipMid.x), lhy
      )
      torsoGrad.addColorStop(0, colors.outfitLight)
      torsoGrad.addColorStop(0.5, colors.outfit)
      torsoGrad.addColorStop(1, colors.outfitDark)
      ctx.fillStyle = torsoGrad
      drawTorsoShape(0)
      ctx.fill()

      // 上衣装饰线（更柔和）
      ctx.strokeStyle = colors.outfitDark
      ctx.lineWidth = 1 * dpr
      ctx.globalAlpha = 0.3
      ctx.beginPath()
      ctx.moveTo(mapX(shoulderMid.x), mapY(shoulderMid.y))
      ctx.lineTo(mapX(hipMid.x), mapY(hipMid.y))
      ctx.stroke()
      ctx.globalAlpha = 1.0
    }

    // ========== 绘制手臂 ==========
    drawLimb(lShoulder, lElbow, colors.outfit, limbWidth * 1.1, colors.outline)
    drawLimb(lElbow, lWrist, colors.skin, limbWidth * 0.95, colors.skinShadow)
    drawLimb(rShoulder, rElbow, colors.outfit, limbWidth * 1.1, colors.outline)
    drawLimb(rElbow, rWrist, colors.skin, limbWidth * 0.95, colors.skinShadow)

    // 圆润手掌（带轮廓 + 高光）
    const drawHand = (wrist: any) => {
      if (!isValid(wrist)) return
      const x = mapX(wrist.x), y = mapY(wrist.y)
      const r = limbWidth * 0.6
      // 轮廓
      ctx.fillStyle = colors.skinShadow
      ctx.beginPath()
      ctx.arc(x, y, r + 1 * dpr, 0, 2 * Math.PI)
      ctx.fill()
      // 主体（渐变）
      const handGrad = ctx.createRadialGradient(
        x - r * 0.2, y - r * 0.2, r * 0.05,
        x, y, r
      )
      handGrad.addColorStop(0, colors.skinLight)
      handGrad.addColorStop(1, colors.skin)
      ctx.fillStyle = handGrad
      ctx.beginPath()
      ctx.arc(x, y, r, 0, 2 * Math.PI)
      ctx.fill()
    }
    drawHand(lWrist)
    drawHand(rWrist)

    // 关节
    drawJoint(lElbow, limbWidth * 0.5, colors.outfit)
    drawJoint(rElbow, limbWidth * 0.5, colors.outfit)
    drawJoint(lKnee, limbWidth * 0.55, colors.pants)

    // ========== 绘制头部（大圆头 + 渐变 + 腮红 + 大眼睛 + 微笑）==========
    if (isValid(nose)) {
      const hx = mapX(nose.x)
      const hy = mapY(nose.y)

      // --- 头发背景（女性长发在头后面）---
      if (!isMale) {
        ctx.fillStyle = colors.outline
        ctx.beginPath()
        ctx.ellipse(hx, hy + headR * 0.25, headR * 1.3, headR * 1.65, 0, 0, 2 * Math.PI)
        ctx.fill()
        ctx.fillStyle = colors.hair
        ctx.beginPath()
        ctx.ellipse(hx, hy + headR * 0.25, headR * 1.25, headR * 1.6, 0, 0, 2 * Math.PI)
        ctx.fill()
      }

      // --- 头部轮廓 ---
      ctx.fillStyle = colors.outline
      ctx.beginPath()
      ctx.arc(hx, hy, headR + 1.5 * dpr, 0, 2 * Math.PI)
      ctx.fill()

      // --- 头部主体（径向渐变，立体感）---
      const headGrad = ctx.createRadialGradient(
        hx - headR * 0.25, hy - headR * 0.25, headR * 0.02,
        hx, hy, headR
      )
      headGrad.addColorStop(0, colors.skinLight)
      headGrad.addColorStop(0.6, colors.skin)
      headGrad.addColorStop(1, colors.skinShadow)
      ctx.fillStyle = headGrad
      ctx.beginPath()
      ctx.arc(hx, hy, headR, 0, 2 * Math.PI)
      ctx.fill()

      // --- 头发 ---
      ctx.fillStyle = colors.hair
      if (isMale) {
        // 男性短发（圆润弧形）
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.05, headR * 1.02, Math.PI * 1.0, Math.PI * 2.0, false)
        ctx.quadraticCurveTo(hx + headR * 1.1, hy - headR * 0.1, hx + headR * 0.85, hy + headR * 0.15)
        ctx.lineTo(hx + headR * 0.6, hy - headR * 0.35)
        ctx.lineTo(hx + headR * 0.3, hy + headR * 0.05)
        ctx.lineTo(hx, hy - headR * 0.55)
        ctx.lineTo(hx - headR * 0.3, hy + headR * 0.05)
        ctx.lineTo(hx - headR * 0.6, hy - headR * 0.35)
        ctx.lineTo(hx - headR * 0.85, hy + headR * 0.15)
        ctx.quadraticCurveTo(hx - headR * 1.1, hy - headR * 0.1, hx - headR * 1.02, hy - headR * 0.05)
        ctx.closePath()
        ctx.fill()
      } else {
        // 女性长发（更圆润的弧形）
        ctx.beginPath()
        ctx.arc(hx, hy - headR * 0.05, headR * 1.08, Math.PI * 0.95, Math.PI * 2.05, false)
        ctx.quadraticCurveTo(hx + headR * 1.2, hy + headR * 0.3, hx + headR * 0.7, hy + headR * 0.1)
        ctx.lineTo(hx + headR * 0.4, hy - headR * 0.15)
        ctx.lineTo(hx + headR * 0.15, hy + headR * 0.1)
        ctx.lineTo(hx, hy - headR * 0.3)
        ctx.lineTo(hx - headR * 0.15, hy + headR * 0.1)
        ctx.lineTo(hx - headR * 0.4, hy - headR * 0.15)
        ctx.lineTo(hx - headR * 0.7, hy + headR * 0.1)
        ctx.quadraticCurveTo(hx - headR * 1.2, hy + headR * 0.3, hx - headR * 1.08, hy - headR * 0.05)
        ctx.closePath()
        ctx.fill()
      }

      // --- 头发高光 ---
      ctx.fillStyle = colors.hairHighlight
      if (isMale) {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.15, hy - headR * 0.55, headR * 0.3, headR * 0.12, -0.3, 0, 2 * Math.PI)
        ctx.fill()
      } else {
        ctx.beginPath()
        ctx.ellipse(hx - headR * 0.25, hy - headR * 0.45, headR * 0.35, headR * 0.1, -0.2, 0, 2 * Math.PI)
        ctx.fill()
      }

      // --- 大眼睛（Q版大眼 + 高光）---
      const eyeY = hy + headR * 0.08
      const eyeOffsetX = headR * 0.32
      const eyeR = headR * 0.16  // 比原来更大

      // 眼白（带轮廓）
      const drawEye = (ex: number, ey: number) => {
        // 轮廓
        ctx.fillStyle = colors.outline
        ctx.beginPath()
        ctx.ellipse(ex, ey, eyeR + 1 * dpr, eyeR * 1.15 + 1 * dpr, 0, 0, 2 * Math.PI)
        ctx.fill()
        // 眼白
        ctx.fillStyle = '#ffffff'
        ctx.beginPath()
        ctx.ellipse(ex, ey, eyeR, eyeR * 1.15, 0, 0, 2 * Math.PI)
        ctx.fill()
        // 瞳孔（更大更明显）
        ctx.fillStyle = colors.eye
        ctx.beginPath()
        ctx.arc(ex, ey + eyeR * 0.1, eyeR * 0.65, 0, 2 * Math.PI)
        ctx.fill()
        // 瞳孔内部深色
        ctx.fillStyle = '#2D1B1B'
        ctx.beginPath()
        ctx.arc(ex, ey + eyeR * 0.15, eyeR * 0.4, 0, 2 * Math.PI)
        ctx.fill()
        // 高光（双高光 - 增加灵动感）
        ctx.fillStyle = colors.eyeHighlight
        ctx.beginPath()
        ctx.arc(ex + eyeR * 0.25, ey - eyeR * 0.2, eyeR * 0.28, 0, 2 * Math.PI)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(ex - eyeR * 0.15, ey + eyeR * 0.3, eyeR * 0.15, 0, 2 * Math.PI)
        ctx.fill()
      }

      drawEye(hx - eyeOffsetX, eyeY)
      drawEye(hx + eyeOffsetX, eyeY)

      // --- 腮红（男女都有，增加可爱感）---
      const blushR = headR * 0.18
      const blushY = hy + headR * 0.3

      const drawBlush = (bx: number, by: number) => {
        const blushGrad = ctx.createRadialGradient(bx, by, 0, bx, by, blushR)
        blushGrad.addColorStop(0, colors.skinBlush)
        blushGrad.addColorStop(0.6, colors.skinBlush.replace(')', ', 0.4)').replace('rgb', 'rgba'))
        blushGrad.addColorStop(1, 'rgba(255, 138, 128, 0)')
        ctx.fillStyle = blushGrad
        ctx.beginPath()
        ctx.ellipse(bx, by, blushR * 1.2, blushR * 0.8, 0, 0, 2 * Math.PI)
        ctx.fill()
      }

      // 简单实现腮红渐变
      const drawBlushSimple = (bx: number, by: number) => {
        ctx.globalAlpha = 0.35
        ctx.fillStyle = colors.skinBlush
        ctx.beginPath()
        ctx.ellipse(bx, by, blushR * 1.1, blushR * 0.7, 0, 0, 2 * Math.PI)
        ctx.fill()
        ctx.globalAlpha = 1.0
      }

      drawBlushSimple(hx - headR * 0.5, blushY)
      drawBlushSimple(hx + headR * 0.5, blushY)

      // --- 微笑嘴巴（温暖的弧线）---
      ctx.strokeStyle = '#E88A6A'  // 温暖的珊瑚橙，而非冷红色
      ctx.lineWidth = Math.max(1.5, 2 * dpr)
      ctx.lineCap = 'round'
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.35, headR * 0.18, 0.15 * Math.PI, 0.85 * Math.PI)
      ctx.stroke()

      // --- 鼻子（小巧的点）---
      ctx.fillStyle = colors.skinShadow
      ctx.beginPath()
      ctx.arc(hx, hy + headR * 0.22, headR * 0.06, 0, 2 * Math.PI)
      ctx.fill()
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
