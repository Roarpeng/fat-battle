import type { ExerciseType } from '../services/poseTypes'

/**
 * 运动质量评分共享层 —— 纯函数实现，为 poseService 集成做准备。
 *
 * 基于角度（深度）、稳定性（晃动）、节奏（速度）、对称性（左右平衡）四个维度
 * 综合评估单次动作质量，输出总分、等级、伤害加成与改进建议。
 *
 * 所有函数均为纯函数：无副作用、不依赖外部状态、相同输入产生相同输出。
 */

// ============================================================
// 类型定义
// ============================================================

/** 运动质量等级 */
export type QualityGrade = 'perfect' | 'good' | 'fair' | 'poor'

/** 质量评分结果 */
export interface QualityScore {
  total: number          // 总分 0-100
  grade: QualityGrade    // 等级
  depth: number          // 动作深度 0-100（幅度是否到位）
  stability: number      // 稳定性 0-100（是否晃动）
  tempo: number          // 节奏 0-100（速度是否合适）
  symmetry: number       // 对称性 0-100（左右是否平衡）
  feedback: string[]     // 改进建议
  damageBonus: number    // 伤害加成 0.8~1.5
}

/** 评分维度数据 */
export interface QualityMetrics {
  exerciseType: ExerciseType
  // 关节角度数据
  primaryAngle: number       // 主要关节角度（如深蹲的膝盖角度）
  targetAngleDeep: number   // 目标深度角度
  targetAngleShallow: number // 目标起始角度
  // 可选：对称性数据
  leftAngle?: number
  rightAngle?: number
  // 可选：速度数据
  repDurationMs?: number    // 本次动作耗时
  targetDurationMs?: number // 目标耗时
  // 可选：稳定性数据
  wobbleCount?: number      // 晃动次数
}

// ============================================================
// 各运动类型评分标准
// ============================================================

export const EXERCISE_STANDARDS: Record<
  ExerciseType,
  {
    targetAngleDeep: number
    targetAngleShallow: number
    targetDurationMs: number
    description: string
  }
> = {
  squat: {
    targetAngleDeep: 70,      // 蹲至大腿与地面平行或更低
    targetAngleShallow: 160,  // 站直
    targetDurationMs: 2000,   // 2秒一个完整动作
    description: '深蹲',
  },
  pushup: {
    targetAngleDeep: 90,      // 手肘90度
    targetAngleShallow: 150,  // 接近伸直
    targetDurationMs: 1500,
    description: '俯卧撑',
  },
  jumprope: {
    targetAngleDeep: 130,     // 落地时膝盖微屈
    targetAngleShallow: 170,  // 起跳时接近伸直
    targetDurationMs: 500,    // 快速节奏
    description: '跳绳',
  },
  highknee: {
    targetAngleDeep: 90,      // 膝盖抬至水平
    targetAngleShallow: 170,  // 站立时膝盖微屈
    targetDurationMs: 800,
    description: '高抬腿',
  },
  plank: {
    targetAngleDeep: 180,     // 身体直线（髋角 180°）
    targetAngleShallow: 180,  // 保持直线（静态动作无行程）
    targetDurationMs: 30000,  // 30秒保持为一个计数周期
    description: '平板支撑',
  },
  burpee: {
    targetAngleDeep: 70,      // 蹲下时膝盖角度
    targetAngleShallow: 170,  // 站立时
    targetDurationMs: 2500,   // 复合动作较慢
    description: '波比跳',
  },
  lunge: {
    targetAngleDeep: 90,      // 前腿膝盖 90 度
    targetAngleShallow: 170,  // 站立时
    targetDurationMs: 2000,
    description: '弓步蹲',
  },
  mountainclimber: {
    targetAngleDeep: 90,      // 收腿时膝盖角度
    targetAngleShallow: 160,  // 伸展时
    targetDurationMs: 600,    // 快速交替
    description: '登山者',
  },
}

