import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';

class VideoDetailPage extends StatelessWidget {
  final String id;
  const VideoDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final vp = context.read<VideoProvider>();
    final Video video = vp.discover.firstWhere(
      (e) => e.id == id,
      orElse: () => vp.featured.firstWhere(
        (e) => e.id == id,
        orElse: () => const Video(id: ''),
      ),
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(video.title ?? '未知视频'),
          bottom: const TabBar(tabs: [Tab(text: '详情'), Tab(text: '评论')]),
          actions: [
          IconButton(onPressed: () => context.go('/video/$id/notes'), icon: const Icon(Icons.note))
          ],
        ),
        body: TabBarView(
          children: [
            ListView(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = (w / 16 * 9).clamp(0.0, MediaQuery.of(context).size.height * 0.6);
                    return Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Image.network(
                          video.coverUrl ?? 'https://picsum.photos/seed/${video.id}/800/450',
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: Text(video.title ?? '未知视频'),
                  subtitle: Text('👍 ${video.likes ?? 0} · 👁️ ${video.views ?? 0}'),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: (video.tags).map((t) => Chip(label: Text(t))).toList(),
                  ),
                ),
              ],
            ),
            const Center(child: Text('评论区占位')),
          ],
        ),
      ),
    );
  }
}