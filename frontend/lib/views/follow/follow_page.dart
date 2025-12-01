import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/video_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/video.dart';
import '../../theme/theme_tokens.dart';
import '../../widgets/comment_sheet.dart';
import '../../widgets/video_stats.dart';
import '../../widgets/animated_like_button.dart';
import '../../utils/url_utils.dart';
import '../../utils/app_config.dart';
import '../../services/user_service.dart';
import '../../app.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  bool _usingFallback = false; // 是否使用备用方案
  List<Video> _fallbackVideos = []; // 备用方案获取的视频

  @override
  void initState() {
    super.initState();
    final vp = context.read<VideoProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vp.follow.isEmpty) {
        _loadFollowVideos();
      }
    });
    // 恢复滚动位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vp.followScrollOffset > 0) {
        _scroll.jumpTo(vp.followScrollOffset);
      }
    });
    _scroll.addListener(() {
      final vp2 = context.read<VideoProvider>();
      vp2.setFollowScrollOffset(_scroll.offset);
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        if (!_usingFallback) {
          vp2.loadMoreFollow();
        }
      }
    });
  }

  /// 加载关注用户的视频
  Future<void> _loadFollowVideos() async {
    final vp = context.read<VideoProvider>();

    // 首先尝试使用原有的 /feed/follow 接口
    await vp.refreshFollow();

    // 如果返回空，尝试使用备用方案
    if (vp.follow.isEmpty && mounted) {
      AppConfig.log('FollowPage: /feed/follow returned empty, trying fallback');
      await _loadFallbackVideos();
    }
  }

  /// 备用方案：从关注列表获取每个用户的视频
  Future<void> _loadFallbackVideos() async {
    final mp = context.read<MessagingProvider>();
    final vp = context.read<VideoProvider>();

    // 获取关注列表
    final following = mp.following;
    if (following.isEmpty) {
      AppConfig.log('FollowPage: no following users');
      return;
    }

    AppConfig.log('FollowPage: fallback - fetching videos from ${following.length} users');

    // 获取关注用户的ID列表
    final userIds = following.map((f) => f.id).toList();

    // 使用备用方法获取视频
    final videos = await vp.repo.fetchVideosFromUsers(userIds, limit: 5);

    if (mounted && videos.isNotEmpty) {
      setState(() {
        _usingFallback = true;
        _fallbackVideos = videos;
      });
      AppConfig.log('FollowPage: fallback got ${videos.length} videos');
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _usingFallback = false;
      _fallbackVideos = [];
    });
    await _loadFollowVideos();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final vp = context.watch<VideoProvider>();

    // 确定显示的视频列表
    final videos = _usingFallback ? _fallbackVideos : vp.follow;
    final isLoading = vp.loadingFollow;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        itemCount: videos.length + 1,
        itemBuilder: (context, index) {
          if (index == videos.length) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (videos.isEmpty) {
              return const _EmptyState();
            }
            return const SizedBox(height: Spacing.lg);
          }
          final video = videos[index];
          final isRecommended = !_usingFallback &&
              vp.recommendStartIndexInFollow != null &&
              index >= vp.recommendStartIndexInFollow!;
          return _FollowListItem(
            video: video,
            isRecommended: isRecommended,
            onTap: () => context.go('/video/${video.id}'),
            onComment: () => showCommentsSheet(context, videoId: video.id),
            onShare: () => _copyVideoId(context, video.id),
          );
        },
      ),
    );
  }

  /// 复制视频ID到剪贴板
  void _copyVideoId(BuildContext context, String videoId) {
    Clipboard.setData(ClipboardData(text: videoId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('视频ID已复制: $videoId'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
          const SizedBox(height: Spacing.md),
          Text('还没有关注的内容', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.sm),
          Text('去发现页关注一些作者吧，我们也会推荐内容给你', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FollowListItem extends StatefulWidget {
  final Video video;
  final bool isRecommended;
  final VoidCallback onTap;
  final VoidCallback onComment;
  final VoidCallback onShare;
  const _FollowListItem({
    required this.video,
    required this.isRecommended,
    required this.onTap,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<_FollowListItem> createState() => _FollowListItemState();
}

class _FollowListItemState extends State<_FollowListItem> {
  String? _authorAvatarUrl;
  String? _authorName;
  bool _fetchingAuthor = false;

  @override
  void initState() {
    super.initState();
    // 如果视频没有作者信息，则根据uid获取
    if (widget.video.uid != null) {
      _fetchAuthorInfo();
    }
  }

  @override
  void didUpdateWidget(covariant _FollowListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.uid != widget.video.uid) {
      _authorAvatarUrl = null;
      _authorName = null;
      if (widget.video.uid != null) {
        _fetchAuthorInfo();
      }
    }
  }

  Future<void> _fetchAuthorInfo() async {
    if (_fetchingAuthor || widget.video.uid == null) return;
    // 如果已经有头像和名称，不需要再获取
    if (widget.video.authorAvatarUrl != null &&
        widget.video.authorAvatarUrl!.isNotEmpty &&
        widget.video.authorName != null &&
        widget.video.authorName!.isNotEmpty) {
      return;
    }

    _fetchingAuthor = true;

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
              _authorAvatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
            }
            if (userName != null && userName.isNotEmpty) {
              _authorName = userName;
            }
          });
        }
      }
    } catch (e) {
      AppConfig.log('_FollowListItem: fetch author error: $e');
    } finally {
      _fetchingAuthor = false;
    }
  }

  /// 获取有效的作者头像URL
  String? get _effectiveAvatarUrl {
    if (widget.video.authorAvatarUrl != null && widget.video.authorAvatarUrl!.isNotEmpty) {
      return UrlUtils.resolveStorageUrl(widget.video.authorAvatarUrl, defaultDir: 'avatars');
    }
    return _authorAvatarUrl;
  }

  /// 获取有效的作者名称
  String get _effectiveAuthorName {
    if (widget.video.authorName != null && widget.video.authorName!.isNotEmpty) {
      return widget.video.authorName!;
    }
    if (_authorName != null && _authorName!.isNotEmpty) {
      return _authorName!;
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

    // 作者名称：使用获取到的名称
    final authorName = _effectiveAuthorName;
    final authorInitial = authorName.isNotEmpty ? authorName.substring(0, 1).toUpperCase() : '?';
    final avatarUrl = _effectiveAvatarUrl;

    // 视频标题
    final videoTitle = widget.video.title ?? '未命名视频';

    // 处理封面URL
    final coverUrl = widget.video.coverUrl != null && widget.video.coverUrl!.isNotEmpty
        ? UrlUtils.resolveStorageUrl(widget.video.coverUrl, defaultDir: 'covers')
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：作者信息与推荐标记
          Row(
            children: [
              // 作者头像（可点��进入主页）
              GestureDetector(
                onTap: _goToAuthorProfile,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          authorInitial,
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // 作者名和视频标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.video.intro != null && widget.video.intro!.isNotEmpty)
                      Text(
                        widget.video.intro!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // 推荐标记
              if (widget.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: Radii.sm,
                  ),
                  child: Text(
                    '相关推荐',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // 视频标题
          Text(
            videoTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Spacing.xs),

          // 标签
          if (widget.video.tags.isNotEmpty)
            Wrap(
              spacing: Spacing.xs,
              children: widget.video.tags.take(3).map((tag) => Text(
                '#$tag',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                ),
              )).toList(),
            ),
          const SizedBox(height: Spacing.sm),

          // 封面图
          GestureDetector(
            onTap: widget.onTap,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: Radii.md,
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildPlaceholder(),
                        errorWidget: (_, __, ___) => _buildErrorPlaceholder(),
                      )
                    : _buildErrorPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // 操作栏
          Row(
            children: [
              const Spacer(),
              // 分享按钮
              _IconAction(
                icon: Icons.share_outlined,
                onPressed: widget.onShare,
                tooltip: '复制视频ID',
              ),
              const SizedBox(width: Spacing.md),
              // 评论
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconAction(icon: Icons.chat_bubble_outline, onPressed: widget.onComment),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(widget.video.commentCount ?? widget.video.comments ?? 0),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(width: Spacing.md),
              // 点赞（带动画，水平布局）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedLikeButton(
                    videoId: widget.video.id,
                    likeCount: widget.video.likes,
                    size: 22,
                    showCount: false,
                    darkMode: false,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(widget.video.likes ?? 0),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: Spacing.lg),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(Icons.videocam_outlined, size: 40, color: Colors.grey.shade400),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  const _IconAction({required this.icon, required this.onPressed, this.tooltip});
  @override
  Widget build(BuildContext context) {
    final child = InkResponse(
      onTap: onPressed,
      radius: 24,
      child: Icon(icon, size: 22, color: Theme.of(context).iconTheme.color),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: child,
      );
    }
    return child;
  }
}
