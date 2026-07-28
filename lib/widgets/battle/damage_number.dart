import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 伤害飘字类型
enum DamageType {
  ///  普通伤害（白色�
  damage,

  /// 克制伤害 / 暴击（橙黄色，放大）
  critical,

  ///  被克伤害（灰色，缩小�
  weak,

  ///  治愈 / 护盾吸收（青色，SHIELD 文字�
  shield,

  /// 治疗（绿色）
  heal,
}

/// 单条伤害飘字
///
/// 设计参�?Web �?DamageNumber.tsx�?/// - 从怪物位置飞出，向上飘�?+ 淡出
/// - 普通伤害：白色
/// - 暴击（克制）：橙黄色 + 放大
/// - 被克：灰�?+ 缩小
/// - 护盾吸收：青�?"SHIELD" 文字
class DamageNumber extends StatefulWidget {
  ///  唯一 ID（用�?key 管理�
  final String id;

  /// 数值（伤害�?/ 治疗�?/ 护盾值）
  final int value;

  /// 类型
  final DamageType type;

  ///  初始水平偏移（相对怪物中心�
  final double offsetX;

  /// 动画结束回调
  final VoidCallback onComplete;

  /// 动画时长
  final Duration duration;

  const DamageNumber({
    super.key,
    required this.id,
    required this.value,
    required this.type,
    required this.onComplete,
    this.offsetX = 0,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  State<DamageNumber> createState() => _DamageNumberState();
}

class _DamageNumberState extends State<DamageNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _yAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _xDiffAnimation;

  // 随机抖动
  final math.Random _rng = math.Random();
  late final double _randomX;
  late final double _randomRotation;

  @override
  void initState() {
    super.initState();
    _randomX = (_rng.nextDouble() - 0.5) * 40;
    _randomRotation = (_rng.nextDouble() - 0.5) * 0.3;

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _yAnimation = Tween<double>(begin: 0, end: -90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 30),
    ]).animate(_controller);
    _scaleAnimation = TweenSequence<double>([
      // 入场弹出
      TweenSequenceItem(tween: Tween(begin: 0.5, end: _targetScale * 1.15),
          weight: 15),
      // 回到目标
      TweenSequenceItem(
          tween: Tween(begin: _targetScale * 1.15, end: _targetScale),
          weight: 15),
      // 保持
      TweenSequenceItem(
          tween: Tween(begin: _targetScale, end: _targetScale),
          weight: 50),
      // 末段轻微缩放
      TweenSequenceItem(
          tween: Tween(begin: _targetScale, end: _targetScale * 0.9),
          weight: 20),
    ]).animate(_controller);
    _xDiffAnimation = Tween<double>(begin: 0, end: _randomX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  double get _targetScale {
    switch (widget.type) {
      case DamageType.critical:
        return 1.5;
      case DamageType.weak:
        return 0.85;
      case DamageType.shield:
        return 1.1;
      default:
        return 1.0;
    }
  }

  double get _fontSize {
    switch (widget.type) {
      case DamageType.critical:
        return 30;
      case DamageType.shield:
        return 18;
      default:
        return 24;
    }
  }

  Color get _color {
    switch (widget.type) {
      case DamageType.critical:
        return AppColors.gold;
      case DamageType.weak:
        return AppColors.text2;
      case DamageType.shield:
        return const Color(0xFF4ECDC4);
      case DamageType.heal:
        return AppColors.green;
      case DamageType.damage:
        return Colors.white;
    }
  }

  String get _prefix {
    switch (widget.type) {
      case DamageType.critical:
        return '暴击! -';
      case DamageType.shield:
        return 'SHIELD ';
      case DamageType.heal:
        return '+';
      case DamageType.damage:
        return '-';
      case DamageType.weak:
        return '-${widget.value} (�?';
      // weak 直接返回完整字串
    }
  }

  String get _displayText {
    if (widget.type == DamageType.weak) {
      return _prefix;
      //  已包含�
}
    return '$_prefix${widget.value}';
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
          offset: Offset(
            widget.offsetX + _xDiffAnimation.value,
            _yAnimation.value,
          ),
          child: Transform.rotate(
            angle: _randomRotation * _controller.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _displayText,
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w900,
                      color: _color,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: _color.withValues(alpha: 0.6),
                          blurRadius: widget.type == DamageType.critical
                              ? 20
                              : 8,
                        ),
                        const Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
