import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../theme/motion.dart';
import 'clay_fx.dart';

/// 胜利奖励信息
class VictoryReward {
  /// 金币奖励
  final int coins;

  ///  怪物�
  final String monsterName;

  /// 怪物等级
  final int monsterLevel;

  /// 是否 Boss
  final bool isBoss;

  ///  连续天数（可选，> 0 显示�
  final int streak;

  const VictoryReward({
    required this.coins,
    required this.monsterName,
    required this.monsterLevel,
    this.isBoss = false,
    this.streak = 0,
  });
}

/// 胜利特效
///
/// 设计参�?Web �?VictoryEffect.tsx�?/// - 金币雨（30 个金币）
/// - 星星发散�?2 颗星�?/// - "VICTORY!" 大字动画
/// - 奖励信息卡片
class VictoryEffect extends StatefulWidget {
  /// 奖励信息（null 则只播放纯特效）
  final VictoryReward? reward;

  ///  完成回调（用户点�?收下成就"按钮�
  final VoidCallback? onCollect;

  /// 是否显示奖励卡片
  final bool showRewardCard;

  const VictoryEffect({
    super.key,
    this.reward,
    this.onCollect,
    this.showRewardCard = true,
  });

  @override
  State<VictoryEffect> createState() => _VictoryEffectState();
}

class _VictoryEffectState extends State<VictoryEffect>
    with TickerProviderStateMixin {
  // 整体淡入淡出
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // 奖杯入场（旋�?+ 弹性）
  late final AnimationController _trophyController;
  late final Animation<double> _trophyScale;
  late final Animation<double> _trophyRotation;

  // 奖杯持续摆动
  late final AnimationController _swingController;
  late final Animation<double> _swingAnimation;

  // 文字入场
  late final AnimationController _textController;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textY;

  // 奖励卡片入场
  late final AnimationController _cardController;
  late final Animation<double> _cardOpacity;
  late final Animation<double> _cardY;

  late final AnimationController _sparkController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _trophyController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _trophyScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.easeOutCubic),
    );
    _trophyRotation = Tween<double>(begin: -math.pi, end: 0).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.easeOut),
    );

    _swingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _swingAnimation = Tween<double>(begin: -0.17, end: 0.17).animate(
      CurvedAnimation(parent: _swingController, curve: Curves.easeInOut),
    ); // �?±10°

    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textY = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardY = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );

    _sparkController = AnimationController(
      duration: AppMotion.spark,
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      _trophyController.forward();
      _sparkController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _trophyController.dispose();
    _swingController.dispose();
    _textController.dispose();
    _cardController.dispose();
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        body: Stack(
          alignment: Alignment.center,
          children: [
            _buildBackgroundGlow(),
            _buildChiselSpark(),
            _buildCenterContent(),
          ],
        ),
      ),
    );
  }

  /// 背景径向光晕
  Widget _buildBackgroundGlow() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _swingController,
        builder: (context, _) {
          final t = (_swingAnimation.value.abs() / 0.17);
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.6,
                colors: [
                  AppColors.gold.withValues(alpha: 0.1 + t * 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChiselSpark() {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _sparkController,
          builder: (context, _) {
            if (AppMotion.reduceMotion(context)) {
              return const SizedBox.shrink();
            }
            return CustomPaint(
              painter: ChiselSparkPainter(
                progress: _sparkController.value,
                spark: AppColors.hitSpark,
                clay: scheme.secondary,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 中央内容：奖�?+ VICTORY 文字 + 奖励卡片
  Widget _buildCenterContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          _buildTrophy(),
          const SizedBox(height: 16),
          _buildVictoryText(),
          if (widget.showRewardCard && widget.reward != null) ...[
            const SizedBox(height: 24),
            _buildRewardCard(),
          ],
          const SizedBox(height: 24),
          _buildCollectButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 奖杯
  Widget _buildTrophy() {
    return AnimatedBuilder(
      animation: Listenable.merge([_trophyController, _swingController]),
      builder: (context, _) {
        return Transform.rotate(
          angle: _trophyRotation.value + _swingAnimation.value,
          child: Transform.scale(
            scale: _trophyScale.value,
            child: const Text(
              '🏆',
              style: TextStyle(
                fontSize: 80,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );
  }

  /// VICTORY 大字
  Widget _buildVictoryText() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _textY.value),
          child: Opacity(
            opacity: _textOpacity.value,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  colors: [AppColors.gold, Colors.orange, AppColors.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: const Text(
                'Victory!',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 奖励信息卡片
  Widget _buildRewardCard() {
    final reward = widget.reward!;
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _cardY.value),
          child: Opacity(
            opacity: _cardOpacity.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${reward.monsterName}${reward.isBoss ? ' (Boss)' : ''} defeated!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          '+${reward.coins}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reward.streak > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Streak ${reward.streak} days',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 收下成就按钮
  Widget _buildCollectButton() {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, _) {
        return Opacity(
          opacity: _cardOpacity.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onCollect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Collect Rewards',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
