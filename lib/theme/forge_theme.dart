import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import 'tokens.dart';

/// 锻造工坊字体体系（中文友好）
///
/// 标题用「站酷快乐体」，正文用「思源黑体」。
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
      GoogleFonts.zcoolKuaiLe(
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
      GoogleFonts.notoSansSc(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );

  static void preload() {
    GoogleFonts.config.allowRuntimeFetching = true;
    GoogleFonts.zcoolKuaiLe();
    GoogleFonts.notoSansSc();
  }
}

/// 锻造工坊 2.0 ThemeData
ThemeData buildForgeTheme() {
  final display = AppFonts.display(color: AppColors.text);
  final body = AppFonts.body(color: AppColors.text);
  final overlayPress = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.pressed)) {
      return Colors.white.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return null;
  });

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.ember,
      secondary: AppColors.copper,
      surface: AppColors.elevated,
      onPrimary: AppColors.onEmber,
      onSecondary: AppColors.bg,
      onSurface: AppColors.text,
      error: AppColors.ember,
      outline: AppColors.border,
    ),
    textTheme: TextTheme(
      displayLarge: display.copyWith(fontSize: 36, height: 1.08, fontWeight: FontWeight.w600),
      displayMedium: display.copyWith(fontSize: 28, height: 1.12, fontWeight: FontWeight.w600),
      headlineMedium: display.copyWith(fontSize: 22, height: 1.18, fontWeight: FontWeight.w600),
      titleLarge: display.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.4),
      bodySmall: body.copyWith(fontSize: 12, height: 1.35, color: AppColors.text2),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.text,
      titleTextStyle: display.copyWith(fontSize: 18),
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.elevated,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ember,
        foregroundColor: AppColors.onEmber,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        textStyle: body.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        overlayColor: Colors.white.withValues(alpha: 0.12),
      ).copyWith(overlayColor: overlayPress),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.copper,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        overlayColor: Colors.white.withValues(alpha: 0.08),
      ).copyWith(overlayColor: overlayPress),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.copper,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ).copyWith(overlayColor: overlayPress),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      height: 68,
      indicatorColor: AppColors.copper.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return body.copyWith(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.copper : AppColors.text2,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.ember : AppColors.text2,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      border: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: const BorderSide(color: AppColors.copper, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.bg3,
      contentTextStyle: body.copyWith(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smAll),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      titleTextStyle: display.copyWith(fontSize: 20, color: AppColors.text),
      contentTextStyle: body.copyWith(fontSize: 14, color: AppColors.text2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.elevated,
      modalBackgroundColor: AppColors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.border,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.copper,
      textColor: AppColors.text,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    ),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
  );
}
