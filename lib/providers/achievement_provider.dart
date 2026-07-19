import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// 单个成就的进度状态
class AchievementProgress {
  /// 成就定义 ID（对应 [Achievement.id]）
  final String id;

  /// 是否已解锁
  final bool unlocked;

  /// 当前进度值
  final int progress;

  /// 解锁日期（YYYY-MM-DD）
  final String unlockedAt;

  const AchievementProgress({
    required this.id,
    this.unlocked = false,
    this.progress = 0,
    this.unlockedAt = '',
  });

  AchievementProgress copyWith({
    bool? unlocked,
    int? progress,
    String? unlockedAt,
  }) {
    return AchievementProgress(
      id: id,
      unlocked: unlocked ?? this.unlocked,
      progress: progress ?? this.progress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// 成就系统状态
///
/// 对齐 Web 端 `achievementSlice`，持有所有成就定义的当前进度。
/// 成就定义本身来自 [Achievements] 静态常量，这里仅维护运行时进度。
class AchievementState {
  /// 所有成就的进度列表（顺序与 [Achievements.all] 一致）
  final List<AchievementProgress> achievements;

  const AchievementState({
    this.achievements = const [],
  });

  AchievementState copyWith({List<AchievementProgress>? achievements}) {
    return AchievementState(
      achievements: achievements ?? this.achievements,
    );
  }

  /// 是否已解锁
  bool isUnlocked(String id) {
    return achievements.any((a) => a.id == id && a.unlocked);
  }

  /// 已解锁数量
  int get unlockedCount => achievements.where((a) => a.unlocked).length;

  /// 总成就数
  int get totalCount => achievements.length;
}

/// 成就系统 Notifier
class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier() : super(const AchievementState()) {
    // 初始化为所有成就的默认进度
    _initFromDefinitions();
  }

  void _initFromDefinitions() {
    final list = Achievements.all
        .map((a) => AchievementProgress(id: a.id))
        .toList();
    state = AchievementState(achievements: list);
  }

  /// 直接设置成就列表（用于从持久化数据恢复）
  void setAchievements(List<AchievementProgress> achievements) {
    state = AchievementState(achievements: achievements);
  }

  /// 从已解锁 ID 列表恢复状态
  ///
  /// 用于与旧版 [GameState.achievements]（`List<String>`）兼容。
  void restoreFromIds(List<String> unlockedIds) {
    final list = Achievements.all.map((a) {
      final unlocked = unlockedIds.contains(a.id);
      return AchievementProgress(
        id: a.id,
        unlocked: unlocked,
        progress: unlocked ? 1 : 0,
      );
    }).toList();
    state = AchievementState(achievements: list);
  }

  /// 更新某个成就的进度，达到阈值时自动解锁
  ///
  /// 返回是否新解锁。
  bool updateProgress(String id, int progress, {int? threshold}) {
    final def = Achievements.all.firstWhere(
      (a) => a.id == id,
      orElse: () => const Achievement(
        id: '',
        name: '',
        desc: '',
        emoji: '',
      ),
    );
    if (def.id.isEmpty) return false;

    final achievements = List<AchievementProgress>.from(state.achievements);
    final idx = achievements.indexWhere((a) => a.id == id);
    if (idx < 0) return false;

    final current = achievements[idx];
    if (current.unlocked) return false;

    final shouldUnlock =
        threshold != null ? progress >= threshold : progress > 0;
    if (!shouldUnlock) {
      achievements[idx] = current.copyWith(progress: progress);
      state = AchievementState(achievements: achievements);
      return false;
    }

    achievements[idx] = current.copyWith(
      unlocked: true,
      progress: progress,
      unlockedAt: _todayStr(),
    );
    state = AchievementState(achievements: achievements);
    return true;
  }

  /// 强制解锁某成就
  bool unlock(String id) {
    final achievements = List<AchievementProgress>.from(state.achievements);
    final idx = achievements.indexWhere((a) => a.id == id);
    if (idx < 0) return false;
    if (achievements[idx].unlocked) return false;
    achievements[idx] = achievements[idx].copyWith(
      unlocked: true,
      unlockedAt: _todayStr(),
    );
    state = AchievementState(achievements: achievements);
    return true;
  }

  /// 导出已解锁 ID 列表（用于持久化兼容）
  List<String> exportUnlockedIds() {
    return state.achievements
        .where((a) => a.unlocked)
        .map((a) => a.id)
        .toList();
  }

  /// 重置
  void reset() {
    _initFromDefinitions();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// 成就系统 Provider
final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>((ref) {
  return AchievementNotifier();
});
