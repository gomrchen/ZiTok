import 'package:flutter/material.dart';
import '../../../theme/theme_tokens.dart';

class UploadBox extends StatelessWidget {
  final String title;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  const UploadBox({super.key, required this.title, required this.hint, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Spacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: Radii.md,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: Radii.md,
              border: Border.all(color: cs.primary.withOpacity(0.6), width: 2),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: cs.onSurfaceVariant),
                const SizedBox(height: Spacing.sm),
                Text(hint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}