import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

/// 魔物种类
enum MonsterKind { slime, goblin, ghost, ogre, demon, dragon }

/// 由怪物的 emoji 映射到矢量种类（Monsters.all 中 emoji 固定）
MonsterKind monsterKindOf(String emoji) {
  switch (emoji) {
    case '👺':
      return MonsterKind.goblin;
    case '👻':
      return MonsterKind.ghost;
    case '👹':
      return MonsterKind.ogre;
    case '😈':
      return MonsterKind.demon;
    case '🐉':
      return MonsterKind.dragon;
    case '👾':
    default:
      return MonsterKind.slime;
  }
}

/// 锻造工坊 · 矢量魔物立绘
///
/// 用 CustomPainter 绘制 6 种卡路里魔物，替代 emoji 文字渲染：
/// 圆润身体 + 渐变体积感 + 炉火高光 + 深色描边（锻造质感）。
/// 坐标系为 100x100 逻辑单位，由 [size] 缩放。
class ForgeMonsterArt extends StatelessWidget {
  final MonsterKind kind;
  final double size;
  /// 狂暴：红眼 + 火焰眼眶
  final bool isEnraged;

  const ForgeMonsterArt({
    super.key,
    required this.kind,
    this.size = 96,
    this.isEnraged = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MonsterArtPainter(kind: kind, isEnraged: isEnraged),
    );
  }
}

class _MonsterArtPainter extends CustomPainter {
  final MonsterKind kind;
  final bool isEnraged;

  const _MonsterArtPainter({required this.kind, required this.isEnraged});

  // ---------- 工具 ----------
  static Color _muted(Color c) => c.withValues(alpha: 0.55);

