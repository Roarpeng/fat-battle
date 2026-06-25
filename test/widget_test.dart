import 'package:flutter_test/flutter_test.dart';

import 'package:fat_battle/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FatBattleApp());
    expect(find.text('减肥大作战'), findsOneWidget);
  });
}
