import { useGameStore } from './useGameStore'
import { useShallow } from 'zustand/react/shallow'

// ===== 用户相关 =====
export const useUser = () => useGameStore((s) => s.user)
export const useUserWeight = () => useGameStore((s) => s.user.weight)
export const useUserDifficulty = () => useGameStore((s) => s.user.difficulty)

// ===== 怪物相关 =====
export const useMonster = () => useGameStore((s) => s.monster)
export const useMonsterHp = () => useGameStore((s) => s.monster.hp)
// 注意：MonsterState 中没有 `phase` 字段，使用 `phaseIndex` 作为阶段标识
export const useMonsterPhase = () => useGameStore((s) => s.monster.phaseIndex)
export const useMonsterShield = () => useGameStore((s) => s.monster.shield)

// ===== 每日状态相关 =====
export const useDaily = () => useGameStore((s) => s.daily)
export const useDailyIntake = () => useGameStore((s) => s.daily.intake)
export const useDailyExerciseBurn = () => useGameStore((s) => s.daily.exerciseBurn)
export const useDailyDamage = () => useGameStore((s) => s.daily.damage)
export const usePendingAttack = () => useGameStore((s) => s.daily.pendingAttack)

// ===== 记录相关 =====
export const useDietRecords = () => useGameStore((s) => s.dietRecords)
export const useExerciseRecords = () => useGameStore((s) => s.exerciseRecords)

// ===== 进度相关 =====
export const usePlayerLevel = () => useGameStore((s) => s.playerLevel)
export const useCoins = () => useGameStore((s) => s.coins)
export const useStreak = () => useGameStore((s) => s.streak)
export const useDays = () => useGameStore((s) => s.days)

// ===== 宠物相关 =====
export const useCompanion = () => useGameStore((s) => s.companion)

// ===== 成就/任务相关 =====
export const useAchievements = () => useGameStore((s) => s.achievements)
export const useDailyQuests = () => useGameStore((s) => s.dailyQuests)

// ===== 物品/技能相关 =====
export const useItems = () => useGameStore((s) => s.items)
export const useSkills = () => useGameStore((s) => s.skills)

// ===== 组合 selector（带 shallow 比较） =====
export const useBattleState = () =>
  useGameStore(
    useShallow((s) => ({
      monster: s.monster,
      pendingAttack: s.daily.pendingAttack,
      damage: s.daily.damage,
    }))
  )

export const useDailySummary = () =>
  useGameStore(
    useShallow((s) => ({
      intake: s.daily.intake,
      exerciseBurn: s.daily.exerciseBurn,
      damage: s.daily.damage,
    }))
  )

export const useGameProgress = () =>
  useGameStore(
    useShallow((s) => ({
      playerLevel: s.playerLevel,
      coins: s.coins,
      streak: s.streak,
      days: s.days,
    }))
  )
