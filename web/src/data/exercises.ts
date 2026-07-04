import type { Exercise, ExerciseType } from '../types/game';

export const exercises: Exercise[] = [
  {
    id: 'running',
    type: 'running',
    name: '跑步',
    caloriesPerMinute: 10,
    emoji: '🏃',
    difficulty: 'medium',
    description: '最经典的有氧运动，有效燃烧脂肪，提升心肺功能。建议每次30分钟以上。',
    damagePerMinute: 8,
  },
  {
    id: 'swimming',
    type: 'swimming',
    name: '游泳',
    caloriesPerMinute: 12,
    emoji: '🏊',
    difficulty: 'medium',
    description: '全身运动，对关节冲击小，能有效锻炼全身肌肉，燃烧大量热量。',
    damagePerMinute: 10,
  },
  {
    id: 'cycling',
    type: 'cycling',
    name: '骑行',
    caloriesPerMinute: 8,
    emoji: '🚴',
    difficulty: 'easy',
    description: '低冲击有氧运动，适合各个年龄段，能有效锻炼腿部肌肉。',
    damagePerMinute: 6,
  },
  {
    id: 'hiit',
    type: 'hiit',
    name: 'HIIT',
    caloriesPerMinute: 15,
    emoji: '🔥',
    difficulty: 'hard',
    description: '高强度间歇训练，短时间内达到高强度燃脂效果，运动后持续燃脂。',
    damagePerMinute: 15,
  },
  {
    id: 'squat',
    type: 'squat',
    name: '深蹲',
    caloriesPerMinute: 6,
    emoji: '🦵',
    difficulty: 'medium',
    description: '力量训练之王，锻炼腿部和臀部肌肉，提升基础代谢率。',
    damagePerMinute: 7,
  },
  {
    id: 'pushup',
    type: 'pushup',
    name: '俯卧撑',
    caloriesPerMinute: 7,
    emoji: '💪',
    difficulty: 'medium',
    description: '经典的上肢力量训练，锻炼胸肌、肩部和核心肌群。',
    damagePerMinute: 8,
  },
  {
    id: 'plank',
    type: 'plank',
    name: '平板支撑',
    caloriesPerMinute: 5,
    emoji: '🧘',
    difficulty: 'easy',
    description: '核心训练动作，增强腹部和背部肌肉，改善体态。',
    damagePerMinute: 5,
  },
  {
    id: 'yoga',
    type: 'yoga',
    name: '瑜伽',
    caloriesPerMinute: 4,
    emoji: '🧘‍♀️',
    difficulty: 'easy',
    description: '舒缓身心的运动，提升柔韧性和平衡力，减轻压力。',
    damagePerMinute: 3,
  },
  {
    id: 'jumprope',
    type: 'jumprope',
    name: '跳绳',
    caloriesPerMinute: 13,
    emoji: '⏰',
    difficulty: 'hard',
    description: '高效的燃脂运动，协调全身，提升心肺功能和敏捷性。',
    damagePerMinute: 12,
  },
  {
    id: 'walking',
    type: 'walking',
    name: '快走',
    caloriesPerMinute: 5,
    emoji: '🚶',
    difficulty: 'easy',
    description: '最温和的运动方式，适合初学者和恢复训练，每天一万步有益健康。',
    damagePerMinute: 3,
  },
  {
    id: 'highknee',
    type: 'highknee',
    name: '高抬腿',
    caloriesPerMinute: 9,
    emoji: '🏃',
    difficulty: 'medium',
    description: '原地快速抬腿，有效锻炼心肺功能和腿部力量，快速提升心率。',
    damagePerMinute: 9,
  },
  {
    id: 'burpee',
    type: 'burpee',
    name: '波比跳',
    caloriesPerMinute: 12,
    emoji: '🔥',
    difficulty: 'hard',
    description: '全身燃脂动作，结合深蹲、俯卧撑和跳跃，高效燃烧热量。',
    damagePerMinute: 14,
  },
  {
    id: 'lunge',
    type: 'lunge',
    name: '弓步蹲',
    caloriesPerMinute: 7,
    emoji: '🦶',
    difficulty: 'medium',
    description: '锻炼腿部肌肉，特别是股四头肌和臀部，提升下肢力量和平衡。',
    damagePerMinute: 8,
  },
  {
    id: 'mountainclimber',
    type: 'mountainclimber',
    name: '登山跑',
    caloriesPerMinute: 10,
    emoji: '⛰️',
    difficulty: 'medium',
    description: '平板姿势交替提膝，锻炼核心和心肺功能，全身燃脂。',
    damagePerMinute: 11,
  },
];

export function getExerciseById(id: string): Exercise | undefined {
  return exercises.find((e) => e.id === id);
}

export function getExercisesByType(type: ExerciseType): Exercise | undefined {
  return exercises.find((e) => e.type === type);
}

export function getExercisesByDifficulty(
  difficulty: 'easy' | 'medium' | 'hard'
): Exercise[] {
  return exercises.filter((e) => e.difficulty === difficulty);
}

export function calculateCaloriesBurned(
  exercise: Exercise,
  duration: number,
  weight: number
): number {
  const met = exercise.caloriesPerMinute / 3.5;
  return Math.round((met * 3.5 * weight * duration) / 200);
}

export function calculateExerciseDamage(
  exercise: Exercise,
  duration: number,
  playerAttack: number
): number {
  const baseDamage = exercise.damagePerMinute * duration;
  const attackBonus = 1 + playerAttack / 100;
  return Math.round(baseDamage * attackBonus);
}

export function getRecommendedExercises(bmi: number): Exercise[] {
  if (bmi >= 30) {
    return exercises.filter((e) => e.difficulty === 'easy');
  } else if (bmi >= 25) {
    return exercises.filter(
      (e) => e.difficulty === 'easy' || e.difficulty === 'medium'
    );
  } else {
    return exercises;
  }
}

export function getExerciseSuggestion(
  availableTime: number,
  fitnessLevel: 'beginner' | 'intermediate' | 'advanced'
): Exercise[] {
  const sortedByEfficiency = [...exercises].sort(
    (a, b) => b.caloriesPerMinute - a.caloriesPerMinute
  );

  if (fitnessLevel === 'beginner') {
    return sortedByEfficiency.filter((e) => e.difficulty === 'easy');
  } else if (fitnessLevel === 'intermediate') {
    return sortedByEfficiency.filter(
      (e) => e.difficulty === 'easy' || e.difficulty === 'medium'
    );
  } else {
    return sortedByEfficiency;
  }
}
