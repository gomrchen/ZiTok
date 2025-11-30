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
    return Scaffold(
      // 按需移除关注与消息顶部标题栏，Shell 不再提供 AppBar
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
      // 中间“+”进入创作界面，底部栏四项：首页 / 朋友 / 消息 / 我
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
                unread: 0, // 不显示未读提示
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
      // 中间“＋”作为内嵌按钮，不再使用突起的 FAB
    );
  }
}

