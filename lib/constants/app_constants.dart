import 'package:flutter/material.dart';

// 主题颜色
class AppColors {
  static const Color bg = Color(0xFF1a1a2e);
  static const Color bg2 = Color(0xFF16213e);
  static const Color bg3 = Color(0xFF0f3460);
  static const Color red = Color(0xFFff6b6b);
  static const Color gold = Color(0xFFffd93d);
  static const Color green = Color(0xFF2ecc71);
  static const Color purple = Color(0xFF667eea);
  static const Color text = Color(0xFFe0e0e0);
  static const Color text2 = Color(0xFFa0a0b0);
  static const Color card = Color(0xFF1e2a4a);
  static const Color border = Color(0xFF2a3a5a);
}

// 怪物配置
class MonsterConfig {
  final String name;
  final String emoji;
  final int baseHp;
  final double healBonus;
  final bool isBoss;

  const MonsterConfig({
    required this.name,
    required this.emoji,
    required this.baseHp,
    this.healBonus = 0,
    this.isBoss = false,
  });
}

class Monsters {
  static const List<MonsterConfig> all = [
    MonsterConfig(name: '贪吃史莱姆', emoji: '👾', baseHp: 100),
    MonsterConfig(name: '暴食哥布林', emoji: '👺', baseHp: 150),
    MonsterConfig(name: '馋嘴幽灵', emoji: '👻', baseHp: 180, healBonus: 0.2),
    MonsterConfig(name: '脂肪巨魔', emoji: '👹', baseHp: 300, isBoss: true),
    MonsterConfig(name: '卡路里恶魔', emoji: '😈', baseHp: 200),
    MonsterConfig(name: '肥胖龙王', emoji: '🐉', baseHp: 500, isBoss: true),
  ];
}

// 快捷食物
class QuickFood {
  final String name;
  final int cal;

  const QuickFood({required this.name, required this.cal});
}

class QuickFoods {
  static const List<QuickFood> breakfast = [
    QuickFood(name: '白粥', cal: 150),
    QuickFood(name: '鸡蛋', cal: 80),
    QuickFood(name: '牛奶', cal: 120),
    QuickFood(name: '面包', cal: 180),
    QuickFood(name: '豆浆', cal: 90),
    QuickFood(name: '油条', cal: 230),
    QuickFood(name: '包子', cal: 200),
  ];

  static const List<QuickFood> lunch = [
    QuickFood(name: '米饭', cal: 230),
    QuickFood(name: '鸡腿', cal: 180),
    QuickFood(name: '炒青菜', cal: 80),
    QuickFood(name: '红烧肉', cal: 350),
    QuickFood(name: '鱼', cal: 120),
    QuickFood(name: '面条', cal: 280),
    QuickFood(name: '沙拉', cal: 100),
  ];

  static const List<QuickFood> dinner = [
    QuickFood(name: '粥', cal: 120),
    QuickFood(name: '蒸鱼', cal: 150),
    QuickFood(name: '蔬菜', cal: 60),
    QuickFood(name: '豆腐', cal: 80),
    QuickFood(name: '水果', cal: 80),
    QuickFood(name: '酸奶', cal: 100),
  ];

  static const List<QuickFood> snack = [
    QuickFood(name: '奶茶', cal: 400),
    QuickFood(name: '薯片', cal: 280),
    QuickFood(name: '可乐', cal: 140),
    QuickFood(name: '饼干', cal: 150),
    QuickFood(name: '坚果', cal: 180),
    QuickFood(name: '巧克力', cal: 220),
  ];
}

// 运动类型
class ExerciseType {
  final String name;
  final String emoji;
  final int calPerMin;
  final String type;
  final bool supportCamera;

  const ExerciseType({
    required this.name,
    required this.emoji,
    required this.calPerMin,
    required this.type,
    this.supportCamera = false,
  });
}

