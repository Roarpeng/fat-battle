import { describe, it, expect } from 'vitest'
import {
  calculateDamage,
  calculateOvereatCalories,
  calculateShieldFromOvereat,
  applyDamageToMonster,
  getXpToNextLevel,
  getLevelTitle,
  addXp,
  calculateBmi,
  generateMonster,
  updateMonsterPhase,
  isMonsterEnraged,
  getLast3DaysCompletionRate,
  analyzeUserPerformance,
  isConsecutiveDay,
  shouldGrantStreakShield,
  canUseStreakFreeze,
  canBuyStreakFreeze,
  shouldRefillStreakFreeze,
  refillStreakFreeze,
  shouldResetStreak,
} from '../index'
import type { WeeklyData } from '../../store/game-types'
import { LEVEL_TITLES, XP_BASE } from '../../store/game-constants'

// 辅助：构造 WeeklyData
function makeWeeklyData(days: { date: string; exercise?: number }[]): WeeklyData {
  return {
    weekStart: days[0]?.date ?? '2024-01-01',
    days: days.map((d) => ({ date: d.date, exercise: d.exercise })),
  }
}

// ============================================================
// damage.ts
// ============================================================

describe('calculateDamage', () => {
  it('应在赤字时给予 10% 加成', () => {
    // burn=2000 > food=500 → deficitBonus=1.1, normal → 1.0
    expect(calculateDamage(500, 2000, 'normal')).toBe(2200)
  })

  it('应在盈余时不给加成', () => {
    // burn=500 > food=2000? 否 → deficitBonus=1.0
    expect(calculateDamage(2000, 500, 'normal')).toBe(500)
  })

  it('难度 easy 应提升伤害（x1.3）', () => {
    expect(calculateDamage(500, 2000, 'easy')).toBe(2860) // 2000 * 1.3 * 1.1
  })

  it('难度 hard 应降低伤害（x0.7）', () => {
    expect(calculateDamage(500, 2000, 'hard')).toBe(1540) // 2000 * 0.7 * 1.1
  })

  it('难度 normal 倍率应为 1.0', () => {
    expect(calculateDamage(0, 1000, 'normal')).toBe(1100) // 赤字（1000>0）→ 1.1
  })

  it('运动消耗为 0 时伤害为 0', () => {
    expect(calculateDamage(0, 0, 'normal')).toBe(0)
    expect(calculateDamage(500, 0, 'normal')).toBe(0)
  })

  it('应将负输入归一化为 0', () => {
    expect(calculateDamage(-100, -50, 'normal')).toBe(0)
    expect(calculateDamage(-100, 200, 'normal')).toBe(220) // 200 * 1.0 * 1.1（200>0 赤字）
  })

  it('极大值不应产生 NaN', () => {
    const result = calculateDamage(0, Number.MAX_SAFE_INTEGER, 'normal')
    expect(Number.isFinite(result)).toBe(true)
    expect(result).toBeGreaterThan(0)
  })

  it('摄入与消耗相等时不算赤字', () => {
    expect(calculateDamage(1000, 1000, 'normal')).toBe(1000) // 不满足 burn > food
  })
})

describe('calculateOvereatCalories', () => {
  it('应返回超出目标的部分', () => {
    expect(calculateOvereatCalories(2500, 2000)).toBe(500)
  })

  it('未超过目标时返回 0', () => {
    expect(calculateOvereatCalories(1500, 2000)).toBe(0)
  })

  it('等于目标时返回 0', () => {
    expect(calculateOvereatCalories(2000, 2000)).toBe(0)
  })

  it('应将负输入归一化为 0', () => {
    expect(calculateOvereatCalories(-100, 2000)).toBe(0)
    expect(calculateOvereatCalories(2500, -100)).toBe(2500) // 目标归 0
    expect(calculateOvereatCalories(-100, -100)).toBe(0)
  })

  it('极大摄入值应正确计算', () => {
    expect(calculateOvereatCalories(1_000_000, 2000)).toBe(998_000)
  })
})