// ============================================================
// 内部常量
// ============================================================

// 各维度权重：深度 40% + 稳定性 25% + 节奏 20% + 对称性 15%
const WEIGHT_DEPTH = 0.4
const WEIGHT_STABILITY = 0.25
const WEIGHT_TEMPO = 0.2
const WEIGHT_SYMMETRY = 0.15

// 等级对应的伤害加成
const DAMAGE_BONUS: Record<QualityGrade, number> = {
  perfect: 1.5,
  good: 1.2,
  fair: 1.0,
  poor: 0.8,
}

// ============================================================
// 各维度独立评分函数
// ============================================================

/**
 * 深度评分（0-100）。
 *
 * 对于动态动作（shallow ≠ deep）：以从起始角度（shallow）向目标深度角度（deep）
 * 的完成比例评分。分段映射，与设计规约一致：
 * - 100% 深度 → 100
 * - 90% 深度 → 80
 * - 70% 深度 → 50
 * - 0% 深度 → 0
 *
 * 对于静态保持型动作（shallow = deep，如平板支撑）：以 primaryAngle 与目标角度
 * 的偏差评分，每偏离 1° 扣 2 分。
 */
export function scoreDepth(metrics: QualityMetrics): number {
  const { primaryAngle, targetAngleDeep, targetAngleShallow } = metrics
  if (!Number.isFinite(primaryAngle)) return 0

  const range = targetAngleShallow - targetAngleDeep

  if (Math.abs(range) < 0.001) {
    // 静态保持型动作：以与目标角度的偏差评分
    const deviation = Math.abs(primaryAngle - targetAngleDeep)
    return Math.max(0, Math.min(100, Math.round(100 - deviation * 2)))
  }

  // 动态动作：完成比例
  const actualDepth = targetAngleShallow - primaryAngle
  const ratio = actualDepth / range
  const r = Math.max(0, Math.min(1, ratio))

  // 分段线性评分，匹配规约关键点：(100%,100) (90%,80) (70%,50) (0%,0)
  if (r >= 1) return 100
  if (r >= 0.9) return Math.round(80 + (r - 0.9) * 200) // 90% → 80, 100% → 100
  if (r >= 0.7) return Math.round(50 + (r - 0.7) * 150) // 70% → 50, 90% → 80
  return Math.round((r / 0.7) * 50) // 0% → 0, 70% → 50
}

/**
 * 稳定性评分（0-100）。
 * - wobbleCount = 0 → 100
 * - wobbleCount = 1 → 80
 * - wobbleCount = 2 → 60
 * - wobbleCount >= 3 → 40
 */
export function scoreStability(metrics: QualityMetrics): number {
  const wobble = metrics.wobbleCount ?? 0
  if (!Number.isFinite(wobble) || wobble <= 0) return 100
  if (wobble === 1) return 80
  if (wobble === 2) return 60
  return 40
}

/**
 * 节奏评分（0-100）。
 * - 过快（< 50% 目标耗时）→ 40（容易受伤）
 * - 偏离 ≤ 20% → 100
 * - 偏离 20%-40% → 80
 * - 偏离 > 40% → 60
 *
 * 缺少耗时数据时返回 100（不惩罚）。
 */
export function scoreTempo(metrics: QualityMetrics): number {
  const { repDurationMs, targetDurationMs } = metrics
  if (repDurationMs == null || targetDurationMs == null || targetDurationMs <= 0) {
    return 100
  }
  if (!Number.isFinite(repDurationMs) || repDurationMs < 0) return 60

  // 过快判定优先（容易受伤）
  if (repDurationMs < targetDurationMs * 0.5) return 40

  const deviation = Math.abs(repDurationMs - targetDurationMs) / targetDurationMs
  if (deviation <= 0.2) return 100
  if (deviation <= 0.4) return 80
  return 60
}

