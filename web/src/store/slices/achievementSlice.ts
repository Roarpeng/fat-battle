import type { PlayerLevel, AchievementProgress, DailyQuest, Skill } from '../game-types'
import { getTodayStr, getXpToNextLevel, ACHIEVEMENTS_DEF, SKILLS_DEF } from '../game-types'

export interface AchievementSlice {
  playerLevel: PlayerLevel
  achievements: AchievementProgress[]
  dailyQuests: DailyQuest[]
  skills: Skill[]
  lastQuestDate: string
  addXp: (amount: number) => { leveledUp: boolean; newLevel?: number }
  checkAchievements: () => AchievementProgress[]
  updateQuestProgress: (type: string, amount: number) => void
  getActiveSkills: () => Skill[]
}

export const createAchievementSlice = (set: any, get: any, _api?: any): AchievementSlice => ({
  playerLevel: { level: 1, xp: 0, totalXp: 0 },
  achievements: ACHIEVEMENTS_DEF.map((a) => ({ id: a.id, unlocked: false, progress: 0 })),
  dailyQuests: [],
  skills: JSON.parse(JSON.stringify(SKILLS_DEF)),
  lastQuestDate: '',

  addXp: (amount) => {
    const state = get()
    let { level, xp, totalXp } = state.playerLevel
    totalXp += amount
    xp += amount
    let leveledUp = false
    let newLevel = level

    while (xp >= getXpToNextLevel(level)) {
      xp -= getXpToNextLevel(level)
      level += 1
      leveledUp = true
      newLevel = level
      // 升级时解锁技能
      const newSkills = state.skills.map((s: Skill) =>
        s.unlockedAtLevel <= level && !s.unlocked ? { ...s, unlocked: true } : s
      )
      set({ skills: newSkills })
    }

    set({ playerLevel: { level, xp, totalXp } })
    return { leveledUp, newLevel: leveledUp ? newLevel : undefined }
  },

  checkAchievements: () => {
    const state = get()
    const today = getTodayStr()
    const totalReps = state.exerciseRecords.reduce((sum: number, r: any) => sum + (r.reps ?? 0), 0)
    const totalDamage = state.exerciseRecords.reduce((sum: number, r: any) => sum + (r.calories * 2), 0)
    const monsterKills = state.totalMonsterKills ?? 0
    const exerciseCount = state.exerciseRecords.length
    const dietCount = state.dietRecords.length
    const streakDays = state.streak
    const playerLvl = state.playerLevel.level

    let totalCoinReward = 0
    const newAchievements = state.achievements.map((ach: AchievementProgress) => {
      if (ach.unlocked) return ach
      const def = ACHIEVEMENTS_DEF.find((a) => a.id === ach.id)
      if (!def) return ach

      let progress = 0
      let shouldUnlock = false

      switch (def.conditionType) {
        case 'exercise_count':
          progress = exerciseCount
          shouldUnlock = exerciseCount >= def.conditionValue
          break
        case 'total_reps':
          progress = totalReps
          shouldUnlock = totalReps >= def.conditionValue
          break
        case 'diet_count':
          progress = dietCount
          shouldUnlock = dietCount >= def.conditionValue
          break
        case 'monster_kills':
          progress = monsterKills
          shouldUnlock = monsterKills >= def.conditionValue
          break
        case 'total_damage':
          progress = totalDamage
          shouldUnlock = totalDamage >= def.conditionValue
          break
        case 'streak_days':
          progress = streakDays
          shouldUnlock = streakDays >= def.conditionValue
          break
        case 'player_level':
          progress = playerLvl
          shouldUnlock = playerLvl >= def.conditionValue
          break
        case 'total_coins':
          progress = state.coins
          shouldUnlock = state.coins >= def.conditionValue
          break
      }

      if (shouldUnlock) {
        totalCoinReward += def.reward
        return { ...ach, unlocked: true, unlockedAt: today, progress: def.conditionValue }
      }
      return { ...ach, progress }
    })

    const newlyUnlocked = newAchievements.filter(
      (a: AchievementProgress) => a.unlocked && !state.achievements.find((sa: AchievementProgress) => sa.id === a.id)?.unlocked
    )

    if (totalCoinReward > 0) {
      set({ coins: state.coins + totalCoinReward, achievements: newAchievements })
    } else {
      set({ achievements: newAchievements })
    }
    return newlyUnlocked
  },

  updateQuestProgress: (type, amount) => {
    const state = get()
    const updatedQuests = state.dailyQuests.map((q: DailyQuest) => {
      if (q.completed || q.type !== type) return q
      const newCurrent = q.current + amount
      const completed = newCurrent >= q.target
      if (completed) {
        // 完成任务奖励
        set({
          coins: state.coins + q.rewardCoins,
        })
        // 经验值通过 addXp 处理
      }
      return { ...q, current: Math.min(newCurrent, q.target), completed }
    })
    set({ dailyQuests: updatedQuests })
  },

  getActiveSkills: () => {
    const state = get()
    return state.skills.filter((s: Skill) => s.unlocked)
  },
})
