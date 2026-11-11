import 'dart:ui';

import 'package:flutter/material.dart';

/// 沉浸封面 / 深色头图上的磨砂圆形导航按钮
class GlassNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color iconColor;
  final double size;

  const GlassNavButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor = Colors.white,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x55FFFFFF), width: 0.8),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: iconColor, size: size * 0.45),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// 沉浸封面上的磨砂胶囊（文案或自定义 child）
class GlassNavChip extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final Color foreground;

  const GlassNavChip({
    super.key,
    this.onPressed,
    this.icon,
    this.label,
    this.child,
    this.foreground = Colors.white,
  }) : assert(child != null || label != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final content = child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 16),
              if (label != null) const SizedBox(width: 6),
            ],
            if (label != null)
              Text(
                label!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
          ],
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.20 : 0.12),
          shape: StadiumBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: enabled ? 0.38 : 0.22),
              width: 0.8,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
