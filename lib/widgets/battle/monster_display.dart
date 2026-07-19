import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 怪物显示组件
///
/// 设计参�?Web �?MonsterAnimation.tsx�?/// - 持续浮动动画（上下移动）
/// - 受伤时抖�?+ 红色滤镜
/// - 狂暴时红色光�?+ emoji 放大 1.1x
/// - 阶段切换�?fade 过渡
/// - 死亡时灰�?+ 旋转消失
/// - HP < 50% 显示情绪 emoji，HP < 30% 显示血�?class MonsterDisplay extends StatefulWidget {
  /// 怪物 emoji
  final String emoji;

  /// 当前 HP 百分比（0..1�?  final double hpPercentage;

  /// 是否正在受伤（触发抖�?+ 红色滤镜�?  final bool isHit;

  /// 是否狂暴（触发红色光�?+ 放大�?  final bool isEnraged;

  /// 是否死亡（触发灰�?+ 旋转消失�?  final bool isDead;

  /// 是否处于阶段切换（触�?fade 过渡�?  final bool isPhaseChanging;

  /// emoji 基础字号
  final double emojiSize;

  /// 点击回调
  final VoidCallback? onTap;

  const MonsterDisplay({
    super.key,
    required this.emoji,
    required this.hpPercentage,
    this.isHit = false,
    this.isEnraged = false,
    this.isDead = false,
    this.isPhaseChanging = false,
    this.emojiSize = 96,
    this.onTap,
  });

  @override
  State<MonsterDisplay> createState() => _MonsterDisplayState();
}

