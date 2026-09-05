import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_battle/theme/forge_palette.dart';
import 'package:fat_battle/theme/pose_hud_theme.dart';

void main() {
  group('PoseHudTheme 对比度', () {
    test('三种主题 chrome 上的字对比度 ≥ 4.5', () {
      for (final p in [ForgePalette.forge, ForgePalette.sketch, ForgePalette.ink]) {
        final hud = PoseHudTheme.fromPalette(p);
        final ratio = PoseHudTheme.contrastRatio(hud.onChrome, hud.chrome);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '${p.visualTheme} onChrome/chrome=$ratio',
        );
        expect(
          PoseHudTheme.contrastRatio(hud.onChromeMuted, hud.chrome),
          greaterThanOrEqualTo(3.0),
          reason: '${p.visualTheme} muted',
        );
      }
    });

    test('sketch 是浅纸深墨，不是白字叠奶油底', () {
      final hud = PoseHudTheme.fromPalette(ForgePalette.sketch);
      expect(hud.lightPaper, isTrue);
      expect(hud.onChrome.computeLuminance(), lessThan(0.3));
      expect(hud.chrome.computeLuminance(), greaterThan(0.7));
    });

    test('forge / ink 保持深底浅字', () {
      for (final p in [ForgePalette.forge, ForgePalette.ink]) {
        final hud = PoseHudTheme.fromPalette(p);
        expect(hud.lightPaper, isFalse);
        expect(hud.onChrome.computeLuminance(), greaterThan(hud.chrome.computeLuminance()));
      }
    });
  });
}
