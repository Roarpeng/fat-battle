import { describe, it, expect } from 'vitest'
import type { ExerciseType } from '../../services/poseTypes'
import {
  scoreExerciseQuality,
  scoreDepth,
  scoreStability,
  scoreTempo,
  scoreSymmetry,
  gradeFromScore,
  damageBonusFromGrade,
  generateFeedback,
  EXERCISE_STANDARDS,
  type QualityMetrics,
  type QualityScore,
} from '../exercise-quality'

// ============================================================
// 辅助构造函数
// ============================================================

/** 按 EXERCISE_STANDARDS 构造完美动作的 metrics */
function makePerfectMetrics(type: ExerciseType): QualityMetrics {
  const std = EXERCISE_STANDARDS[type]
  return {
    exerciseType: type,
    primaryAngle: std.targetAngleDeep,
    targetAngleDeep: std.targetAngleDeep,
    targetAngleShallow: std.targetAngleShallow,
    leftAngle: std.targetAngleDeep,
    rightAngle: std.targetAngleDeep,
    repDurationMs: std.targetDurationMs,
    targetDurationMs: std.targetDurationMs,
    wobbleCount: 0,
  }
}

/** 基于 squat 标准构造可覆盖各维度的 metrics */
function makeSquatMetrics(overrides: Partial<QualityMetrics> = {}): QualityMetrics {
  const std = EXERCISE_STANDARDS.squat
  return {
    exerciseType: 'squat',
    primaryAngle: std.targetAngleDeep,
    targetAngleDeep: std.targetAngleDeep,
    targetAngleShallow: std.targetAngleShallow,
    leftAngle: std.targetAngleDeep,
    rightAngle: std.targetAngleDeep,
    repDurationMs: std.targetDurationMs,
    targetDurationMs: std.targetDurationMs,
    wobbleCount: 0,
    ...overrides,
  }
}

/** 构造一个全 100 分的 QualityScore 用于 generateFeedback 测试 */
function makePerfectScore(overrides: Partial<QualityScore> = {}): QualityScore {
  return {
    total: 100,
    grade: 'perfect',
    depth: 100,
    stability: 100,
    tempo: 100,
    symmetry: 100,
    feedback: [],
    damageBonus: 1.5,
    ...overrides,
  }
}

// ============================================================
// EXERCISE_STANDARDS
// ============================================================

describe('EXERCISE_STANDARDS', () => {
  it('应覆盖全部 8 种运动类型', () => {
    const types: ExerciseType[] = [
      'squat', 'pushup', 'jumprope', 'highknee',
      'plank', 'burpee', 'lunge', 'mountainclimber',
    ]
    for (const t of types) {
      expect(EXERCISE_STANDARDS[t]).toBeDefined()
      expect(EXERCISE_STANDARDS[t].targetAngleDeep).toBeGreaterThanOrEqual(0)
      expect(EXERCISE_STANDARDS[t].targetAngleShallow).toBeGreaterThanOrEqual(0)
      expect(EXERCISE_STANDARDS[t].targetDurationMs).toBeGreaterThan(0)
      expect(EXERCISE_STANDARDS[t].description.length).toBeGreaterThan(0)
    }
  })

  it('squat 标准应符合规约', () => {
    expect(EXERCISE_STANDARDS.squat).toEqual({
      targetAngleDeep: 70,
      targetAngleShallow: 160,
      targetDurationMs: 2000,
      description: '深蹲',
    })
  })

  it('pushup 标准应符合规约', () => {
    expect(EXERCISE_STANDARDS.pushup.targetAngleDeep).toBe(90)
    expect(EXERCISE_STANDARDS.pushup.targetAngleShallow).toBe(150)
    expect(EXERCISE_STANDARDS.pushup.targetDurationMs).toBe(1500)
  })
})

// ============================================================
// scoreDepth
// ============================================================

