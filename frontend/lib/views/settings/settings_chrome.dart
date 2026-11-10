import 'package:flutter/material.dart';

import '../home/shell_surface.dart';

/// 设置体系共用视觉件：与 ShellSurface 纸色画布对齐
class SettingsChrome {
  static Widget page({
    required String title,
    required Widget body,
    List<Widget>? actions,
  }) {
    return AnnotatedRegion(
      value: ShellSurface.systemUi,
      child: Scaffold(
        backgroundColor: ShellSurface.canvas,
        appBar: ShellSurface.appBar(title: title, actions: actions),
        body: body,
      ),
    );
  }

  static Widget section({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ShellSurface.sectionTitle.copyWith(fontSize: 15)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: ShellSurface.caption),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: ShellSurface.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ShellSurface.line),
            boxShadow: [
              BoxShadow(
                color: ShellSurface.ink.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 62,
                      color: ShellSurface.line,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget iconBubble({
    required IconData icon,
    required Color tint,
    required Color iconColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }

  static Widget navTile({
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    bool showChevron = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              iconBubble(icon: icon, tint: tint, iconColor: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ShellSurface.bodyStrong.copyWith(
                        color: titleColor ?? ShellSurface.ink,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle, style: ShellSurface.caption),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: ShellSurface.ink.withValues(alpha: 0.28),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget switchTile({
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          iconBubble(icon: icon, tint: tint, iconColor: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ShellSurface.bodyStrong.copyWith(fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: ShellSurface.caption),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: ShellSurface.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  static InputDecoration fieldDecoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: ShellSurface.card,
      labelStyle: TextStyle(color: ShellSurface.ink.withValues(alpha: 0.55)),
      hintStyle: TextStyle(color: ShellSurface.ink.withValues(alpha: 0.35)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ShellSurface.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ShellSurface.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ShellSurface.coral, width: 1.4),
      ),
    );
  }

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
        backgroundColor: ShellSurface.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      );

  static ButtonStyle get ghostButton => OutlinedButton.styleFrom(
        foregroundColor: ShellSurface.ink,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: ShellSurface.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      );
}
