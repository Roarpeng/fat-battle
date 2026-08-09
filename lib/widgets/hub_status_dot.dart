import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'forge_pressable.dart';

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
        return AppColors.copper;
      case HubStatus.disconnected:
        return AppColors.text2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size + 16,
      height: size + 16,
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: status == HubStatus.connected
              ? [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.45),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ]
              : status == HubStatus.connecting
                  ? [
                      BoxShadow(
                        color: AppColors.copper.withValues(alpha: 0.4),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
        ),
      ),
    );

    final tipped = Tooltip(
      message: tooltip ?? _defaultTooltip,
      child: dot,
    );

    if (onTap != null) {
      return ForgePressable(onTap: onTap, child: tipped);
    }
    return tipped;
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
