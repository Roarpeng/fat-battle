import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 姿态教练引导：暗角站位区 + 白色画框 + 动作剪影 + 入框反馈。
/// 横/竖屏跟随手机姿态，画框随方向自适应。
class PoseCoachGuideOverlay extends StatelessWidget {
  final String exerciseType;
  final Map<String, Map<String, double>>? landmarks;
  final String tip;

  const PoseCoachGuideOverlay({
    super.key,
    required this.exerciseType,
    this.landmarks,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final alignment = PoseCoachGuideMath.alignmentScore(
      exerciseType: exerciseType,
      landmarks: landmarks,
      isPortrait: isPortrait,
    );

    final preferLandscape = PoseCoachGuideMath.prefersLandscape(exerciseType);
    final orientationHint = isPortrait
        ? (preferLandscape ? '建议横持 · 侧身动作更清晰' : '竖屏教学中')
        : (preferLandscape ? '横屏教学中' : '也可竖持 · 站姿动作更清晰');

    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _PoseCoachGuidePainter(
            exerciseType: exerciseType,
            alignment: alignment,
            isPortrait: isPortrait,
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Column(
            children: [
              _TipBanner(tip: tip, alignment: alignment),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPortrait
                            ? Icons.stay_current_portrait
                            : Icons.stay_current_landscape,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        orientationHint,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipBanner extends StatelessWidget {
  final String tip;
  final double alignment;

  const _TipBanner({required this.tip, required this.alignment});

  @override
  Widget build(BuildContext context) {
    final ok = alignment >= 0.7;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? AppColors.copper : Colors.white.withValues(alpha: 0.55),
          width: ok ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.crop_free,
            color: ok ? AppColors.copper : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok ? '入框良好 · 开始动作' : tip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Text(
            '${(alignment * 100).round()}%',
            style: TextStyle(
              color: ok ? AppColors.copper : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// 站位框与入框评分（归一化 0..1 坐标系）。
class PoseCoachGuideMath {
  PoseCoachGuideMath._();

  /// 侧身类动作更适合横屏；站姿类更适合竖屏（仅建议，不强制）。
  static bool prefersLandscape(String exerciseType) {
    switch (exerciseType) {
      case 'pushup':
      case 'plank':
      case 'mountainclimber':
        return true;
      default:
        return false;
    }
  }

  /// 站位框（相对全画面），随横/竖屏与动作类型调整。
  static Rect stageRect(String exerciseType, {required bool isPortrait}) {
    if (isPortrait) {
      switch (exerciseType) {
        case 'pushup':
        case 'plank':
        case 'mountainclimber':
          // 竖屏侧身：框偏宽、居中偏下
          return const Rect.fromLTWH(0.06, 0.26, 0.88, 0.48);
        case 'burpee':
          return const Rect.fromLTWH(0.12, 0.10, 0.76, 0.80);
        default:
          // 站姿：竖屏更自然
          return const Rect.fromLTWH(0.16, 0.10, 0.68, 0.78);
      }
    }

    switch (exerciseType) {
      case 'pushup':
      case 'plank':
      case 'mountainclimber':
        return const Rect.fromLTWH(0.12, 0.22, 0.76, 0.56);
      case 'burpee':
        return const Rect.fromLTWH(0.18, 0.08, 0.64, 0.84);
      default:
        return const Rect.fromLTWH(0.28, 0.08, 0.44, 0.84);
    }
  }

  static double alignmentScore({
    required String exerciseType,
    required Map<String, Map<String, double>>? landmarks,
    required bool isPortrait,
  }) {
    if (landmarks == null || landmarks.isEmpty) return 0;
    final frame = stageRect(exerciseType, isPortrait: isPortrait);
    const keys = [
      'nose',
      'leftShoulder',
      'rightShoulder',
      'leftHip',
      'rightHip',
      'leftAnkle',
      'rightAnkle',
      'leftWrist',
      'rightWrist',
    ];
    var hit = 0;
    var total = 0;
    for (final key in keys) {
      final lm = landmarks[key];
      if (lm == null) continue;
      total++;
      final x = lm['x'] ?? 0.5;
      final y = lm['y'] ?? 0.5;
      if (frame.contains(Offset(x, y))) hit++;
    }
    if (total == 0) return 0;
    return hit / total;
  }
}

class _PoseCoachGuidePainter extends CustomPainter {
  final String exerciseType;
  final double alignment;
  final bool isPortrait;

  _PoseCoachGuidePainter({
    required this.exerciseType,
    required this.alignment,
    required this.isPortrait,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frame =
        PoseCoachGuideMath.stageRect(exerciseType, isPortrait: isPortrait);
    final rect = Rect.fromLTWH(
      frame.left * size.width,
      frame.top * size.height,
      frame.width * size.width,
      frame.height * size.height,
    );

    // 暗角：框外半透明遮罩
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    final borderColor = alignment >= 0.7
        ? AppColors.copper
        : Colors.white.withValues(alpha: 0.92);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = alignment >= 0.7 ? 3.2 : 2.4,
    );

    // 角落刻度
    _drawCorners(canvas, rect, borderColor);

    // 动作剪影（白色半透明火柴人）
    _drawSilhouette(canvas, rect, exerciseType);
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    const len = 22.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx * len, 0), p);
      canvas.drawLine(o, o.translate(0, dy * len), p);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  void _drawSilhouette(Canvas canvas, Rect rect, String type) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = math.max(2.5, rect.width * 0.018)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    Offset p(double nx, double ny) => Offset(
          rect.left + nx * rect.width,
          rect.top + ny * rect.height,
        );

    switch (type) {
      case 'pushup':
      case 'plank':
      case 'mountainclimber':
        // 侧身水平支撑
        canvas.drawCircle(p(0.18, 0.42), rect.height * 0.06, fill);
        canvas.drawCircle(p(0.18, 0.42), rect.height * 0.06, paint);
        canvas.drawLine(p(0.24, 0.45), p(0.72, 0.48), paint);
        canvas.drawLine(p(0.32, 0.48), p(0.30, 0.78), paint);
        canvas.drawLine(p(0.30, 0.78), p(0.22, 0.82), paint);
        canvas.drawLine(p(0.68, 0.50), p(0.78, 0.78), paint);
        canvas.drawLine(p(0.78, 0.78), p(0.88, 0.80), paint);
        break;
      case 'jumping_jack':
        canvas.drawCircle(p(0.5, 0.14), rect.width * 0.08, fill);
        canvas.drawCircle(p(0.5, 0.14), rect.width * 0.08, paint);
        canvas.drawLine(p(0.5, 0.22), p(0.5, 0.48), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.18, 0.12), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.82, 0.12), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.22, 0.88), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.78, 0.88), paint);
        break;
      case 'lunge':
        canvas.drawCircle(p(0.48, 0.12), rect.width * 0.08, fill);
        canvas.drawCircle(p(0.48, 0.12), rect.width * 0.08, paint);
        canvas.drawLine(p(0.48, 0.20), p(0.48, 0.45), paint);
        canvas.drawLine(p(0.48, 0.28), p(0.30, 0.42), paint);
        canvas.drawLine(p(0.48, 0.28), p(0.68, 0.42), paint);
        canvas.drawLine(p(0.48, 0.45), p(0.32, 0.88), paint);
        canvas.drawLine(p(0.48, 0.45), p(0.72, 0.72), paint);
        canvas.drawLine(p(0.72, 0.72), p(0.78, 0.88), paint);
        break;
      case 'highknee':
        canvas.drawCircle(p(0.5, 0.12), rect.width * 0.08, fill);
        canvas.drawCircle(p(0.5, 0.12), rect.width * 0.08, paint);
        canvas.drawLine(p(0.5, 0.20), p(0.5, 0.48), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.28, 0.18), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.72, 0.38), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.38, 0.88), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.62, 0.58), paint);
        canvas.drawLine(p(0.62, 0.58), p(0.58, 0.42), paint);
        break;
      case 'burpee':
        // 站姿剪影（起始态）
        canvas.drawCircle(p(0.5, 0.12), rect.width * 0.07, fill);
        canvas.drawCircle(p(0.5, 0.12), rect.width * 0.07, paint);
        canvas.drawLine(p(0.5, 0.19), p(0.5, 0.48), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.32, 0.40), paint);
        canvas.drawLine(p(0.5, 0.28), p(0.68, 0.40), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.38, 0.88), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.62, 0.88), paint);
        break;
      case 'squat':
      default:
        // 半蹲正面
        canvas.drawCircle(p(0.5, 0.14), rect.width * 0.08, fill);
        canvas.drawCircle(p(0.5, 0.14), rect.width * 0.08, paint);
        canvas.drawLine(p(0.5, 0.22), p(0.5, 0.48), paint);
        canvas.drawLine(p(0.5, 0.30), p(0.28, 0.42), paint);
        canvas.drawLine(p(0.5, 0.30), p(0.72, 0.42), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.34, 0.72), paint);
        canvas.drawLine(p(0.34, 0.72), p(0.32, 0.90), paint);
        canvas.drawLine(p(0.5, 0.48), p(0.66, 0.72), paint);
        canvas.drawLine(p(0.66, 0.72), p(0.68, 0.90), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PoseCoachGuidePainter oldDelegate) {
    return oldDelegate.exerciseType != exerciseType ||
        oldDelegate.alignment != alignment ||
        oldDelegate.isPortrait != isPortrait;
  }
}
