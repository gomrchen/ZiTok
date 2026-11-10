import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 非首页 Tab 统一画布：剧场 / 消息 / 我的 与壳层底色对齐
/// 常量保留浅色品牌默认；运行时请用 *Of(context) 跟随夜晚模式。
class ShellSurface {
  static const canvas = Color(0xFFF4F1EC);
  static const canvasDark = Color(0xFF0B0F1A);
  static const ink = Color(0xFF12151C);
  static const inkDark = Color(0xFFE5E7EB);
  static const muted = Color(0xFF5C6570);
  static const mutedDark = Color(0xFF9CA3AF);
  static const line = Color(0x1412151C);
  static const lineDark = Color(0x22FFFFFF);
  static const card = Color(0xFFFBF9F6);
  static const cardDark = Color(0xFF111827);
  static const coral = Color(0xFFFF6B4A);
  static const accent = Color(0xFF2ED3BE);

  static const pagePad = 16.0;
  static const sectionGap = 22.0;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvasOf(BuildContext context) =>
      isDark(context) ? canvasDark : canvas;

  static Color inkOf(BuildContext context) =>
      isDark(context) ? inkDark : ink;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? mutedDark : muted;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? cardDark : card;

  static Color lineOf(BuildContext context) =>
      isDark(context) ? lineDark : line;

  static SystemUiOverlayStyle systemUiOf(BuildContext context) {
    final dark = isDark(context);
    return (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: canvasOf(context),
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  /// 兼容旧调用（浅色）；优先使用 [systemUiOf]
  static SystemUiOverlayStyle get systemUi => SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  static AppBar appBar({
    required String title,
    BuildContext? context,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    final inkColor = context != null ? inkOf(context) : ink;
    final bg = context != null ? canvasOf(context) : canvas;
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: inkColor,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: inkColor,
      actions: actions,
      bottom: bottom,
      systemOverlayStyle:
          context != null ? systemUiOf(context) : systemUi,
    );
  }

  static TextStyle sectionTitleOf(BuildContext context) => TextStyle(
        color: inkOf(context),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      );

  static TextStyle bodyStrongOf(BuildContext context) => TextStyle(
        color: inkOf(context),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle captionOf(BuildContext context) => TextStyle(
        color: inkOf(context).withValues(alpha: 0.48),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle get sectionTitle => const TextStyle(
        color: ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      );

  static TextStyle get bodyStrong => const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get caption => TextStyle(
        color: ink.withValues(alpha: 0.48),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );
}
