import { describe, it, expect } from 'vitest'
import {
  analyzeWeightTrend,
  detectTrend,
  estimateDaysToTarget,
  calculateProgress,
  addWeightRecord,
} from '../weight'
import type { WeightRecord } from '../weight'

describe('detectTrend —— 趋势检测', () => {
  it('记录不足 2 条时返回 stable', () => {
    expect(detectTrend([])).toBe('stable')
    expect(detectTrend([{ date: '2024-01-01', weightKg: 70 }])).toBe('stable')
  })

  it('体重明显上升时返回 increasing', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 70 },
      { date: '2024-01-07', weightKg: 71 },
    ]
    expect(detectTrend(records)).toBe('increasing')
  })

  it('体重明显下降时返回 decreasing', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 71 },
      { date: '2024-01-07', weightKg: 70 },
    ]
    expect(detectTrend(records)).toBe('decreasing')
  })

  it('体重变化在阈值内返回 stable', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 70 },
      { date: '2024-01-07', weightKg: 70.3 },
    ]
    expect(detectTrend(records)).toBe('stable')
  })

  it('应使用最近 7 条记录进行趋势判断', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 75 },
      { date: '2024-01-02', weightKg: 74.5 },
      { date: '2024-01-03', weightKg: 74 },
      { date: '2024-01-04', weightKg: 73.5 },
      { date: '2024-01-05', weightKg: 73 },
      { date: '2024-01-06', weightKg: 72.5 },
      { date: '2024-01-07', weightKg: 72 },
      { date: '2024-01-08', weightKg: 71.5 },
      { date: '2024-01-09', weightKg: 71 },
    ]
    expect(detectTrend(records)).toBe('decreasing')
  })
})

describe('estimateDaysToTarget —— 目标天数估算', () => {
  it('已达到目标时返回 0 天', () => {
    expect(estimateDaysToTarget(70, 70, 0.5)).toBe(0)
    expect(estimateDaysToTarget(69, 70, 0.5)).toBe(0)
  })

  it('每周减 0.5kg，减 5kg 需要 70 天', () => {
    expect(estimateDaysToTarget(75, 70, 0.5)).toBe(70)
  })

  it('每周减 1kg，减 5kg 需要 35 天', () => {
    expect(estimateDaysToTarget(75, 70, 1)).toBe(35)
  })

  it('每周减 0.25kg，减 3kg 需要 84 天', () => {
    expect(estimateDaysToTarget(73, 70, 0.25)).toBe(84)
  })

  it('减重速率为 0 或负值时返回 Infinity', () => {
    expect(estimateDaysToTarget(75, 70, 0)).toBe(Infinity)
    expect(estimateDaysToTarget(75, 70, -0.5)).toBe(Infinity)
  })

  it('应向上取整天数', () => {
    expect(estimateDaysToTarget(75.2, 70, 0.5)).toBe(73)
  })
})

describe('calculateProgress —— 进度计算', () => {
  it('刚开始时进度为 0%', () => {
    expect(calculateProgress(80, 80, 70)).toBe(0)
  })

  it('达到目标时进度为 100%', () => {
    expect(calculateProgress(80, 70, 70)).toBe(100)
  })

  it('超过目标时进度仍为 100%', () => {
    expect(calculateProgress(80, 69, 70)).toBe(100)
    expect(calculateProgress(80, 65, 70)).toBe(100)
  })

  it('减了一半时进度为 50%', () => {
    expect(calculateProgress(80, 75, 70)).toBe(50)
  })

  it('目标体重等于或高于起始体重时进度为 100%', () => {
    expect(calculateProgress(70, 70, 70)).toBe(100)
    expect(calculateProgress(70, 70, 75)).toBe(100)
  })

  it('体重反而增加时进度为 0%', () => {
    expect(calculateProgress(80, 82, 70)).toBe(0)
  })

  it('应保留一位小数', () => {
    const progress = calculateProgress(80, 76.666, 70)
    const decimalPart = progress.toString().split('.')[1]
    expect(decimalPart ? decimalPart.length : 0).toBeLessThanOrEqual(1)
  })
})

describe('addWeightRecord —— 添加体重记录', () => {
  it('添加新记录时应按日期排序', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-05', weightKg: 72 },
      { date: '2024-01-01', weightKg: 75 },
    ]
    const newRecord: WeightRecord = { date: '2024-01-03', weightKg: 73 }
    const result = addWeightRecord(records, newRecord)
    expect(result.map((r) => r.date)).toEqual(['2024-01-01', '2024-01-03', '2024-01-05'])
  })

  it('同一天的记录应被替换（更新）', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 75 },
      { date: '2024-01-02', weightKg: 74 },
    ]
    const updatedRecord: WeightRecord = { date: '2024-01-01', weightKg: 74.5, note: '早上称重' }
    const result = addWeightRecord(records, updatedRecord)
    expect(result).toHaveLength(2)
    expect(result.find((r) => r.date === '2024-01-01')?.weightKg).toBe(74.5)
    expect(result.find((r) => r.date === '2024-01-01')?.note).toBe('早上称重')
  })

  it('不应修改原始数组（纯函数）', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 75 },
    ]
    const original = [...records]
    const newRecord: WeightRecord = { date: '2024-01-02', weightKg: 74 }
    addWeightRecord(records, newRecord)
    expect(records).toEqual(original)
  })

  it('返回的应是新数组（不修改原数组引用）', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 75 },
    ]
    const newRecord: WeightRecord = { date: '2024-01-02', weightKg: 74 }
    const result = addWeightRecord(records, newRecord)
    expect(result).not.toBe(records)
  })
})

describe('analyzeWeightTrend —— 综合趋势分析', () => {
  it('空记录时返回 null', () => {
    expect(analyzeWeightTrend([], 70)).toBeNull()
  })

  it('单条记录时返回有效分析', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 80 },
    ]
    const result = analyzeWeightTrend(records, 70)
    expect(result).not.toBeNull()
    expect(result?.currentWeight).toBe(80)
    expect(result?.startWeight).toBe(80)
    expect(result?.totalChange).toBe(0)
    expect(result?.progressPercent).toBe(0)
    expect(result?.trend).toBe('stable')
  })

  it('多条记录时应正确计算各项指标', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 80 },
      { date: '2024-01-08', weightKg: 79 },
      { date: '2024-01-15', weightKg: 78 },
    ]
    const result = analyzeWeightTrend(records, 75)
    expect(result).not.toBeNull()
    expect(result?.currentWeight).toBe(78)
    expect(result?.startWeight).toBe(80)
    expect(result?.totalChange).toBe(-2)
    expect(result?.trend).toBe('decreasing')
    expect(result?.progressPercent).toBeGreaterThan(0)
    expect(result?.progressPercent).toBeLessThan(100)
  })

  it('返回值应包含所有必要字段', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 80 },
      { date: '2024-01-07', weightKg: 79 },
    ]
    const result = analyzeWeightTrend(records, 70)
    expect(result).toHaveProperty('currentWeight')
    expect(result).toHaveProperty('startWeight')
    expect(result).toHaveProperty('targetWeight')
    expect(result).toHaveProperty('totalChange')
    expect(result).toHaveProperty('weeklyChange')
    expect(result).toHaveProperty('daysToTarget')
    expect(result).toHaveProperty('progressPercent')
    expect(result).toHaveProperty('trend')
  })

  it('targetWeight 应与输入一致', () => {
    const records: WeightRecord[] = [
      { date: '2024-01-01', weightKg: 80 },
    ]
    const result = analyzeWeightTrend(records, 65)
    expect(result?.targetWeight).toBe(65)
  })
})
