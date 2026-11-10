import 'package:flutter/material.dart';

import '../home/shell_surface.dart';

/// 设置体系共用视觉件：跟随 Theme（含夜晚模式）
class SettingsChrome {
  static Widget page({
    required String title,
    required Widget body,
    List<Widget>? actions,
  }) {
    return Builder(
      builder: (context) {
        return AnnotatedRegion(
          value: ShellSurface.systemUiOf(context),
          child: Scaffold(
            backgroundColor: ShellSurface.canvasOf(context),
            appBar: ShellSurface.appBar(
              title: title,
              context: context,
              actions: actions,
            ),
            body: body,
          ),
        );
      },
    );
  }

  static Widget section({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Builder(
      builder: (context) {
        final card = ShellSurface.cardOf(context);
        final line = ShellSurface.lineOf(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ShellSurface.sectionTitleOf(context).copyWith(fontSize: 15),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: ShellSurface.captionOf(context)),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line),
                boxShadow: [
                  BoxShadow(
                    color: ShellSurface.inkOf(context).withValues(alpha: 0.04),
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
                          color: line,
                        ),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
    return Builder(
      builder: (context) {
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
                          style: ShellSurface.bodyStrongOf(context).copyWith(
                            color: titleColor ?? ShellSurface.inkOf(context),
                            fontSize: 15,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(subtitle, style: ShellSurface.captionOf(context)),
                        ],
                      ],
                    ),
                  ),
                  if (showChevron)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: ShellSurface.inkOf(context).withValues(alpha: 0.28),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
    return Builder(
      builder: (context) {
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
                    Text(
                      title,
                      style: ShellSurface.bodyStrongOf(context).copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle, style: ShellSurface.captionOf(context)),
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
      },
    );
  }

  static InputDecoration fieldDecoration({
    required BuildContext context,
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    final ink = ShellSurface.inkOf(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: ShellSurface.cardOf(context),
      labelStyle: TextStyle(color: ink.withValues(alpha: 0.55)),
      hintStyle: TextStyle(color: ink.withValues(alpha: 0.35)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ShellSurface.lineOf(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: ShellSurface.lineOf(context)),
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

  static ButtonStyle ghostButtonOf(BuildContext context) => OutlinedButton.styleFrom(
        foregroundColor: ShellSurface.inkOf(context),
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: ShellSurface.lineOf(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      );

  /// 设置体系弹窗：委托全局 [ShellSurface.dialog]
  static AlertDialog dialog({
    required BuildContext context,
    required String title,
    Widget? content,
    List<Widget>? actions,
  }) {
    return ShellSurface.dialog(
      context: context,
      title: title,
      content: content,
      actions: actions,
    );
  }
}
