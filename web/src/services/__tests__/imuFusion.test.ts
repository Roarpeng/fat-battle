import { describe, it, expect } from 'vitest'
import {
  parseImuRawData,
  calculateAccelerationMagnitude,
  calculateWaistRotation,
  detectWaistMotion,
  calculateWaistStability,
  complementaryFilter,
  fuseMotionData,
  validateRepWithImu,
  ImuBuffer,
  lowPassFilter,
  movingAverage,
  detectImuAnomaly,
  DEFAULT_FUSION_CONFIG,
  type ImuSample,
} from '../imuFusion'

// 辅助：构造 IMU 样本（默认静止状态：仅重力 az=9.8）
function makeSample(
  partial: Partial<ImuSample> & { timestamp: number }
): ImuSample {
  return {
    ax: 0,
    ay: 0,
    az: 9.8,
    gx: 0,
    gy: 0,
    gz: 0,
    ...partial,
  }
}

// 辅助：构造静止样本序列
function makeStationarySamples(count: number, startTs: number = 1000, intervalMs: number = 20): ImuSample[] {
  return Array.from({ length: count }, (_, i) =>
    makeSample({ timestamp: startTs + i * intervalMs })
  )
}

// ===== IMU 原始数据解析 =====
describe('parseImuRawData', () => {
  it('解析 12 字节 IMU 数据为物理单位', () => {
    const buffer = new ArrayBuffer(12)
    const view = new DataView(buffer)
    view.setInt16(0, 16384, true)   // ax = 16384/16384*9.8 = 9.8 m/s²
    view.setInt16(2, -16384, true)  // ay = -9.8 m/s²
    view.setInt16(4, 8192, true)    // az = 8192/16384*9.8 = 4.9 m/s²
    view.setInt16(6, 131, true)     // gx = 131/131 = 1 °/s
    view.setInt16(8, -262, true)    // gy = -262/131 = -2 °/s
    view.setInt16(10, 655, true)    // gz = 655/131 = 5 °/s

    const sample = parseImuRawData(buffer)

    expect(sample.ax).toBeCloseTo(9.8, 5)
    expect(sample.ay).toBeCloseTo(-9.8, 5)
    expect(sample.az).toBeCloseTo(4.9, 5)
    expect(sample.gx).toBeCloseTo(1, 5)
    expect(sample.gy).toBeCloseTo(-2, 5)
    expect(sample.gz).toBeCloseTo(5, 5)
    expect(sample.timestamp).toBeGreaterThan(0)
  })

  it('字节数不足 12 时返回零值', () => {
    const buffer = new ArrayBuffer(6)
    const sample = parseImuRawData(buffer)

    expect(sample.ax).toBe(0)
    expect(sample.ay).toBe(0)
    expect(sample.az).toBe(0)
    expect(sample.gx).toBe(0)
    expect(sample.gy).toBe(0)
    expect(sample.gz).toBe(0)
    expect(sample.timestamp).toBeGreaterThan(0)
  })

  it('零数据缓冲区返回全零样本', () => {
    const buffer = new ArrayBuffer(12)
    const sample = parseImuRawData(buffer)

    expect(sample.ax).toBe(0)
    expect(sample.gx).toBe(0)
  })
})

// ===== 加速度幅值计算 =====
describe('calculateAccelerationMagnitude', () => {
  it('3-4-5 直角三角形加速度幅值为 5', () => {
    const sample = makeSample({ ax: 3, ay: 4, az: 0, timestamp: 0 })
    expect(calculateAccelerationMagnitude(sample)).toBeCloseTo(5, 5)
  })

  it('静止时幅值约等于重力 9.8', () => {
    const sample = makeSample({ ax: 0, ay: 0, az: 9.8, timestamp: 0 })
    expect(calculateAccelerationMagnitude(sample)).toBeCloseTo(9.8, 5)
  })

  it('三轴均有值时正确计算', () => {
    const sample = makeSample({ ax: 1, ay: 2, az: 2, timestamp: 0 })
    // sqrt(1 + 4 + 4) = sqrt(9) = 3
    expect(calculateAccelerationMagnitude(sample)).toBeCloseTo(3, 5)
  })
})

