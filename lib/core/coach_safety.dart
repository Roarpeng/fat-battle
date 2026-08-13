import '../constants/app_constants.dart';
import '../core/calories.dart';
import '../core/core_types.dart';
import '../models/game_models.dart';
import '../providers/game_provider.dart';

/// 工坊教练安全规则与本地接地气回答（与后端 filter 对齐）。
class CoachSafety {
  CoachSafety._();

  static const int defaultFloor = defaultCalorieFloor;

  static final _purge = RegExp(
    r'催吐|抠喉|催泻|泻药|灌肠|导泻|清肠液|利尿剂|purging|laxative|ipecac',
    caseSensitive: false,
  );
  static final _fast = RegExp(
    r'惩罚性禁食|禁食惩罚|绝食|辟谷|饿到发昏|空腹一天|禁食一天|starve(\s*yourself)?|punitive\s*fast',
    caseSensitive: false,
  );
  static final _skipBoss = RegExp(
    r'跳过.{0,6}(早|午|晚)?餐.{0,8}(打|击败|打爆|打怪|boss|怪物)|不吃.{0,6}(早|午|晚)?餐.{0,8}(打|击败|boss|怪物)|skip\s+meals?\s+to\s+(beat|kill)|空腹打(怪|boss)',
    caseSensitive: false,
  );
  static final _changeGoal = RegExp(
    r'(把|将).{0,8}(目标|预算|下限|floor).{0,6}(改|调|设|降)|改(成|到).{0,4}(目标|预算)|calorie\s*goal.{0,8}(change|set|lower)',
    caseSensitive: false,
  );
  static final _dailyCal = RegExp(
    r'(每天|每日|全日|全天|一天|目标|只吃|控制在).{0,12}(\d{3,4})\s*(千卡|kcal|大卡)',
    caseSensitive: false,
  );

  static int calorieFloor({Gender? gender}) =>
      gender == null ? defaultFloor : safeMinCalories(gender);

  static String fallback(int floor) =>
      '工坊教练不会建议把全日摄入压到 $floor kcal 以下，也不会用禁食、催吐或跳过正餐去打怪。'
      '按你现在的目标吃饭、把蛋白质凑够，饿了就记一餐——打怪靠控制加餐和锤炼，不是靠挨饿。';

  /// 过滤模型输出。命中违禁则替换。
  static CoachFilterResult filter(String reply, {required int floor}) {
    final text = reply.trim();
    if (text.isEmpty) {
      return CoachFilterResult(text: fallback(floor), filtered: true);
    }
    if (_purge.hasMatch(text) ||
        _fast.hasMatch(text) ||
        _skipBoss.hasMatch(text) ||
        _changeGoal.hasMatch(text) ||
        _dailyBelowFloor(text, floor)) {
      return CoachFilterResult(text: fallback(floor), filtered: true);
    }
    return CoachFilterResult(text: text, filtered: false);
  }

  static bool _dailyBelowFloor(String text, int floor) {
    for (final m in _dailyCal.allMatches(text)) {
      final n = int.tryParse(m.group(2) ?? '') ?? 0;
      if (n > 0 && n < floor) return true;
    }
    return false;
  }
}

class CoachFilterResult {
  final String text;
  final bool filtered;
  const CoachFilterResult({required this.text, required this.filtered});
}

/// 常见食物每 100g 蛋白质粗估（克）。未命中则按 5g 保守估计。
const Map<String, double> kProteinPer100g = {
  '鸡胸': 31,
  '鸡肉': 27,
  '鸡蛋': 13,
  '蛋': 13,
  '牛肉': 26,
  '猪肉': 20,
  '鱼': 20,
  '虾': 24,
  '豆腐': 8,
  '豆浆': 3,
  '牛奶': 3.3,
  '酸奶': 5,
  '米饭': 2.6,
  '馒头': 7,
  '面包': 8,
  '面条': 7,
  '坚果': 15,
  '豆': 20,
  '蔬菜': 2,
  '青菜': 2,
  '水果': 0.5,
  '奶茶': 1,
  '可乐': 0,
};