describe('calculateShieldFromOvereat', () => {
  it('默认比例 10:1 应正确转换', () => {
    expect(calculateShieldFromOvereat(100)).toBe(10)
    expect(calculateShieldFromOvereat(99)).toBe(9)
    expect(calculateShieldFromOvereat(10)).toBe(1)
  })

  it('不足 10 卡时向下取整为 0', () => {
    expect(calculateShieldFromOvereat(9)).toBe(0)
    expect(calculateShieldFromOvereat(1)).toBe(0)
  })

  it('0 或负值应返回 0', () => {
    expect(calculateShieldFromOvereat(0)).toBe(0)
    expect(calculateShieldFromOvereat(-50)).toBe(0)
  })

  it('应支持自定义比例', () => {
    expect(calculateShieldFromOvereat(100, 5)).toBe(20)
    expect(calculateShieldFromOvereat(100, 1)).toBe(100)
    expect(calculateShieldFromOvereat(100, 20)).toBe(5)
  })

  it('ratio <= 0 时应回退为默认 10', () => {
    expect(calculateShieldFromOvereat(100, 0)).toBe(10)
    expect(calculateShieldFromOvereat(100, -5)).toBe(10)
  })
})

describe('applyDamageToMonster', () => {
  // 使用 level 1 史莱姆：maxHp=100, shieldReductionRate=0.15
  function makeMonster(overrides: Partial<ReturnType<typeof generateMonster>> = {}) {
    const base = generateMonster(1, 'normal')
    return { ...base, ...overrides }
  }

  it('无护盾时应全额扣除 HP', () => {
    const m = makeMonster({ hp: 100, shield: 0 })
    const result = applyDamageToMonster(m, 30)
    expect(result.hp).toBe(70)
    expect(result.shield).toBe(0)
  })

  it('无护盾时伤害不应使 HP 降至负数', () => {
    const m = makeMonster({ hp: 50, shield: 0 })
    const result = applyDamageToMonster(m, 200)
    expect(result.hp).toBe(0)
    expect(result.shield).toBe(0)
  })

  it('有护盾时护盾承受全额伤害，本体受穿透伤害', () => {
    // shield=50, damage=30, reductionRate=0.15
    // newShield = 50-30 = 20（未破）
    // hpDamage = round(30 * 0.15) = round(4.5) = 5
    const m = makeMonster({ hp: 100, shield: 50 })
    const result = applyDamageToMonster(m, 30)
    expect(result.hp).toBe(95)
    expect(result.shield).toBe(20)
  })

  it('护盾击破时溢出伤害应额外打到本体', () => {
    // shield=50, damage=60, reductionRate=0.15
    // newShield = 50-60 = -10
    // hpDamage = round(60*0.15) = 9 → hp = 100-9 = 91
    // newShield < 0 → hp = max(0, 91 + (-10)) = 81, shield=0
    const m = makeMonster({ hp: 100, shield: 50 })
    const result = applyDamageToMonster(m, 60)
    expect(result.hp).toBe(81)
    expect(result.shield).toBe(0)
  })

  it('应一次性击杀（HP 归 0，护盾归 0）', () => {
    const m = makeMonster({ hp: 100, shield: 0 })
    const result = applyDamageToMonster(m, 100)
    expect(result.hp).toBe(0)
    expect(result.shield).toBe(0)
  })

  it('伤害为 0 时应返回等价状态副本', () => {
    const m = makeMonster({ hp: 100, shield: 50 })
    const result = applyDamageToMonster(m, 0)
    expect(result.hp).toBe(100)
    expect(result.shield).toBe(50)
    expect(result).not.toBe(m) // 新对象
    expect(result).toEqual(m) // 内容相等
  })

  it('负伤害应被视为 0（不修改状态内容）', () => {
    const m = makeMonster({ hp: 80, shield: 30 })
    const result = applyDamageToMonster(m, -50)
    expect(result.hp).toBe(80)
    expect(result.shield).toBe(30)
  })

  it('怪物已死亡时（hp=0）不应改变状态', () => {
    const m = makeMonster({ hp: 0, shield: 50 })
    const result = applyDamageToMonster(m, 100)
    expect(result.hp).toBe(0)
    expect(result.shield).toBe(50)
  })

  it('不应修改原始 monster 对象（纯函数）', () => {
    const m = makeMonster({ hp: 100, shield: 50 })
    const original = { ...m }
    applyDamageToMonster(m, 30)
    expect(m).toEqual(original)
  })
})

