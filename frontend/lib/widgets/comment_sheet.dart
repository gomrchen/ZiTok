import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zitok/providers/comment_provider.dart';
import '../models/comment.dart';
import '../theme/theme_tokens.dart';

enum CommentSort { timeDesc, timeAsc, hot }

/// 评论区底部弹窗
void showCommentsSheet(BuildContext context, {required String videoId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      //【推荐修改】当Provider已在上层提供时，使用 .value 构造函数是最佳实践
      return ChangeNotifierProvider.value(
        value: context.read<CommentProvider>(),
        child: _CommentSheetContent(videoId: videoId),
      );
    },
  );
}

/// 控制器：用于跨组件通信
class CommentsPaneController {
  void Function(String text, String? parentId)? _sendHook;
  void Function(CommentItem comment)? _startReplyHook;

  void send(String text, {String? parentId}) => _sendHook?.call(text, parentId);
  void startReply(CommentItem comment) => _startReplyHook?.call(comment);
}

/// 可复用评论列表组件
class CommentsPane extends StatefulWidget {
  final String videoId;
  final bool showInput;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final CommentSort initialSort;
  final ValueChanged<String>? onSend;
  final CommentsPaneController? controller;
  final ValueSetter<CommentItem>? onReply;

  const CommentsPane({
    super.key,
    required this.videoId,
    this.showInput = true,
    this.padding,
    this.scrollController,
    this.initialSort = CommentSort.timeDesc,
    this.onSend,
    this.controller,
    this.onReply,
  });

  @override
  State<CommentsPane> createState() => _CommentsPaneState();
}

class _CommentsPaneState extends State<CommentsPane> with AutomaticKeepAliveClientMixin {
  late final ValueNotifier<CommentSort> _sort;
  late List<CommentItem> _comments;
  final Set<String> _expanded = <String>{};
  final TextEditingController _text = TextEditingController();
  late CommentProvider commentProvider; // 在initState或build中初始化

