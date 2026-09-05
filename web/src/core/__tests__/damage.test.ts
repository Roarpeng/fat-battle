import { describe, it, expect } from 'vitest'
import {
  calculateDamage,
  calculateShieldFromOvereat,
  applyDamageToMonster,
  generateMonster,
  isIntakeInCalorieBand,
} from '../index'
import type { MonsterState } from '../../store/game-types'

// 辅助：构造测试用怪物状态（level 1 史莱姆：shieldReductionRate=0.15）
function makeMonster(overrides: Partial<MonsterState> = {}): MonsterState {
  const base = generateMonster(1, 'normal')
  return { ...base, ...overrides }
}

// ============================================================
// calculateDamage —— 基础伤害（不传克制参数，向后兼容）
// ============================================================

describe('calculateDamage —— 基础伤害（不传克制参数）', () => {
  it('未传 targetCalories 时不再因赤字加伤，返回 number', () => {
    const result = calculateDamage(0, 1000, 'normal')
    expect(result).toBe(1000)
    expect(typeof result).toBe('number')
  })

  it('未打中预算带时不给加成', () => {
    expect(calculateDamage(2000, 500, 'normal')).toBe(500)
  })

  it('难度 easy 应提升伤害（×1.3）', () => {
    expect(calculateDamage(0, 1000, 'easy')).toBe(1300) // 1000 * 1.3
  })

  it('难度 hard 应降低伤害（×0.7）', () => {
    expect(calculateDamage(0, 1000, 'hard')).toBe(700) // 1000 * 0.7
  })

  it('运动消耗为 0 时伤害为 0', () => {
    expect(calculateDamage(0, 0, 'normal')).toBe(0)
    expect(calculateDamage(500, 0, 'normal')).toBe(0)
  })

  it('应将负输入归一化为 0', () => {
    expect(calculateDamage(-100, -50, 'normal')).toBe(0)
    expect(calculateDamage(-100, 200, 'normal')).toBe(200)
  })

  it('不传克制参数时返回类型应为 number（向后兼容）', () => {
    const result = calculateDamage(500, 2000, 'normal')
    expect(typeof result).toBe('number')
    expect(result).toBe(2000)
  })
})

describe('calculateDamage —— 热量预算带加成', () => {
  it('打中预算带给予 1.15 加成，吃得更少不会更高', () => {
    const target = 1800
    const inBand = calculateDamage(1800, 400, 'normal', target)
    const farBelow = calculateDamage(800, 400, 'normal', target)
    const farAbove = calculateDamage(2600, 400, 'normal', target)

    expect(inBand).toBeGreaterThan(farBelow)
    expect(inBand).toBeGreaterThan(farAbove)
    expect(farBelow).toBe(farAbove)
    expect(inBand).toBe(460) // 400 * 1.15
    expect(farBelow).toBe(400)
  })

  it('不再因 burn > food 额外加伤', () => {
    expect(calculateDamage(0, 1000, 'normal', 1800)).toBe(1000)
    expect(calculateDamage(1800, 1000, 'normal', 1800)).toBe(1150)
  })

  it('isIntakeInCalorieBand 半宽至少 100kcal', () => {
    expect(isIntakeInCalorieBand(1800, 1800)).toBe(true)
    expect(isIntakeInCalorieBand(1650, 1800)).toBe(true) // ±180
    expect(isIntakeInCalorieBand(1000, 1800)).toBe(false)
  })
})

// ============================================================
// calculateDamage —— 克制伤害（cardio vs strength → ×1.5）
// ============================================================

describe('calculateDamage —— 克制伤害（×1.5）', () => {
  it('cardio 运动克制 strength 属性怪物 → effectiveness=super, ×1.5', () => {
    // baseDamage = 1000；克制 ×1.5 → 1500
    const result = calculateDamage(0, 1000, 'normal', 'cardio', 'strength')
    expect(result.damage).toBe(1500)
    expect(result.effectiveness).toBe('super')
    expect(result.multiplier).toBe(1.5)
  })

  it('strength 运动克制 core 属性怪物 → effectiveness=super, ×1.5', () => {
    const result = calculateDamage(0, 1000, 'normal', 'strength', 'core')
    expect(result.damage).toBe(1500)
    expect(result.effectiveness).toBe('super')
    expect(result.multiplier).toBe(1.5)
  })

  it('core 运动克制 cardio 属性怪物 → effectiveness=super, ×1.5', () => {
    const result = calculateDamage(0, 1000, 'normal', 'core', 'cardio')
    expect(result.damage).toBe(1500)
    expect(result.effectiveness).toBe('super')
    expect(result.multiplier).toBe(1.5)
  })

  it('克制关系应覆盖三角循环全部三种', () => {
    const pairs: Array<['cardio' | 'strength' | 'core', 'cardio' | 'strength' | 'core']> = [
      ['cardio', 'strength'],
      ['strength', 'core'],
      ['core', 'cardio'],
    ]
    for (const [ex, aff] of pairs) {
      const result = calculateDamage(0, 1000, 'normal', ex, aff)
      expect(result.effectiveness).toBe('super')
      expect(result.multiplier).toBe(1.5)
    }
  })
})

// ============================================================
// calculateDamage —— 被克伤害（strength vs cardio → ×0.7）
// ============================================================

