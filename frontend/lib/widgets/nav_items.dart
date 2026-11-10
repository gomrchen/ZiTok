import 'package:flutter/material.dart';
import '../theme/theme_tokens.dart';

/// 底部普通导航项
class NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  /// 首页沉浸底栏：未选中用浅色，保证黑底可读
  final bool onDark;
  const NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.onDark = false,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected
        ? cs.primary
        : (onDark ? Colors.white70 : cs.onSurfaceVariant);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, height: 1.0)),
          ],
        ),
      ),
    );
  }
}

/// 底部“消息”项，带未读红点
class MessagesItem extends StatelessWidget {
  final String label;
  final bool selected;
  final int unread;
  final VoidCallback onTap;
  const MessagesItem({
    super.key,
    required this.label,
    required this.selected,
    required this.unread,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline, color: color, size: 22),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: color, fontSize: 12, height: 1.0)),
              ],
            ),
            if (unread > 0)
              Positioned(
                right: -6,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
