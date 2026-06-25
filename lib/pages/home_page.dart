import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/game_algorithm.dart';
import '../widgets/hp_bar.dart';

/// 首页（战斗页面）
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _isShaking = false;
  bool _isGlowing = false;
  
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    
    if (!gameState.hasGame) {
      return const Center(child: Text('请先创建角色'));
    }
    
    final season = GameAlgorithm.getCurrentSeason();
    final hour = DateTime.now().hour;
    String greeting = '勇士，准备战斗！';
    if (hour < 6) greeting = '夜深了，注意休息哦';
    else if (hour < 12) greeting = '早上好，新的一天！';
    else if (hour < 18) greeting = '下午好，继续加油！';
    else greeting = '晚上好，今天表现如何？';
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 金币
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        '${gameState.coins}',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 天数
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '📅 第 ${gameState.day} 天',
                    style: TextStyle(color: AppColors.text2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 问候语
            Text(
              greeting,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              gameState.status == GameStatus.won
                  ? '怪物已被击败！'
                  : gameState.status == GameStatus.lost
                      ? '体力耗尽，明天再战'
                      : '击败${gameState.monster.name}！剩余HP: ${gameState.monster.hp}/${gameState.monster.maxHp}',
              style: TextStyle(color: AppColors.text2),
            ),
            const SizedBox(height: 16),
            
            // 怪物卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 赛季徽章
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.purple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'S${((DateTime.now().month - 1) / 3).floor() + 1} ${season.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 怪物emoji
                    GestureDetector(
                      onTap: () => _tapMonster(gameNotifier, gameState),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        child: AnimatedScale(
                          scale: _isShaking ? 0.9 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 100),
                            style: TextStyle(
                              fontSize: 80,
                              color: _isGlowing ? Colors.white : AppColors.text,
                            ),
                            child: Text(gameState.monster.emoji),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // 怪物名称
                    Text(
                      gameState.monster.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Lv.${gameState.monster.level}${gameState.monster.isBoss ? ' 👑 BOSS' : ''}',
                      style: TextStyle(color: AppColors.purple, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // 怪物血条
                    HpBar(
                      current: gameState.monster.hp,
                      max: gameState.monster.maxHp,
                      color: AppColors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // 玩家体力
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('❤️ 我的体力'),
                        Text('${gameState.playerHp}/${gameState.playerMaxHp}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    HpBar(
                      current: gameState.playerHp,
                      max: gameState.playerMaxHp,
                      color: AppColors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 快捷操作
            Row(
              children: [
                _buildQuickAction(
                  emoji: '🍽️',
                  name: '记录饮食',
                  onTap: () {}, // 导航到饮食页
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  emoji: '🏋️',
                  name: '去锻炼',
                  onTap: () {}, // 导航到锻炼页
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  emoji: '🛡️',
                  name: '护盾(${gameState.shieldCount})',
                  onTap: () => gameNotifier.useShield(),
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  emoji: '😴',
                  name: '休息(${gameState.restDaysLeft})',
                  onTap: () => gameNotifier.useRestDay(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 今日战况
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 今日战况',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatBox(
                          value: gameState.todayCalIn.toString(),
                          label: '摄入(千卡)',
                        ),
                        const SizedBox(width: 8),
                        _buildStatBox(
                          value: gameState.todayCalExercise.toString(),
                          label: '消耗(千卡)',
                        ),
                        const SizedBox(width: 8),
                        _buildStatBox(
                          value: gameState.todayDamage.toString(),
                          label: '总伤害',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // 胜利/失败弹窗
            if (gameState.status == GameStatus.won)
              _buildVictoryDialog(gameState, gameNotifier),
            if (gameState.status == GameStatus.lost)
              _buildDefeatDialog(gameNotifier),
          ],
        ),
      ),
    );
  }
  
  /// 快捷操作按钮
  Widget _buildQuickAction({
    required String emoji,
    required String name,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(color: AppColors.text2, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 统计盒子
  Widget _buildStatBox({required String value, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: AppColors.text2, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 点击怪物
  void _tapMonster(GameStateNotifier gameNotifier, GameState gameState) {
    if (gameState.status != GameStatus.playing) return;
    
    setState(() {
      _isShaking = true;
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() {
        _isShaking = false;
      });
    });
    
    // 小伤害
    // gameNotifier.tapMonster(1);
  }
  
  /// 胜利弹窗
  Widget _buildVictoryDialog(GameState gameState, GameStateNotifier gameNotifier) {
    final reward = GameAlgorithm.calcKillReward(gameState.monster.isBoss);
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text(
            '胜利！',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '你击败了 ${gameState.monster.name}！',
            style: TextStyle(color: AppColors.text2),
          ),
          const SizedBox(height: 16),
          Text(
            '🪙 +$reward 金币',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => gameNotifier.startNewChallenge(),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('迎接新挑战'),
          ),
        ],
      ),
    );
  }
  
  /// 失败弹窗
  Widget _buildDefeatDialog(GameStateNotifier gameNotifier) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red),
      ),
      child: Column(
        children: [
          const Text('💥', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text(
            '体力耗尽',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            '今天的挑战失败了...',
            style: TextStyle(color: AppColors.text2),
          ),
          const SizedBox(height: 16),
          Text(
            '明天再战，勇士永不放弃！',
            style: TextStyle(color: AppColors.text2),
          ),
        ],
      ),
    );
  }
}