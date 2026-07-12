import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

// ========== localStorage 容量保护包装器 ==========
const MAX_STORAGE_SIZE = 4.5 * 1024 * 1024 // 4.5MB

function truncateStateString(value: string): string {
  try {
    const truncateArr = (arr: unknown[], limit: number) =>
      Array.isArray(arr) ? arr.slice(-limit) : arr

    for (const limit of [30, 15, 5, 0]) {
      const draft = JSON.parse(value)
      draft.dietRecords = truncateArr(draft.dietRecords, limit)
      draft.exerciseRecords = truncateArr(draft.exerciseRecords, limit)
      const result = JSON.stringify(draft)
      if (result.length <= MAX_STORAGE_SIZE) {
        return result
      }
    }
    return value
  } catch {
    return value
  }
}

const customLocalStorage = {
  getItem: (key: string): string | null => {
    try {
      return localStorage.getItem(key)
    } catch (e) {
      console.warn(`[storage] getItem("${key}") failed:`, e)
      return null
    }
  },
  setItem: (key: string, value: string): void => {
    let finalValue = value
    if (value.length > MAX_STORAGE_SIZE) {
      console.error('存储空间不足，建议清理历史数据')
      finalValue = truncateStateString(value)
    }
    try {
      localStorage.setItem(key, finalValue)
    } catch (e) {
      const isQuotaError =
        e instanceof DOMException &&
        (e.name === 'QuotaExceededError' || e.code === 22)
      if (isQuotaError) {
        console.error('[storage] QuotaExceededError: 写入被拒绝，防止覆盖已有数据')
        return
      }
      console.error(`[storage] setItem("${key}") failed:`, e)
    }
  },
  removeItem: (key: string): void => {
    try {
      localStorage.removeItem(key)
    } catch (e) {
      console.warn(`[storage] removeItem("${key}") failed:`, e)
    }
  },
}

// ========== 类型与常量 ==========
export type {
  Difficulty,
  Gender,
  UserInfo,
  MonsterState,
  PendingAttack,
  DailyStatus,
  DietRecord,
  ExerciseRecord,
  WeeklyData,
  PlayerLevel,
  AchievementDef,
  AchievementProgress,
  DailyQuest,
  Skill,
  Item,
} from './game-types'

export {
  calculateBmi,
  getTodayStr,
  generateMonster,
  updateMonsterPhase,
  getXpToNextLevel,
  getLevelTitle,
  getInitialWeeklyData,
} from './game-utils'

export {
  ACHIEVEMENTS_DEF,
  SKILLS_DEF,
  ITEMS_DEF,
  QUEST_TEMPLATES,
  XP_BASE,
  LEVEL_TITLES,
  MONSTER_NAMES,
  MONSTER_EMOJIS,
} from './game-constants'

// ========== Slice Creators ==========
import { createUserSlice, initialUser } from './slices/userSlice'
import type { UserSlice } from './slices/userSlice'

import { createMonsterSlice } from './slices/monsterSlice'
import type { MonsterSlice } from './slices/monsterSlice'

import { createDailySlice, initialDaily } from './slices/dailySlice'
import type { DailySlice } from './slices/dailySlice'

import { createProgressSlice } from './slices/progressSlice'
import type { ProgressSlice } from './slices/progressSlice'

import { createAchievementSlice } from './slices/achievementSlice'
import type { AchievementSlice } from './slices/achievementSlice'

import { createInventorySlice } from './slices/inventorySlice'
import type { InventorySlice } from './slices/inventorySlice'

import { createCompanionSlice } from './slices/companionSlice'
import type { CompanionSlice } from './slices/companionSlice'

import { generateMonster, getTodayStr, getInitialWeeklyData } from './game-utils'
import { ACHIEVEMENTS_DEF, SKILLS_DEF, ITEMS_DEF } from './game-constants'

// ========== 组合类型定义（保持向后兼容） ==========

export interface GameStateData {
  user: import('./game-types').UserInfo
  monster: import('./game-types').MonsterState
  daily: import('./game-types').DailyStatus
  dietRecords: import('./game-types').DietRecord[]
  exerciseRecords: import('./game-types').ExerciseRecord[]
  coins: number
  days: number
  streak: number
  weeklyData: import('./game-types').WeeklyData | null
  playerLevel: import('./game-types').PlayerLevel
  achievements: import('./game-types').AchievementProgress[]
  dailyQuests: import('./game-types').DailyQuest[]
  skills: import('./game-types').Skill[]
  items: import('./game-types').Item[]
  lastQuestDate: string
  customFoods: import('../types/game').Food[]
  customExercises: import('../types/game').Exercise[]
  // Streak容错新增字段
  maxStreak: number
  streakFreeze: number
  streakShield: boolean
  streakFreezePrompt: boolean
  streakProtectedToday: boolean
  lastFreezeRefillDate: string
  totalMonsterKills: number
  // AI 教练建议
  advice?: import('../lib/difficultyEngine').DifficultyAdvice
  lastAdviceDate: string
  // 战斗伙伴
  companion: import('../data/companion').CompanionState
}

