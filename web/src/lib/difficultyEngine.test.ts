import { describe, it, expect } from 'vitest'
import { analyzeUserPerformance, getLast3DaysCompletionRate } from './difficultyEngine'
import type { WeeklyData, Difficulty } from '../store/game-types'

function makeWeeklyData(days: { date: string; exercise?: number }[]): WeeklyData {
  return {
    weekStart: days[0]?.date ?? '2024-01-01',
    days: days.map(d => ({ date: d.date, exercise: d.exercise })),
  }
}

describe('difficultyEngine.ts', () => {
  describe('getLast3DaysCompletionRate', () => {
    it('should return 0.5 for null data', () => {
      expect(getLast3DaysCompletionRate(null)).toBe(0.5)
    })

    it('should return 0.5 for empty days', () => {
      expect(getLast3DaysCompletionRate(makeWeeklyData([]))).toBe(0.5)
    })

    it('should return 0 when days exist but no exercises recorded', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03' },
        { date: '2024-01-02' },
        { date: '2024-01-01' },
      ])
      expect(getLast3DaysCompletionRate(data)).toBe(0)
    })

    it('should calculate 100% when all 3 days have exercise', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 45 },
        { date: '2024-01-01', exercise: 20 },
      ])
      expect(getLast3DaysCompletionRate(data)).toBe(1)
    })

    it('should calculate 0% when no days have exercise', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 0 },
        { date: '2024-01-02', exercise: 0 },
        { date: '2024-01-01', exercise: 0 },
      ])
      expect(getLast3DaysCompletionRate(data)).toBe(0)
    })

    it('should calculate 2/3 for mixed days', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 0 },
        { date: '2024-01-01', exercise: 20 },
      ])
      expect(getLast3DaysCompletionRate(data)).toBeCloseTo(2 / 3, 5)
    })

    it('should only consider the last 3 days', () => {
      const data = makeWeeklyData([
        { date: '2024-01-05', exercise: 30 },
        { date: '2024-01-04', exercise: 0 },
        { date: '2024-01-03', exercise: 0 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      expect(getLast3DaysCompletionRate(data)).toBeCloseTo(1 / 3, 5)
    })

    it('should sort days by date descending', () => {
      const data = makeWeeklyData([
        { date: '2024-01-01', exercise: 30 },
        { date: '2024-01-03', exercise: 0 },
        { date: '2024-01-02', exercise: 0 },
      ])
      expect(getLast3DaysCompletionRate(data)).toBeCloseTo(1 / 3, 5)
    })

    it('should filter out days without date', () => {
      const data: WeeklyData = {
        weekStart: '2024-01-01',
        days: [
          { date: '2024-01-03', exercise: 30 },
          { date: '', exercise: 45 },
          { date: '2024-01-01', exercise: 20 },
        ],
      }
      expect(getLast3DaysCompletionRate(data)).toBe(1)
    })
  })

  describe('analyzeUserPerformance', () => {
    it('should return default values with no data', () => {
      const result = analyzeUserPerformance(null, 0, 'normal', 24)
      expect(result.monsterHpMultiplier).toBe(1.0)
      expect(result.questTargetAdjustment).toBe(1.0)
      expect(result.suggestedDifficulty).toBe('normal')
    })

    it('should suggest easy when completion rate < 0.5', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 0 },
        { date: '2024-01-02', exercise: 0 },
        { date: '2024-01-01', exercise: 0 },
      ])
      const result = analyzeUserPerformance(data, 0, 'normal', 24)
      expect(result.suggestedDifficulty).toBe('easy')
      expect(result.monsterHpMultiplier).toBe(0.7)
      expect(result.questTargetAdjustment).toBe(0.7)
    })

    it('should suggest hard when streak >= 14', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 14, 'normal', 24)
      expect(result.suggestedDifficulty).toBe('hard')
      expect(result.monsterHpMultiplier).toBe(1.5)
      expect(result.questTargetAdjustment).toBe(1.2)
    })

    it('should suggest upgrade when completion rate > 0.8 and streak >= 5', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 5, 'normal', 24)
      expect(result.monsterHpMultiplier).toBe(1.2)
      expect(result.questTargetAdjustment).toBe(1.1)
    })

    it('should force easy when BMI > 28 regardless of performance', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 14, 'hard', 30)
      expect(result.suggestedDifficulty).toBe('easy')
    })

    it('should suggest hard when BMI < 22 and completion rate > 0.8', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 3, 'normal', 20)
      expect(result.suggestedDifficulty).toBe('hard')
    })

    it('should clamp monsterHpMultiplier between 0.5 and 1.5', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 100, 'normal', 20)
      expect(result.monsterHpMultiplier).toBeLessThanOrEqual(1.5)
      expect(result.monsterHpMultiplier).toBeGreaterThanOrEqual(0.5)
    })

    it('should clamp questTargetAdjustment between 0.7 and 1.3', () => {
      const data = makeWeeklyData([
        { date: '2024-01-03', exercise: 30 },
        { date: '2024-01-02', exercise: 30 },
        { date: '2024-01-01', exercise: 30 },
      ])
      const result = analyzeUserPerformance(data, 100, 'normal', 20)
      expect(result.questTargetAdjustment).toBeLessThanOrEqual(1.3)
      expect(result.questTargetAdjustment).toBeGreaterThanOrEqual(0.7)
    })

    it('should include a message string', () => {
      const result = analyzeUserPerformance(null, 0, 'normal', 24)
      expect(typeof result.message).toBe('string')
      expect(result.message.length).toBeGreaterThan(0)
    })
  })
})
