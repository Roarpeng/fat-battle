import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 能量护盾特效
///
/// 设计参�?Web �?EnergyShield.tsx�?/// - 护盾存在时，怪物周围环形光圈
/// - 青色渐变 + 旋转动画
/// - 护盾值越高，光圈越亮
///  - 护盾破碎时爆炸特效（通过 [ShieldBreakBurst] 实现�
class EnergyShield extends StatefulWidget {
  /// 护盾值（0..maxShield），决定光圈亮度
  final int value;

  ///  最大护盾�
  final int maxShield;

  ///  光圈直径（默�?280�
  final double size;

  /// 是否正在破碎（触发爆炸特效）
  final bool isBreaking;

  /// 破碎动画完成回调
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
  // 8 个粒子的旋转
  late final AnimationController _rotateController;

  // 内圈脉动
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // 外圈脉动
  late final AnimationController _outerPulseController;
  late final Animation<double> _outerPulseAnimation;

  // 破碎爆炸
  late final AnimationController _breakController;
  late final Animation<double> _breakScale;
  late final Animation<double> _breakOpacity;

  static const Color _shieldColor = Color(0xFF4ECDC4);
  static const Color _shieldDeep = Color(0xFF218C7B);

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.2, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _outerPulseController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _outerPulseAnimation = Tween<double>(begin: 0.1, end: 0.25).animate(
      CurvedAnimation(parent: _outerPulseController, curve: Curves.easeInOut),
    );

    _breakController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _breakScale = Tween<double>(begin: 1, end: 2).animate(
      CurvedAnimation(parent: _breakController, curve: Curves.easeOut),
    );
    _breakOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _breakController, curve: Curves.easeOut),
    );

    if (widget.isBreaking) {
      _breakController.forward().then((_) {
        widget.onBreakComplete?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant EnergyShield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isBreaking && widget.isBreaking) {
      _breakController.forward(from: 0).then((_) {
        widget.onBreakComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _outerPulseController.dispose();
    _breakController.dispose();
    super.dispose();
  }

  /// 护盾密度�?..1）：决定光圈亮度与粒子数
  double get _density {
    if (widget.maxShield <= 0) return 0;
    return (widget.value / widget.maxShield).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value <= 0 && !widget.isBreaking) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈虚线（脉动）
          _buildOuterDashedRing(),
          // 内圈实线（脉�?+ 发光�?          _buildInnerSolidRing(),
          //  8 个旋转粒�
          if (!widget.isBreaking) _buildRotatingDots(),
          // 破碎爆炸效果
          if (widget.isBreaking) _buildBreakBurst(),
        ],
      ),
    );
  }

  /// 内圈实线圆环
  Widget _buildInnerSolidRing() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: 0.3 + _density * 0.4,
          child: Transform.scale(
            scale: 1.0 + _pulseAnimation.value * 0.05,
            child: Container(
              width: widget.size * 0.88,
              height: widget.size * 0.88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _shieldColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _shieldColor.withValues(alpha: 0.2 + _density * 0.3),
                    blurRadius: 30,
                  ),
                  BoxShadow(
                    color: _shieldColor.withValues(alpha: 0.1 + _density * 0.2),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 外圈虚线圆环
  Widget _buildOuterDashedRing() {
    return AnimatedBuilder(
      animation: _outerPulseAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: 0.2 + _density * 0.3,
          child: Transform.scale(
            scale: 1.05 + _outerPulseAnimation.value * 0.05,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _DashedRingPainter(
                color: _shieldDeep,
                strokeWidth: 2,
                dashCount: 32,
                opacity: 0.6 + _density * 0.3,
              ),
            ),
          ),
        );
      },
    );
  }

  ///  8 个旋转粒�
  Widget _buildRotatingDots() {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, _) {
        return Transform.rotate(
          angle: _rotateController.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              children: List.generate(8, _buildDot),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final angle = (index * 45) * (math.pi / 180);
    final radius = widget.size * 0.44;
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _shieldColor,
          boxShadow: [
            BoxShadow(
              color: _shieldColor,
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  /// 护盾破碎爆炸效果
  Widget _buildBreakBurst() {
    return AnimatedBuilder(
      animation: _breakController,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _breakOpacity.value,
              child: Transform.scale(
                scale: _breakScale.value,
                child: Container(
                  width: widget.size * 0.88,
                  height: widget.size * 0.88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _shieldColor,
                      width: 4,
                    ),
                  ),
                ),
              ),
            ),
            //  8 个发散碎�
            ...List.generate(8, (i) {
              final angle = (i * 45) * (math.pi / 180);
              final distance = widget.size * 0.5 * _breakScale.value;
              return Transform.translate(
                offset: Offset(
                  math.cos(angle) * distance,
                  math.sin(angle) * distance,
                ),
                child: Opacity(
                  opacity: _breakOpacity.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _shieldColor,
                      boxShadow: [
                        BoxShadow(
                          color: _shieldColor,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

///  虚线圆环绘制�
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double opacity;

  _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final radius = size.width / 2 - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);

    //  �?Path 绘制虚线�
    final path = Path();
    final circumference = 2 * math.pi * radius;
    final dashLength = circumference / (dashCount * 2);
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * 2) * dashLength / radius;
      final endAngle = startAngle + dashLength / radius;
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
