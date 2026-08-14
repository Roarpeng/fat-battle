import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fat_battle/providers/game_provider.dart';
import 'package:fat_battle/theme/app_visual_theme.dart';
import 'package:fat_battle/theme/forge_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildAppTheme', () {
    test('三种风格的 scaffoldBackgroundColor 互不相同', () {
      final forge = buildAppTheme(AppVisualTheme.forge);
      final sketch = buildAppTheme(AppVisualTheme.sketch);
      final ink = buildAppTheme(AppVisualTheme.ink);

      expect(forge.scaffoldBackgroundColor, isNotNull);
      expect(sketch.scaffoldBackgroundColor, isNotNull);
      expect(ink.scaffoldBackgroundColor, isNotNull);

      expect(
        forge.scaffoldBackgroundColor,
        isNot(equals(sketch.scaffoldBackgroundColor)),
      );
      expect(
        forge.scaffoldBackgroundColor,
        isNot(equals(ink.scaffoldBackgroundColor)),
      );
      expect(
        sketch.scaffoldBackgroundColor,
        isNot(equals(ink.scaffoldBackgroundColor)),
      );

      expect(
        forge.scaffoldBackgroundColor,
        buildForgeTheme().scaffoldBackgroundColor,
      );
    });
  });

  group('visualTheme persistence', () {
    test('GameState JSON 往返保留 visualTheme', () {
      const original = GameState(visualTheme: AppVisualTheme.sketch);
      final loaded = GameState.fromJson(original.toJson());
      expect(loaded.visualTheme, AppVisualTheme.sketch);

      const ink = GameState(visualTheme: AppVisualTheme.ink);
      expect(GameState.fromJson(ink.toJson()).visualTheme, AppVisualTheme.ink);

      const forge = GameState();
      expect(GameState.fromJson(forge.toJson()).visualTheme, AppVisualTheme.forge);
    });

    test('未知 visualTheme 回退熔炉', () {
      final loaded = GameState.fromJson({'visualTheme': 'neon'});
      expect(loaded.visualTheme, AppVisualTheme.forge);
    });

    test('旧存档缺字段时默认熔炉', () {
      final loaded = GameState.fromJson({'day': 3, 'lastDate': '2026-08-13'});
      expect(loaded.visualTheme, AppVisualTheme.forge);
    });

    test('GameStateNotifier 切换后重启仍读到同一风格', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = GameStateNotifier(prefs);
      expect(first.state.visualTheme, AppVisualTheme.forge);
      await first.updateVisualTheme(AppVisualTheme.ink);

      expect(prefs.getString(kAppVisualThemePrefKey), 'ink');
      final saved = prefs.getString('fat_battle_game');
      expect(saved, isNotNull);
      expect(saved!, contains('"visualTheme":"ink"'));

      final second = GameStateNotifier(prefs);
      expect(second.state.visualTheme, AppVisualTheme.ink);
    });

    test('仅 prefs 备份时也能恢复风格', () async {
      SharedPreferences.setMockInitialValues({
        kAppVisualThemePrefKey: 'sketch',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = GameStateNotifier(prefs);
      expect(notifier.state.visualTheme, AppVisualTheme.sketch);
    });
  });
}
