import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 非首页 Tab 统一画布：剧场 / 消息 / 我的 与壳层底色对齐
class ShellSurface {
  static const canvas = Color(0xFFF4F1EC);
  static const ink = Color(0xFF12151C);
  static const muted = Color(0xFF5C6570);
  static const line = Color(0x1412151C);
  static const card = Color(0xFFFBF9F6);
  static const coral = Color(0xFFFF6B4A);
  static const accent = Color(0xFF2ED3BE);

  static const pagePad = 16.0;
  static const sectionGap = 22.0;

  static SystemUiOverlayStyle get systemUi => SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  static AppBar appBar({
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: ink,
      actions: actions,
      bottom: bottom,
      systemOverlayStyle: systemUi,
    );
  }

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
