import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fat_battle/constants/app_constants.dart';
import 'package:fat_battle/core/core_types.dart';
import 'package:fat_battle/models/game_models.dart';
import 'package:fat_battle/providers/game_provider.dart';
import 'package:fat_battle/theme/sculpt_progress.dart';

void main() {
  group('sculptLineFor', () {
    test('男大卫 女维纳斯 其他自选默认维纳斯', () {
      expect(sculptLineFor(gender: Gender.male), SculptLine.david);
      expect(sculptLineFor(gender: Gender.female), SculptLine.venus);
      expect(sculptLineFor(gender: Gender.other), SculptLine.venus);
      expect(
        sculptLineFor(gender: Gender.other, chosen: SculptLine.david),
        SculptLine.david,
      );
    });
  });

  group('sculptAssetPath', () {
    test('按线选目录', () {
      expect(
        sculptAssetPath(line: SculptLine.venus, stage: 4),
        'assets/branding/sculpt/venus/4-master.png',
      );
      expect(
        sculptAssetPath(line: SculptLine.david, stage: 7),
        'assets/branding/sculpt/david/7-rebound.png',
      );
    });
  });

  group('sculptOnboardingFromBody', () {
    test('BMI≥28 或差距≥15kg → 粘土', () {
      final obese = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 90,
        targetWeightKg: 70,
        weeklyFreq: 3,
        pushupCount: 10,
        runDuration: 15,
        workType: WorkType.sometimes,
      );
      expect(obese.floor, 0);
      expect(obese.maintenance, isFalse);

      final bigGap = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 80,
        targetWeightKg: 64,
        weeklyFreq: 3,
        pushupCount: 10,
        runDuration: 15,
        workType: WorkType.sometimes,
      );
      expect(bigGap.floor, 0);
    });

    test('BMI 24–28 → 石块', () {
      final block = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 75,
        targetWeightKg: 65,
        weeklyFreq: 3,
        pushupCount: 10,
        runDuration: 15,
        workType: WorkType.sometimes,
      );
      expect(block.floor, 1);
      expect(block.maintenance, isFalse);
    });

    test('BMI<18.5 不当粘土：低练 2 / 有练 3', () {
      final leanIdle = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 50,
        targetWeightKg: 55,
        weeklyFreq: 1,
        pushupCount: 5,
        runDuration: 8,
        workType: WorkType.sedentary,
      );
      expect(leanIdle.floor, 2);

      final leanTrained = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 50,
        targetWeightKg: 55,
        weeklyFreq: 5,
        pushupCount: 15,
        runDuration: 25,
        workType: WorkType.active,
      );
      expect(leanTrained.floor, 3);
    });

    test('BMI 正常 + 久坐/低频 → 粗坯', () {
      final rough = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 64,
        targetWeightKg: 60,
        weeklyFreq: 1,
        pushupCount: 6,
        runDuration: 10,
        workType: WorkType.sedentary,
      );
      expect(rough.floor, 2);
    });

    test('BMI 正常 + 有训练仍有差距 → 成形', () {
      final emerge = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 66,
        targetWeightKg: 60,
        weeklyFreq: 3,
        pushupCount: 15,
        runDuration: 20,
        workType: WorkType.sometimes,
      );
      expect(emerge.floor, 3);
    });

    test('身体素质很好 → 杰作并立刻进维护', () {
      final master = sculptOnboardingFromBody(
        heightCm: 170,
        weightKg: 63,
        targetWeightKg: 62,
        weeklyFreq: 5,
        pushupCount: 25,
        runDuration: 30,
        workType: WorkType.active,
      );
      expect(master.floor, 4);
      expect(master.maintenance, isTrue);
    });
  });

  group('evaluateSculptMaintenanceStage', () {
    test('3 天内结算 → 保养', () {
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 2,
          overeatSinceSettle: 0,
          weightTrendingUp: false,
        ),
        5,
      );
    });

    test('4–10 天没练 → 蒙尘', () {
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 4,
          overeatSinceSettle: 0,
          weightTrendingUp: false,
        ),
        6,
      );
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 10,
          overeatSinceSettle: 0,
          weightTrendingUp: false,
        ),
        6,
      );
    });

    test('超 10 天 / 反复暴食 / 体重上扬 → 回潮', () {
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 11,
          overeatSinceSettle: 0,
          weightTrendingUp: false,
        ),
        7,
      );
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 1,
          overeatSinceSettle: 2,
          weightTrendingUp: false,
        ),
        7,
      );
      expect(
        evaluateSculptMaintenanceStage(
          daysSinceSettlement: 1,
          overeatSinceSettle: 0,
          weightTrendingUp: true,
        ),
        7,
      );
    });
  });

  group('sculptProgressFromSettlements', () {
    test('0 次是未开凿粘土', () {
      expect(
        sculptProgressFromSettlements(settledCount: 0, averageQuality: 80),
        0,
      );
      expect(sculptStageFromProgress(0), 0);
    });

    test('3 次约 0.25 开大形', () {
      final p = sculptProgressFromSettlements(
        settledCount: 3,
        averageQuality: 70,
      );
      expect(p, closeTo(0.25, 0.001));
      expect(sculptStageFromProgress(p), 1);
    });

    test('10 次约 0.50 出轮廓', () {
      final p = sculptProgressFromSettlements(
        settledCount: 10,
        averageQuality: 70,
      );
      expect(p, closeTo(0.50, 0.001));
      expect(sculptStageFromProgress(p), 2);
    });

    test('21 次约 0.75 精修', () {
      final p = sculptProgressFromSettlements(
        settledCount: 21,
        averageQuality: 70,
      );
      expect(p, closeTo(0.75, 0.001));
      expect(sculptStageFromProgress(p), 3);
    });

    test('30+ 且质量尚可到成品', () {
      final p = sculptProgressFromSettlements(
        settledCount: 30,
        averageQuality: 60,
      );
      expect(p, 1.0);
      expect(sculptStageFromProgress(p), 4);
    });

    test('30+ 但质量偏低不到成品', () {
      final p = sculptProgressFromSettlements(
        settledCount: 30,
        averageQuality: 40,
      );
      expect(p, 0.92);
      expect(sculptStageFromProgress(p), 4);
    });

    test('floor + 结算次数增益，不掉到 floor 之下', () {
      final p = sculptProgressFromSettlements(
        settledCount: 0,
        averageQuality: 70,
        floor: 2,
      );
      expect(p, closeTo(0.50, 0.001));
      expect(sculptStageFromProgress(p), 2);
    });
  });

  test('交叉淡入落在相邻关键帧', () {
    final fade = sculptCrossfade(0.375);
    expect(fade.low, 1);
    expect(fade.high, 2);
    expect(fade.t, closeTo(0.5, 0.001));
  });

  test('GameState JSON 往返雕刻字段', () {
    const gs = GameState(
      sculptProgress: 0.5,
      sculptSettledCount: 10,
      sculptQualitySum: 700,
      sculptStage: 2,
      sculptFloor: 1,
      sculptMaintenance: false,
      sculptLastSettledDate: '2026-08-01',
      sculptOvereatSinceSettle: 1,
    );
    final round = GameState.fromJson(gs.toJson());
    expect(round.sculptProgress, 0.5);
    expect(round.sculptSettledCount, 10);
    expect(round.sculptQualitySum, 700);
    expect(round.sculptStage, 2);
    expect(round.sculptFloor, 1);
    expect(round.sculptMaintenance, isFalse);
    expect(round.sculptLastSettledDate, '2026-08-01');
    expect(round.sculptOvereatSinceSettle, 1);
  });

  test('User JSON 往返性别 other 与 sculptLine', () {
    const user = User(
      gender: Gender.other,
      sculptLine: SculptLine.david,
    );
    final round = User.fromJson(user.toJson());
    expect(round.gender, Gender.other);
    expect(round.sculptLine, SculptLine.david);
  });

  test('结算只升不降，重置回粘土', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = GameStateNotifier(prefs);

    expect(notifier.state.sculptProgress, 0);
    expect(notifier.state.sculptStage, 0);
    expect(sculptStageFromProgress(notifier.state.sculptProgress), 0);

    for (var i = 0; i < 3; i++) {
      await notifier.recordSculptSettlement(grade: 'A');
    }
    expect(notifier.state.sculptSettledCount, 3);
    expect(notifier.state.sculptProgress, closeTo(0.25, 0.001));
    expect(notifier.state.sculptStage, 1);
    expect(prefs.getDouble('sculpt_progress'), closeTo(0.25, 0.001));

    final afterThree = notifier.state.sculptProgress;
    await notifier.recordSculptSettlement(grade: 'D');
    expect(notifier.state.sculptProgress >= afterThree, isTrue);

    for (var i = 0; i < 6; i++) {
      await notifier.recordSculptSettlement(grade: 'B');
    }
    expect(notifier.state.sculptSettledCount, 10);
    expect(notifier.state.sculptProgress, closeTo(0.50, 0.02));
    expect(sculptStageFromProgress(notifier.state.sculptProgress), 2);
    expect(notifier.state.sculptStage, 2);

    await notifier.resetGame();
    expect(notifier.state.sculptProgress, 0);
    expect(notifier.state.sculptSettledCount, 0);
    expect(notifier.state.sculptStage, 0);
    expect(prefs.getDouble('sculpt_progress'), isNull);
  });

  test('建档按身体数据设起点，男角色走大卫线', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = GameStateNotifier(prefs);

    await notifier.createGame(
      const User(
        height: 170,
        weight: 75,
        targetWeight: 65,
        gender: Gender.male,
        weeklyFreq: 3,
        pushupCount: 10,
        runDuration: 15,
        workType: WorkType.sometimes,
      ),
    );
    expect(notifier.state.user.sculptLine, SculptLine.david);
    expect(notifier.state.sculptFloor, 1);
    expect(notifier.state.sculptStage, 1);
    expect(notifier.state.sculptMaintenance, isFalse);
  });

  test('素质很好的建档直接维护保养，结算不掉回粘土', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = GameStateNotifier(prefs);

    await notifier.createGame(
      const User(
        height: 170,
        weight: 63,
        targetWeight: 62,
        gender: Gender.female,
        weeklyFreq: 5,
        pushupCount: 25,
        runDuration: 30,
        workType: WorkType.active,
      ),
    );
    expect(notifier.state.user.sculptLine, SculptLine.venus);
    expect(notifier.state.sculptFloor, 4);
    expect(notifier.state.sculptMaintenance, isTrue);
    expect(notifier.state.sculptStage, 5);

    await notifier.recordSculptSettlement(grade: 'A');
    expect(notifier.state.sculptStage, 5);
    expect(notifier.state.sculptMaintenance, isTrue);

    await notifier.setPendingAttack(
      const PendingAttack(isOvereat: true, overeatCalories: 400),
    );
    await notifier.setPendingAttack(
      const PendingAttack(isOvereat: true, overeatCalories: 400),
    );
    expect(notifier.state.sculptOvereatSinceSettle, 2);
    expect(notifier.state.sculptStage, 7);

    await notifier.recordSculptSettlement(grade: 'B');
    expect(notifier.state.sculptStage, 5);
    expect(notifier.state.sculptMaintenance, isTrue);
  });
}
