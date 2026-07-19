import '../constants/app_constants.dart';
import '../data/city_cuisine_packs.dart';
import '../models/food_recommend_models.dart';

/// 饮食推荐引擎：忌口过滤 → 城市包 → QuickFoods 兜底
class FoodRecommendService {
  /// 优先级：偏好忌口过滤 → 城市包 → QuickFoods 兜底
  /// [recentFoodNames]：近14天加餐名频率，用于 boost 排序
  List<QuickFood> recommend({
    required SupportedCity city,
    required MealType meal,
    required FoodPreference preference,
    Map<String, int> recentFoodNames = const {},
    int limit = 8,
  }) {
    // 城市包；national / 不支持则用 QuickFoods
    final primary = (!CityCuisinePacks.supports(city))
        ? _nationalTagged(meal)
        : CityCuisinePacks.foodsFor(city, meal);

    final filtered = _applyFilters(primary, preference);
    final ranked = _rank(filtered, preference, recentFoodNames);

    final result = <QuickFood>[];
    final seen = <String>{};

    void takeFrom(List<TaggedQuickFood> list) {
      for (final item in list) {
        if (result.length >= limit) return;
        if (!seen.add(item.name)) continue;
        result.add(item.food);
      }
    }

    takeFrom(ranked);

    // 过滤后不足：用 QuickFoods 同餐次补齐（仍过忌口过滤）
    if (result.length < limit) {
      final fallback = _rank(
        _applyFilters(_nationalTagged(meal), preference),
        preference,
        recentFoodNames,
      );
      takeFrom(fallback);
    }

    return result;
  }

  List<TaggedQuickFood> _applyFilters(
    List<TaggedQuickFood> items,
    FoodPreference preference,
  ) {
    return items.where((item) {
      if (preference.vegetarian && !item.vegetarianSafe) return false;
      if (preference.avoidTags.isNotEmpty &&
          item.tags.any(preference.avoidTags.contains)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<TaggedQuickFood> _rank(
    List<TaggedQuickFood> items,
    FoodPreference preference,
    Map<String, int> recentFoodNames,
  ) {
    final preferred = preference.preferredStaple;
    final ranked = List<TaggedQuickFood>.from(items);
    ranked.sort((a, b) {
      if (preferred != null && preferred.isNotEmpty) {
        final aMatch = a.staple == preferred ? 1 : 0;
        final bMatch = b.staple == preferred ? 1 : 0;
        if (aMatch != bMatch) return bMatch - aMatch;
      }
      final aBoost = recentFoodNames[a.name] ?? 0;
      final bBoost = recentFoodNames[b.name] ?? 0;
      if (aBoost != bBoost) return bBoost - aBoost;
      return 0;
    });
    return ranked;
  }

  List<QuickFood> _nationalList(MealType meal) => switch (meal) {
        MealType.breakfast => QuickFoods.breakfast,
        MealType.lunch => QuickFoods.lunch,
        MealType.dinner => QuickFoods.dinner,
        MealType.snack => QuickFoods.snack,
      };

  List<TaggedQuickFood> _nationalTagged(MealType meal) => _nationalList(meal)
      .map(
        (f) => TaggedQuickFood(
          food: f,
          tags: _inferTags(f.name),
          staple: _inferStaple(f.name),
          vegetarianSafe: _inferVegetarianSafe(f.name),
        ),
      )
      .toList();

  Set<FoodAvoidTag> _inferTags(String name) {
    final tags = <FoodAvoidTag>{};
    if (name.contains('奶')) tags.add(FoodAvoidTag.dairy);
    if (name.contains('油条') || name.contains('薯片')) {
      tags.add(FoodAvoidTag.fried);
    }
    if (name.contains('红烧肉')) tags.add(FoodAvoidTag.pork);
    if (name == '鱼' || name.contains('蒸鱼')) {
      tags.add(FoodAvoidTag.seafood);
    }
    return tags;
  }

  String? _inferStaple(String name) {
    if (name.contains('粥') || name.contains('豆浆')) return 'porridge';
    if (name.contains('面')) return 'noodle';
    if (name.contains('饭') ||
        name.contains('面包') ||
        name.contains('包子')) {
      return 'rice';
    }
    return null;
  }

  bool _inferVegetarianSafe(String name) {
    const meatHints = ['鸡', '肉', '鱼', '虾', '蟹', '排骨', '腿'];
    for (final h in meatHints) {
      if (name.contains(h)) return false;
    }
    return true;
  }
}
