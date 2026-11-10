import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../drama/drama_player_page.dart';
import '../drama/theater_page.dart';
import '../drama/watching_page.dart';
import '../profile/profile_page.dart';
import '../../widgets/nav_items.dart';
import '../../services/video/video_preload_manager.dart';
import '../../services/video_playback_manager.dart';
import '../../app.dart';

/// 短剧主壳：首页连播 / 剧场 / 追剧 / 我的
class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;
  bool _isRefreshingToken = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.clamp(0, 3);
    AppBootstrap.userSession.onAuthenticationFailed = _handleAuthenticationFailed;
    _refreshTokenInBackground();
  }

  @override
  void dispose() {
    AppBootstrap.userSession.onAuthenticationFailed = null;
    super.dispose();
  }

  Future<void> _refreshTokenInBackground() async {
    if (_isRefreshingToken) return;
    _isRefreshingToken = true;
    try {
      final success = await AppBootstrap.refreshTokenIfNeeded();
      if (!success && mounted) _handleAuthenticationFailed();
    } finally {
      _isRefreshingToken = false;
    }
  }

  void _handleAuthenticationFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录已失效，请重新登录'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) context.go('/auth/login');
    });
  }

  void _onTabChanged(int newIndex) {
    final oldIndex = _index;
    setState(() => _index = newIndex);
    if (oldIndex == 0 && newIndex != 0) {
      _preloadManager.pauseAll();
      VideoPlaybackManager.instance.pauseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) _onTabChanged(0);
      },
      child: Scaffold(
        // 首页连播：视频铺满屏，底栏浮在画面上（红果沉浸）
        extendBody: true,
        extendBodyBehindAppBar: true,
        // 非首页用纸色，避免「我的」刘海露出壳层黑边
        backgroundColor: _index == 0 ? Colors.black : const Color(0xFFF4F1EC),
        body: IndexedStack(
          index: _index,
          sizing: StackFit.expand,
          children: const [
            DramaPlayerPage(),
            TheaterPage(),
            WatchingPage(),
            ProfilePage(),
          ],
        ),
        bottomNavigationBar: _HomeBottomBar(
          index: _index,
          immersive: _index == 0,
          onChanged: _onTabChanged,
        ),
      ),
    );
  }
}

class _HomeBottomBar extends StatelessWidget {
  final int index;
  final bool immersive;
  final ValueChanged<int> onChanged;

  const _HomeBottomBar({
    required this.index,
    required this.immersive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bar = SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            NavItem(
              label: '首页',
              icon: Icons.play_circle_outline,
              selectedIcon: Icons.play_circle,
              selected: index == 0,
              onDark: immersive,
              onTap: () => onChanged(0),
            ),
            NavItem(
              label: '剧场',
              icon: Icons.theater_comedy_outlined,
              selectedIcon: Icons.theater_comedy,
              selected: index == 1,
              onDark: immersive,
              onTap: () => onChanged(1),
            ),
            NavItem(
              label: '追剧',
              icon: Icons.bookmark_outline,
              selectedIcon: Icons.bookmark,
              selected: index == 2,
              onDark: immersive,
              onTap: () => onChanged(2),
            ),
            NavItem(
              label: '我的',
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              selected: index == 3,
              onDark: immersive,
              onTap: () => onChanged(3),
            ),
          ],
        ),
      ),
    );

    if (!immersive) {
      return Material(color: Theme.of(context).colorScheme.surface, child: bar);
    }

    // 透明 Material + 渐变：保证视频能透过底栏顶部，避免白底裁切感
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.45),
              Colors.black.withValues(alpha: 0.78),
            ],
          ),
        ),
        child: bar,
      ),
    );
  }
}
