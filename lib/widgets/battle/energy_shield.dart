import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../theme/motion.dart';

/// 哑光粘土壳护盾：龟裂纹理，破碎时裂开掉屑，而不是科幻六边形。
class EnergyShield extends StatefulWidget {
  final int value;
  final int maxShield;
  final double size;
  final bool isBreaking;
  final VoidCallback? onBreakComplete;

  const EnergyShield({
    super.key,
    required this.value,
    required this.maxShield,
    this.size = 280,
    this.isBreaking = false,
    this.onBreakComplete,
  });

  @override
  State<EnergyShield> createState() => _EnergyShieldState();
}

class _EnergyShieldState extends State<EnergyShield>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _breakController;
  late final Animation<double> _breakT;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.15, end: 0.32).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.clayBreathe),
    );

    _breakController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _breakT = CurvedAnimation(
      parent: _breakController,
      curve: AppMotion.chipOut,
    );

    if (widget.isBreaking) {
      _breakController.forward().then((_) => widget.onBreakComplete?.call());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = AppMotion.reduceMotion(context);
    if (reduce) {
      _pulseController.stop();
      _pulseController.value = 0.5;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant EnergyShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isBreaking && widget.isBreaking) {
      if (AppMotion.reduceMotion(context)) {
        _breakController.value = 1;
        widget.onBreakComplete?.call();
      } else {
        _breakController.forward(from: 0).then((_) {
          widget.onBreakComplete?.call();
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breakController.dispose();
    super.dispose();
  }

  double get _density {
    if (widget.maxShield <= 0) return 0;
    return (widget.value / widget.maxShield).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value <= 0 && !widget.isBreaking) {
      return const SizedBox.shrink();
    }

    final clay = Theme.of(context).colorScheme.secondary;
    final crust = Color.lerp(AppColors.card, clay, 0.55)!;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _breakController]),
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _ClayCrustPainter(
              color: crust,
              crack: clay,
              density: _density,
              pulse: _pulseAnimation.value,
              breakT: widget.isBreaking ? _breakT.value : 0,
            ),
          );
        },
      ),
    );
  }
}

class _ClayCrustPainter extends CustomPainter {
  final Color color;
  final Color crack;
  final double density;
  final double pulse;
  final double breakT;

  _ClayCrustPainter({
    required this.color,
    required this.crack,
    required this.density,
    required this.pulse,
    required this.breakT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;
    final opacity = (0.28 + density * 0.45) * (1 - breakT * 0.85);

    final ring = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 + pulse * 2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius * (1 + pulse * 0.03), ring);

    final inner = Paint()
      ..color = color.withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.86, inner);

    final crackPaint = Paint()
      ..color = crack.withValues(alpha: 0.45 + density * 0.25 + breakT * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 + breakT * 1.6
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 7; i++) {
      final a0 = (i / 7) * math.pi * 2 + 0.2;
      final a1 = a0 + 0.55;
      final r0 = radius * (0.82 + (i % 2) * 0.08);
      final r1 = radius * (1.02 + breakT * 0.12);
      final p0 = center + Offset(math.cos(a0) * r0, math.sin(a0) * r0);
      final p1 = center + Offset(math.cos(a1) * r1, math.sin(a1) * r1);
      final mid = Offset.lerp(p0, p1, 0.5)! +
          Offset(math.cos(a0 + 0.8) * 6, math.sin(a0 + 0.8) * 6);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, p1.dx, p1.dy);
      canvas.drawPath(path, crackPaint);
    }

    if (breakT > 0) {
      for (var i = 0; i < 8; i++) {
        final angle = (i / 8) * math.pi * 2;
        final dist = radius * (0.2 + breakT * 0.85);
        final c = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(angle + breakT);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 10, height: 6),
            const Radius.circular(1.5),
          ),
          Paint()..color = color.withValues(alpha: 1 - breakT),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClayCrustPainter oldDelegate) =>
      oldDelegate.density != density ||
      oldDelegate.pulse != pulse ||
      oldDelegate.breakT != breakT ||
      oldDelegate.color != color;
}
