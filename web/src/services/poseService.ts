import type { PoseStatus, ExerciseType, PoseLandmark, PoseResults, AvatarMode, CartoonColor, PoseServiceOptions } from './poseTypes'
import {
  MEDIAPIPE_POSE_URL,
  DEFAULT_SQUAT_THRESHOLD, DEFAULT_STAND_THRESHOLD,
  DEFAULT_PUSHUP_THRESHOLD, DEFAULT_MIN_REP_INTERVAL,
} from './poseTypes'
import { withRetry, type RetryOptions } from './retry'
import { exerciseDetectors, type DetectionContext } from './pose/exerciseDetectors'
import { PoseRenderer } from './pose/renderer'
import { ExerciseGameLogic } from './pose/gameLogic'
import {
  createInitialExerciseStates,
  type ExerciseStates,
  type DetectionThresholds,
} from './pose/types'

export class PoseService {
  private status: PoseStatus = 'idle'
  private exerciseType: ExerciseType = 'squat'
  private pose: any = null
  private camera: any = null
  private videoElement: HTMLVideoElement | null = null
  private onResultsCallback?: (results: PoseResults) => void
  private onCountCallback?: (count: number) => void
  private onStatusChangeCallback?: (status: PoseStatus) => void
  private onErrorCallback?: (error: Error) => void
  private scriptLoaded = false
  private boundOnResults: (results: any) => void
  private userWeight: number = 70
  private onPhotoCaptureCallback?: (photoData: string) => void

  // ========== 拆分后的子模块 ==========
  private renderer: PoseRenderer
  private gameLogic: ExerciseGameLogic
  private states: ExerciseStates
  private thresholds: DetectionThresholds

  private startTime: number = 0
  private caloriesBurned: number = 0

  // ========== 帧率监控 & 性能降级 ==========
  private frameTimes: number[] = []
  private readonly FPS_SAMPLE_SIZE: number = 30
  private currentFps: number = 0
  private downgradeLevel: number = 0 // 0=正常, 1=跳过一半帧, 2=每3帧处理1帧
  private frameCounter: number = 0
  private readonly FPS_DOWNGRADE_THRESHOLD: number = 15
  private readonly FPS_UPGRADE_THRESHOLD: number = 25
  private onFpsChangeCallback?: (fps: number) => void
  private onPerformanceDowngradeCallback?: (level: number) => void
  /** 模型加载重试配置，默认 2 次重试 */
  private loadRetryOptions: RetryOptions = {
    retries: 2,
    delay: 1000,
    backoff: 'exponential',
    factor: 2,
  }

  constructor(options: PoseServiceOptions = {}) {
    this.exerciseType = options.exerciseType || 'squat'
    this.renderer = new PoseRenderer(options.canvasElement || undefined)
    if (options.videoElement) {
      this.videoElement = options.videoElement
      this.renderer.setVideoElement(options.videoElement)
    }
    this.onResultsCallback = options.onResults
    this.onCountCallback = options.onCount
    this.onStatusChangeCallback = options.onStatusChange
    this.onErrorCallback = options.onError
    this.onPhotoCaptureCallback = options.onPhotoCapture

    // 游戏化系统回调注册
    this.gameLogic = new ExerciseGameLogic()
    this.gameLogic.setOnPauseChange(options.onPauseChange)
    this.gameLogic.setOnPrepareProgress(options.onPrepareProgress)
    this.gameLogic.setOnComboChange(options.onComboChange)
    this.gameLogic.setOnStaminaChange(options.onStaminaChange)

    this.thresholds = {
      squatThresholdAngle: options.squatThresholdAngle ?? DEFAULT_SQUAT_THRESHOLD,
      standThresholdAngle: options.standThresholdAngle ?? DEFAULT_STAND_THRESHOLD,
      pushupThresholdAngle: options.pushupThresholdAngle ?? DEFAULT_PUSHUP_THRESHOLD,
      minRepInterval: options.minRepInterval ?? DEFAULT_MIN_REP_INTERVAL,
    }

    this.userWeight = options.userWeight ?? 70
    this.renderer.setGender(options.gender ?? 'male')
    this.renderer.setAvatarMode(options.avatarMode ?? 'cartoon')
    this.renderer.setCartoonColor(options.cartoonColor ?? 'orange')

    this.states = createInitialExerciseStates()

    this.boundOnResults = this.onResults.bind(this)
  }

