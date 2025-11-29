import 'package:flutter/material.dart';
import '../models/video.dart';
import 'video_card.dart';
import '../theme/theme_tokens.dart';

class VideoListWidget extends StatefulWidget {
  final List<Video> videos;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRefresh;
  final VoidCallback? onLoadMore;
  final ValueChanged<Video>? onVideoTap;

  const VideoListWidget({
    super.key,
    required this.videos,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
    this.errorMessage,
    this.onRefresh,
    this.onLoadMore,
    this.onVideoTap,
  });

  @override
  State<VideoListWidget> createState() => _VideoListWidgetState();
}

class _VideoListWidgetState extends State<VideoListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // 当滚动到底部附近时触发加载更多
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !widget.isLoadingMore &&
          widget.hasMore) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh?.call();
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading && widget.videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: Spacing.md),
            Text(widget.errorMessage ?? '加载失败，请重试'),
            const SizedBox(height: Spacing.md),
            ElevatedButton(
              onPressed: widget.onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (widget.videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: Spacing.md),
            const Text('暂无视频数据'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount:
          widget.videos.length +
          (widget.hasMore || widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.videos.length) {
          // 加载更多的指示器
          if (widget.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return const SizedBox();
        }

        final video = widget.videos[index];
        return VideoCard(
          video: video,
          onTap: () => widget.onVideoTap?.call(video),
        );
      },
    );
  }
}
