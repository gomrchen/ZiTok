import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../models/user_models.dart';
import '../../models/video.dart';
import '../../providers/messaging_provider.dart';
import '../../services/user_service.dart';
import '../../theme/theme_tokens.dart';
import '../../utils/url_utils.dart';

/// 访客个人主页（只读）
class VisitorProfilePage extends StatefulWidget {
  final String userId;

  const VisitorProfilePage({super.key, required this.userId});

  @override
  State<VisitorProfilePage> createState() => _VisitorProfilePageState();
}

class _VisitorProfilePageState extends State<VisitorProfilePage> {
  User? _user;
  List<Video> _videos = [];
  bool _loading = true;
  bool _loadingVideos = false;
  String? _error;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.userId);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        setState(() {
          _user = User.fromJson(userData);
          _loading = false;
        });
        // 加载用户视频
        _loadUserVideos();
      } else {
        setState(() {
          _error = data['message']?.toString() ?? '加载用户信息失败';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadUserVideos() async {
    if (_loadingVideos) return;

    setState(() => _loadingVideos = true);

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final videos = await userService.getVideos(userId: widget.userId);
      setState(() {
        _videos = videos.map((v) => v.copyWith(
          videoUrl: UrlUtils.resolveStorageUrl(v.videoUrl, defaultDir: 'videos'),
          coverUrl: UrlUtils.resolveStorageUrl(v.coverUrl, defaultDir: 'covers'),
        )).toList();
      });
    } catch (e) {
      debugPrint('加载用户视频失败: $e');
    } finally {
      setState(() => _loadingVideos = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading) return;

    setState(() => _followLoading = true);

    try {
      final mp = context.read<MessagingProvider>();
      final success = await mp.toggleFollow(widget.userId);

      if (mounted) {
        final isNowFollowing = mp.isFollowing(widget.userId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? (isNowFollowing ? '已关注' : '已取消关注')
                : '操作失败'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _followLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户主页')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: Spacing.md),
              Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Spacing.md),
              ElevatedButton(
                onPressed: _loadUserInfo,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = math.min(520.0, constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: CustomScrollView(
                  slivers: [
                    // 头部区域
                    SliverToBoxAdapter(
                      child: _buildHeader(user, theme, cs),
                    ),
                    // 用户信息卡片
                    SliverToBoxAdapter(
                      child: _buildUserInfoCard(user, theme, cs),
                    ),
                    // 视频标题
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Row(
                          children: [
                            Icon(Icons.video_library_outlined, size: 20, color: cs.primary),
                            const SizedBox(width: Spacing.xs),
                            Text(
                              '作品 ${_videos.length}',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 视频网格
                    _buildVideoGrid(theme, cs),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(User user, ThemeData theme, ColorScheme cs) {
    return Stack(
      children: [
        // 背景图
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            image: user.profileBackgroundImageUrl != null && user.profileBackgroundImageUrl!.isNotEmpty
                ? DecorationImage(
                    image: CachedNetworkImageProvider(user.profileBackgroundImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),
        // 渐变遮罩
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                cs.surface.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
        // 返回按钮
        Positioned(
          top: Spacing.sm,
          left: Spacing.sm,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        // 头像
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 4),
              ),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: cs.primaryContainer,
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? Text(
                        (user.username.isNotEmpty ? user.username[0] : '?').toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard(User user, ThemeData theme, ColorScheme cs) {
    final mp = context.watch<MessagingProvider>();
    final isFollowing = mp.isFollowing(widget.userId);

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        children: [
          // 用户名
          Text(
            user.username,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Spacing.xs),
          // ID
          Text(
            'ID: ${user.id}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.sm),
          // 简介
          if (user.bio != null && user.bio!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.bio!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: Spacing.md),
          // 关注按钮
          SizedBox(
            width: 160,
            child: ElevatedButton.icon(
              onPressed: _followLoading ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? cs.surfaceContainerHighest : cs.primary,
                foregroundColor: isFollowing ? cs.onSurface : cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _followLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isFollowing ? cs.onSurface : cs.onPrimary,
                      ),
                    )
                  : Icon(isFollowing ? Icons.check : Icons.add),
              label: Text(isFollowing ? '已关注' : '关注'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(ThemeData theme, ColorScheme cs) {
    if (_loadingVideos) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(Spacing.xl),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              children: [
                Icon(Icons.videocam_off_outlined, size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: Spacing.sm),
                Text(
                  '暂无作品',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 9 / 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final video = _videos[index];
            return _VideoThumbnail(
              video: video,
              onTap: () => context.push('/video/${video.id}'),
            );
          },
          childCount: _videos.length,
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final Video video;
  final VoidCallback onTap;

  const _VideoThumbnail({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 封面图
            video.coverUrl != null && video.coverUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: video.coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: cs.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.videocam_outlined, color: cs.onSurfaceVariant),
                    ),
                  )
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.videocam_outlined, color: cs.onSurfaceVariant),
                  ),
            // 底部统计信息
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(video.likes ?? 0),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
