import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fat_battle/core/safety.dart';
import 'package:fat_battle/pages/setup_page.dart';
import 'package:fat_battle/providers/game_provider.dart';

void main() {
  testWidgets('SetupPage 所有5个步骤构建不崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({
      kMedicalDisclaimerPrefKey: true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SetupPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SetupPage), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);

    final nextBtn = find.byType(ElevatedButton).first;
    for (int i = 1; i <= 4; i++) {
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
    }

    expect(find.byType(SetupPage), findsOneWidget);
  });
}