describe('scoreDepth', () => {
  it('完全达到目标深度应得 100', () => {
    const m = makeSquatMetrics({ primaryAngle: 70 })
    expect(scoreDepth(m)).toBe(100)
  })

  it('超过目标深度应截断为 100', () => {
    const m = makeSquatMetrics({ primaryAngle: 50 })
    expect(scoreDepth(m)).toBe(100)
  })

  it('90% 深度应得 80', () => {
    // range = 160 - 70 = 90; primaryAngle = 79 → ratio = 81/90 = 0.9
    const m = makeSquatMetrics({ primaryAngle: 79 })
    expect(scoreDepth(m)).toBe(80)
  })

  it('70% 深度应得 50', () => {
    // primaryAngle = 97 → ratio = 63/90 = 0.7
    const m = makeSquatMetrics({ primaryAngle: 97 })
    expect(scoreDepth(m)).toBe(50)
  })

  it('50% 深度应在 50 以下（按分段函数衰减）', () => {
    // primaryAngle = 115 → ratio = 45/90 = 0.5 → round(0.5/0.7*50) = 36
    const m = makeSquatMetrics({ primaryAngle: 115 })
    expect(scoreDepth(m)).toBe(36)
  })

  it('起始角度（未下蹲）应得 0', () => {
    const m = makeSquatMetrics({ primaryAngle: 160 })
    expect(scoreDepth(m)).toBe(0)
  })

  it('反向超过起始角度应截断为 0', () => {
    const m = makeSquatMetrics({ primaryAngle: 180 })
    expect(scoreDepth(m)).toBe(0)
  })

  it('静态保持型动作（plank）应以偏差评分', () => {
    // plank: deep = shallow = 180
    const std = EXERCISE_STANDARDS.plank
    const base: QualityMetrics = {
      exerciseType: 'plank',
      primaryAngle: 180,
      targetAngleDeep: std.targetAngleDeep,
      targetAngleShallow: std.targetAngleShallow,
    }
    expect(scoreDepth(base)).toBe(100) // 完美直线
    // 偏差 5° → 100 - 5*2 = 90
    expect(scoreDepth({ ...base, primaryAngle: 175 })).toBe(90)
    // 偏差 10° → 80
    expect(scoreDepth({ ...base, primaryAngle: 190 })).toBe(80)
    // 偏差 50° → 0（截断）
    expect(scoreDepth({ ...base, primaryAngle: 130 })).toBe(0)
  })

  it('pushup 完美深度应得 100', () => {
    const std = EXERCISE_STANDARDS.pushup
    const m: QualityMetrics = {
      exerciseType: 'pushup',
      primaryAngle: std.targetAngleDeep,
      targetAngleDeep: std.targetAngleDeep,
      targetAngleShallow: std.targetAngleShallow,
    }
    expect(scoreDepth(m)).toBe(100)
  })

  it('非有限 primaryAngle 应返回 0', () => {
    const m = makeSquatMetrics({ primaryAngle: NaN })
    expect(scoreDepth(m)).toBe(0)
  })
})

// ============================================================
// scoreStability
// ============================================================

describe('scoreStability', () => {
  it('wobbleCount = 0 应得 100', () => {
    expect(scoreStability(makeSquatMetrics({ wobbleCount: 0 }))).toBe(100)
  })

  it('未提供 wobbleCount 应默认为 100', () => {
    const m = makeSquatMetrics()
    delete (m as Partial<QualityMetrics>).wobbleCount
    expect(scoreStability(m)).toBe(100)
  })

  it('wobbleCount = 1 应得 80', () => {
    expect(scoreStability(makeSquatMetrics({ wobbleCount: 1 }))).toBe(80)
  })

  it('wobbleCount = 2 应得 60', () => {
    expect(scoreStability(makeSquatMetrics({ wobbleCount: 2 }))).toBe(60)
  })

  it('wobbleCount >= 3 应得 40', () => {
    expect(scoreStability(makeSquatMetrics({ wobbleCount: 3 }))).toBe(40)
    expect(scoreStability(makeSquatMetrics({ wobbleCount: 10 }))).toBe(40)
  })

  it('负数 wobbleCount 应按 0 处理', () => {
    expect(scoreStability(makeSquatMetrics({ wobbleCount: -5 }))).toBe(100)
  })
})

// ============================================================
// scoreTempo
// ============================================================

