import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../theme/theme_tokens.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                      SliverToBoxAdapter(child: _ProfileHeader()),
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
                                  Tab(text: '收藏'),
                                  Tab(text: '笔记'),
                                  Tab(text: '动态'),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SliverFillRemaining(
                        hasScrollBody: true,
                        child: TabBarView(
                          children: [
                            _FavoritesList(),
                            _NotesList(),
                            _ActivitiesList(),
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
                  color: cs.surfaceVariant.withOpacity(0.7),
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
  @override
  Widget build(BuildContext context) {
    final box = Hive.box('user_box');
    final nickname = box.get('nickname', defaultValue: '安东尼没有绿山墙');
    final bio = box.get('bio', defaultValue: '室内设计师，商务合作请联系 emile@234.com');
    final cs = Theme.of(context).colorScheme;
    const double headerHeight = 176; // 贴近图二头部高度
    const double avatarRadius = 36;

    return Semantics(
      label: '个人资料头部',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部平直背景：使用渐变兜底，并在右上角叠加菜单图标
          Stack(
            children: [
              Container(
                height: headerHeight,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2BD2C4), // 图二主色近似：明亮青绿
                      Color(0xFFEFF9F7), // 渐隐到浅色
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: const Color(0xFF2BD2C4),
                          child: Icon(Icons.pets, color: cs.onPrimary, size: 24),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nickname,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '抖音号：46082144372',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 12),
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
                            // Flutter 当前版本的 styleFrom.overlayColor 接受 Color? 类型
                            overlayColor: const Color(0x1F2BD2C4),
                          ),
                          onPressed: () => context.push('/profile/edit'),
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
          // 简介
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bio,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget cell(String num, String label) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(num, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          cell('1', '获赞'),
          cell('7', '互关'),
          cell('24', '关注'),
          cell('7', '粉丝'),
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

class _NotesList extends StatelessWidget {
  const _NotesList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Spacing.md),
      itemBuilder: (context, i) => Card(
        elevation: 0,
        child: ListTile(
          title: Text(i == 0 ? 'Constructive and destructive waves' : '这是一个笔记标题'),
          subtitle: const Text('笔记摘要…'),
          trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => context.go('/profile/edit')),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemCount: 8,
    );
  }
}

class _ActivitiesList extends StatelessWidget {
  const _ActivitiesList();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(Spacing.md),
      itemBuilder: (context, i) => ListTile(
        leading: const Icon(Icons.history),
        title: Text('动态事件 #$i'),
        subtitle: const Text('时间与详情'),
      ),
      itemCount: 12,
    );
  }
}