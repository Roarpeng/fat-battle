/**
 * 连续打卡相关纯判定函数（整合自 `store/slices/progressSlice`）。
 *
 * 这些函数从 progressSlice 的副作用方法中提取核心判定逻辑，
 * 不依赖 store 状态，便于双端复用。
 */

/**
 * 判断两个日期字符串（YYYY-MM-DD）是否连续（prevDate 是 today 的前一天）。
 * 跨月、跨年边界正确处理。
 */
export function isConsecutiveDay(prevDate: string, today: string): boolean {
  if (!prevDate || !today) return false
  const todayDate = new Date(today)
  if (isNaN(todayDate.getTime())) return false
  const yesterday = new Date(todayDate)
  yesterday.setDate(yesterday.getDate() - 1)
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`
  return prevDate === yesterdayStr
}

/**
 * 判断是否应在 streak 增加后授予 streak shield。
 * 规则（提取自 `incrementStreak`）：新 streak > 0 且为 7 的倍数，且当前没有 shield。
 */
export function shouldGrantStreakShield(newStreak: number, hasShield: boolean): boolean {
  return newStreak > 0 && newStreak % 7 === 0 && !hasShield
}

/**
 * 判断是否可以使用 streak freeze。
 * 规则（提取自 `useStreakFreeze`）：freeze 数量 > 0 且 freeze 提示处于激活状态。
 */
export function canUseStreakFreeze(streakFreezeCount: number, isPromptActive: boolean): boolean {
  return streakFreezeCount > 0 && isPromptActive
}

/**
 * 判断是否可以购买 streak freeze。
 * 规则（提取自 `buyStreakFreeze`）：当前 freeze < 3 且金币 >= 50。
 */
export function canBuyStreakFreeze(streakFreezeCount: number, coins: number): boolean {
  return streakFreezeCount < 3 && coins >= 50
}

/**
 * 判断是否应在今日补充 streak freeze。
 * 规则（提取自 `resetDailyIfNeeded`）：今天是周一（getDay() === 1）且今日尚未补充过。
 */
export function shouldRefillStreakFreeze(
  todayDayOfWeek: number,
  lastFreezeRefillDate: string,
  today: string,
): boolean {
  return todayDayOfWeek === 1 && lastFreezeRefillDate !== today
}

/**
 * 计算 freeze 补充后的数量。
 * 规则：当前数量 + 1，上限为 maxCount（默认 2）。
 */
export function refillStreakFreeze(currentCount: number, maxCount: number = 2): number {
  return Math.min(currentCount + 1, maxCount)
}

/**
 * 判断 streak 是否应被重置为 0。
 *
 * 规则（提取自 `resetDailyIfNeeded`）：日期不连续，且 streak > 0，
 * 且无 shield 保护，且无可用 freeze。
 *
 * 注意：当 freeze 可用时，streak 不立即重置（等待用户决定是否使用 freeze）。
 */
export function shouldResetStreak(
  isConsecutive: boolean,
  currentStreak: number,
  hasShield: boolean,
  streakFreezeCount: number,
): boolean {
  if (isConsecutive || currentStreak <= 0) return false
  if (hasShield) return false
  if (streakFreezeCount > 0) return false
  return true
}
