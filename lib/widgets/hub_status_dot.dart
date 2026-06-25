import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum HubStatus { disconnected, connecting, connected }

class HubStatusDot extends StatelessWidget {
  final HubStatus status;
  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  const HubStatusDot({
    super.key,
    required this.status,
    this.size = 6,
    this.onTap,
    this.tooltip,
  });

  Color get _color {
    switch (status) {
      case HubStatus.connected:
        return AppColors.green;
      case HubStatus.connecting:
        return AppColors.gold;
      case HubStatus.disconnected:
        return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color,
        boxShadow: status == HubStatus.connected
            ? [
                BoxShadow(
                  color: AppColors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    if (onTap != null || tooltip != null) {
      return GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? _defaultTooltip,
          child: dot,
        ),
      );
    }

    return dot;
  }

  String get _defaultTooltip {
    switch (status) {
      case HubStatus.connected:
        return '腰部Hub已连接';
      case HubStatus.connecting:
        return '连接中...';
      case HubStatus.disconnected:
        return '未连接';
    }
  }
}
