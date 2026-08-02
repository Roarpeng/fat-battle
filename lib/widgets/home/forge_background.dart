import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 锻造工坊氛围背景：径向炉火光 + 暗角 + 漂浮火星粒子
///
/// 设计语言：
/// - 顶部炉火辉光（ember 橙红）沿重力方向下沉，底部回归炭黑
/// - 火星粒子从炉口缓慢上浮、变暗、消失（模拟锻炉飞星）
/// - 细横纹暗示锻打金属的纹理
class ForgeBackground extends StatefulWidget {
  final Widget child;
  /// 粒子浓度：0 关闭粒子（省电/低端机）
  final double particleDensity;

  const ForgeBackground({super.key, required this.child, this.particleDensity = 1.0});

  @override
  State<ForgeBackground> createState() => _ForgeBackgroundState();
}

/// flutter test 运行时设置 FLUTTER_TEST=true。
/// 测试环境禁用无限循环动画，避免 pumpAndSettle 永不结束。
final bool _kIsFlutterTest =
    Platform.environment['FLUTTER_TEST'] == 'true';

class _ForgeBackgroundState extends State<ForgeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (!_kIsFlutterTest) {
      _controller.repeat();
    }

    // 用固定种子的随机生成，避免每次重建布局变化
    final rng = math.Random(42);
    final count = (16 * widget.particleDensity).round().clamp(0, 32);
    _sparks = List.generate(count, (i) {
      return _Spark(
        x: rng.nextDouble(),
        y: 0.72 + rng.nextDouble() * 0.28, // 起始于炉火区域（画面下半部）
        size: 1.2 + rng.nextDouble() * 2.2,
        speed: 0.012 + rng.nextDouble() * 0.03,
        drift: (rng.nextDouble() - 0.5) * 0.5,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.15,
          colors: [
            Color(0xFF2A1E16),
            AppColors.bg,
          ],
          stops: [0.0, 0.72],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.bg.withValues(alpha: 0.55),
                    AppColors.bg,
                  ],
                  stops: const [0.45, 0.82, 1],
                ),
              ),
            ),
          ),
          // 炉口底部余烬微光
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0.95),
                    radius: 1.4,
                    colors: [
                      AppColors.ember.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          // 细微横纹纹理感
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ForgeGrainPainter()),
            ),
          ),
          // 漂浮火星粒子
          if (widget.particleDensity > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _SparkPainter(
                      sparks: _sparks,
                      t: _controller.value,
                    ),
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

/// 一颗火星：位置、大小、上浮速度、横向漂移、闪烁相位
class _Spark {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double drift;
  final double phase;

  const _Spark({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.phase,
  });
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double t;

  const _SparkPainter({required this.sparks, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparks) {
      // 纵向：从炉口上浮，越往上越淡；循环回炉口
      final rawY = s.y - t * s.speed;
      final y = (rawY % 1.0) * size.height;
      // 横向：轻微正弦漂移
      final x = (s.x + math.sin(t * 2 * math.pi + s.phase) * s.drift * 0.05) *
          size.width;
      // 亮度：上浮过程中先升后衰（火柴燃烧感），并叠加呼吸闪烁
      final fade = y / size.height; // 顶部 0 → 底部 1（火星从底部上来）
      final lift = math.sin(t * 2 * math.pi + s.phase) * 0.5 + 0.5;
      final alpha = (1 - fade) * (0.55 + lift * 0.45);
      if (alpha <= 0.02) continue;

      final paint = Paint()
        ..color = AppColors.forgeGlow.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(
        Offset(x, y),
        s.size * (0.8 + lift * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.sparks != sparks;
}

class _ForgeGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.copper.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
