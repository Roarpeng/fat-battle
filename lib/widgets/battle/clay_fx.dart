import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 凿击刨花：几片卷曲粘土屑沿打击方向飞出。
class ClayShavingPainter extends CustomPainter {
  final double progress;
  final Color clay;
  final Color graphite;
  final int seed;

  ClayShavingPainter({
    required this.progress,
    required this.clay,
    required this.graphite,
    this.seed = 7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = math.Random(seed);
    final origin = Offset(size.width * 0.42, size.height * 0.48);
    final n = 5;
    for (var i = 0; i < n; i++) {
      final t = (progress * 1.15 - i * 0.06).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final angle = -0.35 + i * 0.38 + (rng.nextDouble() - 0.5) * 0.25;
      final dist = size.shortestSide * (0.18 + t * 0.55 + rng.nextDouble() * 0.08);
      final c = origin + Offset(math.cos(angle) * dist, math.sin(angle) * dist - t * 10);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final curl = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + 6 * math.cos(angle + 1.2),
          c.dy + 5 * math.sin(angle + 1.2),
          c.dx + 11 * math.cos(angle),
          c.dy + 8 * math.sin(angle),
        );
      final paint = Paint()
        ..color = Color.lerp(clay, graphite, i.isOdd ? 0.35 : 0.08)!
            .withValues(alpha: 0.85 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 - t
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(curl, paint);
      canvas.drawCircle(
        c,
        2.2 * (1 - t * 0.4),
        Paint()..color = clay.withValues(alpha: 0.7 * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClayShavingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.clay != clay ||
      oldDelegate.graphite != graphite;
}

/// 死亡碎裂：粘土块与刨花向外崩解。
class ClayCrumblePainter extends CustomPainter {
  final double progress;
  final Color clay;
  final Color ember;
  final int seed;

  ClayCrumblePainter({
    required this.progress,
    required this.clay,
    required this.ember,
    this.seed = 11,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = math.Random(seed);
    final origin = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 14; i++) {
      final t = (progress * 1.1 - i * 0.03).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final angle = (i / 14) * math.pi * 2 + rng.nextDouble() * 0.4;
      final dist = size.shortestSide * (0.08 + t * (0.42 + rng.nextDouble() * 0.18));
      final c = origin + Offset(math.cos(angle) * dist, math.sin(angle) * dist + t * 16);
      final opacity = (1 - t).clamp(0.0, 1.0);
      final w = 5.0 + rng.nextDouble() * 6;
      final h = 3.0 + rng.nextDouble() * 4;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle + t * 1.4);
      final shard = Path()
        ..moveTo(-w / 2, 0)
        ..quadraticBezierTo(0, -h, w / 2, h * 0.2)
        ..quadraticBezierTo(0, h * 0.6, -w / 2, 0)
        ..close();
      final color = i % 5 == 0 ? ember : clay;
      canvas.drawPath(
        shard,
        Paint()..color = color.withValues(alpha: 0.8 * opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ClayCrumblePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.clay != clay ||
      oldDelegate.ember != ember;
}

/// 胜利短促凿击火花（不是彩带倾泻）。
class ChiselSparkPainter extends CustomPainter {
  final double progress;
  final Color spark;
  final Color clay;

  ChiselSparkPainter({
    required this.progress,
    required this.spark,
    required this.clay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final t = progress;
    final fade = t < 0.25 ? t / 0.25 : (1 - t) / 0.75;
    // 凿刃短线
    final blade = Paint()
      ..color = const Color(0xFFC5C0B6).withValues(alpha: 0.85 * fade)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      origin + const Offset(-18, 10),
      origin + const Offset(8, -6),
      blade,
    );
    for (var i = 0; i < 9; i++) {
      final angle = -1.1 + i * 0.28;
      final dist = 16 + t * (36 + i * 4.0);
      final p = origin + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      canvas.drawCircle(
        p,
        (2.6 - t * 1.4).clamp(0.6, 2.6),
        Paint()
          ..color = (i.isEven ? spark : clay).withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChiselSparkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.spark != spark;
}
