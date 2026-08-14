import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/forge_palette.dart';
import '../theme/motion.dart';

/// 拥有扣血残影条（Ghost Damage Bar）与护盾微光的血条组件
class HpBar extends StatefulWidget {
  final int current;
  final int max;
  final Color color;
  final double height;
  final bool showText;
  final int shield;
  final Color shieldColor;
  
  const HpBar({
    super.key,
    required this.current,
    required this.max,
    required this.color,
    this.height = 20,
    this.showText = true,
    this.shield = 0,
    this.shieldColor = AppColors.shield,
  });

  @override
  State<HpBar> createState() => _HpBarState();
}

class _HpBarState extends State<HpBar> with SingleTickerProviderStateMixin {
  late double _ghostPercent;
  late double _targetPercent;

  @override
  void initState() {
    super.initState();
    _targetPercent = (widget.current / widget.max).clamp(0.0, 1.0);
    _ghostPercent = _targetPercent;
  }

  @override
  void didUpdateWidget(covariant HpBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPercent = (widget.current / widget.max).clamp(0.0, 1.0);
    final oldPercent = (oldWidget.current / oldWidget.max).clamp(0.0, 1.0);

    if (newPercent < oldPercent) {
      // 扣血：主血条即刻缩短，残影条滞后缩回
      setState(() {
        _ghostPercent = oldPercent;
        _targetPercent = newPercent;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _ghostPercent = newPercent;
          });
        }
      });
    } else {
      // 加血/不变：同步更新
      setState(() {
        _targetPercent = newPercent;
        _ghostPercent = newPercent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ForgeColors.of(context);
    final shieldPercent = (widget.shield / widget.max).clamp(0.0, 1.0);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Stack(
        children: [
          // 1. 滞后扣血残影条 (Ghost Damage Bar)
          AnimatedContainer(
            duration: AppMotion.duration(context, const Duration(milliseconds: 640)),
            curve: AppMotion.metalCool,
            width: double.infinity,
            height: widget.height,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _ghostPercent,
              child: Container(
                decoration: BoxDecoration(
                  color: c.ghostBar,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // 2. 主 HP 血条
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.hpFill),
            curve: AppMotion.metalCool,
            width: double.infinity,
            height: widget.height,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _targetPercent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.color.withValues(alpha: 0.8), widget.color],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. 护盾叠加层
          if (widget.shield > 0)
            AnimatedContainer(
              duration: AppMotion.duration(context, const Duration(milliseconds: 360)),
              curve: AppMotion.metalCool,
              width: double.infinity,
              height: widget.height,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_targetPercent + shieldPercent).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, widget.shieldColor.withValues(alpha: 0.7)],
                      stops: const [0.6, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.shieldColor.withValues(alpha: 0.9), width: 1.5),
                  ),
                ),
              ),
            ),

          // 4. 数值显示
          if (widget.showText)
            Center(
              child: Text(
                widget.shield > 0
                    ? '${widget.current}+${widget.shield}/${widget.max}'
                    : '${widget.current}/${widget.max}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.8), offset: const Offset(0, 1)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 进度条组件
class ProgressBar extends StatelessWidget {
  final double percent;
  final String text;
  final Color color;
  
  const ProgressBar({
    super.key,
    required this.percent,
    this.text = '',
    this.color = AppColors.ember,
  });
  
  @override
  Widget build(BuildContext context) {
    final c = ForgeColors.of(context);
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.hpFill),
            curve: AppMotion.metalCool,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.copper, c.ember],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 伤害飘字组件
class DamageFloat extends StatefulWidget {
  final int value;
  final bool isHeal;
  final VoidCallback onComplete;
  
  const DamageFloat({
    super.key,
    required this.value,
    required this.isHeal,
    required this.onComplete,
  });
  
  @override
  State<DamageFloat> createState() => _DamageFloatState();
}

class _DamageFloatState extends State<DamageFloat>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: -60).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward().then((_) => widget.onComplete());
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value / -60;
        final opacity = 1.0 - progress;
        final dy = _animation.value;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: Text(
        '${widget.isHeal ? '+' : '-'}${widget.value}',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: widget.isHeal ? AppColors.green : AppColors.red,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
        ),
      ),
    );
  }
}