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
        orElse: () => const Video(
          id: '',
          title: '未知视频',
          coverUrl: 'https://picsum.photos/seed/unknown/640/360',
          videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          durationSeconds: 0,
          author: '未知',
          likes: 0,
          tags: [],
        ),
      ),
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(video.title),
          bottom: const TabBar(tabs: [Tab(text: '详情'), Tab(text: '评论')]),
          actions: [
          IconButton(onPressed: () => context.go('/video/$id/notes'), icon: const Icon(Icons.note))
          ],
        ),
        body: TabBarView(
          children: [
            ListView(
              children: [
                AspectRatio(aspectRatio: 16/9, child: Image.network(video.coverUrl, fit: BoxFit.cover)),
                ListTile(title: Text(video.title), subtitle: Text('${video.durationSeconds}s · ${video.author}')),
                Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, children: video.tags.map((t) => Chip(label: Text(t))).toList())),
              ],
            ),
            const Center(child: Text('评论区占位')),
          ],
        ),
      ),
    );
  }
}