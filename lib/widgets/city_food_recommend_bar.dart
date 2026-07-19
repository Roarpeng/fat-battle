import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/food_recommend_models.dart';
import '../services/city_location_service.dart';
import '../services/food_preference_service.dart';
import '../services/food_recommend_service.dart';

/// 餐次快捷推荐条：城市 chip + 横滑标签 + 偏好入口
class CityFoodRecommendBar extends StatefulWidget {
  final MealType meal;
  final void Function(QuickFood food) onSelect;
  final void Function(String foodName)? onAddedRecord;

  const CityFoodRecommendBar({
    super.key,
    required this.meal,
    required this.onSelect,
    this.onAddedRecord,
  });

  @override
  State<CityFoodRecommendBar> createState() => CityFoodRecommendBarState();
}

class CityFoodRecommendBarState extends State<CityFoodRecommendBar> {
  final _location = CityLocationService();
  final _prefs = FoodPreferenceService();
  final _recommend = FoodRecommendService();

  FoodPreference _preference = const FoodPreference();
  Map<String, int> _recent = {};
  CityResolveResult _cityResult = const CityResolveResult(
    city: SupportedCity.national,
    source: 'fallback',
  );
  List<QuickFood> _foods = [];
  bool _loading = true;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant CityFoodRecommendBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal != widget.meal) {
      _refreshFoods();
    }
  }

  Future<void> _bootstrap() async {
    final pref = await _prefs.load();
    final recent = await _prefs.loadRecentFoodCounts();
    final city = await _location.resolve(preference: pref);
    if (!mounted) return;
    setState(() {
      _preference = pref;
      _recent = recent;
      _cityResult = city;
      _loading = false;
    });
    _refreshFoods();
  }

  void _refreshFoods() {
    final list = _recommend.recommend(
      city: _cityResult.city,
      meal: widget.meal,
      preference: _preference,
      recentFoodNames: _recent,
      limit: 8,
    );
    setState(() => _foods = list);
  }

  Future<void> _relocate() async {
    setState(() => _locating = true);
    final result = await _location.resolveFromGps();
    await _location.cacheCity(result.city, placeName: result.rawPlaceName);
    // 重新定位时清除手动锁定，让 GPS 生效
    final updated = await _prefs.update((p) => p.copyWith(clearLockedCity: true));
    if (!mounted) return;
    setState(() {
      _preference = updated;
      _cityResult = result;
      _locating = false;
    });
    _refreshFoods();
  }

  Future<void> _openCityPicker() async {
    final chosen = await showModalBottomSheet<SupportedCity>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final cities = [
          SupportedCity.hangzhou,
          SupportedCity.xian,
          SupportedCity.chengdu,
          SupportedCity.ningbo,
          SupportedCity.national,
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择城市', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...cities.map((c) {
                final selected = c == _cityResult.city;
                return ListTile(
                  title: Text('${c.displayName} · ${c.cuisineLabel}'),
                  trailing: selected ? const Icon(Icons.check, color: AppColors.green) : null,
                  onTap: () => Navigator.pop(ctx, c),
                );
              }),
              ListTile(
                leading: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                title: const Text('使用手机定位'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _relocate();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    final updated = await _prefs.update((p) => p.copyWith(lockedCity: chosen));
    await _location.cacheCity(chosen);
    if (!mounted) return;
    setState(() {
      _preference = updated;
      _cityResult = CityResolveResult(
        city: chosen,
        source: 'locked',
        rawPlaceName: chosen.displayName,
      );
    });
    _refreshFoods();
  }

  Future<void> _openPreferenceSheet() async {
    var draft = _preference;
    final saved = await showModalBottomSheet<FoodPreference>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('饮食偏好', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('素食优先'),
                      value: draft.vegetarian,
                      onChanged: (v) => setModal(() => draft = draft.copyWith(vegetarian: v)),
                    ),
                    const Text('忌口', style: TextStyle(fontSize: 13, color: AppColors.text2)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FoodAvoidTag.values.map((tag) {
                        final on = draft.avoidTags.contains(tag);
                        return FilterChip(
                          label: Text(tag.label),
                          selected: on,
                          onSelected: (sel) {
                            setModal(() {
                              final next = {...draft.avoidTags};
                              if (sel) {
                                next.add(tag);
                              } else {
                                next.remove(tag);
                              }
                              draft = draft.copyWith(avoidTags: next);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('主食偏好', style: TextStyle(fontSize: 13, color: AppColors.text2)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ('rice', '米'),
                        ('noodle', '面'),
                        ('porridge', '粥'),
                        (null, '不限'),
                      ].map((e) {
                        final selected = draft.preferredStaple == e.$1 ||
                            (e.$1 == null && draft.preferredStaple == null);
                        return ChoiceChip(
                          label: Text(e.$2),
                          selected: selected,
                          onSelected: (_) => setModal(() {
                            draft = e.$1 == null
                                ? draft.copyWith(clearPreferredStaple: true)
                                : draft.copyWith(preferredStaple: e.$1);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, draft.copyWith(onboardingDone: true)),
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == null) return;
    await _prefs.save(saved);
    if (!mounted) return;
    setState(() => _preference = saved);
    _refreshFoods();
  }

  String get _chipLabel {
    final c = _cityResult.city;
    final src = switch (_cityResult.source) {
      'gps' => '定位',
      'locked' => '手动',
      'cache' => '缓存',
      _ => '默认',
    };
    return '${c.displayName} · ${c.cuisineLabel} · $src';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: _openCityPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_locating)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      else
                        const Text('📍', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _chipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openPreferenceSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('偏好', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _foods.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final food = _foods[index];
              return GestureDetector(
                onTap: () {
                  widget.onSelect(food);
                  widget.onAddedRecord?.call(food.name);
                  _prefs.recordFoodAdded(food.name).then((_) async {
                    final recent = await _prefs.loadRecentFoodCounts();
                    if (!mounted) return;
                    setState(() => _recent = recent);
                    _refreshFoods();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${food.name} ${food.cal}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