class Exercises {
  static const List<ExerciseType> all = [
    ExerciseType(name: '俯卧撑', emoji: '💪', calPerMin: 8, type: 'pushup', supportCamera: true),
    ExerciseType(name: '深蹲', emoji: '🦵', calPerMin: 7, type: 'squat', supportCamera: true),
    ExerciseType(name: '开合跳', emoji: '⏭️', calPerMin: 10, type: 'jumping_jack', supportCamera: true),
    ExerciseType(name: '跑步', emoji: '🏃', calPerMin: 10, type: 'running'),
    ExerciseType(name: '快走', emoji: '🚶', calPerMin: 6, type: 'walking'),
    ExerciseType(name: '骑行', emoji: '🚴', calPerMin: 8, type: 'cycling'),
    ExerciseType(name: '游泳', emoji: '🏊', calPerMin: 11, type: 'swimming'),
    ExerciseType(name: '瑜伽', emoji: '🧘', calPerMin: 4, type: 'yoga'),
    ExerciseType(name: 'HIIT', emoji: '🔥', calPerMin: 14, type: 'hiit'),
    ExerciseType(name: '跳绳', emoji: '⏭️', calPerMin: 12, type: 'jumprope'),
    ExerciseType(name: '力量训练', emoji: '🏋️', calPerMin: 7, type: 'strength'),
  ];
}

// 成就
class Achievement {
  final String id;
  final String name;
  final String desc;
  final String emoji;

  const Achievement({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
  });
}

class Achievements {
  static const List<Achievement> all = [
    Achievement(id: 'first_kill', name: '初次胜利', desc: '击败第一个怪物', emoji: '🎖️'),
    Achievement(id: 'kill_5', name: '怪物猎人', desc: '击败5个怪物', emoji: '⚔️'),
    Achievement(id: 'kill_10', name: '屠魔勇士', desc: '击败10个怪物', emoji: '🗡️'),
    Achievement(id: 'streak_3', name: '三日连胜', desc: '连续3天完成目标', emoji: '🔥'),
    Achievement(id: 'streak_7', name: '一周坚持', desc: '连续7天完成目标', emoji: '⭐'),
    Achievement(id: 'streak_30', name: '月度传奇', desc: '连续30天完成目标', emoji: '👑'),
    Achievement(id: 'exercise_1000', name: '千卡战士', desc: '单日消耗1000千卡', emoji: '💪'),
    Achievement(id: 'coins_1000', name: '小富翁', desc: '累计1000金币', emoji: '💰'),
    Achievement(id: 'boss_kill', name: '弑龙者', desc: '击败一个Boss', emoji: '🐉'),
    Achievement(id: 'weight_5', name: '减重5kg', desc: '减掉5公斤', emoji: '🎯'),
    Achievement(id: 'day_7', name: '一周勇士', desc: '坚持7天', emoji: '📅'),
    Achievement(id: 'day_30', name: '月度英雄', desc: '坚持30天', emoji: '🗓️'),
  ];
}

// 商店物品
class ShopItem {
  final String id;
  final String name;
  final String desc;
  final String emoji;
  final int price;

  const ShopItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
    required this.price,
  });
}

class ShopItems {
  static const List<ShopItem> all = [
    ShopItem(id: 'avatar', name: '新角色形象', desc: '解锁更多角色选择', emoji: '🎭', price: 500),
    ShopItem(id: 'skin', name: '怪物皮肤', desc: '改变怪物外观', emoji: '🎨', price: 300),
    ShopItem(id: 'voice', name: '语音包', desc: '战斗音效增强', emoji: '🔊', price: 400),
    ShopItem(id: 'checkin', name: '补签卡', desc: '补签一天连续记录', emoji: '🎫', price: 200),
  ];
}

// 餐类型
enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeExt on MealType {
  String get name {
    switch (this) {
      case MealType.breakfast: return '早餐';
      case MealType.lunch: return '午餐';
      case MealType.dinner: return '晚餐';
      case MealType.snack: return '零食';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast: return '🌅';
      case MealType.lunch: return '☀️';
      case MealType.dinner: return '🌙';
      case MealType.snack: return '🍿';
    }
  }
}

// 食物分量
enum FoodSize { small, medium, large }

extension FoodSizeExt on FoodSize {
  String get name {
    switch (this) {
      case FoodSize.small: return '小份';
      case FoodSize.medium: return '中份';
      case FoodSize.large: return '大份';
    }
  }

  double get multiplier {
    switch (this) {
      case FoodSize.small: return 0.7;
      case FoodSize.medium: return 1.0;
      case FoodSize.large: return 1.3;
    }
  }
}

// 难度
enum Difficulty { easy, normal, hard }

