import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';

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
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
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
    String query = _searchController.text.trim();// 获取输入框文本（去除前后空格）
    if (query.isNotEmpty) {// 非空校验
    // 用 GoRouter 跳转到当前搜索结果页（携带新关键词），相当于「重新搜索」
      context.push('/search/results?keywords=$query');
    }
  }

  // 处理返回按钮点击
  void _handleBack() {
    context.pop();
  }

  // 打开视频详情
  void _openVideoDetails(String videoId) {
    context.push('/video/$videoId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部搜索栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
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
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: Spacing.sm),
                            child: Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: '搜索视频、用户或话题',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
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
                      child: const Text(
                        '搜索',
                        style: TextStyle(
                          color: Colors.black,
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
                  if (videoProvider.loadingSearch && videoProvider.searchResults.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (videoProvider.searchResults.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('未找到相关内容'),
                          SizedBox(height: 8),
                          Text('试试其他关键词吧', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _buildSearchResultsList(videoProvider),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建搜索结果列表
  Widget _buildSearchResultsList(VideoProvider videoProvider) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              '搜索结果: ${widget.keywords}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = videoProvider.searchResults[index];
              return _SearchResultItem(
                video: video,
                onTap: () => _openVideoDetails(video.id),
              );
            },
            childCount: videoProvider.searchResults.length,
          ),
        ),
        if (videoProvider.loadingSearch && videoProvider.searchResults.isNotEmpty) 
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (!videoProvider.searchHasMore && videoProvider.searchResults.isNotEmpty) 
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('没有更多内容了', style: TextStyle(color: Colors.grey))),
            ),
          ),
      ],
    );
  }
}

// 搜索结果项组件
class _SearchResultItem extends StatelessWidget {
  final dynamic video;
  final VoidCallback onTap;
  //
  const _SearchResultItem({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            // 视频封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video.coverUrl,
                width: 120,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: Spacing.md),
            // 视频信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${video.authorName} · ${video.viewCount}次播放',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
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
