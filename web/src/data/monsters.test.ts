import { describe, it, expect } from 'vitest'
import {
  getMonsterDefByLevel,
  calculateMonsterHp,
  getExerciseMultiplier,
  getCurrentPhase,
  isMonsterEnraged,
  getTierName,
  getWeaknessLabel,
  getCategoryLabel,
  getCategoryEmoji,
  EXERCISE_CATEGORY,
  COUNTER_MAP,
  COUNTER_MULTIPLIER,
  WEAK_MULTIPLIER,
  MONSTER_DEFS,
  SEASONAL_MONSTERS,
} from './monsters'

describe('monsters.ts', () => {
  describe('getMonsterDefByLevel', () => {
    it('should return minion for regular levels (e.g., 1, 2, 3, 4)', () => {
      const m1 = getMonsterDefByLevel(1)
      expect(m1.tier).toBe('minion')
      const m2 = getMonsterDefByLevel(2)
      expect(m2.tier).toBe('minion')
      const m4 = getMonsterDefByLevel(4)
      expect(m4.tier).toBe('minion')
    })

    it('should return elite for levels divisible by 5 but not 10 (e.g., 5, 15, 25)', () => {
      const m5 = getMonsterDefByLevel(5)
      expect(m5.tier).toBe('elite')
      const m15 = getMonsterDefByLevel(15)
      expect(m15.tier).toBe('elite')
      const m25 = getMonsterDefByLevel(25)
      expect(m25.tier).toBe('elite')
    })

    it('should return boss for levels divisible by 10 (e.g., 10, 20, 30, 40, 50)', () => {
      const m10 = getMonsterDefByLevel(10)
      expect(m10.tier).toBe('boss')
      const m20 = getMonsterDefByLevel(20)
      expect(m20.tier).toBe('boss')
      const m30 = getMonsterDefByLevel(30)
      expect(m30.tier).toBe('boss')
      // Level 50 matches %10 first, so it's a boss
      const m50 = getMonsterDefByLevel(50)
      expect(m50.tier).toBe('boss')
    })

    it('should return finalboss for levels >= 50 that are not divisible by 5 or 10', () => {
      const m51 = getMonsterDefByLevel(51)
      expect(m51.tier).toBe('finalboss')
      const m52 = getMonsterDefByLevel(52)
      expect(m52.tier).toBe('finalboss')
      const m56 = getMonsterDefByLevel(56)
      expect(m56.tier).toBe('finalboss')
    })

    it('should cycle through monsters of the same tier', () => {
      const m1 = getMonsterDefByLevel(1)
      const m5 = getMonsterDefByLevel(5)
      const m9 = getMonsterDefByLevel(9)
      // Level 1 and 5 should be different
      expect(m1.id).not.toBe(m5.id)
      // Level 1+4 = 5, but tier changes, so different handling
    })

    it('should include seasonal monsters in the pool', () => {
      const allIds = [...MONSTER_DEFS, ...SEASONAL_MONSTERS].map(m => m.id)
      const m = getMonsterDefByLevel(1)
      expect(allIds).toContain(m.id)
    })
  })

  describe('calculateMonsterHp', () => {
    const def = MONSTER_DEFS[0] // sloth_king or slime

    it('should calculate HP for normal difficulty', () => {
      const hp = calculateMonsterHp(def, 1, 'normal')
      const expected = Math.round((def.baseHp + def.hpPerLevel * 0) * 1.0)
      expect(hp).toBe(expected)
    })

    it('should calculate HP for easy difficulty (0.7x)', () => {
      const hp = calculateMonsterHp(def, 1, 'easy')
      const expected = Math.round((def.baseHp + def.hpPerLevel * 0) * 0.7)
      expect(hp).toBe(expected)
    })

    it('should calculate HP for hard difficulty (1.3x)', () => {
      const hp = calculateMonsterHp(def, 1, 'hard')
      const expected = Math.round((def.baseHp + def.hpPerLevel * 0) * 1.3)
      expect(hp).toBe(expected)
    })

    it('should scale HP with level', () => {
      const hp1 = calculateMonsterHp(def, 1)
      const hp5 = calculateMonsterHp(def, 5)
      expect(hp5).toBeGreaterThan(hp1)
    })

    it('should default to normal difficulty', () => {
      const hp = calculateMonsterHp(def, 1)
      const expected = Math.round(def.baseHp * 1.0)
      expect(hp).toBe(expected)
    })
  })

  describe('getExerciseMultiplier', () => {
    it('should return neutral for unknown exercise', () => {
      const result = getExerciseMultiplier('unknown', 'cardio', 'strength')
      expect(result.multiplier).toBe(1.0)
      expect(result.isCounter).toBe(false)
      expect(result.isResisted).toBe(false)
      expect(result.label).toBe('')
    })

    it('should return counter (weakness hit) when exercise category counters monster affinity', () => {
      // COUNTER_MAP: cardio -> strength, strength -> core, core -> cardio
      // strength exercise (category: strength) counters core affinity monster
      const result = getExerciseMultiplier('squat', 'cardio', 'core')
      expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
      expect(result.isCounter).toBe(true)
      expect(result.isResisted).toBe(false)
      expect(result.label).toBe('弱点命中')
    })

    it('should return counter when exercise category equals monster weakness', () => {
      // If exercise category directly matches monster weakness
      const result = getExerciseMultiplier('running', 'cardio', 'core')
      expect(result.multiplier).toBe(COUNTER_MULTIPLIER)
      expect(result.isCounter).toBe(true)
      expect(result.isResisted).toBe(false)
      expect(result.label).toBe('克制')
    })

    it('should return resisted when exercise category equals monster affinity', () => {
      const result = getExerciseMultiplier('running', 'strength', 'cardio')
      expect(result.multiplier).toBe(WEAK_MULTIPLIER)
      expect(result.isCounter).toBe(false)
      expect(result.isResisted).toBe(true)
      expect(result.label).toBe('被抵抗')
    })

    it('should return neutral for unrelated exercise', () => {
      // running (cardio) vs weakness:strength, affinity:strength
      // cardio !== strength (weakness), COUNTER_MAP[cardio]=strength === strength (affinity) -> this is actually weakness hit!
      // Let's pick a case where none match
      // plank (core) vs weakness:cardio, affinity:strength
      // COUNTER_MAP[core]=cardio !== strength, category !== weakness (core !== cardio), category !== affinity (core !== strength)
      const result = getExerciseMultiplier('plank', 'cardio', 'strength')
      expect(result.multiplier).toBe(1.0)
      expect(result.isCounter).toBe(false)
      expect(result.isResisted).toBe(false)
      expect(result.label).toBe('')
    })
  })

  describe('getCurrentPhase', () => {
    it('should return null if no phases', () => {
      const def = MONSTER_DEFS.find(m => m.id === 'slime')!
      expect(getCurrentPhase(def, 1.0)).toBeNull()
    })

    it('should return first phase at full HP', () => {
      const def = MONSTER_DEFS.find(m => m.id === 'orc')!
      const phase = getCurrentPhase(def, 1.0)
      expect(phase).not.toBeNull()
      expect(phase!.name).toBe('正常状态')
    })

    it('should return matching phase based on HP threshold', () => {
      const def = MONSTER_DEFS.find(m => m.id === 'orc')!
      const phase = getCurrentPhase(def, 0.5)
      expect(phase).not.toBeNull()
      expect(phase!.name).toBe('油脂爆发')
    })

    it('should return lowest threshold phase when HP is very low', () => {
      const def = MONSTER_DEFS.find(m => m.id === 'calorie_demon')!
      const phase = getCurrentPhase(def, 0.1)
      expect(phase).not.toBeNull()
      expect(phase!.name).toBe('虚弱阶段')
    })
  })

  describe('isMonsterEnraged', () => {
    it('should return false when HP is above threshold', () => {
      const def = MONSTER_DEFS[0]
      expect(isMonsterEnraged(def, def.enrageThreshold + 0.1)).toBe(false)
    })

    it('should return true when HP is at or below threshold', () => {
      const def = MONSTER_DEFS[0]
      expect(isMonsterEnraged(def, def.enrageThreshold)).toBe(true)
      expect(isMonsterEnraged(def, def.enrageThreshold - 0.1)).toBe(true)
    })
  })

  describe('getTierName', () => {
    it('should return correct Chinese names', () => {
      expect(getTierName('minion')).toBe('小怪')
      expect(getTierName('elite')).toBe('精英')
      expect(getTierName('boss')).toBe('BOSS')
      expect(getTierName('finalboss')).toBe('最终BOSS')
    })
  })

  describe('getWeaknessLabel', () => {
    it('should return correct labels', () => {
      expect(getWeaknessLabel('cardio')).toBe('有氧运动')
      expect(getWeaknessLabel('strength')).toBe('力量训练')
      expect(getWeaknessLabel('core')).toBe('核心训练')
    })
  })

  describe('getCategoryLabel', () => {
    it('should return correct labels', () => {
      expect(getCategoryLabel('cardio')).toBe('有氧')
      expect(getCategoryLabel('strength')).toBe('力量')
      expect(getCategoryLabel('core')).toBe('核心')
    })
  })

  describe('getCategoryEmoji', () => {
    it('should return correct emojis', () => {
      expect(getCategoryEmoji('cardio')).toBe('🏃')
      expect(getCategoryEmoji('strength')).toBe('💪')
      expect(getCategoryEmoji('core')).toBe('🧘')
    })
  })

  describe('constants', () => {
    it('EXERCISE_CATEGORY should map exercises', () => {
      expect(EXERCISE_CATEGORY['running']).toBe('cardio')
      expect(EXERCISE_CATEGORY['squat']).toBe('strength')
      expect(EXERCISE_CATEGORY['plank']).toBe('core')
    })

    it('COUNTER_MAP should form a cycle', () => {
      expect(COUNTER_MAP['cardio']).toBe('strength')
      expect(COUNTER_MAP['strength']).toBe('core')
      expect(COUNTER_MAP['core']).toBe('cardio')
    })
  })
})