// ===== 腰部旋转角度（陀螺仪积分）=====
describe('calculateWaistRotation', () => {
  it('空数组返回 0', () => {
    expect(calculateWaistRotation([])).toBe(0)
  })

  it('单个样本返回 0', () => {
    expect(calculateWaistRotation([makeSample({ timestamp: 0 })])).toBe(0)
  })

  it('恒定角速度 10°/s 持续 200ms 旋转 2°', () => {
    const samples: ImuSample[] = [
      makeSample({ gz: 10, timestamp: 0 }),
      makeSample({ gz: 10, timestamp: 100 }),
      makeSample({ gz: 10, timestamp: 200 }),
    ]
    // 梯形积分：(10+10)/2 * 0.1 + (10+10)/2 * 0.1 = 1 + 1 = 2
    expect(calculateWaistRotation(samples)).toBeCloseTo(2.0, 5)
  })

  it('线性变化角速度正确积分', () => {
    const samples: ImuSample[] = [
      makeSample({ gz: 0, timestamp: 0 }),
      makeSample({ gz: 10, timestamp: 100 }),
      makeSample({ gz: 20, timestamp: 200 }),
    ]
    // (0+10)/2 * 0.1 + (10+20)/2 * 0.1 = 0.5 + 1.5 = 2
    expect(calculateWaistRotation(samples)).toBeCloseTo(2.0, 5)
  })

  it('负角速度产生负旋转', () => {
    const samples: ImuSample[] = [
      makeSample({ gz: -10, timestamp: 0 }),
      makeSample({ gz: -10, timestamp: 100 }),
    ]
    // (-10 + -10)/2 * 0.1 = -1
    expect(calculateWaistRotation(samples)).toBeCloseTo(-1.0, 5)
  })
})

// ===== 腰部运动检测 =====
describe('detectWaistMotion', () => {
  it('静止样本不检测到运动', () => {
    const samples = makeStationarySamples(5)
    const result = detectWaistMotion(samples, DEFAULT_FUSION_CONFIG.motionThreshold)
    expect(result.isMoving).toBe(false)
    expect(result.intensity).toBeCloseTo(0, 5)
  })

  it('空数组不检测到运动', () => {
    const result = detectWaistMotion([], 2.0)
    expect(result.isMoving).toBe(false)
    expect(result.intensity).toBe(0)
  })

  it('中等运动（偏离重力 3 m/s²）检测到运动', () => {
    // az = 12.8 → 幅值 12.8 → 偏离 9.8 为 3.0 > 阈值 2.0
    const samples: ImuSample[] = [
      makeSample({ az: 9.8, timestamp: 0 }),
      makeSample({ az: 12.8, timestamp: 100 }),
      makeSample({ az: 9.8, timestamp: 200 }),
    ]
    const result = detectWaistMotion(samples, 2.0)
    expect(result.isMoving).toBe(true)
    // intensity = 3.0 / (2.0 * 2) = 0.75
    expect(result.intensity).toBeCloseTo(0.75, 5)
  })

  it('剧烈运动强度达到 1.0', () => {
    // az = 19.8 → 偏离 10.0 → intensity = min(1, 10/4) = 1.0
    const samples: ImuSample[] = [
      makeSample({ az: 19.8, timestamp: 0 }),
    ]
    const result = detectWaistMotion(samples, 2.0)
    expect(result.isMoving).toBe(true)
    expect(result.intensity).toBe(1)
  })

  it('低于阈值的运动不触发', () => {
    // az = 11.0 → 偏离 1.2 < 阈值 2.0
    const samples: ImuSample[] = [
      makeSample({ az: 11.0, timestamp: 0 }),
    ]
    const result = detectWaistMotion(samples, 2.0)
    expect(result.isMoving).toBe(false)
  })
})

