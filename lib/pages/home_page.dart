import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../widgets/hp_bar.dart';
import '../widgets/hub_status_dot.dart';
import '../services/ble_service.dart';

class HomePage extends ConsumerStatefulWidget {
  final void Function(int index)? onTabSwitch;

  const HomePage({super.key, this.onTabSwitch});
  
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
                  Consumer(
                    builder: (context, ref, child) {
                      final bleState = ref.watch(bleConnectionStateProvider);
                      
                      HubStatus status = HubStatus.disconnected;
                      String tooltip = '点击连接腰部Hub';
                      
                      bleState.whenData((data) {
                        if (data.isConnected) {
                          status = HubStatus.connected;
                          tooltip = '腰部Hub已连接 - ${data.name}';
                        }
                      });
                      
                      return HubStatusDot(
                        status: status,
                        size: 8,
                        tooltip: tooltip,
                        onTap: () => _showHubBottomSheet(context),
                      );
                    },
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
                      onTap: () => widget.onTabSwitch?.call(1),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      emoji: '🏋️',
                      label: '锻炼',
                      onTap: () => widget.onTabSwitch?.call(2),
                      isPrimary: true,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      emoji: '⚖️',
                      label: '称重',
                      onTap: () => widget.onTabSwitch?.call(3),
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
  
  void _showHubBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return const HubConnectionSheet();
      },
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
          const Text(
            '🔗 腰部 Hub 连接',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          bleState.when(
            data: (data) {
              return _buildStatusRow(data);
            },
            loading: () => _buildStatusRow(const BleDeviceState()),
            error: (_, __) => _buildStatusRow(const BleDeviceState()),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),
                  label: Text(_isScanning ? '扫描中...' : '扫描设备'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _disconnect(bleService),
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('断开连接'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '连接日志',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.text2,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildStatusRow(BleDeviceState data) {
    HubStatus status = HubStatus.disconnected;
    String statusText = '未连接';
    Color statusColor = AppColors.text2;
    
    if (data.isConnected) {
      status = HubStatus.connected;
      statusText = '已连接';
      statusColor = AppColors.green;
    } else if (_isScanning) {
      status = HubStatus.connecting;
      statusText = '扫描中...';
      statusColor = AppColors.gold;
    }
    
    return Row(
      children: [
        HubStatusDot(status: status, size: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name.isEmpty ? 'ESP32-Hub' : data.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        if (data.deviceId.isNotEmpty)
          Text(
            data.deviceId.substring(0, 8),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text2,
              fontFamily: 'monospace',
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
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }
  
  Future<void> _disconnect(BleService bleService) async {
    await bleService.disconnect();
  }
}
