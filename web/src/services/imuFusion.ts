import type { ImuData } from './bluetoothService'

// ===== 类型定义 =====

// IMU 数据样本（带时间戳）
export interface ImuSample extends ImuData {
  timestamp: number
}

// 融合后的运动数据
export interface FusedMotionData {
  // 来自摄像头的姿态数据
  poseConfidence: number       // 姿态识别置信度 0-1
  bodyAngles: {
    knee?: number
    hip?: number
    elbow?: number
    shoulder?: number
  }
  // 来自 IMU 的腰部数据
  waistAcceleration: number   // 腰部加速度幅值
  waistRotation: number        // 腰部旋转角度
  waistStability: number      // 腰部稳定性 0-1
  // 融合结果
  motionIntensity: number     // 综合运动强度 0-1
  fusionConfidence: number    // 融合后置信度 0-1
  source: 'camera' | 'imu' | 'fused'  // 数据来源
}

// 融合配置
export interface FusionConfig {
  // 互补滤波系数（0=纯摄像头，1=纯IMU，0.5=平均）
  cameraWeight: number        // 默认 0.7
  imuWeight: number           // 默认 0.3
  // 运动检测阈值
  motionThreshold: number     // 加速度变化阈值，超过认为有运动
  // 平滑窗口
  smoothingWindow: number     // 平滑窗口大小（样本数）
  // 采样率
  expectedImuSampleRate: number  // 期望IMU采样率 Hz
}

export const DEFAULT_FUSION_CONFIG: FusionConfig = {
  cameraWeight: 0.7,
  imuWeight: 0.3,
  motionThreshold: 2.0,
  smoothingWindow: 5,
  expectedImuSampleRate: 50,
}

// 物理量转换常量
// 加速度：±2g 量程下，原始 int16 满量程 16384 对应 2g，故 raw/16384*9.8 得到 m/s²
const ACCEL_LSB_PER_G = 16384
const GRAVITY = 9.8
// 陀螺仪：±250°/s 量程下，原始 int16 满量程 131 LSB/(°/s)
const GYRO_LSB_PER_DPS = 131
// 重力基准（静止时加速度幅值应接近重力）
const GRAVITY_MAGNITUDE = 9.8

// ===== IMU 数据处理 =====

/**
 * 解析 IMU 原始字节数据（12字节）
 * 布局：ax, ay, az, gx, gy, gz 各 2 字节，int16 小端序
 * 转换为物理单位：加速度 m/s²，陀螺仪 °/s
 */
export function parseImuRawData(bytes: ArrayBuffer): ImuSample {
  const view = new DataView(bytes)
  const timestamp = Date.now()

  if (view.byteLength < 12) {
    return { ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0, timestamp }
  }

  const axRaw = view.getInt16(0, true)
  const ayRaw = view.getInt16(2, true)
  const azRaw = view.getInt16(4, true)
  const gxRaw = view.getInt16(6, true)
  const gyRaw = view.getInt16(8, true)
  const gzRaw = view.getInt16(10, true)

  return {
    ax: (axRaw / ACCEL_LSB_PER_G) * GRAVITY,
    ay: (ayRaw / ACCEL_LSB_PER_G) * GRAVITY,
    az: (azRaw / ACCEL_LSB_PER_G) * GRAVITY,
    gx: gxRaw / GYRO_LSB_PER_DPS,
    gy: gyRaw / GYRO_LSB_PER_DPS,
    gz: gzRaw / GYRO_LSB_PER_DPS,
    timestamp,
  }
}

/**
 * 计算加速度幅值（m/s²）
 * 静止时约等于重力 9.8 m/s²
 */
export function calculateAccelerationMagnitude(sample: ImuSample): number {
  return Math.sqrt(
    sample.ax * sample.ax +
    sample.ay * sample.ay +
    sample.az * sample.az
  )
}

/**
 * 计算腰部旋转角度（积分陀螺仪 z 轴）
 * 使用梯形积分：sum( (gz[i-1] + gz[i]) / 2 * dt )
 * 返回累计旋转角度（°）
 */
export function calculateWaistRotation(samples: ImuSample[]): number {
  if (samples.length < 2) return 0

  let rotation = 0
  for (let i = 1; i < samples.length; i++) {
    const dtSec = (samples[i].timestamp - samples[i - 1].timestamp) / 1000
    if (dtSec <= 0) continue
    const avgGz = (samples[i - 1].gz + samples[i].gz) / 2
    rotation += avgGz * dtSec
  }
  return rotation
}

/**
 * 检测腰部是否有运动
 * 通过加速度幅值偏离重力的程度判断
 */
