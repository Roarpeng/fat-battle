import 'dart:math' as math;
import '../constants/app_constants.dart';

// 用户模型
class User {
  final String id;
  final String nickname;
  final String avatar;
  
  // 基本信息
  final double height;
  final double weight;
  final double targetWeight;
  final double bmi;
  
  // 生活习惯
  final SleepType sleepType;
  final WorkType workType;
  final ExerciseTime exerciseTime;
  final CharacterStyle characterStyle;
  
  // 体能评估
  final FitnessLevel fitnessLevel;
  final int pushupCount;
  final int runDuration;
  final int weeklyFreq;
  
  // 难度
  final Difficulty difficulty;
  
  // 游戏状态
  final int day;
  final int coins;
  final int kills;
  final double totalDamage;
  final double totalExercise;
  final int streak;
  final int shieldCount;
  final int restDaysLeft;
  final GameStatus status;
  
  // 设置
  final bool dndMode;
  final String dndStart;
  final String dndEnd;
  final String statusMark;
  
  const User({
    this.id = '',
    this.nickname = '勇士',
    this.avatar = '🧑‍💻',
    this.height = 170,
    this.weight = 70,
    this.targetWeight = 65,
    this.bmi = 0,
    this.sleepType = SleepType.normal,
    this.workType = WorkType.sedentary,
    this.exerciseTime = ExerciseTime.evening,
    this.characterStyle = CharacterStyle.pet,
    this.fitnessLevel = FitnessLevel.medium,
    this.pushupCount = 10,
    this.runDuration = 15,
    this.weeklyFreq = 3,
    this.difficulty = Difficulty.normal,
    this.day = 1,
    this.coins = 0,
    this.kills = 0,
    this.totalDamage = 0,
    this.totalExercise = 0,
    this.streak = 0,
    this.shieldCount = 1,
    this.restDaysLeft = 0,
    this.status = GameStatus.playing,
    this.dndMode = false,
    this.dndStart = '22:00',
    this.dndEnd = '08:00',
    this.statusMark = '',
  });
  
  User copyWith({
    String? id,
    String? nickname,
    String? avatar,
    double? height,
    double? weight,
    double? targetWeight,
    double? bmi,
    SleepType? sleepType,
    WorkType? workType,
    ExerciseTime? exerciseTime,
    CharacterStyle? characterStyle,
    FitnessLevel? fitnessLevel,
    int? pushupCount,
    int? runDuration,
    int? weeklyFreq,
    Difficulty? difficulty,
    int? day,
    int? coins,
    int? kills,
    double? totalDamage,
    double? totalExercise,
    int? streak,
    int? shieldCount,
    int? restDaysLeft,
    GameStatus? status,
    bool? dndMode,
    String? dndStart,
    String? dndEnd,
    String? statusMark,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      bmi: bmi ?? this.bmi,
      sleepType: sleepType ?? this.sleepType,
      workType: workType ?? this.workType,
      exerciseTime: exerciseTime ?? this.exerciseTime,
      characterStyle: characterStyle ?? this.characterStyle,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      pushupCount: pushupCount ?? this.pushupCount,
      runDuration: runDuration ?? this.runDuration,
      weeklyFreq: weeklyFreq ?? this.weeklyFreq,
      difficulty: difficulty ?? this.difficulty,
      day: day ?? this.day,
      coins: coins ?? this.coins,
      kills: kills ?? this.kills,
      totalDamage: totalDamage ?? this.totalDamage,
      totalExercise: totalExercise ?? this.totalExercise,
      streak: streak ?? this.streak,
      shieldCount: shieldCount ?? this.shieldCount,
      restDaysLeft: restDaysLeft ?? this.restDaysLeft,
      status: status ?? this.status,
      dndMode: dndMode ?? this.dndMode,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      statusMark: statusMark ?? this.statusMark,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'height': height,
      'weight': weight,
      'targetWeight': targetWeight,
      'bmi': bmi,
      'sleepType': sleepType.index,
      'workType': workType.index,
      'exerciseTime': exerciseTime.index,
      'characterStyle': characterStyle.index,
      'fitnessLevel': fitnessLevel.index,
      'pushupCount': pushupCount,
      'runDuration': runDuration,
      'weeklyFreq': weeklyFreq,
      'difficulty': difficulty.index,
      'day': day,
      'coins': coins,
      'kills': kills,
      'totalDamage': totalDamage,
      'totalExercise': totalExercise,
      'streak': streak,
      'shieldCount': shieldCount,
      'restDaysLeft': restDaysLeft,
      'status': status.index,
      'dndMode': dndMode,
      'dndStart': dndStart,
      'dndEnd': dndEnd,
      'statusMark': statusMark,
    };
  }
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '勇士',
      avatar: json['avatar'] ?? '🧑‍💻',
      height: (json['height'] ?? 170).toDouble(),
      weight: (json['weight'] ?? 70).toDouble(),
      targetWeight: (json['targetWeight'] ?? 65).toDouble(),
      bmi: (json['bmi'] ?? 0).toDouble(),
      sleepType: SleepType.values[json['sleepType'] ?? 1],
      workType: WorkType.values[json['workType'] ?? 0],
      exerciseTime: ExerciseTime.values[json['exerciseTime'] ?? 2],
      characterStyle: CharacterStyle.values[json['characterStyle'] ?? 0],
      fitnessLevel: FitnessLevel.values[json['fitnessLevel'] ?? 1],
      pushupCount: json['pushupCount'] ?? 10,
      runDuration: json['runDuration'] ?? 15,
      weeklyFreq: json['weeklyFreq'] ?? 3,
      difficulty: Difficulty.values[json['difficulty'] ?? 1],
      day: json['day'] ?? 1,
      coins: json['coins'] ?? 0,
      kills: json['kills'] ?? 0,
      totalDamage: (json['totalDamage'] ?? 0).toDouble(),
      totalExercise: (json['totalExercise'] ?? 0).toDouble(),
      streak: json['streak'] ?? 0,
      shieldCount: json['shieldCount'] ?? 1,
      restDaysLeft: json['restDaysLeft'] ?? 0,
      status: GameStatus.values[json['status'] ?? 0],
      dndMode: json['dndMode'] ?? false,
      dndStart: json['dndStart'] ?? '22:00',
      dndEnd: json['dndEnd'] ?? '08:00',
      statusMark: json['statusMark'] ?? '',
    );
  }
}

