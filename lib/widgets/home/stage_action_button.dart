import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../forge_pressable.dart';
import '../sketch_card.dart';

enum StageActionTone { food, forge }

/// 舞台拇指区大按钮（饮食 / 锤炼）— 锻造工坊 2.0
class StageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final StageActionTone tone;
  final VoidCallback onTap;

  const StageActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = ForgeColors.of(context);
    final isForge = tone == StageActionTone.forge;
    final accent = isForge ? c.ember : c.copper;

    return Expanded(
      child: ForgePressable(
        onTap: onTap,
        scale: AppMotion.thumbTapScale,
        haptic: ForgeHaptic.medium,
        borderRadius: AppRadii.lgAll,
        child: SketchCard(
          borderRadius: AppRadii.lgAll,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.md,
          ),
          color: isForge ? c.ember : c.elevated,
          borderColor: isForge
              ? c.forgeGlow.withValues(alpha: 0.45)
              : c.copper.withValues(alpha: 0.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isForge ? 0.32 : 0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          child: SizedBox(
            height: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isForge ? c.onEmber : c.copper,
                  size: 26,
                ),
                const Spacer(),
                Text(
                  label,
                  style: AppFonts.displayOf(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isForge ? c.onEmber : c.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  subtitle,
                  style: AppFonts.bodyOf(
                    context,
                    fontSize: 12,
                    color: isForge
                        ? c.onEmber.withValues(alpha: 0.78)
                        : c.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