describe('scoreTempo', () => {
  const target = 2000

  it('恰好等于目标耗时应得 100', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: target, targetDurationMs: target }))).toBe(100)
  })

  it('偏离 ≤ 20% 应得 100', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 2400, targetDurationMs: target }))).toBe(100) // +20%
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 1600, targetDurationMs: target }))).toBe(100) // -20%
  })

  it('偏离 20%-40% 应得 80', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 2500, targetDurationMs: target }))).toBe(80) // +25%
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 1400, targetDurationMs: target }))).toBe(80) // -30%
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 2800, targetDurationMs: target }))).toBe(80) // +40%（边界）
  })

  it('偏离 > 40% 应得 60', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 3000, targetDurationMs: target }))).toBe(60) // +50%
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 1100, targetDurationMs: target }))).toBe(60) // -45%（但非过快）
  })

  it('过快（< 50% 目标耗时）应得 40', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 999, targetDurationMs: target }))).toBe(40)
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 500, targetDurationMs: target }))).toBe(40)
  })

  it('恰好 50% 不算过快（deviation=0.5 > 0.4 → 60）', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: 1000, targetDurationMs: target }))).toBe(60)
  })

  it('缺少耗时数据应返回 100（不惩罚）', () => {
    const m = makeSquatMetrics()
    delete (m as Partial<QualityMetrics>).repDurationMs
    delete (m as Partial<QualityMetrics>).targetDurationMs
    expect(scoreTempo(m)).toBe(100)
  })

  it('targetDurationMs <= 0 应返回 100', () => {
    expect(scoreTempo(makeSquatMetrics({ targetDurationMs: 0, repDurationMs: 100 }))).toBe(100)
  })

  it('非有限 repDurationMs 应返回 60', () => {
    expect(scoreTempo(makeSquatMetrics({ repDurationMs: NaN, targetDurationMs: target }))).toBe(60)
  })
})

// ============================================================
// scoreSymmetry
// ============================================================

describe('scoreSymmetry', () => {
  it('左右角度差 < 5° 应得 100', () => {
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 74 }))).toBe(100) // diff=4
  })

  it('左右角度差 = 5° 应得 80（边界）', () => {
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 75 }))).toBe(80)
  })

  it('左右角度差 5°-10° 应得 80', () => {
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 80 }))).toBe(80) // diff=10
  })

  it('左右角度差 10°-20° 应得 60', () => {
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 81 }))).toBe(60) // diff=11
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 90 }))).toBe(60) // diff=20（边界）
  })

  it('左右角度差 > 20° 应得 40', () => {
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 91 }))).toBe(40) // diff=21
    expect(scoreSymmetry(makeSquatMetrics({ leftAngle: 70, rightAngle: 100 }))).toBe(40) // diff=30
  })

  it('缺少左右角度数据应返回 100（不惩罚）', () => {
    const m = makeSquatMetrics()
    delete (m as Partial<QualityMetrics>).leftAngle
    delete (m as Partial<QualityMetrics>).rightAngle
    expect(scoreSymmetry(m)).toBe(100)
  })

  it('只提供一侧角度应返回 100', () => {
    const m = makeSquatMetrics()
    delete (m as Partial<QualityMetrics>).rightAngle
    expect(scoreSymmetry(m)).toBe(100)
  })
})

// ============================================================
// gradeFromScore
// ============================================================

describe('gradeFromScore', () => {
  it('90 分应为 perfect（边界）', () => {
    expect(gradeFromScore(90)).toBe('perfect')
  })

  it('100 分应为 perfect', () => {
    expect(gradeFromScore(100)).toBe('perfect')
  })

  it('89 分应为 good（边界）', () => {
    expect(gradeFromScore(89)).toBe('good')
  })

  it('75 分应为 good（边界）', () => {
    expect(gradeFromScore(75)).toBe('good')
  })

  it('74 分应为 fair（边界）', () => {
    expect(gradeFromScore(74)).toBe('fair')
  })

  it('60 分应为 fair（边界）', () => {
    expect(gradeFromScore(60)).toBe('fair')
  })

  it('59 分应为 poor（边界）', () => {
    expect(gradeFromScore(59)).toBe('poor')
  })

  it('0 分应为 poor', () => {
    expect(gradeFromScore(0)).toBe('poor')
  })

  it('非有限数应返回 poor', () => {
    expect(gradeFromScore(NaN)).toBe('poor')
    expect(gradeFromScore(Infinity)).toBe('poor')
  })
})

// ============================================================
// damageBonusFromGrade
// ============================================================

describe('damageBonusFromGrade', () => {
  it('perfect 应 ×1.5', () => {
    expect(damageBonusFromGrade('perfect')).toBe(1.5)
  })

  it('good 应 ×1.2', () => {
    expect(damageBonusFromGrade('good')).toBe(1.2)
  })

  it('fair 应 ×1.0', () => {
    expect(damageBonusFromGrade('fair')).toBe(1.0)
  })

  it('poor 应 ×0.8', () => {
    expect(damageBonusFromGrade('poor')).toBe(0.8)
  })
})

