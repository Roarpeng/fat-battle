import type {
  BMIResult,
  BMICategory,
  UserProfile,
  Monster,
  Food,
  Exercise,
  GameState,
} from '../types/game';

export function calculateBMI(weight: number, height: number): number {
  if (height <= 0 || weight <= 0) return 0;
  const heightInMeters = height / 100;
  return Math.round((weight / (heightInMeters * heightInMeters)) * 10) / 10;
}

export function getBMICategory(bmi: number): BMIResult {
  let category: BMICategory;
  let categoryName: string;
  let color: string;
  let advice: string;

  if (bmi < 18.5) {
    category = 'underweight';
    categoryName = '偏瘦';
    color = '#3B82F6';
    advice = '您的体重偏轻，建议增加营养摄入，适当进行力量训练。';
  } else if (bmi < 24) {
    category = 'normal';
    categoryName = '正常';
    color = '#10B981';
    advice = '您的体重在健康范围内，请继续保持良好的饮食和运动习惯！';
  } else if (bmi < 28) {
    category = 'overweight';
    categoryName = '超重';
    color = '#F59E0B';
    advice = '您的体重略高，建议控制饮食，增加有氧运动，逐步减轻体重。';
  } else if (bmi < 32) {
    category = 'obese_class1';
    categoryName = '轻度肥胖';
    color = '#F97316';
    advice = '您属于轻度肥胖，建议制定科学的减重计划，坚持运动和饮食控制。';
  } else if (bmi < 37) {
    category = 'obese_class2';
    categoryName = '中度肥胖';
    color = '#EF4444';
    advice = '您属于中度肥胖，建议在专业指导下进行减重，注意预防肥胖相关疾病。';
  } else {
    category = 'obese_class3';
    categoryName = '重度肥胖';
    color = '#DC2626';
    advice = '您属于重度肥胖，强烈建议就医咨询，制定专业的减重治疗方案。';
  }

  return { bmi, category, categoryName, color, advice };
}

export function calculateBMR(user: UserProfile): number {
  const { weight, height, age, gender } = user;
  if (gender === 'male') {
    return Math.round(88.362 + 13.397 * weight + 4.799 * height - 5.677 * age);
  } else {
    return Math.round(447.593 + 9.247 * weight + 3.098 * height - 4.33 * age);
  }
}

export function calculateDailyCalorieNeeds(
  user: UserProfile,
  activityLevel: number = 1.375
): number {
  const bmr = calculateBMR(user);
  return Math.round(bmr * activityLevel);
}

export function calculateWeightLoss(caloriesDeficit: number): number {
  const caloriesPerKg = 7700;
  return Math.round((caloriesDeficit / caloriesPerKg) * 1000) / 1000;
}

export function calculateMonsterHp(
  baseHp: number,
  day: number,
  playerBmi: number
): number {
  const dayMultiplier = 1 + (day - 1) * 0.15;
  const bmiMultiplier = Math.max(0.8, Math.min(1.5, playerBmi / 22));
  return Math.round(baseHp * dayMultiplier * bmiMultiplier);
}

export function calculateMonsterAttack(
  baseAttack: number,
  day: number
): number {
  return Math.round(baseAttack * (1 + (day - 1) * 0.1));
}

export function calculateMonsterDefense(
  baseDefense: number,
  day: number
): number {
  return Math.round(baseDefense * (1 + (day - 1) * 0.08));
}

export function calculateFoodHpRestore(food: Food, playerMaxHp: number): number {
  const baseRestore = food.hpRestore;
  const maxRestore = Math.floor(playerMaxHp * 0.3);
  return Math.min(baseRestore, maxRestore);
}

export function calculateMealHpRestore(
  foods: Food[],
  playerMaxHp: number
): number {
  let totalHp = 0;
  for (const food of foods) {
    totalHp += calculateFoodHpRestore(food, playerMaxHp);
  }
  return Math.min(totalHp, Math.floor(playerMaxHp * 0.5));
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

export function calculateCaloriesBurned(
  exercise: Exercise,
  duration: number,
  weight: number
): number {
  const met = exercise.caloriesPerMinute / 3.5;
  return Math.round((met * 3.5 * weight * duration) / 200);
}

export function calculatePlayerDamage(
  monsterAttack: number,
  playerDefense: number
): number {
  const reduction = Math.min(0.8, playerDefense / 100);
  return Math.round(monsterAttack * (1 - reduction));
}

export function calculateTotalMealCalories(foods: Food[]): number {
  return foods.reduce((total, food) => total + food.calories, 0);
}

export function calculateDailyNetCalories(
  consumed: number,
  burned: number,
  bmr: number
): number {
  return consumed - burned - bmr;
}

export function calculateStreakDays(
  lastActiveDate: number,
  currentDate: number
): number {
  const oneDay = 24 * 60 * 60 * 1000;
  const diffDays = Math.floor(
    (currentDate - lastActiveDate) / oneDay
  );
  return Math.max(0, diffDays);
}

export function calculatePlayerMaxHp(baseHp: number, bmi: number): number {
  const bmiBonus = Math.max(0, (bmi - 18.5) * 10);
  return Math.round(baseHp + bmiBonus);
}

export function calculatePlayerAttack(baseAttack: number, bmi: number): number {
  const bmiFactor = Math.max(0.8, Math.min(1.2, 22 / bmi));
  return Math.round(baseAttack * bmiFactor);
}

export function calculatePlayerDefense(
  baseDefense: number,
  bmi: number
): number {
  const bmiBonus = Math.max(0, (bmi - 22) * 2);
  return Math.round(baseDefense + bmiBonus);
}

export function generateDailyMonster(
  day: number,
  playerBmi: number,
  monsters: Monster[]
): Monster | null {
  const availableMonsters = monsters.filter((m) => m.day <= day);
  if (availableMonsters.length === 0) return null;

  const monsterIndex = Math.min(
    Math.floor((day - 1) / 3),
    availableMonsters.length - 1
  );
  const baseMonster = availableMonsters[monsterIndex];

  return {
    ...baseMonster,
    id: `${baseMonster.type}-${day}-${Date.now()}`,
    maxHp: calculateMonsterHp(baseMonster.maxHp, day, playerBmi),
    currentHp: calculateMonsterHp(baseMonster.maxHp, day, playerBmi),
    attack: calculateMonsterAttack(baseMonster.attack, day),
    defense: calculateMonsterDefense(baseMonster.defense, day),
    level: Math.ceil(day / 3),
    day,
    isDefeated: false,
  };
}

export function initializeGameState(
  user: UserProfile,
  baseHp: number = 100,
  baseAttack: number = 10,
  baseDefense: number = 5
): GameState {
  const bmi = calculateBMI(user.weight, user.height);
  const playerMaxHp = calculatePlayerMaxHp(baseHp, bmi);
  const playerAttack = calculatePlayerAttack(baseAttack, bmi);
  const playerDefense = calculatePlayerDefense(baseDefense, bmi);

  return {
    user,
    currentMonster: null,
    day: 1,
    playerHp: playerMaxHp,
    playerMaxHp,
    playerAttack,
    playerDefense,
    monstersDefeated: 0,
    totalCaloriesConsumed: 0,
    totalCaloriesBurned: 0,
    totalWeightLost: 0,
    streakDays: 0,
    lastActiveDate: Date.now(),
    unlockedMonsters: ['slime'],
  };
}