double proteinPer100gFor(String name) {
  for (final e in kProteinPer100g.entries) {
    if (name.contains(e.key)) return e.value;
  }
  return 5;
}

/// 蛋白质目标：减脂期约 1.6 g/kg。
double proteinTargetGrams(double weightKg) =>
    (weightKg <= 0 ? 70 : weightKg) * 1.6;

double estimateLoggedProtein(Iterable<FoodItem> foods) {
  var total = 0.0;
  for (final f in foods) {
    final grams = f.grams ??
        (f.baseCal > 0 ? (f.totalCal / f.baseCal * 100).round() : 100);
    total += proteinPer100gFor(f.name) * grams / 100.0;
  }
  return total;
}

String fitnessLevelLabel(FitnessLevel level) => switch (level) {
      FitnessLevel.low => '低',
      FitnessLevel.medium => '中',
      FitnessLevel.high => '高',
    };

/// 从 GameState 抽出教练只读上下文。
class CoachTurnContext {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> budget;
  final Map<String, dynamic> monster;
  final List<Map<String, dynamic>> meals;
  final List<Map<String, dynamic>> exercises;
  final int calorieFloor;
  final double proteinLogged;
  final double proteinTarget;

  const CoachTurnContext({
    required this.profile,
    required this.budget,
    required this.monster,
    required this.meals,
    required this.exercises,
    required this.calorieFloor,
    required this.proteinLogged,
    required this.proteinTarget,
  });

  factory CoachTurnContext.fromGameState(GameState gs, {Gender? gender}) {
    final floor = CoachSafety.calorieFloor(gender: gender);
    final foods = gs.meals.values.expand((e) => e);
    final protein = estimateLoggedProtein(foods);
    final meals = <Map<String, dynamic>>[];
    gs.meals.forEach((meal, items) {
      for (final f in items) {
        meals.add({
          'name': f.name,
          'totalCal': f.totalCal,
          'meal': meal.name,
          'grams': f.grams ?? 0,
        });
      }
    });
    return CoachTurnContext(
      profile: {
        'nickname': gs.user.nickname,
        'height': gs.user.height,
        'weight': gs.user.weight,
        'targetWeight': gs.user.targetWeight,
        'bmi': gs.user.bmi,
        'sleepType': gs.user.sleepType.name,
        'workType': gs.user.workType.name,
        'exerciseTime': gs.user.exerciseTime.name,
        'fitnessLevel': fitnessLevelLabel(gs.fitnessLevel),
        'difficulty': gs.difficulty.name,
        'pushupCount': gs.user.pushupCount,
        'runDuration': gs.user.runDuration,
        'weeklyFreq': gs.user.weeklyFreq,
      },
      budget: {
        'targetCal': gs.targetCal,
        'calorieFloor': floor,
        'todayCalIn': gs.todayCalIn,
        'todayCalExercise': gs.todayCalExercise,
        'remainingCal': gs.remainingCal,
      },
      monster: {
        'name': gs.monster.name,
        'hp': gs.monster.hp,
        'maxHp': gs.monster.maxHp,
        'shield': gs.monster.shield,
      },
      meals: meals,
      exercises: gs.exercises
          .map((e) => {
                'name': e.name,
                'duration': e.duration,
                'cal': e.cal,
              })
          .toList(),
      calorieFloor: floor,
      proteinLogged: protein,
      proteinTarget: proteinTargetGrams(gs.user.weight),
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile,
        'budget': budget,
        'monster': monster,
        'meals': meals,
        'exercises': exercises,
      };

  /// 后端不可用时的接地气本地回答（不改目标、不记账）。
  String localAnswer(String message) {
    final remaining = budget['remainingCal'] as int;
    final target = budget['targetCal'] as int;
    final eaten = budget['todayCalIn'] as int;
    final burn = budget['todayCalExercise'] as int;
    final hp = monster['hp'];
    final shield = monster['shield'];
    final name = monster['name'];

    if (message.contains('吃什么') || message.contains('剩余预算')) {
      if (remaining <= 0) {
        return '今天预算已经用完（超出 ${-remaining} kcal）。下一餐选高蛋白、低油的一小份，'
            '或去锤炼消耗；不要用禁食或跳过正餐打怪。确认克数后再记。';
      }
      return '还剩 $remaining kcal。优先鸡胸、蛋、豆腐、青菜这类好估克数的。'
          '选一样后改克数、看估算，点确认才记入。';
    }
    if (message.contains('蛋白')) {
      final logged = proteinLogged.round();
      final need = proteinTarget.round();
      final gap = (need - logged).clamp(0, 999);
      if (gap == 0) {
        return '按体重粗估，今日蛋白质大约 $logged g，已经够 $need g 的目标。继续把正餐吃完整就行。';
      }
      return '按体重粗估目标约 $need g 蛋白质，今天账上大约 $logged g，还差约 $gap g。'
          '一块鸡胸或几个蛋就能补上——记入手动确认，我不会偷偷记账。';
    }
    if (message.contains('怎么记') || message.contains('这顿')) {
      return '这顿先估：菜名 + 克数 + 每 100g 千卡。拍一张或搜名称，改克数后点确认才会记入。'
          '我不会改卡路里目标，也不会替你写日志。';
    }
    if (message.contains('预算') && message.contains('剩')) {
      final over = remaining < 0;
      final extra = burn > 0 ? '今日锤炼已烧掉 $burn kcal。' : '今天还没锤炼。';
      return over
          ? '工坊目标 $target kcal，已记 $eaten kcal，超出 ${-remaining} kcal。'
              '$name 护盾 $shield、HP $hp。$extra 下一餐往蛋白质靠，别靠跳过正餐破盾。'
          : '工坊目标 $target kcal，已记 $eaten kcal，还剩 $remaining kcal。'
              '$name HP $hp/${monster['maxHp']}，护盾 $shield。$extra '
              '安全下限 $calorieFloor kcal，我不会改你的目标。';
    }
    return '我只看你今天的饮食账、剩余预算和锤炼。问「今天预算还剩多少」「蛋白质够不够」或「这顿怎么记」就行。'
        '目标 $target kcal 我不会改。';
  }
}

class CoachProposedLog {
  final String name;
  final int grams;
  final int caloriePer100g;
  final int proteinPer100g;
  final MealType meal;

