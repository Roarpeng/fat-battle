import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../constants/app_constants.dart';

/// 通用进度条（饥饿/体力/经验等）— 锻造工坊风格
class StatBar extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;
  final Color color;

  const StatBar({
    super.key,
    required this.label,
    required this.valueText,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final body = AppFonts.body(color: AppColors.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: body.copyWith(color: AppColors.text2, fontSize: 12)),
            Text(valueText, style: body.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.bg2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