// ============================================================
// progression.ts
// ============================================================

describe('getXpToNextLevel', () => {
  it('level 1 应返回基础 XP', () => {
    expect(getXpToNextLevel(1)).toBe(XP_BASE)
    expect(getXpToNextLevel(1)).toBe(100)
  })

  it('XP 应随等级递增', () => {
    expect(getXpToNextLevel(2)).toBeGreaterThan(getXpToNextLevel(1))
    expect(getXpToNextLevel(5)).toBeGreaterThan(getXpToNextLevel(4))
  })

  it('level 5 应符合公式 floor(100 * 1.15^4)', () => {
    expect(getXpToNextLevel(5)).toBe(Math.floor(100 * Math.pow(1.15, 4)))
  })

  it('level 0 或负数应返回正整数（pow 指数为负）', () => {
    expect(getXpToNextLevel(0)).toBe(Math.floor(100 * Math.pow(1.15, -1)))
    expect(getXpToNextLevel(0)).toBeGreaterThan(0)
    expect(getXpToNextLevel(-1)).toBeGreaterThan(0)
  })

  it('非有限数应按 level 1 处理', () => {
    expect(getXpToNextLevel(NaN)).toBe(100)
  })
})

describe('getLevelTitle', () => {
  it('level 1 应返回首个称号', () => {
    expect(getLevelTitle(1)).toBe(LEVEL_TITLES[0])
  })

  it('应返回对应等级的称号', () => {
    expect(getLevelTitle(2)).toBe(LEVEL_TITLES[1])
    expect(getLevelTitle(15)).toBe(LEVEL_TITLES[14])
  })

  it('level <= 0 应返回首个称号', () => {
    expect(getLevelTitle(0)).toBe(LEVEL_TITLES[0])
    expect(getLevelTitle(-1)).toBe(LEVEL_TITLES[0])
    expect(getLevelTitle(-100)).toBe(LEVEL_TITLES[0])
  })

  it('level 超出范围应返回最后一个称号', () => {
    const last = LEVEL_TITLES[LEVEL_TITLES.length - 1]
    expect(getLevelTitle(LEVEL_TITLES.length)).toBe(last)
    expect(getLevelTitle(999)).toBe(last)
  })

  it('level 恰好等于表长应返回最后一个称号', () => {
    // LEVEL_TITLES.length = 15, level 16 > 15 → 最后一个
    expect(getLevelTitle(LEVEL_TITLES.length + 1)).toBe(LEVEL_TITLES[LEVEL_TITLES.length - 1])
  })
})

