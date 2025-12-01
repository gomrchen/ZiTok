import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../models/video.dart';
import '../../models/notes_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/video_provider.dart';
import '../../services/user_service.dart';
import '../../services/notes_service.dart';
import '../../repositories/notes_repository.dart';
import '../../theme/theme_tokens.dart';
import '../../providers/profile_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_models.dart';
import '../../utils/url_utils.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _initialLoadComplete = false;
  int _videosCount = 0; // 添加视频计数状态
  bool _loadingVideosCount = false; // 添加视频数量加载状态

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<ProfileProvider>().loadCurrentUser();

        // 用户数据加载完成后，立即加载视频数量
        _loadVideosCount();

        setState(() {
          _initialLoadComplete = true;
        });
      } catch (e) {
        // Error loading user data
      }
    });
  }

  // 独立加载视频数量
  void _loadVideosCount() async {
    if (mounted) {
      setState(() {
        _loadingVideosCount = true;
      });
    }

    try {
      // 获取用户ID
      final String? userId = await _getUserId();

      if (userId == null || userId.isEmpty) {
        return;
      }

      // 使用UserService获取视频列表并统计数量
      final userService = UserService(AppBootstrap.apiClient.dio);
      final videos = await userService.getVideos(
        userId: userId,
        page: 1,
        size: 999, // 只获取1条来统计总数
      );

      if (mounted) {
        setState(() {
          _videosCount = videos.length;
        });
      }

    } catch (e) {
      // Error loading videos count
    } finally {
      if (mounted) {
        setState(() {
          _loadingVideosCount = false;
        });
      }
    }
  }

  // 获取用户ID的独立方法
  Future<String?> _getUserId() async {
    // 方法1: 从 ProfileProvider 获取（主要方法）
    final profileProvider = context.read<ProfileProvider>();
    final profileUser = profileProvider.user;

    if (profileUser != null && profileUser.id.isNotEmpty) {
      return profileUser.id;
    }

    // 方法2: 从 AuthProvider 获取（备用方法）
    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        return authUser.id;
      }
    } catch (e) {
      // Error getting user ID from AuthProvider
    }

    // 方法3: 从本地存储获取（最后备选）
    return await _getUserIdFromStorage();
  }

  Future<String?> _getUserIdFromStorage() async {
    try {
      // 首先尝试从 Hive 获取
      final box = await Hive.openBox('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        return hiveUserId;
      }

      // 然后尝试从 SharedPreferences 获取（统一使用 user_id）
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('user_id');

      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        return prefsUserId;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 添加视频数量更新方法
  void _updateVideosCount(int count) {
    setState(() {
      _videosCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final user = profile.user;

    // 如果初始加载未完成且不在加载状态，显示加载指示器
    if (!_initialLoadComplete && !profile.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示加载状态
    if (profile.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示错误信息
    if (profile.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('加载失败: ${profile.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<ProfileProvider>().loadFromCache();
                  setState(() {
                    _initialLoadComplete = false;
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = math.min(520.0, constraints.maxWidth);
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: maxW),
              child: DefaultTabController(
                length: 3,
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(child: _ProfileHeader(
                        userName: user?.username ?? '用户',
                        bio: user?.bio ?? '',
                        avatarUrl: user?.avatarUrl,
                        backgroundUrl: user?.profileBackgroundImageUrl,
                        gender: user?.gender,
                        birthday: user?.birthday,
                        onEdit: () => context.push('/profile/edit'))),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                              child: _StatsRow(
                                videosCount: _videosCount,
                                loadingVideosCount: _loadingVideosCount,
                              ), // 传递视频数量和加载状态
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickyTabBarDelegate(
                              child: Builder(
                                builder: (context) {
                                  final cs = Theme.of(context).colorScheme;
                                  return Container(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    child: TabBar(
                                      labelColor: cs.primary,
                                      unselectedLabelColor: cs.onSurfaceVariant,
                                      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      indicator: UnderlineTabIndicator(
                                        borderSide: BorderSide(color: cs.primary, width: 2),
                                      ),
                                      tabs: const [
                                        Tab(text: '我的收藏'),
                                        Tab(text: '我的笔记'),
                                        Tab(text: '我的视频'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        body: TabBarView(
                          children: [
                            _FavoritesList(),
                            _NotesTab(),
                            _VideosTab(onVideosLoaded: _updateVideosCount), // 传递回调函数
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
          ),
        );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String userName;
  final String bio;
  final String? avatarUrl;
  final String? backgroundUrl;
  final Gender? gender;
  final String? birthday;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.userName,
    required this.bio,
    required this.avatarUrl,
    this.backgroundUrl,
    this.gender,
    this.birthday,
    required this.onEdit
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.themeName == 'dark';
    const double headerHeight = 176;
    const double avatarRadius = 36;

    return Semantics(
      label: '个人资料头部',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // 背景容器 - 包含透明度渐变和横向缩放
              _buildBackground(headerHeight, backgroundUrl),

              // 顶部功能栏（覆盖在背景上，透明背景）
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左侧：主题切换按钮
                        Tooltip(
                          message: isDark ? '切换到浅色模式' : '切换到深色模式',
                          child: IconButton(
                            onPressed: () => themeProvider.toggleDark(),
                            icon: Icon(
                              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // 右侧：菜单入口按钮
                        Tooltip(
                          message: '设置',
                          child: IconButton(
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(
                              Icons.menu,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 内容层
              SizedBox(
                height: headerHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 头像部分
                        _buildAvatar(cs, avatarRadius),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName.isEmpty ? '用户' : userName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${userName.isEmpty ? 'unknown' : userName}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 12
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2BD2C4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            overlayColor: const Color(0x1F2BD2C4),
                          ),
                          onPressed: onEdit,
                          child: const Text('编辑主页'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 简介部分保持不变
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bio.isEmpty ? '完善个人介绍' : bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (gender != null && gender != Gender.unknown)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                              borderRadius: Radii.sm
                          ),
                          child: Text(
                              gender == Gender.male ? '男' : '女',
                              style: Theme.of(context).textTheme.bodySmall
                          ),
                        ),
                      if ((gender != null && gender != Gender.unknown) &&
                          (birthday != null && birthday!.isNotEmpty))
                        const SizedBox(width: Spacing.sm),
                      if (birthday != null && birthday!.isNotEmpty)
                        Text(
                            '生日 $birthday',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant
                            )
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 重构背景构建方法 - 添加上到下透明度渐变和横向缩放
// 在 profile_page.dart 中确保 _buildBackground 方法使用正确的 fit
  Widget _buildBackground(double headerHeight, String? backgroundUrl) {
    // 如果有有效的背景图URL，显示网络图片
    if (backgroundUrl != null && backgroundUrl.isNotEmpty && backgroundUrl != 'null') {
      return SizedBox(
        height: headerHeight,
        width: double.infinity,
        child: Stack(
          children: [
            // 背景图片 - 横向填充
            Image.network(
              backgroundUrl,
              fit: BoxFit.fitWidth, // 确保使用 fitWidth 进行水平填充
              width: double.infinity,
              height: headerHeight,
              errorBuilder: (context, error, stackTrace) {
                return _buildGradientBackground(headerHeight);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildGradientBackground(headerHeight);
              },
            ),
            // 渐变遮罩保持不变...
          ],
        ),
      );
    }

    return _buildGradientBackground(headerHeight);
  }

  // 渐变背景构建方法
  Widget _buildGradientBackground(double headerHeight) {
    return Container(
      height: headerHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2BD2C4),
            Color(0xFFEFF9F7),
          ],
        ),
      ),
    );
  }

  // 头像构建方法
  Widget _buildAvatar(ColorScheme cs, double avatarRadius) {
    if (avatarUrl == null || avatarUrl!.isEmpty || avatarUrl == 'null') {
      return CircleAvatar(
        radius: avatarRadius,
        backgroundColor: const Color(0xFF2BD2C4),
        child: Icon(
            Icons.person,
            color: cs.onPrimary,
            size: 24
        ),
      );
    }

    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: const Color(0xFF2BD2C4),
      backgroundImage: NetworkImage(avatarUrl!),
      onBackgroundImageError: (exception, stackTrace) {
        // Error loading avatar image
      },
      child: avatarUrl == null ? Icon(
          Icons.person,
          color: cs.onPrimary,
          size: 24
      ) : null,
    );
  }
}

class _StatsRow extends StatefulWidget {
  final int videosCount; // 接收视频数量
  final bool loadingVideosCount; // 接收视频数量加载状态

  const _StatsRow({
    required this.videosCount,
    required this.loadingVideosCount,
  });

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  String? _userId;
  int _notesCount = 0;
  bool _loadingNotesCount = false;

  @override
  void initState() {
    super.initState();
    // 组件初始化时获取用户ID并加载统计数据
    _getUserIdAndLoadStats();
  }

  void _getUserIdAndLoadStats() {
    // 方法1: 从 ProfileProvider 获取（主要方法）
    final profileProvider = context.read<ProfileProvider>();
    final profileUser = profileProvider.user;

    if (profileUser != null && profileUser.id.isNotEmpty) {
      _userId = profileUser.id;
      _loadStats();
      _loadNotesCount();
      return;
    }

    // 方法2: 从 AuthProvider 获取（备用方法）
    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        _userId = authUser.id;
        _loadStats();
        _loadNotesCount();
        return;
      }
    } catch (e) {
      // Error getting user ID from AuthProvider
    }

    // 方法3: 从本地存储获取（最后备选）
    _getUserIdFromStorage();
  }

  void _getUserIdFromStorage() async {
    try {
      // 首先尝试从 Hive 获取
      final box = await Hive.openBox('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        setState(() {
          _userId = hiveUserId;
        });
        _loadStats();
        _loadNotesCount();
        return;
      }

      // 然后尝试从 SharedPreferences 获取（统一使用 user_id）
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('user_id');

      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        setState(() {
          _userId = prefsUserId;
        });
        _loadStats();
        _loadNotesCount();
        return;
      }

    } catch (e) {
      // Error getting user ID from storage
    }
  }

  void _loadStats() {
    if (_userId == null || _userId!.isEmpty) {
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    profileProvider.loadUserStats(userId: _userId!);
  }

  /// 加载笔记数量
  Future<void> _loadNotesCount() async {
    if (_userId == null || _userId!.isEmpty) return;

    if (mounted) {
      setState(() => _loadingNotesCount = true);
    }

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final result = await notesRepo.getUserNotes(
        userId: int.tryParse(_userId!) ?? 0,
        page: 1,
        pageSize: 1, // 只需获取总数
      );

      if (mounted) {
        setState(() {
          _notesCount = result.total;
        });
      }
    } catch (e) {
      // Error loading notes count
    } finally {
      if (mounted) {
        setState(() => _loadingNotesCount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final cs = Theme.of(context).colorScheme;

    Widget cell(String num, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(num, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: (profile.loadingStats || widget.loadingVideosCount) ? cs.onSurfaceVariant : cs.onSurface,
        )),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        )),
      ],
    );

    // 显示视频数量（处理加载状态）
    String getVideosCountText() {
      if (widget.loadingVideosCount) {
        return '...';
      }
      return widget.videosCount.toString();
    }

    // 显示笔记数量（处理加载状态）
    String getNotesCountText() {
      if (_loadingNotesCount) {
        return '...';
      }
      return _notesCount.toString();
    }

    // 如果没有获取到用户ID，显示加载状态
    if (_userId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell(getVideosCountText(), '视频'), // 使用传入的视频数量
            cell(getNotesCountText(), '笔记'),
            cell('...', '粉丝'),
            cell('...', '关注'),
          ],
        ),
      );
    }

    // 显示加载状态
    if (profile.loadingStats) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell(getVideosCountText(), '视频'), // 使用传入的视频数量
            cell(getNotesCountText(), '笔记'),
            cell('...', '粉丝'),
            cell('...', '关注'),
          ],
        ),
      );
    }

    // 显示错误状态
    if (profile.statsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                cell(getVideosCountText(), '视频'), // 使用传入的视频数量
                cell(getNotesCountText(), '笔记'),
                cell('0', '粉丝'),
                cell('0', '关注'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '统计数据加载失败',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          cell(getVideosCountText(), '视频'), // 使用传入的视频数量
          cell(getNotesCountText(), '笔记'),
          cell(profile.followersCount.toString(), '粉丝'),
          cell(profile.followingsCount.toString(), '关注'),
        ],
      ),
    );
  }
}

class _FavoritesList extends StatefulWidget {
  const _FavoritesList();

  @override
  State<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<_FavoritesList> {
  String _sortBy = 'like'; // 'like' or 'comment'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vp = context.read<VideoProvider>();
      if (vp.favorites.isEmpty) {
        vp.refreshFavorites();
      }
    });
  }

  /// 根据排序方式对收藏列表排序
  List<Video> _sortedFavorites(List<Video> favorites) {
    final sorted = List<Video>.from(favorites);
    if (_sortBy == 'like') {
      sorted.sort((a, b) => (b.likes ?? 0).compareTo(a.likes ?? 0));
    } else {
      sorted.sort((a, b) => (b.commentCount ?? 0).compareTo(a.commentCount ?? 0));
    }
    return sorted;
  }

  Widget _buildThumbnail(Video video) {
    final coverUrl = video.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          UrlUtils.resolveStorageUrl(coverUrl, defaultDir: 'covers'),
          width: 80,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultThumbnail(),
        ),
      );
    }
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.videocam, color: Colors.grey),
    );
  }

  Future<void> _unfavorite(String videoId) async {
    final vp = context.read<VideoProvider>();
    final success = await vp.toggleFavorite(videoId);
    if (success) {
      // 刷新收藏列表
      await vp.refreshFavorites();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消收藏失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final favorites = vp.favorites;
    final sortedFavorites = _sortedFavorites(favorites);
    final loading = vp.loadingFavorites;

    if (loading && favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_border,
                color: cs.onSurfaceVariant,
                size: 64,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '暂无收藏',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '您还没有收藏任何视频',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              ElevatedButton(
                onPressed: () => vp.refreshFavorites(),
                child: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 排序栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.star_outline, size: 18, color: cs.primary),
              const SizedBox(width: Spacing.xs),
              Text('收藏视频 (${favorites.length})', style: theme.textTheme.labelLarge),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (value) => setState(() => _sortBy = value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _sortBy == 'like' ? '按点赞数' : '按评论数',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'like', child: Text('按点赞数排序')),
                  const PopupMenuItem(value: 'comment', child: Text('按评论数排序')),
                ],
              ),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => vp.refreshFavorites(),
            child: ListView.separated(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: sortedFavorites.length + (vp.favoritesHasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
              itemBuilder: (context, i) {
                // 加载更多指示器
                if (i >= sortedFavorites.length) {
                  if (!loading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      vp.loadMoreFavorites();
                    });
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final video = sortedFavorites[i];
                return ListTile(
                  leading: _buildThumbnail(video),
                  title: Text(
                    video.title ?? '未命名视频',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Icon(Icons.thumb_up_outlined, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${video.likes ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Icon(Icons.chat_bubble_outline, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${video.commentCount ?? 0}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Color(0xFFFFD700)),
                    tooltip: '取消收藏',
                    onPressed: () => _unfavorite(video.id),
                  ),
                  onTap: () {
                    context.push('/video/${video.id}', extra: video);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesTab extends StatefulWidget {
  const _NotesTab();

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  List<NoteItem> _notes = [];
  bool _loading = false;
  String? _error;
  String? _userId;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;
  String _sortBy = 'like'; // 'like' or 'favorite'

  /// 根据排序方式对笔记列表排序
  List<NoteItem> get _sortedNotes {
    final sorted = List<NoteItem>.from(_notes);
    if (_sortBy == 'like') {
      sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      sorted.sort((a, b) => b.favoriteCount.compareTo(a.favoriteCount));
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _getUserIdAndLoadNotes();
  }

  void _getUserIdAndLoadNotes() {
    final profileProvider = context.read<ProfileProvider>();
    final profileUser = profileProvider.user;

    if (profileUser != null && profileUser.id.isNotEmpty) {
      _userId = profileUser.id;
      _loadNotes();
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        _userId = authUser.id;
        _loadNotes();
        return;
      }
    } catch (e) {
      // Error getting user ID from AuthProvider
    }

    _getUserIdFromStorage();
  }

  void _getUserIdFromStorage() async {
    try {
      final box = await Hive.openBox('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        setState(() => _userId = hiveUserId);
        _loadNotes();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('user_id');

      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        setState(() => _userId = prefsUserId);
        _loadNotes();
        return;
      }

      setState(() {
        _error = '无法获取用户ID，请重新登录';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '获取用户信息失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadNotes({bool refresh = false}) async {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _error = '用户ID为空，无法加载笔记';
        _loading = false;
      });
      return;
    }

    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    if (mounted) {
      setState(() {
        _loading = true;
        if (refresh) _error = null;
      });
    }

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final result = await notesRepo.getUserNotes(
        userId: int.tryParse(_userId!) ?? 0,
        page: _page,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _notes = result.notes;
          } else {
            _notes.addAll(result.notes);
          }
          _hasMore = result.notes.length >= _pageSize;
          _page++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sortedNotes = _sortedNotes;

    if (_userId == null && !_loading && _error == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loading && _notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 48),
              const SizedBox(height: Spacing.md),
              Text('加载失败', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.error)),
              const SizedBox(height: Spacing.sm),
              Text(_error!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: Spacing.lg),
              ElevatedButton(onPressed: _getUserIdAndLoadNotes, child: const Text('重新加载')),
            ],
          ),
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.note_outlined, color: cs.onSurfaceVariant, size: 64),
              const SizedBox(height: Spacing.md),
              Text('暂无笔记', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: Spacing.sm),
              Text('您还没有发布任何笔记', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: Spacing.lg),
              ElevatedButton(onPressed: () => _loadNotes(refresh: true), child: const Text('刷新')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 排序栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 18, color: cs.primary),
              const SizedBox(width: Spacing.xs),
              Text('我的笔记 (${_notes.length})', style: theme.textTheme.labelLarge),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (value) => setState(() => _sortBy = value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _sortBy == 'like' ? '按点赞数' : '按收藏数',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'like', child: Text('按点赞数排序')),
                  const PopupMenuItem(value: 'favorite', child: Text('按收藏数排序')),
                ],
              ),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _loadNotes(refresh: true),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  if (_hasMore && !_loading &&
                      notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
                    _loadNotes();
                  }
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(Spacing.md),
                itemCount: sortedNotes.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= sortedNotes.length) {
                    return const Padding(
                      padding: EdgeInsets.all(Spacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final note = sortedNotes[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _NoteListItem(
                      note: note,
                      onTap: () async {
                        await context.push('/profile/note/${note.id}/manage', extra: {
                          'note': note,
                        });
                        _loadNotes(refresh: true);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteListItem extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;

  const _NoteListItem({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.article_outlined, color: cs.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : '无标题笔记',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.thumb_up_outlined, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${note.likeCount}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Icon(Icons.star_outline, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${note.favoriteCount}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideosTab extends StatefulWidget {
  final Function(int)? onVideosLoaded;

  const _VideosTab({this.onVideosLoaded});

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab> with WidgetsBindingObserver {
  List<Video> _videos = [];
  bool _loading = false;
  String? _error;
  String? _userId;
  bool _needsRefresh = false;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;
  String _sortBy = 'like'; // 'like' or 'comment'

  /// 根据排序方式对视频列表排序
  List<Video> get _sortedVideos {
    final sorted = List<Video>.from(_videos);
    if (_sortBy == 'like') {
      sorted.sort((a, b) => (b.likes ?? 0).compareTo(a.likes ?? 0));
    } else {
      sorted.sort((a, b) => (b.commentCount ?? 0).compareTo(a.commentCount ?? 0));
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getUserIdAndLoadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_needsRefresh) {
        _loadVideos();
        _needsRefresh = false;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Note: addScopedWillPopCallback is deprecated in newer Flutter versions
    // Consider using PopScope widget instead if needed
    // Commenting out deprecated code for now
    /*
    ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      route.addScopedWillPopCallback(() {
        _needsRefresh = true;
        return SynchronousFuture(true);
      });
    }
    */
  }

  void _getUserIdAndLoadVideos() {
    // 方法1: 从 ProfileProvider 获取（主要方法）
    final profileProvider = context.read<ProfileProvider>();
    final profileUser = profileProvider.user;

    if (profileUser != null && profileUser.id.isNotEmpty) {
      _userId = profileUser.id;
      _loadVideos();
      return;
    }

    // 方法2: 从 AuthProvider 获取（备用方法）
    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        _userId = authUser.id;
        _loadVideos();
        return;
      }
    } catch (e) {
      // Error getting user ID from AuthProvider
    }

    // 方法3: 从本地存储获取（最后备选）
    _getUserIdFromStorage();
  }

  void _getUserIdFromStorage() async {
    try {
      // 首先尝试从 Hive 获取
      final box = await Hive.openBox('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        setState(() {
          _userId = hiveUserId;
        });
        _loadVideos();
        return;
      }

      // 然后尝试从 SharedPreferences 获取（统一使用 user_id）
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('user_id');

      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        setState(() {
          _userId = prefsUserId;
        });
        _loadVideos();
        return;
      }

      setState(() {
        _error = '无法获取用户ID，请重新登录';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '获取用户信息失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _error = '用户ID为空，无法加载视频';
        _loading = false;
      });
      return;
    }

    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    if (mounted) {
      setState(() {
        _loading = true;
        if (refresh) _error = null;
      });
    }

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final videos = await userService.getVideos(
        userId: _userId!,
        page: _page,
        size: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _videos = videos;
          } else {
            _videos.addAll(videos);
          }
          _hasMore = videos.length >= _pageSize;
          _page++;
        });
      }

      // 新增：通知父组件视频数量更新
      if (widget.onVideosLoaded != null) {
        widget.onVideosLoaded!(_videos.length);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _refreshVideos() {
    _loadVideos(refresh: true);
  }

  // 构建视频封面组件
  Widget _buildVideoThumbnail(Video video) {
    String? resolvedCoverUrl;

    if (video.coverUrl != null && video.coverUrl!.isNotEmpty) {
      resolvedCoverUrl = UrlUtils.resolveStorageUrl(video.coverUrl!, defaultDir: 'covers');
    }

    if (resolvedCoverUrl != null && resolvedCoverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          resolvedCoverUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultThumbnail();
          },
        ),
      );
    }
    return _buildDefaultThumbnail();
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.videocam, color: Colors.grey),
    );
  }

  // 构建视频统计信息 - 使用统一的icon样式
  Widget _buildVideoStats(Video video) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.thumb_up_outlined, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${video.likes ?? 0}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 12),
        Icon(Icons.chat_bubble_outline, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('${video.commentCount ?? 0}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final sortedVideos = _sortedVideos;

    // 如果还没有获取到用户ID，显示加载状态
    if (_userId == null && !_loading && _error == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示加载状态
    if (_loading && _videos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示错误状态
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: cs.error,
                size: 48,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.error,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.lg),
              ElevatedButton(
                onPressed: _getUserIdAndLoadVideos,
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    // 显示空状态
    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: cs.onSurfaceVariant,
                size: 64,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                '暂无视频',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '您还没有发布任何视频',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              ElevatedButton(
                onPressed: _refreshVideos,
                child: const Text('刷新'),
              ),
            ],
          ),
        ),
      );
    }

    // 显示视频列表 - 添加刷新指示器和分页
    return Column(
      children: [
        // 排序栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.video_library_outlined, size: 18, color: cs.primary),
              const SizedBox(width: Spacing.xs),
              Text('我的视频 (${_videos.length})', style: theme.textTheme.labelLarge),
              const Spacer(),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (value) => setState(() => _sortBy = value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _sortBy == 'like' ? '按点赞数' : '按评论数',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'like', child: Text('按点赞数排序')),
                  const PopupMenuItem(value: 'comment', child: Text('按评论数排序')),
                ],
              ),
            ],
          ),
        ),
        // 列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadVideos(refresh: true);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  if (_hasMore && !_loading &&
                      notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
                    _loadVideos();
                  }
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(Spacing.md),
                itemCount: sortedVideos.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= sortedVideos.length) {
                    return const Padding(
                      padding: EdgeInsets.all(Spacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final video = sortedVideos[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: ListTile(
                      leading: _buildVideoThumbnail(video),
                      title: Text(
                        video.title ?? '未命名视频',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (video.intro != null && video.intro!.isNotEmpty) ...[
                            Text(
                              video.intro!,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                          ],
                          _buildVideoStats(video),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                        onPressed: () async {
                          await context.push('/profile/video/${video.id}/manage', extra: {
                            'title': video.title ?? '未命名视频',
                            'description': video.intro ?? '',
                            'likes': video.likes ?? 0,
                            'views': video.views ?? 0,
                            'coverUrl': UrlUtils.resolveStorageUrl(video.coverUrl ?? '', defaultDir: 'covers'),
                            'videoUrl': video.videoUrl,
                            'tags': video.tags,
                          });

                          // 返回后刷新视频列表
                          _refreshVideos();
                        },
                      ),
                      onTap: () async {
                        await context.push('/profile/video/${video.id}/manage', extra: {
                          'title': video.title ?? '未命名视频',
                          'description': video.intro ?? '',
                          'likes': video.likes ?? 0,
                          'views': video.views ?? 0,
                          'coverUrl': UrlUtils.resolveStorageUrl(video.coverUrl ?? '', defaultDir: 'covers'),
                          'videoUrl': video.videoUrl,
                          'tags': video.tags,
                        });

                        // 返回后刷新视频列表
                        _refreshVideos();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// TabBar 固定在顶部的代理类
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}