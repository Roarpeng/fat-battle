import 'package:flutter/material.dart';
import '../../theme/forge_theme.dart';
import '../../theme/motion.dart';
import '../../constants/app_constants.dart';
import 'clay_fx.dart';
import 'forge_monster_art.dart';

/// 粘土魔物立绘：慢呼吸 + 炉芯脉动 + 凿击刨花，而不是 RPG 斩击。
class MonsterDisplay extends StatefulWidget {
  /// 怪物 emoji（仅用于映射 [ForgeMonsterArt] 种类）
  final String emoji;

  /// 当前 HP 百分比（0..1）
  final double hpPercentage;

  /// 是否正在受伤（凿击挤压 + 刨花）
  final bool isHit;

  /// 是否狂暴（炉芯更亮、呼吸更快）
  final bool isEnraged;

  /// 是否死亡（碎裂溶解）
  final bool isDead;

  /// 是否处于阶段切换（触发 fade 过渡）
  final bool isPhaseChanging;

  /// 立绘基础尺寸
  final double emojiSize;

  /// 暴食/卡路里超标膨胀系数 (0.0 ~ 1.0)
  final double overeatFactor;

  /// 点击回调
  final VoidCallback? onTap;

  const MonsterDisplay({
    super.key,
    required this.emoji,
    required this.hpPercentage,
    this.isHit = false,
    this.isEnraged = false,
    this.isDead = false,
    this.isPhaseChanging = false,
    this.emojiSize = 96,
    this.overeatFactor = 0.0,
    this.onTap,
  });

  @override
  State<MonsterDisplay> createState() => _MonsterDisplayState();
}

