import 'package:flutter/material.dart';
import '../theme/motion.dart';
import '../theme/sculpt_progress.dart';

/// 应用内雕刻图标：按 [line] 选维纳斯/大卫目录，按阶段显示关键帧。
///
/// 0–4 可按 [sculptProgress] 交叉淡入；5–7 维护阶段直接切帧。
class SculptIcon extends StatelessWidget {
  final int? stage;
  final SculptLine line;
  final double? sculptProgress;
  final double size;
  final bool showLabel;
  final String? semanticLabel;

  const SculptIcon({
    super.key,
    this.stage,
    this.line = SculptLine.venus,
    this.sculptProgress,
    this.size = 72,
    this.showLabel = false,
    this.semanticLabel,
  });

  int get _stage {
    if (stage != null) return stage!.clamp(0, 7);
    if (sculptProgress != null) return sculptStageFromProgress(sculptProgress!);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    final current = _stage;
    final label = semanticLabel ?? '塑身工坊 · ${sculptStageLabels[current]}';

    Widget frame(int index, double opacity) {
      return Opacity(
        opacity: opacity,
        child: Image.asset(
          sculptAssetPath(line: line, stage: index),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          semanticLabel: label,
        ),
      );
    }

    final Widget inner;
    final progress = sculptProgress;
    if (current >= 5 || progress == null || reduce) {
      inner = frame(current, 1);
    } else {
      final fade = sculptCrossfade(progress);
      inner = fade.low == fade.high
          ? frame(fade.low, 1)
          : Stack(
              fit: StackFit.expand,
              children: [
                frame(fade.low, 1 - fade.t),
                frame(fade.high, fade.t),
              ],
            );
    }

    final body = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: inner,
      ),
    );

    if (!showLabel) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        const SizedBox(height: 6),
        Text(
          sculptStageLabels[current],
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
