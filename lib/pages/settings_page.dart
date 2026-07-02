import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/voice_service.dart';
import '../pages/welcome_page.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ 设置'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 游戏设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 游戏难度
                    _buildSettingItem(
                      icon: '🎮',
                      title: '游戏难度',
                      subtitle: gameState.difficulty.name,
                      trailing: DropdownButton<Difficulty>(
                        value: gameState.difficulty,
                        items: Difficulty.values.map((d) => 
                          DropdownMenuItem(value: d, child: Text(d.name)),
                        ).toList(),
                        onChanged: (v) {
                          if (v != null) gameNotifier.updateDifficulty(v);
                        },
                        underline: Container(),
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    
                    // 勿扰模式
                    _buildSettingItem(
                      icon: '🔕',
                      title: '勿扰模式',
                      subtitle: '关闭所有提醒',
                      trailing: Switch(
                        value: gameState.dndMode,
                        onChanged: (v) {
                          gameNotifier.updateDndMode(v, gameState.dndStart, gameState.dndEnd);
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                    
                    // 勿扰时间段
                    if (gameState.dndMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: '开始时间',
                                  hintText: '22:00',
                                ),
                                controller: TextEditingController(text: gameState.dndStart),
                                onChanged: (v) {
                                  gameNotifier.updateDndMode(gameState.dndMode, v, gameState.dndEnd);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: '结束时间',
                                  hintText: '08:00',
                                ),
                                controller: TextEditingController(text: gameState.dndEnd),
                                onChanged: (v) {
                                  gameNotifier.updateDndMode(gameState.dndMode, gameState.dndStart, v);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(color: AppColors.border),
                    
                    // 通知开关
                    _buildSettingItem(
                      icon: '🔔',
                      title: '通知提醒',
                      subtitle: '接收成就与每日摘要通知',
                      trailing: Switch(
                        value: gameState.notificationEnabled,
                        onChanged: (v) {
                          gameNotifier.updateNotificationEnabled(v);
                          _showToast(v ? '通知已开启' : '通知已关闭');
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    
                    // 提醒频率
                    _buildSettingItem(
                      icon: '⏰',
                      title: '提醒频率',
                      subtitle: '饮食与锻炼提醒频率',
                      trailing: DropdownButton<String>(
                        value: gameState.reminderFrequency,
                        items: [
                          DropdownMenuItem(value: 'often', child: Text('频繁')),
                          DropdownMenuItem(value: 'normal', child: Text('适中')),
                          DropdownMenuItem(value: 'rare', child: Text('较少')),
                        ].toList(),
                        onChanged: (v) {
                          if (v != null) {
                            gameNotifier.updateReminderFrequency(v);
                            _showToast('提醒频率已调整为: ${v == 'often' ? '频繁' : v == 'normal' ? '适中' : '较少'}');
                          }
                        },
                        underline: Container(),
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    
                    // 语音播报
                    _buildSettingItem(
                      icon: '🔊',
                      title: '语音播报',
                      subtitle: '战斗语音提示',
                      trailing: Switch(
                        value: gameState.voiceEnabled,
                        onChanged: (v) {
                          VoiceService().setEnabled(v);
                          gameNotifier.updateVoiceEnabled(v);
                          _showToast(v ? '语音已开启' : '语音已关闭');
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 角色风格选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('角色风格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: CharacterStyle.values.map((style) {
                        return ChoiceChip(
                          label: Text('${style.emoji} ${style.name}'),
                          selected: false,
                          onSelected: (_) {
                            // 映射角色风格到语音风格
                            final voiceStyleMap = {
                              CharacterStyle.pet: VoiceStyle.pet,
                              CharacterStyle.warrior: VoiceStyle.warrior,
                              CharacterStyle.mage: VoiceStyle.mage,
                              CharacterStyle.assassin: VoiceStyle.assassin,
                            };
                            VoiceService().setStyle(voiceStyleMap[style]!);
                            _showToast('已切换为${style.name}风格');
                          },
                          selectedColor: AppColors.purple.withOpacity(0.3),
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(color: AppColors.text),
                          side: BorderSide(color: AppColors.border),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 成就页面入口
            Card(
              child: ListTile(
                leading: const Text('🏆', style: TextStyle(fontSize: 24)),
                title: const Text('成就'),
                trailing: Text('${gameState.achievements.length}/${Achievements.all.length}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AchievementsPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // 商店页面入口
            Card(
              child: ListTile(
                leading: const Text('🛒', style: TextStyle(fontSize: 24)),
                title: const Text('商店'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🪙', style: TextStyle(color: AppColors.gold)),
                    Text('${gameState.coins}', style: TextStyle(color: AppColors.gold)),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // 重置游戏
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认重置'),
                        content: const Text('确定要重置游戏吗？所有进度将丢失！'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              gameNotifier.resetGame();
                              Navigator.of(ctx).pop();
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const WelcomePage()),
                              );
                              _showToast('游戏已重置');
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                            child: const Text('确认重置'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red.withOpacity(0.15),
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withOpacity(0.3)),
                  ),
                  child: const Text('🗑️ 重置游戏'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 设置项
  Widget _buildSettingItem({
    required String icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 20)),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: AppColors.text2, fontSize: 12)),
      trailing: trailing,
      contentPadding: EdgeInsets.zero,
    );
  }
  
  /// 显示提示
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 成就页面
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 成就'),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: Achievements.all.map((a) {
          final unlocked = gameState.achievements.contains(a.id);
          
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unlocked ? AppColors.gold : AppColors.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  a.emoji,
                  style: TextStyle(
                    fontSize: 36,
                    color: unlocked ? AppColors.text : AppColors.text.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? AppColors.text : AppColors.text.withOpacity(0.4),
                  ),
                ),
                Text(
                  a.desc,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.text2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 商店页面
class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final gameNotifier = ref.read(gameStateProvider.notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛒 商店 '),
            Text('🪙 ${gameState.coins}', style: TextStyle(color: AppColors.gold)),
          ],
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: ShopItems.all.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(item.desc, style: TextStyle(color: AppColors.text2, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('🪙 ${item.price}', style: TextStyle(color: AppColors.gold)),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: gameState.coins >= item.price
                            ? () {
                                gameNotifier.buyItem(item);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('购买成功！${item.name}'),
                                    backgroundColor: AppColors.card,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('购买'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}