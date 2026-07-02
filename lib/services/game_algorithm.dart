import '../models/game_models.dart';
import '../constants/app_constants.dart';

/// 游戏核心算法
class GameAlgorithm {
  /// 计算BMI
  static double calcBMI(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0;
    return weightKg / ((heightCm / 100) * (heightCm / 100));
  }
  
  /// 获取体型类型
  static String getBodyType(double bmi) {
    if (bmi < 18.5) return '偏瘦';
    if (bmi < 24) return '正常';
    if (bmi < 28) return '偏胖';
    return '肥胖';
  }
  
  /// 获取体型颜色代码
  static String getBodyTypeColor(double bmi) {
    if (bmi < 18.5) return 'blue';
    if (bmi < 24) return 'green';
    if (bmi < 28) return 'gold';
    return 'red';
  }
  
  /// 计算目标卡路里
  static int calcTargetCal(double weightKg, Difficulty difficulty) {
    final base = weightKg * 24;
    switch (difficulty) {
      case Difficulty.easy:
        return (base + 200).toInt();
      case Difficulty.hard:
        return (base - 400).toInt();
      default:
        return base.toInt();
    }
  }
  
  /// 计算怪物血量
  static int calcMonsterHp(int baseHp, Difficulty difficulty, FitnessLevel fitness) {
    double hp = baseHp.toDouble();
    
    // 难度系数
    switch (difficulty) {
      case Difficulty.easy:
        hp *= 0.7;
        break;
      case Difficulty.hard:
        hp *= 1.5;
        break;
      default:
        break;
    }
    
    // 体能系数
    switch (fitness) {
      case FitnessLevel.high:
        hp *= 0.8;
        break;
      case FitnessLevel.low:
        hp *= 1.3;
        break;
      default:
        break;
    }
    
    return hp.toInt();
  }
  
  /// 计算玩家最大体力
  static int calcPlayerMaxHp(FitnessLevel fitness) {
    switch (fitness) {
      case FitnessLevel.high:
        return 120;
      case FitnessLevel.low:
        return 90;
      default:
        return 100;
    }
  }
  
  /// 饮食对怪物的影响（怪物获得护盾而非回血，减少挫败感）
  static FoodImpactResult foodImpactOnMonster(
    int foodCal,
    int todayCalIn,
    int targetCal,
    int monsterMaxHp,
    int currentMonsterHp,
    double healBonus,
    int currentShield,
  ) {
    // 基础护盾：摄入卡路里的5%转为护盾（而非回血）
    final baseShield = (foodCal * 0.05).toInt();
    
    // 超标护盾：如果超过目标卡路里，额外增加护盾
    int overageShield = 0;
    final previousCal = todayCalIn - foodCal;
    
    if (previousCal <= targetCal && todayCalIn > targetCal) {
      final over = todayCalIn - targetCal;
      overageShield = (over * 0.3).toInt();
    }
    
    // 总护盾
    final totalShieldGain = ((baseShield + overageShield) * (1 + healBonus)).toInt();
    final newShield = currentShield + totalShieldGain;
    
    // HP 不变（正向反馈：不会让怪物变强，只是暂时更抗揍）
    final newHp = currentMonsterHp;
    
    return FoodImpactResult(
      heal: 0,
      shieldGained: totalShieldGain,
      newMonsterHp: newHp,
      newMonsterShield: newShield,
      isOverage: overageShield > 0,
      baseHeal: baseShield,
      overageHeal: overageShield,
    );
  }
  
  /// 锻炼对怪物的影响（伤害优先消耗护盾，护盾归零后才掉血）
  /// [season] 可选赛季配置，提供伤害加成
  static ExerciseImpactResult exerciseImpactOnMonster(
    int calBurned,
    String mode,
    int monsterHp,
    int monsterMaxHp,
    int monsterShield, {
    SeasonConfig? season,
  }) {
    // 基础伤害：消耗卡路里的80%
    double baseDamage = calBurned * 0.8;
    
    // 手动模式降20%
    if (mode == 'manual') {
      baseDamage *= 0.8;
    }
    
    // 摄像头/IMU模式有额外加成
    if (mode == 'camera' || mode == 'imu') {
      baseDamage *= 1.1;
    }
    
    // 赛季加成：锻炼伤害额外加成
    if (season != null && season.exerciseDamageBonus > 0) {
      baseDamage *= (1 + season.exerciseDamageBonus);
    }
    
    final damage = baseDamage.toInt();
    
    // 先消耗护盾
    int remainingDamage = damage;
    int newShield = monsterShield;
    int shieldBroken = 0;
    
    if (newShield > 0) {
      if (remainingDamage >= newShield) {
        shieldBroken = newShield;
        remainingDamage -= newShield;
        newShield = 0;
      } else {
        shieldBroken = remainingDamage;
        newShield -= remainingDamage;
        remainingDamage = 0;
      }
    }
    
    // 再扣血
    final newHp = (monsterHp - remainingDamage).clamp(0, monsterMaxHp);
    
    return ExerciseImpactResult(
      damage: damage,
      shieldDamage: shieldBroken,
      newMonsterHp: newHp,
      newMonsterShield: newShield,
      killed: newHp == 0,
    );
  }
  
