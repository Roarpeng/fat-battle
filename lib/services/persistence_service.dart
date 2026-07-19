import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';

/// 持久化服务
///
/// 封装 SharedPreferences 的读写逻辑，用于将 [GameState] 持久化到本地。
/// 该服务可作为子 Provider 持久化的统一入口，便于后续扩展。
class PersistenceService {
  /// 旧版本游戏状态的存储 key（与原 [GameStateNotifier] 保持一致）
  static const String gameKey = 'fat_battle_game';

  final SharedPreferences? _prefs;

  PersistenceService(this._prefs);

  /// 是否可用
  bool get available => _prefs != null;

  /// 保存完整的 [GameState] 到本地存储
  Future<void> saveGameState(GameState state) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(gameKey, jsonEncode(state.toJson()));
  }

  /// 从本地存储加载 [GameState]
  ///
  /// 返回 null 表示没有保存过或解析失败。
  GameState? loadGameState() {
    final prefs = _prefs;
    if (prefs == null) return null;
    final saved = prefs.getString(gameKey);
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved) as Map<String, dynamic>;
      return GameState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// 清除本地存储的游戏状态
  Future<void> clearGameState() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(gameKey);
  }

  /// 通用写入方法，供子 Provider 持久化分片状态使用
  Future<void> writeString(String key, String value) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(key, value);
  }

  /// 通用读取方法，供子 Provider 持久化分片状态使用
  String? readString(String key) {
    final prefs = _prefs;
    if (prefs == null) return null;
    return prefs.getString(key);
  }

  /// 通用删除方法
  Future<void> remove(String key) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(key);
  }
}

/// 持久化服务 Provider
///
/// 默认情况下不可用（prefs 为 null），需要在 main.dart 中通过 override 注入
/// 已初始化的 [SharedPreferences] 实例。复用了 [sharedPreferencesProvider]
/// 的 prefs，避免破坏现有逻辑。
final persistenceServiceProvider = Provider<PersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PersistenceService(prefs);
});