// ===== 腰部稳定性计算 =====
describe('calculateWaistStability', () => {
  it('空数组返回 1（最稳定）', () => {
    expect(calculateWaistStability([])).toBe(1)
  })

  it('单个样本返回 1（最稳定）', () => {
    expect(calculateWaistStability([makeSample({ timestamp: 0 })])).toBe(1)
  })

  it('静止样本稳定性为 1', () => {
    const samples = makeStationarySamples(5)
    // 所有幅值 = 9.8，方差 = 0，稳定性 = 1/(1+0) = 1
    expect(calculateWaistStability(samples)).toBeCloseTo(1, 5)
  })

  it('波动样本稳定性降低', () => {
    const samples: ImuSample[] = [
      makeSample({ az: 9.8, timestamp: 0 }),
      makeSample({ az: 12.8, timestamp: 100 }),
      makeSample({ az: 9.8, timestamp: 200 }),
      makeSample({ az: 12.8, timestamp: 300 }),
    ]
    // 幅值：9.8, 12.8, 9.8, 12.8
    // 均值 = 11.3，方差 = 2.25
    // 稳定性 = 1/(1+2.25) = 1/3.25 ≈ 0.3077
    const stability = calculateWaistStability(samples)
    expect(stability).toBeLessThan(1)
    expect(stability).toBeGreaterThan(0)
    expect(stability).toBeCloseTo(1 / 3.25, 5)
  })

  it('波动越大稳定性越低', () => {
    const smallVariance = [
      makeSample({ az: 9.8, timestamp: 0 }),
      makeSample({ az: 10.0, timestamp: 100 }),
    ]
    const largeVariance = [
      makeSample({ az: 9.8, timestamp: 0 }),
      makeSample({ az: 20.0, timestamp: 100 }),
    ]
    expect(calculateWaistStability(smallVariance)).toBeGreaterThan(
      calculateWaistStability(largeVariance)
    )
  })
})

// ===== 互补滤波融合 =====
describe('complementaryFilter', () => {
  it('加权平均（0.7/0.3）', () => {
    // (10*0.7 + 20*0.3) / 1.0 = 13
    expect(complementaryFilter(10, 20, 0.7, 0.3)).toBeCloseTo(13, 5)
  })

  it('等权平均（0.5/0.5）', () => {
    expect(complementaryFilter(10, 20, 0.5, 0.5)).toBeCloseTo(15, 5)
  })

  it('纯摄像头权重（1/0）', () => {
    expect(complementaryFilter(10, 20, 1, 0)).toBeCloseTo(10, 5)
  })

  it('纯 IMU 权重（0/1）', () => {
    expect(complementaryFilter(10, 20, 0, 1)).toBeCloseTo(20, 5)
  })

  it('权重为 0 时回退到摄像头值', () => {
    expect(complementaryFilter(10, 20, 0, 0)).toBe(10)
  })

  it('小数值正确融合', () => {
    // (0.8*0.7 + 0.6*0.3) / 1.0 = 0.56 + 0.18 = 0.74
    expect(complementaryFilter(0.8, 0.6, 0.7, 0.3)).toBeCloseTo(0.74, 5)
  })
})

// ===== 融合数据 =====
describe('fuseMotionData', () => {
  it('无 IMU 数据时来源为 camera', () => {
    const result = fuseMotionData(
      { confidence: 0.9, bodyAngles: { knee: 90 } },
      []
    )
    expect(result.source).toBe('camera')
    expect(result.poseConfidence).toBeCloseTo(0.9, 5)
    expect(result.waistAcceleration).toBe(0)
    expect(result.fusionConfidence).toBeCloseTo(0.9, 5)
  })

  it('摄像头置信度为 0 时来源为 imu', () => {
    const samples = makeStationarySamples(3)
    const result = fuseMotionData(
      { confidence: 0, bodyAngles: {} },
      samples
    )
    expect(result.source).toBe('imu')
    expect(result.poseConfidence).toBe(0)
    expect(result.waistStability).toBeCloseTo(1, 5)
  })

  it('双源数据来源为 fused', () => {
    const samples = makeStationarySamples(3)
    const result = fuseMotionData(
      { confidence: 0.8, bodyAngles: { knee: 100 } },
      samples
    )
    expect(result.source).toBe('fused')
    expect(result.bodyAngles.knee).toBe(100)
    expect(result.motionIntensity).toBeGreaterThan(0)
    expect(result.fusionConfidence).toBeGreaterThan(0)
  })
})

