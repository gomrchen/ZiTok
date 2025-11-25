import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../theme/theme_tokens.dart';
import '../../providers/profile_provider.dart';
import '../../models/user_models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    print('🚀 ProfilePage: initState 调用');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('📱 ProfilePage: 开始加载用户数据');
      try {
        await context.read<ProfileProvider>().loadFromAuthProvider(context);
        setState(() {
          _initialLoadComplete = true;
        });
      } catch (e) {
        print('❌ ProfilePage: 加载用户数据失败: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final user = profile.user;

    // 添加详细的用户数据调试信息
    print('🔍 ProfilePage 用户数据检查:');
    print('   - user对象: ${user != null ? "非空" : "空"}');
    print('   - username: ${user?.username ?? "null"}');
    print('   - id: ${user?.id ?? "null"}');
    print('   - avatarUrl: ${user?.avatarUrl ?? "null"}');
    print('   - bio: ${user?.bio ?? "null"}');
    print('   - profileBackgroundImageUrl: ${user?.profileBackgroundImageUrl ?? "null"}');
    print('   - _initialLoadComplete: $_initialLoadComplete');
    print('   - profile.loading: ${profile.loading}');

    // 如果初始加载未完成且不在加载状态，显示加载指示器
    if (!_initialLoadComplete && !profile.loading) {
      print('⏳ ProfilePage: 显示初始加载状态');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示加载状态
    if (profile.loading) {
      print('⏳ ProfilePage: 显示加载状态');
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 显示错误信息
    if (profile.error != null) {
      print('❌ ProfilePage: 显示错误: ${profile.error}');
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

    print('✅ ProfilePage: 显示用户数据 - username: ${user?.username ?? "null"}');

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
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                          child: _StatsRow(),
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
                            _VideosTab(),
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
              Container(
                height: headerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2BD2C4),
                      Color(0xFFEFF9F7),
                    ],
                  ),
                  image: backgroundUrl == null
                      ? null
                      : DecorationImage(
                      image: NetworkImage(backgroundUrl!),
                      fit: BoxFit.cover
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 头像部分 - 添加调试信息和错误处理
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

  // 提取头像构建方法，添加调试和错误处理
  Widget _buildAvatar(ColorScheme cs, double avatarRadius) {
    print('🖼️ 头像URL: $avatarUrl'); // 调试信息

    // 如果头像URL为空，显示默认图标
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      print('⚠️ 头像URL为空，显示默认图标');
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

    // 如果有头像URL，显示网络图片
    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: const Color(0xFF2BD2C4),
      backgroundImage: NetworkImage(avatarUrl!),
      // 添加错误处理，如果图片加载失败显示默认图标
      child: avatarUrl == null ? Icon(
          Icons.person,
          color: cs.onPrimary,
          size: 24
      ) : null,
    );
  }
}

class _StatsRow extends StatefulWidget {
  const _StatsRow();

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
    print('🔍 _StatsRow: 开始获取用户ID');

    // 方法1: 从 ProfileProvider 获取（主要方法）
    final profileProvider = context.read<ProfileProvider>();
    final profileUser = profileProvider.user;

    if (profileUser != null && profileUser.id.isNotEmpty) {
      print('✅ _StatsRow: 从ProfileProvider获取到用户ID: ${profileUser.id}');
      _userId = profileUser.id;
      _loadStats();
      return;
    }

    // 方法2: 从 AuthProvider 获取（备用方法）
    try {
      final authProvider = context.read<AuthProvider>();
      final authUser = authProvider.user;
      if (authUser != null && authUser.id.isNotEmpty) {
        print('✅ _StatsRow: 从AuthProvider获取到用户ID: ${authUser.id}');
        _userId = authUser.id;
        _loadStats();
        return;
      }
    } catch (e) {
      print('⚠️ _StatsRow: 从AuthProvider获取用户ID失败: $e');
    }

    // 方法3: 从本地存储获取（最后备选）
    _getUserIdFromStorage();
  }

  void _getUserIdFromStorage() async {
    try {
      print('🔍 _StatsRow: 尝试从本地存储获取用户ID');

      // 首先尝试从 Hive 获取
      final box = await Hive.openBox('user_box');
      final String? hiveUserId = box.get('id') as String?;

      if (hiveUserId != null && hiveUserId.isNotEmpty) {
        print('✅ _StatsRow: 从Hive获取到用户ID: $hiveUserId');
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
        print('✅ _StatsRow: 从SharedPreferences获取到用户ID: $prefsUserId');
        setState(() {
          _userId = prefsUserId;
        });
        _loadStats();
        return;
      }

      print('❌ _StatsRow: 无法从任何地方获取用户ID');
    } catch (e) {
      print('❌ _StatsRow: 从本地存储获取用户ID失败: $e');
    }
  }

  void _loadStats() {
    if (_userId == null || _userId!.isEmpty) {
      print('⚠️ _StatsRow: 用户ID为空，无法加载统计数据');
      return;
    }

    final profileProvider = context.read<ProfileProvider>();
    print('🔍 _StatsRow: 开始加载用户统计数据，userId: $_userId');
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
          color: profile.loadingStats ? cs.onSurfaceVariant : cs.onSurface,
        )),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        )),
      ],
    );

    // 如果没有获取到用户ID，显示加载状态
    if (_userId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell('-', '视频'),
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
            cell('-', '视频'),
            cell('-', '笔记'),
            cell('...', '粉丝'),
            cell('...', '关注'),
          ],
        ),
      );
    }

    // 显示错误状态
    if (profile.statsError != null) {
      print('❌ _StatsRow: 统计数据加载错误: ${profile.statsError}');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                cell('-', '视频'),
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

    print('✅ _StatsRow: 显示统计数据 - 粉丝: ${profile.followersCount}, 关注: ${profile.followingsCount}');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          cell('-', '视频'),
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

class _VideosTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Spacing.md),
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.video_library),
        title: Text('视频 #$i'),
        subtitle: const Text('视频简介…'),
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => context.push('/profile/video/$i/manage', extra: {
            'title': '视频 #$i',
            'tags': const ['教程'],
            'likes': 0,
            'favorites': 0,
            'views': 0,
            'coverUrl': null,
          }),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemCount: 8,
    );
  }
}