export function detectWaistMotion(
  samples: ImuSample[],
  threshold: number
): { isMoving: boolean; intensity: number } {
  if (samples.length === 0) {
    return { isMoving: false, intensity: 0 }
  }

  let maxDeviation = 0
  for (const sample of samples) {
    const mag = calculateAccelerationMagnitude(sample)
    const deviation = Math.abs(mag - GRAVITY_MAGNITUDE)
    if (deviation > maxDeviation) {
      maxDeviation = deviation
    }
  }

  const isMoving = maxDeviation > threshold
  // 归一化强度：阈值 2 倍处达到 1.0
  const intensity = Math.min(1, maxDeviation / (threshold * 2))

  return { isMoving, intensity }
}

/**
 * 计算腰部稳定性（基于加速度幅值方差）
 * 方差越小越稳定，返回 0-1
 */
export function calculateWaistStability(samples: ImuSample[]): number {
  if (samples.length < 2) return 1

  const magnitudes = samples.map(calculateAccelerationMagnitude)
  const mean = magnitudes.reduce((a, b) => a + b, 0) / magnitudes.length
  const variance =
    magnitudes.reduce((sum, m) => sum + (m - mean) * (m - mean), 0) /
    magnitudes.length

  // 1/(1+variance)：方差 0 时稳定性 1，方差越大稳定性越低
  return 1 / (1 + variance)
}

// ===== 融合算法 =====

/**
 * 互补滤波融合
 * 权重归一化后加权平均
 */
export function complementaryFilter(
  cameraValue: number,
  imuValue: number,
  cameraWeight: number,
  imuWeight: number
): number {
  const total = cameraWeight + imuWeight
  if (total <= 0) return cameraValue
  return (cameraValue * cameraWeight + imuValue * imuWeight) / total
}

/**
 * 融合摄像头姿态和 IMU 数据
 */
export function fuseMotionData(
  poseData: {
    confidence: number
    bodyAngles: FusedMotionData['bodyAngles']
  },
  imuSamples: ImuSample[],
  config?: Partial<FusionConfig>
): FusedMotionData {
  const cfg: FusionConfig = { ...DEFAULT_FUSION_CONFIG, ...config }

  // 无 IMU 数据，仅使用摄像头
  if (imuSamples.length === 0) {
    return {
      poseConfidence: poseData.confidence,
      bodyAngles: poseData.bodyAngles,
      waistAcceleration: 0,
      waistRotation: 0,
      waistStability: 0,
      motionIntensity: poseData.confidence,
      fusionConfidence: poseData.confidence,
      source: 'camera',
    }
  }

  const latestSample = imuSamples[imuSamples.length - 1]
  const waistAcceleration = calculateAccelerationMagnitude(latestSample)
  const waistRotation = calculateWaistRotation(imuSamples)
  const waistStability = calculateWaistStability(imuSamples)
  const motionResult = detectWaistMotion(imuSamples, cfg.motionThreshold)

  // 摄像头置信度极低，仅使用 IMU
  if (poseData.confidence <= 0) {
    return {
      poseConfidence: 0,
      bodyAngles: poseData.bodyAngles,
      waistAcceleration,
      waistRotation,
      waistStability,
      motionIntensity: motionResult.intensity,
      fusionConfidence: waistStability,
      source: 'imu',
    }
  }

  // 双源融合
  const motionIntensity = complementaryFilter(
    poseData.confidence,
    motionResult.intensity,
    cfg.cameraWeight,
    cfg.imuWeight
  )
  const fusionConfidence = complementaryFilter(
    poseData.confidence,
    waistStability,
    cfg.cameraWeight,
    cfg.imuWeight
  )

  return {
    poseConfidence: poseData.confidence,
    bodyAngles: poseData.bodyAngles,
    waistAcceleration,
    waistRotation,
    waistStability,
    motionIntensity,
    fusionConfidence,
    source: 'fused',
  }
}

/**
 * 运动计数辅助验证
 * 用 IMU 数据验证摄像头检测到的运动是否真实
 */
