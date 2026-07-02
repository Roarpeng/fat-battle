import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../constants/app_constants.dart';
import '../services/game_algorithm.dart';
import '../services/notification_service.dart';
import '../services/voice_service.dart';

/// 游戏状态Provider
class GameStateNotifier extends StateNotifier<GameState> {
  final SharedPreferences? prefs;
  final NotificationService? notificationService;
  int _notificationIdCounter = 0;
  
  GameStateNotifier(this.prefs, {this.notificationService}) : super(GameState()) {
    _loadGame();
  }
  
  Future<void> _sendNotification(String title, String body, {NotificationType type = NotificationType.system}) async {
    if (notificationService == null) return;
    if (!state.notificationEnabled) return;
    
    final shouldSend = notificationService!.shouldNotifyNow(
      priority: type == NotificationType.achievement ? NotifyPriority.high : NotifyPriority.normal,
      dndEnabled: state.dndMode,
      dndStart: state.dndStart,
      dndEnd: state.dndEnd,
    );
    
    if (shouldSend) {
      _notificationIdCounter++;
      await notificationService!.showNotification(
        id: _notificationIdCounter,
        title: title,
        body: body,
        type: type,
      );
    } else if (type != NotificationType.system) {
      notificationService!.queue(QueuedNotification(
        id: _notificationIdCounter.toString(),
        title: title,
        body: body,
        type: type,
        priority: type == NotificationType.achievement ? NotifyPriority.high : NotifyPriority.normal,
        createdAt: DateTime.now(),
      ));
    }
  }
  
