import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 战斗�?HP 条（带护盾条 + 受伤闪烁 + 阶段切换动画�?///
/// 设计参�?Web �?HpBar.tsx�?/// - HP 主体（红色渐变，从右向左减少�?/// - 护盾条覆盖在 HP 条上方（青色，带发光动画�?/// - 受伤时水平抖�?+ 低血量闪�?/// - 数字显示 "当前HP / 最大HP" + 护盾�?class BattleHpBar extends StatefulWidget {
  /// 当前 HP
  final int current;

  /// 最�?HP
  final int max;

  /// 当前护盾�?  final int shield;

  /// 最大护盾值（用于计算护盾宽度比例），默认�?max 相同
  final int maxShield;

  /// 条高�?  final double height;

  /// 是否显示数字
  final bool showText;

  /// HP 颜色（默认红色）
  final Color color;

  /// 护盾颜色（默认青色）
  final Color shieldColor;

  /// 是否为低血量（< 30%）触发闪�?  final bool lowHpPulse;

  const BattleHpBar({
    super.key,
    required this.current,
    required this.max,
    this.shield = 0,
    this.maxShield = 0,
    this.height = 18,
    this.showText = true,
    this.color = AppColors.red,
    this.shieldColor = const Color(0xFF4ECDC4),
    this.lowHpPulse = true,
  });

  @override
  State<BattleHpBar> createState() => _BattleHpBarState();
}

class _BattleHpBarState extends State<BattleHpBar>
    with TickerProviderStateMixin {
  // 用于水平抖动
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // 用于低血量呼吸闪�?  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // 用于护盾光波流动
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(covariant BattleHpBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检�?HP 或护盾变化，触发水平抖动
    if (oldWidget.current != widget.current ||
        oldWidget.shield != widget.shield) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  double get _hpPercent {
    if (widget.max <= 0) return 0;
    return (widget.current / widget.max).clamp(0.0, 1.0);
  }

  double get _shieldPercent {
    final base = widget.maxShield > 0 ? widget.maxShield : widget.max;
    if (base <= 0) return 0;
    return (widget.shield / base).clamp(0.0, 1.0);
  }

  bool get _isLowHp =>
      widget.lowHpPulse && _hpPercent < 0.3 && _hpPercent > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // 水平抖动偏移：在 -2..2 之间往�?        final t = _shakeAnimation.value;
        final dx = (t < 0.5)
            ? (t * 2 * 4 - 2) // 0..0.5 -> -2..2
            : ((1 - t) * 2 * 4 - 2); // 0.5..1 -> 2..-2
        return Transform.translate(
          offset: Offset(dx.toDouble(), 0),
          child: child,
        );
      },
      child: _buildBar(),
    );
  }

  Widget _buildBar() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(widget.height / 2),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // HP 主体
          _buildHpBar(),
          // 护盾条叠加在 HP 上方
          if (widget.shield > 0) _buildShieldBar(),
          // 数字
          if (widget.showText) _buildText(),
        ],
      ),
    );
  }

  /// HP 主体（红色渐�?+ 低血量闪烁）
  Widget _buildHpBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * _hpPercent;
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            // 低血量时调整亮度
            final brightness = _isLowHp ? (0.7 + _pulseAnimation.value * 0.6) : 1.0;
            return Container(
              width: width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color.lerp(widget.color, Colors.white, 0.3 * brightness)!,
                    widget.color,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 
                      _isLowHp ? 0.5 * _pulseAnimation.value : 0.35,
                    ),
                    blurRadius: _isLowHp ? 14 : 8,
                  ),
                ],
              ),
              child: Container(),
            );
          },
        );
      },
    );
  }

  /// 护盾条（青色 + 流光 + 边框�?  Widget _buildShieldBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * _shieldPercent;
        return AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            // 流光位置：在 0..1 之间
            final shimmer = (_shimmerAnimation.value + 1) / 2;
            return Container(
              width: width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    widget.shieldColor.withValues(alpha: 0.85),
                    widget.shieldColor.withValues(alpha: 0.6),
                  ],
                ),
                border: Border(
                  right: BorderSide(
                    color: widget.shieldColor,
                    width: 2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.shieldColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _ShieldShimmerPainter(
                  progress: shimmer,
                  color: widget.shieldColor,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 文字层（HP 数字 + 护盾数字�?  Widget _buildText() {
    return Center(
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          children: [
            TextSpan(text: '${widget.current} / ${widget.max}'),
            if (widget.shield > 0)
              TextSpan(
                text: '  (+${widget.shield})',
                style: TextStyle(
                  color: widget.shieldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 护盾流光绘制器：在护盾条上绘制一条移动的高光�?class _ShieldShimmerPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;

  _ShieldShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [
          (progress - 0.2).clamp(0.0, 1.0),
          progress.clamp(0.0, 1.0),
          (progress + 0.2).clamp(0.0, 1.0),
        ],
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShieldShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
