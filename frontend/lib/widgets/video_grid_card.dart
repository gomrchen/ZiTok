import 'package:flutter/material.dart';
import '../models/video.dart';
import '../theme/theme_tokens.dart';

class VideoGridCard extends StatelessWidget {
  final Video video;
  final VoidCallback? onTap;
  const VideoGridCard({super.key, required this.video, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.md,
              child: Image.network(video.coverUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}