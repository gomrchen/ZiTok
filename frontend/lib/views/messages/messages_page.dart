import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/messaging_provider.dart';
import '../../models/social_models.dart'; // 确保引入了模型文件以识别 Friend/Conversation
import '../../services/user_session.dart';
import '../chat/chat_page.dart';
import '../chat/friend_search_page.dart';
import '../chat/global_search_page.dart'; // 全网搜索（添加好友）
import '../chat/create_group_page.dart'; // 【新增】新建群聊页面

/// 消息列表筛选类型
enum MessageFilter {
  all,       // 全部（群聊 + 所有好友）
  following, // 我关注的
  mutual,    // 互关好友
  followers, // 粉丝
  groups,    // 群聊
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _isLoading = false;
  String? _error;
  MessageFilter _currentFilter = MessageFilter.all;

  @override
  void initState() {
    super.initState();
    // 初始化时加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final userSession = context.read<UserSession>();
    final mp = context.read<MessagingProvider>();

    if (!userSession.isLoggedIn) {
      setState(() {
        _error = '请先登录';
        _isLoading = false;
      });
      return;
    }

    final uid = int.tryParse(userSession.userId!);
    if (uid == null) {
      setState(() {
        _error = '用户ID无效';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await mp.loadRelationData(uid: uid);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();

    // 根据筛选器获取对应的会话列表
    final List<Conversation> filteredConversations = _getFilteredConversations(mp);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: '筛选',
          onPressed: () => _showFilterMenu(context, mp),
        ),
        centerTitle: true,
        title: Text(_getFilterTitle()),
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
            onPressed: () => _showAddMenu(context),
          ),
        ],
      ),
      body: _buildBody(mp, filteredConversations),
    );
  }

  /// 获取筛选标题
  String _getFilterTitle() {
    switch (_currentFilter) {
      case MessageFilter.all:
        return '消息';
      case MessageFilter.following:
        return '我关注的';
      case MessageFilter.mutual:
        return '互关好友';
      case MessageFilter.followers:
        return '我的粉丝';
      case MessageFilter.groups:
        return '群聊';
    }
  }

  /// 根据筛选器获取会话列表
  List<Conversation> _getFilteredConversations(MessagingProvider mp) {
    switch (_currentFilter) {
      case MessageFilter.all:
        // 全部：群聊 + 所有好友（关注+粉丝去重）
        final Map<String, Friend> uniqueContacts = {};
        for (var f in mp.following) {
          uniqueContacts[f.id] = f;
        }
        for (var f in mp.followers) {
          uniqueContacts[f.id] = f;
        }
        final List<Conversation> all = [];
        all.addAll(mp.chatRooms);
        all.addAll(uniqueContacts.values);
        return all;

      case MessageFilter.following:
        // 我关注的
        return mp.following.cast<Conversation>();

      case MessageFilter.mutual:
        // 互关好友
        return mp.mutualFriends.cast<Conversation>();

      case MessageFilter.followers:
        // 粉丝
        return mp.followers.cast<Conversation>();

      case MessageFilter.groups:
        // 群聊
        return mp.chatRooms.cast<Conversation>();
    }
  }

  /// 显示筛选菜单
  void _showFilterMenu(BuildContext context, MessagingProvider mp) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '筛选消息',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Divider(),
                _buildFilterOption(
                  context: ctx,
                  filter: MessageFilter.all,
                  icon: Icons.all_inbox,
                  title: '全部消息',
                  subtitle: '显示所有联系人和群聊',
                  count: mp.following.length + mp.followers.length + mp.chatRooms.length,
                ),
                _buildFilterOption(
                  context: ctx,
                  filter: MessageFilter.mutual,
                  icon: Icons.people,
                  title: '互关好友',
                  subtitle: '双向关注的好友',
                  count: mp.mutualFriends.length,
                ),
                _buildFilterOption(
                  context: ctx,
                  filter: MessageFilter.following,
                  icon: Icons.person_add,
                  title: '我关注的',
                  subtitle: '我关注的用户',
                  count: mp.following.length,
                ),
                _buildFilterOption(
                  context: ctx,
                  filter: MessageFilter.followers,
                  icon: Icons.person,
                  title: '我的粉丝',
                  subtitle: '关注我的用户',
                  count: mp.followers.length,
                ),
                _buildFilterOption(
                  context: ctx,
                  filter: MessageFilter.groups,
                  icon: Icons.group,
                  title: '群聊',
                  subtitle: '我加入的群组',
                  count: mp.chatRooms.length,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建筛选选项
  Widget _buildFilterOption({
    required BuildContext context,
    required MessageFilter filter,
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _currentFilter == filter;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check, color: cs.primary, size: 20),
          ],
        ],
      ),
      onTap: () {
        setState(() {
          _currentFilter = filter;
        });
        Navigator.pop(context);
      },
    );
  }

  /// 显示添加菜单
  void _showAddMenu(BuildContext context) async {
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
  }

  Widget _buildBody(MessagingProvider mp, List<Conversation> filteredConversations) {
    // 显示加载状态
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 显示错误状态
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 显示空状态
    if (filteredConversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: [
            const SizedBox(height: 200),
            Center(child: Text(_getEmptyMessage(), style: const TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    // 显示消息列表
    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // --- 顶部横向快捷头像栏 (仅在全部或互关好友筛选时显示互关好友) ---
          if ((_currentFilter == MessageFilter.all || _currentFilter == MessageFilter.mutual) &&
              mp.mutualFriends.isNotEmpty)
            SliverToBoxAdapter(
              child: _QuickAccessBar(
                friends: mp.mutualFriends,
                onTapFriend: (f) => _toChat(context, f),
              ),
            ),

          // --- 下方消息列表 ---
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final c = filteredConversations[i];

                final msgs = mp.messagesFor(c.id);
                final lastMsg = msgs.isNotEmpty ? msgs.last : null;
                final previewText = lastMsg != null ? lastMsg.content : '';

                // 处理头像 URL
                final fullAvatarUrl = (c.avatarUrl.isNotEmpty && c.avatarUrl != 'null')
                    ? c.avatarUrl
                    : null;

                final defaultIcon = c.isGroup ? Icons.group : Icons.person;

                // 根据当前筛选类型添加标签提示
                String? tagText;
                if (_currentFilter == MessageFilter.all && !c.isGroup) {
                  final friend = c as Friend;
                  final isFollowing = mp.following.any((f) => f.id == friend.id);
                  final isFollower = mp.followers.any((f) => f.id == friend.id);
                  if (isFollowing && isFollower) {
                    tagText = '互关';
                  } else if (isFollowing) {
                    tagText = '已关注';
                  } else if (isFollower) {
                    tagText = '粉丝';
                  }
                }

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
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                            c.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                        ),
                      ),
                      if (tagText != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tagText,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
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
              childCount: filteredConversations.length,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取空状态提示消息
  String _getEmptyMessage() {
    switch (_currentFilter) {
      case MessageFilter.all:
        return '暂无消息';
      case MessageFilter.following:
        return '您还没有关注任何人';
      case MessageFilter.mutual:
        return '暂无互关好友';
      case MessageFilter.followers:
        return '暂无粉丝';
      case MessageFilter.groups:
        return '暂无群聊';
    }
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
