import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';

/// 玩家进度状态
///
/// 对齐 Web 端 `progressSlice`，包含等级/经验/金币/连续打卡/护盾/成就解锁
/// 等长期累积数据。体重记录也归属此处。
class ProgressState {
  /// 等级
  final int level;

  /// 当前经验值
  final int xp;

  /// 总经验值（累计）
  final int totalXp;

  /// 当前游戏天数
  final int day;

  /// 击杀总数
  final int kills;

  /// 连续打卡天数
  final int streak;

  /// 历史最长连续打卡
  final int maxStreak;

  /// 金币
  final int coins;

  /// 护盾数量
  final int shieldCount;

  /// 剩余休息日
  final int restDaysLeft;

  /// 游戏状态
  final GameStatus status;

  /// 是否进入维持模式（达到目标体重后）
  final bool maintenanceMode;

  /// 体重记录
  final List<WeightRecord> weightRecords;

  /// 已解锁的成就 ID 列表
  ///
  /// 注意：成就详细定义和检查逻辑在 [AchievementState] 中维护，
  /// 这里仅保留 ID 列表以便聚合查询。
  final List<String> unlockedAchievements;

  const ProgressState({
    this.level = 1,
    this.xp = 0,
    this.totalXp = 0,
    this.day = 1,
    this.kills = 0,
    this.streak = 0,
    this.maxStreak = 0,
    this.coins = 0,
    this.shieldCount = 1,
    this.restDaysLeft = 0,
    this.status = GameStatus.playing,
    this.maintenanceMode = false,
    this.weightRecords = const [],
    this.unlockedAchievements = const [],
  });

  ProgressState copyWith({
    int? level,
    int? xp,
    int? totalXp,
    int? day,
    int? kills,
    int? streak,
    int? maxStreak,
    int? coins,
    int? shieldCount,
    int? restDaysLeft,
    GameStatus? status,
    bool? maintenanceMode,
    List<WeightRecord>? weightRecords,
    List<String>? unlockedAchievements,
  }) {
    return ProgressState(
      level: level ?? this.level,
      xp: xp ?? this.xp,
      totalXp: totalXp ?? this.totalXp,
      day: day ?? this.day,
      kills: kills ?? this.kills,
      streak: streak ?? this.streak,
      maxStreak: maxStreak ?? this.maxStreak,
      coins: coins ?? this.coins,
      shieldCount: shieldCount ?? this.shieldCount,
      restDaysLeft: restDaysLeft ?? this.restDaysLeft,
      status: status ?? this.status,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      weightRecords: weightRecords ?? this.weightRecords,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    );
  }

  /// 升到下一级所需经验
  int get xpToNextLevel => level * 100;

  /// 升级进度百分比（0.0 - 1.0）
  double get levelProgress => xpToNextLevel > 0 ? xp / xpToNextLevel : 0;
}

/// 进度 Notifier
class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(const ProgressState());

  /// 增加经验值，自动处理升级
  ///
  /// 返回是否升级。
  bool addXp(int amount) {
    if (amount <= 0) return false;
    int level = state.level;
    int xp = state.xp + amount;
    int totalXp = state.totalXp + amount;
    bool leveledUp = false;

    while (xp >= level * 100) {
      xp -= level * 100;
      level += 1;
      leveledUp = true;
    }

    state = state.copyWith(level: level, xp: xp, totalXp: totalXp);
    return leveledUp;
  }

  /// 增加一次击杀
  void addKill({int reward = 0}) {
    state = state.copyWith(
      kills: state.kills + 1,
      coins: state.coins + reward,
    );
  }

  /// 增加金币
  void addCoins(int amount) {
    if (amount == 0) return;
    state = state.copyWith(coins: state.coins + amount);
  }

  /// 消费金币，返回是否成功
  bool spendCoins(int amount) {
    if (state.coins < amount) return false;
    state = state.copyWith(coins: state.coins - amount);
    return true;
  }

  /// 增加连续打卡天数（自动同步 maxStreak）
  void incrementStreak() {
    final newStreak = state.streak + 1;
    state = state.copyWith(
      streak: newStreak,
      maxStreak:
          newStreak > state.maxStreak ? newStreak : state.maxStreak,
    );
  }

  /// 重置连续打卡
  void resetStreak() {
    state = state.copyWith(streak: 0);
  }

  /// 增加天数
  void advanceDay() {
    state = state.copyWith(day: state.day + 1);
  }

  /// 使用护盾
  bool useShield() {
    if (state.shieldCount <= 0) return false;
    state = state.copyWith(shieldCount: state.shieldCount - 1);
    return true;
  }

  /// 增加护盾
  void addShield({int amount = 1}) {
    state = state.copyWith(shieldCount: state.shieldCount + amount);
  }

  /// 使用休息日
  bool useRestDay() {
    if (state.restDaysLeft <= 0) return false;
    state = state.copyWith(restDaysLeft: state.restDaysLeft - 1);
    return true;
  }

  /// 增加休息日
  void addRestDay({int amount = 1}) {
    state = state.copyWith(restDaysLeft: state.restDaysLeft + amount);
  }

  /// 记录体重
  void recordWeight(double weight) {
    final records = List<WeightRecord>.from(state.weightRecords);
    records.add(WeightRecord(
      date: _todayStr(),
      weight: weight,
    ));
    if (records.length > 30) {
      records.removeRange(0, records.length - 30);
    }
    state = state.copyWith(weightRecords: records);
  }

  /// 更新游戏状态
  void updateStatus(GameStatus status) {
    state = state.copyWith(status: status);
  }

  /// 进入/退出维持模式
  void setMaintenanceMode(bool enabled) {
    state = state.copyWith(maintenanceMode: enabled);
  }

  /// 标记成就解锁
  void unlockAchievement(String id) {
    if (state.unlockedAchievements.contains(id)) return;
    final list = List<String>.from(state.unlockedAchievements)..add(id);
    state = state.copyWith(unlockedAchievements: list);
  }

  /// 重置
  void reset() {
    state = const ProgressState();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 进度 Provider
final progressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});
