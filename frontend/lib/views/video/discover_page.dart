import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import '../../providers/video_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../services/video/video_preload_manager.dart';
import '../../services/video_playback_manager.dart';
import '../../services/user_service.dart';
import '../../app.dart';
import '../../utils/url_utils.dart';
import '../../widgets/video_stats.dart';
import '../../widgets/animated_like_button.dart';
import '../../utils/app_config.dart';
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
    // Tab切换时暂停所有视频（无论切换到哪个Tab）
    _pauseAllVideos();
  }

  void _pauseAllVideos() {
    // 通过PreloadManager和PlaybackManager暂停所有视频
    _preloadManager.pauseAll();
    VideoPlaybackManager.instance.pauseAll();
  }

  void _onIndexChanged(int index) {
    // 更新预加载状态，实际播放由_FullScreenVideoItem管理
    _preloadManager.updateCurrentIndex(index);
  }

  void _onSearchTap() {
    // 进入搜索页前暂停视频
    VideoPlaybackManager.instance.pauseAll();
    context.push('/search');
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final cs = Theme.of(context).colorScheme;

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
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: cs.surface,
        // 搜索输入框
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '搜索视频、用户或话题',
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

  /// 是否正在加载中
  bool _isFetching = false;

  Future<void> _fetch({bool refresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    final vp = context.read<VideoProvider>();
    if (refresh) {
      await vp.refreshRecommend();
    } else {
      await vp.loadMoreRecommend();
    }

    _isFetching = false;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VideoProvider>();
      if (vp.recommend.isEmpty) {
        _fetch(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 将虚拟索引转换为实际列表索引（循环）
  int _toRealIndex(int virtualIndex, int listLength) {
    if (listLength == 0) return 0;
    return virtualIndex % listLength;
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final items = vp.recommend;
    final loading = vp.loadingRecommend;

    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('暂无推荐内容'), const SizedBox(height: 8), ElevatedButton(onPressed: () => _fetch(refresh: true), child: const Text('重新加载'))]),
      );
    }

    // 使用无限滚动模式：itemCount 为 null 表示无限
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      // 不设置 itemCount，允许无限滚动
      onPageChanged: (virtualIdx) {
        final realIndex = _toRealIndex(virtualIdx, items.length);
        widget.onIndexChanged(realIndex);

        // 当虚拟索引接近当前已加载数据的边界时，尝试加载更多
        // 这里用虚拟索引来判断，确保每次接近"边界"都会触发
        final distanceToEnd = items.length - (virtualIdx % items.length) - 1;
        if (distanceToEnd <= 3 && !loading) {
          _fetch();
        }
      },
      itemBuilder: (context, virtualIdx) {
        final realIndex = _toRealIndex(virtualIdx, items.length);
        final v = items[realIndex];
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

  // 作者信息（通过API获取）
  String? _fetchedAuthorName;
  bool _fetchingAuthor = false;

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
    _fetchAuthorInfo();
  }

  /// 获取作者信息
  Future<void> _fetchAuthorInfo() async {
    if (_fetchingAuthor || widget.video.uid == null) return;
    // 如果视频已有作者名称，不需要再获取
    if (widget.video.authorName != null && widget.video.authorName!.isNotEmpty) {
      return;
    }

    _fetchingAuthor = true;
    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.video.uid);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final userName = (userData['username'] ?? userData['nickname'] ?? userData['name'])?.toString();

        if (userName != null && userName.isNotEmpty && mounted && !_isDisposed) {
          setState(() {
            _fetchedAuthorName = userName;
          });
        }
      }
    } catch (e) {
      AppConfig.log('_FullScreenVideoItem: fetch author error: $e');
    } finally {
      _fetchingAuthor = false;
    }
  }

  /// 获取有效的作者名称
  String get _effectiveAuthorName {
    if (widget.video.authorName != null && widget.video.authorName!.isNotEmpty) {
      return widget.video.authorName!;
    }
    if (_fetchedAuthorName != null && _fetchedAuthorName!.isNotEmpty) {
      return _fetchedAuthorName!;
    }
    return widget.video.uid ?? '未知作者';
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
        // 注册到全局播放管理器
        VideoPlaybackManager.instance.register(_controller!);
        VideoPlaybackManager.instance.markAsPlaying(_controller!);
        _controller!.play();
        // 启动淡入动画
        _fadeController.forward();
        context.read<VideoProvider>().visit(widget.video.id);
      }
      AppConfig.videoLog('_FullScreenVideoItem: using preloaded controller');
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
        // 注册到全局播放管理器
        VideoPlaybackManager.instance.register(_controller!);
        VideoPlaybackManager.instance.markAsPlaying(_controller!);
        _controller!.play();
        // 启动淡入动画
        _fadeController.forward();
        context.read<VideoProvider>().visit(widget.video.id);
      } else if (_controller != newController) {
        // controller已被替换，dispose旧的
        newController.dispose();
      }
    } catch (e) {
      AppConfig.videoLog('FullScreenVideoItem: initialize error $e');
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
      // 从全局播放管理器注销
      VideoPlaybackManager.instance.unregister(_controller!);
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
    // 通过全局管理器暂停当前视频
    VideoPlaybackManager.instance.pauseCurrent();

    // 导航到视频详情页
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoDetailPage(video: widget.video),
      ),
    ).then((_) {
      // 返回时恢复播放（如果页面仍然活跃）
      if (mounted && !_isDisposed && _controller != null) {
        VideoPlaybackManager.instance.markAsPlaying(_controller!);
        _controller!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频播放器 - 全屏铺满
          if (_error != null)
            Center(
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
          else if (_initialized && _controller != null)
            GestureDetector(
              onTap: _onVideoTap,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 缓冲指示器
          if (_initialized && _isBuffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),

          // 播放/暂停按钮overlay
          if (_initialized && _showControls && !_isBuffering && _controller != null)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                  child: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // 底部渐变遮罩 - 从下往上渐变，覆盖底部区域
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 280,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x40000000),
                      Color(0x99000000),
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 顶部功能栏
          Positioned(
            left: Spacing.md,
            right: Spacing.md,
            top: MediaQuery.of(context).padding.top + Spacing.xs,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.white),
                    tooltip: '查看笔记',
                    onPressed: _openNotesSheet,
                  ),
                ),
              ],
            ),
          ),

          // 右侧操作栏 - 调整位置确保在渐变区域内
          Positioned(
            right: 8,
            bottom: bottomPadding + 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PublisherAvatar(
                  uid: widget.video.uid,
                  avatarUrl: widget.video.authorAvatarUrl,
                ),
                const SizedBox(height: 20),
                FullScreenLikeButton(
                  videoId: widget.video.id,
                  likeCount: widget.video.likes,
                ),
                const SizedBox(height: 16),
                _ActionIcon(
                  icon: Icons.chat_bubble_outline,
                  label: formatCountCompact(widget.video.commentCount),
                  onTap: () => showCommentsSheet(context, videoId: widget.video.id),
                ),
                const SizedBox(height: 16),
                _CollectActionIcon(videoId: widget.video.id),
              ],
            ),
          ),

          // 底部信息区域
          Positioned(
            left: Spacing.md,
            right: 70,
            bottom: bottomPadding + 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 作者名
                GestureDetector(
                  onTap: () {
                    if (widget.video.uid != null) {
                      context.push('/user/${widget.video.uid}');
                    }
                  },
                  child: Text(
                    '@$_effectiveAuthorName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 视频简介
                if (widget.video.intro != null && widget.video.intro!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isDescriptionExpanded = !_isDescriptionExpanded;
                      });
                    },
                    child: Text(
                      widget.video.intro!,
                      maxLines: _isDescriptionExpanded ? null : 2,
                      overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // 查看详情按钮
                if (_initialized)
                  GestureDetector(
                    onTap: _openVideoDetail,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, color: Colors.white.withValues(alpha: 0.9), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '查看详情',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 底部进度条
          if (_initialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPadding,
              child: _VideoProgressBar(controller: _controller!),
            ),
        ],
      ),
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
  bool _isLoading = false;
  String? _fetchedAvatarUrl; // 从API获取的头像URL
  bool _fetchingAvatar = false;

  @override
  void initState() {
    super.initState();
    // 如果传入的avatarUrl为空，则尝试获取用户头像
    if ((widget.avatarUrl == null || widget.avatarUrl!.isEmpty) && widget.uid != null) {
      _fetchUserAvatar();
    }
  }

  @override
  void didUpdateWidget(covariant _PublisherAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果uid变化了，重新获取头像
    if (oldWidget.uid != widget.uid) {
      _fetchedAvatarUrl = null;
      if ((widget.avatarUrl == null || widget.avatarUrl!.isEmpty) && widget.uid != null) {
        _fetchUserAvatar();
      }
    }
  }

  Future<void> _fetchUserAvatar() async {
    if (_fetchingAvatar || widget.uid == null) return;
    _fetchingAvatar = true;

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.uid);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final avatarUrl = (userData['avatar'] ?? userData['avatar_url'])?.toString();
        if (avatarUrl != null && avatarUrl.isNotEmpty && mounted) {
          setState(() {
            _fetchedAvatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
          });
        }
      }
    } catch (e) {
      AppConfig.log('_PublisherAvatar: fetch avatar error: $e');
    } finally {
      _fetchingAvatar = false;
    }
  }

  /// 获取有效的头像URL（优先使用传入的，其次使用获取的）
  String? get _effectiveAvatarUrl {
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      return widget.avatarUrl;
    }
    return _fetchedAvatarUrl;
  }

  void _handleTap() {
    // 防抖处理：300ms内只响应一次点击
    final now = DateTime.now();
    if (_lastClickTime != null && now.difference(_lastClickTime!).inMilliseconds < 300) {
      return;
    }
    _lastClickTime = now;

    // 跳转到创作者主页
    if (widget.uid != null) {
      context.push('/user/${widget.uid}');
    }
  }

  Future<void> _handleFollow() async {
    if (_isLoading || widget.uid == null) return;

    // 防抖处理
    final now = DateTime.now();
    if (_lastClickTime != null && now.difference(_lastClickTime!).inMilliseconds < 300) {
      return;
    }
    _lastClickTime = now;

    setState(() => _isLoading = true);

    try {
      final mp = context.read<MessagingProvider>();
      final success = await mp.toggleFollow(widget.uid!);

      if (mounted) {
        final isNowFollowing = mp.isFollowing(widget.uid!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (isNowFollowing ? '已关注' : '已取消关注')
                : '操作失败'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();
    final isFollowed = widget.uid != null && mp.isFollowing(widget.uid!);
    final avatarUrl = _effectiveAvatarUrl;

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
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder();
                        },
                      )
                    : _buildPlaceholder(),
              ),
            ),
            // 右下角关注按钮
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _isLoading ? null : _handleFollow,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFollowed ? Colors.grey : const Color(0xFFFF2D55),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isFollowed ? Icons.check : Icons.add,
                          color: Colors.white,
                          size: 14,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    // 如果有uid，显示首字母
    if (widget.uid != null && widget.uid!.isNotEmpty) {
      return Center(
        child: Text(
          widget.uid!.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      );
    }
    return Icon(Icons.person, size: 30, color: Colors.grey.shade600);
  }
}

/// 收藏图标（星形）带动画，不显示计数
class _CollectActionIcon extends StatefulWidget {
  final String videoId;
  const _CollectActionIcon({required this.videoId});
  @override
  State<_CollectActionIcon> createState() => _CollectActionIconState();
}

class _CollectActionIconState extends State<_CollectActionIcon> with SingleTickerProviderStateMixin {
  bool loading = false;
  late AnimationController pulse;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (loading) return;

    setState(() => loading = true);
    pulse.forward(from: 0);

    try {
      final success = await context.read<VideoProvider>().toggleFavorite(widget.videoId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('操作失败，请重试'),
            duration: Duration(milliseconds: 2000),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
    final vp = context.watch<VideoProvider>();
    final isFavorited = vp.isFavorited(widget.videoId);

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
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x33000000),
                  ),
                ),
                if (!loading)
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                      CurvedAnimation(parent: pulse, curve: Curves.easeOut),
                    ),
                    child: Icon(
                      isFavorited ? Icons.star : Icons.star_border,
                      color: isFavorited ? const Color(0xFFFFD700) : Colors.white,
                      size: 28,
                    ),
                  ),
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
          '收藏',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
        ),
      ],
    );
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