describe('addXp', () => {
  it('未达阈值时不应升级', () => {
    const result = addXp(0, 1, 50)
    expect(result.xp).toBe(50)
    expect(result.level).toBe(1)
    expect(result.levelsGained).toBe(0)
  })

  it('恰好达到阈值应升级且 XP 归 0', () => {
    // level 1 需要 100
    const result = addXp(0, 1, 100)
    expect(result.xp).toBe(0)
    expect(result.level).toBe(2)
    expect(result.levelsGained).toBe(1)
  })

  it('应支持连续升级', () => {
    // level 1 需要 floor(100 * 1.15^0) = 100
    // level 2 需要 floor(100 * 1.15^1) = floor(114.999...) = 114（浮点精度，与原 game-utils 一致）
    // 250 - 100 = 150 (lvl2), 150 - 114 = 36 (lvl3), 36 < 132 → 停
    const result = addXp(0, 1, 250)
    expect(result.level).toBe(3)
    expect(result.xp).toBe(36)
    expect(result.levelsGained).toBe(2)
  })

  it('amount 为 0 时不应改变状态', () => {
    const result = addXp(50, 3, 0)
    expect(result.xp).toBe(50)
    expect(result.level).toBe(3)
    expect(result.levelsGained).toBe(0)
  })

  it('负 amount 应将 XP 限制为 0，不降级', () => {
    const result = addXp(50, 3, -100)
    expect(result.xp).toBe(0)
    expect(result.level).toBe(3)
    expect(result.levelsGained).toBe(0)
  })

  it('currentLevel < 1 应按 1 处理', () => {
    const result = addXp(0, 0, 50)
    expect(result.level).toBe(1)
    expect(result.xp).toBe(50)
  })

  it('极大 amount 不应死循环', () => {
    const result = addXp(0, 1, 1_000_000)
    expect(result.level).toBeGreaterThan(1)
    expect(result.levelsGained).toBeGreaterThan(0)
    expect(result.xp).toBeGreaterThanOrEqual(0)
  })
})

describe('calculateBmi', () => {
  it('应正确计算 BMI（保留 1 位小数）', () => {
    // 70 / 1.75^2 = 22.857 → 22.9
    expect(calculateBmi(70, 175)).toBe(22.9)
    expect(calculateBmi(60, 170)).toBe(20.8)
    expect(calculateBmi(80, 180)).toBe(24.7)
  })

  it('身高 <= 0 应返回 0', () => {
    expect(calculateBmi(70, 0)).toBe(0)
    expect(calculateBmi(70, -10)).toBe(0)
  })

  it('体重为 0 应返回 0', () => {
    expect(calculateBmi(0, 170)).toBe(0)
  })

  it('极小身高应返回大数值', () => {
    const bmi = calculateBmi(70, 1)
    expect(bmi).toBeGreaterThan(0)
    expect(bmi).toBe(700000.0) // 70 / 0.01^2 = 700000
  })

  it('负体重应返回负 BMI', () => {
    expect(calculateBmi(-70, 175)).toBe(-22.9)
  })
})

// ============================================================
// monster.ts
// ============================================================

describe('generateMonster', () => {
  it('应生成结构完整的怪物', () => {
    const m = generateMonster(1)
    expect(m).toHaveProperty('hp')
    expect(m).toHaveProperty('maxHp')
    expect(m).toHaveProperty('level')
    expect(m).toHaveProperty('defId')
    expect(m).toHaveProperty('tier')
    expect(m).toHaveProperty('shield')
    expect(m).toHaveProperty('shieldReductionRate')
  })

  it('初始 HP 应等于 maxHp', () => {
    const m = generateMonster(1)
    expect(m.hp).toBe(m.maxHp)
  })

  it('初始护盾应为 0', () => {
    const m = generateMonster(1)
    expect(m.shield).toBe(0)
    expect(m.maxShield).toBe(0)
  })

  it('初始不应为狂暴状态', () => {
    const m = generateMonster(1)
    expect(m.isEnraged).toBe(false)
  })

  it('默认 isPhantom 应为 false', () => {
    expect(generateMonster(1).isPhantom).toBe(false)
  })

  it('应尊重 level 参数', () => {
    expect(generateMonster(5).level).toBe(5)
    expect(generateMonster(10).level).toBe(10)
  })

  it('应正确应用 hpMultiplier', () => {
    const m1 = generateMonster(1, 'normal', 1)
    const m2 = generateMonster(1, 'normal', 2)
    expect(m2.maxHp).toBe(m1.maxHp * 2)
  })

  it('easy 难度 HP 应低于 normal，hard 应高于 normal', () => {
    const easy = generateMonster(1, 'easy')
    const normal = generateMonster(1, 'normal')
    const hard = generateMonster(1, 'hard')
    expect(easy.maxHp).toBeLessThan(normal.maxHp)
    expect(hard.maxHp).toBeGreaterThan(normal.maxHp)
  })

  it('level 1 (slime) normal 应有正确的 maxHp', () => {
    // slime: baseHp=100, hpPerLevel=30 → 100 + 30*0 = 100
    expect(generateMonster(1, 'normal').maxHp).toBe(100)
  })

  it('level 10 应为 BOSS 且含阶段信息', () => {
    const boss = generateMonster(10)
    expect(boss.tier).toBe('boss')
    expect(boss.phaseName).toBeTruthy()
  })
})

