import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/motion.dart';

enum ForgeHaptic { none, selection, light, medium }

/// 统一按压反馈：scale + 可选 haptic，尊重 reduce-motion
class ForgePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final ForgeHaptic haptic;
  final bool enabled;
  final BorderRadius? borderRadius;

  const ForgePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = AppMotion.tapScale,
    this.duration = AppMotion.tap,
    this.haptic = ForgeHaptic.selection,
    this.enabled = true,
    this.borderRadius,
  });

  @override
  State<ForgePressable> createState() => _ForgePressableState();
}

class _ForgePressableState extends State<ForgePressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case ForgeHaptic.none:
        break;
      case ForgeHaptic.selection:
        HapticFeedback.selectionClick();
      case ForgeHaptic.light:
        HapticFeedback.lightImpact();
      case ForgeHaptic.medium:
        HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final scale = AppMotion.pressScale(context, scale: widget.scale);
    final duration = AppMotion.duration(context, widget.duration);

    Widget child = AnimatedScale(
      scale: _pressed ? scale : 1,
      duration: duration,
      curve: AppMotion.easeOut,
      child: widget.child,
    );

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              _fireHaptic();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: child,
    );
  }
}
