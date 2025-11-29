import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/messaging_provider.dart';
import '../../models/social_models.dart'; // 确保引入了模型文件以识别 Friend/Conversation
import '../chat/chat_page.dart';
import '../chat/friend_search_page.dart';
import '../chat/global_search_page.dart'; // 全网搜索（添加好友）
import '../chat/create_group_page.dart'; // 【新增】新建群聊页面

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();

    // 1. 准备好友数据 (关注 + 粉丝 并集去重)
    final Map<String, Friend> uniqueContacts = {};
    for (var f in mp.following) {
      uniqueContacts[f.id] = f;
    }
    for (var f in mp.followers) {
      uniqueContacts[f.id] = f;
    }

    // 2. 准备总列表：先放群聊，再放好友
    final List<Conversation> allConversations = [];
    allConversations.addAll(mp.chatRooms);
    allConversations.addAll(uniqueContacts.values);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        centerTitle: true,
        title: const Text('消息'),
        actions: [
          // 🔍 搜索按钮：跳转到【本地搜索】（搜已关注好友/聊天记录）
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage())),
          ),

          // ➕ 添加按钮：弹出菜单
          IconButton(
            tooltip: '添加',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              final screenWidth = MediaQuery.of(context).size.width;
              final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight;

              final selected = await showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(screenWidth, topOffset + 1, 0, 0),
                elevation: 3,
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                items: [
                  // 选项 1: 添加好友
                  const PopupMenuItem<String>(
                    value: 'add_friend',
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_outlined, size: 20, color: Colors.black87),
                        SizedBox(width: 10),
                        Text('添加好友', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  // 选项 2: 新建群聊
                  const PopupMenuItem<String>(
                    value: 'create_group',
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black87),
                        SizedBox(width: 10),
                        Text('新建群聊', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              );

              if (!context.mounted) return;

              // 处理菜单点击跳转
              if (selected == 'add_friend') {
                // 跳转到全网搜索页
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GlobalSearchPage()));
              } else if (selected == 'create_group') {
                // 【新增】跳转到新建群聊页
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupPage()));
              }
            },
          ),
        ],
      ),
      body: allConversations.isEmpty
          ? const Center(child: Text("暂无消息", style: TextStyle(color: Colors.grey)))
          : CustomScrollView(
        slivers: [
          // --- 顶部横向快捷头像栏 (只显示互关好友) ---
          if (mp.mutualFriends.isNotEmpty)
            SliverToBoxAdapter(
              child: _QuickAccessBar(
                friends: mp.mutualFriends,
                onTapFriend: (f) => _toChat(context, f),
              ),
            ),

          // --- 下方消息列表 (显示 群聊 + 所有好友) ---
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final c = allConversations[i];

                final msgs = mp.messagesFor(c.id);
                final lastMsg = msgs.isNotEmpty ? msgs.last : null;
                final previewText = lastMsg != null ? lastMsg.content : '';

                // 处理头像 URL
                final fullAvatarUrl = (c.avatarUrl.isNotEmpty && c.avatarUrl != 'null')
                    ? c.avatarUrl
                    : null;

                final defaultIcon = c.isGroup ? Icons.group : Icons.person;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: fullAvatarUrl != null
                            ? CachedNetworkImageProvider(fullAvatarUrl)
                            : null,
                        child: fullAvatarUrl == null
                            ? Icon(defaultIcon, color: Colors.grey)
                            : null,
                      ),
                      // 仅好友显示在线状态 (群聊不显示)
                      if (!c.isGroup && (c as Friend).online)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                      c.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                  ),
                  subtitle: previewText.isNotEmpty
                      ? Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  )
                      : null,
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                  onTap: () => _toChat(context, c),
                );
              },
              childCount: allConversations.length,
            ),
          ),
        ],
      ),
    );
  }

  void _toChat(BuildContext context, Conversation c) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(
      conversationId: c.id,
      isGroup: c.isGroup,
    )));
  }
}

// --- 顶部横向快捷栏组件 ---
class _QuickAccessBar extends StatelessWidget {
  final List<Friend> friends;
  final void Function(Friend) onTapFriend;

  const _QuickAccessBar({
    required this.friends,
    required this.onTapFriend,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 125,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        itemBuilder: (context, i) {
          final f = friends[i];
          final fullAvatarUrl = (f.avatarUrl.isNotEmpty && f.avatarUrl != 'null')
              ? f.avatarUrl
              : null;

          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => onTapFriend(f),
              borderRadius: BorderRadius.circular(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: fullAvatarUrl != null
                        ? CachedNetworkImageProvider(fullAvatarUrl)
                        : null,
                    child: fullAvatarUrl == null
                        ? const Icon(Icons.person, color: Colors.blueGrey)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
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