// ===== 运动计数验证 =====
describe('validateRepWithImu', () => {
  it('摄像头检测到 + IMU 确认运动 = 有效', () => {
    // az = 12.8 → 偏离 3.0 > 阈值 2.0 → 有运动
    const samples: ImuSample[] = [
      makeSample({ az: 9.8, timestamp: 0 }),
      makeSample({ az: 12.8, timestamp: 100 }),
    ]
    const result = validateRepWithImu(true, samples)
    expect(result.isValid).toBe(true)
    expect(result.confidence).toBeGreaterThan(0.5)
    expect(result.reason).toContain('IMU')
  })

  it('摄像头检测到 + IMU 无运动 = 无效（可能误检）', () => {
    const samples = makeStationarySamples(5)
    const result = validateRepWithImu(true, samples)
    expect(result.isValid).toBe(false)
    expect(result.confidence).toBeLessThan(0.5)
    expect(result.reason).toContain('误检')
  })

  it('摄像头未检测到动作 = 无效', () => {
    const samples = makeStationarySamples(3)
    const result = validateRepWithImu(false, samples)
    expect(result.isValid).toBe(false)
    expect(result.confidence).toBe(0)
    expect(result.reason).toContain('未检测到动作')
  })

  it('摄像头检测到 + 无 IMU 数据 = 仅依赖摄像头', () => {
    const result = validateRepWithImu(true, [])
    expect(result.isValid).toBe(true)
    expect(result.confidence).toBeCloseTo(0.3, 5)
    expect(result.reason).toContain('无 IMU 数据')
  })

  it('剧烈运动时置信度更高', () => {
    const moderate: ImuSample[] = [
      makeSample({ az: 12.8, timestamp: 0 }), // 偏离 3.0
    ]
    const intense: ImuSample[] = [
      makeSample({ az: 19.8, timestamp: 0 }), // 偏离 10.0
    ]
    const moderateResult = validateRepWithImu(true, moderate)
    const intenseResult = validateRepWithImu(true, intense)
    expect(intenseResult.confidence).toBeGreaterThan(moderateResult.confidence)
  })
})

