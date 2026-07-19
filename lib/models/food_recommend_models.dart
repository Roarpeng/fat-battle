import '../constants/app_constants.dart';

/// 支持城市菜系推荐的城市（MVP）
enum SupportedCity {
  hangzhou,
  xian,
  chengdu,
  ningbo,
  /// 全国通用兜底（现有 QuickFoods）
  national,
}

extension SupportedCityX on SupportedCity {
  String get displayName => switch (this) {
        SupportedCity.hangzhou => '杭州',
        SupportedCity.xian => '西安',
        SupportedCity.chengdu => '成都',
        SupportedCity.ningbo => '宁波',
        SupportedCity.national => '全国',
      };

  String get cuisineLabel => switch (this) {
        SupportedCity.hangzhou => '杭帮',
        SupportedCity.xian => '陕味',
        SupportedCity.chengdu => '川味',
        SupportedCity.ningbo => '甬帮',
        SupportedCity.national => '常见',
      };

  /// 逆地理/手动选择用的别名
  List<String> get aliases => switch (this) {
        SupportedCity.hangzhou => ['杭州', '杭州市', 'Hangzhou'],
        SupportedCity.xian => ['西安', '西安市', "Xi'an", 'Xian', 'XiAn'],
        SupportedCity.chengdu => ['成都', '成都市', 'Chengdu'],
        SupportedCity.ningbo => ['宁波', '宁波市', 'Ningbo'],
        SupportedCity.national => ['全国', '通用'],
      };
}

/// 忌口标签（过滤用）
enum FoodAvoidTag {
  spicy('辣'),
  seafood('海鲜'),
  pork('猪肉'),
  beef('牛肉'),
  lamb('牛羊肉'),
  dairy('奶制品'),
  fried('油炸');

  final String label;
  const FoodAvoidTag(this.label);
}

/// 用户饮食偏好（本地持久化）
class FoodPreference {
  final Set<FoodAvoidTag> avoidTags;
  final bool vegetarian;
  /// 主食偏好：rice / noodle / porridge / null(不限)
  final String? preferredStaple;
  /// 手动锁定的城市（优先于 GPS）
  final SupportedCity? lockedCity;
  /// 是否完成过冷启动引导
  final bool onboardingDone;

  const FoodPreference({
    this.avoidTags = const {},
    this.vegetarian = false,
    this.preferredStaple,
    this.lockedCity,
    this.onboardingDone = false,
  });

  FoodPreference copyWith({
    Set<FoodAvoidTag>? avoidTags,
    bool? vegetarian,
    String? preferredStaple,
    bool clearPreferredStaple = false,
    SupportedCity? lockedCity,
    bool clearLockedCity = false,
    bool? onboardingDone,
  }) {
    return FoodPreference(
      avoidTags: avoidTags ?? this.avoidTags,
      vegetarian: vegetarian ?? this.vegetarian,
      preferredStaple: clearPreferredStaple
          ? null
          : (preferredStaple ?? this.preferredStaple),
      lockedCity: clearLockedCity ? null : (lockedCity ?? this.lockedCity),
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  Map<String, dynamic> toJson() => {
        'avoidTags': avoidTags.map((e) => e.name).toList(),
        'vegetarian': vegetarian,
        'preferredStaple': preferredStaple,
        'lockedCity': lockedCity?.name,
        'onboardingDone': onboardingDone,
      };

  factory FoodPreference.fromJson(Map<String, dynamic> json) {
    final tags = <FoodAvoidTag>{};
    for (final t in (json['avoidTags'] as List?) ?? const []) {
      for (final v in FoodAvoidTag.values) {
        if (v.name == t) tags.add(v);
      }
    }
    SupportedCity? locked;
    final lockedName = json['lockedCity'] as String?;
    if (lockedName != null) {
      for (final c in SupportedCity.values) {
        if (c.name == lockedName) locked = c;
      }
    }
    return FoodPreference(
      avoidTags: tags,
      vegetarian: json['vegetarian'] == true,
      preferredStaple: json['preferredStaple'] as String?,
      lockedCity: locked,
      onboardingDone: json['onboardingDone'] == true,
    );
  }
}

/// 带标签的快捷食物（用于过滤/排序）
class TaggedQuickFood {
  final QuickFood food;
  final Set<FoodAvoidTag> tags;
  final String? staple; // rice / noodle / porridge
  final bool vegetarianSafe;

  const TaggedQuickFood({
    required this.food,
    this.tags = const {},
    this.staple,
    this.vegetarianSafe = false,
  });

  String get name => food.name;
  int get cal => food.cal;
}

/// 定位解析结果
class CityResolveResult {
  final SupportedCity city;
  final String source; // gps | locked | cache | fallback
  final String? rawPlaceName;
  final bool fromGps;

  const CityResolveResult({
    required this.city,
    required this.source,
    this.rawPlaceName,
    this.fromGps = false,
  });
}
