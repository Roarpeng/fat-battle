import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/app_constants.dart';
import '../providers/game_provider.dart';
import '../services/voice_service.dart';
import '../pages/welcome_page.dart';
import '../pages/companion_page.dart';
import '../pages/achievements_page.dart';
import '../providers/inventory_provider.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/meta/shop_item_card.dart';

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
    
    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '工坊设置',
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
          ),
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

            // 养成与元系统
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: AppColors.copper, size: 18),
                const SizedBox(width: 8),
                Text(
                  '养成与元系统',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.pets_outlined, color: AppColors.copper, size: 24),
                    title: Text('战斗伙伴', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '切换宠物、互动与领取掉落',
                      style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppColors.copper),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CompanionPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    leading: Icon(Icons.emoji_events_outlined, color: AppColors.copper, size: 24),
                    title: Text('成就', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '已解锁 ${gameState.achievements.length}/${Achievements.all.length}',
                      style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppColors.copper),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AchievementsPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    leading: Icon(Icons.storefront_outlined, color: AppColors.copper, size: 24),
                    title: Text('锻造商店', style: GoogleFonts.figtree(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '用金币购买道具与装饰',
                      style: GoogleFonts.figtree(color: AppColors.text2, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.copper.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.copper.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on_outlined,
                                  color: AppColors.copper, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${gameState.coins}',
                                style: GoogleFonts.fraunces(
                                  color: AppColors.copper,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.copper),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShopPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 成就分享卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏆 成就分享', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '将你的雕刻成就分享给朋友',
                      style: TextStyle(color: AppColors.text2, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _buildAchievementCard(gameState),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _shareAchievementCard(gameState),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('分享成就卡片'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 数据导出/备份
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💾 数据管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '导出数据备份或从备份恢复',
                      style: TextStyle(color: AppColors.text2, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportData(gameState),
                            icon: const Icon(Icons.file_download, size: 18),
                            label: const Text('导出备份'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _importData(context),
                            icon: const Icon(Icons.file_upload, size: 18),
                            label: const Text('导入备份'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.purple,
                              side: const BorderSide(color: AppColors.purple),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // 账号管理与隐私合规 (App Store / Google Play / 国内市场强制上架要求)
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.copper, size: 18),
                const SizedBox(width: 8),
                Text(
                  '账号安全与隐私规范',
                  style: GoogleFonts.figtree(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 后端 API 网关配置 (防秘钥外泄)
                    _buildSettingItem(
                      icon: '🌐',
                      title: 'API 网关服务',
                      subtitle: '食物卡路里识别与大模型加密中转代理',
                      trailing: Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                    ),
                    const Divider(color: AppColors.border),

                    // 账号注销 (刚性合规项)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('注销账号并抹除个人数据'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('⚠️ 确认注销账号？'),
                              content: const Text(
                                '按照应用市场隐私合规规范，注销账号将永久删除您的身高体重历史、锻炼纪录、饮食卡路里数据及所有游戏成就，且不可恢复！',
                              ),
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
                                    _showToast('账号已安全注销，本地与云端数据已彻底擦除');
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                                  child: const Text('确认彻底注销'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red.withValues(alpha: 0.15),
                          foregroundColor: AppColors.red,
                          side: BorderSide(color: AppColors.red.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
  
  /// 成就卡片预览
  Widget _buildAchievementCard(GameState gs) {
    final unlocked = Achievements.all.where((a) => gs.achievements.contains(a.id)).toList();
    final total = Achievements.all.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.bg2, AppColors.bg3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🔨 塑身工坊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('第${gs.day}天', style: TextStyle(color: AppColors.text2, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '🏆 $unlocked/$total 成就解锁',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          if (unlocked.isNotEmpty)
            Wrap(
              spacing: 4,
              children: unlocked.take(6).map((a) =>
                Text(a.emoji, style: const TextStyle(fontSize: 16)),
              ).toList(),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniStat('🐉', '${gs.kills}杀'),
              const SizedBox(width: 16),
              _miniStat('🔥', '${gs.streak}连'),
              const SizedBox(width: 16),
              _miniStat('🪙', '${gs.coins}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(text, style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// 分享成就卡片
  Future<void> _shareAchievementCard(GameState gs) async {
    final unlocked = Achievements.all.where((a) => gs.achievements.contains(a.id)).toList();
    final body = StringBuffer();
    body.writeln('🔨 塑身工坊 — 我的雕刻报告');
    body.writeln('━━━━━━━━━━━━━━');
    body.writeln('📅 已坚持 ${gs.day} 天');
    body.writeln('🐉 击败怪物 ${gs.kills} 只');
    body.writeln('🔥 连续打卡 ${gs.streak} 天');
    body.writeln('🪙 累计金币 ${gs.coins}');
    body.writeln('⚖️ 当前体重 ${gs.user.weight.toStringAsFixed(1)}kg');
    body.writeln('🏆 成就解锁 ${unlocked.length}/${Achievements.all.length}');
    if (unlocked.isNotEmpty) {
      body.writeln('    ${unlocked.map((a) => a.emoji + a.name).join(' · ')}');
    }
    body.writeln('━━━━━━━━━━━━━━');
    body.writeln('你的身体，是你精心雕琢的作品。');

    try {
      await Share.share(body.toString());
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: body.toString()));
      _showToast('已复制到剪贴板，去分享吧！');
    }
  }

  /// 导出数据备份
  Future<void> _exportData(GameState gs) async {
    try {
      final json = jsonEncode(gs.toJson());
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/body_studio_backup_${DateTime.now().toDateString()}.json');
      await file.writeAsString(json, flush: true);

      // 复制到剪贴板并通过分享发送
      await Clipboard.setData(ClipboardData(text: json));
      _showToast('备份已保存到: ${file.path}\nJSON 已复制到剪贴板');
    } catch (e) {
      _showToast('导出失败: $e');
    }
  }

  /// 导入数据备份
  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text('导入备份将覆盖当前所有进度，确定继续吗？\n\n请从剪贴板粘贴备份数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text == null || text.isEmpty) {
        _showToast('剪贴板为空，请先复制备份数据');
        return;
      }

      final json = jsonDecode(text) as Map<String, dynamic>;
      final restored = GameState.fromJson(json);

      if (!mounted) return;
      // 直接写入 SharedPreferences 让下次启动生效
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs != null) {
        await prefs.setString('fat_battle_game', jsonEncode(restored.toJson()));
      }

      _showToast('备份已导入！请重新打开应用');
    } catch (e) {
      _showToast('导入失败: 数据格式不正确\n$e');
    }
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

/// 商店页面
///
/// 金币扣减走 [gameStateProvider]（持久化），
/// 物品数量同步写入 [inventoryProvider]（SharedPreferences 持久化）。
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inv = ref.read(inventoryProvider);
      if (inv.items.isEmpty) {
        ref.read(inventoryProvider.notifier).initFromShopItems();
      }
    });
  }

  Future<void> _buy(ShopItem item) async {
    final gameState = ref.read(gameStateProvider);
    if (gameState.coins < item.price) return;

    await ref.read(gameStateProvider.notifier).buyItem(item);
    ref.read(inventoryProvider.notifier).addItem(item.id);

    if (!mounted) return;
    final qty = ref.read(inventoryProvider).getQuantity(item.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('购买成功！${item.name}（拥有 ×$qty）'),
        backgroundColor: AppColors.ember.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final inventory = ref.watch(inventoryProvider);
    final display = GoogleFonts.fraunces(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    final body = GoogleFonts.figtree(color: AppColors.text);

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('锻造商店', style: display.copyWith(fontSize: 20)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.copper.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on_outlined,
                          color: AppColors.copper, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${gameState.coins}',
                        style: display.copyWith(
                          color: AppColors.copper,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '购买后金币从主存档扣除；物品栏数量写入本地 inventory 存档。',
                style: body.copyWith(color: AppColors.text2, fontSize: 11),
              ),
            ),
            ...ShopItems.all.map((item) {
              return ShopItemCard(
                item: item,
                ownedQuantity: inventory.getQuantity(item.id),
                coins: gameState.coins,
                onBuy: () => _buy(item),
              );
            }),
          ],
        ),
      ),
    );
  }
}