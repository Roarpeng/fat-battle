import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../widgets/hp_bar.dart';
import '../widgets/hub_status_dot.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isShaking = false;
  
  String _getStatusMessage(GameState gs) {
    if (gs.status == GameStatus.won) {
      return '今日任务完成 🎉 明天继续保持';
    }
    if (gs.status == GameStatus.lost) {
      return '今日体力已用完，好好休息';
    }
    if (gs.monster.hasShield) {
      return '它套了层壳，去走走就能破防';
    }
    if (gs.remainingCal >= 0) {
      return '再消耗 ${(gs.monster.hp * 0.8).toInt()} kcal 就能击败它';
    } else {
      return '超出 ${-gs.remainingCal} kcal，动一动就好';
    }
  }
  
  String _getCalorieDisplay(GameState gs) {
    final remaining = gs.remainingCal;
    if (remaining >= 0) {
      return '今日还能吃 $remaining kcal';
    } else {
      return '已超出 ${-remaining} kcal';
    }
  }
  
  Color _getCalorieColor(GameState gs) {
    if (gs.remainingCal >= 500) return AppColors.green;
    if (gs.remainingCal >= 0) return AppColors.gold;
    return AppColors.red;
  }
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    
    if (!gameState.hasGame) {
      return const Center(child: Text('请先创建角色'));
    }
    
    final hour = DateTime.now().hour;
    String greeting = '今天也加油';
    if (hour < 6) greeting = '夜深了，早点休息';
    else if (hour < 12) greeting = '早上好';
    else if (hour < 18) greeting = '下午好';
    else greeting = '晚上好';
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // 顶部：状态行（Hub状态点 + 天数 + 金币）
              Row(
                children: [
                  const HubStatusDot(
                    status: HubStatus.disconnected,
                    size: 8,
                    tooltip: '腰部Hub未连接',
                  ),
                  const Spacer(),
                  Text(
                    '第 ${gameState.day} 天',
                    style: TextStyle(color: AppColors.text2, fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '🪙 ${gameState.coins}',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              // 中部：问候 + 卡路里余额 + 怪物 + 血条 + 状态文案
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getCalorieDisplay(gameState),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getCalorieColor(gameState),
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // 怪物
                    GestureDetector(
                      onTap: () => _tapMonster(),
                      child: AnimatedScale(
                        scale: _isShaking ? 0.92 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: Text(
                          gameState.monster.emoji,
                          style: TextStyle(fontSize: 96),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      gameState.monster.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Lv.${gameState.monster.level}${gameState.monster.isBoss ? ' 👑' : ''}',
                      style: TextStyle(color: AppColors.text2, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    
                    // 怪物血条（含护盾）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: HpBar(
                        current: gameState.monster.hp,
                        max: gameState.monster.maxHp,
                        color: AppColors.red,
                        shield: gameState.monster.shield,
                        height: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 状态文案（正向反馈）
                    Text(
                      _getStatusMessage(gameState),
                      style: TextStyle(
                        color: AppColors.text2,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 底部：3个入口按钮
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    _buildActionButton(
                      emoji: '🍽️',
                      label: '饮食',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      emoji: '🏋️',
                      label: '锻炼',
                      onTap: () {},
                      isPrimary: true,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      emoji: '⚖️',
                      label: '称重',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              
              // 胜利/失败轻提示（非弹窗，静默展示）
              if (gameState.status == GameStatus.won)
                _buildWinBanner(gameNotifier),
              if (gameState.status == GameStatus.lost)
                _buildLoseBanner(),
            ],
          ),
        ),
      ),
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
            color: isPrimary ? AppColors.green : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : AppColors.text,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日任务完成',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
                Text(
                  '明日继续保持',
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('😴', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日体力已用完',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.purple,
                  ),
                ),
                Text(
                  '好好休息，明天满血归来',
                  style: TextStyle(color: AppColors.text2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _tapMonster() {
    setState(() {
      _isShaking = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _isShaking = false);
      }
    });
  }
}
