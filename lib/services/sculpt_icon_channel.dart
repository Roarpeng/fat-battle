import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../theme/sculpt_progress.dart';

/// 桌面图标换阶段。部分启动器会缓存图标，需长按主屏或重启后才刷新。
class SculptIconChannel {
  SculptIconChannel._();

  static const MethodChannel _channel = MethodChannel('fat_battle/sculpt_icon');
  static String? _lastKey;

  /// [stage] 0..7，[line] 维纳斯/大卫。非 Android 为 no-op。
  static Future<void> setSculptIcon({
    required int stage,
    required SculptLine line,
  }) async {
    final nextStage = stage.clamp(0, 7);
    final key = '${line.name}:$nextStage';
    if (_lastKey == key) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _lastKey = key;
      return;
    }
    try {
      await _channel.invokeMethod<void>('setSculptStage', {
        'stage': nextStage,
        'line': line.name,
      });
      _lastKey = key;
    } catch (e) {
      debugPrint('[塑身工坊] setSculptIcon($key) 失败: $e');
    }
  }

  /// 兼容旧调用：只传阶段时按维纳斯线。
  static Future<void> setSculptStage(int stage) =>
      setSculptIcon(stage: stage, line: SculptLine.venus);

  @visibleForTesting
  static void resetCache() => _lastKey = null;
}
