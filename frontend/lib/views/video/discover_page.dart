import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/video.dart';
import '../../providers/video_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../services/video/video_preload_manager.dart';
import 'featured_page.dart';
import 'widgets/md_notes_sheet.dart';
import '../../widgets/comment_sheet.dart';
import 'package:go_router/go_router.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tab;
  int _currentRecommendIndex = 0;
  final Map<String, VideoPlayerController> _controllers = {};
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;
  bool _isPageVisible = true;

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
    for (final c in _controllers.values) {
      c.dispose();
    }
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台时暂停所有视频
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAllVideos();
      _isPageVisible = false;
    } else if (state == AppLifecycleState.resumed) {
      _isPageVisible = true;
      // 恢复当前视频（如果在推荐页）
      if (_tab.index == 1 && _controllers.isNotEmpty) {
        final vp = context.read<VideoProvider>();
        if (_currentRecommendIndex < vp.discover.length) {
          final v = vp.discover[_currentRecommendIndex];
          _controllers[v.id]?.play();
        }
      }
    }
  }

  void _onTabChanged() {
    // Tab切换时暂停非当前页的视频
    if (_tab.index != 1) {
      _pauseAllVideos();
    }
  }

  void _pauseAllVideos() {
    for (final c in _controllers.values) {
      c.pause();
    }
    _preloadManager.pauseAll();
  }

  Future<void> _playIndex(List videos, int index) async {
    if (index < 0 || index >= videos.length) return;
    if (!_isPageVisible) return; // 页面不可见时不播放

    setState(() => _currentRecommendIndex = index);
    final v = videos[index];

    // 暂停所有其他视频
    for (final entry in _controllers.entries) {
      if (entry.key != v.id) entry.value.pause();
    }

    // 更新预加载管理器的当前索引
    _preloadManager.updateCurrentIndex(index);

    // 当前控制器
    var ctrl = _controllers[v.id];
    if (ctrl == null) {
      // 尝试从预加载管理器获取
      ctrl = _preloadManager.getPreloadedController(v.id);
      if (ctrl != null) {
        _controllers[v.id] = ctrl;
        debugPrint('DiscoverPage: using preloaded controller for ${v.id}');
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(v.videoUrl));
        _controllers[v.id] = ctrl;
        await ctrl.initialize();
      }
    }
    ctrl.setLooping(true);
    await ctrl.play();
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
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '精选'), Tab(text: '推荐')],
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
            onIndexChanged: (i) => _playIndex(vp.discover, i),
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
  const _RecommendFullScreen({required this.videos, required this.onIndexChanged, required this.isLoading, required this.onRetry});
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

class _FullScreenVideoItemState extends State<_FullScreenVideoItem> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isBuffering = false;
  String? _error;
  bool _wasPlayingBeforePause = false;

  String _fmtLocal(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}k';
    return '$c';
  }

  // 顶部栏：菜单展开占位
  void _onMenu() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('菜单功能待接入'), duration: Duration(milliseconds: 1200)));
  }

  // 顶部栏：搜索占位
  void _onSearch() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('搜索功能待接入'), duration: Duration(milliseconds: 1200)));
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

  // 分享占位：显示气泡提示（2秒消失）
  void _onShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制链接'),
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.black.withValues(alpha: 0.85),
      ),
    );
  }

  // 跳转视频详情
  void _openDetails() {
    // 暂停当前视频再跳转
    _controller.pause();
    context.go('/video/${widget.video.id}');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  Future<void> _initController() async {
    final url = widget.video.videoUrl ?? '';
    if (url.isEmpty) {
      setState(() => _error = '视频地址为空');
      return;
    }

    // 尝试从预加载管理器获取
    final preloadManager = VideoPreloadManager.instance;
    final preloaded = preloadManager.getPreloadedController(widget.video.id);

    if (preloaded != null) {
      _controller = preloaded;
      if (mounted) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.play();
        context.read<VideoProvider>().visit(widget.video.id);
      }
      debugPrint('_FullScreenVideoItem: using preloaded controller');
      return;
    }

    // 创建新控制器
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller.addListener(_onControllerUpdate);

    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.play();
        context.read<VideoProvider>().visit(widget.video.id);
      }
    } catch (e) {
      debugPrint('FullScreenVideoItem: initialize error $e');
      if (mounted) setState(() => _error = '视频加载失败');
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final wasBuffering = _isBuffering;
    final isBufferingNow = _controller.value.isBuffering;

    if (wasBuffering != isBufferingNow) {
      setState(() => _isBuffering = isBufferingNow);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasPlayingBeforePause = _controller.value.isPlaying;
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        _controller.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.black54)))
            : _initialized
                ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))
                : const Center(child: CircularProgressIndicator()),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
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
          right: Spacing.md,
          top: MediaQuery.of(context).size.height * 0.25,
          child: Column(
            children: [
              _LikeActionIcon(
                initialCount: widget.video.likes ?? 0,
                onTap: () => context.read<VideoProvider>().like(widget.video.id),
              ),
              const SizedBox(height: Spacing.md),
              _ActionIcon(icon: Icons.chat_bubble_outline, label: '1.2k', onTap: () {
                // 打开评论弹窗
                showCommentsSheet(context, videoId: 'v_2');
              }),
              const SizedBox(height: Spacing.md),
              _ActionIcon(icon: Icons.share_outlined, label: '4.6k', onTap: _onShare),
              const SizedBox(height: Spacing.md),
              _ActionIcon(icon: Icons.open_in_full, label: '', onTap: _openDetails),
            ],
          ),
        ),
        // 底部文案
        Positioned(
          left: Spacing.md,
          right: Spacing.md,
          bottom: Spacing.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${widget.video.uid ?? '未知作者'}', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text('${widget.video.intro ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('点赞 ${_fmtLocal(widget.video.likes ?? 0)} · 收藏 ${_fmtLocal(widget.video.stars ?? 0)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
            ],
          ),
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
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
        ],
      ],
    );
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

class _LikeActionIconState extends State<_LikeActionIcon> with TickerProviderStateMixin {
  late int count;
  bool liked = false;
  late AnimationController pulse; // 心形缩放
  late AnimationController burst; // 粒子爆裂

  @override
  void initState() {
    super.initState();
    count = widget.initialCount;
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
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
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33000000)),
                ),
                // 心形图标（缩放/颜色过渡）
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.25).animate(CurvedAnimation(parent: pulse, curve: Curves.easeOut)),
                  child: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : Colors.white),
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
