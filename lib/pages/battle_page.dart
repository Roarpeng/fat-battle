import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../widgets/battle/battle_effects.dart';
import '../widgets/battle/damage_number.dart' show DamageType;
import '../widgets/battle/hp_bar.dart';
import '../widgets/battle/victory_effect.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/hub_status_dot.dart';
import '../services/ble_service.dart';

/// 锻造工坊 · 战斗舞台（核心玩法页）
class BattlePage extends ConsumerStatefulWidget {
  /// Tab 切换：1 饮食 / 2 锤炼 / 3 进度
  final void Function(int index)? onTabSwitch;

  const BattlePage({super.key, this.onTabSwitch});

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage> {
  TextStyle get _displayStyle => AppFonts.display(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  DamageEvent? _lastDamage;
  int _prevMonsterHp = 0;
  int _prevMonsterShield = 0;
  bool _isShieldBreaking = false;
  bool _isPhaseChanging = false;
  bool _showVictory = false;
  GameStatus _prevStatus = GameStatus.playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameState = ref.read(gameStateProvider);
      _prevMonsterHp = gameState.monster.hp;
      _prevMonsterShield = gameState.monster.shield;
      _prevStatus = gameState.status;
    });
  }

  void _onGameStateChange(GameState gs) {
    if (gs.monster.hp != _prevMonsterHp) {
      final damageValue =
          (_prevMonsterHp - gs.monster.hp).clamp(0, _prevMonsterHp);
      if (damageValue > 0) {
        final isCritical = (gs.monster.hp + _prevMonsterHp) % 7 == 0;
        final shieldBroken =
            _prevMonsterShield > 0 && gs.monster.shield < _prevMonsterShield;
        final attackKind = inferAttackKind('running');
        setState(() {
          _lastDamage = DamageEvent(
            value: damageValue,
            type: isCritical
                ? DamageType.critical
                : (shieldBroken ? DamageType.shield : DamageType.damage),
            attackKind: shieldBroken ? null : attackKind,
          );
          if (shieldBroken) {
            _isShieldBreaking = true;
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() => _isShieldBreaking = false);
              }
            });
          }
        });
      }
      _prevMonsterHp = gs.monster.hp;
    }

    if (gs.monster.shield != _prevMonsterShield) {
      final shieldDelta =
          (gs.monster.shield - _prevMonsterShield).clamp(0, gs.monster.shield);
      if (shieldDelta > 0 && _prevMonsterHp == gs.monster.hp) {
        setState(() {
          _lastDamage = DamageEvent(
            value: shieldDelta,
            type: DamageType.shield,
            attackKind: null,
          );
        });
      }
      _prevMonsterShield = gs.monster.shield;
    }

    if (gs.status == GameStatus.won && _prevStatus != GameStatus.won) {
      setState(() => _showVictory = true);
    }
    _prevStatus = gs.status;
  }

  String _getStatusMessage(GameState gs) {
    if (gs.status == GameStatus.won) {
      return '怪物已被击败，炉火正旺，明日再战';
    }
    if (gs.status == GameStatus.lost) {
      return '精力耗尽，好好休养，明天满血归来';
    }
    if (gs.monster.hasShield) {
      return '它裹着护甲——吃少一点，或去锤炼破盾';
    }
    if (gs.remainingCal >= 0) {
      return '再消耗约 ${(gs.monster.hp * 0.8).toInt()} kcal 就能攻克它';
    }
    return '已超出 ${-gs.remainingCal} kcal，动一动就能削盾';
  }

  String _getCalorieDisplay(GameState gs) {
    final remaining = gs.remainingCal;
    if (remaining >= 0) {
      return '今日目标还剩 $remaining kcal';
    }
    return '已超支 ${-remaining} kcal';
  }

  Color _getCalorieColor(GameState gs) {
    if (gs.remainingCal >= 500) return AppColors.green;
    if (gs.remainingCal >= 0) return AppColors.copper;
    return AppColors.ember;
  }

  String _getTierName(Monster monster) {
    if (monster.isBoss) return 'BOSS';
    return '精英';
  }

  Color _getTierColor(Monster monster) {
    if (monster.isBoss) return AppColors.ember;
    return AppColors.bg3;
  }

  void _switchTabOrPop(int index) {
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(index);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);

    ref.listen(gameStateProvider, (previous, next) {
      _onGameStateChange(next);
    });

    if (!gameState.hasGame) {
      return const Center(child: Text('请先创建角色'));
    }

    final hour = DateTime.now().hour;
    String greeting = '炉火正旺，向卡路里怪物宣战';
    if (hour < 6) {
      greeting = '夜深了，养精蓄锐，明天再战';
    } else if (hour < 12) {
      greeting = '早安，工坊开工，先打败它';
    } else if (hour < 18) {
      greeting = '午后时光，动一动就削它一层血';
    } else {
      greeting = '夜幕降临，炉火正旺，继续雕琢';
    }

    final monsterBattle = MonsterBattleState.from(
      gameState.monster,
      isPhaseChanging: _isPhaseChanging,
    );

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  _buildTopBar(gameState),
                  const SizedBox(height: 16),
                  _buildInfoSummary(gameState),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildBattleArea(
                      gameState: gameState,
                      monsterBattle: monsterBattle,
                      greeting: greeting,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 8),
                  if (gameState.status == GameStatus.won &&
                      !_showVictory) ...[
                    const SizedBox(height: 8),
                    _buildWinBanner(gameNotifier),
                  ],
                  if (gameState.status == GameStatus.lost) ...[
                    const SizedBox(height: 8),
                    _buildLoseBanner(),
                  ],
                ],
              ),
            ),
            if (_showVictory)
              VictoryEffect(
                reward: VictoryReward(
                  coins: gameState.monster.isBoss ? 200 : 100,
                  monsterName: gameState.monster.name,
                  monsterLevel: gameState.monster.level,
                  isBoss: gameState.monster.isBoss,
                  streak: gameState.streak,
                ),
                onCollect: () {
                  setState(() => _showVictory = false);
                  gameNotifier.startNewChallenge();
                },
              ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameState gs) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: '返回',
        ),
        const SizedBox(width: 4),
        Consumer(
          builder: (context, ref, child) {
            final bleState = ref.watch(bleConnectionStateProvider);
            HubStatus status = HubStatus.disconnected;
            String tooltip = '腰部 Hub';
            bleState.whenData((data) {
              if (data.isConnected) {
                status = HubStatus.connected;
                tooltip = '已连接 Hub - ${data.name}';
              }
            });
            return HubStatusDot(
              status: status,
              size: 8,
              tooltip: tooltip,
            );
          },
        ),
        const Spacer(),
        Text(
          '第 ${gs.day} 天',
          style: _bodyStyle.copyWith(color: AppColors.text2, fontSize: 13),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_outlined,
                color: AppColors.copper, size: 14),
            const SizedBox(width: 4),
            Text(
              '${gs.coins}',
              style: _displayStyle.copyWith(
                color: AppColors.copper,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSummary(GameState gs) {
    final isOver = gs.remainingCal < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('摄入', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                const Text(
                  'kcal',
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  '${gs.todayCalIn}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ' / ${gs.targetCal}',
                  style: const TextStyle(color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 12,
            color: AppColors.border,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('消耗', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                const Text(
                  'kcal',
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  '${gs.todayCalExercise}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isOver)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '超支 ${-gs.remainingCal}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBattleArea({
    required GameState gameState,
    required MonsterBattleState monsterBattle,
    required String greeting,
  }) {
    final monster = gameState.monster;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${monster.name} Lv.${monster.level}',
                style: _displayStyle.copyWith(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getTierColor(monster).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTierName(monster),
                  style: TextStyle(
                    color: _getTierColor(monster),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (monster.isBoss) ...[
                const SizedBox(width: 4),
                const Text('👑', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: BattleEffects(
                monster: monsterBattle,
                lastDamage: _lastDamage,
                isShieldBreaking: _isShieldBreaking,
                emojiSize: 88,
                shieldSize: 260,
                onMonsterTap: () {
                  setState(() => _isPhaseChanging = true);
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (mounted) {
                      setState(() => _isPhaseChanging = false);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: BattleHpBar(
              current: monster.hp,
              max: monster.maxHp,
              shield: monster.shield,
              maxShield: monster.maxHp,
              height: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            greeting,
            style: _bodyStyle.copyWith(fontSize: 14, color: AppColors.text2),
          ),
          const SizedBox(height: 4),
          Text(
            _getCalorieDisplay(gameState),
            style: _displayStyle.copyWith(
              fontSize: 22,
              color: _getCalorieColor(gameState),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusMessage(gameState),
            style: _bodyStyle.copyWith(color: AppColors.text2, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(
          emoji: '🍽️',
          label: '饮食',
          onTap: () => _switchTabOrPop(1),
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          emoji: '🔨',
          label: '锤炼',
          onTap: () => _switchTabOrPop(2),
          isPrimary: true,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          emoji: '📈',
          label: '进度',
          onTap: () => _switchTabOrPop(3),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String emoji,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.ember : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? Border.all(color: AppColors.ember.withValues(alpha: 0.5))
                : Border.all(color: AppColors.border),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.ember.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: _bodyStyle.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? const Color(0xFFFFF8F5) : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinBanner(GameStateNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日雕琢完成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                Text(
                  '炉火温着，明日再战',
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => notifier.startNewChallenge(),
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoseBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.copper.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.copper.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🛌', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日精力耗尽',
                  style: _displayStyle.copyWith(
                    fontSize: 14,
                    color: AppColors.copper,
                  ),
                ),
                Text(
                  '好好休养，明天满血归来',
                  style: _bodyStyle.copyWith(color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
