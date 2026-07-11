import type { DailyStatus, DietRecord, ExerciseRecord, PendingAttack, DailyQuest } from '../game-types'
import type { Food, Exercise } from '../../types/game'
import type { DifficultyAdvice } from '../../lib/difficultyEngine'
import { analyzeUserPerformance } from '../../lib/difficultyEngine'
import { getTodayStr, QUEST_TEMPLATES } from '../game-types'

export interface DailySlice {
  daily: DailyStatus
  dietRecords: DietRecord[]
  exerciseRecords: ExerciseRecord[]
  customFoods: Food[]
  customExercises: Exercise[]
  advice?: DifficultyAdvice
  lastAdviceDate: string
  addDietRecord: (record: Omit<DietRecord, 'id'>) => void
  removeDietRecord: (id: string) => void
  addExerciseRecord: (record: Omit<ExerciseRecord, 'id'>) => void
  removeExerciseRecord: (id: string) => void
  setPendingAttack: (attack: PendingAttack | null) => void
  setOvereatCalories: (calories: number) => void
  addCustomFood: (food: Food) => void
  removeCustomFood: (id: string) => void
  addCustomExercise: (exercise: Exercise) => void
  removeCustomExercise: (id: string) => void
  generateDailyQuests: () => void
}

export const initialDaily: DailyStatus = {
  intake: 0,
  exerciseBurn: 0,
  damage: 0,
  date: '', // filled at store creation
  pendingAttack: null,
  overeatCalories: 0,
}

export const createDailySlice = (set: any, get: any, _api?: any): DailySlice => ({
  daily: initialDaily,
  dietRecords: [],
  exerciseRecords: [],
  customFoods: [],
  customExercises: [],
  lastAdviceDate: '',

  addDietRecord: (record) =>
    set((state: any) => {
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
    set((state: any) => {
      const record = state.dietRecords.find((r: DietRecord) => r.id === id)
      if (!record) return state
      return {
        dietRecords: state.dietRecords.filter((r: DietRecord) => r.id !== id),
        daily: { ...state.daily, intake: Math.max(0, state.daily.intake - record.calories) },
      }
    }),

  addExerciseRecord: (record) =>
    set((state: any) => {
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
    set((state: any) => {
      const record = state.exerciseRecords.find((r: ExerciseRecord) => r.id === id)
      if (!record) return state
      return {
        exerciseRecords: state.exerciseRecords.filter((r: ExerciseRecord) => r.id !== id),
        daily: {
          ...state.daily,
          exerciseBurn: Math.max(0, state.daily.exerciseBurn - record.calories),
        },
      }
    }),

  setPendingAttack: (attack) =>
    set((state: any) => ({ daily: { ...state.daily, pendingAttack: attack } })),

  setOvereatCalories: (calories: number) =>
    set((state: any) => ({ daily: { ...state.daily, overeatCalories: calories } })),

  addCustomFood: (food) =>
    set((state: any) => ({
      customFoods: [...state.customFoods, food],
    })),

  removeCustomFood: (id) =>
    set((state: any) => ({
      customFoods: state.customFoods.filter((f: Food) => f.id !== id),
    })),

  addCustomExercise: (exercise) =>
    set((state: any) => ({
      customExercises: [...state.customExercises, exercise],
    })),

  removeCustomExercise: (id) =>
    set((state: any) => ({
      customExercises: state.customExercises.filter((e: Exercise) => e.id !== id),
    })),

  generateDailyQuests: () => {
    const state = get()
    const today = getTodayStr()

    // 如果今日已生成过任务和建议，直接返回
    if (state.lastQuestDate === today && state.lastAdviceDate === today) return

    // 调用 AI 教练分析用户表现
    const advice = analyzeUserPerformance(
      state.weeklyData ?? null,
      state.streak ?? 0,
      state.user?.difficulty ?? 'normal',
      state.user?.bmi ?? 24
    )

    // 如果今日已生成任务但未生成建议，只更新建议
    if (state.lastQuestDate === today && state.lastAdviceDate !== today) {
      set({ advice, lastAdviceDate: today })
      return
    }

    // 随机选3个任务
    const shuffled = [...QUEST_TEMPLATES].sort(() => Math.random() - 0.5)
    const selected = shuffled.slice(0, 3)

    const quests: DailyQuest[] = selected.map((q, i) => {
      const baseTarget = q.baseTarget[Math.floor(Math.random() * q.baseTarget.length)]
      const adjustedTarget = Math.max(1, Math.round(baseTarget * advice.questTargetAdjustment))

      return {
        id: `quest-${today}-${i}`,
        title: q.title,
        description: q.desc.replace('{target}', String(adjustedTarget)),
        type: q.type as DailyQuest['type'],
        target: adjustedTarget,
        current: 0,
        completed: false,
        rewardCoins: Math.floor(adjustedTarget * 0.5) + 5,
        rewardXp: Math.floor(adjustedTarget * 0.8) + 10,
      }
    })

    set({
      dailyQuests: quests,
      lastQuestDate: today,
      advice,
      lastAdviceDate: today,
    })
  },
})