  /// 计算锻炼消耗卡路里
  static int calcExerciseCal(ExerciseType exercise, int durationMinutes) {
    return exercise.calPerMin * durationMinutes;
  }
  
  /// 计算玩家疲劳值
  static int calcFatigue(int durationMinutes) {
    return (durationMinutes * 0.3).toInt();
  }
  
  /// 计算击败奖励
  /// [season] 可选赛季配置，提供奖励翻倍加成
  static int calcKillReward(bool isBoss, {SeasonConfig? season}) {
    int baseReward = isBoss ? 200 : 100;
    
    // 赛季加成：击败奖励乘数
    if (season != null) {
      baseReward = (baseReward * season.killRewardMultiplier).toInt();
      // 额外赛季金币奖励
      baseReward += season.coinBonus;
    }
    
    return baseReward;
  }
  
  /// 生成新怪物
  static Monster generateMonster(int kills, Difficulty difficulty, FitnessLevel fitness) {
    // 循环怪物列表
    final index = kills % Monsters.all.length;
    final config = Monsters.all[index];
    
    // 等级：每击败一轮怪物，等级+1
    final level = (kills / Monsters.all.length).floor() + 1;
    
    // 计算血量
    final hp = calcMonsterHp(config.baseHp, difficulty, fitness);
    
    return Monster(
      index: index,
      name: config.name,
      emoji: config.emoji,
      maxHp: hp,
      hp: hp,
      level: level,
      isBoss: config.isBoss,
      healBonus: config.healBonus,
    );
  }
  
  /// 计算减肥进度
  static double calcProgress(double startWeight, double currentWeight, double targetWeight) {
    if (startWeight <= targetWeight) return 100;
    final lost = startWeight - currentWeight;
    final total = startWeight - targetWeight;
    return (lost / total * 100).clamp(0, 100);
  }
  
  /// 计算7日移动平均体重
  static double calcWeightMovingAverage(List<WeightRecord> records) {
    if (records.isEmpty) return 0;
    final recent = records.length > 7 ? records.sublist(records.length - 7) : records;
    return recent.fold(0.0, (sum, r) => sum + r.weight) / recent.length;
  }
  
  /// 判断是否可以使用护盾
  static bool canUseShield(int streak, int shieldCount) {
    return streak >= 7 && shieldCount > 0;
  }
  
  /// 获取当前赛季
  static SeasonInfo getCurrentSeason() {
    final month = DateTime.now().month;
    final seasonIndex = ((month - 1) / 3).floor() + 1;
    
    if (month >= 1 && month <= 3) {
      return SeasonInfo(name: '春节季', theme: 'spring', bonus: '击败奖励翻倍');
    }
    if (month >= 4 && month <= 6) {
      return SeasonInfo(name: '夏日季', theme: 'summer', bonus: '锻炼伤害+15%');
    }
    if (month >= 7 && month <= 9) {
      return SeasonInfo(name: '开学季', theme: 'school', bonus: '学生专属');
    }
    return SeasonInfo(name: '年末季', theme: 'year_end', bonus: '全年数据回顾');
  }
  
  /// 判断体能等级
  static FitnessLevel calcFitnessLevel(int pushupCount, int runDuration, int weeklyFreq) {
    int score = 0;
    
    // 俯卧撑评分
    if (pushupCount >= 30) score += 2;
    else if (pushupCount >= 15) score += 1;
    
    // 跑步时长评分
    if (runDuration >= 30) score += 2;
    else if (runDuration >= 15) score += 1;
    
    // 每周频率评分
    if (weeklyFreq >= 5) score += 2;
    else if (weeklyFreq >= 3) score += 1;
    
    if (score >= 5) return FitnessLevel.high;
    if (score >= 2) return FitnessLevel.medium;
    return FitnessLevel.low;
  }
}

/// 饮食影响结果
class FoodImpactResult {
  final int heal;
  final int shieldGained;
  final int newMonsterHp;
  final int newMonsterShield;
  final bool isOverage;
  final int baseHeal;
  final int overageHeal;
  
  const FoodImpactResult({
    required this.heal,
    required this.shieldGained,
    required this.newMonsterHp,
    required this.newMonsterShield,
    required this.isOverage,
    required this.baseHeal,
    required this.overageHeal,
  });
}

/// 锻炼影响结果
class ExerciseImpactResult {
  final int damage;
  final int shieldDamage;
  final int newMonsterHp;
  final int newMonsterShield;
  final bool killed;
  
  const ExerciseImpactResult({
    required this.damage,
    required this.shieldDamage,
    required this.newMonsterHp,
    required this.newMonsterShield,
    required this.killed,
  });
}

/// 赛季信息
class SeasonInfo {
  final String name;
  final String theme;
  final String bonus;
  
  const SeasonInfo({
    required this.name,
    required this.theme,
    required this.bonus,
  });
}