class _MonsterDisplayState extends State<MonsterDisplay>
    with TickerProviderStateMixin {
  // 持续浮动
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // 持续呼吸缩放
  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  // 受伤抖动
  late final AnimationController _hitController;
  late final Animation<double> _hitShakeAnimation;
  late final Animation<double> _hitScaleAnimation;

  // 死亡动画
  late final AnimationController _deathController;
  late final Animation<double> _deathRotation;
  late final Animation<double> _deathScale;
  late final Animation<double> _deathOpacity;

  // 阶段切换 fade
  late final AnimationController _phaseController;
  late final Animation<double> _phaseFade;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _hitController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _hitShakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _hitController, curve: Curves.linear),
    );
    _hitScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _hitController, curve: Curves.linear),
    );

    _deathController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _deathRotation = Tween<double>(begin: 0, end: -math.pi / 2).animate(
      CurvedAnimation(parent: _deathController, curve: Curves.easeIn),
    );
    _deathScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _deathController, curve: Curves.easeIn),
    );
    _deathOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _deathController, curve: Curves.linear),
    );

    _phaseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _phaseFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _phaseController, curve: Curves.easeInOut),
    );

    if (widget.isDead) {
      _deathController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MonsterDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 受伤触发
    if (!oldWidget.isHit && widget.isHit) {
      _hitController.forward(from: 0);
    }
    // 死亡触发
    if (!oldWidget.isDead && widget.isDead) {
      _deathController.forward(from: 0);
    }
    // 阶段切换触发
    if (!oldWidget.isPhaseChanging && widget.isPhaseChanging) {
      _phaseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _breatheController.dispose();
    _hitController.dispose();
    _deathController.dispose();
    _phaseController.dispose();
    super.dispose();
  }

  /// 根据 HP 百分比返回情�?emoji
  String _getEmotionEmoji() {
    if (widget.isDead) return '💀';
    if (widget.hpPercentage < 0.2) return '😵';
    if (widget.hpPercentage < 0.4) return '😫';
    if (widget.hpPercentage < 0.6) return '😠';
    if (widget.hpPercentage < 0.8) return '😏';
    return '😈';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.emojiSize * 1.6,
        height: widget.emojiSize * 1.6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 狂暴红色光晕背景
            if (widget.isEnraged && !widget.isDead) _buildEnrageGlow(),
            // 死亡爆炸光晕
            if (widget.isDead) _buildDeathGlow(),
            // 主体怪物 emoji
            _buildMonster(),
            // 受伤爆炸特效
            if (widget.isHit) _buildHitBurst(),
            // HP < 30% 血迹效�?            if (widget.hpPercentage < 0.3 && !widget.isDead) _buildBloodOverlay(),
            // HP < 50% 情绪 emoji
            if (widget.hpPercentage < 0.5 && !widget.isDead) _buildEmotionBadge(),
          ],
        ),
      ),
    );
  }

  /// 主体怪物 emoji（浮�?+ 呼吸 + 抖动 + 阶段切换 + 死亡动画�?  Widget _buildMonster() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatAnimation,
        _breatheAnimation,
        _hitController,
        _deathController,
        _phaseController,
      ]),
      builder: (context, child) {
        // 死亡动画
        final deathScale = _deathScale.value;
        final deathOpacity = _deathOpacity.value;
        final deathRotation = _deathRotation.value;

        // 受伤抖动 + 缩放
        final hitDx = _hitShakeAnimation.value;
        final hitScale = _hitScaleAnimation.value;

        // 浮动 + 呼吸
        final dy = _floatAnimation.value;
        final breatheScale = _breatheAnimation.value;

        // 狂暴放大
        final enrageScale = widget.isEnraged ? 1.1 : 1.0;

        // 阶段切换 fade
        final phaseOpacity = widget.isPhaseChanging ? _phaseFade.value : 1.0;

        final totalScale = breatheScale *
            hitScale *
            enrageScale *
            (widget.isDead ? deathScale : 1.0);

        // 受伤红色滤镜（仅在受伤瞬间）+ 死亡灰度
        ColorFilter colorFilter = const ColorFilter.mode(
          Colors.transparent,
          BlendMode.dst,
        );
        if (widget.isDead) {
          colorFilter = const ColorFilter.mode(
            Color(0xFF666666),
            BlendMode.saturation,
          );
        } else if (widget.isHit && _hitController.value < 0.6) {
          final intensity = (1 - _hitController.value / 0.6).clamp(0.0, 1.0);
          colorFilter = ColorFilter.mode(
            Colors.red.withValues(alpha: 0.5 * intensity),
            BlendMode.srcATop,
          );
        }

        // 受伤时叠加红色覆盖层（更直观的受伤反馈）
        final hitRedOverlay = (widget.isHit && _hitController.value < 0.6)
            ? Colors.red.withValues(alpha: 
                (1 - _hitController.value / 0.6).clamp(0.0, 1.0) * 0.4)
            : Colors.transparent;

        Widget emojiWidget = ColorFiltered(
          colorFilter: colorFilter,
          child: Text(
            widget.emoji,
            style: TextStyle(
              fontSize: widget.emojiSize,
              decoration: TextDecoration.none,
              // 受伤时叠加红色滤�?              color: hitRedOverlay == Colors.transparent
                  ? null
                  : Color.lerp(Colors.white, Colors.red, 0.3),
            ),
          ),
        );

        return Opacity(
          opacity: deathOpacity * phaseOpacity,
          child: Transform.translate(
            offset: Offset(hitDx, dy),
            child: Transform.rotate(
              angle: deathRotation,
              child: Transform.scale(
                scale: totalScale,
                child: emojiWidget,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 受伤瞬间爆炸 emoji（💥）
  Widget _buildHitBurst() {
    return AnimatedBuilder(
      animation: _hitController,
      builder: (context, child) {
        // �?0..0.3 期间出现�?.3..1 期间淡出
        final t = _hitController.value;
        final opacity = t < 0.3 ? (t / 0.3) : ((1 - t) / 0.7).clamp(0.0, 1.0);
        final scale = 0.8 + t * 0.6;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: const Text(
              '💥',
              style: TextStyle(
                fontSize: 56,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 狂暴红色光晕（脉动）
  Widget _buildEnrageGlow() {
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, _) {
        final pulse = 0.5 + _breatheAnimation.value * 0.3;
        return Container(
          width: widget.emojiSize * 1.4,
          height: widget.emojiSize * 1.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.15 * pulse),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4 * pulse),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 死亡时灰光扩�?  Widget _buildDeathGlow() {
    return AnimatedBuilder(
      animation: _deathController,
      builder: (context, _) {
        final t = _deathController.value;
        return Opacity(
          opacity: (1 - t),
          child: Transform.scale(
            scale: 1.0 + t * 1.5,
            child: Container(
              width: widget.emojiSize * 1.2,
              height: widget.emojiSize * 1.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withValues(alpha: 0.2),
              ),
            ),
          ),
        );
      },
    );
  }

  /// HP < 30% 显示半透明血�?emoji
  Widget _buildBloodOverlay() {
    return const Opacity(
      opacity: 0.5,
      child: Text(
        '🩸',
        style: TextStyle(
          fontSize: 60,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  /// HP < 50% 显示情绪 emoji 角标（脉动）
  Widget _buildEmotionBadge() {
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, _) {
        return Positioned(
          top: 0,
          right: 0,
          child: Opacity(
            opacity: 0.5 + _breatheAnimation.value * 0.3,
            child: Text(
              _getEmotionEmoji(),
              style: const TextStyle(
                fontSize: 24,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );
  }
}
