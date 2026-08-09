import 'package:flutter/material.dart';

/// Emil 风格交互 / 动效 token（对齐 web interaction.ts）
class AppMotion {
  AppMotion._();

  // --- Scale ---
  static const double tapScale = 0.97;
  static const double thumbTapScale = 0.96;
  static const double enterScale = 0.95;
  static const double dialogScale = 0.95;

  // --- Duration ---
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration pageEnter = Duration(milliseconds: 280);
  static const Duration pageExit = Duration(milliseconds: 200);
  static const Duration dialog = Duration(milliseconds: 280);
  static const Duration floatLabel = Duration(milliseconds: 560);
  static const Duration stagger = Duration(milliseconds: 50);
  static const Duration staggerItem = Duration(milliseconds: 240);

  // --- Curves ---
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve ease = Curves.ease;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration normal) =>
      reduceMotion(context) ? Duration.zero : normal;

  static double pressScale(BuildContext context, {double scale = tapScale}) =>
      reduceMotion(context) ? 1.0 : scale;
}

/// 列表 / 分区短 stagger 入场
class ForgeStagger extends StatelessWidget {
  final int index;
  final Widget child;
  final bool animate;

  const ForgeStagger({
    super.key,
    required this.index,
    required this.child,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate || AppMotion.reduceMotion(context)) return child;

    final delay = AppMotion.stagger * index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.staggerItem + delay,
      curve: AppMotion.easeOut,
      builder: (context, t, child) {
        // 用 delay 近似：前 delay 比例保持起点
        final totalMs =
            (AppMotion.staggerItem + delay).inMilliseconds.toDouble();
        final delayMs = delay.inMilliseconds.toDouble();
        final local = totalMs <= 0
            ? 1.0
            : ((t * totalMs - delayMs) / AppMotion.staggerItem.inMilliseconds)
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: local,
          child: Transform.translate(
            offset: Offset(0, (1 - local) * 10),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
