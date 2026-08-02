import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/widgets/battle/forge_monster_art.dart';

void main() {
  testWidgets('forge monster art preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF14110E),
          body: Center(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final kind in MonsterKind.values)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ForgeMonsterArt(kind: kind, size: 120),
                      Text(kind.name),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('monster_art_preview.png'),
    );
  });
}
