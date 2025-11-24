import 'package:flutter/material.dart';
import '../../../theme/theme_tokens.dart';

class WorkDetailSheet extends StatelessWidget {
  const WorkDetailSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const WorkDetailSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: Spacing.sm),
                Text('作品详情', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.edit)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Container(height: 160, decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: Radii.md)),
            const SizedBox(height: Spacing.md),
            ListTile(title: const Text('标题'), subtitle: const Text('作品标题展示')),
            ListTile(title: const Text('发布时间'), subtitle: const Text('1970-01-01 08:00:00')),
            ListTile(title: const Text('简介'), subtitle: const Text('作品简介…')),
          ],
        ),
      ),
    );
  }
}