import 'package:flutter/material.dart';
import '../../../theme/theme_tokens.dart';

class StepMeta {
  final IconData icon;
  final String label;
  const StepMeta({required this.icon, required this.label});
}

class StepIndicator extends StatelessWidget {
  final List<StepMeta> steps;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const StepIndicator({super.key, required this.steps, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepNode(
            icon: steps[i].icon,
            label: steps[i].label,
            active: i == currentIndex,
            done: i < currentIndex,
            onTap: () => onTap(i),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                color: i < currentIndex ? cs.primary : cs.outlineVariant,
              ),
            ),
        ]
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool done;
  final VoidCallback onTap;
  const _StepNode({required this.icon, required this.label, required this.active, required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active ? cs.primary : (done ? cs.primary.withOpacity(0.2) : cs.surfaceContainerHighest);
    final fg = active ? cs.onPrimary : (done ? cs.primary : cs.onSurfaceVariant);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bg, borderRadius: Radii.md, border: Border.all(color: cs.outlineVariant)),
              child: Icon(icon, color: fg, size: 18),
            ),
            const SizedBox(width: Spacing.sm),
            Text(label, style: TextStyle(color: fg, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}