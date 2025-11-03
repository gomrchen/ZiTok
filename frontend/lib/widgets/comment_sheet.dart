import 'package:flutter/material.dart';
import '../theme/theme_tokens.dart';

enum CommentSort { timeDesc, timeAsc, hot }

class _CommentItem {
  final String id;
  final String author;
  final String content;
  final DateTime time;
  int likes;
  final List<_CommentItem> replies;
  _CommentItem({required this.id, required this.author, required this.content, required this.time, this.likes = 0, this.replies = const []});
}

List<_CommentItem> _mockComments() {
  final now = DateTime.now();
  return List.generate(8, (i) {
    final replies = List.generate(i % 4, (j) => _CommentItem(
          id: 'r${i}_$j',
          author: '用户$j',
          content: '子回复内容 示例 #$j，父评论 $i',
          time: now.subtract(Duration(minutes: (i * 5 + j))),
          likes: (i + j) * 2,
        ));
    return _CommentItem(
      id: 'p$i',
      author: '用户$i',
      content: '这是父评论内容 示例 #$i，包含一些文字说明。',
      time: now.subtract(Duration(minutes: i * 7)),
      likes: i * 3 + 1,
      replies: replies,
    );
  });
}

/// 评论区底部弹窗（双栏 + 标签切换 + 父子评论/折叠/排序/点赞 + 输入区）
void showCommentsSheet(BuildContext context, {required String videoId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      return _CommentSheetContent(videoId: videoId);
    },
  );
}

/// 控制器：用于跨组件通信（例如在弹窗底部输入区点击“发送”时，通知列表组件追加评论）。
class CommentsPaneController {
  void Function(String text)? _sendHook;
  void send(String text) => _sendHook?.call(text);
}

/// 可复用评论列表组件：排序、父子评论折叠、点赞，支持可选底部输入区。
class CommentsPane extends StatefulWidget {
  final String videoId;
  final bool showInput;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final CommentSort initialSort;
  final ValueChanged<String>? onSend;
  final CommentsPaneController? controller;

  const CommentsPane({
    super.key,
    required this.videoId,
    this.showInput = true,
    this.padding,
    this.scrollController,
    this.initialSort = CommentSort.timeDesc,
    this.onSend,
    this.controller,
  });

  @override
  State<CommentsPane> createState() => _CommentsPaneState();
}

