import type { MonsterState, Difficulty } from '../game-types'
import { generateMonster, updateMonsterPhase } from '../game-types'
import { analyzeUserPerformance } from '../../lib/difficultyEngine'

export interface MonsterSlice {
  monster: MonsterState
  attackMonster: (damage: number) => void
  healMonster: () => void
  levelUpMonster: () => void
  spawnDailyMonster: () => void
  spawnPhantomMonster: () => void
  solidifyMonster: () => void
}

function generateMonsterWithDifficulty(
  level: number,
  difficulty: Difficulty,
  getState: () => any
): MonsterState {
  const state = getState()
  const advice = analyzeUserPerformance(
    state.weeklyData ?? null,
    state.streak ?? 0,
    state.user?.difficulty ?? difficulty,
    state.user?.bmi ?? 24
  )
  return generateMonster(level, difficulty, advice.monsterHpMultiplier)
}

export const createMonsterSlice = (set: any, get: any, _api?: any): MonsterSlice => ({
  monster: generateMonster(1, 'normal', 1.0),

  attackMonster: (damage) =>
    set((state: any) => {
      const newHp = Math.max(0, state.monster.hp - damage)
      const newDaily = { ...state.daily, damage: state.daily.damage + damage }
      if (newHp === 0) {
        const coinsEarned = Math.round(state.monster.level * 10 * state.monster.coinMultiplier)
        const dropsEarned = state.monster.level * 2
        // 每日作战模式：击败后不再立即生成新怪物，而是标记今日已完成
        // 同时给宠物积攒怪物掉落物
        return {
          monster: { ...state.monster, hp: 0 },
          coins: state.coins + coinsEarned,
          daily: { ...newDaily, monsterDefeated: true },
          totalMonsterKills: (state.totalMonsterKills ?? 0) + 1,
          companion: {
            ...state.companion,
            pendingDrops: state.companion.pendingDrops + dropsEarned,
          },
        }
      }
      const updatedMonster = { ...state.monster, hp: newHp }
      const phaseUpdate = updateMonsterPhase(updatedMonster)
      return { monster: { ...updatedMonster, ...phaseUpdate }, daily: newDaily }
    }),

  healMonster: () =>
    set((state: any) => ({ monster: { ...state.monster, hp: state.monster.maxHp } })),

  levelUpMonster: () =>
    set((state: any) => ({
      monster: generateMonsterWithDifficulty(state.monster.level + 1, state.user.difficulty, get),
    })),

  spawnDailyMonster: () =>
    set((state: any) => ({
      monster: generateMonsterWithDifficulty(state.days, state.user.difficulty, get),
    })),

  spawnPhantomMonster: () =>
    set((state: any) => ({
      monster: { ...generateMonsterWithDifficulty(state.days, state.user.difficulty, get), isPhantom: true },
    })),

  solidifyMonster: () =>
    set((state: any) => ({
      monster: { ...state.monster, isPhantom: false },
    })),
})
