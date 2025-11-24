import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/messaging_provider.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  const ChatPage({super.key, required this.conversationId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<MessagingProvider>().sendMessage(widget.conversationId, text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showAddFriendMenu(BuildContext context) async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 8, 0),
      items: const [
        PopupMenuItem<String>(value: 'add_friend', child: ListTile(leading: Icon(Icons.person_add_outlined), title: Text('添加好友'))),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    if (selected == 'add_friend' && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();
    final friend = mp.friendById(widget.conversationId);
    final messages = mp.messagesFor(widget.conversationId);
    return Scaffold(
      appBar: AppBar(
        title: Text(friend?.name ?? '聊天'),
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage())), icon: const Icon(Icons.search)),
          IconButton(onPressed: () => _showAddFriendMenu(context), icon: const Icon(Icons.add)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final isMine = m.senderId == 'me';
                final timeText = DateFormat('MM/dd HH:mm').format(m.timestamp);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMine)
                            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isMine ? 12 : 2),
                                  bottomRight: Radius.circular(isMine ? 2 : 12),
                                ),
                              ),
                              child: Text(m.text, style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isMine)
                            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(timeText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6))),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.photo_camera_outlined)),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '发送消息...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});
  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();
    final results = mp.searchFriends(_search.text);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _search,
          autofocus: true,
          decoration: const InputDecoration(hintText: '搜索联系人、群聊或聊天记录', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消'))],
      ),
      body: ListView.separated(
        itemBuilder: (_, i) {
          final f = results[i];
          return ListTile(
            leading: CircleAvatar(
              radius: 20,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: f.avatarUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorWidget: (ctx, _, __) => const Icon(Icons.person),
                ),
              ),
            ),
            title: Text(f.name),
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(conversationId: f.id)));
              },
              child: const Text('发私信'),
            ),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: results.length,
      ),
    );
  }
}