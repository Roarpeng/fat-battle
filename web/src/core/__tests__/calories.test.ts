import { describe, it, expect } from 'vitest'
import {
  calculateBMR,
  calculateTDEE,
  calculateTargetCalories,
  ACTIVITY_FACTORS,
} from '../calories'
import type { ActivityLevel } from '../calories'

describe('calculateBMR —— Mifflin-St Jeor 公式', () => {
  it('男性 BMR 计算正确', () => {
    const bmr = calculateBMR('male', 70, 175, 30)
    const expected = Math.round(10 * 70 + 6.25 * 175 - 5 * 30 + 5)
    expect(bmr).toBe(expected)
    expect(bmr).toBe(1649)
  })

  it('女性 BMR 计算正确', () => {
    const bmr = calculateBMR('female', 60, 165, 25)
    const expected = Math.round(10 * 60 + 6.25 * 165 - 5 * 25 - 161)
    expect(bmr).toBe(expected)
    expect(bmr).toBe(1345)
  })

  it('应为整数（四舍五入）', () => {
    const bmr = calculateBMR('male', 70.5, 175.3, 30)
    expect(Number.isInteger(bmr)).toBe(true)
  })

  it('负值输入应归一化为 0', () => {
    const bmr = calculateBMR('male', -10, -170, -5)
    expect(bmr).toBe(5)
  })

  it('0 输入应返回合理值', () => {
    const maleBmr = calculateBMR('male', 0, 0, 0)
    const femaleBmr = calculateBMR('female', 0, 0, 0)
    expect(maleBmr).toBe(5)
    expect(femaleBmr).toBe(-161)
  })
})

describe('calculateTDEE —— 每日总消耗', () => {
  const baseBmr = 1500

  it('sedentary 活动水平（×1.2）', () => {
    expect(calculateTDEE(baseBmr, 'sedentary')).toBe(Math.round(baseBmr * 1.2))
  })

  it('light 活动水平（×1.375）', () => {
    expect(calculateTDEE(baseBmr, 'light')).toBe(Math.round(baseBmr * 1.375))
  })

  it('moderate 活动水平（×1.55）', () => {
    expect(calculateTDEE(baseBmr, 'moderate')).toBe(Math.round(baseBmr * 1.55))
  })

  it('active 活动水平（×1.725）', () => {
    expect(calculateTDEE(baseBmr, 'active')).toBe(Math.round(baseBmr * 1.725))
  })

  it('veryActive 活动水平（×1.9）', () => {
    expect(calculateTDEE(baseBmr, 'veryActive')).toBe(Math.round(baseBmr * 1.9))
  })

  it('所有活动水平因子应正确定义', () => {
    const levels: ActivityLevel[] = ['sedentary', 'light', 'moderate', 'active', 'veryActive']
    levels.forEach((level) => {
      expect(ACTIVITY_FACTORS[level]).toBeGreaterThan(0)
    })
  })

  it('负值 BMR 应归一化为 0', () => {
    expect(calculateTDEE(-100, 'moderate')).toBe(0)
  })

  it('应为整数（四舍五入）', () => {
    const tdee = calculateTDEE(1234, 'light')
    expect(Number.isInteger(tdee)).toBe(true)
  })
})

describe('calculateTargetCalories —— 目标卡路里计算', () => {
  const maleParams = {
    gender: 'male' as const,
    weightKg: 80,
    heightCm: 180,
    age: 30,
    activityLevel: 'moderate' as const,
  }

  const femaleParams = {
    gender: 'female' as const,
    weightKg: 65,
    heightCm: 165,
    age: 28,
    activityLevel: 'light' as const,
  }

  describe('默认目标（loss）', () => {
    it('男性默认目标每日缺口 500 kcal，每周减 0.5kg', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel
      )
      expect(result.dailyDeficit).toBe(500)
      expect(result.estimatedWeeklyLoss).toBe(0.5)
      expect(result.targetCalories).toBe(result.tdee - 500)
    })

    it('女性默认目标每日缺口 500 kcal，每周减 0.5kg', () => {
      const result = calculateTargetCalories(
        femaleParams.gender,
        femaleParams.weightKg,
        femaleParams.heightCm,
        femaleParams.age,
        femaleParams.activityLevel
      )
      expect(result.dailyDeficit).toBe(500)
      expect(result.estimatedWeeklyLoss).toBe(0.5)
      expect(result.targetCalories).toBe(result.tdee - 500)
    })
  })

  describe('mildLoss 目标', () => {
    it('每日缺口 250 kcal，每周减 0.25kg', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel,
        'mildLoss'
      )
      expect(result.dailyDeficit).toBe(250)
      expect(result.estimatedWeeklyLoss).toBe(0.25)
      expect(result.targetCalories).toBe(result.tdee - 250)
    })
  })

  describe('extremeLoss 目标', () => {
    it('每日缺口 1000 kcal，每周减 1kg', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel,
        'extremeLoss'
      )
      expect(result.dailyDeficit).toBe(1000)
      expect(result.estimatedWeeklyLoss).toBe(1)
      expect(result.targetCalories).toBe(result.tdee - 1000)
    })
  })

  describe('安全下限', () => {
    it('男性目标卡路里不低于 1500 kcal', () => {
      const result = calculateTargetCalories('male', 50, 160, 50, 'sedentary', 'extremeLoss')
      expect(result.targetCalories).toBeGreaterThanOrEqual(1500)
    })

    it('女性目标卡路里不低于 1200 kcal', () => {
      const result = calculateTargetCalories('female', 45, 150, 50, 'sedentary', 'extremeLoss')
      expect(result.targetCalories).toBeGreaterThanOrEqual(1200)
    })

    it('触达安全下限时实际缺口应调整', () => {
      const result = calculateTargetCalories('female', 55, 160, 30, 'sedentary', 'extremeLoss')
      const expectedDeficit = Math.max(0, result.tdee - 1200)
      expect(result.dailyDeficit).toBe(expectedDeficit)
      expect(result.dailyDeficit).toBeLessThan(1000)
    })

    it('触达安全下限时每周减重应按比例降低', () => {
      const result = calculateTargetCalories('female', 45, 150, 50, 'sedentary', 'extremeLoss')
      const expectedWeeklyLoss = Math.round(((result.dailyDeficit * 7) / 7700) * 100) / 100
      expect(result.estimatedWeeklyLoss).toBe(expectedWeeklyLoss)
    })
  })

  describe('返回值结构', () => {
    it('应包含所有必要字段', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel
      )
      expect(result).toHaveProperty('bmr')
      expect(result).toHaveProperty('tdee')
      expect(result).toHaveProperty('targetCalories')
      expect(result).toHaveProperty('dailyDeficit')
      expect(result).toHaveProperty('estimatedWeeklyLoss')
    })

    it('BMR 应与 calculateBMR 结果一致', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel
      )
      const expectedBmr = calculateBMR(maleParams.gender, maleParams.weightKg, maleParams.heightCm, maleParams.age)
      expect(result.bmr).toBe(expectedBmr)
    })

    it('TDEE 应与 calculateTDEE 结果一致', () => {
      const result = calculateTargetCalories(
        maleParams.gender,
        maleParams.weightKg,
        maleParams.heightCm,
        maleParams.age,
        maleParams.activityLevel
      )
      const expectedBmr = calculateBMR(maleParams.gender, maleParams.weightKg, maleParams.heightCm, maleParams.age)
      const expectedTdee = calculateTDEE(expectedBmr, maleParams.activityLevel)
      expect(result.tdee).toBe(expectedTdee)
    })
  })
})