  /// 从本地存储加载游戏
  Future<void> _loadGame() async {
    if (prefs == null) return;
    
    final saved = prefs!.getString('fat_battle_game');
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        state = GameState.fromJson(json);
        _checkDailyReset();
      } catch (e) {
        // 解析失败，使用默认状态
      }
    }
  }
  
  /// 保存游戏到本地存储
  Future<void> _saveGame() async {
    if (prefs == null) return;
    
    await prefs!.setString('fat_battle_game', jsonEncode(state.toJson()));
  }
  
  /// 检查是否需要每日重置
  void _checkDailyReset() {
    final today = DateTime.now().toDateString();
    if (state.lastDate != today) {
      // 昨天是否完成
      final yesterdayCompleted = state.monster.hp <= 0;
      
      if (yesterdayCompleted) {
        state = state.copyWith(
          streak: state.streak + 1,
          coins: state.coins + 50,
        );
      } else if (state.status == GameStatus.playing) {
        state = state.copyWith(streak: 0);
      }
      
      // 保存昨日数据
      final weekData = List<WeekData>.from(state.weekData);
      weekData.add(WeekData(
        day: state.day,
        date: state.lastDate,
        calIn: state.todayCalIn,
        calExercise: state.todayCalExercise,
        damage: state.todayDamage,
        completed: yesterdayCompleted,
      ));
      
      // 只保留最近7天
      if (weekData.length > 7) {
        weekData.removeRange(0, weekData.length - 7);
      }
      
      // 新的一天
      state = state.copyWith(
        day: state.day + 1,
        todayCalIn: 0,
        todayCalExercise: 0,
        todayDamage: 0,
        meals: {},
        exercises: [],
        playerHp: state.playerMaxHp,
        status: GameStatus.playing,
        lastDate: today,
        weekData: weekData,
      );
      
      // 生成新怪物
      _spawnMonster();
      _saveGame();
    }
  }
  
  /// 生成新怪物
  void _spawnMonster() {
    final monster = GameAlgorithm.generateMonster(
      state.kills,
      state.difficulty,
      state.fitnessLevel,
    );
    
    state = state.copyWith(monster: monster.copyWith(shield: 0));
  }
  
  /// 创建新游戏（角色创建后）
  Future<void> createGame(User user) async {
    final bmi = GameAlgorithm.calcBMI(user.weight, user.height);
    final fitnessLevel = GameAlgorithm.calcFitnessLevel(
      user.pushupCount,
      user.runDuration,
      user.weeklyFreq,
    );
    final targetCal = GameAlgorithm.calcTargetCal(user.weight, user.difficulty);
    final playerMaxHp = GameAlgorithm.calcPlayerMaxHp(fitnessLevel);
    
    final newUser = user.copyWith(
      bmi: bmi,
      fitnessLevel: fitnessLevel,
      day: 1,
      coins: 0,
      kills: 0,
      streak: 0,
      shieldCount: 1,
      status: GameStatus.playing,
    );
    
    final monster = GameAlgorithm.generateMonster(0, user.difficulty, fitnessLevel);
    
    state = GameState(
      user: newUser,
      monster: monster,
      playerMaxHp: playerMaxHp,
      playerHp: playerMaxHp,
      targetCal: targetCal,
      todayCalIn: 0,
      todayCalExercise: 0,
      todayDamage: 0,
      day: 1,
      lastDate: DateTime.now().toDateString(),
      meals: {},
      exercises: [],
      achievements: [],
      weightRecords: [WeightRecord(
        date: DateTime.now().toDateString(),
        weight: user.weight,
      )],
      weekData: [],
    );
    
    await _saveGame();
  }
  
  /// 添加食物记录
  Future<void> addFood(FoodItem food) async {
    final meals = Map<MealType, List<FoodItem>>.from(state.meals);
    if (!meals.containsKey(food.meal)) {
      meals[food.meal] = [];
    }
    meals[food.meal]!.add(food);
    
    final newCalIn = state.todayCalIn + food.totalCal;
    
    // 计算怪物护盾（正向反馈：吃多了只是加护盾，不会回血）
    final result = GameAlgorithm.foodImpactOnMonster(
      food.totalCal,
      newCalIn,
      state.targetCal,
      state.monster.maxHp,
      state.monster.hp,
      state.monster.healBonus,
      state.monster.shield,
    );
    
    state = state.copyWith(
      meals: meals,
      todayCalIn: newCalIn,
      monster: state.monster.copyWith(
        hp: result.newMonsterHp,
        shield: result.newMonsterShield,
      ),
    );
    
    await _saveGame();
  }
  
  /// 移除食物记录
  Future<void> removeFood(MealType meal, int index) async {
    final meals = Map<MealType, List<FoodItem>>.from(state.meals);
    if (meals.containsKey(meal) && meals[meal]!.length > index) {
      final food = meals[meal]![index];
      meals[meal]!.removeAt(index);
      
      final newCalIn = state.todayCalIn - food.totalCal;
      
      // 回滚护盾（正向反馈：撤销食物直接减护盾，不影响HP）
      final result = GameAlgorithm.foodImpactOnMonster(
        food.totalCal,
        state.todayCalIn,
        state.targetCal,
        state.monster.maxHp,
        state.monster.hp,
        state.monster.healBonus,
        state.monster.shield,
      );
      
      final newShield = (state.monster.shield - result.shieldGained).clamp(0, state.monster.maxHp).toInt();
      
      state = state.copyWith(
        meals: meals,
        todayCalIn: newCalIn,
        monster: state.monster.copyWith(
          shield: newShield,
        ),
      );
      
      await _saveGame();
    }
  }
  
  /// 添加锻炼记录
  Future<void> addExercise(ExerciseRecord exercise) async {
    final exercises = List<ExerciseRecord>.from(state.exercises);
    exercises.add(exercise);
    
    // 获取当前赛季配置
    final season = Seasons.getCurrentSeason();
    
    // 计算伤害（先破盾再掉血），传入赛季加成
    final result = GameAlgorithm.exerciseImpactOnMonster(
      exercise.cal,
      exercise.mode,
      state.monster.hp,
      state.monster.maxHp,
      state.monster.shield,
      season: season,
    );
    
    // 计算疲劳
    final fatigue = GameAlgorithm.calcFatigue(exercise.duration);
    final newPlayerHp = (state.playerHp - fatigue).clamp(0, state.playerMaxHp).toInt();
    
    state = state.copyWith(
      exercises: exercises,
      todayCalExercise: state.todayCalExercise + exercise.cal,
      todayDamage: state.todayDamage + result.damage,
      monster: state.monster.copyWith(
        hp: result.newMonsterHp,
        shield: result.newMonsterShield,
      ),
      playerHp: newPlayerHp,
      user: state.user.copyWith(
        totalExercise: state.user.totalExercise + exercise.cal,
        totalDamage: state.user.totalDamage + result.damage,
      ),
    );
    
    // 检查是否击败怪物
    if (result.killed) {
      await _onMonsterDefeated();
    }
    
    // 检查玩家体力是否耗尽
    if (newPlayerHp == 0) {
      state = state.copyWith(status: GameStatus.lost);
    }
    
    await _checkAchievements();
    await _saveGame();
  }
  
  /// 添加自动锻炼记录（来自IMU被动采集）
  Future<void> addAutoExercise(ExerciseRecord exercise) async {
    final autoExercises = state.exercises.where((e) => e.mode == 'auto').toList();
    final todayAutoCal = autoExercises.fold<int>(0, (sum, e) => sum + e.cal);
    
    if (todayAutoCal + exercise.cal > 500) return;
    
    await addExercise(exercise);
  }
  
  /// 怪物被击败
  Future<void> _onMonsterDefeated() async {
    // 获取当前赛季配置，计算赛季加成奖励
    final season = Seasons.getCurrentSeason();
    final reward = GameAlgorithm.calcKillReward(
      state.monster.isBoss,
      season: season,
    );
    
    state = state.copyWith(
      status: GameStatus.won,
      kills: state.kills + 1,
      user: state.user.copyWith(
        kills: state.kills + 1,
        coins: state.coins + reward,
      ),
    );
    
    // 语音播报：怪物击败
    if (state.voiceEnabled) {
      VoiceService().monsterDefeated(state.monster.name, reward);
    }
    
    await _sendNotification(
      state.monster.isBoss ? 'Boss击败！' : '怪物被击败！',
      '你击败了${state.monster.name}，获得 $reward 金币奖励！'
          '${season.coinBonus > 0 ? ' (含${season.name}赛季加成 ${season.coinBonus}金币)' : ''}'
          '${season.killRewardMultiplier > 1 ? ' (奖励x${season.killRewardMultiplier})' : ''}',
      type: NotificationType.achievement,
    );
    
    await _checkAchievements();
    await _saveGame();
  }
  
  /// 开始新挑战
  Future<void> startNewChallenge() async {
    _spawnMonster();
    
    state = state.copyWith(
      status: GameStatus.playing,
      playerHp: state.playerMaxHp,
    );
    
    await _saveGame();
  }
  
  /// 使用护盾
  Future<void> useShield() async {
    if (state.shieldCount <= 0) return;
    
    final newHp = (state.playerHp + 30).clamp(0, state.playerMaxHp);
    
    state = state.copyWith(
      shieldCount: state.shieldCount - 1,
      playerHp: newHp,
    );
    
    await _saveGame();
  }
  
  /// 使用休息日
  Future<void> useRestDay() async {
    if (state.restDaysLeft <= 0) return;
    
    state = state.copyWith(
      restDaysLeft: state.restDaysLeft - 1,
      playerHp: state.playerMaxHp,
    );
    
    await _saveGame();
  }
  
  /// 记录体重
  Future<void> recordWeight(double weight) async {
    final records = List<WeightRecord>.from(state.weightRecords);
    records.add(WeightRecord(
      date: DateTime.now().toDateString(),
      weight: weight,
    ));
    
    // 只保留最近30天
    if (records.length > 30) {
      records.removeRange(0, records.length - 30);
    }
    
    final bmi = GameAlgorithm.calcBMI(weight, state.user.height);
    
    // 检查是否达到目标体重，自动切换到maintenance模式
    GameStatus newStatus = state.status;
    bool newMaintenanceMode = state.maintenanceMode;
    if (weight <= state.user.targetWeight && !state.maintenanceMode) {
      newStatus = GameStatus.maintenance;
      newMaintenanceMode = true;
      // 语音播报：进入维护模式
      if (state.voiceEnabled) {
        VoiceService().maintenanceEnter();
      }
    }
    
    state = state.copyWith(
      weightRecords: records,
      user: state.user.copyWith(
        weight: weight,
        bmi: bmi,
        status: newStatus,
      ),
      maintenanceMode: newMaintenanceMode,
    );
    
    await _checkAchievements();
    await _saveGame();
  }
  
  /// 更新难度
  Future<void> updateDifficulty(Difficulty difficulty) async {
    final targetCal = GameAlgorithm.calcTargetCal(state.user.weight, difficulty);
    
    state = state.copyWith(
      difficulty: difficulty,
      targetCal: targetCal,
      user: state.user.copyWith(difficulty: difficulty),
    );
    
    await _saveGame();
  }
  
  /// 更新勿扰模式
  Future<void> updateDndMode(bool enabled, String start, String end) async {
    state = state.copyWith(
      dndMode: enabled,
      dndStart: start,
      dndEnd: end,
    );
    
    await _saveGame();
  }
  
  /// 更新通知开关
  Future<void> updateNotificationEnabled(bool enabled) async {
    state = state.copyWith(notificationEnabled: enabled);
    await _saveGame();
  }
  
  /// 更新语音播报开关
  Future<void> updateVoiceEnabled(bool enabled) async {
    VoiceService().setEnabled(enabled);
    state = state.copyWith(voiceEnabled: enabled);
    await _saveGame();
  }
  
  /// 更新提醒频率
  Future<void> updateReminderFrequency(String frequency) async {
    state = state.copyWith(reminderFrequency: frequency);
    await _saveGame();
  }
  
  /// 检查成就
  Future<void> _checkAchievements() async {
    final achievements = List<String>.from(state.achievements);
    
    for (final achievement in Achievements.all) {
      if (!achievements.contains(achievement.id)) {
        bool unlocked = false;
        
        switch (achievement.id) {
          case 'first_kill':
            unlocked = state.kills >= 1;
            break;
          case 'kill_5':
            unlocked = state.kills >= 5;
            break;
          case 'kill_10':
            unlocked = state.kills >= 10;
            break;
          case 'streak_3':
            unlocked = state.streak >= 3;
            break;
          case 'streak_7':
            unlocked = state.streak >= 7;
            break;
          case 'streak_30':
            unlocked = state.streak >= 30;
            break;
          case 'exercise_1000':
            unlocked = state.todayCalExercise >= 1000;
            break;
          case 'coins_1000':
            unlocked = state.coins >= 1000;
            break;
          case 'boss_kill':
            unlocked = state.kills >= 3;
            break;
          case 'weight_5':
            unlocked = (state.user.weight - state.user.targetWeight) >= 5;
            break;
          case 'day_7':
            unlocked = state.day >= 7;
            break;
          case 'day_30':
            unlocked = state.day >= 30;
            break;
        }
        
        if (unlocked) {
          achievements.add(achievement.id);
          _sendNotification(
            '🏆 成就解锁！',
            '恭喜你解锁了「${achievement.name}」成就',
            type: NotificationType.achievement,
          );
        }
      }
    }
    
    state = state.copyWith(achievements: achievements);
    await _saveGame();
  }
  
  /// 购买商店物品
  Future<void> buyItem(ShopItem item) async {
    if (state.coins < item.price) return;
    
    int newCoins = state.coins - item.price;
    int newStreak = state.streak;
    int newShieldCount = state.shieldCount;
    
    switch (item.id) {
      case 'checkin':
        newStreak++;
        break;
      case 'shield':
        newShieldCount++;
        break;
    }
    
    state = state.copyWith(
      coins: newCoins,
      streak: newStreak,
      shieldCount: newShieldCount,
      user: state.user.copyWith(
        coins: newCoins,
        streak: newStreak,
        shieldCount: newShieldCount,
      ),
    );
    
    await _saveGame();
  }
  
  /// 重置游戏
  Future<void> resetGame() async {
    state = GameState();
    if (prefs != null) {
      await prefs!.remove('fat_battle_game');
    }
  }
}

