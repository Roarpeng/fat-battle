import type { Gender } from '../store/game-types'

export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'veryActive'

export const ACTIVITY_FACTORS: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  veryActive: 1.9,
}

const SAFE_MIN_CALORIES: Record<Gender, number> = {
  male: 1500,
  female: 1200,
}

const GOAL_CONFIGS: Record<string, { dailyDeficit: number; weeklyLoss: number }> = {
  mildLoss: { dailyDeficit: 250, weeklyLoss: 0.25 },
  loss: { dailyDeficit: 500, weeklyLoss: 0.5 },
  extremeLoss: { dailyDeficit: 1000, weeklyLoss: 1 },
}

export function calculateBMR(
  gender: Gender,
  weightKg: number,
  heightCm: number,
  age: number
): number {
  const weight = Math.max(0, weightKg)
  const height = Math.max(0, heightCm)
  const ageYears = Math.max(0, age)

  if (gender === 'male') {
    return Math.round(10 * weight + 6.25 * height - 5 * ageYears + 5)
  }
  return Math.round(10 * weight + 6.25 * height - 5 * ageYears - 161)
}

export function calculateTDEE(bmr: number, activityLevel: ActivityLevel): number {
  const baseBmr = Math.max(0, bmr)
  const factor = ACTIVITY_FACTORS[activityLevel]
  return Math.round(baseBmr * factor)
}

export function calculateTargetCalories(
  gender: Gender,
  weightKg: number,
  heightCm: number,
  age: number,
  activityLevel: ActivityLevel,
  goal: 'mildLoss' | 'loss' | 'extremeLoss' = 'loss'
): {
  bmr: number
  tdee: number
  targetCalories: number
  dailyDeficit: number
  estimatedWeeklyLoss: number
} {
  const bmr = calculateBMR(gender, weightKg, heightCm, age)
  const tdee = calculateTDEE(bmr, activityLevel)
  const goalConfig = GOAL_CONFIGS[goal]
  const safeMin = SAFE_MIN_CALORIES[gender]

  let targetCalories = tdee - goalConfig.dailyDeficit
  let actualDeficit = goalConfig.dailyDeficit
  let actualWeeklyLoss = goalConfig.weeklyLoss

  if (targetCalories < safeMin) {
    targetCalories = safeMin
    actualDeficit = tdee - safeMin
    actualWeeklyLoss = (actualDeficit * 7) / 7700
  }

  return {
    bmr,
    tdee,
    targetCalories: Math.max(0, targetCalories),
    dailyDeficit: Math.max(0, actualDeficit),
    estimatedWeeklyLoss: Math.max(0, Math.round(actualWeeklyLoss * 100) / 100),
  }
}