// ============================================================
// 每种运动的完美动作评分
// ============================================================

describe('scoreExerciseQuality - 每种运动完美动作', () => {
  const types: ExerciseType[] = [
    'squat', 'pushup', 'jumprope', 'highknee',
    'plank', 'burpee', 'lunge', 'mountainclimber',
  ]

  for (const type of types) {
    it(`${type} 完美动作应得满分 100 且为 perfect 等级`, () => {
      const result = scoreExerciseQuality(makePerfectMetrics(type))
      expect(result.depth).toBe(100)
      expect(result.stability).toBe(100)
      expect(result.tempo).toBe(100)
      expect(result.symmetry).toBe(100)
      expect(result.total).toBe(100)
      expect(result.grade).toBe('perfect')
      expect(result.damageBonus).toBe(1.5)
    })
  }

  it('完美动作的反馈应包含鼓励语', () => {
    const result = scoreExerciseQuality(makePerfectMetrics('squat'))
    expect(result.feedback).toEqual(['动作质量优秀，继续保持！'])
  })
})

// ============================================================
// scoreExerciseQuality - 综合评分
// ============================================================

describe('scoreExerciseQuality - 综合', () => {
  it('深度不足但其他完美应得 good', () => {
    // squat: primaryAngle = 97 → depth = 50；其他全 100
    const m = makeSquatMetrics({ primaryAngle: 97 })
    const result = scoreExerciseQuality(m)
    expect(result.depth).toBe(50)
    expect(result.stability).toBe(100)
    expect(result.tempo).toBe(100)
    expect(result.symmetry).toBe(100)
    // total = 50*0.4 + 100*0.25 + 100*0.2 + 100*0.15 = 20 + 25 + 20 + 15 = 80
    expect(result.total).toBe(80)
    expect(result.grade).toBe('good')
    expect(result.damageBonus).toBe(1.2)
  })

  it('仅稳定性差（wobble=2）应得 good', () => {
    const m = makeSquatMetrics({ wobbleCount: 2 })
    const result = scoreExerciseQuality(m)
    expect(result.stability).toBe(60)
    // total = 100*0.4 + 60*0.25 + 100*0.2 + 100*0.15 = 40 + 15 + 20 + 15 = 90
    expect(result.total).toBe(90)
    expect(result.grade).toBe('perfect')
  })

  it('仅节奏过快应得 good', () => {
    // squat targetDuration=2000，repDuration=500（过快）
    const m = makeSquatMetrics({ repDurationMs: 500 })
    const result = scoreExerciseQuality(m)
    expect(result.tempo).toBe(40)
    // total = 100*0.4 + 100*0.25 + 40*0.2 + 100*0.15 = 40 + 25 + 8 + 15 = 88
    expect(result.total).toBe(88)
    expect(result.grade).toBe('good')
  })

  it('仅对称性差应得 perfect', () => {
    // diff = 30 → symmetry = 40
    const m = makeSquatMetrics({ leftAngle: 70, rightAngle: 100 })
    const result = scoreExerciseQuality(m)
    expect(result.symmetry).toBe(40)
    // total = 100*0.4 + 100*0.25 + 100*0.2 + 40*0.15 = 40 + 25 + 20 + 6 = 91
    expect(result.total).toBe(91)
    expect(result.grade).toBe('perfect')
  })

  it('全维度差应得 poor', () => {
    const m = makeSquatMetrics({
      primaryAngle: 160, // depth = 0
      wobbleCount: 5,     // stability = 40
      repDurationMs: 100, // tempo = 40（过快）
      leftAngle: 70,
      rightAngle: 100,    // symmetry = 40
    })
    const result = scoreExerciseQuality(m)
    expect(result.depth).toBe(0)
    expect(result.stability).toBe(40)
    expect(result.tempo).toBe(40)
    expect(result.symmetry).toBe(40)
    // total = 0*0.4 + 40*0.25 + 40*0.2 + 40*0.15 = 0 + 10 + 8 + 6 = 24
    expect(result.total).toBe(24)
    expect(result.grade).toBe('poor')
    expect(result.damageBonus).toBe(0.8)
  })

  it('应返回与子评分一致的字段', () => {
    const m = makeSquatMetrics({ primaryAngle: 79, wobbleCount: 1 })
    const result = scoreExerciseQuality(m)
    expect(result.depth).toBe(scoreDepth(m))
    expect(result.stability).toBe(scoreStability(m))
    expect(result.tempo).toBe(scoreTempo(m))
    expect(result.symmetry).toBe(scoreSymmetry(m))
  })

  it('不应修改输入 metrics（纯函数）', () => {
    const m = makeSquatMetrics({ primaryAngle: 79, wobbleCount: 1 })
    const snapshot = { ...m }
    scoreExerciseQuality(m)
    expect(m).toEqual(snapshot)
  })
})

