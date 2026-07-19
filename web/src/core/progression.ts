import { XP_BASE, LEVEL_TITLES } from '../store/game-constants'

/**
 * 升到下一级所需的经验值。
 * 公式：`XP_BASE * 1.15^(level-1)`，向下取整。
 * level <= 0 时按 1 处理（pow 指数为非正数），仍返回正整数。
 */
export function getXpToNextLevel(level: number): number {
  const safeLevel = Number.isFinite(level) ? level : 1
  return Math.floor(XP_BASE * Math.pow(1.15, safeLevel - 1))
}

/**
 * 根据等级返回称号。
 * 等级 <= 0 返回首个称号；等级超出称号表范围返回最后一个称号。
 */
export function getLevelTitle(level: number): string {
  if (level <= 0) return LEVEL_TITLES[0]
  if (level > LEVEL_TITLES.length) return LEVEL_TITLES[LEVEL_TITLES.length - 1]
  return LEVEL_TITLES[level - 1]
}

/**
 * 增加经验值并处理连续升级。
 *
 * @param currentXp 当前等级内的经验值
 * @param currentLevel 当前等级（< 1 时按 1 处理）
 * @param amount 增加的经验值（可为负，但 XP 不会降至 0 以下）
 * @returns 新的经验值、等级、本次升级级数
 *
 * 注意：本函数不处理降级；XP 下限为 0。升级阈值 <= 0 时终止以防死循环。
 */
export function addXp(
  currentXp: number,
  currentLevel: number,
  amount: number,
): { xp: number; level: number; levelsGained: number } {
  let xp = Math.max(0, currentXp + amount)
  let level = Math.max(1, Math.floor(currentLevel))
  let levelsGained = 0

  let guard = 0
  while (guard < 1000) {
    const need = getXpToNextLevel(level)
    if (need <= 0 || xp < need) break
    xp -= need
    level += 1
    levelsGained += 1
    guard += 1
  }

  return { xp, level, levelsGained }
}

/**
 * 计算 BMI。
 * @param weight 体重 (kg)
 * @param height 身高 (cm)
 * @returns BMI 值（保留 1 位小数）；身高 <= 0 时返回 0
 */
export function calculateBmi(weight: number, height: number): number {
  if (height <= 0) return 0
  const h = height / 100
  return Number((weight / (h * h)).toFixed(1))
}
