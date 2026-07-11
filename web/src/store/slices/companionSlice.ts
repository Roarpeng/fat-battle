import type { CompanionState } from '../../data/companion'
import {
  getXpToNextLevel,
  getCompanionStage,
} from '../../data/companion'
import { getTodayStr } from '../game-types'

export interface CompanionSlice {
  companion: CompanionState
  feedCompanion: (calories: number) => void
  exerciseWithCompanion: (duration: number) => void
  updateCompanionMood: () => void
  petCompanion: () => void
  addPendingDrops: (drops: number) => void
  collectDrops: () => void
}

function getDateStrFromTimestamp(time: number): string {
  const d = new Date(time)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function refreshCompanionDaily(companion: CompanionState): CompanionState {
  const today = getTodayStr()
  if (companion.lastActiveDate === today) return companion
  return {
    ...companion,
    hunger: Math.min(100, companion.hunger + 20),
    energy: Math.min(100, companion.energy + 50),
    lastActiveDate: today,
  }
}

function checkLevelUp(companion: CompanionState): CompanionState {
  let { level, xp } = companion
  let xpToNext = getXpToNextLevel(level)

  while (xp >= xpToNext) {
    xp -= xpToNext
    level += 1
    xpToNext = getXpToNextLevel(level)
  }

  const stage = getCompanionStage(companion.defId, level)
  return {
    ...companion,
    level,
    xp,
    xpToNext,
    name: stage.name,
    emoji: stage.emoji,
  }
}

function determineMood(
  companion: CompanionState,
  hasDietToday: boolean,
  hasExerciseToday: boolean
): CompanionState['mood'] {
  if (companion.hunger > 80) return 'sad'
  if (companion.energy < 20) return 'tired'
  if (hasDietToday && hasExerciseToday) return 'happy'
  return 'normal'
}

function calculateSkinLevel(totalDrops: number): number {
  return Math.min(10, 1 + Math.floor(totalDrops / 8))
}

function calculateDialogueLevel(totalDrops: number): number {
  return Math.min(10, 1 + Math.floor(totalDrops / 12))
}

export const createCompanionSlice = (set: any, get: any, _api?: any): CompanionSlice => ({
  companion: {
    defId: 'cat',
    name: '小猫崽',
    emoji: '🐱',
    level: 1,
    xp: 0,
    xpToNext: getXpToNextLevel(1),
    mood: 'normal',
    hunger: 50,
    energy: 100,
    totalExercises: 0,
    totalDiets: 0,
    lastActiveDate: getTodayStr(),
    pendingDrops: 0,
    monsterDrops: 0,
    skinLevel: 1,
    dialogueLevel: 1,
  },

  feedCompanion: (calories) =>
    set((state: any) => {
      let companion = refreshCompanionDaily(state.companion)
      companion = {
        ...companion,
        hunger: Math.max(0, companion.hunger - 10),
        totalDiets: companion.totalDiets + 1,
      }

      const today = getTodayStr()
      const hasDietToday = true
      const hasExerciseToday = state.exerciseRecords.some((r: any) => getDateStrFromTimestamp(r.time) === today)

      return {
        companion: {
          ...companion,
          mood: determineMood(companion, hasDietToday, hasExerciseToday),
        },
      }
    }),

  exerciseWithCompanion: (duration) =>
    set((state: any) => {
      let companion = refreshCompanionDaily(state.companion)
      const xpGain = Math.round(duration * 2)
      companion = {
        ...companion,
        energy: Math.max(0, companion.energy - 5),
        xp: companion.xp + xpGain,
        totalExercises: companion.totalExercises + 1,
      }
      companion = checkLevelUp(companion)

      const today = getTodayStr()
      const hasDietToday = state.dietRecords.some((r: any) => getDateStrFromTimestamp(r.time) === today)
      const hasExerciseToday = true

      return {
        companion: {
          ...companion,
          mood: determineMood(companion, hasDietToday, hasExerciseToday),
        },
      }
    }),

  updateCompanionMood: () =>
    set((state: any) => {
      let companion = refreshCompanionDaily(state.companion)
      const today = getTodayStr()
      const hasDietToday = state.dietRecords.some((r: any) => getDateStrFromTimestamp(r.time) === today)
      const hasExerciseToday = state.exerciseRecords.some((r: any) => getDateStrFromTimestamp(r.time) === today)

      return {
        companion: {
          ...companion,
          mood: determineMood(companion, hasDietToday, hasExerciseToday),
        },
      }
    }),

  petCompanion: () =>
    set((state: any) => {
      const companion = refreshCompanionDaily(state.companion)
      return {
        companion: {
          ...companion,
          mood: 'happy',
        },
      }
    }),

  addPendingDrops: (drops: number) =>
    set((state: any) => {
      const companion = refreshCompanionDaily(state.companion)
      return {
        companion: {
          ...companion,
          pendingDrops: companion.pendingDrops + drops,
        },
      }
    }),

  collectDrops: () =>
    set((state: any) => {
      const companion = refreshCompanionDaily(state.companion)
      if (companion.pendingDrops <= 0) return state
      const totalDrops = companion.monsterDrops + companion.pendingDrops
      const newSkinLevel = calculateSkinLevel(totalDrops)
      const newDialogueLevel = calculateDialogueLevel(totalDrops)
      return {
        companion: {
          ...companion,
          monsterDrops: totalDrops,
          pendingDrops: 0,
          skinLevel: newSkinLevel,
          dialogueLevel: newDialogueLevel,
          mood: 'happy',
        },
      }
    }),
})
