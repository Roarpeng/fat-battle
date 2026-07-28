import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 锻造工坊氛围背景：径向炉火光 + 轻微暗角
class ForgeBackground extends StatelessWidget {
  final Widget child;

  const ForgeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.15,
          colors: [
            Color(0xFF2A1E16),
            AppColors.bg,
          ],
          stops: [0.0, 0.72],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.bg.withValues(alpha: 0.55),
                    AppColors.bg,
                  ],
                  stops: const [0.45, 0.82, 1],
                ),
              ),
            ),
          ),
          // 细微横纹纹理感
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ForgeGrainPainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ForgeGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.copper.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