/**
 * 对称性评分（0-100）。
 * - 左右角度差 < 5° → 100
 * - 差 5°-10° → 80
 * - 差 10°-20° → 60
 * - 差 > 20° → 40
 *
 * 缺少左右角度数据时返回 100（不惩罚）。
 */
export function scoreSymmetry(metrics: QualityMetrics): number {
  const { leftAngle, rightAngle } = metrics
  if (leftAngle == null || rightAngle == null) return 100
  if (!Number.isFinite(leftAngle) || !Number.isFinite(rightAngle)) return 60

  const diff = Math.abs(leftAngle - rightAngle)
  if (diff < 5) return 100
  if (diff <= 10) return 80
  if (diff <= 20) return 60
  return 40
}

// ============================================================
// 等级与伤害加成
// ============================================================

/**
 * 等级判定。
 * - 90-100: perfect
 * - 75-89: good
 * - 60-74: fair
 * - < 60: poor
 */
export function gradeFromScore(score: number): QualityGrade {
  if (!Number.isFinite(score)) return 'poor'
  if (score >= 90) return 'perfect'
  if (score >= 75) return 'good'
  if (score >= 60) return 'fair'
  return 'poor'
}

/**
 * 伤害加成计算。
 * - perfect: ×1.5
 * - good: ×1.2
 * - fair: ×1.0
 * - poor: ×0.8
 */
export function damageBonusFromGrade(grade: QualityGrade): number {
  return DAMAGE_BONUS[grade]
}

// ============================================================
// 反馈建议
// ============================================================

/**
 * 生成针对性改进建议。
 * 依据各维度评分给出具体提示；当所有维度均良好时返回鼓励语。
 */
export function generateFeedback(metrics: QualityMetrics, score: QualityScore): string[] {
  const feedback: string[] = []
  const desc = EXERCISE_STANDARDS[metrics.exerciseType]?.description ?? '动作'

  if (score.depth < 70) {
    feedback.push(`${desc}深度不足，请尽量达到目标幅度`)
  }
  if (score.stability < 80) {
    feedback.push('身体晃动较大，注意保持核心稳定')
  }
  if (score.tempo < 80) {
    const tooFast =
      metrics.repDurationMs != null &&
      metrics.targetDurationMs != null &&
      metrics.targetDurationMs > 0 &&
      metrics.repDurationMs < metrics.targetDurationMs * 0.5
    if (tooFast) {
      feedback.push('动作过快，容易受伤，请放慢节奏')
    } else {
      feedback.push('动作节奏偏离目标，注意控制速度')
    }
  }
  if (score.symmetry < 80) {
    feedback.push('左右两侧不对称，注意保持平衡')
  }

  if (feedback.length === 0) {
    feedback.push('动作质量优秀，继续保持！')
  }
  return feedback
}

// ============================================================
// 主评分函数
// ============================================================

/**
 * 主评分函数：综合深度、稳定性、节奏、对称性得出总分与等级。
 *
 * 总分 = 深度×40% + 稳定性×25% + 节奏×20% + 对称性×15%。
 * 等级与伤害加成由总分派生，反馈建议由各维度评分派生。
 */
export function scoreExerciseQuality(metrics: QualityMetrics): QualityScore {
  const depth = scoreDepth(metrics)
  const stability = scoreStability(metrics)
  const tempo = scoreTempo(metrics)
  const symmetry = scoreSymmetry(metrics)

  const total = Math.round(
    depth * WEIGHT_DEPTH +
      stability * WEIGHT_STABILITY +
      tempo * WEIGHT_TEMPO +
      symmetry * WEIGHT_SYMMETRY,
  )
  const grade = gradeFromScore(total)
  const damageBonus = damageBonusFromGrade(grade)

  const partial = {
    total,
    grade,
    depth,
    stability,
    tempo,
    symmetry,
    damageBonus,
  }
  const feedback = generateFeedback(metrics, { ...partial, feedback: [] })

  return { ...partial, feedback }
}