class _MonsterDisplayState extends State<MonsterDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  late final AnimationController _jiggleController;
  late final Animation<double> _jiggleAnimation;

  late final AnimationController _emberController;
  late final Animation<double> _emberAnimation;

  late final AnimationController _hitController;
  late final Animation<double> _hitSquash;
  late final Animation<double> _hitSlide;

  late final AnimationController _deathController;
  late final Animation<double> _deathCrumble;
  late final Animation<double> _deathOpacity;

  late final AnimationController _phaseController;
  late final Animation<double> _phaseFade;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3800),
      vsync: this,
    );
    _floatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: AppMotion.clayBreathe),
    );

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 4400),
      vsync: this,
    );
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.028).animate(
      CurvedAnimation(parent: _breatheController, curve: AppMotion.clayBreathe),
    );

    _jiggleController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    _jiggleAnimation = Tween<double>(begin: -0.012, end: 0.012).animate(
      CurvedAnimation(parent: _jiggleController, curve: AppMotion.clayBreathe),
    );

    _emberController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
    _emberAnimation = Tween<double>(begin: 0.42, end: 1.0).animate(
      CurvedAnimation(parent: _emberController, curve: AppMotion.easeInOut),
    );

    _hitController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _hitSquash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 72),
    ]).animate(CurvedAnimation(parent: _hitController, curve: AppMotion.chipOut));
    _hitSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 70),
    ]).animate(CurvedAnimation(parent: _hitController, curve: AppMotion.easeOut));

    _deathController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _deathCrumble = CurvedAnimation(
      parent: _deathController,
      curve: const Cubic(0.2, 0.0, 0.4, 1),
    );
    _deathOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 65),
    ]).animate(_deathController);

    _phaseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _phaseFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _phaseController, curve: AppMotion.easeInOut),
    );

    if (widget.isDead) {
      _deathController.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIdleMotion(AppMotion.reduceMotion(context));
  }

  @override
  void didUpdateWidget(covariant MonsterDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnraged != widget.isEnraged) {
      _syncIdleMotion(AppMotion.reduceMotion(context));
    }
    if (!oldWidget.isHit && widget.isHit && !AppMotion.reduceMotion(context)) {
      _hitController.forward(from: 0);
    }
    if (!oldWidget.isDead && widget.isDead) {
      if (AppMotion.reduceMotion(context)) {
        _deathController.value = 1;
      } else {
        _deathController.forward(from: 0);
      }
    }
    if (!oldWidget.isPhaseChanging && widget.isPhaseChanging) {
      if (AppMotion.reduceMotion(context)) {
        _phaseController.value = 1;
      } else {
        _phaseController.forward(from: 0);
      }
    }
  }

  void _syncIdleMotion(bool reduce) {
    if (reduce) {
      _floatController.stop();
      _breatheController.stop();
      _jiggleController.stop();
      _emberController.stop();
      _floatController.value = 0.5;
      _breatheController.value = 0.5;
      _jiggleController.value = 0.5;
      _emberController.value = widget.isEnraged ? 0.85 : 0.55;
      return;
    }
    _breatheController.duration = Duration(
      milliseconds: widget.isEnraged ? 2400 : 4400,
    );
    _emberController.duration = Duration(
      milliseconds: widget.isEnraged ? 1100 : 2200,
    );
    if (!_floatController.isAnimating) {
      _floatController.repeat(reverse: true);
    }
    if (!_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    } else {
      _breatheController.repeat(reverse: true);
    }
    if (!_jiggleController.isAnimating) {
      _jiggleController.repeat(reverse: true);
    }
    if (!_emberController.isAnimating) {
      _emberController.repeat(reverse: true);
    } else {
      _emberController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _breatheController.dispose();
    _jiggleController.dispose();
    _emberController.dispose();
    _hitController.dispose();
    _deathController.dispose();
    _phaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.emojiSize * 1.6,
        height: widget.emojiSize * 1.6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isEnraged && !widget.isDead) _buildEnrageGlow(context),
            if (widget.isDead) _buildDeathCrumble(context),
            _buildMonster(context),
            if (widget.isHit && !AppMotion.reduceMotion(context))
              _buildHitShavings(context),
            if (widget.hpPercentage < 0.3 && !widget.isDead)
              _buildLowHpCracks(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMonster(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ember = scheme.primary;
    final copper = scheme.secondary;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatAnimation,
        _breatheAnimation,
        _jiggleAnimation,
        _emberAnimation,
        _hitController,
        _deathController,
        _phaseController,
      ]),
      builder: (context, child) {
        final deathT = widget.isDead ? _deathCrumble.value : 0.0;
        final deathOpacity = widget.isDead ? _deathOpacity.value : 1.0;
        final squash = widget.isHit ? _hitSquash.value : 0.0;
        final hitDx = widget.isHit ? _hitSlide.value : 0.0;
        final dy = _floatAnimation.value;
        final jiggle = _jiggleAnimation.value;
        final breatheScale = _breatheAnimation.value;
        final overeat = widget.overeatFactor.clamp(0.0, 1.0);
        final overeatX = 1.0 + overeat * 0.30;
        final overeatY = 1.0 + overeat * 0.38;
        final phaseOpacity = widget.isPhaseChanging ? _phaseFade.value : 1.0;
        final scaleX = breatheScale * overeatX * (1.0 - squash * 0.16) *
            (widget.isDead ? (1.0 - deathT * 0.35) : 1.0);
        final scaleY = breatheScale * overeatY * (1.0 + squash * 0.10) *
            (widget.isDead ? (1.0 - deathT * 0.45) : 1.0);

        ColorFilter colorFilter = const ColorFilter.mode(
          Colors.transparent,
          BlendMode.dst,
        );
        if (widget.isDead) {
          colorFilter = ColorFilter.mode(
            copper.withValues(alpha: 0.35 + deathT * 0.25),
            BlendMode.modulate,
          );
        } else if (widget.isHit && _hitController.value < 0.38) {
          final intensity =
              (1 - _hitController.value / 0.38).clamp(0.0, 1.0);
          colorFilter = ColorFilter.mode(
            AppColors.hitSpark.withValues(alpha: 0.42 * intensity),
            BlendMode.srcATop,
          );
        }

        final emberPulse = widget.isEnraged
            ? (0.72 + _emberAnimation.value * 0.28)
            : _emberAnimation.value;

        Widget monsterCard = Container(
          width: widget.emojiSize * 1.4,
          height: widget.emojiSize * 1.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: widget.isEnraged
                  ? [ember.withValues(alpha: 0.45 + emberPulse * 0.2), AppColors.bg]
                  : [copper.withValues(alpha: 0.25), AppColors.card],
            ),
            border: Border.all(
              color: widget.isEnraged ? ember : copper,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isEnraged ? ember : copper)
                    .withValues(alpha: 0.35 + (widget.isEnraged ? emberPulse * 0.2 : 0)),
                blurRadius: widget.isEnraged ? 26 : 20,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: copper.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
              ),
              Opacity(
                opacity: (1.0 - deathT * 0.55).clamp(0.0, 1.0),
                child: ForgeMonsterArt(
                  kind: monsterKindOf(widget.emoji),
                  size: widget.emojiSize * 0.95,
                  isEnraged: widget.isEnraged,
                  emberPulse: emberPulse,
                ),
              ),
              Positioned(
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: copper.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    widget.isEnraged ? '狂暴脂肪霸主' : '卡路里领主',
                    style: AppFonts.body(
                      color: widget.isEnraged ? ember : AppColors.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return Opacity(
          opacity: deathOpacity * phaseOpacity,
          child: Transform.translate(
            offset: Offset(hitDx, dy),
            child: Transform.rotate(
              angle: jiggle + (widget.isDead ? deathT * 0.08 : 0),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                child: ColorFiltered(
                  colorFilter: colorFilter,
                  child: monsterCard,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHitShavings(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _hitController,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.emojiSize * 1.6),
          painter: ClayShavingPainter(
            progress: _hitController.value,
            clay: const Color(0xFFC4A574),
            graphite: scheme.secondary,
          ),
        );
      },
    );
  }

  Widget _buildEnrageGlow(BuildContext context) {
    final ember = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _emberAnimation,
      builder: (context, _) {
        final pulse = 0.45 + _emberAnimation.value * 0.4;
        return Container(
          width: widget.emojiSize * 1.45,
          height: widget.emojiSize * 1.45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ember.withValues(alpha: 0.12 * pulse),
            boxShadow: [
              BoxShadow(
                color: ember.withValues(alpha: 0.38 * pulse),
                blurRadius: 28,
                spreadRadius: 6,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeathCrumble(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _deathController,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.emojiSize * 1.6),
          painter: ClayCrumblePainter(
            progress: _deathCrumble.value,
            clay: const Color(0xFFB08968),
            ember: scheme.primary,
          ),
        );
      },
    );
  }

  /// 低血量：粘土表面裂纹，而不是血迹 emoji
  Widget _buildLowHpCracks(BuildContext context) {
    final copper = Theme.of(context).colorScheme.secondary;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(widget.emojiSize * 1.2),
        painter: _ClayCrackPainter(
          color: copper.withValues(alpha: 0.45),
          intensity: (0.3 - widget.hpPercentage).clamp(0.0, 0.3) / 0.3,
        ),
      ),
    );
  }
}

class _ClayCrackPainter extends CustomPainter {
  final Color color;
  final double intensity;

  _ClayCrackPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35 + intensity * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(c.dx - 18, c.dy - 6)
      ..lineTo(c.dx - 4, c.dy + 2)
      ..lineTo(c.dx + 10, c.dy - 8)
      ..moveTo(c.dx + 2, c.dy + 2)
      ..lineTo(c.dx + 16, c.dy + 14)
      ..moveTo(c.dx - 8, c.dy + 8)
      ..lineTo(c.dx - 18, c.dy + 18);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ClayCrackPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.color != color;
}
