// ========== 游戏逻辑层：连击 / 体力 / 准备 / 暂停 等游戏化系统 ==========

export class ExerciseGameLogic {
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

  // ========== 回调注册 ==========

  setOnPauseChange(callback: ((paused: boolean) => void) | undefined): void {
    this.onPauseChangeCallback = callback
  }

  setOnPrepareProgress(callback: ((progress: number) => void) | undefined): void {
    this.onPrepareProgressCallback = callback
  }

  setOnComboChange(callback: ((combo: number, multiplier: number) => void) | undefined): void {
    this.onComboChangeCallback = callback
  }

  setOnStaminaChange(callback: ((stamina: number) => void) | undefined): void {
    this.onStaminaChangeCallback = callback
  }

  // ========== 暂停系统 ==========

  /**
   * 每帧更新人体离开/返回检测，自动触发暂停与恢复
   */
  updatePauseState(hasPerson: boolean): void {
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
  }

  isGamePaused(): boolean {
    return this.isPaused
  }

  /**
   * 返回恢复进度 (0-1)，用于暂停覆盖层倒计时进度环
   */
  getPauseProgress(): number {
    return Math.min(1, this.personReturnedFrames / this.PERSON_RETURN_THRESHOLD)
  }

  // ========== 准备姿势系统 ==========

  /**
   * 进入准备姿势检测阶段（站好2秒后才正式计时）
   */
  startPrepare(): void {
    this.isPreparing = true
    this.prepareStartTime = Date.now()
    this.prepareProgress = 0
  }

  /**
   * 每帧更新准备进度
   * @returns completed - 是否在本帧完成准备（调用方据此设置正式计时起点）
   */
  updatePrepareState(hasPerson: boolean): { completed: boolean } {
    if (!hasPerson) {
      // 准备中人体离开，重置
      this.prepareStartTime = Date.now()
      this.prepareProgress = 0
      this.onPrepareProgressCallback?.(0)
      return { completed: false }
    }
    const elapsed = Date.now() - this.prepareStartTime
    this.prepareProgress = Math.min(1, elapsed / this.PREPARE_REQUIRED_MS)
    this.onPrepareProgressCallback?.(this.prepareProgress)
    if (elapsed >= this.PREPARE_REQUIRED_MS) {
      this.isPreparing = false
      this.prepareProgress = 1
      this.onPrepareProgressCallback?.(1)
      return { completed: true }
    }
    return { completed: false }
  }

  isInPreparing(): boolean {
    return this.isPreparing
  }

  getPrepareProgress(): number {
    return this.prepareProgress
  }

  // ========== 体力值系统 ==========

  /**
   * 每帧恢复体力
   */
  recoverStamina(): void {
    if (this.stamina < this.MAX_STAMINA) {
      this.stamina = Math.min(this.MAX_STAMINA, this.stamina + this.STAMINA_RECOVERY_RATE)
      this.onStaminaChangeCallback?.(Math.round(this.stamina))
    }
  }

  getStamina(): number {
    return Math.round(this.stamina)
  }

  // ========== 连击系统 ==========

  /**
   * 每帧检查连击是否过期
   */
  checkComboExpiry(): void {
    if (this.comboCount > 0 && Date.now() - this.lastRepTime > this.COMBO_WINDOW_MS) {
      this.comboCount = 0
      this.comboMultiplier = 1.0
      this.onComboChangeCallback?.(0, 1.0)
    }
  }

  getComboCount(): number {
    return this.comboCount
  }

  getComboMultiplier(): number {
    return this.comboMultiplier
  }

  // ========== 通用计数成功处理（连击 + 体力值）==========

  /**
   * 一次动作计数成功时调用：
   * - 检查体力是否足够，不足则返回 false（不计入计数）
   * - 消耗体力、更新连击倍率
   * @returns 是否应当计入本次计数
   */
  handleRepSuccess(): boolean {
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

  // 保留 lastRepQuality 字段以维持原有状态语义（当前未在算法中使用）
  getLastRepQuality(): 'perfect' | 'good' | 'normal' {
    return this.lastRepQuality
  }
}
