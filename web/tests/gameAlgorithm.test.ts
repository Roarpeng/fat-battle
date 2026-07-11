import { describe, it, expect } from 'vitest'
import {
  calculateBMI,
  getBMICategory,
  calculateBMR,
  calculateMonsterHp,
  calculateExerciseDamage,
} from '../src/lib/gameAlgorithm'

describe('calculateBMI', () => {
  it('returns 0 when height is 0', () => {
    expect(calculateBMI(70, 0)).toBe(0)
  })

  it('returns 0 when weight is negative', () => {
    expect(calculateBMI(-10, 170)).toBe(0)
  })

  it('returns 0 when height is negative', () => {
    expect(calculateBMI(70, -170)).toBe(0)
  })

  it('calculates normal BMI correctly', () => {
    // 70kg, 175cm -> 70 / (1.75^2) = 22.857... -> 22.9
    expect(calculateBMI(70, 175)).toBe(22.9)
  })
})

describe('getBMICategory', () => {
  it('classifies underweight correctly', () => {
    const result = getBMICategory(17)
    expect(result.category).toBe('underweight')
    expect(result.categoryName).toBe('偏瘦')
  })

  it('classifies normal correctly', () => {
    const result = getBMICategory(21)
    expect(result.category).toBe('normal')
    expect(result.categoryName).toBe('正常')
  })

  it('classifies overweight correctly', () => {
    const result = getBMICategory(25)
    expect(result.category).toBe('overweight')
    expect(result.categoryName).toBe('超重')
  })

  it('classifies obese_class1 correctly', () => {
    const result = getBMICategory(29)
    expect(result.category).toBe('obese_class1')
    expect(result.categoryName).toBe('轻度肥胖')
  })

  it('classifies obese_class2 correctly', () => {
    const result = getBMICategory(33)
    expect(result.category).toBe('obese_class2')
    expect(result.categoryName).toBe('中度肥胖')
  })

  it('classifies obese_class3 correctly', () => {
    const result = getBMICategory(40)
    expect(result.category).toBe('obese_class3')
    expect(result.categoryName).toBe('重度肥胖')
  })
})

describe('calculateBMR', () => {
  it('calculates male BMR correctly', () => {
    const user = { weight: 70, height: 175, age: 25, gender: 'male' as const }
    // 88.362 + 13.397*70 + 4.799*175 - 5.677*25
    // = 88.362 + 937.79 + 839.825 - 141.925 = 1724.052
    expect(calculateBMR(user)).toBe(1724)
  })

  it('calculates female BMR correctly', () => {
    const user = { weight: 60, height: 165, age: 30, gender: 'female' as const }
    // 447.593 + 9.247*60 + 3.098*165 - 4.33*30
    // = 447.593 + 554.82 + 511.17 - 129.9 = 1383.683
    expect(calculateBMR(user)).toBe(1384)
  })
})

describe('calculateMonsterHp', () => {
  it('calculates base HP on day 1 with normal BMI', () => {
    expect(calculateMonsterHp(100, 1, 22)).toBe(100)
  })

  it('applies day multiplier correctly', () => {
    // day 5: multiplier = 1 + 4*0.15 = 1.6
    expect(calculateMonsterHp(100, 5, 22)).toBe(160)
  })

  it('applies BMI multiplier correctly for high BMI', () => {
    // BMI 30: multiplier = min(1.5, 30/22) = 1.3636...
    // 100 * 1 * 1.3636... = 136.36... -> 136
    expect(calculateMonsterHp(100, 1, 30)).toBe(136)
  })

  it('caps BMI multiplier at minimum 0.8', () => {
    // BMI 15: multiplier = max(0.8, 15/22) = 0.8
    expect(calculateMonsterHp(100, 1, 15)).toBe(80)
  })

  it('caps BMI multiplier at maximum 1.5', () => {
    // BMI 40: multiplier = min(1.5, 40/22) = 1.5
    expect(calculateMonsterHp(100, 1, 40)).toBe(150)
  })
})

describe('calculateExerciseDamage', () => {
  it('calculates damage with base values', () => {
    const exercise = { damagePerMinute: 10 } as any
    // baseDamage = 10 * 5 = 50, attackBonus = 1 + 50/100 = 1.5
    // 50 * 1.5 = 75
    expect(calculateExerciseDamage(exercise, 5, 50)).toBe(75)
  })

  it('calculates damage with zero attack', () => {
    const exercise = { damagePerMinute: 8 } as any
    // baseDamage = 8 * 10 = 80, attackBonus = 1 + 0 = 1
    expect(calculateExerciseDamage(exercise, 10, 0)).toBe(80)
  })
})
