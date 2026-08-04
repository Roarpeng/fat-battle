import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/forge_theme.dart';

import '../../constants/app_constants.dart';

enum StageActionTone { food, forge }

/// 舞台拇指区大按钮（饮食 / 锤炼）
class StageActionButton extends StatefulWidget {
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
  State<StageActionButton> createState() => _StageActionButtonState();
}

class _StageActionButtonState extends State<StageActionButton> {
  bool _pressed = false;

  Color get _accent => widget.tone == StageActionTone.food
      ? AppColors.copper
      : AppColors.ember;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.tone == StageActionTone.forge
                    ? [
                        AppColors.ember.withValues(alpha: 0.95),
                        const Color(0xFFB33A2C),
                      ]
                    : [
                        AppColors.card,
                        AppColors.bg3,
                      ],
              ),
              border: Border.all(
                color: widget.tone == StageActionTone.forge
                    ? AppColors.forgeGlow.withValues(alpha: 0.5)
                    : AppColors.copper.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.icon,
                  color: widget.tone == StageActionTone.forge
                      ? const Color(0xFFFFF8F5)
                      : AppColors.copper,
                  size: 26,
                ),
                const Spacer(),
                Text(
                  widget.label,
                  style: AppFonts.display(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.tone == StageActionTone.forge
                        ? const Color(0xFFFFF8F5)
                        : AppColors.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: AppFonts.body(
                    fontSize: 12,
                    color: widget.tone == StageActionTone.forge
                        ? const Color(0xFFFFF8F5).withValues(alpha: 0.78)
                        : AppColors.text2,
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