// ============================================================
// generateFeedback
// ============================================================

describe('generateFeedback', () => {
  it('全维度满分应返回鼓励语', () => {
    const m = makePerfectMetrics('squat')
    const fb = generateFeedback(m, makePerfectScore())
    expect(fb).toEqual(['动作质量优秀，继续保持！'])
  })

  it('深度不足应包含深度建议', () => {
    const m = makeSquatMetrics({ primaryAngle: 160 }) // depth = 0
    const fb = generateFeedback(m, makePerfectScore({ depth: 0 }))
    expect(fb.some((s) => s.includes('深蹲深度不足'))).toBe(true)
  })

  it('稳定性差应包含稳定性建议', () => {
    const m = makeSquatMetrics({ wobbleCount: 3 })
    const fb = generateFeedback(m, makePerfectScore({ stability: 40 }))
    expect(fb.some((s) => s.includes('晃动'))).toBe(true)
  })

  it('节奏过快应包含过快建议', () => {
    const m = makeSquatMetrics({ repDurationMs: 500, targetDurationMs: 2000 })
    const fb = generateFeedback(m, makePerfectScore({ tempo: 40 }))
    expect(fb.some((s) => s.includes('过快'))).toBe(true)
  })

  it('节奏过慢应包含节奏建议（不含"过快"）', () => {
    const m = makeSquatMetrics({ repDurationMs: 4000, targetDurationMs: 2000 })
    const fb = generateFeedback(m, makePerfectScore({ tempo: 60 }))
    expect(fb.some((s) => s.includes('节奏偏离'))).toBe(true)
    expect(fb.some((s) => s.includes('过快'))).toBe(false)
  })

  it('对称性差应包含对称性建议', () => {
    const m = makeSquatMetrics({ leftAngle: 70, rightAngle: 100 })
    const fb = generateFeedback(m, makePerfectScore({ symmetry: 40 }))
    expect(fb.some((s) => s.includes('不对称'))).toBe(true)
  })

  it('多个维度差应返回多条建议', () => {
    const m = makeSquatMetrics({
      primaryAngle: 160,
      wobbleCount: 3,
      repDurationMs: 500,
      leftAngle: 70,
      rightAngle: 100,
    })
    const fb = generateFeedback(m, makePerfectScore({ depth: 0, stability: 40, tempo: 40, symmetry: 40 }))
    expect(fb.length).toBe(4)
    expect(fb.some((s) => s.includes('深度不足'))).toBe(true)
    expect(fb.some((s) => s.includes('晃动'))).toBe(true)
    expect(fb.some((s) => s.includes('过快'))).toBe(true)
    expect(fb.some((s) => s.includes('不对称'))).toBe(true)
  })

  it('pushup 深度不足应使用俯卧撑描述', () => {
    const std = EXERCISE_STANDARDS.pushup
    const m: QualityMetrics = {
      exerciseType: 'pushup',
      primaryAngle: std.targetAngleShallow, // 未下压
      targetAngleDeep: std.targetAngleDeep,
      targetAngleShallow: std.targetAngleShallow,
    }
    const fb = generateFeedback(m, makePerfectScore({ depth: 0 }))
    expect(fb.some((s) => s.includes('俯卧撑深度不足'))).toBe(true)
  })

  it('scoreExerciseQuality 集成后反馈应正确生成', () => {
    const m = makeSquatMetrics({ primaryAngle: 160, wobbleCount: 3 })
    const result = scoreExerciseQuality(m)
    expect(result.feedback.some((s) => s.includes('深度不足'))).toBe(true)
    expect(result.feedback.some((s) => s.includes('晃动'))).toBe(true)
  })
})
