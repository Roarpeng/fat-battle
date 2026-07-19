import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/pages/setup_page.dart';

void main() {
  testWidgets('SetupPage 所有5个步骤构建不崩溃', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
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
