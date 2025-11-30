import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/video_provider.dart';
import '../../providers/comment_provider.dart';
import '../../models/video.dart';
import '../../models/comment.dart';
import '../../theme/theme_tokens.dart';
import '../../widgets/video_controls_overlay.dart';
import '../../widgets/comment_sheet.dart';
import '../../widgets/animated_like_button.dart';
import '../../services/user_service.dart';
import '../../utils/url_utils.dart';
import '../../app.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

/// 视频详情页 - 支持可拖拽互动区域（类似B站移动端）
///
/// 特性：
/// - 瘦高比例视频时，用户可向上拖拽互动区扩大操作空间
/// - 播放中：视频最小可缩小到默认16:9占比
/// - 暂停时：视频可全屏填满
/// - 评论输入时，输入框始终显示在键盘上方
class VideoDetailPage extends StatefulWidget {
  final String? id;
  final Video? video;

  const VideoDetailPage({super.key, this.id, this.video}) : assert(id != null || video != null);

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  String? _error;
  bool _initialized = false;
  bool _isFullscreen = false;

  // 拖拽相关状态
  double _videoHeightRatio = 0.40; // 视频区域占屏幕高度的比例 (0.0 ~ 1.0)
  bool _isDragging = false;

  // 视频比例边界（使用自定义控制层后可以更灵活）
  static const double _minRatioPlaying = 0.25;  // 播放时最小比例
  static const double _maxRatioPlaying = 0.60;  // 播放时最大比例
  static const double _minRatioPaused = 0.20;   // 暂停时最小比例
  static const double _maxRatioPaused = 0.75;   // 暂停时最大比例

  // 拖拽手柄高度
  static const double _dragHandleHeight = 20.0;

  // 互动区域最小高度（Tab栏 + 内容 + 安全边距）
  static const double _minContentHeight = 200.0;

