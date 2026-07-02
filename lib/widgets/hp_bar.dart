import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 血条组件
class HpBar extends StatelessWidget {
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
    this.shieldColor = AppColors.purple,
  });
  
  @override
  Widget build(BuildContext context) {
    final percent = (current / max).clamp(0.0, 1.0);
    final shieldPercent = (shield / max).clamp(0.0, 1.0);
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          // 血条
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: double.infinity,
            height: height,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          
          // 护盾层
          if (shield > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: double.infinity,
              height: height,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (percent + shieldPercent).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, shieldColor.withOpacity(0.6)],
                      stops: [0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: shieldColor.withOpacity(0.8), width: 1.5),
                  ),
                ),
              ),
            ),
          
          // 文字
          if (showText)
            Center(
              child: Text(
                shield > 0 ? '$current+$shield/$max' : '$current/$max',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), offset: Offset(0, 1)),
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
    this.color = AppColors.green,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.green, AppColors.gold],
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