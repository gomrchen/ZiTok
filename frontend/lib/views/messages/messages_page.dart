import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/messaging_provider.dart';
import '../chat/chat_page.dart';

/// 消息页（独立路由）：包含顶部栏与列表内容
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        centerTitle: true,
        title: const Text('消息'),
        actions: [
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage())),
          ),
          IconButton(
            tooltip: '添加',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              final selected = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(
                  MediaQuery.of(context).size.width - 200,
                  kToolbarHeight + MediaQuery.of(context).padding.top,
                  8,
                  0,
                ),
                items: const [
                  PopupMenuItem<String>(
                    value: 'add',
                    child: ListTile(leading: Icon(Icons.person_add_outlined), title: Text('添加好友')),
                  ),
                ],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
              if (selected == 'add') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage()));
              }
            },
          ),
        ],
      ),
      body: const MessagesBody(),
    );
  }
}

/// 顶部快速访问头像条（公开以供 Shell 复用）
class QuickAccessBar extends StatelessWidget {
  final List<Friend> friends;
  final void Function(Friend) onTapFriend;
  const QuickAccessBar({super.key, required this.friends, required this.onTapFriend});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        cacheExtent: 400,
        itemBuilder: (context, i) {
          final f = friends[i];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => onTapFriend(f),
              borderRadius: BorderRadius.circular(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: f.avatarUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (ctx, _) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          errorWidget: (ctx, _, __) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: friends[i].online ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 56,
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 仅包含消息列表内容的主体，供 HomeShell 与独立路由复用
class MessagesBody extends StatelessWidget {
  const MessagesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: QuickAccessBar(
            friends: mp.friends,
            onTapFriend: (f) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(conversationId: f.id))),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final f = mp.friends[i % mp.friends.length];
              return ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(f.avatarUrl)),
                title: Text(f.name),
                subtitle: const Text('最后一条消息预览'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(conversationId: f.id))),
              );
            },
            childCount: mp.friends.length,
          ),
        ),
      ],
    );
  }
}