describe('calculateDamage —— 被克伤害（×0.7）', () => {
  it('strength 运动被 cardio 属性怪物克制 → effectiveness=weak, ×0.7', () => {
    const result = calculateDamage(0, 1000, 'normal', 'strength', 'cardio')
    expect(result.damage).toBe(700)
    expect(result.effectiveness).toBe('weak')
    expect(result.multiplier).toBe(0.7)
  })

  it('core 运动被 strength 属性怪物克制 → effectiveness=weak, ×0.7', () => {
    const result = calculateDamage(0, 1000, 'normal', 'core', 'strength')
    expect(result.damage).toBe(700)
    expect(result.effectiveness).toBe('weak')
    expect(result.multiplier).toBe(0.7)
  })

  it('cardio 运动被 core 属性怪物克制 → effectiveness=weak, ×0.7', () => {
    const result = calculateDamage(0, 1000, 'normal', 'cardio', 'core')
    expect(result.damage).toBe(700)
    expect(result.effectiveness).toBe('weak')
    expect(result.multiplier).toBe(0.7)
  })

  it('被克关系应覆盖三角循环反向全部三种', () => {
    const pairs: Array<['cardio' | 'strength' | 'core', 'cardio' | 'strength' | 'core']> = [
      ['strength', 'cardio'],
      ['core', 'strength'],
      ['cardio', 'core'],
    ]
    for (const [ex, aff] of pairs) {
      const result = calculateDamage(0, 1000, 'normal', ex, aff)
      expect(result.effectiveness).toBe('weak')
      expect(result.multiplier).toBe(0.7)
    }
  })
})

// ============================================================
// calculateDamage —— 同属性（cardio vs cardio → ×1.0）
// ============================================================

describe('calculateDamage —— 同属性/无克制关系（×1.0）', () => {
  it('cardio vs cardio → effectiveness=normal, ×1.0', () => {
    const result = calculateDamage(0, 1000, 'normal', 'cardio', 'cardio')
    expect(result.damage).toBe(1000)
    expect(result.effectiveness).toBe('normal')
    expect(result.multiplier).toBe(1.0)
  })

  it('strength vs strength → effectiveness=normal, ×1.0', () => {
    const result = calculateDamage(0, 1000, 'normal', 'strength', 'strength')
    expect(result.damage).toBe(1000)
    expect(result.effectiveness).toBe('normal')
    expect(result.multiplier).toBe(1.0)
  })

  it('core vs core → effectiveness=normal, ×1.0', () => {
    const result = calculateDamage(0, 1000, 'normal', 'core', 'core')
    expect(result.damage).toBe(1000)
    expect(result.effectiveness).toBe('normal')
    expect(result.multiplier).toBe(1.0)
  })
})

// ============================================================
// calculateDamage —— 难度倍率与克制倍率叠加
// ============================================================

describe('calculateDamage —— 难度倍率与克制倍率叠加', () => {
  it('easy(×1.3) + 克制(×1.5) 应正确叠加（无赤字加成）', () => {
    // baseDamage = round(1000 * 1.3) = 1300
    // finalDamage = round(1300 * 1.5) = 1950
    const result = calculateDamage(0, 1000, 'easy', 'cardio', 'strength')
    expect(result.damage).toBe(1950)
    expect(result.effectiveness).toBe('super')
    expect(result.multiplier).toBe(1.5)
  })

  it('hard(×0.7) + 被克(×0.7) 应正确叠加（无赤字加成）', () => {
    // baseDamage = round(1000 * 0.7) = 700
    // finalDamage = round(700 * 0.7) = 490
    const result = calculateDamage(0, 1000, 'hard', 'strength', 'cardio')
    expect(result.damage).toBe(490)
    expect(result.effectiveness).toBe('weak')
    expect(result.multiplier).toBe(0.7)
  })

  it('normal(×1.0) + 同属性(×1.0) 应等于基础伤害', () => {
    const result = calculateDamage(0, 1000, 'normal', 'cardio', 'cardio')
    expect(result.damage).toBe(1000)
    expect(result.effectiveness).toBe('normal')
    expect(result.multiplier).toBe(1.0)
  })

  it('克制参数下未打中预算带应正确计算', () => {
    const result = calculateDamage(2000, 500, 'normal', 'cardio', 'strength')
    expect(result.damage).toBe(750)
    expect(result.effectiveness).toBe('super')
  })

  it('克制系统不影响 0 伤害', () => {
    const result = calculateDamage(0, 0, 'normal', 'cardio', 'strength')
    expect(result.damage).toBe(0)
    expect(result.effectiveness).toBe('super')
    expect(result.multiplier).toBe(1.5)
  })
})

// ============================================================
// calculateShieldFromOvereat —— 护盾转换 10:1
// ============================================================

describe('calculateShieldFromOvereat —— 护盾转换 10:1', () => {
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

  it('典型暴食场景：过量 500 卡 → 50 护盾', () => {
    expect(calculateShieldFromOvereat(500)).toBe(50)
    expect(calculateShieldFromOvereat(1234)).toBe(123)
  })
})

// ============================================================
// applyDamageToMonster —— 护盾穿透伤害
// ============================================================

describe('applyDamageToMonster —— 护盾穿透伤害', () => {
  it('无护盾时应全额扣除 HP', () => {
    const m = makeMonster({ hp: 100, shield: 0 })
    const result = applyDamageToMonster(m, 30)
    expect(result.hp).toBe(70)
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

  it('伤害为 0 时应返回等价状态副本（不修改内容）', () => {
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

  it('高减伤率怪物护盾存在时穿透伤害应按比例降低', () => {
    // shieldReductionRate=0.3, shield=50, damage=30
    // hpDamage = round(30 * 0.3) = 9
    const m = makeMonster({ hp: 100, shield: 50, shieldReductionRate: 0.3 })
    const result = applyDamageToMonster(m, 30)
    expect(result.hp).toBe(91)
    expect(result.shield).toBe(20)
  })
})
