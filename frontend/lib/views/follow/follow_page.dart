import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';
import '../../theme/theme_tokens.dart';
import '../../widgets/comment_sheet.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});
  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final vp = context.read<VideoProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vp.follow.isEmpty) {
        vp.refreshFollow();
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
        vp2.loadMoreFollow();
      }
    });
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
    return RefreshIndicator(
      onRefresh: () => vp.refreshFollow(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        itemCount: vp.follow.length + 1,
        itemBuilder: (context, index) {
          if (index == vp.follow.length) {
            if (vp.loadingFollow) {
              return const Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!vp.followHasMore && vp.follow.isEmpty) {
              return const _EmptyState();
            }
            return const SizedBox(height: Spacing.lg);
          }
          final video = vp.follow[index];
          final isRecommended = vp.recommendStartIndexInFollow != null && index >= vp.recommendStartIndexInFollow!;
          return _FollowListItem(
            video: video,
            isRecommended: isRecommended,
            onTap: () => context.go('/video/${video.id}'),
            onLike: () => vp.like(video.id),
            onComment: () => showCommentsSheet(context, videoId: video.id),
          );
        },
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
  const _FollowListItem({required this.video, required this.isRecommended, required this.onTap, required this.onLike, required this.onComment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：作者信息与推荐标记
          Row(
            children: [
              CircleAvatar(
                child: Text((video.title ?? video.uid ?? '视频').isNotEmpty
                    ? (video.title ?? video.uid ?? '视频').substring(0, 1)
                    : '?'),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(video.title ?? (video.uid ?? '未知'), style: theme.textTheme.titleSmall)),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: Radii.sm),
                  child: Text('相关推荐', style: theme.textTheme.labelSmall),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // 文案（标签模拟）
          if (video.tags.isNotEmpty)
            Text('#${video.tags.take(3).join(' #')}', style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
          const SizedBox(height: Spacing.sm),
          // 封面图
          GestureDetector(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: Radii.md,
                child: CachedNetworkImage(
                  imageUrl: video.coverUrl ?? 'https://picsum.photos/seed/${video.id}/640/360',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.grey))),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          // 操作栏
          Row(
            children: [
              Text('10-9', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const Spacer(),
              _IconAction(icon: Icons.share_outlined, onPressed: () {}),
              const SizedBox(width: Spacing.md),
              _IconAction(icon: Icons.chat_bubble_outline, onPressed: onComment),
              const SizedBox(width: Spacing.md),
              Row(children: [
                _IconAction(icon: Icons.favorite_border, onPressed: onLike),
                const SizedBox(width: 4),
                Text('${video.likes ?? 0}', style: theme.textTheme.bodySmall),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _IconAction({required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 24,
      child: Icon(icon, color: Theme.of(context).iconTheme.color),
    );
  }
}