  const CoachProposedLog({
    required this.name,
    required this.grams,
    required this.caloriePer100g,
    this.proteinPer100g = 0,
    this.meal = MealType.lunch,
  });

  int get estimatedCal => (caloriePer100g * grams / 100).round();

  factory CoachProposedLog.fromJson(Map<String, dynamic> json) {
    MealType meal = MealType.lunch;
    final raw = json['meal']?.toString() ?? 'lunch';
    for (final m in MealType.values) {
      if (m.name == raw || m.toString().split('.').last == raw) {
        meal = m;
        break;
      }
    }
    return CoachProposedLog(
      name: json['name']?.toString() ?? '',
      grams: int.tryParse('${json['grams'] ?? 100}') ?? 100,
      caloriePer100g: int.tryParse('${json['caloriePer100g'] ?? 0}') ?? 0,
      proteinPer100g: int.tryParse('${json['proteinPer100g'] ?? 0}') ?? 0,
      meal: meal,
    );
  }

  CoachProposedLog copyWith({int? grams, String? name, MealType? meal}) {
    return CoachProposedLog(
      name: name ?? this.name,
      grams: grams ?? this.grams,
      caloriePer100g: caloriePer100g,
      proteinPer100g: proteinPer100g,
      meal: meal ?? this.meal,
    );
  }

  FoodItem toFoodItem() => FoodItem(
        name: name,
        baseCal: caloriePer100g,
        size: FoodSize.medium,
        totalCal: estimatedCal,
        meal: meal,
        grams: grams,
      );
}

class CoachTurnResult {
  final String reply;
  final bool filtered;
  final List<CoachProposedLog> proposedLogs;
  final bool fromLocal;

  const CoachTurnResult({
    required this.reply,
    this.filtered = false,
    this.proposedLogs = const [],
    this.fromLocal = false,
  });
}
