import '../constants/app_constants.dart';
import '../models/food_recommend_models.dart';

/// 杭州 / 西安 / 成都 / 宁波 城市菜系快捷包（按餐次）
class CityCuisinePacks {
  static bool supports(SupportedCity city) => city != SupportedCity.national;

  static List<TaggedQuickFood> foodsFor(SupportedCity city, MealType meal) {
    final pack = _packs[city];
    if (pack == null) return const [];
    return List.unmodifiable(pack[meal] ?? const []);
  }

  static final Map<SupportedCity, Map<MealType, List<TaggedQuickFood>>> _packs = {
    SupportedCity.hangzhou: _hangzhou,
    SupportedCity.xian: _xian,
    SupportedCity.chengdu: _chengdu,
    SupportedCity.ningbo: _ningbo,
  };

  // —— 杭州 · 杭帮 ——
  static final Map<MealType, List<TaggedQuickFood>> _hangzhou = {
    MealType.breakfast: [
      TaggedQuickFood(food: QuickFood(name: '豆浆油条', cal: 320), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '小笼包', cal: 280), tags: {FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '定胜糕', cal: 180), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '葱包烩', cal: 350), tags: {FoodAvoidTag.pork, FoodAvoidTag.fried}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '片儿川', cal: 420), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '藕粉', cal: 120), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '茶叶蛋', cal: 90), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '白粥配酱瓜', cal: 160), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '粢饭团', cal: 300), staple: 'rice', vegetarianSafe: true),
    ],
    MealType.lunch: [
      TaggedQuickFood(food: QuickFood(name: '西湖牛肉羹', cal: 220), tags: {FoodAvoidTag.beef}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '龙井虾仁', cal: 280), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '东坡肉', cal: 480), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '宋嫂鱼羹', cal: 240), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '西湖醋鱼', cal: 320), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '片儿川', cal: 420), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '叫花鸡', cal: 450), staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '干炸响铃', cal: 260), tags: {FoodAvoidTag.pork, FoodAvoidTag.fried}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '油焖笋', cal: 150), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '虾爆鳝面', cal: 480), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
    ],
    MealType.dinner: [
      TaggedQuickFood(food: QuickFood(name: '东坡肉', cal: 480), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '西湖醋鱼', cal: 320), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '叫花鸡', cal: 450), staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '龙井虾仁', cal: 280), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '宋嫂鱼羹', cal: 240), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '西湖牛肉羹', cal: 220), tags: {FoodAvoidTag.beef}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '笋干老鸭煲', cal: 380), staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '蜜汁火方', cal: 420), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '清汤鱼圆', cal: 200), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '荠菜冬笋', cal: 90), vegetarianSafe: true),
    ],
    MealType.snack: [
      TaggedQuickFood(food: QuickFood(name: '定胜糕', cal: 180), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '藕粉', cal: 120), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '桂花糕', cal: 160), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '龙井茶酥', cal: 200), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '条头糕', cal: 150), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '椒盐桃片', cal: 140), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '西湖藕粉羹', cal: 130), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '猫耳朵', cal: 220), staple: 'noodle', vegetarianSafe: true),
    ],
  };

  // —— 西安 · 陕味 ——
  static final Map<MealType, List<TaggedQuickFood>> _xian = {
    MealType.breakfast: [
      TaggedQuickFood(food: QuickFood(name: '肉夹馍', cal: 450), tags: {FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '胡辣汤', cal: 180), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, staple: 'porridge', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '肉丸胡辣汤', cal: 220), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, staple: 'porridge', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '甑糕', cal: 280), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '豆浆油条', cal: 320), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '凉皮', cal: 250), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '柿子饼', cal: 200), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '羊肉泡馍', cal: 520), tags: {FoodAvoidTag.lamb}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '豆腐脑', cal: 110), vegetarianSafe: true),
    ],
    MealType.lunch: [
      TaggedQuickFood(food: QuickFood(name: '肉夹馍', cal: 450), tags: {FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '凉皮', cal: 250), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '羊肉泡馍', cal: 520), tags: {FoodAvoidTag.lamb}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '油泼面', cal: 480), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: 'biangbiang面', cal: 550), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '胡辣汤', cal: 180), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, staple: 'porridge', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '羊肉串', cal: 280), tags: {FoodAvoidTag.lamb}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '臊子面', cal: 420), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '葫芦头泡馍', cal: 480), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '岐山臊子面', cal: 400), tags: {FoodAvoidTag.pork, FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: false),
    ],
    MealType.dinner: [
      TaggedQuickFood(food: QuickFood(name: '羊肉泡馍', cal: 520), tags: {FoodAvoidTag.lamb}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '油泼面', cal: 480), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: 'biangbiang面', cal: 550), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '肉夹馍', cal: 450), tags: {FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '凉皮', cal: 250), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '羊肉串', cal: 280), tags: {FoodAvoidTag.lamb}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '水盆羊肉', cal: 380), tags: {FoodAvoidTag.lamb}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '酸汤水饺', cal: 360), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '粉蒸肉', cal: 420), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '菠菜面', cal: 320), staple: 'noodle', vegetarianSafe: true),
    ],
    MealType.snack: [
      TaggedQuickFood(food: QuickFood(name: '冰峰', cal: 140), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '柿子饼', cal: 200), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '甑糕', cal: 280), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '黄桂稠酒', cal: 120), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '石子馍', cal: 180), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '蜜枣粽糕', cal: 220), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '烤红薯', cal: 160), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '杏仁茶', cal: 100), vegetarianSafe: true),
    ],
  };

  // —— 成都 · 川味 ——
  static final Map<MealType, List<TaggedQuickFood>> _chengdu = {
    MealType.breakfast: [
      TaggedQuickFood(food: QuickFood(name: '担担面', cal: 420), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '钟水饺', cal: 320), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '龙抄手', cal: 350), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '甜水面', cal: 380), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '蛋烘糕', cal: 220), tags: {FoodAvoidTag.dairy}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '叶儿粑', cal: 180), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '豆浆油条', cal: 320), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '肥肠粉', cal: 400), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '小笼包', cal: 280), tags: {FoodAvoidTag.pork}, vegetarianSafe: false),
    ],
    MealType.lunch: [
      TaggedQuickFood(food: QuickFood(name: '夫妻肺片', cal: 380), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '冒菜', cal: 450), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '火锅冒菜简版', cal: 520), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '担担面', cal: 420), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '钵钵鸡', cal: 360), tags: {FoodAvoidTag.spicy}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '蒜泥白肉', cal: 340), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '钟水饺', cal: 320), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '龙抄手', cal: 350), tags: {FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '回锅肉', cal: 480), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '麻婆豆腐', cal: 280), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, staple: 'rice', vegetarianSafe: false),
    ],
    MealType.dinner: [
      TaggedQuickFood(food: QuickFood(name: '冒菜', cal: 450), tags: {FoodAvoidTag.spicy}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '火锅冒菜简版', cal: 520), tags: {FoodAvoidTag.spicy}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '夫妻肺片', cal: 380), tags: {FoodAvoidTag.spicy, FoodAvoidTag.beef}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '钵钵鸡', cal: 360), tags: {FoodAvoidTag.spicy}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '蒜泥白肉', cal: 340), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '水煮鱼', cal: 420), tags: {FoodAvoidTag.spicy, FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '宫保鸡丁', cal: 360), tags: {FoodAvoidTag.spicy}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '鱼香茄子', cal: 240), tags: {FoodAvoidTag.spicy}, staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '酸菜鱼', cal: 400), tags: {FoodAvoidTag.spicy, FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '担担面', cal: 420), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
    ],
    MealType.snack: [
      TaggedQuickFood(food: QuickFood(name: '蛋烘糕', cal: 220), tags: {FoodAvoidTag.dairy}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '冰粉', cal: 80), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '赖汤圆', cal: 280), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '三大炮', cal: 200), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '糖油果子', cal: 260), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '肥肠粉小份', cal: 280), tags: {FoodAvoidTag.spicy, FoodAvoidTag.pork}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '凉糕', cal: 150), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '红糖糍粑', cal: 240), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
    ],
  };

  // —— 宁波 · 甬帮 ——
  static final Map<MealType, List<TaggedQuickFood>> _ningbo = {
    MealType.breakfast: [
      TaggedQuickFood(food: QuickFood(name: '宁波汤团', cal: 320), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '酒酿圆子', cal: 240), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '年糕', cal: 200), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '豆浆油条', cal: 320), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '海鲜面', cal: 420), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '黄鱼面', cal: 400), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '白粥配咸齑', cal: 150), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '豆酥糖', cal: 160), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '粢饭糕', cal: 260), tags: {FoodAvoidTag.fried}, staple: 'rice', vegetarianSafe: true),
    ],
    MealType.lunch: [
      TaggedQuickFood(food: QuickFood(name: '海鲜面', cal: 420), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '红膏炝蟹', cal: 280), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '黄鱼面', cal: 400), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '雪菜黄鱼', cal: 320), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '烤鱿鱼', cal: 240), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '宁波汤团', cal: 320), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '年糕炒肉丝', cal: 380), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '苔条花生', cal: 200), tags: {FoodAvoidTag.seafood}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '清蒸黄鱼', cal: 260), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '油炸臭豆腐', cal: 220), tags: {FoodAvoidTag.fried}, vegetarianSafe: true),
    ],
    MealType.dinner: [
      TaggedQuickFood(food: QuickFood(name: '雪菜黄鱼', cal: 320), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '红膏炝蟹', cal: 280), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '海鲜面', cal: 420), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '黄鱼面', cal: 400), tags: {FoodAvoidTag.seafood}, staple: 'noodle', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '烤鱿鱼', cal: 240), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '酒酿圆子', cal: 240), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '梅干菜烧肉', cal: 450), tags: {FoodAvoidTag.pork}, staple: 'rice', vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '咸齑黄鱼汤', cal: 180), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '炒年糕', cal: 300), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '清蒸带鱼', cal: 280), tags: {FoodAvoidTag.seafood}, staple: 'rice', vegetarianSafe: false),
    ],
    MealType.snack: [
      TaggedQuickFood(food: QuickFood(name: '汤圆', cal: 280), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '豆酥糖', cal: 160), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '酒酿圆子', cal: 240), staple: 'porridge', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '烤鱿鱼', cal: 240), tags: {FoodAvoidTag.seafood}, vegetarianSafe: false),
      TaggedQuickFood(food: QuickFood(name: '年糕片', cal: 180), staple: 'rice', vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '海苔花生', cal: 190), tags: {FoodAvoidTag.seafood}, vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '杏仁饼', cal: 150), vegetarianSafe: true),
      TaggedQuickFood(food: QuickFood(name: '水磨年糕糖', cal: 170), vegetarianSafe: true),
    ],
  };
}
