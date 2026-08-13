import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/core/core_types.dart';
import 'package:fat_battle/core/damage.dart';
import 'package:fat_battle/models/game_models.dart';
import 'package:fat_battle/services/coach_feel.dart';
import 'package:fat_battle/services/coach_injury.dart';
import 'package:fat_battle/services/coach_lesson.dart';
import 'package:fat_battle/services/exercise_prescription.dart';

User _user({
  FitnessLevel fitness = FitnessLevel.medium,
  Difficulty difficulty = Difficulty.normal,
}) {
  return User(
    height: 170,
    weight: 70,
    targetWeight: 65,
    fitnessLevel: fitness,
    difficulty: difficulty,
  );
}

void main() {
  group('克制映射', () {
    test('三角：有氧克力量、力量克核心、核心克有氧', () {
      expect(counterCategoryOf(ExerciseCategory.strength), ExerciseCategory.cardio);
      expect(counterCategoryOf(ExerciseCategory.core), ExerciseCategory.strength);
      expect(counterCategoryOf(ExerciseCategory.cardio), ExerciseCategory.core);
    });

    test('摄像头动作归类与 web EXERCISE_CATEGORY 对齐', () {
      expect(categoryOfExercise('jumping_jack'), ExerciseCategory.cardio);
      expect(categoryOfExercise('highknee'), ExerciseCategory.cardio);
      expect(categoryOfExercise('squat'), ExerciseCategory.strength);
      expect(categoryOfExercise('pushup'), ExerciseCategory.strength);
      expect(categoryOfExercise('lunge'), ExerciseCategory.strength);
      expect(categoryOfExercise('plank'), ExerciseCategory.core);
      expect(categoryOfExercise('mountainclimber'), ExerciseCategory.core);
    });

    test('力量型怪物的今日课含有氧克制动作', () {
      final plan = CoachLesson.recommendToday(
        user: _user(),
        focus: WorkoutFocus.mixed,
        monsterAffinity: ExerciseCategory.strength,
        streak: 9,
      );
      expect(plan.title, contains('今日克制课'));
      expect(plan.title, contains('有氧破力量'));
      final types = plan.exercises.map((e) => e.type).toSet();
      final hasCardio = types.any((t) => categoryOfExercise(t) == ExerciseCategory.cardio);
      expect(hasCardio, isTrue, reason: 'types=$types');
      expect(plan.items.every((i) => i.exercise.supportCamera), isTrue);
    });

    test('核心型怪物的今日课含力量克制动作', () {
      final plan = CoachLesson.recommendToday(
        user: _user(),
        focus: WorkoutFocus.mixed,
        monsterAffinity: ExerciseCategory.core,
        streak: 9,
      );
      expect(plan.title, contains('力量破核心'));
      final types = plan.exercises.map((e) => e.type);
      expect(
        types.any((t) => categoryOfExercise(t) == ExerciseCategory.strength),
        isTrue,
      );
    });

    test('有氧型怪物的今日课含核心克制动作', () {
      final plan = CoachLesson.recommendToday(
        user: _user(),
        focus: WorkoutFocus.mixed,
        monsterAffinity: ExerciseCategory.cardio,
        streak: 9,
      );
      expect(plan.title, contains('核心破有氧'));
      final types = plan.exercises.map((e) => e.type);
      expect(
        types.any((t) => categoryOfExercise(t) == ExerciseCategory.core),
        isTrue,
      );
    });
  });

  group('伤病过滤', () {
    test('膝盖不适去掉深蹲与弓步', () {
      final flags = const InjuryFlags(kneeIssue: true);
      expect(flags.excludedTypes, containsAll(['squat', 'lunge']));
      final plan = CoachLesson.recommendToday(
        user: _user(),
        monsterAffinity: ExerciseCategory.core,
        injury: flags,
        streak: 9,
      );
      final types = plan.exercises.map((e) => e.type).toSet();
      expect(types.contains('squat'), isFalse, reason: 'types=$types');
      expect(types.contains('lunge'), isFalse);
      expect(plan.items, isNotEmpty);
    });

    test('腰腹不适去掉平板与登山跑', () {
      final plan = CoachLesson.recommendToday(
        user: _user(),
        monsterAffinity: ExerciseCategory.cardio,
        injury: const InjuryFlags(waistIssue: true),
        streak: 9,
      );
      final types = plan.exercises.map((e) => e.type).toSet();
      expect(types.contains('plank'), isFalse, reason: 'types=$types');
      expect(types.contains('mountainclimber'), isFalse);
      expect(plan.items, isNotEmpty);
    });

    test('默认全部动作可用', () {
      expect(const InjuryFlags().hasAny, isFalse);
      expect(const InjuryFlags().excludedTypes, isEmpty);
    });
  });

  group('手感量档', () {
    test('太轻松加量，太累减量，夹在 ±2', () {
      var n = 0;
      final up = applyCoachFeel(feel: CoachFeel.tooEasy, currentNudge: n);
      expect(up.volumeNudge, 1);
      final up2 = applyCoachFeel(feel: CoachFeel.tooEasy, currentNudge: 2);
      expect(up2.volumeNudge, 2);
      expect(up2.difficulty, Difficulty.hard);
      expect(up2.difficultyChanged, isTrue);

      final down = applyCoachFeel(feel: CoachFeel.tooHard, currentNudge: 0);
      expect(down.volumeNudge, -1);
      final down2 = applyCoachFeel(
        feel: CoachFeel.tooHard,
        currentNudge: -2,
        difficulty: Difficulty.hard,
      );
      expect(down2.volumeNudge, -2);
      expect(down2.difficulty, Difficulty.normal);
    });

    test('加量课目标次数高于减量课', () {
      final easy = CoachLesson.recommendToday(
        user: _user(),
        feelNudge: 2,
        streak: 6,
      );
      final hard = CoachLesson.recommendToday(
        user: _user(),
        feelNudge: -2,
        streak: 6,
      );
      final easySum = easy.items.fold<int>(0, (a, i) => a + i.target);
      final hardSum = hard.items.fold<int>(0, (a, i) => a + i.target);
      expect(easySum, greaterThan(hardSum));
    });
  });

  group('克制效果标签', () {
    test('开合跳对力量怪效果绝佳', () {
      expect(
        counterEffectiveness(
          exerciseType: 'jumping_jack',
          monsterAffinity: ExerciseCategory.strength,
        ),
        DamageEffectiveness.superEffective,
      );
    });

    test('平板对力量怪被克', () {
      expect(
        counterEffectiveness(
          exerciseType: 'plank',
          monsterAffinity: ExerciseCategory.strength,
        ),
        DamageEffectiveness.weak,
      );
    });
  });
}
