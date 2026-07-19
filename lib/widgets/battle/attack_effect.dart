import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 攻击类型（运动类�?�?颜色映射�?enum AttackKind {
  /// 有氧（绿色风�?  cardio,

  /// 力量（红色冲击）
  strength,

  /// 核心（蓝色波纹）
  core,
}

/// 攻击特效配置
extension AttackKindExt on AttackKind {
  Color get color {
    switch (this) {
      case AttackKind.cardio:
        return AppColors.green;
      case AttackKind.strength:
        return AppColors.red;
      case AttackKind.core:
        return const Color(0xFF4A90E2);
    }
  }

  String get emoji {
    switch (this) {
      case AttackKind.cardio:
        return '💨';
      case AttackKind.strength:
        return '💥';
      case AttackKind.core:
        return '🌊';
    }
  }

  String get label {
    switch (this) {
      case AttackKind.cardio:
        return '有氧冲击�?;
      case AttackKind.strength:
        return '力量爆发�?;
      case AttackKind.core:
        return '核心震荡�?;
    }
  }
}

/// 攻击瞬间闪光特效
///
/// 设计参�?Web �?AttackEffect.tsx�?/// - 攻击瞬间的图标飞�?+ 闪光
/// - 不同运动类型不同颜色�?///   - cardio（有氧）：绿色风
///   - strength（力量）：红色冲�?///   - core（核心）：蓝色波�?/// - 持续�?300-500ms 消散
class AttackEffect extends StatefulWidget {
  /// 唯一 ID
  final String id;

  /// 攻击类型
  final AttackKind kind;

  /// 伤害�?  final int damage;

  /// 动画结束回调
  final VoidCallback onComplete;

  const AttackEffect({
    super.key,
    required this.id,
    required this.kind,
    required this.damage,
    required this.onComplete,
  });

  @override
  State<AttackEffect> createState() => _AttackEffectState();
}

class _AttackEffectState extends State<AttackEffect>
    with TickerProviderStateMixin {
  // 主图标飞�?+ 消散
  late final AnimationController _iconController;
  late final Animation<double> _iconX;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;

  // 闪光圆环扩散
  late final AnimationController _flashController;
  late final Animation<double> _flashScale1;
  late final Animation<double> _flashOpacity1;
  late final Animation<double> _flashScale2;
  late final Animation<double> _flashOpacity2;

  // 标签淡入
  late final AnimationController _labelController;
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelY;

  @override
  void initState() {
    super.initState();

    // 图标飞入�?00ms
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _iconX = Tween<double>(begin: -150, end: 0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeIn),
    );
    _iconOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_iconController);
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1, end: 2), weight: 40),
    ]).animate(_iconController);

    // 闪光扩散�?00ms
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flashScale1 = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _flashOpacity1 = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _flashScale2 = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _flashOpacity2 = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    // 标签
    _labelController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _labelOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 20),
    ]).animate(_labelController);
    _labelY = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _labelController, curve: Curves.easeOut),
    );

    // 时序：图标先飞入，然后闪光，标签同步淡入
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _flashController.forward();
    });
    _labelController.forward();

    // 整体 700ms 后结�?    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _flashController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 闪光圆环 1（外层）
            _buildFlashRing(
              scale: _flashScale1,
              opacity: _flashOpacity1,
              size: 96,
              blur: true,
            ),
            // 闪光圆环 2（内层）
            _buildFlashRing(
              scale: _flashScale2,
              opacity: _flashOpacity2,
              size: 64,
              blur: false,
            ),
            // 主图标飞�?            _buildIcon(),
            // 标签徽章（顶部）
            _buildLabel(),
          ],
        ),
      ),
    );
  }

  /// 攻击图标飞入
  Widget _buildIcon() {
    return AnimatedBuilder(
      animation: _iconController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(_iconX.value, 0),
          child: Transform.scale(
            scale: _iconScale.value,
            child: Opacity(
              opacity: _iconOpacity.value,
              child: Text(
                widget.kind.emoji,
                style: const TextStyle(
                  fontSize: 56,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 闪光圆环扩散
  Widget _buildFlashRing({
    required Animation<double> scale,
    required Animation<double> opacity,
    required double size,
    required bool blur,
  }) {
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, _) {
        return Opacity(
          opacity: opacity.value,
          child: Transform.scale(
            scale: scale.value,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.kind.color.withValues(alpha: 0.5),
                boxShadow: blur
                    ? [
                        BoxShadow(
                          color: widget.kind.color.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 顶部伤害标签
  Widget _buildLabel() {
    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _labelController,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _labelY.value),
              child: Opacity(
                opacity: _labelOpacity.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.kind.color.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: widget.kind.color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.kind.label} -${widget.damage}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 攻击粒子（向 8 个方向发散）
class AttackShard extends StatefulWidget {
  final int index;
  final AttackKind kind;
  final double distance;
  final Duration delay;
  final VoidCallback onComplete;

  const AttackShard({
    super.key,
    required this.index,
    required this.kind,
    required this.distance,
    required this.delay,
    required this.onComplete,
  });

  @override
  State<AttackShard> createState() => _AttackShardState();
}

class _AttackShardState extends State<AttackShard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final angle = (widget.index * 45) * (math.pi / 180);
    final dx = math.cos(angle) * widget.distance;
    final dy = math.sin(angle) * widget.distance;

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 70),
    ]).animate(_controller);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 70),
    ]).animate(_controller);
    _offset = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(dx, dy),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) => widget.onComplete());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.translate(
          offset: _offset.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.kind.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.kind.color,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
