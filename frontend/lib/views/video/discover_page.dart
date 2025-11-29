import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/video.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../services/video/video_preload_manager.dart';
import '../../widgets/video_stats.dart';
import 'featured_page.dart';
import 'widgets/md_notes_sheet.dart';
import '../../widgets/comment_sheet.dart';
import 'video_detail_page.dart';
import 'dart:async';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tab;
  // 移除_controllers map，由_FullScreenVideoItem独立管理自己的controller
  // 这样避免了重复创建和dispose冲突的问题
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VideoProvider>();
      if (vp.discover.isEmpty) {
        vp.refreshDiscover();
      }
      if (vp.featured.isEmpty) {
        vp.refreshFeatured();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台时暂停所有视频
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAllVideos();
    }
    // 恢复播放由各_FullScreenVideoItem通过自己的WidgetsBindingObserver处理
  }

  void _onTabChanged() {
    // Tab切换时暂停非当前页的视频
    if (_tab.index != 1) {
      _pauseAllVideos();
    }
  }

  void _pauseAllVideos() {
    // 通过PreloadManager暂停所有视频
    _preloadManager.pauseAll();
  }

  void _onIndexChanged(int index) {
    // 更新预加载状态，实际播放由_FullScreenVideoItem管理
    _preloadManager.updateCurrentIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();

    // 更新预加载列表
    if (vp.discover.isNotEmpty) {
      final preloadItems = vp.discover.asMap().entries.map((e) => PreloadItem(
        videoId: e.value.id,
        videoUrl: e.value.videoUrl ?? '',
        index: e.key,
      )).toList();
      _preloadManager.setVideoList(preloadItems);
    }

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: cs.surface,
        // 添加搜索输入框
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          child: GestureDetector(
            onTap: _onSearchTap,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: cs.onSurfaceVariant,
                    size: 18,
                  ), // 搜索图标
                  const SizedBox(width: 8),
                  Text(
                    '搜索视频、用户或话题', // placeholder
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '精选'),
            Tab(text: '推荐'),
          ],
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          dividerColor: cs.outline,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          const FeaturedBody(),
          _RecommendFullScreen(
            videos: vp.discover,
            isLoading: vp.loadingDiscover,
            onRetry: () => vp.refreshDiscover(),
            onIndexChanged: _onIndexChanged,
          ),
        ],
      ),
    );
  }
}

class _RecommendFullScreen extends StatefulWidget {
  final List videos;
  final ValueChanged<int> onIndexChanged;
  final bool isLoading;
  final VoidCallback onRetry;
  const _RecommendFullScreen({
    required this.videos,
    required this.onIndexChanged,
    required this.isLoading,
    required this.onRetry,
  });
  @override
  State<_RecommendFullScreen> createState() => _RecommendFullScreenState();
}

class _RecommendFullScreenState extends State<_RecommendFullScreen> {
  late final PageController _pageController;
  List<dynamic> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  Future<void> _fetch({bool refresh = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    if (refresh) {
      _page = 1;
      _items = [];
      _hasMore = true;
      _error = null;
    }
    try {
      final repo = context.read<VideoProvider>().repo;
      final res = await repo.fetchDiscover(VideoQuery(page: _page, pageSize: 10));
      _items.addAll(res.items);
      _hasMore = res.hasMore;
      _page += 1;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(refresh: true));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('推荐加载失败'), const SizedBox(height: 8), ElevatedButton(onPressed: () => _fetch(refresh: true), child: const Text('重试'))]));
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('暂无推荐内容'), const SizedBox(height: 8), ElevatedButton(onPressed: () => _fetch(refresh: true), child: const Text('重新加载'))]),
      );
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _items.length,
      onPageChanged: (i) {
        widget.onIndexChanged(i);
        if (_hasMore && i >= _items.length - 2) _fetch();
      },
      itemBuilder: (context, i) {
        final v = _items[i];
        return _FullScreenVideoItem(video: v);
      },
    );
  }
}

class _FullScreenVideoItem extends StatefulWidget {
  final dynamic video;
  const _FullScreenVideoItem({required this.video});
  @override
  State<_FullScreenVideoItem> createState() => _FullScreenVideoItemState();
}