describe('updateMonsterPhase', () => {
  const phases = [
    { name: '阶段A', hpThreshold: 1.0, emoji: '🅰️', damageBonus: 1.0, desc: '' },
    { name: '阶段B', hpThreshold: 0.5, emoji: '🅱️', damageBonus: 1.3, desc: '' },
  ]

  it('满血时应返回第一阶段', () => {
    const r = updateMonsterPhase(1.0, phases, 0.3)
    expect(r.phaseIndex).toBe(0)
    expect(r.phaseName).toBe('阶段A')
    expect(r.phaseEmoji).toBe('🅰️')
    expect(r.isEnraged).toBe(false)
  })

  it('HP 降到 0.5 阈值时应切换到第二阶段', () => {
    const r = updateMonsterPhase(0.5, phases, 0.3)
    expect(r.phaseIndex).toBe(1)
    expect(r.phaseName).toBe('阶段B')
  })

  it('HP 介于两阈值之间应保持第一阶段', () => {
    const r = updateMonsterPhase(0.6, phases, 0.3)
    expect(r.phaseIndex).toBe(0)
    expect(r.phaseName).toBe('阶段A')
  })

  it('HP 低于狂暴阈值应进入狂暴', () => {
    const r = updateMonsterPhase(0.3, phases, 0.3)
    expect(r.isEnraged).toBe(true)
  })

  it('HP 高于狂暴阈值不应狂暴', () => {
    const r = updateMonsterPhase(0.31, phases, 0.3)
    expect(r.isEnraged).toBe(false)
  })

  it('无阶段定义时应返回空阶段名，但仍判定狂暴', () => {
    const r = updateMonsterPhase(0.2, [], 0.3)
    expect(r.phaseIndex).toBe(0)
    expect(r.phaseName).toBe('')
    expect(r.isEnraged).toBe(true)
  })

  it('应使用默认狂暴阈值 0.3', () => {
    expect(updateMonsterPhase(0.3).isEnraged).toBe(true)
    expect(updateMonsterPhase(0.31).isEnraged).toBe(false)
  })

  it('0 HP 应判定为狂暴', () => {
    const r = updateMonsterPhase(0, phases, 0.3)
    expect(r.isEnraged).toBe(true)
  })
})

describe('isMonsterEnraged', () => {
  it('HP <= 阈值应返回 true', () => {
    expect(isMonsterEnraged(0.2)).toBe(true)
    expect(isMonsterEnraged(0.3)).toBe(true) // 边界：等于阈值
    expect(isMonsterEnraged(0)).toBe(true)
  })

  it('HP > 阈值应返回 false', () => {
    expect(isMonsterEnraged(0.31)).toBe(false)
    expect(isMonsterEnraged(0.5)).toBe(false)
    expect(isMonsterEnraged(1.0)).toBe(false)
  })

  it('应支持自定义阈值', () => {
    expect(isMonsterEnraged(0.2, 0.25)).toBe(true)
    expect(isMonsterEnraged(0.3, 0.25)).toBe(false)
  })

  it('默认阈值为 0.3', () => {
    expect(isMonsterEnraged(0.3)).toBe(true)
    expect(isMonsterEnraged(0.3, 0.3)).toBe(true)
  })
})

