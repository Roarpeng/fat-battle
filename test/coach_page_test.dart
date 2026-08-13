import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fat_battle/pages/coach_page.dart';
import 'package:fat_battle/providers/game_provider.dart';
import 'package:fat_battle/theme/forge_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CoachPage 展示快捷 chips 与工坊语气欢迎语', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: buildForgeTheme(),
          home: const CoachPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('工坊教练'), findsWidgets);
    expect(find.text('今天预算还剩多少'), findsOneWidget);
    expect(find.text('蛋白质够不够'), findsOneWidget);
    expect(find.text('这顿怎么记'), findsOneWidget);
    expect(find.text('剩余预算吃什么'), findsOneWidget);
    expect(find.textContaining('不会偷偷记账'), findsOneWidget);
  });

  testWidgets('点「今天预算还剩多少」给出本地接地气回答', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: buildForgeTheme(),
          home: const CoachPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('今天预算还剩多少'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('今天预算还剩多少'), findsWidgets);
    expect(find.textContaining('工坊目标'), findsOneWidget);
    expect(find.textContaining('我不会改'), findsOneWidget);
  });
}
