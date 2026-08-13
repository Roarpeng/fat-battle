import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/app_constants.dart';
import '../../providers/game_provider.dart';
import '../../services/progress_sync_service.dart';
import '../../theme/forge_theme.dart';
import '../../theme/tokens.dart';
import '../forge_pressable.dart';

/// 设置页「云同步」状态块（独立文件，降低与 settings_page 其它改动的合并冲突）
///
/// 展示：未配置后端 / 游客 / 上次成功 / 上次错误，并提供立即同步。
class SyncStatusTile extends ConsumerStatefulWidget {
  const SyncStatusTile({super.key});

  @override
  ConsumerState<SyncStatusTile> createState() => _SyncStatusTileState();
}

class _SyncStatusTileState extends ConsumerState<SyncStatusTile> {
  final ProgressSyncService _sync = ProgressSyncService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSync);
    _sync.hydrateStatus();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }

  void _onSync() {
    if (mounted) setState(() {});
  }

  Color get _dotColor {
    switch (_sync.status.phase) {
      case ProgressSyncPhase.success:
        return AppColors.green;
      case ProgressSyncPhase.syncing:
        return AppColors.copper;
      case ProgressSyncPhase.error:
        return AppColors.red;
      case ProgressSyncPhase.notConfigured:
      case ProgressSyncPhase.guest:
      case ProgressSyncPhase.idle:
        return AppColors.text2;
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final game = ref.read(gameStateProvider);
      await _sync.syncNow(
        localJson: game.toJson(),
        localHasGame: game.hasGame,
        applyRemote: (json) async {
          await ref.read(gameStateProvider.notifier).replaceState(
                GameState.fromJson(json),
              );
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _sync.status;
    final canTap = status.phase != ProgressSyncPhase.notConfigured &&
        status.phase != ProgressSyncPhase.guest &&
        !(_busy || status.phase == ProgressSyncPhase.syncing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GameState 云备份',
                    style: AppFonts.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    status.subtitle,
                    style: AppFonts.body(fontSize: 12, color: AppColors.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        ForgePressable(
          enabled: canTap,
          onTap: canTap ? _syncNow : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadii.smAll,
              border: Border.all(
                color: AppColors.copper.withValues(alpha: 0.45),
              ),
            ),
            child: _busy || status.phase == ProgressSyncPhase.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    canTap ? '立即同步' : '当前无法同步',
                    style: AppFonts.body(
                      fontWeight: FontWeight.w600,
                      color: canTap ? AppColors.copper : AppColors.text2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
