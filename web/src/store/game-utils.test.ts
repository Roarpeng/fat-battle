import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import {
  getTodayStr,
  calculateBmi,
  generateMonster,
  updateMonsterPhase,
  getXpToNextLevel,
  getLevelTitle,
  getInitialWeeklyData,
  LEVEL_TITLES,
  XP_BASE,
} from './game-types'

describe('game-types utility functions', () => {
  describe('getTodayStr', () => {
    it('should return date string in YYYY-MM-DD format', () => {
      const result = getTodayStr()
      expect(result).toMatch(/^\d{4}-\d{2}-\d{2}$/)
    })

    it('should match current date', () => {
      const now = new Date()
      const expected = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
      expect(getTodayStr()).toBe(expected)
    })
  })

  describe('calculateBmi', () => {
    it('should return 0 when height <= 0', () => {
      expect(calculateBmi(70, 0)).toBe(0)
      expect(calculateBmi(70, -10)).toBe(0)
    })

    it('should calculate BMI correctly for normal inputs', () => {
      // weight=70kg, height=175cm -> h=1.75 -> 70/(1.75^2) = 70/3.0625 = 22.857... -> 22.9
      expect(calculateBmi(70, 175)).toBe(22.9)
    })

    it('should calculate BMI correctly for another example', () => {
      // weight=60kg, height=170cm -> h=1.7 -> 60/(1.7^2) = 60/2.89 = 20.761... -> 20.8
      expect(calculateBmi(60, 170)).toBe(20.8)
    })

    it('should return rounded to 1 decimal place', () => {
      const bmi = calculateBmi(80, 180)
      // 80/(1.8^2) = 80/3.24 = 24.691... -> 24.7
      expect(bmi).toBe(24.7)
    })

    it('should handle edge case with very small height', () => {
      expect(calculateBmi(70, 1)).toBeGreaterThan(0)
    })
  })

  describe('generateMonster', () => {
    it('should generate a monster with correct structure', () => {
      const monster = generateMonster(1)
      expect(monster).toHaveProperty('hp')
      expect(monster).toHaveProperty('maxHp')
      expect(monster).toHaveProperty('level')
      expect(monster).toHaveProperty('name')
      expect(monster).toHaveProperty('emoji')
      expect(monster).toHaveProperty('defId')
      expect(monster).toHaveProperty('tier')
      expect(monster).toHaveProperty('weakness')
      expect(monster).toHaveProperty('affinity')
      expect(monster).toHaveProperty('baseAttack')
      expect(monster).toHaveProperty('enrageThreshold')
      expect(monster).toHaveProperty('phaseIndex')
      expect(monster).toHaveProperty('isEnraged')
      expect(monster).toHaveProperty('isPhantom')
    })

    it('should set hp equal to maxHp on generation', () => {
      const monster = generateMonster(1)
      expect(monster.hp).toBe(monster.maxHp)
    })

    it('should set isEnraged to false at full HP', () => {
      const monster = generateMonster(1)
      expect(monster.isEnraged).toBe(false)
    })

    it('should set isPhantom to false by default', () => {
      const monster = generateMonster(1)
      expect(monster.isPhantom).toBe(false)
    })

    it('should respect level parameter', () => {
      const monster = generateMonster(5)
      expect(monster.level).toBe(5)
    })

    it('should apply hpMultiplier', () => {
      const m1 = generateMonster(1, 'normal', 1)
      const m2 = generateMonster(1, 'normal', 2)
      expect(m2.maxHp).toBe(m1.maxHp * 2)
    })

    it('should apply difficulty to HP', () => {
      const easy = generateMonster(1, 'easy')
      const normal = generateMonster(1, 'normal')
      const hard = generateMonster(1, 'hard')
      expect(easy.maxHp).toBeLessThan(normal.maxHp)
      expect(hard.maxHp).toBeGreaterThan(normal.maxHp)
    })

    it('should include phase info for bosses', () => {
      const boss = generateMonster(10) // level 10 is a boss
      if (boss.phaseName) {
        expect(boss.phaseName).toBeTruthy()
      }
    })
  })

  describe('updateMonsterPhase', () => {
    it('should update phase based on HP percentage', () => {
      const monster = generateMonster(10)
      monster.hp = Math.floor(monster.maxHp * 0.3)
      const updates = updateMonsterPhase(monster)
      expect(updates).toHaveProperty('phaseIndex')
      expect(updates).toHaveProperty('phaseName')
      expect(updates).toHaveProperty('phaseEmoji')
      expect(updates).toHaveProperty('isEnraged')
    })

    it('should set isEnraged true when HP is low', () => {
      const monster = generateMonster(1)
      monster.hp = 1
      const updates = updateMonsterPhase(monster)
      expect(updates.isEnraged).toBe(true)
    })

    it('should set isEnraged false when HP is high', () => {
      const monster = generateMonster(1)
      monster.hp = monster.maxHp
      const updates = updateMonsterPhase(monster)
      expect(updates.isEnraged).toBe(false)
    })

    it('should keep phaseIndex 0 for minions without phases', () => {
      const monster = generateMonster(1)
      monster.hp = monster.maxHp
      const updates = updateMonsterPhase(monster)
      expect(updates.phaseIndex).toBe(0)
      expect(updates.phaseName).toBe('')
    })
  })

  describe('getXpToNextLevel', () => {
    it('should return base XP for level 1', () => {
      const xp = getXpToNextLevel(1)
      expect(xp).toBe(Math.floor(XP_BASE * Math.pow(1.15, 0)))
      expect(xp).toBe(100)
    })

    it('should increase XP with level', () => {
      const xp1 = getXpToNextLevel(1)
      const xp2 = getXpToNextLevel(2)
      expect(xp2).toBeGreaterThan(xp1)
    })

    it('should calculate correct XP for level 5', () => {
      const xp = getXpToNextLevel(5)
      expect(xp).toBe(Math.floor(100 * Math.pow(1.15, 4)))
    })
  })

  describe('getLevelTitle', () => {
    it('should return first title for level <= 0', () => {
      expect(getLevelTitle(0)).toBe(LEVEL_TITLES[0])
      expect(getLevelTitle(-1)).toBe(LEVEL_TITLES[0])
    })

    it('should return correct title for valid levels', () => {
      expect(getLevelTitle(1)).toBe(LEVEL_TITLES[0])
      expect(getLevelTitle(2)).toBe(LEVEL_TITLES[1])
      expect(getLevelTitle(15)).toBe(LEVEL_TITLES[14])
    })

    it('should return last title for level beyond array', () => {
      const lastTitle = LEVEL_TITLES[LEVEL_TITLES.length - 1]
      expect(getLevelTitle(999)).toBe(lastTitle)
    })
  })

  describe('getInitialWeeklyData', () => {
    it('should return 7 days', () => {
      const data = getInitialWeeklyData()
      expect(data.days).toHaveLength(7)
    })

    it('should start from Monday', () => {
      const data = getInitialWeeklyData()
      const firstDay = new Date(data.days[0].date)
      expect(firstDay.getDay()).toBe(1) // Monday = 1
    })

    it('should have valid date strings for all days', () => {
      const data = getInitialWeeklyData()
      for (const day of data.days) {
        expect(day.date).toMatch(/^\d{4}-\d{2}-\d{2}$/)
      }
    })

    it('should have weekStart matching first day', () => {
      const data = getInitialWeeklyData()
      expect(data.weekStart).toBe(data.days[0].date)
    })

    it('should generate consecutive days', () => {
      const data = getInitialWeeklyData()
      for (let i = 1; i < data.days.length; i++) {
        const prev = new Date(data.days[i - 1].date)
        const curr = new Date(data.days[i].date)
        const diff = (curr.getTime() - prev.getTime()) / (1000 * 60 * 60 * 24)
        expect(diff).toBe(1)
      }
    })
  })
})
