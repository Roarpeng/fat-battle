import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/core/calories.dart';
import 'package:fat_battle/core/coach_safety.dart';
import 'package:fat_battle/core/core_types.dart';
import 'package:fat_battle/models/game_models.dart';
import 'package:fat_battle/providers/game_provider.dart';

void main() {
  group('CoachSafety.filter', () {
    const floor = 1500;

    test('allows grounded remaining-budget advice', () {
      final r = CoachSafety.filter('今天预算还剩 420 kcal，蛋白质再补一块鸡胸。', floor: floor);
      expect(r.filtered, isFalse);
    });

    test('blocks purging', () {
      expect(CoachSafety.filter('吃完催吐就不会长胖。', floor: floor).filtered, isTrue);
    });

    test('blocks punitive fasting', () {
      expect(CoachSafety.filter('惩罚性禁食一天。', floor: floor).filtered, isTrue);
    });

    test('blocks skip-meals-to-beat-boss', () {
      expect(CoachSafety.filter('跳过晚餐去打 Boss 吧。', floor: floor).filtered, isTrue);
    });

    test('blocks changing calorie goal', () {
      expect(CoachSafety.filter('把目标改成 800 千卡。', floor: floor).filtered, isTrue);
    });

    test('blocks below-floor daily calories', () {
      final r = CoachSafety.filter('每天只吃 800 千卡就能瘦。', floor: floor);
      expect(r.filtered, isTrue);
      expect(r.text, contains('1500'));
    });

    test('allows per-meal estimate below floor', () {
      final r = CoachSafety.filter('这顿红烧肉大约 350 kcal，按 120g 记。', floor: floor);
      expect(r.filtered, isFalse);
    });
  });

  test('calorieFloor uses conservative default without gender', () {
    expect(CoachSafety.calorieFloor(), defaultCalorieFloor);
    expect(CoachSafety.calorieFloor(gender: Gender.female), 1200);
    expect(CoachSafety.calorieFloor(gender: Gender.male), 1500);
  });

  test('protein estimate from logged foods', () {
    final foods = [
      const FoodItem(name: '鸡胸肉', baseCal: 165, totalCal: 165, meal: MealType.lunch, grams: 100),
      const FoodItem(name: '米饭', baseCal: 116, totalCal: 116, meal: MealType.lunch, grams: 100),
    ];
    final p = estimateLoggedProtein(foods);
    expect(p, closeTo(31 + 2.6, 0.2));
    expect(proteinTargetGrams(70), closeTo(112, 0.1));
  });

  test('local answers stay grounded and do not write logs', () {
    const gs = GameState(
      targetCal: 1800,
      todayCalIn: 600,
      todayCalExercise: 100,
      lastDate: '2026-08-13',
    );
    final ctx = CoachTurnContext.fromGameState(gs);
    expect(ctx.budget['remainingCal'], 1300);
    final remain = ctx.localAnswer('今天预算还剩多少');
    expect(remain, contains('1300'));
    expect(remain, isNot(contains('已记入')));
    final protein = ctx.localAnswer('蛋白质够不够');
    expect(protein, contains('蛋白质'));
    expect(protein, contains('偷偷记账'));
    final how = ctx.localAnswer('这顿怎么记');
    expect(how, contains('克数'));
    expect(how, isNot(contains('已帮你记')));
    final eat = ctx.localAnswer('剩余预算吃什么');
    expect(eat, contains('确认'));
  });

  test('proposed log converts grams to calories without auto-applying', () {
    const log = CoachProposedLog(
      name: '鸡胸肉',
      grams: 120,
      caloriePer100g: 165,
      meal: MealType.lunch,
    );
    expect(log.estimatedCal, 198);
    final item = log.toFoodItem();
    expect(item.grams, 120);
    expect(item.totalCal, 198);
  });
}
