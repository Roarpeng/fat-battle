import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/food_recommend_models.dart';
import '../services/food_preference_service.dart';
import 'game_provider.dart';

/// 饮食推荐相关本地状态（偏好 + 近期加餐计数）。
class FoodRecommendState {
  final FoodPreference preference;
  final Map<String, int> recentCounts;
  final bool loaded;

  const FoodRecommendState({
    this.preference = const FoodPreference(),
    this.recentCounts = const {},
    this.loaded = false,
  });

  FoodRecommendState copyWith({
    FoodPreference? preference,
    Map<String, int>? recentCounts,
    bool? loaded,
  }) {
    return FoodRecommendState(
      preference: preference ?? this.preference,
      recentCounts: recentCounts ?? this.recentCounts,
      loaded: loaded ?? this.loaded,
    );
  }
}

final foodPreferenceServiceProvider = Provider<FoodPreferenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FoodPreferenceService(prefs: prefs);
});

class FoodRecommendNotifier extends StateNotifier<FoodRecommendState> {
  FoodRecommendNotifier(this._service) : super(const FoodRecommendState()) {
    refresh();
  }

  final FoodPreferenceService _service;

  Future<void> refresh() async {
    final preference = await _service.load();
    final recentCounts = await _service.loadRecentFoodCounts();
    state = FoodRecommendState(
      preference: preference,
      recentCounts: Map.unmodifiable(recentCounts),
      loaded: true,
    );
  }

  Future<void> save(FoodPreference preference) async {
    await _service.save(preference);
    state = state.copyWith(preference: preference, loaded: true);
  }

  Future<FoodPreference> update(FoodPreference Function(FoodPreference) fn) async {
    final next = await _service.update(fn);
    state = state.copyWith(preference: next, loaded: true);
    return next;
  }

  Future<void> recordFoodAdded(String name) async {
    await _service.recordFoodAdded(name);
    final recentCounts = await _service.loadRecentFoodCounts();
    state = state.copyWith(
      recentCounts: Map.unmodifiable(recentCounts),
      loaded: true,
    );
  }

  /// 城市解析占位：仅使用锁定城市，不依赖 CityLocationService。
  ///
  /// 后续可接入 GPS / 缓存解析，替换此实现。
  CityResolveResult resolveCity() {
    final locked = state.preference.lockedCity;
    if (locked != null) {
      return CityResolveResult(
        city: locked,
        source: 'locked',
        rawPlaceName: locked.displayName,
        fromGps: false,
      );
    }
    return const CityResolveResult(
      city: SupportedCity.national,
      source: 'fallback',
      fromGps: false,
    );
  }
}

final foodPreferenceProvider =
    StateNotifierProvider<FoodRecommendNotifier, FoodRecommendState>((ref) {
  final service = ref.watch(foodPreferenceServiceProvider);
  return FoodRecommendNotifier(service);
});