// 怪物模型
class Monster {
  final int index;
  final String name;
  final String emoji;
  final int maxHp;
  final int hp;
  final int level;
  final bool isBoss;
  final double healBonus;
  final int shield;
  
  const Monster({
    this.index = 0,
    this.name = '贪吃史莱姆',
    this.emoji = '👾',
    this.maxHp = 100,
    this.hp = 100,
    this.level = 1,
    this.isBoss = false,
    this.healBonus = 0,
    this.shield = 0,
  });
  
  Monster copyWith({
    int? index,
    String? name,
    String? emoji,
    int? maxHp,
    int? hp,
    int? level,
    bool? isBoss,
    double? healBonus,
    int? shield,
  }) {
    return Monster(
      index: index ?? this.index,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      maxHp: maxHp ?? this.maxHp,
      hp: hp ?? this.hp,
      level: level ?? this.level,
      isBoss: isBoss ?? this.isBoss,
      healBonus: healBonus ?? this.healBonus,
      shield: shield ?? this.shield,
    );
  }
  
  double get hpPercent => hp / maxHp;
  double get shieldPercent => maxHp > 0 ? (shield / maxHp).clamp(0.0, 1.0) : 0;
  bool get hasShield => shield > 0;
}

// 每日状态
class DailyState {
  final String date;
  final int day;
  final Monster monster;
  final int playerMaxHp;
  final int playerHp;
  final int todayCalIn;
  final int todayCalExercise;
  final int todayDamage;
  final int targetCal;
  final bool settled;
  final bool killed;
  final int coinsEarned;
  
  const DailyState({
    this.date = '',
    this.day = 1,
    this.monster = const Monster(),
    this.playerMaxHp = 100,
    this.playerHp = 100,
    this.todayCalIn = 0,
    this.todayCalExercise = 0,
    this.todayDamage = 0,
    this.targetCal = 1800,
    this.settled = false,
    this.killed = false,
    this.coinsEarned = 0,
  });
  