extension DifficultyExt on Difficulty {
  String get name {
    switch (this) {
      case Difficulty.easy: return '简单';
      case Difficulty.normal: return '普通';
      case Difficulty.hard: return '困难';
    }
  }
}

// 作息类型
enum SleepType { early, normal, night }

extension SleepTypeExt on SleepType {
  String get name {
    switch (this) {
      case SleepType.early: return '早睡早起';
      case SleepType.normal: return '标准作息';
      case SleepType.night: return '夜猫子';
    }
  }
}

// 办公方式
enum WorkType { sedentary, sometimes, active }

extension WorkTypeExt on WorkType {
  String get name {
    switch (this) {
      case WorkType.sedentary: return '久坐不动';
      case WorkType.sometimes: return '偶尔走动';
      case WorkType.active: return '经常外出';
    }
  }
}

// 锻炼时间段
enum ExerciseTime { morning, afternoon, evening }

extension ExerciseTimeExt on ExerciseTime {
  String get name {
    switch (this) {
      case ExerciseTime.morning: return '早晨';
      case ExerciseTime.afternoon: return '下午';
      case ExerciseTime.evening: return '晚上';
    }
  }
}

// 角色风格
enum CharacterStyle { pet, warrior, mage, assassin }

extension CharacterStyleExt on CharacterStyle {
  String get name {
    switch (this) {
      case CharacterStyle.pet: return '可爱萌宠';
      case CharacterStyle.warrior: return '战斗勇士';
      case CharacterStyle.mage: return '魔法师';
      case CharacterStyle.assassin: return '神秘刺客';
    }
  }

  String get emoji {
    switch (this) {
      case CharacterStyle.pet: return '🐱';
      case CharacterStyle.warrior: return '⚔️';
      case CharacterStyle.mage: return '🧙';
      case CharacterStyle.assassin: return '🗡️';
    }
  }
}

// 赛季配置
class SeasonConfig {
  final String name;
  final String theme;
  final String emoji;
  final String description;
  final double killRewardMultiplier;
  final double exerciseDamageBonus;
  final int coinBonus;
  final int startMonth; // 1-12
  final int endMonth;   // 1-12

  const SeasonConfig({
    required this.name,
    required this.theme,
    required this.emoji,
    required this.description,
    required this.killRewardMultiplier,
    required this.exerciseDamageBonus,
    required this.coinBonus,
    required this.startMonth,
    required this.endMonth,
  });
}

class Seasons {
  static const List<SeasonConfig> all = [
    SeasonConfig(
      name: '春节季',
      theme: 'spring_festival',
      emoji: '🧧',
      description: '新春新气象，击败奖励翻倍！',
      killRewardMultiplier: 2.0,
      exerciseDamageBonus: 0.0,
      coinBonus: 50,
      startMonth: 1,
      endMonth: 3,
    ),
    SeasonConfig(
      name: '夏日季',
      theme: 'summer',
      emoji: '☀️',
      description: '挥洒汗水，锻炼伤害+15%！',
      killRewardMultiplier: 1.0,
      exerciseDamageBonus: 0.15,
      coinBonus: 0,
      startMonth: 4,
      endMonth: 6,
    ),
    SeasonConfig(
      name: '开学季',
      theme: 'school',
      emoji: '📚',
      description: '重返校园，连续打卡额外+20金币！',
      killRewardMultiplier: 1.0,
      exerciseDamageBonus: 0.0,
      coinBonus: 20,
      startMonth: 7,
      endMonth: 9,
    ),
    SeasonConfig(
      name: '年末季',
      theme: 'year_end',
      emoji: '🎄',
      description: '年终冲刺，击败奖励+50%！',
      killRewardMultiplier: 1.5,
      exerciseDamageBonus: 0.05,
      coinBonus: 30,
      startMonth: 10,
      endMonth: 12,
    ),
  ];

  /// 根据当前月份获取赛季配置
  static SeasonConfig getCurrentSeason() {
    final month = DateTime.now().month;
    for (final season in all) {
      if (month >= season.startMonth && month <= season.endMonth) {
        return season;
      }
    }
    return all.first; // 默认返回春节季
  }
}

// 体能水平
enum FitnessLevel { low, medium, high }

// 游戏状态
enum GameStatus { playing, won, lost, maintenance }

// 运动时长选项
const List<int> durations = [10, 15, 20, 30, 45, 60];