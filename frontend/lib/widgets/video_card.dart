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
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(video.coverUrl, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: [
                      Text('${video.durationSeconds}s · ${video.author}', style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      const Icon(Icons.favorite, size: 16),
                      const SizedBox(width: 4),
                      Text('${video.likes}', style: Theme.of(context).textTheme.bodySmall),
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