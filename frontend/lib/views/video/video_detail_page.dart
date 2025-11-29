import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/advanced_video_player.dart';
import '../../models/video.dart';
import 'widgets/video_detail_content.dart';
import 'package:go_router/go_router.dart';

class VideoDetailPage extends StatelessWidget {
  final String? id;
  final Video? video;

  const VideoDetailPage({super.key, this.id, this.video}) : assert(id != null || video != null);

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();

    // 如果直接传入了video对象，使用它；否则从provider中查找
    final Video displayVideo = video ?? vp.discover.firstWhere(
      (e) => e.id == id,
      orElse: () => vp.featured.firstWhere(
        (e) => e.id == id,
        orElse: () => vp.follow.firstWhere(
          (e) => e.id == id,
          orElse: () => const Video(id: ''),
        ),
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
                VideoSource(label: '原画', url: displayVideo.videoUrl ?? (displayVideo.coverUrl ?? '')),
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
              onInitialized: () => context.read<VideoProvider>().visit(displayVideo.id),
            ),
          ),
          Expanded(child: VideoDetailContent(video: displayVideo)),
        ],
      ),
    );
  }
}
