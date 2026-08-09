import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 锻造工坊 2.0 间距阶梯
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets page = EdgeInsets.fromLTRB(xl, sm, xl, md);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets chip = EdgeInsets.symmetric(horizontal: md, vertical: sm);
}

/// 锻造工坊 2.0 圆角阶梯
class AppRadii {
  AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// 分区标题样式快捷方式
class ForgeSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ForgeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.text,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 统一表面卡片容器
class ForgeSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const ForgeSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? AppSpace.card,
      decoration: BoxDecoration(
        color: color ?? AppColors.elevated,
        borderRadius: borderRadius ?? AppRadii.lgAll,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
