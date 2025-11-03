import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';
import '../../widgets/advanced_video_player.dart';
import 'widgets/video_detail_content.dart';
import 'package:go_router/go_router.dart';

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
    // 上下分区：上半视频播放器 + 下半内容滚动区
    return Scaffold(
      appBar: null, // 移除顶部标题行
      body: Column(
        children: [
          // 上半：高级视频播放器，宽度自适应
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
                debugPrint('VideoDetailPage: onBack pressed');
                if (Navigator.of(context).canPop()) {
                  debugPrint('VideoDetailPage: Navigator.pop');
                  Navigator.of(context).pop();
                } else {
                  debugPrint('VideoDetailPage: fallback go(/home)');
                  context.go('/home');
                }
              },
            ),
          ),
          // 下半：内容展示区（评论 / 简介 / 笔记）
          Expanded(
            child: VideoDetailContent(video: video),
          ),
        ],
      ),
    );
  }
}