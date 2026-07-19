import type { MonsterState, Difficulty } from '../game-types'
import { generateMonster, updateMonsterPhase } from '../game-types'
import { analyzeUserPerformance } from '../../lib/difficultyEngine'
import { calculateShieldFromOvereat } from '../../core/damage'

function calculateSkinLevel(totalDrops: number): number {
  return Math.min(10, 1 + Math.floor(totalDrops / 8))
}

function calculateDialogueLevel(totalDrops: number): number {
  return Math.min(10, 1 + Math.floor(totalDrops / 12))
}

export interface MonsterSlice {
  monster: MonsterState
  attackMonster: (damage: number) => void
  /** 暴食增加怪物护盾（护盾完全来自过量卡路里） */
  addMonsterShield: (calories: number) => void
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
      const monster = state.monster
      let newHp = monster.hp
      let newShield = monster.shield

      // ========== 护盾机制 ==========
      if (newShield > 0) {
        // 护盾存在时：护盾直接扣除全额伤害
        newShield -= damage

        // HP同时受到穿透伤害（护盾减伤率决定穿透比例）
        const hpDamage = Math.round(damage * monster.shieldReductionRate)
        newHp = Math.max(0, newHp - hpDamage)

        // 如果护盾破了，剩余护盾的负数部分额外打到HP上
        if (newShield < 0) {
          newHp = Math.max(0, newHp + newShield) // newShield为负，相当于hp -= abs(newShield)
          newShield = 0
        }
      } else {
        // 护盾已破，全额伤害打到HP
        newHp = Math.max(0, newHp - damage)
      }

      // 实际对HP造成的伤害（用于每日统计 - 记录原始运动伤害）
      const newDaily = { ...state.daily, damage: state.daily.damage + damage }

      if (newHp === 0) {
        const coinsEarned = Math.round(monster.level * 10 * monster.coinMultiplier)
        const dropsEarned = monster.level * 2
        // 每日作战模式：击败后不再立即生成新怪物，而是标记今日已完成
        // 宠物即时吃掉掉落物，升级皮肤和对话能力
        const totalDrops = state.companion.monsterDrops + dropsEarned
        const newSkinLevel = calculateSkinLevel(totalDrops)
        const newDialogueLevel = calculateDialogueLevel(totalDrops)
        return {
          monster: { ...monster, hp: 0, shield: 0 },
          coins: state.coins + coinsEarned,
          daily: { ...newDaily, monsterDefeated: true },
          totalMonsterKills: (state.totalMonsterKills ?? 0) + 1,
          companion: {
            ...state.companion,
            monsterDrops: totalDrops,
            skinLevel: newSkinLevel,
            dialogueLevel: newDialogueLevel,
            mood: 'happy' as const,
          },
        }
      }
      const updatedMonster = { ...monster, hp: newHp, shield: newShield }
      const phaseUpdate = updateMonsterPhase(updatedMonster)
      return { monster: { ...updatedMonster, ...phaseUpdate }, daily: newDaily }
    }),

  healMonster: () =>
    set((state: any) => ({ monster: { ...state.monster, hp: state.monster.maxHp } })),

  /** 暴食增加怪物护盾：过量卡路里按 10:1 比例转化为护盾值 */
  addMonsterShield: (calories: number) =>
    set((state: any) => {
      if (calories <= 0) return {}
      const monster = state.monster
      // 转化比例：每 10 过量卡路里 = 1 点护盾（与 core/damage.ts calculateShieldFromOvereat 一致）
      // 设计理由：暴食惩罚但不至于过强——高卡路里数值不会让护盾条瞬间溢出
      // maxShield 用于护盾条百分比显示，随护盾增长动态调整
      const shieldGain = calculateShieldFromOvereat(calories)
      if (shieldGain <= 0) return {}
      const newShield = monster.shield + shieldGain
      const newMaxShield = Math.max(monster.maxShield, newShield)
      return {
        monster: {
          ...monster,
          shield: newShield,
          maxShield: newMaxShield,
        },
      }
    }),

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
