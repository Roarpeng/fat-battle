import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';
import '../constants/app_constants.dart';
import '../providers/achievement_provider.dart';
import '../providers/game_provider.dart';
import '../widgets/home/forge_background.dart';

/// 成就页面
///
/// 解锁状态以 [gameStateProvider] 为准（持久化存档），
/// 进入页面时同步到 [achievementProvider] 以便展示结构化进度。
class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage> {
  TextStyle get _displayStyle => AppFonts.display(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  TextStyle get _mutedStyle =>
      AppFonts.body(color: AppColors.text2, fontSize: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromGameState());
  }

  void _syncFromGameState() {
    final gs = ref.read(gameStateProvider);
    ref.read(achievementProvider.notifier).restoreFromIds(gs.achievements);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameStateProvider, (_, next) {
      ref.read(achievementProvider.notifier).restoreFromIds(next.achievements);
    });

    final gameState = ref.watch(gameStateProvider);
    final achievementState = ref.watch(achievementProvider);
    final unlocked = achievementState.unlockedCount;
    final total = Achievements.all.length;

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('成就', style: _displayStyle.copyWith(fontSize: 20)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.sm,
              ),
              child: _ProgressHeader(
                unlocked: unlocked,
                total: total,
                displayStyle: _displayStyle,
                mutedStyle: _mutedStyle,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: AppSpace.page.copyWith(bottom: AppSpace.xxl),
                itemCount: Achievements.all.length,
                itemBuilder: (context, index) {
                  final def = Achievements.all[index];
                  final progress = achievementState.achievements
                      .where((a) => a.id == def.id)
                      .firstOrNull;
                  final unlocked = progress?.unlocked ??
                      gameState.achievements.contains(def.id);
                  final (current, target) = _progressFor(def.id, gameState);

                  return _AchievementTile(
                    achievement: def,
                    unlocked: unlocked,
                    current: current,
                    target: target,
                    unlockedAt: progress?.unlockedAt ?? '',
                    displayStyle: _displayStyle,
                    bodyStyle: _bodyStyle,
                    mutedStyle: _mutedStyle,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  final TextStyle displayStyle;
  final TextStyle mutedStyle;

  const _ProgressHeader({
    required this.unlocked,
    required this.total,
    required this.displayStyle,
    required this.mutedStyle,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? unlocked / total : 0.0;
    return ForgeSurface(
      borderColor: AppColors.copper.withValues(alpha: 0.35),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, color: AppColors.copper, size: 20),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  '已解锁 $unlocked / $total',
                  style: displayStyle.copyWith(
                    color: AppColors.copper,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: mutedStyle.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpace.sm - 2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ember),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final int current;
  final int target;
  final String unlockedAt;
  final TextStyle displayStyle;
  final TextStyle bodyStyle;
  final TextStyle mutedStyle;

  const _AchievementTile({
    required this.achievement,
    required this.unlocked,
    required this.current,
    required this.target,
    required this.unlockedAt,
    required this.displayStyle,
    required this.bodyStyle,
    required this.mutedStyle,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        target > 0 ? (current / target).clamp(0.0, 1.0) : (unlocked ? 1.0 : 0.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: ForgeSurface(
        color: unlocked
            ? AppColors.copper.withValues(alpha: 0.08)
            : AppColors.elevated,
        borderColor: unlocked
            ? AppColors.copper.withValues(alpha: 0.4)
            : AppColors.border,
        padding: const EdgeInsets.all(AppSpace.lg - 2),
        child: Row(
          children: [
            Opacity(
              opacity: unlocked ? 1.0 : 0.45,
              child: Icon(
                AppIcons.achievement(achievement.id),
                size: 36,
                color: unlocked ? AppColors.gold : AppColors.text2,
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.name,
                          style: displayStyle.copyWith(
                            fontSize: 15,
                            color: unlocked ? AppColors.text : AppColors.text2,
                          ),
                        ),
                      ),
                      if (unlocked)
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.copper, size: 18),
                    ],
                  ),
                  Text(achievement.desc, style: mutedStyle),
                  if (!unlocked && target > 0) ...[
                    const SizedBox(height: AppSpace.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpace.xs),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surface,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppColors.ember),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs - 2),
                    Text('$current / $target', style: mutedStyle.copyWith(fontSize: 10)),
                  ],
                  if (unlocked && unlockedAt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.xs),
                      child: Text(
                        '解锁于 $unlockedAt',
                        style: bodyStyle.copyWith(
                          color: AppColors.green,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 根据 gameState 计算成就进度（与 game_provider._checkAchievements 对齐）
(int current, int target) _progressFor(String id, GameState gs) {
  switch (id) {
    case 'first_kill':
      return (gs.kills, 1);
    case 'kill_5':
      return (gs.kills, 5);
    case 'kill_10':
      return (gs.kills, 10);
    case 'streak_3':
      return (gs.streak, 3);
    case 'streak_7':
      return (gs.streak, 7);
    case 'streak_30':
      return (gs.streak, 30);
    case 'exercise_1000':
      return (gs.todayCalExercise, 1000);
    case 'coins_1000':
      return (gs.coins, 1000);
    case 'boss_kill':
      return (gs.kills >= 3 ? 1 : 0, 1);
    case 'weight_5':
      final lost = (gs.user.weight - gs.user.targetWeight).clamp(0, 999).toInt();
      return (lost, 5);
    case 'day_7':
      return (gs.day, 7);
    case 'day_30':
      return (gs.day, 30);
    default:
      return (0, 1);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
