import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../constants/app_constants.dart';
import '../forge_pressable.dart';

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

  Color get _accent =>
      tone == StageActionTone.food ? AppColors.copper : AppColors.ember;

  @override
  Widget build(BuildContext context) {
    final isForge = tone == StageActionTone.forge;

    return Expanded(
      child: ForgePressable(
        onTap: onTap,
        scale: AppMotion.thumbTapScale,
        haptic: ForgeHaptic.medium,
        borderRadius: AppRadii.lgAll,
        child: Container(
          height: 112,
          decoration: BoxDecoration(
            borderRadius: AppRadii.lgAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isForge
                  ? [
                      AppColors.ember.withValues(alpha: 0.98),
                      const Color(0xFFC23428),
                    ]
                  : [
                      AppColors.elevated,
                      AppColors.bg3,
                    ],
            ),
            border: Border.all(
              color: isForge
                  ? AppColors.forgeGlow.withValues(alpha: 0.45)
                  : AppColors.copper.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: isForge ? 0.32 : 0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.md,
            AppSpace.lg,
            AppSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isForge ? AppColors.onEmber : AppColors.copper,
                size: 26,
              ),
              const Spacer(),
              Text(
                label,
                style: AppFonts.display(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isForge ? AppColors.onEmber : AppColors.text,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                subtitle,
                style: AppFonts.body(
                  fontSize: 12,
                  color: isForge
                      ? AppColors.onEmber.withValues(alpha: 0.78)
                      : AppColors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
