import 'package:flutter/material.dart';
import '../theme/forge_theme.dart';
import '../theme/forge_routes.dart';
import '../theme/tokens.dart';
import '../constants/app_constants.dart';
import '../models/food_recommend_models.dart';
import '../services/city_location_service.dart';
import '../services/food_preference_service.dart';
import '../services/food_recommend_service.dart';
import 'forge_pressable.dart';

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
  TextStyle get _displayStyle => AppFonts.display(
        color: AppColors.text,
        fontWeight: FontWeight.w600,
      );

  TextStyle get _bodyStyle => AppFonts.body(color: AppColors.text);

  TextStyle get _mutedStyle =>
      AppFonts.body(color: AppColors.text2, fontSize: 12);

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

  /// 供父组件在外部加餐后刷新近期偏好排序
  Future<void> refreshRecent() async {
    final recent = await _prefs.loadRecentFoodCounts();
    if (!mounted) return;
    setState(() => _recent = recent);
    _refreshFoods();
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
    final chosen = await showForgeSheet<SupportedCity>(
      context: context,
      isScrollControlled: false,
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
              Padding(
                padding: AppSpace.card,
                child: Text(
                  '选择城市',
                  style: _displayStyle.copyWith(fontSize: 17),
                ),
              ),
              ...cities.map((c) {
                final selected = c == _cityResult.city;
                return ListTile(
                  title: Text(
                    '${c.displayName} · ${c.cuisineLabel}',
                    style: _bodyStyle,
                  ),
                  trailing: selected
                      ? Icon(Icons.check, color: AppColors.copper)
                      : null,
                  onTap: () => Navigator.pop(ctx, c),
                );
              }),
              ListTile(
                leading: _locating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.copper,
                        ),
                      )
                    : Icon(Icons.my_location, color: AppColors.copper),
                title: Text('使用手机定位', style: _bodyStyle),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _relocate();
                },
              ),
              const SizedBox(height: AppSpace.sm),
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
    final saved = await showForgeSheet<FoodPreference>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpace.lg,
                right: AppSpace.lg,
                top: AppSpace.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpace.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('饮食偏好', style: _displayStyle.copyWith(fontSize: 17)),
                    const SizedBox(height: AppSpace.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('素食优先', style: _bodyStyle),
                      activeTrackColor: AppColors.copper.withValues(alpha: 0.35),
                      activeThumbColor: AppColors.copper,
                      value: draft.vegetarian,
                      onChanged: (v) => setModal(() => draft = draft.copyWith(vegetarian: v)),
                    ),
                    Text('忌口', style: _mutedStyle),
                    const SizedBox(height: AppSpace.xs + 2),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: FoodAvoidTag.values.map((tag) {
                        final on = draft.avoidTags.contains(tag);
                        return FilterChip(
                          label: Text(tag.label, style: _bodyStyle.copyWith(fontSize: 13)),
                          selected: on,
                          selectedColor: AppColors.ember.withValues(alpha: 0.22),
                          checkmarkColor: AppColors.copper,
                          backgroundColor: AppColors.bg2,
                          side: BorderSide(
                            color: on ? AppColors.copper : AppColors.border,
                          ),
                          labelStyle: _bodyStyle.copyWith(
                            fontSize: 13,
                            color: on ? AppColors.copper : AppColors.text,
                          ),
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
                    const SizedBox(height: AppSpace.md),
                    Text('主食偏好', style: _mutedStyle),
                    const SizedBox(height: AppSpace.xs + 2),
                    Wrap(
                      spacing: AppSpace.sm,
                      children: [
                        ('rice', '米'),
                        ('noodle', '面'),
                        ('porridge', '粥'),
                        (null, '不限'),
                      ].map((e) {
                        final selected = draft.preferredStaple == e.$1 ||
                            (e.$1 == null && draft.preferredStaple == null);
                        return ChoiceChip(
                          label: Text(e.$2, style: _bodyStyle.copyWith(fontSize: 13)),
                          selected: selected,
                          selectedColor: AppColors.copper.withValues(alpha: 0.22),
                          backgroundColor: AppColors.bg2,
                          side: BorderSide(
                            color: selected ? AppColors.copper : AppColors.border,
                          ),
                          labelStyle: _bodyStyle.copyWith(
                            fontSize: 13,
                            color: selected ? AppColors.copper : AppColors.text,
                          ),
                          onSelected: (_) => setModal(() {
                            draft = e.$1 == null
                                ? draft.copyWith(clearPreferredStaple: true)
                                : draft.copyWith(preferredStaple: e.$1);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpace.lg),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: LinearProgressIndicator(
          minHeight: 2,
          color: AppColors.copper,
          backgroundColor: AppColors.border,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: ForgePressable(
                onTap: _openCityPicker,
                borderRadius: AppRadii.mdAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: AppRadii.mdAll,
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_locating)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.copper,
                          ),
                        )
                      else
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.copper),
                      const SizedBox(width: AppSpace.xs),
                      Flexible(
                        child: Text(
                          _chipLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle.copyWith(fontSize: 12),
                        ),
                      ),
                      Icon(Icons.expand_more, size: 16, color: AppColors.copper),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            ForgePressable(
              onTap: _openPreferenceSheet,
              borderRadius: AppRadii.mdAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_outlined, size: 14, color: AppColors.copper),
                    const SizedBox(width: AppSpace.xs),
                    Text('偏好', style: _bodyStyle.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _foods.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppSpace.xs + 2),
            itemBuilder: (context, index) {
              final food = _foods[index];
              return ForgePressable(
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
                borderRadius: AppRadii.mdAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: AppRadii.mdAll,
                    border: Border.all(
                      color: AppColors.copper.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '${food.name} ${food.cal}',
                    style: _bodyStyle.copyWith(fontSize: 12),
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