export function validateRepWithImu(
  cameraDetectedRep: boolean,
  imuSamples: ImuSample[],
  config?: Partial<FusionConfig>
): {
  isValid: boolean      // 是否有效
  confidence: number    // 置信度
  reason: string         // 验证原因
} {
  const cfg: FusionConfig = { ...DEFAULT_FUSION_CONFIG, ...config }

  // 摄像头未检测到动作
  if (!cameraDetectedRep) {
    return {
      isValid: false,
      confidence: 0,
      reason: '摄像头未检测到动作',
    }
  }

  // 无 IMU 数据，仅依赖摄像头
  if (imuSamples.length === 0) {
    return {
      isValid: true,
      confidence: 0.3,
      reason: '无 IMU 数据，仅依赖摄像头检测结果',
    }
  }

  const motionResult = detectWaistMotion(imuSamples, cfg.motionThreshold)

  if (motionResult.isMoving) {
    return {
      isValid: true,
      confidence: 0.5 + motionResult.intensity * 0.5,
      reason: `摄像头与 IMU 均检测到运动（强度: ${motionResult.intensity.toFixed(2)}）`,
    }
  }

  // 摄像头检测到但 IMU 未检测到腰部运动，可能为误检
  return {
    isValid: false,
    confidence: 0.2,
    reason: '摄像头检测到动作但 IMU 未检测到腰部运动，可能为误检',
  }
}

// ===== IMU 数据缓冲区 =====

/**
 * IMU 数据环形缓冲区
 * 保留最新的 maxSize 个样本
 */
export class ImuBuffer {
  private buffer: ImuSample[] = []
  private maxSize: number

  constructor(maxSize: number = 100) {
    this.maxSize = maxSize
  }

  add(sample: ImuSample): void {
    this.buffer.push(sample)
    while (this.buffer.length > this.maxSize) {
      this.buffer.shift()
    }
  }

  getLatest(n: number = 1): ImuSample[] {
    if (n <= 0) return []
    return this.buffer.slice(-n)
  }

  clear(): void {
    this.buffer = []
  }

  size(): number {
    return this.buffer.length
  }

  /**
   * 获取最近 durationMs 毫秒内的样本
   */
  getRecentWindow(durationMs: number): ImuSample[] {
    if (this.buffer.length === 0) return []
    const latest = this.buffer[this.buffer.length - 1].timestamp
    const cutoff = latest - durationMs
    return this.buffer.filter((s) => s.timestamp >= cutoff)
  }
}

// ===== 辅助函数 =====

/**
 * 低通滤波（指数移动平均）
 * y[i] = alpha * x[i] + (1 - alpha) * y[i-1]
 * alpha 越大平滑越弱，越小平滑越强
 */
export function lowPassFilter(values: number[], alpha: number): number[] {
  if (values.length === 0) return []
  const result: number[] = [values[0]]
  for (let i = 1; i < values.length; i++) {
    result.push(alpha * values[i] + (1 - alpha) * result[i - 1])
  }
  return result
}

/**
 * 移动平均
 * 对每个位置取前 window 个样本的平均值（不足时取可用部分）
 */
export function movingAverage(values: number[], window: number): number[] {
  if (values.length === 0) return []
  if (window <= 1) return [...values]

  const result: number[] = []
  for (let i = 0; i < values.length; i++) {
    const start = Math.max(0, i - window + 1)
    const slice = values.slice(start, i + 1)
    const sum = slice.reduce((a, b) => a + b, 0)
    result.push(sum / slice.length)
  }
  return result
}

/**
 * 检测 IMU 数据是否异常（传感器故障检测）
 * 检查 NaN、Infinity、数值超范围、时间戳无效
 */
export function detectImuAnomaly(sample: ImuSample): {
  isAnomaly: boolean
  issues: string[]
} {
  const issues: string[] = []

  const accelFields: Array<['ax' | 'ay' | 'az', number]> = [
    ['ax', sample.ax],
    ['ay', sample.ay],
    ['az', sample.az],
  ]
  const gyroFields: Array<['gx' | 'gy' | 'gz', number]> = [
    ['gx', sample.gx],
    ['gy', sample.gy],
    ['gz', sample.gz],
  ]

  const ACCEL_LIMIT = 100   // m/s²，约 10g，超出认为异常
  const GYRO_LIMIT = 2000   // °/s，超出认为异常

  for (const [name, value] of accelFields) {
    if (Number.isNaN(value) || !Number.isFinite(value)) {
      issues.push(`加速度 ${name} 值无效 (NaN 或 Infinity)`)
    } else if (Math.abs(value) > ACCEL_LIMIT) {
      issues.push(`加速度 ${name} 值超范围: ${value}`)
    }
  }

  for (const [name, value] of gyroFields) {
    if (Number.isNaN(value) || !Number.isFinite(value)) {
      issues.push(`陀螺仪 ${name} 值无效 (NaN 或 Infinity)`)
    } else if (Math.abs(value) > GYRO_LIMIT) {
      issues.push(`陀螺仪 ${name} 值超范围: ${value}`)
    }
  }

  if (Number.isNaN(sample.timestamp) || !Number.isFinite(sample.timestamp) || sample.timestamp <= 0) {
    issues.push('时间戳无效')
  }

  return { isAnomaly: issues.length > 0, issues }
}
