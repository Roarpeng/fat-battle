import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fat_battle/theme/motion.dart';
import 'package:fat_battle/widgets/battle/forge_monster_art.dart';
import 'package:fat_battle/widgets/battle/monster_display.dart';
import 'package:fat_battle/widgets/sculpt_icon.dart';

void main() {
  testWidgets('SculptIcon 用人体雕塑资源交叉淡入', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SculptIcon(sculptProgress: 0, size: 48),
        ),
      ),
    );
    expect(find.byType(SculptIcon), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SculptIcon(sculptProgress: 0.5, size: 48),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('MonsterDisplay 仍用 ForgeMonsterArt 且尊重 reduceMotion',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: Scaffold(
            body: MonsterDisplay(
              emoji: '👾',
              hpPercentage: 1,
              isHit: true,
              isEnraged: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(ForgeMonsterArt), findsOneWidget);
    expect(find.textContaining('💥'), findsNothing);
  });

  testWidgets('六种魔物立绘可绘制', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final kind in MonsterKind.values)
                ForgeMonsterArt(kind: kind, size: 40, emberPulse: 0.8),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(ForgeMonsterArt), findsNWidgets(MonsterKind.values.length));
  });

  test('按压 token 是凿击而不是 0.97', () {
    expect(AppMotion.tapScale, lessThan(0.97));
    expect(AppMotion.tapDip, 1.0);
  });
}