class _FullScreenVideoItemState extends State<_FullScreenVideoItem> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isBuffering = false;
  String? _error;
  bool _wasPlayingBeforePause = false;
  bool _showControls = false;
  Timer? _hideControlsTimer;
  bool _isDescriptionExpanded = false;
  bool _isPreloadedController = false; // 标记是否使用预加载的controller
  bool _isDisposed = false; // 标记是否已dispose

  // 淡入动画控制器
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // 顶部栏：菜单展开占位
  void _onMenu() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('菜单功能待接入'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  // 顶部栏：搜索占位
  void _onSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('搜索功能待接入'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  // 附件：打开笔记弹窗
  void _openNotesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return MdNotesBottomSheet(videoId: widget.video.id);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化淡入动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _initController();
  }

  Future<void> _initController() async {
    if (_isDisposed) return;

    final url = widget.video.videoUrl ?? '';
    if (url.isEmpty) {
      if (mounted) setState(() => _error = '视频地址为空');
      return;
    }

    // 尝试从预加载管理器获取
    final preloadManager = VideoPreloadManager.instance;
    final preloaded = preloadManager.getPreloadedController(widget.video.id);

    if (preloaded != null && preloaded.value.isInitialized) {
      _controller = preloaded;
      _isPreloadedController = true;
      if (mounted && !_isDisposed) {
        setState(() => _initialized = true);
        _controller!.setLooping(true);
        _controller!.addListener(_onControllerUpdate);
        _controller!.play();
        // 启动淡入动画
        _fadeController.forward();
        context.read<VideoProvider>().visit(widget.video.id);
      }
      debugPrint('_FullScreenVideoItem: using preloaded controller');
      return;
    }

    // 创建新控制器
    final newController = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = newController;
    _isPreloadedController = false;
    _controller!.addListener(_onControllerUpdate);

    try {
      await newController.initialize();
      // 初始化完成后再次检查状态
      if (mounted && !_isDisposed && _controller == newController) {
        setState(() => _initialized = true);
        _controller!.setLooping(true);
        _controller!.play();
        // 启动淡入动画
        _fadeController.forward();
        context.read<VideoProvider>().visit(widget.video.id);
      } else if (_controller != newController) {
        // controller已被替换，dispose旧的
        newController.dispose();
      }
    } catch (e) {
      debugPrint('FullScreenVideoItem: initialize error $e');
      if (mounted && !_isDisposed) setState(() => _error = '视频加载失败');
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _isDisposed || _controller == null) return;

    final wasBuffering = _isBuffering;
    final isBufferingNow = _controller!.value.isBuffering;

    if (wasBuffering != isBufferingNow) {
      setState(() => _isBuffering = isBufferingNow);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || _isDisposed) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasPlayingBeforePause = _controller!.value.isPlaying;
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _controller!.play();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideControlsTimer?.cancel();
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);

    if (_controller != null) {
      _controller!.removeListener(_onControllerUpdate);
      // 只有非预加载的controller才需要dispose
      // 预加载的controller由PreloadManager管理
      if (!_isPreloadedController) {
        _controller!.dispose();
      }
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || _isDisposed) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });
    _resetHideControlsTimer();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDisposed && _controller != null && _controller!.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onVideoTap() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideControlsTimer();
    }
  }

  void _openVideoDetail() {
    // 暂停当前视频
    _controller?.pause();

    // 导航到视频详情页
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailPage(video: widget.video),
      ),
    ).then((_) {
      // 返回时恢复播放
      if (mounted && !_isDisposed && _controller != null) {
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频播放器
        _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initController,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : _initialized && _controller != null
                ? FadeTransition(
                    opacity: _fadeAnimation,
                    child: GestureDetector(
                      onTap: _onVideoTap,
                      child: Container(
                        color: Colors.black,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),

        // 缓冲指示器
        if (_initialized && _isBuffering)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),

        // 播放/暂停按钮overlay
        if (_initialized && _showControls && !_isBuffering && _controller != null)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        // 顶部功能栏（左：附件；右：搜索、菜单）
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          top: MediaQuery.of(context).padding.top + Spacing.xs,
          child: Row(
            children: [
              // 附件标志 icon（圆形半透明背景）
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33000000),
                ),
                child: IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.white),
                  tooltip: '查看笔记',
                  onPressed: _openNotesSheet,
                ),
              ),
              const Spacer(),
              // 搜索 icon
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33000000),
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  tooltip: '搜索',
                  onPressed: _onSearch,
                ),
              ),
              // 菜单 icon
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33000000),
                ),
                child: IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  tooltip: '菜单',
                  onPressed: _onMenu,
                ),
              ),
            ],
          ),
        ),
        // 右侧操作栏
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).size.height * 0.15,
          child: Column(
            children: [
              // 创作者头像（带+关注）
              _PublisherAvatar(
                uid: widget.video.uid,
                avatarUrl: null, // TODO: 添加头像URL字段到Video模型
              ),
              const SizedBox(height: 24),
              // 点赞
              _LikeActionIcon(
                initialCount: widget.video.likes ?? 0,
                onTap: () =>
                    context.read<VideoProvider>().like(widget.video.id),
              ),
              const SizedBox(height: 16),
              // 评论
              _ActionIcon(
                icon: Icons.chat_bubble_outline,
                label: formatCountCompact(widget.video.commentCount),
                onTap: () {
                  showCommentsSheet(context, videoId: widget.video.id);
                },
              ),
              const SizedBox(height: 16),
              // 收藏
              _CollectActionIcon(
                initialCount: widget.video.stars ?? 0,
                onTap: () => context.read<VideoProvider>().collect(widget.video.id),
              ),
              // 注：转发按钮按需求不予实现，但保留注释说明
              // const SizedBox(height: 16),
              // _ActionIcon(
              //   icon: Icons.share_outlined,
              //   label: '',
              //   onTap: _onShare,
              // ),
            ],
          ),
        ),
        // 底部文案（添加渐变背景确保始终可见）
        Positioned(
          left: 0,
          right: 80,
          bottom: 50,
          child: Container(
            padding: EdgeInsets.only(
              left: Spacing.md,
              right: Spacing.md,
              top: 40,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${widget.video.uid ?? '未知作者'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                  child: Text(
                    '${widget.video.intro ?? ''}',
                    maxLines: _isDescriptionExpanded ? null : 2,
                    overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                VideoStatsText(
                  commentCount: widget.video.commentCount,
                  likeCount: widget.video.likes,
                  isDark: true,
                ),
              ],
            ),
          ),
        ),

        // 查看详情按钮（底部中央）
        if (_initialized)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _openVideoDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        '查看详情',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 底部进度条
        if (_initialized && _controller != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VideoProgressBar(controller: _controller!),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionIcon({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x33000000),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        ],
      ],
    );
  }
}

