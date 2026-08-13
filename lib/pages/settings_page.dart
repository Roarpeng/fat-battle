import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/forge_theme.dart';
import '../theme/app_icons.dart';
import '../theme/forge_routes.dart';
import '../theme/tokens.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../config/api_config.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';
import '../services/voice_service.dart';
import '../widgets/settings/sync_status_tile.dart';
import '../pages/auth_page.dart';
import '../pages/companion_page.dart';
import '../pages/achievements_page.dart';
import '../pages/privacy_page.dart';
import '../providers/inventory_provider.dart';
import '../widgets/forge_pressable.dart';
import '../widgets/home/forge_background.dart';
import '../widgets/meta/shop_item_card.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  AuthUser? _me;
  String? _localAccount;
  bool? _gatewayReachable; // null = 探测中 / 未开始

  @override
  void initState() {
    super.initState();
    _loadAccountAndGateway();
  }

  Future<void> _loadAccountAndGateway() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString('user_nickname') ??
        prefs.getString('user_account');
    final localEmail = prefs.getString('user_email');
    if (mounted) {
      setState(() {
        _localAccount = local;
        if (localEmail != null && localEmail.isNotEmpty) {
          _me = AuthUser(
            email: localEmail,
            nickname: local ?? '',
          );
        }
      });
    }

    if (AuthService().isBackendConfigured) {
      try {
        final me = await AuthService().fetchMe();
        if (mounted && me != null) {
          setState(() => _me = me);
        }
      } catch (_) {}
      final ok = await AuthService().pingHealthz();
      if (mounted) setState(() => _gatewayReachable = ok);
    } else if (mounted) {
      setState(() => _gatewayReachable = false);
    }
  }

  String get _accountTitle {
    final nick = _me?.nickname.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    final local = _localAccount?.trim() ?? '';
    if (local.isNotEmpty) return local;
    return '未登录';
  }

  String get _accountSubtitle {
    final email = _me?.email.trim() ?? '';
    if (email.isNotEmpty) return email;
    if (_localAccount == '离线体验勇士') return '离线试用（未绑定邮箱）';
    return AuthService().isBackendConfigured ? '正在同步账号…' : '离线模式';
  }
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
            style: AppFonts.display(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
        padding: AppSpace.page.copyWith(bottom: AppSpace.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 游戏设置
            ForgeSurface(
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
                        padding: const EdgeInsets.only(top: AppSpace.sm),
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
                            const SizedBox(width: AppSpace.md),
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
            const SizedBox(height: AppSpace.lg),
            
            // 角色风格选择
            ForgeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ForgeSectionHeader(title: '角色风格', subtitle: '影响战斗语音风格'),
                    Row(
                      children: CharacterStyle.values.map((style) {
                        final currentVoice = VoiceService().style;
                        final voiceStyleMap = {
                          CharacterStyle.pet: VoiceStyle.pet,
                          CharacterStyle.warrior: VoiceStyle.warrior,
                          CharacterStyle.mage: VoiceStyle.mage,
                          CharacterStyle.assassin: VoiceStyle.assassin,
                        };
                        final isSelected = currentVoice == voiceStyleMap[style];

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs - 1),
                            child: ForgePressable(
                              onTap: () {
                                VoiceService().setStyle(voiceStyleMap[style]!);
                                setState(() {});
                                _showToast('已切换为${style.name}风格');
                              },
                              borderRadius: AppRadii.smAll,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: AppSpace.md - 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.purple.withValues(alpha: 0.25)
                                      : AppColors.surface,
                                  borderRadius: AppRadii.smAll,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.purple
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.characterStyle(style),
                                      size: 20,
                                      color: isSelected ? AppColors.purple : AppColors.text2,
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    Text(
                                      style.name,
                                      style: AppFonts.body(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? AppColors.purple : AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
            ),
            const SizedBox(height: AppSpace.lg),

            // 养成与元系统
            const ForgeSectionHeader(
              title: '养成与元系统',
              subtitle: '伙伴、成就与商店',
            ),
            ForgeSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _navRow(
                    icon: Icons.pets_outlined,
                    title: '战斗伙伴',
                    subtitle: '切换宠物、互动与领取掉落',
                    onTap: () {
                      Navigator.of(context).push(
                        forgePageRoute(builder: (_) => const CompanionPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _navRow(
                    icon: Icons.emoji_events_outlined,
                    title: '成就',
                    subtitle:
                        '已解锁 ${gameState.achievements.length}/${Achievements.all.length}',
                    onTap: () {
                      Navigator.of(context).push(
                        forgePageRoute(builder: (_) => const AchievementsPage()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _navRow(
                    icon: Icons.storefront_outlined,
                    title: '锻造商店',
                    subtitle: '用金币购买道具与装饰',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ForgeSurface(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: AppSpace.xs,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          color: AppColors.copper.withValues(alpha: 0.12),
                          borderColor: AppColors.copper.withValues(alpha: 0.35),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_outlined,
                                  color: AppColors.copper, size: 14),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                '${gameState.coins}',
                                style: AppFonts.display(
                                  color: AppColors.copper,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.copper),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        forgePageRoute(builder: (_) => const ShopPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            
            // 成就分享卡片
            ForgeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ForgeSectionHeader(
                      title: '成就分享',
                      subtitle: '将你的雕刻成就分享给朋友',
                    ),
                    _buildAchievementCard(gameState),
                    const SizedBox(height: AppSpace.md),
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
            const SizedBox(height: AppSpace.lg),

            // —— 云同步（P0）独立 widget：lib/widgets/settings/sync_status_tile.dart ——
            const ForgeSectionHeader(
              title: '云同步',
              subtitle: '登录后自动备份进度，重装可从服务器恢复',
            ),
            ForgeSurface(
              child: const SyncStatusTile(),
            ),
            const SizedBox(height: AppSpace.lg),

            // 数据导出/备份
            ForgeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ForgeSectionHeader(
                      title: '数据管理',
                      subtitle: '导出数据备份或从备份恢复',
                    ),
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
                        const SizedBox(width: AppSpace.md),
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
            const SizedBox(height: AppSpace.lg),

            // 账号管理与隐私合规 (App Store / Google Play / 国内市场强制上架要求)
            const ForgeSectionHeader(
              title: '账号安全与隐私规范',
              subtitle: '合规入口与账号操作',
            ),
            ForgeSurface(
              child: Column(
                  children: [
                    _buildSettingItem(
                      icon: '👤',
                      title: _accountTitle,
                      subtitle: _accountSubtitle,
                      trailing: Icon(
                        Icons.badge_outlined,
                        color: AppColors.copper,
                        size: 20,
                      ),
                    ),
                    const Divider(color: AppColors.border),

                    // 后端 API 网关：绑定 ApiConfig + healthz
                    _buildSettingItem(
                      icon: '🌐',
                      title: 'API 网关服务',
                      subtitle: !ApiConfig.isBackendEnabled
                          ? '未配置 API_BASE_URL，识别走本地/调试直连'
                          : _gatewayReachable == true
                              ? '已连接 ${ApiConfig.backendBaseUrl}'
                              : _gatewayReachable == false
                                  ? '已配置但 healthz 不可达'
                                  : '正在检测 ${ApiConfig.backendBaseUrl}',
                      trailing: Icon(
                        !ApiConfig.isBackendEnabled
                            ? Icons.cancel_outlined
                            : _gatewayReachable == true
                                ? Icons.check_circle_outline
                                : _gatewayReachable == false
                                    ? Icons.error_outline
                                    : Icons.hourglass_empty,
                        color: !ApiConfig.isBackendEnabled ||
                                _gatewayReachable == false
                            ? AppColors.red
                            : _gatewayReachable == true
                                ? AppColors.green
                                : AppColors.text2,
                        size: 20,
                      ),
                    ),
                    const Divider(color: AppColors.border),

                    _buildSettingItem(
                      icon: '☁️',
                      title: '云端进度同步',
                      subtitle: '关闭后不再把游戏进度上传到服务器',
                      trailing: Switch(
                        value: gameState.cloudSyncEnabled,
                        onChanged: (v) {
                          gameNotifier.updatePrivacyFlags(cloudSyncEnabled: v);
                          _showToast(v ? '已允许云端同步' : '已关闭云端同步');
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    _buildSettingItem(
                      icon: '📷',
                      title: '食物视觉识别',
                      subtitle: '关闭后拍照识别不再上传图片',
                      trailing: Switch(
                        value: gameState.foodVisionEnabled,
                        onChanged: (v) {
                          gameNotifier.updatePrivacyFlags(foodVisionEnabled: v);
                          _showToast(v ? '已允许食物识别' : '已关闭食物识别');
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                    const Divider(color: AppColors.border),
                    _buildSettingItem(
                      icon: '🤸',
                      title: '摄像头姿态检测',
                      subtitle: '关闭后锻炼不再使用摄像头采集姿态',
                      trailing: Switch(
                        value: gameState.cameraPoseEnabled,
                        onChanged: (v) {
                          gameNotifier.updatePrivacyFlags(cameraPoseEnabled: v);
                          _showToast(v ? '已允许姿态检测' : '已关闭姿态检测');
                        },
                        activeColor: AppColors.green,
                      ),
                    ),
                    const Divider(color: AppColors.border),

                    // 隐私政策入口（商店上架合规）
                    ForgePressable(
                      onTap: () => Navigator.of(context).push(
                        forgePageRoute(builder: (_) => const PrivacyPolicyPage()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                        child: Row(
                          children: [
                            const Icon(Icons.policy_outlined, color: AppColors.copper, size: 20),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '用户协议与隐私政策',
                                    style: AppFonts.body(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    '信息收集、权限用途与注销说明',
                                    style: AppFonts.body(fontSize: 12, color: AppColors.text2),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.text2, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.border),

                    // 退出当前账号按钮
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('退出当前账号 / 切换身份'),
                        onPressed: () async {
                          // 真实后端模式下通知后端登出并清理 token；
                          // 未配置后端时仅做本地清理（向后兼容）
                          await AuthService().logout();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('is_logged_in', false);
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              forgePageRoute(builder: (_) => const AuthPage()),
                              (route) => false,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.copper,
                          side: BorderSide(color: AppColors.copper.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),

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
                                '注销后账号立即停用，云端数据将在 30 天后彻底清除；本地身高体重、锻炼、饮食与成就会马上抹除且不可恢复。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('取消'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    _showToast('正在注销账号并抹除数据…');
                                    // 先删云端账号（后端 DELETE /user），成功后再擦本地
                                    final ok = await AuthService().deleteAccount();
                                    if (!mounted) return;
                                    if (!ok) {
                                      _showToast('网络异常，云端删除失败，请重试');
                                      return;
                                    }
                                    gameNotifier.resetGame();
                                    Navigator.of(context).pushReplacement(
                                      forgePageRoute(builder: (_) => const AuthPage()),
                                    );
                                    _showToast('账号已注销。云端数据将在 30 天后清除');
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
                Icon(AppIcons.achievement(a.id), size: 16, color: AppColors.gold),
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

  /// 设置导航行
  Widget _navRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ForgePressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.copper, size: 24),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.body(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: AppFonts.body(color: AppColors.text2, fontSize: 12),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: AppColors.copper),
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
    final display = AppFonts.display(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
    final body = AppFonts.body(color: AppColors.text);

    return ForgeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('锻造商店', style: display.copyWith(fontSize: 20)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.lg),
              child: Center(
                child: ForgeSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md - 2,
                    vertical: AppSpace.xs,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  color: AppColors.copper.withValues(alpha: 0.12),
                  borderColor: AppColors.copper.withValues(alpha: 0.35),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          color: AppColors.copper, size: 16),
                      const SizedBox(width: AppSpace.xs),
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
          padding: AppSpace.page.copyWith(bottom: AppSpace.xxl),
          children: [
            ForgeSurface(
              color: AppColors.surface,
              borderRadius: AppRadii.smAll,
              padding: AppSpace.card,
              child: Text(
                '购买后金币从主存档扣除；物品栏数量写入本地 inventory 存档。',
                style: body.copyWith(color: AppColors.text2, fontSize: 11),
              ),
            ),
            const SizedBox(height: AppSpace.md),
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