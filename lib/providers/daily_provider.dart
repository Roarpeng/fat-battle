import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';

/// 每日战斗状态
///
/// 对齐 Web 端 `dailySlice`，包含今日摄入/消耗/伤害、饮食与锻炼记录，
/// 以及玩家当日体力。周数据（[WeekData]）作为日结算产物也归属此处。
class DailyState {
  /// 当天日期（YYYY-MM-DD）
  final String date;

  /// 当前游戏日数（第几天）
  final int day;

  /// 今日摄入卡路里
  final int todayCalIn;

  /// 今日运动消耗卡路里
  final int todayCalExercise;

  /// 今日累计伤害
  final int todayDamage;

  /// 目标卡路里
  final int targetCal;

  /// 玩家最大体力
  final int playerMaxHp;

  /// 玩家当前体力
  final int playerHp;

  /// 当日饮食记录（按餐次分组）
  final Map<MealType, List<FoodItem>> meals;

  /// 当日锻炼记录
  final List<ExerciseRecord> exercises;

  /// 最近 7 天的日结算数据
  final List<WeekData> weekData;

  /// 今日任务是否完成（怪物击败）
  final bool dailyCompleted;

  const DailyState({
    this.date = '',
    this.day = 1,
    this.todayCalIn = 0,
    this.todayCalExercise = 0,
    this.todayDamage = 0,
    this.targetCal = 1800,
    this.playerMaxHp = 100,
    this.playerHp = 100,
    this.meals = const {},
    this.exercises = const [],
    this.weekData = const [],
    this.dailyCompleted = false,
  });

  DailyState copyWith({
    String? date,
    int? day,
    int? todayCalIn,
    int? todayCalExercise,
    int? todayDamage,
    int? targetCal,
    int? playerMaxHp,
    int? playerHp,
    Map<MealType, List<FoodItem>>? meals,
    List<ExerciseRecord>? exercises,
    List<WeekData>? weekData,
    bool? dailyCompleted,
  }) {
    return DailyState(
      date: date ?? this.date,
      day: day ?? this.day,
      todayCalIn: todayCalIn ?? this.todayCalIn,
      todayCalExercise: todayCalExercise ?? this.todayCalExercise,
      todayDamage: todayDamage ?? this.todayDamage,
      targetCal: targetCal ?? this.targetCal,
      playerMaxHp: playerMaxHp ?? this.playerMaxHp,
      playerHp: playerHp ?? this.playerHp,
      meals: meals ?? this.meals,
      exercises: exercises ?? this.exercises,
      weekData: weekData ?? this.weekData,
      dailyCompleted: dailyCompleted ?? this.dailyCompleted,
    );
  }

  /// 剩余可摄入卡路里
  int get remainingCal => targetCal - todayCalIn + todayCalExercise;

  /// 玩家是否体力耗尽
  bool get playerExhausted => playerHp <= 0;
}

/// 每日状态 Notifier
class DailyNotifier extends StateNotifier<DailyState> {
  DailyNotifier() : super(const DailyState());

  /// 设置当前日期（用于每日重置判断）
  void setDate(String date) {
    state = state.copyWith(date: date);
  }

  /// 设置玩家最大体力
  void setPlayerMaxHp(int maxHp) {
    state = state.copyWith(playerMaxHp: maxHp, playerHp: maxHp);
  }

  /// 设置目标卡路里
  void setTargetCal(int targetCal) {
    state = state.copyWith(targetCal: targetCal);
  }

  /// 添加饮食记录
  void addFood(FoodItem food) {
    final meals = Map<MealType, List<FoodItem>>.from(state.meals);
    meals.putIfAbsent(food.meal, () => []);
    meals[food.meal]!.add(food);
    state = state.copyWith(
      meals: meals,
      todayCalIn: state.todayCalIn + food.totalCal,
    );
  }

  /// 移除饮食记录
  void removeFood(MealType meal, int index) {
    final meals = Map<MealType, List<FoodItem>>.from(state.meals);
    final list = meals[meal];
    if (list == null || index < 0 || index >= list.length) return;
    final food = list.removeAt(index);
    if (list.isEmpty) {
      meals.remove(meal);
    }
    final newCalIn = (state.todayCalIn - food.totalCal).clamp(0, 1 << 30);
    state = state.copyWith(
      meals: meals,
      todayCalIn: newCalIn,
    );
  }

  /// 添加锻炼记录
  ///
  /// 返回产生的伤害，便于上层怪物 Notifier 同步扣血。
  int addExercise(ExerciseRecord exercise, {int? fatigue}) {
    final exercises = List<ExerciseRecord>.from(state.exercises);
    exercises.add(exercise);

    int newPlayerHp = state.playerHp;
    if (fatigue != null) {
      newPlayerHp = (state.playerHp - fatigue).clamp(0, state.playerMaxHp);
    }

    state = state.copyWith(
      exercises: exercises,
      todayCalExercise: state.todayCalExercise + exercise.cal,
      todayDamage: state.todayDamage + exercise.damage,
      playerHp: newPlayerHp,
    );

    return exercise.damage;
  }

  /// 玩家承受疲劳伤害
  void damagePlayer(int fatigue) {
    final newHp = (state.playerHp - fatigue).clamp(0, state.playerMaxHp);
    state = state.copyWith(playerHp: newHp);
  }

  /// 玩家回复体力
  void healPlayer(int amount) {
    final newHp = (state.playerHp + amount).clamp(0, state.playerMaxHp);
    state = state.copyWith(playerHp: newHp);
  }

  /// 恢复玩家满血
  void resetPlayerHp() {
    state = state.copyWith(playerHp: state.playerMaxHp);
  }

  /// 标记今日任务完成
  void markCompleted() {
    state = state.copyWith(dailyCompleted: true);
  }

  /// 推入一条周数据
  void pushWeekData(WeekData data) {
    final weekData = List<WeekData>.from(state.weekData);
    weekData.add(data);
    // 仅保留最近 7 天
    if (weekData.length > 7) {
      weekData.removeRange(0, weekData.length - 7);
    }
    state = state.copyWith(weekData: weekData);
  }

  /// 每日重置（清空当日饮食/锻炼/伤害，恢复玩家体力）
  void resetDaily({required String newDate, required int newDay}) {
    state = DailyState(
      date: newDate,
      day: newDay,
      targetCal: state.targetCal,
      playerMaxHp: state.playerMaxHp,
      playerHp: state.playerMaxHp,
      weekData: state.weekData,
    );
  }

  /// 重置为默认状态
  void reset() {
    state = const DailyState();
  }
}

/// 每日状态 Provider
final dailyProvider =
    StateNotifierProvider<DailyNotifier, DailyState>((ref) {
  return DailyNotifier();
});
