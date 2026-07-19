import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_recommend_models.dart';

/// 饮食偏好与近期加餐频率的本地持久化。
class FoodPreferenceService {
  static const prefKey = 'food_preference_v1';
  static const recentKey = 'food_recent_names_v1';

  /// 近期加餐名字上限；超出时淘汰 count 最小的条目。
  static const int maxRecentNames = 40;

  SharedPreferences? _prefs;

  /// [prefs] 可注入便于测试；为 null 时首次读写会调用 [SharedPreferences.getInstance]。
  FoodPreferenceService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<FoodPreference> load() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) {
      return const FoodPreference();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return FoodPreference.fromJson(json);
    } catch (_) {
      return const FoodPreference();
    }
  }

  Future<void> save(FoodPreference preference) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(prefKey, jsonEncode(preference.toJson()));
  }

  /// 记录一次加餐（名字），用于推荐 boost。
  ///
  /// 每次同名 +1；名字数超过 [maxRecentNames] 时删掉 count 最小的。
  Future<void> recordFoodAdded(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final counts = await loadRecentFoodCounts();
    counts[trimmed] = (counts[trimmed] ?? 0) + 1;

    while (counts.length > maxRecentNames) {
      String? victim;
      var minCount = 1 << 30;
      counts.forEach((key, value) {
        if (key == trimmed) return;
        if (value < minCount) {
          minCount = value;
          victim = key;
        }
      });
      if (victim == null) break;
      counts.remove(victim);
    }

    final prefs = await _ensurePrefs();
    await prefs.setString(recentKey, jsonEncode(counts));
  }

  Future<Map<String, int>> loadRecentFoodCounts() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(recentKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, int>{};
      decoded.forEach((key, value) {
        final count = value is int
            ? value
            : (value is num ? value.toInt() : int.tryParse('$value'));
        if (count != null && count > 0) {
          result['$key'] = count;
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// 便捷：读取 → 变换 → 写回偏好。
  Future<FoodPreference> update(FoodPreference Function(FoodPreference) fn) async {
    final next = fn(await load());
    await save(next);
    return next;
  }
}
