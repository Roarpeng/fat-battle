import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../services/ble_service.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/home/monster_stage_avatar.dart';
import '../widgets/home/stage_action_button.dart';
import '../widgets/hp_bar.dart';
import '../widgets/hub_status_dot.dart';
import 'exercise_page.dart';
import 'food_page.dart';
import 'settings_page.dart';

/// 方案 A：首页即舞台
class HomePage extends ConsumerStatefulWidget {
  final void Function(int index)? onTabSwitch;

  const HomePage({super.key, this.onTabSwitch});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hitFlash = false;
  String? _floatLabel;
  Color _floatColor = AppColors.ember;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);

    ref.listen<GameState>(gameStateProvider, (prev, next) {
      if (prev == null) return;
      _reactToCombat(prev, next);
    });

    if (!gameState.hasGame) {
      return const Center(child: Text('请先创建角色'));
    }

    final mealCount =
        gameState.meals.values.fold<int>(0, (n, list) => n + list.length);
    final exerciseCount = gameState.exercises.length;

    return ForgeBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              _buildTopBar(gameState),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gameState.monster.name,
                      style: GoogleFonts.fraunces(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusLine(gameState),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                        fontSize: 14,
                        color: AppColors.text2,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        MonsterStageAvatar(
                          monster: gameState.monster,
                          hitFlash: _hitFlash,
                          onTap: () {
                            setState(() => _hitFlash = true);
                            Future.delayed(const Duration(milliseconds: 120),
                                () {
                              if (mounted) setState(() => _hitFlash = false);
                            });
                          },
                        ),
                        if (_floatLabel != null)
                          Positioned(
                            top: 8,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _floatLabel == null ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  _floatLabel!,
                                  style: GoogleFonts.fraunces(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: _floatColor,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: HpBar(
                        current: gameState.monster.hp,
                        max: gameState.monster.maxHp,
                        color: AppColors.ember,
                        shield: gameState.monster.shield,
                        shieldColor: AppColors.shield,
                        height: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (gameState.status == GameStatus.won)
                _banner(
                  title: '今日雕琢完成',
                  subtitle: '炉火温着，明日再战',
                  color: AppColors.green,
                  actionLabel: '再来一次',
                  onAction: () => notifier.startNewChallenge(),
                ),
              if (gameState.status == GameStatus.lost)
                _banner(
                  title: '今日精力耗尽',
                  subtitle: '好好休养，明天满血归来',
                  color: AppColors.shield,
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  StageActionButton(
                    icon: Icons.restaurant_rounded,
                    label: '饮食',
                    subtitle: mealCount > 0 ? '今日已记 $mealCount 餐' : '记录一餐',
                    tone: StageActionTone.food,
                    onTap: () => _openFood(),
                  ),
                  const SizedBox(width: 12),
                  StageActionButton(
                    icon: Icons.fitness_center_rounded,
                    label: '锤炼',
                    subtitle:
                        exerciseCount > 0 ? '今日已练 $exerciseCount 次' : '开练攻击',
                    tone: StageActionTone.forge,
                    onTap: () => _openExercise(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reactToCombat(GameState prev, GameState next) {
    final dHp = prev.monster.hp - next.monster.hp;
    final dShield = next.monster.shield - prev.monster.shield;
    if (dHp > 0) {
      HapticFeedback.heavyImpact();
      _showFloat('-$dHp', AppColors.ember);
      setState(() => _hitFlash = true);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) setState(() => _hitFlash = false);
      });
    } else if (dShield > 0) {
      HapticFeedback.lightImpact();
      _showFloat('+$dShield 盾', AppColors.shield);
    } else if (dShield < 0 && dHp <= 0) {
      HapticFeedback.mediumImpact();
      _showFloat('${dShield.abs()} 破盾', AppColors.copper);
    }
  }

  void _showFloat(String label, Color color) {
    setState(() {
      _floatLabel = label;
      _floatColor = color;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _floatLabel = null);
    });
  }

  String _statusLine(GameState gs) {
    if (gs.status == GameStatus.won) return '今日任务完成，炉火歇着';
    if (gs.status == GameStatus.lost) return '精力见底，先去休整';
    if (gs.monster.hasShield) return '它裹着护甲——吃少一点，或去锤炼破盾';
    if (gs.remainingCal >= 0) {
      return '再消耗约 ${(gs.monster.hp * 0.8).toInt()} kcal 就能攻克它';
    }
    return '已超出 ${-gs.remainingCal} kcal，动一动就能削盾';
  }

  Widget _buildTopBar(GameState gs) {
    return Row(
      children: [
        Consumer(
          builder: (context, ref, _) {
            final bleState = ref.watch(bleConnectionStateProvider);
            HubStatus status = HubStatus.disconnected;
            String tip = '连接腰部 Hub';
            bleState.whenData((data) {
              if (data.isConnected) {
                status = HubStatus.connected;
                tip = '已连接 ${data.name}';
              }
            });
            return HubStatusDot(
              status: status,
              size: 9,
              tooltip: tip,
              onTap: () => _showHubBottomSheet(context),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          '第 ${gs.day} 天',
          style: GoogleFonts.figtree(
            fontSize: 13,
            color: AppColors.text2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.monetization_on_rounded,
                  size: 14, color: AppColors.copper),
              const SizedBox(width: 4),
              Text(
                '${gs.coins}',
                style: GoogleFonts.figtree(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.copper,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '更多',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          icon: const Icon(Icons.tune_rounded, color: AppColors.text2),
        ),
      ],
    );
  }

  Widget _banner({
    required String title,
    required String subtitle,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.figtree(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.figtree(
                    fontSize: 12,
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Future<void> _openFood() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FoodPage(showMonsterHeader: true)),
    );
  }

  Future<void> _openExercise() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExercisePage(showMonsterHeader: true),
      ),
    );
  }

  void _showHubBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HubConnectionSheet(),
    );
  }
}

class HubConnectionSheet extends ConsumerStatefulWidget {
  const HubConnectionSheet({super.key});

  @override
  ConsumerState<HubConnectionSheet> createState() => _HubConnectionSheetState();
}

class _HubConnectionSheetState extends ConsumerState<HubConnectionSheet> {
  bool _isScanning = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    final bleService = ref.read(bleServiceProvider);
    bleService.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 50) _logs.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleService = ref.watch(bleServiceProvider);
    final bleState = ref.watch(bleConnectionStateProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '腰部 Hub',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          bleState.when(
            data: _buildStatusRow,
            loading: () => _buildStatusRow(const BleDeviceState()),
            error: (_, _) => _buildStatusRow(const BleDeviceState()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),
                  label: Text(_isScanning ? '扫描中...' : '扫描设备'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _disconnect(bleService),
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('断开'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _logs.isEmpty ? '等待操作...' : _logs.join('\n'),
                style: GoogleFonts.figtree(
                  fontSize: 12,
                  color: AppColors.text2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BleDeviceState data) {
    final connected = data.isConnected;
    return Row(
      children: [
        HubStatusDot(
          status: connected
              ? HubStatus.connected
              : (_isScanning ? HubStatus.connecting : HubStatus.disconnected),
          size: 12,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            connected
                ? (data.name.isEmpty ? 'ESP32-Hub' : data.name)
                : (_isScanning ? '扫描中…' : '未连接'),
            style: GoogleFonts.figtree(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Future<void> _startScan() async {
    final bleService = ref.read(bleServiceProvider);
    setState(() => _isScanning = true);
    try {
      await bleService.startScan();
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _disconnect(BleService bleService) async {
    await bleService.disconnect();
  }
}