// ===== IMU 缓冲区 =====
describe('ImuBuffer', () => {
  it('默认 maxSize 为 100', () => {
    const buf = new ImuBuffer()
    expect(buf.size()).toBe(0)
    for (let i = 0; i < 150; i++) {
      buf.add(makeSample({ timestamp: i }))
    }
    expect(buf.size()).toBe(100)
  })

  it('超过 maxSize 时保留最新样本', () => {
    const buf = new ImuBuffer(3)
    buf.add(makeSample({ timestamp: 1 }))
    buf.add(makeSample({ timestamp: 2 }))
    buf.add(makeSample({ timestamp: 3 }))
    buf.add(makeSample({ timestamp: 4 }))
    buf.add(makeSample({ timestamp: 5 }))

    expect(buf.size()).toBe(3)
    const latest = buf.getLatest(3)
    expect(latest.map((s) => s.timestamp)).toEqual([3, 4, 5])
  })

  it('getLatest 返回最新 n 个样本', () => {
    const buf = new ImuBuffer(10)
    for (let i = 1; i <= 5; i++) {
      buf.add(makeSample({ timestamp: i }))
    }
    const latest2 = buf.getLatest(2)
    expect(latest2).toHaveLength(2)
    expect(latest2[0].timestamp).toBe(4)
    expect(latest2[1].timestamp).toBe(5)
  })

  it('getLatest 默认返回 1 个样本', () => {
    const buf = new ImuBuffer(10)
    buf.add(makeSample({ timestamp: 42 }))
    const latest = buf.getLatest()
    expect(latest).toHaveLength(1)
    expect(latest[0].timestamp).toBe(42)
  })

  it('getLatest(0) 返回空数组', () => {
    const buf = new ImuBuffer(10)
    buf.add(makeSample({ timestamp: 1 }))
    expect(buf.getLatest(0)).toEqual([])
  })

  it('clear 清空缓冲区', () => {
    const buf = new ImuBuffer(10)
    buf.add(makeSample({ timestamp: 1 }))
    buf.add(makeSample({ timestamp: 2 }))
    expect(buf.size()).toBe(2)
    buf.clear()
    expect(buf.size()).toBe(0)
    expect(buf.getLatest()).toEqual([])
  })

  it('getRecentWindow 返回时间窗口内样本', () => {
    const buf = new ImuBuffer(100)
    // timestamps: 1000, 1100, 1200, 1300, 1400
    for (let i = 0; i < 5; i++) {
      buf.add(makeSample({ timestamp: 1000 + i * 100 }))
    }
    // 最新时间戳 1400，窗口 200ms → cutoff = 1200
    const window = buf.getRecentWindow(200)
    expect(window).toHaveLength(3)
    expect(window.map((s) => s.timestamp)).toEqual([1200, 1300, 1400])
  })

  it('getRecentWindow 空缓冲区返回空数组', () => {
    const buf = new ImuBuffer()
    expect(buf.getRecentWindow(100)).toEqual([])
  })

  it('size 返回当前样本数', () => {
    const buf = new ImuBuffer(10)
    expect(buf.size()).toBe(0)
    buf.add(makeSample({ timestamp: 1 }))
    expect(buf.size()).toBe(1)
    buf.add(makeSample({ timestamp: 2 }))
    expect(buf.size()).toBe(2)
  })
})

