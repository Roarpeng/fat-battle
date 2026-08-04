import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/forge_theme.dart';

import '../../constants/app_constants.dart';
import '../../models/game_models.dart';
import '../battle/forge_monster_art.dart';

/// 舞台中央怪物立绘：底座光环 + 护盾光圈 + 打击缩放
class MonsterStageAvatar extends StatefulWidget {
  final Monster monster;
  final bool hitFlash;
  final VoidCallback? onTap;

  const MonsterStageAvatar({
    super.key,
    required this.monster,
    this.hitFlash = false,
    this.onTap,
  });

  @override
  State<MonsterStageAvatar> createState() => _MonsterStageAvatarState();
}

class _MonsterStageAvatarState extends State<MonsterStageAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enraged = widget.monster.hpPercent < 0.3;
    final ringColor = widget.monster.hasShield
        ? AppColors.shield
        : (enraged ? AppColors.ember : AppColors.copper);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          final t = _breath.value;
          final scale = widget.hitFlash
              ? 0.88
              : (0.98 + t * 0.04);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: SizedBox(
          width: 220,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 底座
              Positioned(
                bottom: 18,
                child: Container(
                  width: 150,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: RadialGradient(
                      colors: [
                        ringColor.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // 护盾环
              if (widget.monster.hasShield)
                CustomPaint(
                  size: const Size(190, 190),
                  painter: _ShieldRingPainter(
                    color: AppColors.shield,
                    progress: math.min(
                      1.0,
                      widget.monster.shield /
                          math.max(1, widget.monster.maxHp),
                    ),
                  ),
                ),
              // 立绘盘
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.bg3,
                      AppColors.card,
                      enraged
                          ? AppColors.ember.withValues(alpha: 0.35)
                          : AppColors.bg2,
                    ],
                  ),
                  border: Border.all(
                    color: ringColor.withValues(alpha: 0.65),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ForgeMonsterArt(
                  kind: monsterKindOf(widget.monster.emoji),
                  size: 116,
                  isEnraged: enraged,
                ),
              ),
              // 等级徽章
              Positioned(
                bottom: 42,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg2.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Lv.${widget.monster.level}'
                    '${widget.monster.isBoss ? ' · BOSS' : ''}',
                    style: AppFonts.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.copper,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ShieldRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bg = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final fg = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.08, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
