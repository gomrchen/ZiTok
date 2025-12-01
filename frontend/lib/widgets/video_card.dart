import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/theme_tokens.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  const VideoCard({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: InkWell(
        borderRadius: Radii.md,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = (w / 16 * 9).clamp(0.0, MediaQuery.of(context).size.height * 0.35);
                return Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Image.network(
                      video.coverUrl ?? 'https://picsum.photos/seed/${video.id}/640/360',
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title ?? '未命名视频', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: [
                      Text('👍 ${video.likes ?? 0} · 👁️ ${video.views ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      const Icon(Icons.thumb_up_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('${video.likes ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}