/// 游戏状态
class GameState {
  final User user;
  final Monster monster;
  final int playerMaxHp;
  final int playerHp;
  final int targetCal;
  final int todayCalIn;
  final int todayCalExercise;
  final int todayDamage;
  final int day;
  final String lastDate;
  final Map<MealType, List<FoodItem>> meals;
  final List<ExerciseRecord> exercises;
  final List<String> achievements;
  final List<WeightRecord> weightRecords;
  final List<WeekData> weekData;
  final GameStatus status;
  final Difficulty difficulty;
  final FitnessLevel fitnessLevel;
  final int kills;
  final int streak;
  final int coins;
  final int shieldCount;
  final int restDaysLeft;
  final bool dndMode;
  final String dndStart;
  final String dndEnd;
  final bool notificationEnabled;
  final bool voiceEnabled;
  final bool maintenanceMode;
  final String reminderFrequency;
  
  const GameState({
    this.user = const User(),
    this.monster = const Monster(),
    this.playerMaxHp = 100,
    this.playerHp = 100,
    this.targetCal = 1800,
    this.todayCalIn = 0,
    this.todayCalExercise = 0,
    this.todayDamage = 0,
    this.day = 1,
    this.lastDate = '',
    this.meals = const {},
    this.exercises = const [],
    this.achievements = const [],
    this.weightRecords = const [],
    this.weekData = const [],
    this.status = GameStatus.playing,
    this.difficulty = Difficulty.normal,
    this.fitnessLevel = FitnessLevel.medium,
    this.kills = 0,
    this.streak = 0,
    this.coins = 0,
    this.shieldCount = 1,
    this.restDaysLeft = 0,
    this.dndMode = false,
    this.dndStart = '22:00',
    this.dndEnd = '08:00',
    this.notificationEnabled = true,
    this.voiceEnabled = true,
    this.maintenanceMode = false,
    this.reminderFrequency = 'normal',
  });
  
