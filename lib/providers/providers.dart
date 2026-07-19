/// Providers barrel 文件
///
/// 统一导出所有 Provider，方便业务代码一行导入：
/// ```dart
/// import 'package:fat_battle/providers/providers.dart';
/// ```
///
/// 拆分说明（对齐 Web 端 `store/slices/`）：
/// - [gameStateProvider]：聚合 Provider，保留旧 API，组合所有状态（向后兼容）
/// - [userProvider]：用户档案与偏好设置
/// - [monsterProvider]：怪物战斗状态
/// - [dailyProvider]：每日战斗记录与体力
/// - [progressProvider]：等级/经验/金币/连续打卡/护盾/成就解锁
/// - [achievementProvider]：成就定义与解锁进度
/// - [inventoryProvider]：物品栏（道具/装备/数量）
/// - [companionProvider]：战斗宠物
library;

export 'game_provider.dart';
export 'user_provider.dart';
export 'monster_provider.dart';
export 'daily_provider.dart';
export 'progress_provider.dart';
export 'achievement_provider.dart';
export 'inventory_provider.dart';
export 'companion_provider.dart';
