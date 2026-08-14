import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/forge_theme.dart';
import '../../theme/tokens.dart';

import '../../providers/game_provider.dart';
import '../battle/forge_monster_art.dart';
import '../hp_bar.dart';

/// 饮食 / 锤炼子页顶栏迷你怪 — 2.0
class MiniMonsterHeader extends ConsumerWidget {
  const MiniMonsterHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(gameStateProvider);
    final c = ForgeColors.of(context);
    if (!gs.hasGame) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.md,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.elevated,
              border: Border.all(
                color: gs.monster.hasShield
                    ? c.shield
                    : c.copper.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: ForgeMonsterArt(
              kind: monsterKindOf(gs.monster.emoji),
              size: 32,
              isEnraged: gs.monster.isBoss
                  ? gs.monster.hpPercent < 0.4
                  : gs.monster.hpPercent < 0.3,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gs.monster.name,
                  style: AppFonts.bodyOf(
                    context,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                HpBar(
                  current: gs.monster.hp,
                  max: gs.monster.maxHp,
                  color: c.ember,
                  shield: gs.monster.shield,
                  shieldColor: c.shield,
                  height: 10,
                  showText: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            '${gs.monster.hp}/${gs.monster.maxHp}',
            style: AppFonts.bodyOf(
              context,
              fontSize: 11,
              color: c.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
