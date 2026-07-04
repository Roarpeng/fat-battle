export interface UserProfile {
  id: string;
  name: string;
  gender: 'male' | 'female';
  age: number;
  height: number;
  weight: number;
  targetWeight: number;
  avatar?: string;
  createdAt: number;
}

export interface BMIRecord {
  id: string;
  weight: number;
  bmi: number;
  date: number;
}

export type MonsterType =
  | 'slime'
  | 'goblin'
  | 'ghost'
  | 'skeleton'
  | 'orc'
  | 'vampire'
  | 'dragon'
  | 'boss';

export interface Monster {
  id: string;
  type: MonsterType;
  name: string;
  maxHp: number;
  currentHp: number;
  attack: number;
  defense: number;
  level: number;
  day: number;
  emoji: string;
  description: string;
  isDefeated: boolean;
}

export interface Food {
  id: string;
  name: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  servingSize: string;
  emoji: string;
  category: FoodCategory;
  hpRestore: number;
}

export type FoodCategory =
  | 'staple'
  | 'meat'
  | 'vegetable'
  | 'fruit'
  | 'snack'
  | 'drink'
  | 'fastfood'
  | 'chinese';

export interface MealRecord {
  id: string;
  foodIds: string[];
  totalCalories: number;
  mealType: 'breakfast' | 'lunch' | 'dinner' | 'snack';
  date: number;
  hpRestored: number;
}

export type ExerciseType =
  | 'running'
  | 'swimming'
  | 'cycling'
  | 'hiit'
  | 'squat'
  | 'pushup'
  | 'plank'
  | 'yoga'
  | 'jumprope'
  | 'walking'
  | 'highknee'
  | 'burpee'
  | 'lunge'
  | 'mountainclimber';

export interface Exercise {
  id: string;
  type: ExerciseType;
  name: string;
  caloriesPerMinute: number;
  emoji: string;
  difficulty: 'easy' | 'medium' | 'hard';
  description: string;
  damagePerMinute: number;
}

export interface ExerciseRecord {
  id: string;
  exerciseId: string;
  duration: number;
  caloriesBurned: number;
  damageDealt: number;
  date: number;
}

export interface WeightRecord {
  id: string;
  weight: number;
  date: number;
  bmi: number;
}

export interface GameState {
  user: UserProfile;
  currentMonster: Monster | null;
  day: number;
  playerHp: number;
  playerMaxHp: number;
  playerAttack: number;
  playerDefense: number;
  monstersDefeated: number;
  totalCaloriesConsumed: number;
  totalCaloriesBurned: number;
  totalWeightLost: number;
  streakDays: number;
  lastActiveDate: number;
  unlockedMonsters: MonsterType[];
}

export interface DailyStats {
  date: number;
  caloriesConsumed: number;
  caloriesBurned: number;
  meals: MealRecord[];
  exercises: ExerciseRecord[];
  monsterDamageDealt: number;
  monsterHpRestored: number;
  weight?: number;
  bmi?: number;
}

export type BMICategory =
  | 'underweight'
  | 'normal'
  | 'overweight'
  | 'obese_class1'
  | 'obese_class2'
  | 'obese_class3';

export interface BMIResult {
  bmi: number;
  category: BMICategory;
  categoryName: string;
  color: string;
  advice: string;
}