/// 创作者头像组件（带+关注按钮）
class _PublisherAvatar extends StatefulWidget {
  final String? uid;
  final String? avatarUrl;
  const _PublisherAvatar({this.uid, this.avatarUrl});
  @override
  State<_PublisherAvatar> createState() => _PublisherAvatarState();
}

class _PublisherAvatarState extends State<_PublisherAvatar> {
  DateTime? _lastClickTime;
  bool _isFollowed = false;

  void _handleTap() {
    // 防抖处理：300ms内只响应一次点击
    final now = DateTime.now();
    if (_lastClickTime != null && now.difference(_lastClickTime!).inMilliseconds < 300) {
      return;
    }
    _lastClickTime = now;

    // TODO: 跳转到创作者主页 /publisher/:id
    if (widget.uid != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('跳转到创作者主页: ${widget.uid}'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // context.go('/publisher/${widget.uid}');
    }
  }

  void _handleFollow() {
    // 防抖处理
    final now = DateTime.now();
    if (_lastClickTime != null && now.difference(_lastClickTime!).inMilliseconds < 300) {
      return;
    }
    _lastClickTime = now;

    setState(() {
      _isFollowed = !_isFollowed;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFollowed ? '已关注' : '已取消关注'),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          children: [
            // 圆形头像
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                color: Colors.grey.shade300,
              ),
              child: ClipOval(
                child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? Image.network(
                        widget.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.person, size: 30, color: Colors.grey.shade600);
                        },
                      )
                    : Icon(Icons.person, size: 30, color: Colors.grey.shade600),
              ),
            ),
            // 右上角+号关注按钮
            if (!_isFollowed)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _handleFollow,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF2D55), // 抖音红色
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 收藏图标（星形）带动画与计数
class _CollectActionIcon extends StatefulWidget {
  final int initialCount;
  final VoidCallback? onTap;
  const _CollectActionIcon({required this.initialCount, this.onTap});
  @override
  State<_CollectActionIcon> createState() => _CollectActionIconState();
}

class _CollectActionIconState extends State<_CollectActionIcon> with SingleTickerProviderStateMixin {
  late int count;
  bool collected = false;
  bool loading = false;
  late AnimationController pulse;