  Paint _fill(List<Color> colors, {double? r, Alignment begin = Alignment.topLeft, Alignment end = Alignment.bottomRight, List<double>? stops}) {
    return Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: const Offset(50, 50), radius: r ?? 60));
  }

  Paint _outline(Color color, {double width = 2.5}) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;
  }

  void _eye(Canvas canvas, Offset c, double radius, {bool angry = false, Color pupil = const Color(0xFF1A140F)}) {
    // 眼白
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFFFBF4EA));
    // 瞳孔
    final px = isEnraged ? 0.0 : (angry ? -radius * 0.3 : 0.0);
    canvas.drawCircle(c + Offset(px, radius * 0.18), radius * 0.52,
        Paint()..color = isEnraged ? AppColors.ember : pupil);
    // 高光
    canvas.drawCircle(c + Offset(-radius * 0.32, -radius * 0.32), radius * 0.2,
        Paint()..color = Colors.white);
  }

  void _horn(Canvas canvas, Offset base, double height, double lean, {Color? color}) {
    final path = Path()
      ..moveTo(base.dx - 6, base.dy)
      ..quadraticBezierTo(base.dx - 6 + lean, base.dy - height * 0.55, base.dx + lean * 0.6, base.dy - height)
      ..quadraticBezierTo(base.dx + lean * 1.2, base.dy - height * 0.6, base.dx + 5, base.dy)
      ..close();
    canvas.drawPath(path, _fill([
      color ?? const Color(0xFF8A6A4B),
      (color ?? const Color(0xFF8A6A4B)).withValues(alpha: 0.85),
    ]));
  }

  void _fang(Canvas canvas, Offset c, bool up) {
    final h = 7.0, w = 5.0;
    final path = Path()
      ..moveTo(c.dx - w, c.dy)
      ..lineTo(c.dx, up ? c.dy - h : c.dy + h)
      ..lineTo(c.dx + w, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF6E8));
  }

  // ---------- 各魔物 ----------
  void _paintSlime(Canvas canvas) {
    // 果冻团身体（下宽上窄）
    final body = Path()
      ..moveTo(32, 40)
      ..quadraticBezierTo(32, 22, 50, 22)
      ..quadraticBezierTo(68, 22, 68, 40)
      ..quadraticBezierTo(72, 62, 50, 64)
      ..quadraticBezierTo(28, 62, 32, 40)
      ..close();
    canvas.drawPath(body, _fill([
      const Color(0xFF8FBF8A),
      const Color(0xFF5E8F5C),
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    canvas.drawPath(body, _outline(const Color(0xFF3E6B3C)));

    // 果冻顶部高光
    canvas.drawArc(
      const Rect.fromLTWH(38, 26, 24, 12),
      math.pi, math.pi,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    // 触角
    canvas.drawLine(const Offset(40, 24), const Offset(36, 14), Paint()
      ..color = const Color(0xFF5E8F5C)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(60, 24), const Offset(64, 14), Paint()
      ..color = const Color(0xFF5E8F5C)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(36, 13), 2.6, Paint()..color = const Color(0xFF8FBF8A));
    canvas.drawCircle(const Offset(64, 13), 2.6, Paint()..color = const Color(0xFF8FBF8A));

    // 眼睛（大而圆）
    _eye(canvas, const Offset(40, 44), 8);
    _eye(canvas, const Offset(60, 44), 8);
    // 嘴（O 型）
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 58), width: 12, height: 9),
        Paint()..color = const Color(0xFF3A5C38));
    // 口水
    canvas.drawCircle(const Offset(58, 63), 2.2, Paint()..color = _muted(const Color(0xFFB8D9B4)));
  }

  void _paintGoblin(Canvas canvas) {
    // 矮胖肌肉身
    final body = Path()
      ..moveTo(34, 34)
      ..quadraticBezierTo(32, 24, 50, 24)
      ..quadraticBezierTo(68, 24, 66, 34)
      ..quadraticBezierTo(72, 56, 60, 62)
      ..quadraticBezierTo(50, 66, 40, 62)
      ..quadraticBezierTo(28, 56, 34, 34)
      ..close();
    canvas.drawPath(body, _fill([
      const Color(0xFFB06A4B),
      const Color(0xFF7C4632),
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    canvas.drawPath(body, _outline(const Color(0xFF5A3325)));

    // 尖耳
    final earL = Path()
      ..moveTo(32, 32)
      ..lineTo(20, 20)
      ..lineTo(28, 42)
      ..close();
    final earR = Path()
      ..moveTo(68, 32)
      ..lineTo(80, 20)
      ..lineTo(72, 42)
      ..close();
    canvas.drawPath(earL, _fill([const Color(0xFFB06A4B), const Color(0xFF7C4632)]));
    canvas.drawPath(earR, _fill([const Color(0xFFB06A4B), const Color(0xFF7C4632)]));
    canvas.drawPath(earL, _outline(const Color(0xFF5A3325), width: 2));
    canvas.drawPath(earR, _outline(const Color(0xFF5A3325), width: 2));

    // 粗眉（怒）
    canvas.drawLine(const Offset(33, 36), const Offset(43, 38), Paint()
      ..color = const Color(0xFF4A271B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(67, 36), const Offset(57, 38), Paint()
      ..color = const Color(0xFF4A271B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    // 眼
    _eye(canvas, const Offset(40, 44), 5.4, angry: true);
    _eye(canvas, const Offset(60, 44), 5.4, angry: true);
    // 大鼻
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 51), width: 10, height: 7),
        Paint()..color = const Color(0xFF8A4E36));
    // 宽嘴 + 獠牙
    canvas.drawArc(const Rect.fromLTWH(38, 52, 24, 12), 0, math.pi, false,
        Paint()
          ..color = const Color(0xFF4A271B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _fang(canvas, const Offset(42, 55), true);
    _fang(canvas, const Offset(58, 55), true);
  }

  void _paintGhost(Canvas canvas) {
    // 幽灵身（顶圆 + 底部波浪）
    final body = Path();
    body.moveTo(34, 44);
    body.quadraticBezierTo(32, 22, 50, 22);
    body.quadraticBezierTo(68, 22, 66, 44);
    body.lineTo(66, 56);
    // 底部三个波浪
    body.quadraticBezierTo(66, 66, 58, 56);
    body.quadraticBezierTo(58, 66, 50, 56);
    body.quadraticBezierTo(50, 66, 42, 56);
    body.quadraticBezierTo(42, 66, 34, 56);
    body.close();
    final ghostPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFFFFDF6).withValues(alpha: 0.95), const Color(0xFFD9D3E8).withValues(alpha: 0.82)],
      ).createShader(const Rect.fromLTWH(30, 20, 40, 50));
    canvas.drawPath(body, ghostPaint);
    canvas.drawPath(body, _outline(const Color(0xFF8B86A3), width: 2));

    // 眼（大而深）
    canvas.drawCircle(const Offset(41, 42), 7, Paint()..color = const Color(0xFF23202E));
    canvas.drawCircle(const Offset(59, 42), 7, Paint()..color = const Color(0xFF23202E));
    canvas.drawCircle(const Offset(38.6, 39.6), 2.4, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(56.6, 39.6), 2.4, Paint()..color = Colors.white);
    // 嘴（O）+ 舌头
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 50), width: 9, height: 7),
        Paint()..color = const Color(0xFF23202E));
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 53), width: 5, height: 6),
        Paint()..color = const Color(0xFFD96C6C));
    // 腮红
    canvas.drawCircle(const Offset(34, 50), 4, Paint()..color = const Color(0xFFE8A0B4).withValues(alpha: 0.5));
    canvas.drawCircle(const Offset(66, 50), 4, Paint()..color = const Color(0xFFE8A0B4).withValues(alpha: 0.5));
  }

  void _paintOgre(Canvas canvas) {
    // 巨胖紫魔
    final body = Path()
      ..moveTo(30, 34)
      ..quadraticBezierTo(28, 20, 50, 20)
      ..quadraticBezierTo(72, 20, 70, 34)
      ..quadraticBezierTo(76, 56, 64, 64)
      ..quadraticBezierTo(50, 70, 36, 64)
      ..quadraticBezierTo(24, 56, 30, 34)
      ..close();
    canvas.drawPath(body, _fill([
      const Color(0xFF8A78B5),
      const Color(0xFF5C4E82),
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    canvas.drawPath(body, _outline(const Color(0xFF3E3460)));

    // 角（两个短弯角）
    _horn(canvas, const Offset(38, 24), 13, -4, color: const Color(0xFFB9A8D8));
    _horn(canvas, const Offset(62, 24), 13, 4, color: const Color(0xFFB9A8D8));

    // 额头皱纹
    canvas.drawArc(const Rect.fromLTWH(42, 26, 16, 8), 0, math.pi, false, Paint()
      ..color = _muted(const Color(0xFF3E3460))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);

    // 小眼睛（深陷）
    canvas.drawCircle(const Offset(41, 42), 3.6, Paint()..color = const Color(0xFF2A2240));
    canvas.drawCircle(const Offset(59, 42), 3.6, Paint()..color = const Color(0xFF2A2240));
    canvas.drawCircle(const Offset(41.8, 41.2), 1.3, Paint()..color = const Color(0xFFC9BFE8));
    canvas.drawCircle(const Offset(59.8, 41.2), 1.3, Paint()..color = const Color(0xFFC9BFE8));
    // 粗眉
    canvas.drawLine(const Offset(34, 36), const Offset(46, 37), Paint()
      ..color = const Color(0xFF2A2240)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(66, 36), const Offset(54, 37), Paint()
      ..color = const Color(0xFF2A2240)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round);
    // 大鼻
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 50), width: 12, height: 8),
        Paint()..color = const Color(0xFF6E5D99));
    // 三层下巴
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(50, 58 + i * 2.5), width: 26 - i * 3, height: 10),
        0, math.pi, false,
        Paint()
          ..color = _muted(const Color(0xFF3E3460))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintDemon(Canvas canvas) {
    // 赤红恶魔（倒三角火球身）
    final body = Path()
      ..moveTo(36, 26)
      ..quadraticBezierTo(50, 14, 64, 26)
      ..quadraticBezierTo(72, 40, 64, 58)
      ..quadraticBezierTo(56, 70, 50, 70)
      ..quadraticBezierTo(44, 70, 36, 58)
      ..quadraticBezierTo(28, 40, 36, 26)
      ..close();
    canvas.drawPath(body, _fill([
      const Color(0xFFE85D4C),
      const Color(0xFFA63A2E),
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    canvas.drawPath(body, _outline(const Color(0xFF6E241B)));

    // 角
    _horn(canvas, const Offset(40, 26), 16, -5, color: const Color(0xFF3A1D18));
    _horn(canvas, const Offset(60, 26), 16, 5, color: const Color(0xFF3A1D18));

    // 火焰眼（狂暴更亮）
    final eyeColor = isEnraged ? const Color(0xFFFFE082) : const Color(0xFFFFB74D);
    canvas.drawCircle(const Offset(42, 40), 6, Paint()..color = eyeColor);
    canvas.drawCircle(const Offset(58, 40), 6, Paint()..color = eyeColor);
    canvas.drawCircle(const Offset(42, 40), 2.6, Paint()..color = const Color(0xFF8A2400));
    canvas.drawCircle(const Offset(58, 40), 2.6, Paint()..color = const Color(0xFF8A2400));
    // 斜眼眉
    canvas.drawLine(const Offset(35, 32), const Offset(47, 36), Paint()
      ..color = const Color(0xFF5E1C14)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(65, 32), const Offset(53, 36), Paint()
      ..color = const Color(0xFF5E1C14)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round);

    // 咧嘴獠牙
    canvas.drawArc(const Rect.fromLTWH(38, 48, 24, 14), 0.15 * math.pi, 0.7 * math.pi, false, Paint()
      ..color = const Color(0xFF4A150F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round);
    _fang(canvas, const Offset(44, 52), true);
    _fang(canvas, const Offset(56, 52), true);

    // 火焰尾尖（右下）
    final tail = Path()
      ..moveTo(64, 60)
      ..quadraticBezierTo(78, 62, 82, 74)
      ..quadraticBezierTo(76, 82, 66, 76)
      ..quadraticBezierTo(70, 68, 64, 60)
      ..close();
    canvas.drawPath(tail, _fill([const Color(0xFFFFB74D), const Color(0xFFE85D4C)], begin: Alignment.topLeft, end: Alignment.bottomRight));
    canvas.drawPath(tail, _outline(const Color(0xFF8A4A1A), width: 2));
  }

  void _paintDragon(Canvas canvas) {
    // 肥胖龙王（金色胖龙）
    final body = Path()
      ..moveTo(30, 30)
      ..quadraticBezierTo(28, 16, 50, 16)
      ..quadraticBezierTo(72, 16, 70, 30)
      ..quadraticBezierTo(78, 56, 62, 66)
      ..quadraticBezierTo(50, 72, 38, 66)
      ..quadraticBezierTo(22, 56, 30, 30)
      ..close();
    canvas.drawPath(body, _fill([
      const Color(0xFFD9B96F),
      const Color(0xFFA8844C),
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter));
    canvas.drawPath(body, _outline(const Color(0xFF6E5328)));

    // 龙角（分叉）
    _horn(canvas, const Offset(40, 20), 15, -4, color: const Color(0xFF8A6A3A));
    _horn(canvas, const Offset(60, 20), 15, 4, color: const Color(0xFF8A6A3A));
    // 额上小冠
    canvas.drawCircle(const Offset(50, 18), 3, Paint()..color = const Color(0xFFE8CD8A));

    // 腹部鳞片（横向分层）
    final scalePaint = Paint()
      ..color = const Color(0xFFC9A45C).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(50, 58 + i * 3.4), width: 30 - i * 4, height: 9),
        0, math.pi, false, scalePaint,
      );
    }

    // 龙眼（竖瞳）
    canvas.drawCircle(const Offset(41, 38), 6.4, Paint()..color = const Color(0xFFFFF3D6));
    canvas.drawCircle(const Offset(59, 38), 6.4, Paint()..color = const Color(0xFFFFF3D6));
    canvas.drawLine(const Offset(41, 34), const Offset(41, 42), Paint()
      ..color = const Color(0xFF4A3308)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(59, 34), const Offset(59, 42), Paint()
      ..color = const Color(0xFF4A3308)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);

    // 龙吻 + 鼻孔
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 52), width: 12, height: 9),
        Paint()..color = const Color(0xFFB8944E));
    canvas.drawCircle(const Offset(47, 51), 1.6, Paint()..color = const Color(0xFF6E5328));
    canvas.drawCircle(const Offset(53, 51), 1.6, Paint()..color = const Color(0xFF6E5328));
    // 小龙翼（两侧）
    final wingL = Path()
      ..moveTo(30, 34)
      ..quadraticBezierTo(16, 28, 14, 44)
      ..quadraticBezierTo(20, 44, 24, 52)
      ..quadraticBezierTo(27, 44, 30, 40)
      ..close();
    final wingR = Path()
      ..moveTo(70, 34)
      ..quadraticBezierTo(84, 28, 86, 44)
      ..quadraticBezierTo(80, 44, 76, 52)
      ..quadraticBezierTo(73, 44, 70, 40)
      ..close();
    canvas.drawPath(wingL, _fill([const Color(0xFFE8CD8A), const Color(0xFFB8944E)]));
    canvas.drawPath(wingR, _fill([const Color(0xFFE8CD8A), const Color(0xFFB8944E)]));
    canvas.drawPath(wingL, _outline(const Color(0xFF6E5328), width: 2));
    canvas.drawPath(wingR, _outline(const Color(0xFF6E5328), width: 2));
  }

  // ---------- 入口 ----------
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.width / 100;
    canvas.scale(scale, scale);
    switch (kind) {
      case MonsterKind.slime:
        _paintSlime(canvas);
      case MonsterKind.goblin:
        _paintGoblin(canvas);
      case MonsterKind.ghost:
        _paintGhost(canvas);
      case MonsterKind.ogre:
        _paintOgre(canvas);
      case MonsterKind.demon:
        _paintDemon(canvas);
      case MonsterKind.dragon:
        _paintDragon(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MonsterArtPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.isEnraged != isEnraged;
}
