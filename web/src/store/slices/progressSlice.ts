import type { WeeklyData } from '../game-types'
import { getTodayStr, getInitialWeeklyData } from '../game-types'

export interface ProgressSlice {
  days: number
  streak: number
  weeklyData: WeeklyData | null
  maxStreak: number
  streakFreeze: number
  streakShield: boolean
  streakFreezePrompt: boolean
  streakProtectedToday: boolean
  lastFreezeRefillDate: string
  totalMonsterKills: number
  incrementStreak: () => void
  resetDailyIfNeeded: () => boolean
  useStreakFreeze: () => boolean
  buyStreakFreeze: () => boolean
  declineStreakFreeze: () => void
}

export const createProgressSlice = (set: any, get: any, _api?: any): ProgressSlice => ({
  days: 1,
  streak: 0,
  weeklyData: getInitialWeeklyData(),
  maxStreak: 0,
  streakFreeze: 1,
  streakShield: false,
  streakFreezePrompt: false,
  streakProtectedToday: false,
  lastFreezeRefillDate: '',
  totalMonsterKills: 0,

  incrementStreak: () =>
    set((state: any) => {
      const newStreak = state.streak + 1
      const shouldGrantShield = newStreak > 0 && newStreak % 7 === 0 && !state.streakShield
      return {
        streak: newStreak,
        maxStreak: Math.max(state.maxStreak, newStreak),
        streakShield: shouldGrantShield ? true : state.streakShield,
      }
    }),

  resetDailyIfNeeded: () => {
    const today = getTodayStr()
    const state = get()
    if (state.daily.date === today) return false

    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)
    const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`

    const isConsecutive = state.daily.date === yesterdayStr
    let newStreak = state.streak
    let newStreakShield = state.streakShield
    let streakFreezePrompt = false
    let streakProtectedToday = false

    if (!isConsecutive && state.streak > 0) {
      if (state.streakShield) {
        newStreakShield = false
        streakProtectedToday = true
        // streak stays
      } else if (state.streakFreeze > 0) {
        streakFreezePrompt = true
        // streak stays for now, user must decide
      } else {
        newStreak = 0
      }
    }

    // Monday freeze refill (day 1 = Monday)
    const todayDate = new Date(today)
    const todayDayOfWeek = todayDate.getDay()
    let newStreakFreeze = state.streakFreeze
    let newLastFreezeRefillDate = state.lastFreezeRefillDate

    if (todayDayOfWeek === 1 && state.lastFreezeRefillDate !== today) {
      newStreakFreeze = Math.min(state.streakFreeze + 1, 2)
      newLastFreezeRefillDate = today
    }

    // Weekly data update
    const yesterdayData = {
      date: state.daily.date,
      weight: state.user.weight,
      calories: state.daily.intake,
      exercise: state.daily.exerciseBurn,
    }
    let newWeekly: WeeklyData | null = state.weeklyData
    if (newWeekly) {
      newWeekly = {
        ...newWeekly,
        days: newWeekly.days.map((d: any) =>
          d.date === state.daily.date ? { ...d, ...yesterdayData } : d
        ),
      }
    }

    set({
      daily: { intake: 0, exerciseBurn: 0, damage: 0, date: today, pendingAttack: null, overeatCalories: 0, monsterDefeated: false },
      days: state.days + 1,
      weeklyData: newWeekly,
      streak: newStreak,
      streakShield: newStreakShield,
      streakFreezePrompt,
      streakProtectedToday,
      streakFreeze: newStreakFreeze,
      lastFreezeRefillDate: newLastFreezeRefillDate,
    })
    return true
  },

  useStreakFreeze: () => {
    const state = get()
    if (state.streakFreeze <= 0 || !state.streakFreezePrompt) return false
    set({
      streakFreeze: state.streakFreeze - 1,
      streakFreezePrompt: false,
      streakProtectedToday: true,
    })
    return true
  },

  buyStreakFreeze: () => {
    const state = get()
    if (state.streakFreeze >= 3) return false
    if (state.coins < 50) return false
    set({
      coins: state.coins - 50,
      streakFreeze: state.streakFreeze + 1,
    })
    return true
  },

  declineStreakFreeze: () => {
    set({
      streak: 0,
      streakFreezePrompt: false,
    })
  },
})
