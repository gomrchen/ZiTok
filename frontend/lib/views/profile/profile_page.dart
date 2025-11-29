import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../models/video.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../theme/theme_tokens.dart';
import '../../providers/profile_provider.dart';
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
        await context.read<ProfileProvider>().loadFromAuthProvider(context);

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

      // 然后尝试从 SharedPreferences 获取
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('auth_user_id');

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
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = math.min(520.0, constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints.tightFor(width: maxW),
                child: DefaultTabController(
                  length: 3,
                  child: CustomScrollView(
                    slivers: [
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: Spacing.md),
                          child: Builder(
                            builder: (context) {
                              final cs = Theme.of(context).colorScheme;
                              return TabBar(
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
                              );
                            },
                          ),
                        ),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: TabBarView(
                          children: [
                            _FavoritesList(),
                            _NotesTab(),
                            _VideosTab(onVideosLoaded: _updateVideosCount), // 传递回调函数
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 右上角菜单入口按钮（跳转设置页）
class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: '设置',
      child: Semantics(
        button: true,
        label: '打开设置',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              // push 到设置页，保留返回动画
              context.push('/settings');
            },
            child: SizedBox(
              width: 48,
              height: 48,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.dehaze, color: cs.onSurface, size: 20),
              ),
            ),
          ),
        ),
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
              const Positioned(
                right: Spacing.md,
                top: Spacing.sm,
                child: _MenuActionButton(),
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
      return;
    }

    // 方法2: 从 AuthProvider 获取（备用方法）
    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        _userId = authUser.id;
        _loadStats();
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
        return;
      }

      // 然后尝试从 SharedPreferences 获取
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('auth_user_id');

      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        setState(() {
          _userId = prefsUserId;
        });
        _loadStats();
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

    // 如果没有获取到用户ID，显示加载状态
    if (_userId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell(getVideosCountText(), '视频'), // 使用传入的视频数量
            cell('-', '笔记'),
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
            cell('-', '笔记'),
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
                cell('-', '笔记'),
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
          cell('-', '笔记'),
          cell(profile.followersCount.toString(), '粉丝'),
          cell(profile.followingsCount.toString(), '关注'),
        ],
      ),
    );
  }
}

class _FavoritesList extends StatelessWidget {
  const _FavoritesList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Spacing.md),
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.bookmark),
        title: Text('收藏项 #$i'),
        subtitle: const Text('收藏的内容简介'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemCount: 6,
    );
  }
}

class _NotesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Spacing.md),
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.note),
        title: Text('笔记 #$i'),
        subtitle: const Text('笔记摘要…'),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => context.push('/profile/note/$i/manage', extra: {
            'title': '笔记 #$i',
            'tags': const ['学习', '记录'],
            'likes': 0,
            'favorites': 0,
            'reads': 0,
          }),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemCount: 8,
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

      // 然后尝试从 SharedPreferences 获取
      final prefs = await SharedPreferences.getInstance();
      final String? prefsUserId = prefs.getString('auth_user_id');

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

  Future<void> _loadVideos() async {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _error = '用户ID为空，无法加载视频';
        _loading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final videos = await userService.getVideos(
        userId: _userId!,
        page: 1,
        size: 20,
      );

      if (mounted) {
        setState(() {
          _videos = videos;
        });
      }

      // 新增：通知父组件视频数量更新
      if (widget.onVideosLoaded != null) {
        widget.onVideosLoaded!(videos.length);
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
    _loadVideos();
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

  // 构建视频统计信息
  Widget _buildVideoStats(Video video) {
    final stats = <String>[];

    if (video.views != null && video.views! > 0) {
      stats.add('${video.views} 播放');
    }

    if (video.likes != null && video.likes! > 0) {
      stats.add('${video.likes} 点赞');
    }

    if (stats.isEmpty) {
      stats.add('暂无数据');
    }

    return Text(
      stats.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
    if (_loading) {
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

    // 显示视频列表 - 添加刷新指示器
    return RefreshIndicator(
      onRefresh: () async {
        await _loadVideos();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(Spacing.md),
        itemCount: _videos.length,
        separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
        itemBuilder: (context, index) {
          final video = _videos[index];
          return ListTile(
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
          );
        },
      ),
    );
  }
}