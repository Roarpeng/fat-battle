import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_visual_theme.dart';
import 'forge_palette.dart';
import 'tokens.dart';

export 'app_visual_theme.dart';
export 'forge_palette.dart';

final bool _kIsFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';

TextStyle _plain({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  List<Shadow>? shadows,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );

/// 锻造工坊字体体系（中文友好）
///
/// 熔炉标题用「站酷快乐体」；铅笔手账 / 墨稿标题用「马善政楷书」；
/// 正文一律「思源黑体」。
class AppFonts {
  AppFonts._();

  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) =>
      _kIsFlutterTest
          ? _plain(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            )
          : GoogleFonts.zcoolKuaiLe(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            );

  /// 手账 / 墨稿标题（楷书手写感，不是蜡笔）。
  static TextStyle journalDisplay({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) =>
      _kIsFlutterTest
          ? _plain(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            )
          : GoogleFonts.maShanZheng(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            );

  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) =>
      _kIsFlutterTest
          ? _plain(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            )
          : GoogleFonts.notoSansSc(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              height: height,
              letterSpacing: letterSpacing,
              shadows: shadows,
            );

  /// 按当前 [ForgePalette.visualTheme] 选标题字体。
  static TextStyle displayOf(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    final palette = ForgeColors.of(context);
    final resolved = color ?? palette.text;
    if (palette.visualTheme == AppVisualTheme.forge) {
      return display(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: resolved,
        height: height,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
    return journalDisplay(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: resolved,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static TextStyle bodyOf(
    BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    final palette = ForgeColors.of(context);
    return body(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? palette.text,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static void preload() {
    GoogleFonts.config.allowRuntimeFetching = true;
    GoogleFonts.zcoolKuaiLe();
    GoogleFonts.maShanZheng();
    GoogleFonts.notoSansSc();
  }
}

TextStyle _titleFontFor(
  AppVisualTheme theme, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
  List<Shadow>? shadows,
}) {
  if (theme == AppVisualTheme.forge) {
    return AppFonts.display(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }
  return AppFonts.journalDisplay(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );
}

/// 锻造工坊 2.0 ThemeData（熔炉默认，保持现有观感）
ThemeData buildForgeTheme() => buildAppTheme(AppVisualTheme.forge);

ThemeData buildSketchTheme() => buildAppTheme(AppVisualTheme.sketch);

ThemeData buildInkTheme() => buildAppTheme(AppVisualTheme.ink);

/// 按视觉风格构建 Material 主题。熔炉走原 [buildForgeTheme] 色板与字体。
ThemeData buildAppTheme(AppVisualTheme theme) {
  final palette = ForgePalette.forTheme(theme);
  return _buildPaletteTheme(palette);
}

ThemeData _buildPaletteTheme(ForgePalette palette) {
  final display = _titleFontFor(palette.visualTheme, color: palette.text);
  final body = AppFonts.body(color: palette.text);
  final isLight = palette.isLight;
  final overlayPress = WidgetStateProperty.resolveWith<Color?>((states) {
    final pressed = isLight ? Colors.black : Colors.white;
    if (states.contains(WidgetState.pressed)) {
      return pressed.withValues(alpha: isLight ? 0.08 : 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return pressed.withValues(alpha: isLight ? 0.05 : 0.08);
    }
    return null;
  });

  final colorScheme = isLight
      ? ColorScheme.light(
          primary: palette.ember,
          secondary: palette.copper,
          surface: palette.elevated,
          onPrimary: palette.onEmber,
          onSecondary: palette.bg,
          onSurface: palette.text,
          error: palette.ember,
          outline: palette.border,
        )
      : ColorScheme.dark(
          primary: palette.ember,
          secondary: palette.copper,
          surface: palette.elevated,
          onPrimary: palette.onEmber,
          onSecondary: palette.bg,
          onSurface: palette.text,
          error: palette.ember,
          outline: palette.border,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    scaffoldBackgroundColor: palette.bg,
    colorScheme: colorScheme,
    extensions: <ThemeExtension<dynamic>>[palette],
    textTheme: TextTheme(
      displayLarge: display.copyWith(fontSize: 36, height: 1.08, fontWeight: FontWeight.w600),
      displayMedium: display.copyWith(fontSize: 28, height: 1.12, fontWeight: FontWeight.w600),
      headlineMedium: display.copyWith(fontSize: 22, height: 1.18, fontWeight: FontWeight.w600),
      titleLarge: display.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.4),
      bodySmall: body.copyWith(fontSize: 12, height: 1.35, color: palette.text2),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: palette.text,
      titleTextStyle: display.copyWith(fontSize: 18),
      centerTitle: true,
      systemOverlayStyle:
          isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: palette.elevated,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: BorderSide(color: palette.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.ember,
        foregroundColor: palette.onEmber,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        textStyle: body.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        overlayColor: (isLight ? Colors.black : Colors.white)
            .withValues(alpha: isLight ? 0.08 : 0.12),
      ).copyWith(overlayColor: overlayPress),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.copper,
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        overlayColor: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
      ).copyWith(overlayColor: overlayPress),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.copper,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ).copyWith(overlayColor: overlayPress),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surface,
      elevation: 0,
      height: 68,
      indicatorColor: palette.copper.withValues(alpha: isLight ? 0.14 : 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return body.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? palette.copper : palette.text2,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? palette.ember : palette.text2,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      border: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: palette.copper, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.bg3,
      contentTextStyle: body.copyWith(color: palette.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      titleTextStyle: display.copyWith(fontSize: 20, color: palette.text),
      contentTextStyle: body.copyWith(fontSize: 14, color: palette.text2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.elevated,
      modalBackgroundColor: palette.elevated,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      showDragHandle: true,
      dragHandleColor: palette.border,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.copper,
      textColor: palette.text,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    ),
    dividerColor: palette.border,
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.onEmber;
        return palette.text2;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return palette.green;
        return palette.border;
      }),
    ),
    iconTheme: IconThemeData(color: palette.copper),
  );
}
