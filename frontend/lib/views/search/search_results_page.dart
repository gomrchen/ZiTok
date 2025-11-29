import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../models/video.dart';

class SearchResultsPage extends StatefulWidget {
  final String keywords;
  //
  const SearchResultsPage({super.key, required this.keywords});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  //页面初始化
  @override
  void initState() {
    super.initState();
    //初始化搜索输入框：将传入的关键词填充到输入框中
    _searchController.text = widget.keywords;

    // 监听滚动事件，实现加载更多
    _scrollController.addListener(() {
      //当滚动距离接近底部（剩余 100 像素）时，触发加载更多
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _loadMore();
      }
    });

    // 初始化搜索
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  //页面销毁
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 执行搜索
  Future<void> _performSearch() async {
    // 从 Provider 中获取 VideoProvider 实例（状态管理核心，存储搜索结果、加载状态等）
    final videoProvider = context.read<VideoProvider>();
    //调用 VideoProvider 的 refreshSearch 方法：清空旧结果 + 重新请求搜索接口（关键词为传入的 widget.keywords）
    await videoProvider.refreshSearch(widget.keywords);
  }

  // 加载更多
  void _loadMore() {
    final videoProvider = context.read<VideoProvider>();
    if (!videoProvider.loadingSearch && videoProvider.searchHasMore) {
      videoProvider.loadMoreSearch();
    }
  }

  // 下拉刷新
  Future<void> _onRefresh() async {
    await _performSearch();
  }

  // 点击「搜索」按钮或输入框回车触发
  void _handleSearch() {
    String query = _searchController.text.trim(); // 获取输入框文本（去除前后空格）
    if (query.isNotEmpty) {
      // 非空校验
      // 用 GoRouter 跳转到当前搜索结果页（携带新关键词），相当于「重新搜索」
      context.push('/search/results?keywords=$query');
    }
  }

  // 处理返回
  void _handleBack() {
    context.pop();
  }

  // 打开视频详情
  void _openVideoDetails(String videoId) {
    context.push('/video/$videoId');
  }

  //UI构建
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.surfaceContainerHighest),
                ),
              ),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _handleBack,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: Spacing.sm),
                  // 搜索输入框
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.sm,
                            ),
                            child: Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '搜索视频、用户或话题',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onSubmitted: (_) => _handleSearch(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 搜索按钮
                  Padding(
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    child: TextButton(
                      onPressed: _handleSearch,
                      child: Text(
                        '搜索',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 搜索结果区域
            Expanded(
              child: Consumer<VideoProvider>(
                builder: (context, videoProvider, child) {
                  // 转换搜索结果为Video模型列表
                  List<Video> videoList = [];
                  try {
                    // 过滤并转换有效的Video对象
                    videoList = videoProvider.searchResults
                        .where((item) => item is Video)
                        .cast<Video>()
                        .toList();
                  } catch (e) {
                    print('Error converting search results to Video list: $e');
                    videoList = [];
                  }

                  // 显示搜索结果标题
                  return Column(
                    children: [
                      Expanded(
                        child: videoList.isEmpty
                            ? Center(
                                child: videoProvider.loadingSearch
                                    ? const CircularProgressIndicator()
                                    : ElevatedButton(
                                        onPressed: _onRefresh,
                                        child: const Text('重新搜索'),
                                      ),
                              )
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                child: CustomScrollView(
                                  slivers: [
                                    NotificationListener<ScrollNotification>(
                                      onNotification: (n) {
                                        if (n.metrics.pixels >=
                                            n.metrics.maxScrollExtent - 200) {
                                          _loadMore();
                                        }
                                        return false;
                                      },
                                      child: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, i) {
                                            if (i < videoList.length) {
                                              print(
                                                'videoList.length=${videoList.length}',
                                              );
                                              print('i=$i');
                                              final v = videoList[i];
                                              return _FeaturedListItem(
                                                video: v,
                                                onTap: () =>
                                                    _openVideoDetails(v.id),
                                              );
                                            }
                                            return videoProvider.searchHasMore
                                                ? const Padding(
                                                    padding: EdgeInsets.all(
                                                      Spacing.md,
                                                    ),
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  )
                                                : Container();
                                          },
                                          childCount:
                                              videoList.length +
                                              (videoProvider.searchHasMore
                                                  ? 1
                                                  : 0), //
                                        ),
                                      ),
                                    ),
                                    const SliverPadding(
                                      padding: EdgeInsets.only(
                                        bottom: Spacing.xl,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedListItem extends StatelessWidget {
  final dynamic video; // 使用轻耦合以避免空列表时构造报错
  final VoidCallback? onTap;
  const _FeaturedListItem({required this.video, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            // 视频封面
            ClipRRect(
              borderRadius: Radii.md,
              child: Image.network(
                video.coverUrl,
                width: 120,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 72,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.video_library_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 视频标题
                  Text(
                    video.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  // 视频描述
                  Text(
                    video.intro ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  // 统计信息：收藏数和评论数
                  Row(
                    children: [
                      Text(
                        'likes-${video.likes ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        'comments-${video.comments ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
