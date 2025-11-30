import 'package:flutter/material.dart';

import '../video/discover_page.dart';
import '../follow/follow_page.dart';
import '../messages/messages_page.dart';
import '../../widgets/nav_items.dart';
import '../profile/profile_page.dart';

/// 统一主界面：以组件方式管理四个模块，避免重复底部导航
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
          setState(() => _index = 0);
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
                    onTap: () => setState(() => _index = 0),
                  ),
                  NavItem(
                    label: '关注',
                    icon: Icons.group_outlined,
                    selectedIcon: Icons.group,
                    selected: _index == 1,
                    onTap: () => setState(() => _index = 1),
                  ),
                  const PlusInlineButton(),
                  MessagesItem(
                    label: '消息',
                    selected: _index == 2,
                    onTap: () => setState(() => _index = 2),
                    unread: 0,
                  ),
                  NavItem(
                    label: '我',
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    selected: _index == 3,
                    onTap: () => setState(() => _index = 3),
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