class _CommentsPaneState extends State<CommentsPane> with AutomaticKeepAliveClientMixin {
  late final ValueNotifier<CommentSort> _sort;
  late final List<_CommentItem> _comments;
  final Set<String> _expanded = <String>{};
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sort = ValueNotifier<CommentSort>(widget.initialSort);
    _comments = _mockComments();
    // 绑定控制器，外部可通过 controller.send(text) 追加评论
    widget.controller?._sendHook = _receiveExternalSend;
  }

  @override
  void dispose() {
    widget.controller?._sendHook = null;
    _sort.dispose();
    _text.dispose();
    super.dispose();
  }

  List<_CommentItem> _sorted(List<_CommentItem> list, CommentSort s) {
    final out = List<_CommentItem>.from(list);
    switch (s) {
      case CommentSort.timeDesc:
        out.sort((a, b) => b.time.compareTo(a.time));
        break;
      case CommentSort.timeAsc:
        out.sort((a, b) => a.time.compareTo(b.time));
        break;
      case CommentSort.hot:
        out.sort((a, b) => (b.likes + (b.replies.length * 2)).compareTo(a.likes + (a.replies.length * 2)));
        break;
    }
    return out;
  }

  void _receiveExternalSend(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _comments.insert(0, _CommentItem(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        author: '我',
        content: t,
        time: DateTime.now(),
        likes: 0,
      ));
    });
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    widget.onSend?.call(t);
    _receiveExternalSend(t);
    _text.clear();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pad = widget.padding ?? const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm);
    final controller = widget.scrollController ?? ScrollController();
    return Column(
      children: [
        // 排序菜单与总数
        ValueListenableBuilder<CommentSort>(
          valueListenable: _sort,
          builder: (context, sort, _) {
            final list = _sorted(_comments, sort);
            return Padding(
              padding: pad,
              child: Row(
                children: [
                  Text('评论（${list.length}）'),
                  const Spacer(),
                  PopupMenuButton<CommentSort>(
                    tooltip: '排序',
                    initialValue: sort,
                    onSelected: (v) => _sort.value = v,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: CommentSort.timeDesc, child: Text('按时间（新→旧）')),
                      PopupMenuItem(value: CommentSort.timeAsc, child: Text('按时间（旧→新）')),
                      PopupMenuItem(value: CommentSort.hot, child: Text('按热度')),
                    ],
                    child: const Icon(Icons.sort),
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1),
        // 列表
        Expanded(
          child: ValueListenableBuilder<CommentSort>(
            valueListenable: _sort,
            builder: (context, sort, _) {
              final list = _sorted(_comments, sort);
              return ListView.builder(
                controller: controller,
                key: PageStorageKey('comments_${widget.videoId}'),
                itemCount: list.length,
                itemBuilder: (_, i) => _CommentTile(
                  item: list[i],
                  expanded: _expanded.contains(list[i].id),
                  onToggleExpand: () {
                    setState(() {
                      if (_expanded.contains(list[i].id)) {
                        _expanded.remove(list[i].id);
                      } else {
                        _expanded.add(list[i].id);
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
        // 可选底部输入区
        if (widget.showInput)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(
                        hintText: '写下你的评论...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  PopupMenuButton<String>(
                    tooltip: 'Emoji',
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: '😊', child: Text('😊')),
                      PopupMenuItem(value: '👍', child: Text('👍')),
                      PopupMenuItem(value: '🎯', child: Text('🎯')),
                      PopupMenuItem(value: '❤️', child: Text('❤️')),
                      PopupMenuItem(value: '🚀', child: Text('🚀')),
                    ],
                    onSelected: (e) => _text.text = (_text.text + e),
                    child: const Icon(Icons.emoji_emotions_outlined),
                  ),
                  const SizedBox(width: Spacing.md),
                  ElevatedButton(onPressed: _send, child: const Text('发送')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentSheetContent extends StatefulWidget {
  final String videoId;
  const _CommentSheetContent({required this.videoId});
  @override
  State<_CommentSheetContent> createState() => _CommentSheetContentState();
}

class _CommentSheetContentState extends State<_CommentSheetContent> with TickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _text = TextEditingController();
  final CommentsPaneController _paneController = CommentsPaneController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            // 顶部标题 + 关闭
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
              child: Row(
                children: [
                  Text('互动 · 视频#${widget.videoId}', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(tooltip: '关闭', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            // 标签栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: TabBar(
                controller: _tab,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                tabs: const [Tab(text: '视频简介'), Tab(text: '评论区')],
              ),
            ),
            const Divider(height: 1),
            // 内容：响应式布局。如果宽屏，显示双栏；否则使用 TabBarView 滑动切换。
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, box) {
                  final isWide = box.maxWidth >= 720;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: _videoIntro(controller)),
                        const VerticalDivider(width: 1),
                        Expanded(child: _commentsPane(controller)),
                      ],
                    );
                  }
                  return TabBarView(
                    controller: _tab,
                    children: [
                      _videoIntro(controller),
                      _commentsPane(controller),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // 底部输入区（固定）
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        decoration: const InputDecoration(
                          hintText: '写下你的评论...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    // 简易 emoji 选择
                    PopupMenuButton<String>(
                      tooltip: 'Emoji',
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: '😊', child: Text('😊')),
                        PopupMenuItem(value: '👍', child: Text('👍')),
                        PopupMenuItem(value: '🎯', child: Text('🎯')),
                        PopupMenuItem(value: '❤️', child: Text('❤️')),
                        PopupMenuItem(value: '🚀', child: Text('🚀')),
                      ],
                      onSelected: (e) => _text.text = (_text.text + e),
                      child: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    const SizedBox(width: Spacing.md),
                    ElevatedButton(
                      onPressed: () {
                        final t = _text.text.trim();
                        if (t.isEmpty) return;
                        _paneController.send(t); // 通过控制器通知列表组件
                        _text.clear();
                      },
                      child: const Text('发送'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 左侧：视频简介
  Widget _videoIntro(ScrollController controller) {
    final theme = Theme.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        Text('视频标题示例', style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.sm),
        Text('这是一个视频的简要介绍。包含标签、作者、发布时间等信息。', style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.md),
        Wrap(spacing: 8, runSpacing: 8, children: const [
          Chip(label: Text('#知识')), Chip(label: Text('#学习')), Chip(label: Text('#技能')),
        ]),
      ],
    );
  }

  // 右侧：评论区
  Widget _commentsPane(ScrollController controller) {
    return CommentsPane(
      videoId: widget.videoId,
      scrollController: controller,
      showInput: false,
      controller: _paneController,
    );
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentItem item;
  final bool expanded;
  final VoidCallback onToggleExpand;
  const _CommentTile({required this.item, required this.expanded, required this.onToggleExpand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = item.replies;
    final showButton = children.length > 2;
    final visibleChildren = expanded ? children : children.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 16, child: Text(item.author.substring(0, 1))),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.author, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(_fmt(item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.content),
                  ],
                ),
              ),
              // 点赞按钮（带计数）
              _LikeButton(initial: item.likes),
            ],
          ),
          const SizedBox(height: 8),
          // 子评论区块，视觉缩进与分割线
          if (children.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 40),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Column(
                        children: [
                          for (final r in visibleChildren) _ReplyTile(item: r),
                        ],
                      ),
                    ),
                    if (showButton)
                      TextButton(
                        onPressed: onToggleExpand,
                        child: Text(expanded ? '收起回复' : '展开更多回复(${children.length - 2})'),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }
}

class _ReplyTile extends StatelessWidget {
  final _CommentItem item;
  const _ReplyTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 6),
          CircleAvatar(radius: 12, child: Text(item.author.substring(0, 1))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.author, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text(item.content),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_fmt(item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }
}

class _LikeButton extends StatefulWidget {
  final int initial;
  const _LikeButton({required this.initial});
  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late int count;
  bool liked = false;
  @override
  void initState() {
    super.initState();
    count = widget.initial;
  }
  void _toggle() {
    setState(() {
      liked = !liked;
      count += liked ? 1 : -1;
    });
  }
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(20),
      hoverColor: Colors.red.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : Colors.grey),
            Text('$count', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}