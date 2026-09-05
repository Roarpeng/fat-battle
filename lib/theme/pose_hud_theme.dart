import 'package:flutter/material.dart';

import 'app_visual_theme.dart';
import 'forge_palette.dart';

/// 姿态教练 HUD 色：跟 Forge 主题走，但保证安全可读。
///
/// 镜头预览上必须高对比。浅色纸面（sketch）不用白字叠奶油底，
/// 改用深墨字 + 不透明纸片；熔炉/墨稿用深底浅字。
class PoseHudTheme {
  final Color chrome;
  final Color chromeBorder;
  final Color onChrome;
  final Color onChromeMuted;
  final Color accent;
  final Color accentOnChrome;
  final Color warn;
  final Color scrim;
  final Color frameOk;
  final Color frameIdle;
  final Color skeletonHigh;
  final Color skeletonMid;
  final Color skeletonLow;
  final bool lightPaper;

  const PoseHudTheme({
    required this.chrome,
    required this.chromeBorder,
    required this.onChrome,
    required this.onChromeMuted,
    required this.accent,
    required this.accentOnChrome,
    required this.warn,
    required this.scrim,
    required this.frameOk,
    required this.frameIdle,
    required this.skeletonHigh,
    required this.skeletonMid,
    required this.skeletonLow,
    required this.lightPaper,
  });

  factory PoseHudTheme.fromPalette(ForgePalette p) {
    switch (p.visualTheme) {
      case AppVisualTheme.sketch:
        return PoseHudTheme(
          chrome: const Color(0xFFF7F1E6),
          chromeBorder: const Color(0xFF2A2622),
          onChrome: const Color(0xFF1A1714),
          onChromeMuted: const Color(0xFF3F3A35),
          accent: const Color(0xFF8A4B32),
          accentOnChrome: const Color(0xFF6A351F),
          warn: const Color(0xFF7A2E22),
          scrim: const Color(0x990C0A08),
          frameOk: const Color(0xFF3F3A35),
          frameIdle: const Color(0xFF1A1714),
          skeletonHigh: const Color(0xFF2A2622),
          skeletonMid: const Color(0xFF5A534C),
          skeletonLow: const Color(0xFF8A4B32),
          lightPaper: true,
        );
      case AppVisualTheme.ink:
        return PoseHudTheme(
          chrome: const Color(0xF21A1714),
          chromeBorder: const Color(0xFFD4C4A8),
          onChrome: const Color(0xFFF4EDE4),
          onChromeMuted: const Color(0xFFD4C4A8),
          accent: const Color(0xFFC97870),
          accentOnChrome: const Color(0xFFE8C4B8),
          warn: const Color(0xFFE89A90),
          scrim: const Color(0xB312100E),
          frameOk: const Color(0xFFC97870),
          frameIdle: const Color(0xFFE6DFD4),
          skeletonHigh: const Color(0xFFE6DFD4),
          skeletonMid: const Color(0xFFC97870),
          skeletonLow: const Color(0xFFB14A42),
          lightPaper: false,
        );
      case AppVisualTheme.forge:
        return PoseHudTheme(
          chrome: const Color(0xF2140C0A),
          chromeBorder: const Color(0x66E8C4A8),
          onChrome: const Color(0xFFFFF6F0),
          onChromeMuted: const Color(0xFFE8C4A8),
          accent: p.gold,
          accentOnChrome: p.gold,
          warn: p.red,
          scrim: const Color(0x73000000),
          frameOk: p.gold,
          frameIdle: const Color(0xEBFFFFFF),
          skeletonHigh: p.gold,
          skeletonMid: p.forgeGlow,
          skeletonLow: p.red,
          lightPaper: false,
        );
    }
  }

  static PoseHudTheme of(BuildContext context) =>
      PoseHudTheme.fromPalette(ForgeColors.of(context));

  /// 相对亮度差，供单测保证纸面主题不是浅字浅底。
  static double contrastRatio(Color a, Color b) {
    double lum(Color c) {
      double lin(double channel) {
        final n = channel;
        return n <= 0.03928
            ? n / 12.92
            : ((n + 0.055) / 1.055) * ((n + 0.055) / 1.055);
      }

      return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    final l1 = lum(a);
    final l2 = lum(b);
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }
}