// ===== 异常检测 =====
describe('detectImuAnomaly', () => {
  it('正常样本不报异常', () => {
    const sample = makeSample({ ax: 9.8, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(false)
    expect(result.issues).toEqual([])
  })

  it('加速度 NaN 检测为异常', () => {
    const sample = makeSample({ ax: NaN, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.length).toBeGreaterThan(0)
    expect(result.issues.some((i) => i.includes('ax'))).toBe(true)
  })

  it('陀螺仪 NaN 检测为异常', () => {
    const sample = makeSample({ gz: NaN, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('gz'))).toBe(true)
  })

  it('加速度超范围检测为异常', () => {
    // 阈值 100 m/s²，200 超出
    const sample = makeSample({ ax: 200, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('超范围'))).toBe(true)
  })

  it('陀螺仪超范围检测为异常', () => {
    // 阈值 2000 °/s，3000 超出
    const sample = makeSample({ gx: 3000, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('超范围'))).toBe(true)
  })

  it('Infinity 检测为异常', () => {
    const sample = makeSample({ ay: Infinity, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('ay'))).toBe(true)
  })

  it('时间戳无效检测为异常', () => {
    const sample = makeSample({ timestamp: 0 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('时间戳'))).toBe(true)
  })

  it('负时间戳检测为异常', () => {
    const sample = makeSample({ timestamp: -1 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.some((i) => i.includes('时间戳'))).toBe(true)
  })

  it('多个异常同时存在全部记录', () => {
    const sample = makeSample({ ax: NaN, gz: 5000, timestamp: 0 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(true)
    expect(result.issues.length).toBeGreaterThanOrEqual(3)
  })

  it('边界值不报异常', () => {
    // 恰好 100 不超过（使用 > 严格比较）
    const sample = makeSample({ ax: 100, gx: 2000, timestamp: 1000 })
    const result = detectImuAnomaly(sample)
    expect(result.isAnomaly).toBe(false)
  })
})

// ===== 低通滤波 =====
describe('lowPassFilter', () => {
  it('空数组返回空数组', () => {
    expect(lowPassFilter([], 0.5)).toEqual([])
  })

  it('单元素数组返回原值', () => {
    expect(lowPassFilter([5], 0.5)).toEqual([5])
  })

  it('alpha=0.5 正确滤波', () => {
    const result = lowPassFilter([1, 2, 3, 4, 5], 0.5)
    // y[0] = 1
    // y[1] = 0.5*2 + 0.5*1 = 1.5
    // y[2] = 0.5*3 + 0.5*1.5 = 2.25
    // y[3] = 0.5*4 + 0.5*2.25 = 3.125
    // y[4] = 0.5*5 + 0.5*3.125 = 4.0625
    expect(result).toHaveLength(5)
    expect(result[0]).toBeCloseTo(1, 5)
    expect(result[1]).toBeCloseTo(1.5, 5)
    expect(result[2]).toBeCloseTo(2.25, 5)
    expect(result[3]).toBeCloseTo(3.125, 5)
    expect(result[4]).toBeCloseTo(4.0625, 5)
  })

  it('alpha=1 时不滤波（返回原值）', () => {
    const input = [1, 2, 3, 4, 5]
    const result = lowPassFilter(input, 1)
    expect(result).toEqual(input)
  })

  it('alpha=0 时全部等于首值', () => {
    const result = lowPassFilter([1, 2, 3, 4, 5], 0)
    expect(result).toEqual([1, 1, 1, 1, 1])
  })

  it('平滑后波动小于原始波动', () => {
    const input = [0, 10, 0, 10, 0]
    const result = lowPassFilter(input, 0.3)
    const inputRange = Math.max(...input) - Math.min(...input)
    const resultRange = Math.max(...result) - Math.min(...result)
    expect(resultRange).toBeLessThan(inputRange)
  })
})

// ===== 移动平均 =====
describe('movingAverage', () => {
  it('空数组返回空数组', () => {
    expect(movingAverage([], 3)).toEqual([])
  })

  it('window=3 正确计算移动平均', () => {
    const result = movingAverage([1, 2, 3, 4, 5], 3)
    // i=0: avg(1) = 1
    // i=1: avg(1,2) = 1.5
    // i=2: avg(1,2,3) = 2
    // i=3: avg(2,3,4) = 3
    // i=4: avg(3,4,5) = 4
    expect(result).toHaveLength(5)
    expect(result[0]).toBeCloseTo(1, 5)
    expect(result[1]).toBeCloseTo(1.5, 5)
    expect(result[2]).toBeCloseTo(2, 5)
    expect(result[3]).toBeCloseTo(3, 5)
    expect(result[4]).toBeCloseTo(4, 5)
  })

  it('window=1 返回原值', () => {
    const input = [1, 2, 3]
    expect(movingAverage(input, 1)).toEqual(input)
  })

  it('window<=0 返回原值', () => {
    const input = [1, 2, 3]
    expect(movingAverage(input, 0)).toEqual(input)
    expect(movingAverage(input, -1)).toEqual(input)
  })

  it('window 大于数组长度时取全部平均', () => {
    const result = movingAverage([1, 2, 3], 10)
    // 每个位置都取可用部分：1, 1.5, 2
    expect(result[0]).toBeCloseTo(1, 5)
    expect(result[1]).toBeCloseTo(1.5, 5)
    expect(result[2]).toBeCloseTo(2, 5)
  })

  it('平滑后波动小于原始波动', () => {
    const input = [0, 10, 0, 10, 0]
    const result = movingAverage(input, 3)
    const inputRange = Math.max(...input) - Math.min(...input)
    const resultRange = Math.max(...result) - Math.min(...result)
    expect(resultRange).toBeLessThan(inputRange)
  })
})
