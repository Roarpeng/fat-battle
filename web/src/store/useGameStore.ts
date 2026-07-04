import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

export type Difficulty = 'easy' | 'normal' | 'hard'

export interface UserInfo {
  height: number
  weight: number
  targetWeight: number
  bmi: number
  difficulty: Difficulty
  role: string
}

export interface MonsterState {
  hp: number
  maxHp: number
  level: number
  name: string
  emoji: string
}

export interface DailyStatus {
  intake: number
  exerciseBurn: number
  damage: number
  date: string
}

export interface DietRecord {
  id: string
  name: string
  calories: number
  time: number
}

export interface ExerciseRecord {
  id: string
  name: string
  calories: number
  time: number
  reps?: number
}

export interface WeeklyData {
  weekStart: string
  days: { date: string; weight?: number; calories?: number; exercise?: number }[]
}

export interface GameStateData {
  user: UserInfo
  monster: MonsterState
  daily: DailyStatus
  dietRecords: DietRecord[]
  exerciseRecords: ExerciseRecord[]
  coins: number
  days: number
  streak: number
  weeklyData: WeeklyData | null
}

export interface GameStateActions {
  setUser: (user: Partial<UserInfo>) => void
  updateWeight: (weight: number) => void
  setDifficulty: (difficulty: Difficulty) => void
  attackMonster: (damage: number) => void
  healMonster: () => void
  levelUpMonster: () => void
  addDietRecord: (record: Omit<DietRecord, 'id'>) => void
  removeDietRecord: (id: string) => void
  addExerciseRecord: (record: Omit<ExerciseRecord, 'id'>) => void
  removeExerciseRecord: (id: string) => void
  addCoins: (amount: number) => void
  spendCoins: (amount: number) => boolean
  incrementStreak: () => void
  resetDailyIfNeeded: () => void
  resetGame: () => void
}

export type GameState = GameStateData & GameStateActions

const MONSTER_NAMES = ['脂肪怪', '油腻龙', '卡路里魔王', '肥肉巨人', '懒惰史莱姆', '肥胖幽灵', '甜点恶魔', '碳水巨兽']
const MONSTER_EMOJIS = ['👹', '🐉', '👿', '🧟', '🟢', '👻', '😈', '🦣']

const getTodayStr = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const calculateBmi = (weight: number, height: number) => {
  if (height <= 0) return 0
  const h = height / 100
  return Number((weight / (h * h)).toFixed(1))
}

const generateMonster = (level: number): MonsterState => {
  const idx = (level - 1) % MONSTER_NAMES.length
  const baseHp = 100 + (level - 1) * 50
  return {
    hp: baseHp,
    maxHp: baseHp,
    level,
    name: MONSTER_NAMES[idx],
    emoji: MONSTER_EMOJIS[idx],
  }
}

const getInitialWeeklyData = (): WeeklyData => {
  const today = new Date()
  const dayOfWeek = today.getDay()
  const monday = new Date(today)
  monday.setDate(today.getDate() - (dayOfWeek === 0 ? 6 : dayOfWeek - 1))
  const days = []
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday)
    d.setDate(monday.getDate() + i)
    days.push({
      date: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`,
    })
  }
  return {
    weekStart: days[0].date, days }
}

const initialState: GameStateData = {
  user: {
    height: 170,
    weight: 70,
    targetWeight: 60,
    bmi: calculateBmi(70, 170),
    difficulty: 'normal',
    role: '战士',
  },
  monster: generateMonster(1),
  daily: {
    intake: 0,
    exerciseBurn: 0,
    damage: 0,
    date: getTodayStr(),
  },
  dietRecords: [],
  exerciseRecords: [],
  coins: 0,
  days: 1,
  streak: 0,
  weeklyData: getInitialWeeklyData(),
}

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      ...initialState,

      setUser: (user) =>
        set((state) => ({
          user: {
            ...state.user,
            ...user,
            bmi: calculateBmi(user.weight ?? state.user.weight, user.height ?? state.user.height),
          },
        })),

      updateWeight: (weight) =>
        set((state) => {
        const bmi = calculateBmi(weight, state.user.height)
        return { user: { ...state.user, weight, bmi } }
      }),

      setDifficulty: (difficulty) =>
        set((state) => ({ user: { ...state.user, difficulty } })),

      attackMonster: (damage) =>
        set((state) => {
          const newHp = Math.max(0, state.monster.hp - damage)
          const newDaily = { ...state.daily, damage: state.daily.damage + damage }
          if (newHp === 0) {
            const coinsEarned = state.monster.level * 10
            return {
              monster: generateMonster(state.monster.level + 1),
              coins: state.coins + coinsEarned,
              daily: newDaily,
            }
          }
          return { monster: { ...state.monster, hp: newHp }, daily: newDaily }
        }),

      healMonster: () =>
        set((state) => ({ monster: { ...state.monster, hp: state.monster.maxHp } })),

      levelUpMonster: () =>
        set((state) => ({ monster: generateMonster(state.monster.level + 1) })),

      addDietRecord: (record) =>
        set((state) => {
          const newRecord: DietRecord = {
            ...record,
            id: Date.now().toString() + Math.random().toString(36).slice(2, 8),
          }
          return {
            dietRecords: [newRecord, ...state.dietRecords],
            daily: { ...state.daily, intake: state.daily.intake + record.calories },
          }
        }),

      removeDietRecord: (id) =>
        set((state) => {
          const record = state.dietRecords.find((r) => r.id === id)
          if (!record) return state
          return {
            dietRecords: state.dietRecords.filter((r) => r.id !== id),
            daily: { ...state.daily, intake: Math.max(0, state.daily.intake - record.calories) },
          }
        }),

      addExerciseRecord: (record) =>
        set((state) => {
          const newRecord: ExerciseRecord = {
            ...record,
            id: Date.now().toString() + Math.random().toString(36).slice(2, 8),
          }
          return {
            exerciseRecords: [newRecord, ...state.exerciseRecords],
            daily: { ...state.daily, exerciseBurn: state.daily.exerciseBurn + record.calories },
          }
        }),

      removeExerciseRecord: (id) =>
        set((state) => {
          const record = state.exerciseRecords.find((r) => r.id === id)
          if (!record) return state
          return {
            exerciseRecords: state.exerciseRecords.filter((r) => r.id !== id),
            daily: {
              ...state.daily,
              exerciseBurn: Math.max(0, state.daily.exerciseBurn - record.calories),
            },
          }
        }),

      addCoins: (amount) => set((state) => ({ coins: state.coins + amount })),

      spendCoins: (amount) => {
        const state = get()
        if (state.coins < amount) return false
        set({ coins: state.coins - amount })
        return true
      },

      incrementStreak: () => set((state) => ({ streak: state.streak + 1 })),

      resetDailyIfNeeded: () => {
        const today = getTodayStr()
        const state = get()
        if (state.daily.date === today) return

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
            days: newWeekly.days.map((d) =>
              d.date === state.daily.date ? { ...d, ...yesterdayData } : d
            ),
          }
        }

        set({
          daily: { intake: 0, exerciseBurn: 0, damage: 0, date: today },
          days: state.days + 1,
          weeklyData: newWeekly,
        })
      },

      resetGame: () => set(initialState),
    }),
    {
      name: 'fat-battle-game-store',
      storage: createJSONStorage(() => localStorage),
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
      }),
    }
  )
)
