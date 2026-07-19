/// 游戏核心逻辑共享层 —— 双端（Web/Flutter）行为一致性基准。
///
/// 所有导出函数均为纯函数：无副作用、不依赖外部状态、相同输入产生相同输出。
///
/// 此文件为 `lib/core/` 目录的统一导出入口，对应 Web 端
/// `web/src/core/index.ts`，使用方只需导入 `package:fat_battle/core/barrel.dart`
/// 即可访问全部核心逻辑层 API。
///
/// 导出模块顺序与 Web 端 `index.ts` 对齐，额外导出 `core_types.dart`
/// （类型基准）与 `exercise_quality.dart` （运动质量评分，Web 端独立引入）。
library;

export 'core_types.dart';
export 'damage.dart';
export 'progression.dart';
export 'monster.dart';
export 'difficulty.dart';
export 'streak.dart';
export 'calories.dart';
export 'weight.dart';
export 'exercise_quality.dart';