export interface GameStateActions {
  setUser: (user: Partial<import('./game-types').UserInfo>) => void
  updateWeight: (weight: number) => void
  setDifficulty: (difficulty: import('./game-types').Difficulty) => void
  attackMonster: (damage: number) => void
  /** 暴食增加怪物护盾（护盾完全来自过量卡路里） */
  addMonsterShield: (calories: number) => void
  healMonster: () => void
  levelUpMonster: () => void
  addDietRecord: (record: Omit<import('./game-types').DietRecord, 'id'>) => void
  removeDietRecord: (id: string) => void
  addExerciseRecord: (record: Omit<import('./game-types').ExerciseRecord, 'id'>) => void
  removeExerciseRecord: (id: string) => void
  addCoins: (amount: number) => void
  spendCoins: (amount: number) => boolean
  incrementStreak: () => void
  resetDailyIfNeeded: () => boolean
  resetGame: () => void
  setPendingAttack: (attack: import('./game-types').PendingAttack | null) => void
  setOvereatCalories: (calories: number) => void
  addXp: (amount: number) => { leveledUp: boolean; newLevel?: number }
  checkAchievements: () => import('./game-types').AchievementProgress[]
  generateDailyQuests: () => void
  updateQuestProgress: (type: string, amount: number) => void
  useItem: (itemId: string) => boolean
  getActiveSkills: () => import('./game-types').Skill[]
  addCustomFood: (food: import('../types/game').Food) => void
  removeCustomFood: (id: string) => void
  addCustomExercise: (exercise: import('../types/game').Exercise) => void
  removeCustomExercise: (id: string) => void
  // Streak容错新增Action
  useStreakFreeze: () => boolean
  buyStreakFreeze: () => boolean
  declineStreakFreeze: () => void
  // 每日作战
  spawnDailyMonster: () => void
  spawnPhantomMonster: () => void
  solidifyMonster: () => void
  // 战斗伙伴
  feedCompanion: (calories: number) => void
  exerciseWithCompanion: (duration: number) => void
  updateCompanionMood: () => void
  petCompanion: () => void
  addPendingDrops: (drops: number) => void
  collectDrops: () => void
}

export type GameState = GameStateData & GameStateActions

type FullSlice = UserSlice & MonsterSlice & DailySlice & ProgressSlice & AchievementSlice & InventorySlice & CompanionSlice

// ========== 统一 Store ==========

export const useGameStore = create<GameState>()(
  persist(
    (set, get, api) => {
      const dailySlice = createDailySlice(set, get, api)
      const companionSlice = createCompanionSlice(set, get, api)

      return {
        ...createUserSlice(set, get, api),
        ...createMonsterSlice(set, get, api),
        ...dailySlice,
        ...createProgressSlice(set, get, api),
        ...createAchievementSlice(set, get, api),
        ...createInventorySlice(set, get, api),
        ...companionSlice,

        // 修正 daily.date 初始值（slice 中为空字符串，在这里覆盖为今天）
        daily: {
          ...initialDaily,
          date: getTodayStr(),
        },

        addDietRecord: (record) => {
          dailySlice.addDietRecord(record)
          companionSlice.feedCompanion(record.calories)
        },

        addExerciseRecord: (record) => {
          dailySlice.addExerciseRecord(record)
          companionSlice.exerciseWithCompanion(record.reps || 0)
        },

        resetGame: () =>
          set({
            user: initialUser,
            monster: generateMonster(1, 'normal'),
            daily: {
              intake: 0,
              exerciseBurn: 0,
              damage: 0,
              date: getTodayStr(),
              pendingAttack: null,
              overeatCalories: 0,
              monsterDefeated: false,
            },
            dietRecords: [],
            exerciseRecords: [],
            customFoods: [],
            customExercises: [],
            coins: 0,
            days: 1,
            streak: 0,
            weeklyData: getInitialWeeklyData(),
            playerLevel: { level: 1, xp: 0, totalXp: 0 },
            achievements: ACHIEVEMENTS_DEF.map((a) => ({ id: a.id, unlocked: false, progress: 0 })),
            dailyQuests: [],
            skills: JSON.parse(JSON.stringify(SKILLS_DEF)),
            items: ITEMS_DEF.map((i) => ({ ...i, quantity: 0 })),
            lastQuestDate: '',
            advice: undefined,
            lastAdviceDate: '',
            maxStreak: 0,
            streakFreeze: 1,
            streakShield: false,
            streakFreezePrompt: false,
            streakProtectedToday: false,
            lastFreezeRefillDate: '',
            totalMonsterKills: 0,
            companion: companionSlice.companion,
          }),
      }
    },
    {
      name: 'fat-battle-game-store',
      storage: createJSONStorage(() => customLocalStorage),
      partialize: (state) => ({
        user: state.user,
        monster: state.monster,
        daily: state.daily,
        dietRecords: state.dietRecords,
        exerciseRecords: state.exerciseRecords,
        coins: state.coins,
        days: state.days,
        streak: state.streak,
        weeklyData: state.weeklyData,
        playerLevel: state.playerLevel,
        achievements: state.achievements,
        dailyQuests: state.dailyQuests,
        skills: state.skills,
        items: state.items,
        lastQuestDate: state.lastQuestDate,
        advice: state.advice,
        lastAdviceDate: state.lastAdviceDate,
        customFoods: state.customFoods,
        customExercises: state.customExercises,
        maxStreak: state.maxStreak,
        streakFreeze: state.streakFreeze,
        streakShield: state.streakShield,
        streakFreezePrompt: state.streakFreezePrompt,
        streakProtectedToday: state.streakProtectedToday,
        lastFreezeRefillDate: state.lastFreezeRefillDate,
        totalMonsterKills: state.totalMonsterKills,
        companion: state.companion,
      }),
    }
  )
)
