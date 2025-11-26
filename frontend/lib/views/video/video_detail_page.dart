import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/advanced_video_player.dart';
import '../../models/video.dart';
import 'widgets/video_detail_content.dart';
import 'package:go_router/go_router.dart';

class VideoDetailPage extends StatelessWidget {
  final String id;
  const VideoDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final Video video = vp.discover.firstWhere(
      (e) => e.id == id,
      orElse: () => vp.featured.firstWhere(
        (e) => e.id == id,
        orElse: () => const Video(id: ''),
      ),
    );
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: AdvancedVideoPlayer(
              sources: [
                VideoSource(label: '原画', url: video.videoUrl ?? (video.coverUrl ?? '')),
              ],
              initialLabel: '原画',
              autoPlay: true,
              looping: false,
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              },
              onInitialized: () => context.read<VideoProvider>().visit(video.id),
            ),
          ),
          Expanded(child: VideoDetailContent(video: video)),
        ],
      ),
    );
  }
}
