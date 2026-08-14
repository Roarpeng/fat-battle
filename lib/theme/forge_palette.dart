import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_visual_theme.dart';

/// 工坊色板 ThemeExtension：卡片纸色、描边、主强调等。
///
/// 通过 [ForgeColors.of] 读取；无 extension 时回退熔炉色。
@immutable
class ForgePalette extends ThemeExtension<ForgePalette> {
  final AppVisualTheme visualTheme;
  final Brightness brightness;
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color red;
  final Color gold;
  final Color green;
  final Color purple;
  final Color text;
  final Color text2;
  final Color card;
  final Color border;
  final Color overlay;
  final Color forgeGlow;
  final Color ghostBar;
  final Color hitSpark;
  final Color dopamineOrange;
  final Color onEmber;
  final Color paper;
  /// 0 = 规整圆角；>0 时 [ForgeSurface] / [SketchCard] 使用手绘描边。
  final double borderRoughness;
  final bool sketchBorders;

  const ForgePalette({
    required this.visualTheme,
    required this.brightness,
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.red,
    required this.gold,
    required this.green,
    required this.purple,
    required this.text,
    required this.text2,
    required this.card,
    required this.border,
    required this.overlay,
    required this.forgeGlow,
    required this.ghostBar,
    required this.hitSpark,
    required this.dopamineOrange,
    required this.onEmber,
    required this.paper,
    required this.borderRoughness,
    required this.sketchBorders,
  });

  Color get surface => bg2;
  Color get elevated => card;
  Color get ember => red;
  Color get copper => gold;
  Color get shield => purple;

  bool get isLight => brightness == Brightness.light;

  /// 与 [AppColors] 字段一一对应的熔炉色板（默认）。
  static const ForgePalette forge = ForgePalette(
    visualTheme: AppVisualTheme.forge,
    brightness: Brightness.dark,
    bg: AppColors.bg,
    bg2: AppColors.bg2,
    bg3: AppColors.bg3,
    red: AppColors.red,
    gold: AppColors.gold,
    green: AppColors.green,
    purple: AppColors.purple,
    text: AppColors.text,
    text2: AppColors.text2,
    card: AppColors.card,
    border: AppColors.border,
    overlay: AppColors.overlay,
    forgeGlow: AppColors.forgeGlow,
    ghostBar: AppColors.ghostBar,
    hitSpark: AppColors.hitSpark,
    dopamineOrange: AppColors.dopamineOrange,
    onEmber: AppColors.onEmber,
    paper: AppColors.bg,
    borderRoughness: 0,
    sketchBorders: false,
  );

  /// 浅色暖纸 + 石墨描边（铅笔手账）。
  static const ForgePalette sketch = ForgePalette(
    visualTheme: AppVisualTheme.sketch,
    brightness: Brightness.light,
    bg: Color(0xFFF3EBDD),
    bg2: Color(0xFFEBE2D2),
    bg3: Color(0xFFE4D9C6),
    red: Color(0xFF8A4B32),
    gold: Color(0xFF4A453F),
    green: Color(0xFF6A8A62),
    purple: Color(0xFF6E7C88),
    text: Color(0xFF2A2622),
    text2: Color(0xFF6F675C),
    card: Color(0xFFFAF6EE),
    border: Color(0xFF3F3A35),
    overlay: Color(0xCCEDE4D4),
    forgeGlow: Color(0xFFC4A07A),
    ghostBar: Color(0xFFC4A090),
    hitSpark: Color(0xFF5A534C),
    dopamineOrange: Color(0xFFA05A3C),
    onEmber: Color(0xFFF7F1E6),
    paper: Color(0xFFF3EBDD),
    borderRoughness: 1.15,
    sketchBorders: true,
  );

  /// 深色纸面 + 闷墨红 / 石色（夜读墨稿）。
  static const ForgePalette ink = ForgePalette(
    visualTheme: AppVisualTheme.ink,
    brightness: Brightness.dark,
    bg: Color(0xFF12100E),
    bg2: Color(0xFF1A1714),
    bg3: Color(0xFF221E1A),
    red: Color(0xFFB14A42),
    gold: Color(0xFF9A9186),
    green: Color(0xFF7A9480),
    purple: Color(0xFF7D8890),
    text: Color(0xFFE6DFD4),
    text2: Color(0xFF8E867C),
    card: Color(0xFF1E1B17),
    border: Color(0xFF5C564E),
    overlay: Color(0xCC12100E),
    forgeGlow: Color(0xFFC97870),
    ghostBar: Color(0xFFC97870),
    hitSpark: Color(0xFFD4C4A8),
    dopamineOrange: Color(0xFFB85A4A),
    onEmber: Color(0xFFF4EDE4),
    paper: Color(0xFF12100E),
    borderRoughness: 0.95,
    sketchBorders: true,
  );

  static ForgePalette forTheme(AppVisualTheme theme) {
    switch (theme) {
      case AppVisualTheme.forge:
        return ForgePalette.forge;
      case AppVisualTheme.sketch:
        return ForgePalette.sketch;
      case AppVisualTheme.ink:
        return ForgePalette.ink;
    }
  }

  @override
  ForgePalette copyWith({
    AppVisualTheme? visualTheme,
    Brightness? brightness,
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? red,
    Color? gold,
    Color? green,
    Color? purple,
    Color? text,
    Color? text2,
    Color? card,
    Color? border,
    Color? overlay,
    Color? forgeGlow,
    Color? ghostBar,
    Color? hitSpark,
    Color? dopamineOrange,
    Color? onEmber,
    Color? paper,
    double? borderRoughness,
    bool? sketchBorders,
  }) {
    return ForgePalette(
      visualTheme: visualTheme ?? this.visualTheme,
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      red: red ?? this.red,
      gold: gold ?? this.gold,
      green: green ?? this.green,
      purple: purple ?? this.purple,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      card: card ?? this.card,
      border: border ?? this.border,
      overlay: overlay ?? this.overlay,
      forgeGlow: forgeGlow ?? this.forgeGlow,
      ghostBar: ghostBar ?? this.ghostBar,
      hitSpark: hitSpark ?? this.hitSpark,
      dopamineOrange: dopamineOrange ?? this.dopamineOrange,
      onEmber: onEmber ?? this.onEmber,
      paper: paper ?? this.paper,
      borderRoughness: borderRoughness ?? this.borderRoughness,
      sketchBorders: sketchBorders ?? this.sketchBorders,
    );
  }

  @override
  ForgePalette lerp(ThemeExtension<ForgePalette>? other, double t) {
    if (other is! ForgePalette) return this;
    return ForgePalette(
      visualTheme: t < 0.5 ? visualTheme : other.visualTheme,
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      red: Color.lerp(red, other.red, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      green: Color.lerp(green, other.green, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      forgeGlow: Color.lerp(forgeGlow, other.forgeGlow, t)!,
      ghostBar: Color.lerp(ghostBar, other.ghostBar, t)!,
      hitSpark: Color.lerp(hitSpark, other.hitSpark, t)!,
      dopamineOrange: Color.lerp(dopamineOrange, other.dopamineOrange, t)!,
      onEmber: Color.lerp(onEmber, other.onEmber, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      borderRoughness:
          lerpDouble(borderRoughness, other.borderRoughness, t) ?? 0,
      sketchBorders: t < 0.5 ? sketchBorders : other.sketchBorders,
    );
  }
}

/// 当前主题色板。无 ThemeExtension 时回退熔炉。
class ForgeColors {
  ForgeColors._();

  static ForgePalette of(BuildContext context) =>
      Theme.of(context).extension<ForgePalette>() ?? ForgePalette.forge;
}
