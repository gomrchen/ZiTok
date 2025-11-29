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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度决定是否显示文本标签
        // 每个步骤节点大约需要 80-100px（图标+文本），连接线约 20px
        // 4个步骤需要约 400px，如果宽度不足则只显示图标
        final showLabels = constraints.maxWidth >= 360;

        return Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              Flexible(
                flex: 0,
                child: _StepNode(
                  icon: steps[i].icon,
                  label: steps[i].label,
                  active: i == currentIndex,
                  done: i < currentIndex,
                  onTap: () => onTap(i),
                  showLabel: showLabels,
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                    color: i < currentIndex ? cs.primary : cs.outlineVariant,
                  ),
                ),
            ]
          ],
        );
      },
    );
  }
}

class _StepNode extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool done;
  final VoidCallback onTap;
  final bool showLabel;
  const _StepNode({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
    required this.onTap,
    this.showLabel = true,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active ? cs.primary : (done ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHighest);
    final fg = active ? cs.onPrimary : (done ? cs.primary : cs.onSurfaceVariant);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.md,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: Spacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: bg, borderRadius: Radii.md, border: Border.all(color: cs.outlineVariant)),
                child: Icon(icon, color: fg, size: 18),
              ),
              if (showLabel) ...[
                const SizedBox(width: Spacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}