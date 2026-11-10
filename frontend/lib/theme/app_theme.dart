import 'package:flutter/material.dart';
import 'theme_tokens.dart';

class AppTheme {
  static ThemeData build(AppColors colors, {Brightness brightness = Brightness.light}) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: Colors.white,
      secondary: colors.accent,
      onSecondary: Colors.white,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      // 使用本地中文系统字体，避免 Web 引擎远程加载字体
      fontFamily: 'Microsoft YaHei',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(TypographyTokens.caption.copyWith(color: colors.textSecondary)),
        iconTheme: WidgetStateProperty.all(IconThemeData(color: colors.textSecondary)),
      ),
      textTheme: TextTheme(
        titleLarge: TypographyTokens.h1.copyWith(color: colors.textPrimary),
        titleMedium: TypographyTokens.h2.copyWith(color: colors.textPrimary),
        bodyMedium: TypographyTokens.body.copyWith(color: colors.textPrimary),
        bodySmall: TypographyTokens.caption.copyWith(color: colors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 1,
        shape: const RoundedRectangleBorder(borderRadius: Radii.md),
      ),
      // 输入框遵循设计：下划线样式、清晰的提示与标签
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TypographyTokens.body.copyWith(color: colors.textPrimary),
        hintStyle: TypographyTokens.caption.copyWith(color: colors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: colors.accent, width: 2),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        filled: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.primary.withValues(alpha: 0.5);
            }
            return colors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: Radii.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size.fromHeight(44)),
          side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFD1D5DB), width: 1)),
          shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: Radii.md)),
          foregroundColor: WidgetStateProperty.all(colors.textPrimary),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(colors.accent),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brightness == Brightness.light ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
        labelStyle: TypographyTokens.caption.copyWith(color: colors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : const Color(0xFF1A1F2A),
        contentTextStyle: TypographyTokens.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  static ThemeData get light => build(AppColors.light, brightness: Brightness.light);
  static ThemeData get dark => build(AppColors.dark, brightness: Brightness.dark);
}