// ============================================================
// difficulty.ts
// ============================================================

describe('getLast3DaysCompletionRate', () => {
  it('null 数据应返回 0.5', () => {
    expect(getLast3DaysCompletionRate(null)).toBe(0.5)
  })

  it('空天数应返回 0.5', () => {
    expect(getLast3DaysCompletionRate(makeWeeklyData([]))).toBe(0.5)
  })

  it('最近 3 天全部完成应返回 1', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 45 },
      { date: '2024-01-01', exercise: 20 },
    ])
    expect(getLast3DaysCompletionRate(data)).toBe(1)
  })

  it('最近 3 天均无运动应返回 0', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 0 },
      { date: '2024-01-02', exercise: 0 },
      { date: '2024-01-01', exercise: 0 },
    ])
    expect(getLast3DaysCompletionRate(data)).toBe(0)
  })

  it('混合天数应正确计算比例', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 0 },
      { date: '2024-01-01', exercise: 20 },
    ])
    expect(getLast3DaysCompletionRate(data)).toBeCloseTo(2 / 3, 5)
  })

  it('只取最近 3 天（忽略更早的）', () => {
    const data = makeWeeklyData([
      { date: '2024-01-05', exercise: 30 },
      { date: '2024-01-04', exercise: 0 },
      { date: '2024-01-03', exercise: 0 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    expect(getLast3DaysCompletionRate(data)).toBeCloseTo(1 / 3, 5)
  })

  it('应按日期降序排序后再取', () => {
    const data = makeWeeklyData([
      { date: '2024-01-01', exercise: 30 },
      { date: '2024-01-03', exercise: 0 },
      { date: '2024-01-02', exercise: 0 },
    ])
    expect(getLast3DaysCompletionRate(data)).toBeCloseTo(1 / 3, 5)
  })

  it('应过滤掉日期为空的天数', () => {
    const data: WeeklyData = {
      weekStart: '2024-01-01',
      days: [
        { date: '2024-01-03', exercise: 30 },
        { date: '', exercise: 45 },
        { date: '2024-01-01', exercise: 20 },
      ],
    }
    expect(getLast3DaysCompletionRate(data)).toBe(1)
  })
})

describe('analyzeUserPerformance', () => {
  it('无数据时应返回默认值', () => {
    const r = analyzeUserPerformance(null, 0, 'normal', 24)
    expect(r.monsterHpMultiplier).toBe(1.0)
    expect(r.questTargetAdjustment).toBe(1.0)
    expect(r.suggestedDifficulty).toBe('normal')
  })

  it('streak >= 14 应建议 hard 且 HP 倍率 1.5', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    const r = analyzeUserPerformance(data, 14, 'normal', 24)
    expect(r.suggestedDifficulty).toBe('hard')
    expect(r.monsterHpMultiplier).toBe(1.5)
    expect(r.questTargetAdjustment).toBe(1.2)
  })

  it('完成率 > 0.8 且 streak >= 5 应提升难度', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    const r = analyzeUserPerformance(data, 5, 'normal', 24)
    expect(r.monsterHpMultiplier).toBe(1.2)
    expect(r.questTargetAdjustment).toBe(1.1)
  })

  it('完成率 < 0.5 应建议 easy', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 0 },
      { date: '2024-01-02', exercise: 0 },
      { date: '2024-01-01', exercise: 0 },
    ])
    const r = analyzeUserPerformance(data, 0, 'normal', 24)
    expect(r.suggestedDifficulty).toBe('easy')
    expect(r.monsterHpMultiplier).toBe(0.7)
    expect(r.questTargetAdjustment).toBe(0.7)
  })

  it('BMI > 28 应强制 easy（无论表现）', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    const r = analyzeUserPerformance(data, 14, 'hard', 30)
    expect(r.suggestedDifficulty).toBe('easy')
  })

  it('BMI < 22 且完成率 > 0.8 应建议 hard', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    const r = analyzeUserPerformance(data, 3, 'normal', 20)
    expect(r.suggestedDifficulty).toBe('hard')
  })

  it('monsterHpMultiplier 应限制在 [0.5, 1.5]', () => {
    const data = makeWeeklyData([
      { date: '2024-01-03', exercise: 30 },
      { date: '2024-01-02', exercise: 30 },
      { date: '2024-01-01', exercise: 30 },
    ])
    const r = analyzeUserPerformance(data, 100, 'normal', 20)
    expect(r.monsterHpMultiplier).toBeLessThanOrEqual(1.5)
    expect(r.monsterHpMultiplier).toBeGreaterThanOrEqual(0.5)
  })

  it('questTargetAdjustment 应限制在 [0.7, 1.3]', () => {
    const r = analyzeUserPerformance(null, 0, 'easy', 24)
    expect(r.questTargetAdjustment).toBeLessThanOrEqual(1.3)
    expect(r.questTargetAdjustment).toBeGreaterThanOrEqual(0.7)
  })

  it('应返回非空 message 字符串', () => {
    const r = analyzeUserPerformance(null, 0, 'normal', 24)
    expect(typeof r.message).toBe('string')
    expect(r.message.length).toBeGreaterThan(0)
  })
})

