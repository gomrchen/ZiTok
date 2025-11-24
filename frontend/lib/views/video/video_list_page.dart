import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../widgets/video_list_widget.dart';
import '../../models/video.dart';

class VideoListPage extends StatefulWidget {
  final bool useSearch; // 是否使用搜索数据
  final String? searchKeyword;

  const VideoListPage({super.key, this.useSearch = false, this.searchKeyword});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  @override
  void initState() {
    super.initState();
    // 初始加载数据
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant VideoListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当搜索关键词变化时重新加载数据
    if (widget.searchKeyword != oldWidget.searchKeyword) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final videoProvider = context.read<VideoProvider>();
    if (widget.useSearch && widget.searchKeyword != null) {
      videoProvider.refreshSearch(widget.searchKeyword!);
    } else {
      videoProvider.refreshDiscover();
    }
  }

  void _onRefresh() {
    _loadInitialData();
  }

  void _onLoadMore() {
    final videoProvider = context.read<VideoProvider>();
    if (widget.useSearch) {
      videoProvider.loadMoreSearch();
    } else {
      videoProvider.loadMoreDiscover();
    }
  }

  void _onVideoTap(Video video) {
    // 导航到视频详情页
    Navigator.of(context).pushNamed('/video/${video.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.useSearch && widget.searchKeyword != null
              ? '搜索：${widget.searchKeyword}'
              : '视频列表',
        ),
      ),
      body: Consumer<VideoProvider>(
        builder: (context, videoProvider, child) {
          // 根据是否使用搜索来选择相应的数据和状态
          final videos = widget.useSearch
              ? videoProvider.searchResults
              : videoProvider.discover;
          final isLoading = widget.useSearch
              ? videoProvider.loadingSearch
              : videoProvider.loadingDiscover;
          final isLoadingMore =
              isLoading; // 复用loading状态，因为VideoProvider中没有专门的isLoadingMore字段
          final hasMore = widget.useSearch
              ? videoProvider.searchHasMore
              : videoProvider.discoverHasMore;
          final hasError = false; // VideoProvider中没有明确的error字段
          final errorMessage = null; // 暂不处理错误信息

          return VideoListWidget(
            videos: videos,
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            hasMore: hasMore,
            hasError: hasError,
            errorMessage: errorMessage,
            onRefresh: _onRefresh,
            onLoadMore: _onLoadMore,
            onVideoTap: _onVideoTap,
          );
        },
      ),
    );
  }
}
