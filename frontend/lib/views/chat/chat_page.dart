import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/url_utils.dart';
import 'friend_search_page.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final bool isGroup; // 这里已经接收了是群还是人的标记

  const ChatPage({
    super.key,
    required this.conversationId,
    this.isGroup = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _emojiShowing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().connectToChat(
          id: widget.conversationId,
          isGroup: widget.isGroup
      );
      _scrollToBottom();
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    final mp = context.read<MessagingProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) return;
      mp.connectGlobal();
    });
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<MessagingProvider>().sendMessage(widget.conversationId, text);
    _controller.clear();
    _scrollToBottom();
  }

  void _toggleEmojiPicker() {
    if (_emojiShowing) {
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }

    setState(() {
      _emojiShowing = !_emojiShowing;
    });
  }

  _onEmojiSelected(Category? category, Emoji emoji) {
    _controller
      ..text += emoji.emoji
      ..selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
  }

  _onBackspacePressed() {
    _controller
      ..text = _controller.text.characters.skipLast(1).toString()
      ..selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MessagingProvider>();


    // 【关键修复】在此处传入 isGroup 参数
    // 强制 Provider 根据 widget.isGroup 决定去查群还是查人
    final conversation = mp.conversationById(
        widget.conversationId,
        isGroup: widget.isGroup
    );

    final messages = mp.messagesFor(widget.conversationId);

    // 调试日志：打印所有消息内容
    developer.log('[ChatPage] 会话${widget.conversationId} 共${messages.length}条消息', name: 'UI');
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      developer.log(
        '[ChatPage] 消息[$i] senderId=${m.senderId}, content="${m.content.substring(0, m.content.length > 100 ? 100 : m.content.length)}"',
        name: 'UI',
      );
    }

    final myId = mp.currentUid?.toString() ?? '';
    final profileProvider = context.watch<ProfileProvider>();
    final myAvatarUrl = profileProvider.user?.avatarUrl;

    return PopScope(
      canPop: !_emojiShowing,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_emojiShowing) {
          setState(() {
            _emojiShowing = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // 现在这里显示的标题就是正确的了
          title: Text(conversation?.name ?? '聊天'),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendSearchPage())),
                icon: const Icon(Icons.search)
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text("暂无消息", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final isMine = (m.senderId.toString() == myId);
                  final date = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
                  final timeText = DateFormat('MM/dd HH:mm').format(date);

                  // 获取发送者名称（群聊时显示不同成员名称，私聊时显示对方名称）
                  String? senderName;
                  String? senderAvatar;
                  if (!isMine) {
                    if (widget.isGroup) {
                      // 群聊：查找发送者信息
                      final sender = mp.friendById(m.senderId.toString());
                      senderName = sender?.name ?? '用户${m.senderId}';
                      senderAvatar = sender?.avatarUrl;
                    } else {
                      // 私聊：使用会话对象的名称
                      senderName = conversation?.name;
                      senderAvatar = conversation?.avatarUrl;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // 显示发送者名称（仅对方消息）
                        if (!isMine && senderName != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 40, bottom: 4),
                            child: Text(
                              senderName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isMine) ...[
                              _buildAvatar(UrlUtils.resolveStorageUrl(senderAvatar, defaultDir: 'avatars')),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: Radius.circular(isMine ? 12 : 2),
                                    bottomRight: Radius.circular(isMine ? 2 : 12),
                                  ),
                                ),
                                child: Text(m.content, style: Theme.of(context).textTheme.bodyMedium),
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 8),
                              _buildAvatar(UrlUtils.resolveStorageUrl(myAvatarUrl, defaultDir: 'avatars')),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 调试：显示原始时间戳和格式化时间
                        Text(
                            '$timeText ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                            )
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            _InputBar(
              controller: _controller,
              focusNode: _focusNode,
              onSend: _send,
              onEmojiToggle: _toggleEmojiPicker,
              isEmojiShowing: _emojiShowing,
            ),

            Offstage(
              offstage: !_emojiShowing,
              child: SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: _onEmojiSelected,
                  onBackspacePressed: _onBackspacePressed,
                  config: Config(
                    height: 250,
                    checkPlatformCompatibility: true,
                    viewOrderConfig: const ViewOrderConfig(),
                    emojiViewConfig: const EmojiViewConfig(
                      columns: 7,
                      emojiSizeMax: 28,
                    ),
                    skinToneConfig: const SkinToneConfig(),
                    categoryViewConfig: const CategoryViewConfig(),
                    bottomActionBarConfig: const BottomActionBarConfig(),
                    searchViewConfig: const SearchViewConfig(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
          imageUrl: url,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => const Icon(Icons.person, size: 18, color: Colors.grey),
        )
            : const Icon(Icons.person, size: 18, color: Colors.grey),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onEmojiToggle;
  final bool isEmojiShowing;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onEmojiToggle,
    required this.isEmojiShowing,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: !isEmojiShowing,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
                onPressed: onEmojiToggle,
                icon: Icon(
                  isEmojiShowing ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: isEmojiShowing ? Theme.of(context).primaryColor : Colors.grey[600],
                )
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
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
