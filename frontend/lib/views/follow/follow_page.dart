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
import '../../utils/url_utils.dart';

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
      debugPrint('FollowPage: /feed/follow returned empty, trying fallback');
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
      debugPrint('FollowPage: no following users');
      return;
    }

    debugPrint('FollowPage: fallback - fetching videos from ${following.length} users');

    // 获取关注用户的ID列表
    final userIds = following.map((f) => f.id).toList();

    // 使用备用方法获取视频
    final videos = await vp.repo.fetchVideosFromUsers(userIds, limit: 5);

    if (mounted && videos.isNotEmpty) {
      setState(() {
        _usingFallback = true;
        _fallbackVideos = videos;
      });
      debugPrint('FollowPage: fallback got ${videos.length} videos');
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
            onLike: () => vp.like(video.id),
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

class _FollowListItem extends StatelessWidget {
  final Video video;
  final bool isRecommended;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  const _FollowListItem({
    required this.video,
    required this.isRecommended,
    required this.onTap,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 作者名称：优先使用uid，没有则用title的第一部分
    final authorName = video.uid ?? '用户${video.id.substring(0, 4)}';
    final authorInitial = authorName.isNotEmpty ? authorName.substring(0, 1).toUpperCase() : '?';

    // 视频标题
    final videoTitle = video.title ?? '未命名视频';

    // 处理封面URL
    final coverUrl = video.coverUrl != null && video.coverUrl!.isNotEmpty
        ? UrlUtils.resolveStorageUrl(video.coverUrl, defaultDir: 'covers')
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：作者信息与推荐标记
          Row(
            children: [
              // 作者头像
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  authorInitial,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
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
                    if (video.intro != null && video.intro!.isNotEmpty)
                      Text(
                        video.intro!,
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
              if (isRecommended)
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
          if (video.tags.isNotEmpty)
            Wrap(
              spacing: Spacing.xs,
              children: video.tags.take(3).map((tag) => Text(
                '#$tag',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                ),
              )).toList(),
            ),
          const SizedBox(height: Spacing.sm),

          // 封面图
          GestureDetector(
            onTap: onTap,
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
                onPressed: onShare,
                tooltip: '复制视频ID',
              ),
              const SizedBox(width: Spacing.md),
              // 评论
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconAction(icon: Icons.chat_bubble_outline, onPressed: onComment),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(video.commentCount ?? video.comments ?? 0),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(width: Spacing.md),
              // 点赞
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconAction(icon: Icons.favorite_border, onPressed: onLike),
                  const SizedBox(width: 4),
                  Text(
                    formatCount(video.likes ?? 0),
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
