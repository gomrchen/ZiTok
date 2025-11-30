import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../video/discover_page.dart';
import '../follow/follow_page.dart';
import '../messages/messages_page.dart';
import '../../widgets/nav_items.dart';
import '../profile/profile_page.dart';
import '../../services/video/video_preload_manager.dart';
import '../../app.dart';

/// 统一主界面：以组件方式管理四个模块，避免重复底部导航
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final VideoPreloadManager _preloadManager = VideoPreloadManager.instance;
  bool _isRefreshingToken = false;

  @override
  void initState() {
    super.initState();
    // 设置认证失效回调
    AppBootstrap.userSession.onAuthenticationFailed = _handleAuthenticationFailed;
    // 进入主界面后在后台刷新token
    _refreshTokenInBackground();
  }

  @override
  void dispose() {
    // 清理认证失效回调
    AppBootstrap.userSession.onAuthenticationFailed = null;
    super.dispose();
  }

  /// 在后台刷新token
  Future<void> _refreshTokenInBackground() async {
    if (_isRefreshingToken) return;
    _isRefreshingToken = true;

    try {
      final success = await AppBootstrap.refreshTokenIfNeeded();
      if (!success && mounted) {
        // token刷新失败，认证已失效
        _handleAuthenticationFailed();
      }
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// 处理认证失效
  void _handleAuthenticationFailed() {
    if (!mounted) return;

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录已失效，请重新登录'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 延迟跳转，让用户看到提示
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/auth/login');
      }
    });
  }

  /// 切换Tab时处理视频播放状态
  void _onTabChanged(int newIndex) {
    final oldIndex = _index;
    setState(() => _index = newIndex);

    // 从首页Tab切走时暂停所有视频
    if (oldIndex == 0 && newIndex != 0) {
      _preloadManager.pauseAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只有在首页Tab时才允许系统返回手势退出应用
    // 在其他Tab时，返回手势会先切换到首页Tab
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // 如果当前不在首页Tab，切换到首页Tab
        if (_index != 0) {
          _onTabChanged(0);
        }
      },
      child: Scaffold(
        appBar: null,
        body: IndexedStack(
          index: _index,
          children: const [
            DiscoverPage(),
            FollowPage(),
            MessagesPage(),
            ProfilePage(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomAppBar(
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  NavItem(
                    label: '首页',
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    selected: _index == 0,
                    onTap: () => _onTabChanged(0),
                  ),
                  NavItem(
                    label: '关注',
                    icon: Icons.group_outlined,
                    selectedIcon: Icons.group,
                    selected: _index == 1,
                    onTap: () => _onTabChanged(1),
                  ),
                  const PlusInlineButton(),
                  MessagesItem(
                    label: '消息',
                    selected: _index == 2,
                    onTap: () => _onTabChanged(2),
                    unread: 0,
                  ),
                  NavItem(
                    label: '我',
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    selected: _index == 3,
                    onTap: () => _onTabChanged(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
