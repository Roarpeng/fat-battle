import type { Gender } from '../store/game-types'

export type ActivityLevel = 'sedentary' | 'light' | 'moderate' | 'active' | 'veryActive'

export const ACTIVITY_FACTORS: Record<ActivityLevel, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  veryActive: 1.9,
}

/** 性别 → 最低安全卡路里摄入。未识别性别回退 1500，与 Flutter `defaultCalorieFloor` 一致。 */
const SAFE_MIN_CALORIES: Record<Gender, number> = {
  male: 1500,
  female: 1200,
}

export const DEFAULT_CALORIE_FLOOR = 1500
export const MAX_DAILY_DEFICIT_KCAL = 750
export const DEFAULT_DAILY_DEFICIT_KCAL = 500
export const MILD_DAILY_DEFICIT_KCAL = 250

const GOAL_CONFIGS: Record<string, { dailyDeficit: number; weeklyLoss: number }> = {
  mildLoss: { dailyDeficit: MILD_DAILY_DEFICIT_KCAL, weeklyLoss: 0.25 },
  loss: { dailyDeficit: DEFAULT_DAILY_DEFICIT_KCAL, weeklyLoss: 0.5 },
  extremeLoss: { dailyDeficit: MAX_DAILY_DEFICIT_KCAL, weeklyLoss: 0.75 },
}

export function safeMinCalories(gender: Gender): number {
  return SAFE_MIN_CALORIES[gender] ?? DEFAULT_CALORIE_FLOOR
}

/** 热量下限：max(1200 女 / 1500 男, BMR)，永不低于该值生成目标。 */
export function calorieFloorFor(gender: Gender, bmr: number): number {
  return Math.max(safeMinCalories(gender), Math.max(0, bmr))
}

/** 将计划赤字限制在 [0, 750]。 */
export function capDailyDeficit(deficit: number): number {
  return Math.max(0, Math.min(MAX_DAILY_DEFICIT_KCAL, Math.round(deficit)))
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

/**
 * 目标卡路里：与 Flutter `lib/core/calories.dart` 对齐。
 *
 * - 日赤字上限 750 kcal（extremeLoss），默认 500，温和 250。
 * - 目标 = max(热量下限, TDEE − 赤字)；热量下限 = max(性别下限, BMR)。
 * - 永不生成低于下限的目标。
 */
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
  calorieFloor: number
} {
  const bmr = calculateBMR(gender, weightKg, heightCm, age)
  const tdee = calculateTDEE(bmr, activityLevel)
  const goalConfig = GOAL_CONFIGS[goal]
  const floor = calorieFloorFor(gender, bmr)

  const desiredDeficit = capDailyDeficit(goalConfig.dailyDeficit)
  let targetCalories = tdee - desiredDeficit

  if (targetCalories < floor) {
    targetCalories = floor
  }

  let actualDeficit = Math.max(0, tdee - targetCalories)
  actualDeficit = capDailyDeficit(actualDeficit)
  targetCalories = Math.max(floor, tdee - actualDeficit)

  const actualWeeklyLoss = (actualDeficit * 7) / 7700

  return {
    bmr,
    tdee,
    targetCalories: Math.max(floor, targetCalories),
    dailyDeficit: Math.max(0, actualDeficit),
    estimatedWeeklyLoss: Math.max(0, Math.round(actualWeeklyLoss * 100) / 100),
    calorieFloor: floor,
  }
}
