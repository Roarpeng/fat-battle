import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/forge_palette.dart';

/// 手绘感卡片：填充纸色 + 轻微不规则石墨描边（双线铅笔）。
///
/// 熔炉主题下退化为普通圆角矩形，开销可忽略。
class SketchCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final double? roughness;

  const SketchCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
    this.roughness,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ForgeColors.of(context);
    final radius = borderRadius ?? BorderRadius.circular(20);
    final fill = color ?? palette.elevated;
    final stroke = borderColor ?? palette.border;
    final wobble = roughness ?? palette.borderRoughness;
    final useSketch = palette.sketchBorders && wobble > 0;

    if (!useSketch) {
      return Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border.all(color: stroke),
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    return CustomPaint(
      painter: SketchBorderPainter(
        fill: fill,
        stroke: stroke,
        borderRadius: radius,
        roughness: wobble,
        shadows: boxShadow,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

/// 沿圆角矩形走一圈，用正弦把边微微顶歪，再叠一条淡铅笔线。
class SketchBorderPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final BorderRadius borderRadius;
  final double roughness;
  final List<BoxShadow>? shadows;

  const SketchBorderPainter({
    required this.fill,
    required this.stroke,
    required this.borderRadius,
    required this.roughness,
    this.shadows,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final inset = rect.deflate(1.15);
    if (inset.isEmpty) return;

    final path = _wobblyRRect(inset, borderRadius, roughness);

    if (shadows != null) {
      for (final shadow in shadows!) {
        final paint = Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius);
        canvas.save();
        canvas.translate(shadow.offset.dx, shadow.offset.dy);
        canvas.drawPath(path, paint);
        canvas.restore();
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(0.65, 0.45);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SketchBorderPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.roughness != roughness;
}

Path _wobblyRRect(Rect rect, BorderRadius radius, double roughness) {
  final rrect = radius.toRRect(rect);
  const samplesPerSide = 10;
  final points = <Offset>[];

  void addEdge(Offset a, Offset b) {
    for (var i = 0; i < samplesPerSide; i++) {
      final t = i / samplesPerSide;
      points.add(Offset.lerp(a, b, t)!);
    }
  }

  void addArc(Offset center, double r, double start, double sweep) {
    const steps = 6;
    for (var i = 0; i < steps; i++) {
      final t = start + sweep * (i / steps);
      points.add(Offset(center.dx + r * math.cos(t), center.dy + r * math.sin(t)));
    }
  }

  final tl = rrect.tlRadiusX.clamp(0.0, rect.shortestSide / 2);
  final tr = rrect.trRadiusX.clamp(0.0, rect.shortestSide / 2);
  final br = rrect.brRadiusX.clamp(0.0, rect.shortestSide / 2);
  final bl = rrect.blRadiusX.clamp(0.0, rect.shortestSide / 2);

  addEdge(Offset(rect.left + tl, rect.top), Offset(rect.right - tr, rect.top));
  addArc(Offset(rect.right - tr, rect.top + tr), tr, -math.pi / 2, math.pi / 2);
  addEdge(Offset(rect.right, rect.top + tr), Offset(rect.right, rect.bottom - br));
  addArc(Offset(rect.right - br, rect.bottom - br), br, 0, math.pi / 2);
  addEdge(Offset(rect.right - br, rect.bottom), Offset(rect.left + bl, rect.bottom));
  addArc(Offset(rect.left + bl, rect.bottom - bl), bl, math.pi / 2, math.pi / 2);
  addEdge(Offset(rect.left, rect.bottom - bl), Offset(rect.left, rect.top + tl));
  addArc(Offset(rect.left + tl, rect.top + tl), tl, math.pi, math.pi / 2);

  final path = Path();
  for (var i = 0; i < points.length; i++) {
    final prev = points[(i - 1 + points.length) % points.length];
    final next = points[(i + 1) % points.length];
    var tangent = next - prev;
    final len = tangent.distance;
    if (len < 0.001) {
      tangent = const Offset(1, 0);
    } else {
      tangent = tangent / len;
    }
    final normal = Offset(-tangent.dy, tangent.dx);
    final t = i / points.length;
    final mag = math.sin(t * math.pi * 6 + 0.7) * roughness * 1.35 +
        math.sin(t * math.pi * 13 + 1.9) * roughness * 0.45;
    final p = points[i] + normal * mag;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}