  DailyState copyWith({
    String? date,
    int? day,
    Monster? monster,
    int? playerMaxHp,
    int? playerHp,
    int? todayCalIn,
    int? todayCalExercise,
    int? todayDamage,
    int? targetCal,
    bool? settled,
    bool? killed,
    int? coinsEarned,
  }) {
    return DailyState(
      date: date ?? this.date,
      day: day ?? this.day,
      monster: monster ?? this.monster,
      playerMaxHp: playerMaxHp ?? this.playerMaxHp,
      playerHp: playerHp ?? this.playerHp,
      todayCalIn: todayCalIn ?? this.todayCalIn,
      todayCalExercise: todayCalExercise ?? this.todayCalExercise,
      todayDamage: todayDamage ?? this.todayDamage,
      targetCal: targetCal ?? this.targetCal,
      settled: settled ?? this.settled,
      killed: killed ?? this.killed,
      coinsEarned: coinsEarned ?? this.coinsEarned,
    );
  }
}

// 食物记录
class FoodItem {
  final String name;
  final int baseCal;
  final FoodSize size;
  final int totalCal;
  final MealType meal;
  final String? photoUrl;
  
  const FoodItem({
    required this.name,
    required this.baseCal,
    this.size = FoodSize.medium,
    required this.totalCal,
    required this.meal,
    this.photoUrl,
  });
  
  FoodItem copyWith({
    String? name,
    int? baseCal,
    FoodSize? size,
    int? totalCal,
    MealType? meal,
    String? photoUrl,
  }) {
    return FoodItem(
      name: name ?? this.name,
      baseCal: baseCal ?? this.baseCal,
      size: size ?? this.size,
      totalCal: totalCal ?? this.totalCal,
      meal: meal ?? this.meal,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

// 食物记录条目
class FoodRecord {
  final String id;
  final String date;
  final MealType meal;
  final List<FoodItem> items;
  final int totalCal;
  final String source;
  DateTime createdAt;

  FoodRecord({
    this.id = '',
    this.date = '',
    this.meal = MealType.lunch,
    this.items = const [],
    this.totalCal = 0,
    this.source = 'manual',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// 锻炼记录
class ExerciseRecord {
  final String id;
  final String date;
  final String name;
  final String emoji;
  final int duration;
  final int cal;
  final int damage;
  final String mode;
  final int? accuracyScore;
  DateTime createdAt;

  ExerciseRecord({
    this.id = '',
    this.date = '',
    this.name = '',
    this.emoji = '💪',
    this.duration = 0,
    this.cal = 0,
    this.damage = 0,
    this.mode = 'manual',
    this.accuracyScore,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// 体重记录
class WeightRecord {
  final String date;
  final double weight;
  
  const WeightRecord({
    this.date = '',
    this.weight = 0,
  });
}

// 身体变化照片
class ProgressPhoto {
  final String id;
  final String date;
  final String photoPath;   // 本地文件路径
  final double weight;      // 拍照时的体重
  final String? note;       // 备注

  const ProgressPhoto({
    this.id = '',
    this.date = '',
    this.photoPath = '',
    this.weight = 0,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'photoPath': photoPath,
    'weight': weight,
    'note': note,
  };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    photoPath: json['photoPath'] ?? '',
    weight: (json['weight'] ?? 0).toDouble(),
    note: json['note'],
  );
}

// 周数据
class WeekData {
  final int day;
  final String date;
  final int calIn;
  final int calExercise;
  final int damage;
  final bool completed;
  
  const WeekData({
    this.day = 0,
    this.date = '',
    this.calIn = 0,
    this.calExercise = 0,
    this.damage = 0,
    this.completed = false,
  });
}

// IMU数据（来自ESP32腰部Hub）
class ImuData {
  final DateTime timestamp;
  final double ax; // 加速度X
  final double ay; // 加速度Y
  final double az; // 加速度Z
  final double gx; // 角速度X
  final double gy; // 角速度Y
  final double gz; // 角速度Z
  
  const ImuData({
    required this.timestamp,
    this.ax = 0,
    this.ay = 0,
    this.az = 0,
    this.gx = 0,
    this.gy = 0,
    this.gz = 0,
  });
  
  // 计算加速度幅值
  double get accelMagnitude => sqrt(ax * ax + ay * ay + az * az);
  
  // 计算角速度幅值
  double get gyroMagnitude => sqrt(gx * gx + gy * gy + gz * gz);
  
  double sqrt(double x) => x < 0 ? 0 : math.sqrt(x);
}

// BLE设备状态
class BleDeviceState {
  final String name;
  final String deviceId;
  final bool isConnected;
  final int rssi;
  final DateTime? lastUpdate;
  
  const BleDeviceState({
    this.name = 'ESP32-Hub',
    this.deviceId = '',
    this.isConnected = false,
    this.rssi = -100,
    this.lastUpdate,
  });
}