  @override
  void initState() {
    super.initState();
    count = widget.initialCount;
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (loading) return;

    setState(() {
      loading = true;
      collected = !collected;
      count += collected ? 1 : -1;
    });

    pulse.forward(from: 0);

    try {
      if (widget.onTap != null) {
        widget.onTap!();
      }
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // 失败回滚
      if (mounted) {
        setState(() {
          collected = !collected;
          count += collected ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: loading ? null : _toggle,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 圆形半透明底
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33000000),
                  ),
                ),
                // 星形图标（缩放动画）
                if (!loading)
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                      CurvedAnimation(parent: pulse, curve: Curves.easeOut),
                    ),
                    child: Icon(
                      collected ? Icons.star : Icons.star_border,
                      color: collected ? const Color(0xFFFFD700) : Colors.white,
                      size: 28,
                    ),
                  ),
                // 加载指示器
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formatCount(count),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  String _formatCount(int c) {
    if (c >= 100000000) return '${(c / 100000000).toStringAsFixed(1)}亿';
    if (c >= 10000) return '${(c / 10000).toStringAsFixed(1)}万';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}k';
    return '$c';
  }
}

/// 点赞图标（红心）带动画与计数（300~450ms）
class _LikeActionIcon extends StatefulWidget {
  final int initialCount;
  final VoidCallback? onTap;
  const _LikeActionIcon({required this.initialCount, this.onTap});
  @override
  State<_LikeActionIcon> createState() => _LikeActionIconState();
}

class _LikeActionIconState extends State<_LikeActionIcon>
    with TickerProviderStateMixin {
  late int count;
  bool liked = false;
  late AnimationController pulse; // 心形缩放
  late AnimationController burst; // 粒子爆裂

  @override
  void initState() {
    super.initState();
    count = widget.initialCount;
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    pulse.dispose();
    burst.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      liked = !liked;
      count += liked ? 1 : -1;
    });
    pulse.forward(from: 0);
    if (liked) {
      burst.forward(from: 0);
    }
    if (widget.onTap != null) widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _toggle,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 粒子心形（6个方向）
                AnimatedBuilder(
                  animation: burst,
                  builder: (context, child) {
                    final t = burst.value; // 0~1
                    final radius = 18 * t;
                    final opacity = (1 - t).clamp(0.0, 1.0);
                    Color c = Colors.red.withValues(alpha: opacity);
                    return Stack(children: [
                      _particle(Offset(0, -radius), c),
                      _particle(Offset(0, radius), c),
                      _particle(Offset(radius, 0), c),
                      _particle(Offset(-radius, 0), c),
                      _particle(Offset(radius * 0.7, -radius * 0.7), c),
                      _particle(Offset(-radius * 0.7, -radius * 0.7), c),
                    ]);
                  },
                ),
                // 圆形半透明底
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33000000),
                  ),
                ),
                // 心形图标（缩放/颜色过渡）
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                    CurvedAnimation(parent: pulse, curve: Curves.easeOut),
                  ),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.red : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(_formatCount(count), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
      ],
    );
  }

  Widget _particle(Offset offset, Color color) {
    return Transform.translate(
      offset: offset,
      child: Icon(Icons.favorite, color: color, size: 10),
    );
  }

  String _formatCount(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}k';
    return '$c';
  }
}

/// 视频进度条组件
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoProgressBar({required this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!_isDragging && mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final position = _isDragging
        ? Duration(milliseconds: (_dragValue * widget.controller.value.duration.inMilliseconds).toInt())
        : widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // 进度条直接浮在视频上方，无背景，与视频一体化
    return Container(
      // 底部安全区域内边距
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条主体
          LayoutBuilder(
            builder: (context, constraints) {
              final sliderWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isDragging = true;
                    _dragValue = progress.clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragUpdate: (details) {
                  if (!mounted) return;
                  setState(() {
                    final localX = details.localPosition.dx;
                    _dragValue = (localX / sliderWidth).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (details) {
                  if (!mounted) return;
                  final newPosition = Duration(
                    milliseconds: (_dragValue * duration.inMilliseconds).toInt(),
                  );
                  widget.controller.seekTo(newPosition);
                  setState(() {
                    _isDragging = false;
                  });
                },
                child: Container(
                  height: 24, // 触摸区域高度
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // 进度条背景轨道（半透明白色）
                      Container(
                        height: _isDragging ? 4 : 2, // 拖动时变粗
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 已播放进度（白色）
                      FractionallySizedBox(
                        widthFactor: _isDragging ? _dragValue : progress,
                        child: Container(
                          height: _isDragging ? 4 : 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // 拖动指示器
                      if (_isDragging)
                        Positioned(
                          left: sliderWidth * _dragValue - 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 时间显示（仅在拖动时显示）
          if (_isDragging)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