  GameState copyWith({
    User? user,
    Monster? monster,
    int? playerMaxHp,
    int? playerHp,
    int? targetCal,
    int? todayCalIn,
    int? todayCalExercise,
    int? todayDamage,
    int? day,
    String? lastDate,
    Map<MealType, List<FoodItem>>? meals,
    List<ExerciseRecord>? exercises,
    List<String>? achievements,
    List<WeightRecord>? weightRecords,
    List<WeekData>? weekData,
    GameStatus? status,
    Difficulty? difficulty,
    FitnessLevel? fitnessLevel,
    int? kills,
    int? streak,
    int? coins,
    int? shieldCount,
    int? restDaysLeft,
    bool? dndMode,
    String? dndStart,
    String? dndEnd,
    bool? notificationEnabled,
    bool? voiceEnabled,
    bool? maintenanceMode,
    String? reminderFrequency,
  }) {
    return GameState(
      user: user ?? this.user,
      monster: monster ?? this.monster,
      playerMaxHp: playerMaxHp ?? this.playerMaxHp,
      playerHp: playerHp ?? this.playerHp,
      targetCal: targetCal ?? this.targetCal,
      todayCalIn: todayCalIn ?? this.todayCalIn,
      todayCalExercise: todayCalExercise ?? this.todayCalExercise,
      todayDamage: todayDamage ?? this.todayDamage,
      day: day ?? this.day,
      lastDate: lastDate ?? this.lastDate,
      meals: meals ?? this.meals,
      exercises: exercises ?? this.exercises,
      achievements: achievements ?? this.achievements,
      weightRecords: weightRecords ?? this.weightRecords,
      weekData: weekData ?? this.weekData,
      status: status ?? this.status,
      difficulty: difficulty ?? this.difficulty,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      kills: kills ?? this.kills,
      streak: streak ?? this.streak,
      coins: coins ?? this.coins,
      shieldCount: shieldCount ?? this.shieldCount,
      restDaysLeft: restDaysLeft ?? this.restDaysLeft,
      dndMode: dndMode ?? this.dndMode,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'monster': {
        'index': monster.index,
        'name': monster.name,
        'emoji': monster.emoji,
        'maxHp': monster.maxHp,
        'hp': monster.hp,
        'level': monster.level,
        'isBoss': monster.isBoss,
        'healBonus': monster.healBonus,
        'shield': monster.shield,
      },
      'playerMaxHp': playerMaxHp,
      'playerHp': playerHp,
      'targetCal': targetCal,
      'todayCalIn': todayCalIn,
      'todayCalExercise': todayCalExercise,
      'todayDamage': todayDamage,
      'day': day,
      'lastDate': lastDate,
      'meals': meals.map((k, v) => MapEntry(k.index, v.map((f) => {
        'name': f.name,
        'baseCal': f.baseCal,
        'size': f.size.index,
        'totalCal': f.totalCal,
        'meal': f.meal.index,
      }).toList())),
      'exercises': exercises.map((e) => {
        'id': e.id,
        'date': e.date,
        'name': e.name,
        'emoji': e.emoji,
        'duration': e.duration,
        'cal': e.cal,
        'damage': e.damage,
        'mode': e.mode,
      }).toList(),
      'achievements': achievements,
      'weightRecords': weightRecords.map((w) => {
        'date': w.date, 'weight': w.weight,
      }).toList(),
      'weekData': weekData.map((w) => {
        'day': w.day,
        'date': w.date,
        'calIn': w.calIn,
        'calExercise': w.calExercise,
        'damage': w.damage,
        'completed': w.completed,
      }).toList(),
      'status': status.index,
      'difficulty': difficulty.index,
      'fitnessLevel': fitnessLevel.index,
      'kills': kills,
      'streak': streak,
      'coins': coins,
      'shieldCount': shieldCount,
      'restDaysLeft': restDaysLeft,
      'dndMode': dndMode,
      'dndStart': dndStart,
      'dndEnd': dndEnd,
      'notificationEnabled': notificationEnabled,
      'voiceEnabled': voiceEnabled,
      'maintenanceMode': maintenanceMode,
      'reminderFrequency': reminderFrequency,
    };
  }
  