// ============================================================
// streak.ts
// ============================================================

describe('isConsecutiveDay', () => {
  it('前一天应判定为连续', () => {
    expect(isConsecutiveDay('2024-01-02', '2024-01-03')).toBe(true)
  })

  it('同一天应判定为不连续', () => {
    expect(isConsecutiveDay('2024-01-03', '2024-01-03')).toBe(false)
  })

  it('隔天应判定为不连续', () => {
    expect(isConsecutiveDay('2024-01-01', '2024-01-03')).toBe(false)
  })

  it('应正确处理跨月边界', () => {
    expect(isConsecutiveDay('2024-01-31', '2024-02-01')).toBe(true)
    // 2023 非闰年：2 月 28 日是 3 月 1 日的前一天
    expect(isConsecutiveDay('2023-02-28', '2023-03-01')).toBe(true)
    // 2024 闰年：2 月 29 日是 3 月 1 日的前一天
    expect(isConsecutiveDay('2024-02-29', '2024-03-01')).toBe(true)
  })

  it('应正确处理跨年边界', () => {
    expect(isConsecutiveDay('2023-12-31', '2024-01-01')).toBe(true)
  })

  it('空字符串应返回 false', () => {
    expect(isConsecutiveDay('', '2024-01-03')).toBe(false)
    expect(isConsecutiveDay('2024-01-02', '')).toBe(false)
    expect(isConsecutiveDay('', '')).toBe(false)
  })
})

describe('shouldGrantStreakShield', () => {
  it('streak 为 7 的倍数且无 shield 应授予', () => {
    expect(shouldGrantStreakShield(7, false)).toBe(true)
    expect(shouldGrantStreakShield(14, false)).toBe(true)
    expect(shouldGrantStreakShield(21, false)).toBe(true)
  })

  it('已有 shield 时不应授予', () => {
    expect(shouldGrantStreakShield(7, true)).toBe(false)
  })

  it('非 7 的倍数不应授予', () => {
    expect(shouldGrantStreakShield(6, false)).toBe(false)
    expect(shouldGrantStreakShield(8, false)).toBe(false)
  })

  it('streak <= 0 不应授予', () => {
    expect(shouldGrantStreakShield(0, false)).toBe(false)
    expect(shouldGrantStreakShield(-7, false)).toBe(false)
  })
})

