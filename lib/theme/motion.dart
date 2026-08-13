import 'package:flutter/material.dart';

/// 塑身工坊交互 / 动效 token：雕刻工具感，而不是 iOS 默认弹性。
class AppMotion {
  AppMotion._();

  // --- Scale / offset ---
  /// 略深的按压（凿一下），比 0.97 更像工具落点
  static const double tapScale = 0.94;
  static const double thumbTapScale = 0.93;
  static const double enterScale = 0.95;
  static const double dialogScale = 0.95;
  /// 按压时下沉 1px，模拟凿子点到粘土
  static const double tapDip = 1.0;

  // --- Duration ---
  static const Duration tap = Duration(milliseconds: 140);
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration pageEnter = Duration(milliseconds: 280);
  static const Duration pageExit = Duration(milliseconds: 200);
  static const Duration dialog = Duration(milliseconds: 280);
  static const Duration floatLabel = Duration(milliseconds: 560);
  static const Duration stagger = Duration(milliseconds: 50);
  static const Duration staggerItem = Duration(milliseconds: 240);
  static const Duration hpFill = Duration(milliseconds: 420);
  static const Duration chipFly = Duration(milliseconds: 980);
  static const Duration spark = Duration(milliseconds: 620);

  // --- Curves ---
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve ease = Curves.ease;
  /// 血条：冷却金属 / 石墨笔触，先快后滞
  static const Curve metalCool = Cubic(0.22, 0.61, 0.12, 1.0);
  /// 刨花飞出：短促推出后失速
  static const Curve chipOut = Cubic(0.16, 0.84, 0.32, 1.0);
  /// 粘土呼吸：慢、沉，避免卡通弹跳
  static const Curve clayBreathe = Cubic(0.37, 0.0, 0.63, 1.0);

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration normal) =>
      reduceMotion(context) ? Duration.zero : normal;

  static double pressScale(BuildContext context, {double scale = tapScale}) =>
      reduceMotion(context) ? 1.0 : scale;

  static double pressDip(BuildContext context, {double dip = tapDip}) =>
      reduceMotion(context) ? 0.0 : dip;
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