  // 内部回复状态（当 showInput 为 true 时使用）
  CommentItem? _replyingTo;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _sort = ValueNotifier<CommentSort>(widget.initialSort);
    // 使用 WidgetsBinding 确保 Provider 在 build 之后被安全访问
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<CommentProvider>(context, listen: false).fetchComments(widget.videoId);
      }
    });

    // 只有当 showInput 为 true 时，才在内部设置 _sendHook
    // 当 showInput 为 false 时，由外部（如 _CommentSheetContentState）设置 hook
    if (widget.showInput) {
      widget.controller?._sendHook = _receiveExternalSend;
    }
  }

  @override
  void dispose() {
    // 只有当 showInput 为 true 时，才清理 _sendHook（因为只有这时是内部设置的）
    if (widget.showInput) {
      widget.controller?._sendHook = null;
    }
    _sort.dispose();
    _text.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommentItem> _sorted(List<CommentItem> list, CommentSort s) {
    final out = List<CommentItem>.from(list);
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

  void _receiveExternalSend(String text, String? parentId) {
    final t = text.trim();
    if (t.isEmpty) return;
    if (mounted) {
      context.read<CommentProvider>().addComment(
        videoId: widget.videoId,
        content: t,
        parentId: parentId,
      );
    }
  }

  /// 内部回复处理（当 showInput 为 true 时使用）
  void _handleInternalReply(CommentItem comment) {
    setState(() {
      _replyingTo = comment;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    widget.onSend?.call(t);
    _receiveExternalSend(t, _replyingTo?.id);
    _text.clear();
    // 清除回复状态
    if (_replyingTo != null) {
      setState(() {
        _replyingTo = null;
      });
    }
  }

  /// 【新增】处理删除逻辑的方法
  void _handleDelete(CommentItem commentToDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条评论及其所有回复吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 调用 provider 中已经完成的方法
              context.read<CommentProvider>().deleteCommentAndChildren(
                videoId: widget.videoId,
                commentToDelete: commentToDelete,
              );
              Navigator.of(ctx).pop();
            },
            child: Text('确认', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // 在 build 方法中，使用 watch 来确保数据更新时UI能重建
    commentProvider = context.watch<CommentProvider>();
    _comments = commentProvider.commentsMap[widget.videoId] ?? [];

    super.build(context);
    final pad = widget.padding ?? const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm);
    final controller = widget.scrollController ?? ScrollController();
    return Column(
      children: [
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
        Expanded(
          child: ValueListenableBuilder<CommentSort>(
            valueListenable: _sort,
            builder: (context, sort, _) {
              final list = _sorted(_comments, sort);
              return ListView.builder(
                controller: controller,
                key: PageStorageKey('comments_${widget.videoId}'),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final commentItem = list[i];
                  return _CommentTile(
                    item: commentItem,
                    expanded: _expanded.contains(commentItem.id),
                    onToggleExpand: () {
                      setState(() {
                        if (_expanded.contains(commentItem.id)) {
                          _expanded.remove(commentItem.id);
                        } else {
                          _expanded.add(commentItem.id);
                        }
                      });
                    },
                    // 当 showInput 为 true 时使用内部回复处理，否则使用外部回调
                    onReply: widget.showInput ? _handleInternalReply : widget.onReply,
                    onDelete: () => _handleDelete(commentItem),
                    onDeleteReply: (replyItem) => _handleDelete(replyItem),
                  );
                },
              );
            },
          ),
        ),
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
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: _replyingTo == null
                            ? '写下你的评论...'
                            : '回复 @${_replyingTo!.author}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        // 显示取消回复按钮
                        suffixIcon: _replyingTo != null
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _replyingTo = null;
                                  });
                                },
                              )
                            : null,
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

  CommentItem? _replyingTo;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    // 设置回复 hook：当子组件触发回复时，更新 _replyingTo 状态
    _paneController._startReplyHook = (commentToReply) {
      setState(() {
        _replyingTo = commentToReply;
      });
      _focusNode.requestFocus();
    };

    // 【关键修复】设置发送 hook：当调用 _paneController.send() 时，实际执行发送逻辑
    _paneController._sendHook = (text, parentId) {
      if (text.trim().isEmpty) return;
      if (mounted) {
        context.read<CommentProvider>().addComment(
          videoId: widget.videoId,
          content: text.trim(),
          parentId: parentId,
        );
      }
    };
  }

  @override
  void dispose() {
    _tab.dispose();
    _text.dispose();
    _focusNode.dispose();
    // 清理所有 hooks，防止内存泄漏
    _paneController._startReplyHook = null;
    _paneController._sendHook = null;
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: _replyingTo == null ? '写下你的评论...' : '回复 @${_replyingTo!.author}',
                          border: const OutlineInputBorder(),
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
                    ElevatedButton(
                      onPressed: () {
                        final t = _text.text.trim();
                        if (t.isEmpty) return;
                        _paneController.send(t, parentId: _replyingTo?.id);
                        _text.clear();
                        _focusNode.unfocus();
                        setState(() {
                          _replyingTo = null;
                        });
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

  Widget _videoIntro(ScrollController controller) {
    return Container(alignment: Alignment.center, child: const Text('视频简介区'));
  }

  Widget _commentsPane(ScrollController controller) {
    return CommentsPane(
      key: const ValueKey('comments'),
      videoId: widget.videoId,
      showInput: false,
      scrollController: controller,
      controller: _paneController,
      onReply: (commentToReply) {
        setState(() {
          _replyingTo = commentToReply;
        });
        // 使用 addPostFrameCallback 确保在 UI 更新后再请求焦点
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusNode.canRequestFocus) {
            _focusNode.requestFocus();
          }
        });
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem item;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final ValueSetter<CommentItem>? onReply;
  final VoidCallback? onDelete;
  final ValueSetter<CommentItem>? onDeleteReply;

  const _CommentTile({
    required this.item,
    required this.expanded,
    required this.onToggleExpand,
    this.onReply,
    this.onDelete,
    this.onDeleteReply,
  });

  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = item.replies;
    final visibleChildren = expanded ? children : (children.length > 2 ? children.sublist(0, 2) : children);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 16, child: Text(item.author.isNotEmpty ? item.author.substring(0, 1) : '?')),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.author.isNotEmpty ? item.author : '匿名用户', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(item.content),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_fmt(item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(width: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              onReply?.call(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400, width: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '回复',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 24,
                width: 24,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tooltip: '删除评论',
                  iconSize: 16,
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 8),
              margin: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  ...visibleChildren.map((reply) => _ReplyTile(
                    item: reply,
                    onReply: onReply, // 把 onReply 传下去
                    onDelete: () => onDeleteReply?.call(reply),
                  )),
                  if (children.length > 2)
                    InkWell(
                      onTap: onToggleExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          expanded ? '收起' : '展开 ${children.length - visibleChildren.length} 条回复',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.blue),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

// 【关键修改】_ReplyTile 现在有了自己的“回复”按钮
class _ReplyTile extends StatelessWidget {
  final CommentItem item;
  final ValueSetter<CommentItem>? onReply;
  final VoidCallback? onDelete;

  const _ReplyTile({
    required this.item,
    this.onReply,
    this.onDelete
  });

  // 新增一个和父评论一样的 _fmt 方法
  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parentAuthor = item.parent?.author;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // 使用Column来组织内容和操作行
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 评论内容部分
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium, // 默认文字样式
                    children: [
                      TextSpan(
                        text: item.author.isNotEmpty ? item.author : '匿名用户',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (parentAuthor != null && parentAuthor.isNotEmpty) ...[
                        TextSpan(
                          text: ' 回复 ',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                        ),
                        TextSpan(
                          text: '@$parentAuthor',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                      TextSpan(text: ': ${item.content}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 新增的操作行，和父评论的样式一致
                Row(
                  children: [
                    Text(_fmt(item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(width: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          onReply?.call(item);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, width: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '回复',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 删除按钮保持不变
          SizedBox(
            height: 20,
            width: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: '删除回复',
              iconSize: 14,
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
