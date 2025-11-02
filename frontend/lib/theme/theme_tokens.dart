import 'package:flutter/material.dart';

class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Radii {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16));
}

class AppColors {
  final Color primary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const AppColors({
    required this.primary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  static const AppColors light = AppColors(
    // 设计主色：清新的青绿色，用于主按钮与强调元素
    primary: Color(0xFF2ED3BE),
    // 背景采用更接近设计稿的浅灰白
    background: Color(0xFFF7F9FC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    // 次要强调色，略深的青绿用于链接与装饰元素
    accent: Color(0xFF14B8A6),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFF2ED3BE),
    background: Color(0xFF0B0F1A),
    surface: Color(0xFF111827),
    textPrimary: Color(0xFFE5E7EB),
    textSecondary: Color(0xFF9CA3AF),
    accent: Color(0xFF14B8A6),
  );
}

class TypographyTokens {
  // 标题略大以贴合登录/欢迎页主标题视觉
  static const TextStyle h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w700);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const TextStyle caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
}