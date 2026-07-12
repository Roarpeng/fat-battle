import type { WeeklyData, Difficulty } from '../store/game-types'

export interface DifficultyAdvice {
  monsterHpMultiplier: number
  questTargetAdjustment: number
  suggestedDifficulty: 'easy' | 'normal' | 'hard'
  message: string
}

export function getLast3DaysCompletionRate(weeklyData: WeeklyData | null): number {
  if (!weeklyData || !weeklyData.days || weeklyData.days.length === 0) {
    return 0.5
  }

  const sortedDays = [...weeklyData.days]
    .filter((d) => d.date)
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())

  const last3 = sortedDays.slice(0, 3)
  if (last3.length === 0) return 0.5

  let completed = 0
  for (const day of last3) {
    if (day.exercise && day.exercise > 0) {
      completed++
    }
  }

  return completed / last3.length
}

/**
 * 分析用户最近运动数据，返回难度调整建议
 * 难度调整是渐进的，避免一天之内剧烈变化
 */
export function analyzeUserPerformance(
  weeklyData: WeeklyData | null,
  currentStreak: number,
  currentDifficulty: Difficulty,
  bmi: number
): DifficultyAdvice {
  const completionRate = getLast3DaysCompletionRate(weeklyData)

  let monsterHpMultiplier = 1.0
  let questTargetAdjustment = 1.0
  let suggestedDifficulty: 'easy' | 'normal' | 'hard' = currentDifficulty
  let message = '主人~ 今天也要加油哦！我会一直陪着你的！'

  // 连续两周最高优先级
  if (currentStreak >= 14) {
    monsterHpMultiplier = 1.5
    questTargetAdjustment = 1.2
    suggestedDifficulty = 'hard'
    message = '连续两周了！你已经是健身大师啦！太厉害了主人！'
  } else if (completionRate > 0.8 && currentStreak >= 5) {
    monsterHpMultiplier = 1.2
    questTargetAdjustment = 1.1
    suggestedDifficulty = currentStreak >= 7 ? 'hard' : 'normal'
    message = '主人好厉害！要不要挑战更高难度？我会为你加油的！'
  } else if (completionRate < 0.5) {
    monsterHpMultiplier = 0.7
    questTargetAdjustment = 0.7
    suggestedDifficulty = 'easy'
    message = '主人~ 最近有点累吗？我帮你调低难度啦，休息好再继续哦！'
  }

  // BMI 相关建议
  if (bmi > 28) {
    if (suggestedDifficulty !== 'easy') {
      suggestedDifficulty = 'easy'
      if (completionRate >= 0.5) {
        message = '主人~ 健康第一，我们先从轻松模式开始吧！慢慢来，你是最棒的！'
      }
    }
  } else if (bmi < 22 && completionRate > 0.8) {
    if (suggestedDifficulty !== 'hard') {
      suggestedDifficulty = 'hard'
      message = '主人身材好棒！来试试困难模式吧，你绝对可以的！'
    }
  }

  // 渐进保护：确保倍率在安全范围内，避免剧烈变化
  monsterHpMultiplier = Math.max(0.5, Math.min(1.5, monsterHpMultiplier))
  questTargetAdjustment = Math.max(0.7, Math.min(1.3, questTargetAdjustment))

  return {
    monsterHpMultiplier,
    questTargetAdjustment,
    suggestedDifficulty,
    message,
  }
}