  getStatus(): PoseStatus {
    return this.status
  }

  getCount(): number {
    switch (this.exerciseType) {
      case 'squat': return this.states.squat.count
      case 'pushup': return this.states.pushup.count
      case 'jumprope': return this.states.jumprope.count
      case 'highknee': return this.states.highknee.count
      case 'plank': return this.states.plank.count
      case 'burpee': return this.states.burpee.count
      case 'lunge': return this.states.lunge.count
      case 'mountainclimber': return this.states.mountainclimber.count
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
    this.renderer.setGender(gender)
  }

  getCaloriesBurned(): number {
    return this.caloriesBurned
  }

  getElapsedTime(): number {
    if (this.startTime === 0) return 0
    return Math.floor((Date.now() - this.startTime) / 1000)
  }

  getKneeAngle(): number {
    return this.states.squat.kneeAngle
  }

  getElbowAngle(): number {
    return this.states.pushup.elbowAngle
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

  // ========== 帧率监控 & 性能降级 ==========
  getCurrentFps(): number {
    return this.currentFps
  }

  getDowngradeLevel(): number {
    return this.downgradeLevel
  }

  setOnFpsChange(callback: (fps: number) => void): void {
    this.onFpsChangeCallback = callback
  }

  setOnPerformanceDowngrade(callback: (level: number) => void): void {
    this.onPerformanceDowngradeCallback = callback
  }

  /** 配置模型加载的重试参数 */
  setLoadRetryOptions(options: RetryOptions): void {
    this.loadRetryOptions = { ...this.loadRetryOptions, ...options }
  }

  // ========== 游戏化系统 getter/setter ==========
  isGamePaused(): boolean { return this.gameLogic.isGamePaused() }
  getComboCount(): number { return this.gameLogic.getComboCount() }
  getComboMultiplier(): number { return this.gameLogic.getComboMultiplier() }
  getStamina(): number { return this.gameLogic.getStamina() }
  isInPreparing(): boolean { return this.gameLogic.isInPreparing() }
  getPrepareProgress(): number { return this.gameLogic.getPrepareProgress() }

  setOnPauseChange(callback: (paused: boolean) => void): void {
    this.gameLogic.setOnPauseChange(callback)
  }
  setOnPrepareProgress(callback: (progress: number) => void): void {
    this.gameLogic.setOnPrepareProgress(callback)
  }
  setOnComboChange(callback: (combo: number, multiplier: number) => void): void {
    this.gameLogic.setOnComboChange(callback)
  }
  setOnStaminaChange(callback: (stamina: number) => void): void {
    this.gameLogic.setOnStaminaChange(callback)
  }

  setOnPhotoCapture(callback: (photoData: string) => void): void {
    this.onPhotoCaptureCallback = callback
  }

  setAvatarMode(mode: AvatarMode): void {
    this.renderer.setAvatarMode(mode)
  }

  getAvatarMode(): AvatarMode {
    return this.renderer.getAvatarMode()
  }

  setCartoonColor(color: CartoonColor): void {
    this.renderer.setCartoonColor(color)
  }

  getCartoonColor(): CartoonColor {
    return this.renderer.getCartoonColor()
  }

  capturePhoto(): string | null {
    return this.renderer.capturePhoto()
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.videoElement = video
    this.renderer.setVideoElement(video)
  }

  setCanvasElement(canvas: HTMLCanvasElement): void {
    this.renderer.setCanvas(canvas)
  }

  setCameraFacing(facing: 'user' | 'environment'): void {
    this.renderer.setCameraFacing(facing)
  }

  resetCount(): void {
    this.states = createInitialExerciseStates()
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

      // 脚本加载带重试（默认 2 次，指数退避）
      if (!this.scriptLoaded) {
        await withRetry(async () => {
          await this.loadScript(`${MEDIAPIPE_POSE_URL}/pose.js`)
          if (!window.Pose) {
            throw new Error('MediaPipe Pose 加载失败')
          }
        }, this.loadRetryOptions)
        this.scriptLoaded = true
      }

      if (!window.Pose) {
        throw new Error('MediaPipe Pose 加载失败')
      }

      // 仅在尚未创建时实例化 Pose，避免重试导致重复实例
      if (!this.pose) {
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
      }

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
        throw new Error('当前浏览器不支持摄像头访问，请使用 Chrome/Edge/Firefox 最新版')
      }

      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('摄像头连接超时')), 5000)
      })

      const streamPromise = navigator.mediaDevices.getUserMedia({
        video: {
          width: { ideal: 640 },
          height: { ideal: 480 },
          facingMode: this.renderer.getCameraFacing(),
        },
        audio: false,
      })

      const stream = await Promise.race([streamPromise, timeoutPromise])

      this.videoElement.srcObject = stream
      await this.videoElement.play()

      // 重置帧率监控状态
      this.frameTimes = []
      this.currentFps = 0
      this.downgradeLevel = 0
      this.frameCounter = 0

      if (window.Camera) {
        this.camera = new window.Camera(this.videoElement, {
          onFrame: async () => {
            if (this.pose && (this.status === 'running' || this.gameLogic.isInPreparing())) {
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
      this.gameLogic.startPrepare()
      this.setStatus('running')
      return true
    } catch (err) {
      const error = this.normalizeCameraError(err)
      this.stopCamera()
      this.setStatus('error')
      this.emitError(error)
      return false
    }
  }

  /**
   * 将摄像头错误转换为带友好提示的错误，便于 UI 给出降级指引
   */
  private normalizeCameraError(err: unknown): Error {
    const raw = err instanceof Error ? err : new Error(String(err))
    const name = raw.name || ''
    const msg = (raw.message || '').toLowerCase()

    // 权限被拒绝
    if (name === 'NotAllowedError' || msg.includes('permission') || msg.includes('permissiondenied')) {
      const e = new Error('摄像头权限被拒绝，请在浏览器地址栏点击锁形图标，允许摄像头权限后重试')
      e.name = 'CameraPermissionError'
      return e
    }
    // 未找到设备
    if (name === 'NotFoundError' || name === 'DevicesNotFoundError' || msg.includes('notfound')) {
      const e = new Error('未检测到摄像头设备，请检查摄像头是否已连接且未被其他应用占用')
      e.name = 'CameraNotFoundError'
      return e
    }
    // 设备被占用
    if (name === 'NotReadableError' || name === 'TrackStartError' || msg.includes('notreadable')) {
      const e = new Error('摄像头被其他应用占用，请关闭其他使用摄像头的程序后重试')
      e.name = 'CameraBusyError'
      return e
    }
    // 超时
    if (msg.includes('超时') || msg.includes('timeout')) {
      const e = new Error('摄像头连接超时，请检查设备后重试')
      e.name = 'CameraTimeoutError'
      return e
    }
    return raw
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
      if (this.status !== 'running' && !this.gameLogic.isInPreparing()) return

      // 性能降级：根据 downgradeLevel 跳过部分帧
      this.frameCounter++
      if (this.shouldSkipFrame()) {
        requestAnimationFrame(loop)
        return
      }

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

  /**
   * 根据当前降级等级判断是否跳过本帧
   * - level 0: 不跳过
   * - level 1: 跳过偶数帧（处理一半）
   * - level 2: 每 3 帧处理 1 帧
   */
  private shouldSkipFrame(): boolean {
    if (this.downgradeLevel <= 0) return false
    if (this.downgradeLevel === 1) {
      return this.frameCounter % 2 === 0
    }
    return this.frameCounter % 3 !== 0
  }

  /**
   * 更新帧率统计并根据 FPS 调整降级等级
   */
  private updateFpsStats(): void {
    const now = performance.now()
    this.frameTimes.push(now)
    if (this.frameTimes.length > this.FPS_SAMPLE_SIZE) {
      this.frameTimes.shift()
    }
    if (this.frameTimes.length < 10) return

    const elapsed = this.frameTimes[this.frameTimes.length - 1] - this.frameTimes[0]
    if (elapsed <= 0) return

    const fps = Math.round((this.frameTimes.length - 1) * 1000 / elapsed)
    if (fps !== this.currentFps) {
      this.currentFps = fps
      this.onFpsChangeCallback?.(fps)
    }
    this.adjustPerformance(fps)
  }

  /**
   * 性能不足时自动降级，恢复时自动升级
   */
  private adjustPerformance(fps: number): void {
    const previousLevel = this.downgradeLevel
    if (fps < this.FPS_DOWNGRADE_THRESHOLD && this.downgradeLevel < 2) {
      this.downgradeLevel++
    } else if (fps > this.FPS_UPGRADE_THRESHOLD && this.downgradeLevel > 0) {
      this.downgradeLevel--
    }
    if (this.downgradeLevel !== previousLevel) {
      this.onPerformanceDowngradeCallback?.(this.downgradeLevel)
    }
  }

  async stop(): Promise<void> {
    try {
      if (this.camera) {
        this.camera.stop?.()
        this.camera = null
      }

      this.stopCamera()
      // 停止时清空帧率统计，避免恢复后计算异常
      this.frameTimes = []
      this.currentFps = 0
      this.downgradeLevel = 0
      this.frameCounter = 0
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

  private buildDetectionContext(landmarks: PoseLandmark[]): DetectionContext {
    return {
      landmarks,
      thresholds: this.thresholds,
      states: this.states,
      userWeight: this.userWeight,
      handleRepSuccess: () => this.gameLogic.handleRepSuccess(),
      setCalories: (calories: number) => { this.caloriesBurned = calories },
      onCount: (count: number) => { this.onCountCallback?.(count) },
    }
  }

  private onResults(results: any): void {
    // 帧率监控：每次拿到一帧结果即更新统计
    this.updateFpsStats()

    this.renderer.drawBackground(results)

    const hasPerson = !!results.poseLandmarks && results.poseLandmarks.length > 0

    // ========== 人体离开检测 & 暂停系统 ==========
    this.gameLogic.updatePauseState(hasPerson)

    // 暂停中：绘制暂停提示，停止一切检测
    if (this.gameLogic.isGamePaused()) {
      this.renderer.drawPauseOverlay(this.gameLogic.getPauseProgress())
      return
    }

    // 准备姿势检测阶段
    if (this.gameLogic.isInPreparing()) {
      const { completed } = this.gameLogic.updatePrepareState(hasPerson)
      if (completed) {
        this.startTime = Date.now()
      }
      this.renderer.drawCharacter(results)
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
    this.gameLogic.recoverStamina()

    // ========== 连击过期检查 ==========
    this.gameLogic.checkComboExpiry()

    // ========== 运动检测（委托给检测算法层）==========
    exerciseDetectors[this.exerciseType].detect(this.buildDetectionContext(landmarks))

    this.renderer.drawCharacter(results)
    this.onResultsCallback?.(poseResults)
  }

  async destroy(): Promise<void> {
    await this.stop()
    if (this.pose) {
      this.pose.close?.()
      this.pose = null
    }
    this.renderer.dispose()
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

export * from './poseTypes'
