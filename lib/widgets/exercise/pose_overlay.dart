import 'package:flutter/material.dart';
import '../../theme/pose_hud_theme.dart';

/// Renders a human pose skeleton overlay on a camera preview.
///
/// Accepts normalized landmark coordinates (0.0-1.0) with a 'z' confidence
/// field and draws coloured bones + joints using the COCO skeleton topology.
class PoseOverlay extends StatelessWidget {
  /// Normalized landmark map keyed by COCO-style landmark name strings.
  /// Each entry has 'x', 'y' (normalized 0.0 – 1.0) and 'z' (confidence /
  /// depth). When null the widget collapses to zero size.
  final Map<String, Map<String, double>>? landmarks;

  /// The logical size of the camera preview this overlay sits on top of.
  final Size size;

  /// Whether to draw the skeleton bones. Joints are always drawn.
  final bool showSkeleton;

  const PoseOverlay({
    super.key,
    this.landmarks,
    required this.size,
    this.showSkeleton = true,
  });

  @override
  Widget build(BuildContext context) {
    if (landmarks == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: PoseOverlayPainter(
          landmarks: landmarks!,
          showSkeleton: showSkeleton,
          hud: PoseHudTheme.of(context),
        ),
      ),
    );
  }
}

/// Custom painter that draws pose keypoints and skeleton connections.
class PoseOverlayPainter extends CustomPainter {
  static const double _jointRadius = 5.0;
  static const double _lineWidth = 2.0;

  /// Body joints only — skips face points (nose / ears / eyes / mouth).
  static const Set<String> _bodyJointKeys = {
    'leftShoulder',
    'rightShoulder',
    'leftElbow',
    'rightElbow',
    'leftWrist',
    'rightWrist',
    'leftHip',
    'rightHip',
    'midHip',
    'leftKnee',
    'rightKnee',
    'leftAnkle',
    'rightAnkle',
  };

  final Map<String, Map<String, double>> landmarks;
  final bool showSkeleton;
  final PoseHudTheme? hud;

  PoseOverlayPainter({
    required this.landmarks,
    required this.showSkeleton,
    this.hud,
  });

  // ---- colour helpers ----

  /// Maps the 'z' value (treated as confidence 0.0–1.0) to forge palette:
  ///   z >= 0.7  → copper   (high confidence)
  ///   z >= 0.3  → forgeGlow (medium)
  ///   z <  0.3  → ember    (low)
  Color _confidenceColor(double z) {
    final t = hud;
    if (t != null) {
      if (z >= 0.7) return t.skeletonHigh;
      if (z >= 0.3) return t.skeletonMid;
      return t.skeletonLow;
    }
    if (z >= 0.7) return const Color(0xFFC9A227);
    if (z >= 0.3) return const Color(0xFFE8A87C);
    return const Color(0xFFC0392B);
  }

  /// Returns the average colour between two landmarks so a bone is drawn
  /// in a blended tint rather than jerking between two extremes.
  Color _boneColor(
    Map<String, double> a,
    Map<String, double> b,
  ) {
    final double az = a['z'] ?? 0.0;
    final double bz = b['z'] ?? 0.0;
    return Color.lerp(
      _confidenceColor(az),
      _confidenceColor(bz),
      0.5,
    )!;
  }

  // ---- coordinate mapping ----

  /// Converts a normalized (0-1) coordinate to canvas pixel space.
  Offset _toPixel(Map<String, double> lm, Size canvasSize) {
    final double x = (lm['x'] ?? 0.5) * canvasSize.width;
    final double y = (lm['y'] ?? 0.5) * canvasSize.height;
    return Offset(x, y);
  }

  /// Safely resolves a landmark map from [landmarks] by key name.
  Map<String, double>? _lm(String key) => landmarks[key];

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // ----- joints (body only; always drawn when present) -----
    for (final String key in _bodyJointKeys) {
      final Map<String, double>? lm = _lm(key);
      if (lm == null) continue;

      final Offset pos = _toPixel(lm, canvasSize);
      final double z = lm['z'] ?? 0.0;

      canvas.drawCircle(
        pos,
        _jointRadius,
        Paint()
          ..color = _confidenceColor(z)
          ..style = PaintingStyle.fill,
      );
    }

    // ----- bones (optional) -----
    if (!showSkeleton) return;

    // Bones defined as (startKey, endKey) pairs — torso / arms / legs only.
    const List<(String, String)> bones = [
      // Torso
      ('leftShoulder', 'rightShoulder'),
      ('rightShoulder', 'rightHip'),
      ('rightHip', 'leftHip'),
      ('leftHip', 'leftShoulder'),
      // Left arm
      ('leftShoulder', 'leftElbow'),
      ('leftElbow', 'leftWrist'),
      // Right arm
      ('rightShoulder', 'rightElbow'),
      ('rightElbow', 'rightWrist'),
      // Left leg
      ('leftHip', 'leftKnee'),
      ('leftKnee', 'leftAnkle'),
      // Right leg
      ('rightHip', 'rightKnee'),
      ('rightKnee', 'rightAnkle'),
    ];

    final Paint bonePaint = Paint()
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final (String aKey, String bKey) in bones) {
      final Map<String, double>? a = _lm(aKey);
      final Map<String, double>? b = _lm(bKey);
      if (a == null || b == null) continue;

      bonePaint.color = _boneColor(a, b);
      canvas.drawLine(_toPixel(a, canvasSize), _toPixel(b, canvasSize), bonePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return landmarks != oldDelegate.landmarks ||
        showSkeleton != oldDelegate.showSkeleton ||
        hud?.lightPaper != oldDelegate.hud?.lightPaper;
  }
}