describe('canUseStreakFreeze', () => {
  it('freeze > 0 且提示激活时应可使用', () => {
    expect(canUseStreakFreeze(1, true)).toBe(true)
    expect(canUseStreakFreeze(2, true)).toBe(true)
  })

  it('freeze 为 0 时不应可使用', () => {
    expect(canUseStreakFreeze(0, true)).toBe(false)
  })

  it('提示未激活时不应可使用', () => {
    expect(canUseStreakFreeze(1, false)).toBe(false)
  })

  it('负 freeze 数量应被拒绝', () => {
    expect(canUseStreakFreeze(-1, true)).toBe(false)
  })
})

describe('canBuyStreakFreeze', () => {
  it('freeze < 3 且金币 >= 50 应可购买', () => {
    expect(canBuyStreakFreeze(0, 50)).toBe(true)
    expect(canBuyStreakFreeze(2, 100)).toBe(true)
  })

  it('freeze >= 3 时不应可购买', () => {
    expect(canBuyStreakFreeze(3, 100)).toBe(false)
  })

  it('金币 < 50 时不应可购买', () => {
    expect(canBuyStreakFreeze(0, 49)).toBe(false)
    expect(canBuyStreakFreeze(0, 0)).toBe(false)
  })
})

describe('shouldRefillStreakFreeze', () => {
  it('周一且今日未补充应返回 true', () => {
    expect(shouldRefillStreakFreeze(1, '2024-01-01', '2024-01-08')).toBe(true)
  })

  it('周一但今日已补充应返回 false', () => {
    expect(shouldRefillStreakFreeze(1, '2024-01-08', '2024-01-08')).toBe(false)
  })

  it('非周一应返回 false', () => {
    expect(shouldRefillStreakFreeze(0, '', '2024-01-08')).toBe(false)
    expect(shouldRefillStreakFreeze(2, '', '2024-01-08')).toBe(false)
    expect(shouldRefillStreakFreeze(3, '', '2024-01-08')).toBe(false)
  })
})

describe('refillStreakFreeze', () => {
  it('应在 maxCount 上限内 +1', () => {
    expect(refillStreakFreeze(0)).toBe(1)
    expect(refillStreakFreeze(1)).toBe(2)
  })

  it('应被 maxCount 上限截断（默认 2）', () => {
    expect(refillStreakFreeze(2)).toBe(2)
    expect(refillStreakFreeze(5)).toBe(2)
  })

  it('应支持自定义 maxCount', () => {
    expect(refillStreakFreeze(0, 5)).toBe(1)
    expect(refillStreakFreeze(4, 5)).toBe(5)
    expect(refillStreakFreeze(5, 5)).toBe(5) // 已满
  })

  it('负数输入应正确处理', () => {
    expect(refillStreakFreeze(-1, 2)).toBe(0) // min(0, 2)
  })
})

describe('shouldResetStreak', () => {
  it('不连续 + streak>0 + 无shield + 无freeze 应重置', () => {
    expect(shouldResetStreak(false, 5, false, 0)).toBe(true)
  })

  it('连续时应不重置', () => {
    expect(shouldResetStreak(true, 5, false, 0)).toBe(false)
  })

  it('有 shield 保护时应不重置', () => {
    expect(shouldResetStreak(false, 5, true, 0)).toBe(false)
  })

  it('有可用 freeze 时应不重置（等待用户决定）', () => {
    expect(shouldResetStreak(false, 5, false, 1)).toBe(false)
    expect(shouldResetStreak(false, 5, false, 3)).toBe(false)
  })

  it('streak <= 0 时应不重置', () => {
    expect(shouldResetStreak(false, 0, false, 0)).toBe(false)
    expect(shouldResetStreak(false, -3, false, 0)).toBe(false)
  })

  it('同时有 shield 和 freeze 时应不重置', () => {
    expect(shouldResetStreak(false, 10, true, 2)).toBe(false)
  })
})