  // 视频区域最小高度
  static const double _minVideoHeight = 120.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVideoPlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    // 退出时恢复屏幕方向
    if (_isFullscreen) {
      _exitFullscreen();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台时暂停视频
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _videoController?.pause();
    }
  }

  Video get _displayVideo {
    if (widget.video != null) return widget.video!;
    final vp = context.read<VideoProvider>();
    return vp.discover.firstWhere(
      (e) => e.id == widget.id,
      orElse: () => vp.featured.firstWhere(
        (e) => e.id == widget.id,
        orElse: () => vp.follow.firstWhere(
          (e) => e.id == widget.id,
          orElse: () => const Video(id: ''),
        ),
      ),
    );
  }

  Future<void> _initVideoPlayer() async {
    final video = _displayVideo;
    final url = video.videoUrl ?? video.coverUrl ?? '';

    if (url.isEmpty) {
      setState(() => _error = '视频地址为空');
      return;
    }

    // 探测资源可达性
    try {
      final ok = await _probeUrl(url);
      if (!ok) {
        setState(() => _error = '视频资源不可访问');
        return;
      }
    } catch (e) {
      debugPrint('VideoDetailPage: probe error $e');
    }

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _videoController!.initialize();

      // 根据视频实际比例计算初始高度比例
      final videoRatio = _videoController!.value.aspectRatio;
      _calculateInitialHeightRatio(videoRatio);

      // 监听播放状态变化
      _videoController!.addListener(_onVideoStateChanged);

      // 自动播放
      _videoController!.play();

      setState(() => _initialized = true);

      // 记录访问
      if (mounted) {
        context.read<VideoProvider>().visit(video.id);
      }
    } catch (e) {
      debugPrint('VideoDetailPage: initialize error $e');
      setState(() => _error = '播放器初始化失败');
    }
  }

  Future<bool> _probeUrl(String url) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.add('Range', 'bytes=0-1');
      final resp = await req.close();
      return resp.statusCode == 200 || resp.statusCode == 206;
    } catch (_) {
      return false;
    }
  }

  /// 根据视频实际比例计算初始高度
  void _calculateInitialHeightRatio(double aspectRatio) {
    // 横屏视频（宽>高）：使用较小比例
    // 竖屏视频（高>宽）：使用较大比例，但给互动区留足空间
    if (aspectRatio >= 1.0) {
      // 横屏视频，默认40%高度
      _videoHeightRatio = 0.40;
    } else {
      // 竖屏视频，根据比例动态计算
      // 比例越小（越瘦高），初始高度越大但上限为50%
      _videoHeightRatio = (0.42 + (1 - aspectRatio) * 0.1).clamp(0.40, 0.50);
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    // 当播放状态变化时，可能需要调整拖拽边界
    setState(() {});
  }

  /// 获取当前允许的最小/最大比例
  double get _currentMinRatio {
    final isPlaying = _videoController?.value.isPlaying ?? false;
    return isPlaying ? _minRatioPlaying : _minRatioPaused;
  }

  double get _currentMaxRatio {
    final isPlaying = _videoController?.value.isPlaying ?? false;
    return isPlaying ? _maxRatioPlaying : _maxRatioPaused;
  }

  /// 处理拖拽开始
  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  /// 处理拖拽更新
  void _onDragUpdate(DragUpdateDetails details, double availableHeight) {
    final delta = details.delta.dy;
    final deltaRatio = delta / availableHeight;

    // 计算有效的最小/最大比例
    final minRatioByVideoHeight = _minVideoHeight / availableHeight;
    final maxRatioByContentHeight = (availableHeight - _minContentHeight - _dragHandleHeight) / availableHeight;

    final effectiveMinRatio = _currentMinRatio.clamp(minRatioByVideoHeight, 1.0);
    final effectiveMaxRatio = _currentMaxRatio.clamp(0.0, maxRatioByContentHeight);

    setState(() {
      _videoHeightRatio = (_videoHeightRatio + deltaRatio).clamp(effectiveMinRatio, effectiveMaxRatio);
    });
  }

  /// 处理拖拽结束
  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    // 如果拖拽到接近边界，吸附到边界值
    if (_videoHeightRatio < _currentMinRatio + 0.05) {
      setState(() => _videoHeightRatio = _currentMinRatio);
    } else if (_videoHeightRatio > _currentMaxRatio - 0.05) {
      setState(() => _videoHeightRatio = _currentMaxRatio);
    }
  }

  void _onBack() {
    if (_isFullscreen) {
      _exitFullscreen();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    // 横屏全屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    // 恢复竖屏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // 可用高度（减去状态栏和底部安全区）
    final availableHeight = screenHeight - statusBarHeight - bottomPadding;

    // 计算动态最小/最大比例，确保视频和互动区域都有足够空间
    final minRatioByVideoHeight = _minVideoHeight / availableHeight;
    final maxRatioByContentHeight = (availableHeight - _minContentHeight - _dragHandleHeight) / availableHeight;

    final effectiveMinRatio = _currentMinRatio.clamp(minRatioByVideoHeight, 1.0);
    final effectiveMaxRatio = _currentMaxRatio.clamp(0.0, maxRatioByContentHeight);

    // 视频区域高度（确保在有效范围内）
    final clampedRatio = _videoHeightRatio.clamp(effectiveMinRatio, effectiveMaxRatio);
    final videoHeight = (availableHeight * clampedRatio).clamp(_minVideoHeight, availableHeight - _minContentHeight);

    // 检查是否可以正常返回（有路由可以pop）
    final canPopNormally = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopNormally && !_isFullscreen, // 只有在非全屏且有路由可pop时才允许系统返回
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // 处理无法正常pop的情况
        if (_isFullscreen) {
          _exitFullscreen();
        } else if (!canPopNormally) {
          // 如果没有路由可pop，则跳转到首页
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isFullscreen
            // 全屏模式：只显示视频播放器
            ? _buildVideoPlayer()
            // 普通模式：显示视频+互动区
            : SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    // 状态栏占位
                    SizedBox(height: statusBarHeight),

                    // 视频播放区域（包含自定义控制层，控制层内有返回按钮）
                    SizedBox(
                      height: videoHeight,
                      child: _buildVideoPlayer(),
                    ),

                    // 可拖拽分隔条
                    _buildDragHandle(availableHeight),

                    // 互动内容区域
                    Expanded(
                      child: Container(
                        color: Theme.of(context).colorScheme.surface,
                        child: _initialized
                            ? VideoDetailContentWithKeyboard(
                                video: _displayVideo,
                                keyboardHeight: keyboardHeight,
                                bottomPadding: bottomPadding,
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initVideoPlayer,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized || _videoController == null) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // 使用 Stack 将视频播放器和自定义控制层分离
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 底层：视频播放器
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // 顶层：自定义控制层（不影响视频区域大小）
          VideoControlsOverlay(
            controller: _videoController!,
            isFullscreen: _isFullscreen,
            title: _displayVideo.title,
            onBack: _onBack,
            onFullscreenToggle: _toggleFullscreen,
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle(double availableHeight) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 计算有效的最小/最大比例
    final minRatioByVideoHeight = _minVideoHeight / availableHeight;
    final maxRatioByContentHeight = (availableHeight - _minContentHeight - _dragHandleHeight) / availableHeight;

    final effectiveMinRatio = _currentMinRatio.clamp(minRatioByVideoHeight, 1.0);
    final effectiveMaxRatio = _currentMaxRatio.clamp(0.0, maxRatioByContentHeight);

    // 检查是否可以拖拽（有拖拽空间）
    final canDrag = _initialized && effectiveMaxRatio > effectiveMinRatio;

    return GestureDetector(
      onVerticalDragStart: canDrag ? _onDragStart : null,
      onVerticalDragUpdate: canDrag ? (d) => _onDragUpdate(d, availableHeight) : null,
      onVerticalDragEnd: canDrag ? _onDragEnd : null,
      child: Container(
        height: _dragHandleHeight,
        color: cs.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 拖拽指示条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _isDragging ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (canDrag) ...[
                const SizedBox(height: 2),
                Icon(
                  Icons.drag_handle,
                  size: 14,
                  color: _isDragging ? cs.primary : cs.outlineVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 带键盘适配的视频详情内容组件
/// 确保评论输入框始终显示在键盘上方
class VideoDetailContentWithKeyboard extends StatefulWidget {
  final Video video;
  final double keyboardHeight;
  final double bottomPadding;

  const VideoDetailContentWithKeyboard({
    super.key,
    required this.video,
    required this.keyboardHeight,
    required this.bottomPadding,
  });

  @override
  State<VideoDetailContentWithKeyboard> createState() => _VideoDetailContentWithKeyboardState();
}

class _VideoDetailContentWithKeyboardState extends State<VideoDetailContentWithKeyboard>
    with TickerProviderStateMixin {
  late final TabController _tab;
  bool _commentsMounted = false;

  // 评论输入相关
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  // 回复状态
  CommentItem? _replyingTo;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging && _tab.index == 1 && !_commentsMounted) {
      setState(() => _commentsMounted = true);
    }
    // 切换 Tab 时清除回复状态
    if (_tab.indexIsChanging) {
      setState(() => _replyingTo = null);
    }
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // 直接使用 CommentProvider 发送评论
    context.read<CommentProvider>().addComment(
      videoId: widget.video.id,
      content: text,
      parentId: _replyingTo?.id,
    );

    _commentController.clear();
    _commentFocusNode.unfocus();
    setState(() => _replyingTo = null);
  }

  void _handleReply(CommentItem comment) {
    setState(() => _replyingTo = comment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _commentFocusNode.canRequestFocus) {
        _commentFocusNode.requestFocus();
      }
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasKeyboard = widget.keyboardHeight > 0;

    return Column(
      children: [
        // Tab栏
        Material(
          color: cs.surface,
          child: TabBar(
            controller: _tab,
            labelColor: cs.primary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: '简介'),
              Tab(text: '评论'),
              Tab(text: '笔记'),
            ],
          ),
        ),

        // 内容区域
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              // 简介
              _IntroTab(video: widget.video),

              // 评论
              _CommentsTab(
                video: widget.video,
                mounted: _commentsMounted,
                onReply: _handleReply,
              ),

              // 笔记
              _NotesTab(video: widget.video),
            ],
          ),
        ),

        // 评论输入框（键盘弹起时显示在键盘上方）
        if (_tab.index == 1) // 仅在评论Tab显示
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              left: Spacing.md,
              right: Spacing.md,
              top: Spacing.sm,
              bottom: hasKeyboard ? Spacing.sm : widget.bottomPadding + Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 回复提示条
                if (_replyingTo != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: Spacing.xs),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '回复 @${_replyingTo!.author}',
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                // 输入框行
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: _replyingTo == null ? '写下你的评论...' : '回复 @${_replyingTo!.author}',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        style: theme.textTheme.bodyMedium,
                        maxLines: hasKeyboard ? 3 : 1,
                        minLines: 1,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    IconButton(
                      onPressed: _sendComment,
                      icon: Icon(Icons.send, color: cs.primary),
                      tooltip: '发送',
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 简介Tab
class _IntroTab extends StatelessWidget {
  final Video video;
  const _IntroTab({required this.video});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频标题
          Text(
            video.title ?? '未知视频',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.sm),

          // 统计数据
          Row(
            children: [
              Icon(Icons.favorite_border, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${video.likes ?? 0}', style: theme.textTheme.bodySmall),
              const SizedBox(width: Spacing.md),
              Icon(Icons.chat_bubble_outline, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${video.commentCount ?? 0}', style: theme.textTheme.bodySmall),
              const Spacer(),
              // 点赞按钮（带动画）
              AnimatedLikeButton(
                videoId: video.id,
                likeCount: video.likes,
                showCount: false,
                size: 24,
              ),
              // 收藏按钮
              _FavoriteButton(videoId: video.id),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // 作者信息
          if (video.uid != null || video.authorName != null)
            _AuthorInfoCard(video: video),
          const SizedBox(height: Spacing.md),

          // 视频简介
          if ((video.intro ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: cs.primary),
                      const SizedBox(width: Spacing.xs),
                      Text('视频简介', style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      )),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(video.intro!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                ],
              ),
            ),
          const SizedBox(height: Spacing.md),

          // 标签
          if (video.tags.isNotEmpty)
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: video.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '#$tag',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }
}

/// 评论Tab - 整合 CommentsPane 组件
class _CommentsTab extends StatefulWidget {
  final Video video;
  final bool mounted;
  final ValueSetter<CommentItem>? onReply;

  const _CommentsTab({
    required this.video,
    required this.mounted,
    this.onReply,
  });

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  @override
  void initState() {
    super.initState();
    // 加载评论数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CommentProvider>().fetchComments(widget.video.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.mounted) {
      return const _CommentsSkeleton();
    }

    final commentProvider = context.watch<CommentProvider>();
    final comments = commentProvider.commentsMap[widget.video.id] ?? [];
    final isLoading = commentProvider.loadingStatus[widget.video.id] ?? false;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 暂无评论时显示空状态
    if (comments.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: Spacing.md),
            Text('暂无评论', style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            )),
            const SizedBox(height: Spacing.sm),
            Text('快来发表第一条评论吧', style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            )),
          ],
        ),
      );
    }

    // 使用 CommentsPane 组件，但不显示内置输入框（外部已有）
    return CommentsPane(
      key: ValueKey('comments_${widget.video.id}'),
      videoId: widget.video.id,
      showInput: false,
      onReply: widget.onReply,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
    );
  }
}

/// 笔记Tab
class _NotesTab extends StatelessWidget {
  final Video video;
  const _NotesTab({required this.video});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: Spacing.md),
          Text('暂无笔记', style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

/// 收藏按钮
class _FavoriteButton extends StatefulWidget {
  final String videoId;
  const _FavoriteButton({required this.videoId});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _loading = false;

  Future<void> _toggleFavorite() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final success = await context.read<VideoProvider>().toggleFavorite(widget.videoId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请重试'), duration: Duration(milliseconds: 2000)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(milliseconds: 2000)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final isFavorited = vp.isFavorited(widget.videoId);
    final theme = Theme.of(context);

    return IconButton(
      onPressed: _loading ? null : _toggleFavorite,
      icon: _loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            )
          : Icon(
              isFavorited ? Icons.star : Icons.star_border,
              color: isFavorited ? const Color(0xFFFFD700) : null,
            ),
      tooltip: isFavorited ? '取消收藏' : '收藏',
    );
  }
}

/// 作者信息卡片（带头像获取）
class _AuthorInfoCard extends StatefulWidget {
  final Video video;
  const _AuthorInfoCard({required this.video});

  @override
  State<_AuthorInfoCard> createState() => _AuthorInfoCardState();
}

class _AuthorInfoCardState extends State<_AuthorInfoCard> {
  String? _fetchedAvatarUrl;
  String? _fetchedAuthorName;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchAuthorInfo();
  }

  @override
  void didUpdateWidget(covariant _AuthorInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.uid != widget.video.uid) {
      _fetchedAvatarUrl = null;
      _fetchedAuthorName = null;
      _fetchAuthorInfo();
    }
  }

  Future<void> _fetchAuthorInfo() async {
    if (_fetching || widget.video.uid == null) return;
    // 如果已经有头像和名称，不需要再获取
    if (widget.video.authorAvatarUrl != null &&
        widget.video.authorAvatarUrl!.isNotEmpty &&
        widget.video.authorName != null &&
        widget.video.authorName!.isNotEmpty) {
      return;
    }

    _fetching = true;
    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.video.uid);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final avatarUrl = (userData['avatar'] ?? userData['avatar_url'])?.toString();
        final userName = (userData['username'] ?? userData['nickname'] ?? userData['name'])?.toString();

        if (mounted) {
          setState(() {
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              _fetchedAvatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
            }
            if (userName != null && userName.isNotEmpty) {
              _fetchedAuthorName = userName;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('_AuthorInfoCard: fetch error: $e');
    } finally {
      _fetching = false;
    }
  }

  String? get _effectiveAvatarUrl {
    if (widget.video.authorAvatarUrl != null && widget.video.authorAvatarUrl!.isNotEmpty) {
      return UrlUtils.resolveStorageUrl(widget.video.authorAvatarUrl, defaultDir: 'avatars');
    }
    return _fetchedAvatarUrl;
  }

  String get _effectiveAuthorName {
    if (widget.video.authorName != null && widget.video.authorName!.isNotEmpty) {
      return widget.video.authorName!;
    }
    if (_fetchedAuthorName != null && _fetchedAuthorName!.isNotEmpty) {
      return _fetchedAuthorName!;
    }
    return widget.video.uid ?? '未知作者';
  }

  void _goToAuthorProfile() {
    if (widget.video.uid != null) {
      context.push('/user/${widget.video.uid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatarUrl = _effectiveAvatarUrl;
    final authorName = _effectiveAuthorName;
    final authorInitial = authorName.isNotEmpty ? authorName.substring(0, 1).toUpperCase() : '?';

    return GestureDetector(
      onTap: _goToAuthorProfile,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.primaryContainer,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      authorInitial,
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                authorName,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 评论骨架屏
class _CommentsSkeleton extends StatelessWidget {
  const _CommentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}