  factory GameState.fromJson(Map<String, dynamic> json) {
    final mealsMap = <MealType, List<FoodItem>>{};
    if (json['meals'] != null) {
      for (final entry in (json['meals'] as Map).entries) {
        final mealType = MealType.values[int.parse(entry.key.toString())];
        final items = (entry.value as List).map((f) => FoodItem(
          name: f['name'],
          baseCal: f['baseCal'],
          size: FoodSize.values[f['size'] ?? 1],
          totalCal: f['totalCal'],
          meal: mealType,
        )).toList();
        mealsMap[mealType] = items;
      }
    }
    
    return GameState(
      user: User.fromJson(json['user'] ?? {}),
      monster: Monster(
        index: json['monster']?['index'] ?? 0,
        name: json['monster']?['name'] ?? '贪吃史莱姆',
        emoji: json['monster']?['emoji'] ?? '👾',
        maxHp: json['monster']?['maxHp'] ?? 100,
        hp: json['monster']?['hp'] ?? 100,
        level: json['monster']?['level'] ?? 1,
        isBoss: json['monster']?['isBoss'] ?? false,
        healBonus: (json['monster']?['healBonus'] ?? 0).toDouble(),
        shield: json['monster']?['shield'] ?? 0,
      ),
      playerMaxHp: json['playerMaxHp'] ?? 100,
      playerHp: json['playerHp'] ?? 100,
      targetCal: json['targetCal'] ?? 1800,
      todayCalIn: json['todayCalIn'] ?? 0,
      todayCalExercise: json['todayCalExercise'] ?? 0,
      todayDamage: json['todayDamage'] ?? 0,
      day: json['day'] ?? 1,
      lastDate: json['lastDate'] ?? '',
      meals: mealsMap,
      exercises: (json['exercises'] as List?)?.map((e) => ExerciseRecord(
        id: e['id'] ?? '',
        date: e['date'] ?? '',
        name: e['name'] ?? '',
        emoji: e['emoji'] ?? '💪',
        duration: e['duration'] ?? 0,
        cal: e['cal'] ?? 0,
        damage: e['damage'] ?? 0,
        mode: e['mode'] ?? 'manual',
      )).toList() ?? [],
      achievements: (json['achievements'] as List?)?.map((a) => a.toString()).toList() ?? [],
      weightRecords: (json['weightRecords'] as List?)?.map((w) => WeightRecord(
        date: w['date'] ?? '',
        weight: (w['weight'] ?? 0).toDouble(),
      )).toList() ?? [],
      weekData: (json['weekData'] as List?)?.map((w) => WeekData(
        day: w['day'] ?? 0,
        date: w['date'] ?? '',
        calIn: w['calIn'] ?? 0,
        calExercise: w['calExercise'] ?? 0,
        damage: w['damage'] ?? 0,
        completed: w['completed'] ?? false,
      )).toList() ?? [],
      status: GameStatus.values[json['status'] ?? 0],
      difficulty: Difficulty.values[json['difficulty'] ?? 1],
      fitnessLevel: FitnessLevel.values[json['fitnessLevel'] ?? 1],
      kills: json['kills'] ?? 0,
      streak: json['streak'] ?? 0,
      coins: json['coins'] ?? 0,
      shieldCount: json['shieldCount'] ?? 1,
      restDaysLeft: json['restDaysLeft'] ?? 0,
      dndMode: json['dndMode'] ?? false,
      dndStart: json['dndStart'] ?? '22:00',
      dndEnd: json['dndEnd'] ?? '08:00',
      notificationEnabled: json['notificationEnabled'] ?? true,
      voiceEnabled: json['voiceEnabled'] ?? true,
      maintenanceMode: json['maintenanceMode'] ?? false,
      reminderFrequency: json['reminderFrequency'] ?? 'normal',
    );
  }
  
  bool get hasGame => lastDate.isNotEmpty;
  
  int get remainingCal => targetCal - todayCalIn + todayCalExercise;
}

/// DateTime扩展
extension DateTimeExt on DateTime {
  String toDateString() {
    return '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }
}

/// Provider定义
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  SharedPreferences? prefs;
  NotificationService? notificationService;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
    notificationService = ref.watch(notificationServiceProvider);
    // 异步初始化，失败不影响主流程
    () async {
      try {
        await notificationService?.init();
      } catch (_) {}
    }();
  } catch (e) {
    // ignore
  }
  return GameStateNotifier(prefs, notificationService: notificationService);
});

/// 初始化SharedPreferences的FutureProvider
final sharedPreferencesInitProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});