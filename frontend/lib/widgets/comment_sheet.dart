import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zitok/providers/comment_provider.dart';
import 'package:zitok/providers/video_provider.dart';
import '../models/comment.dart';
import '../models/video.dart';
import '../theme/theme_tokens.dart';
import '../services/user_service.dart';
import '../utils/url_utils.dart';
import '../app.dart';
import 'video_stats.dart';
import 'package:go_router/go_router.dart';

enum CommentSort { timeDesc, timeAsc, hot }

/// 评论区底部弹窗
void showCommentsSheet(BuildContext context, {required String videoId}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) {
      // 使用Padding包裹，确保键盘弹出时输入框在键盘上方
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ChangeNotifierProvider.value(
          value: context.read<CommentProvider>(),
          child: _CommentSheetContent(videoId: videoId),
        ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 当可用高度太小时（键盘弹出），只显示评论列表
        final showHeader = constraints.maxHeight > 100;

        return Column(
          children: [
            if (showHeader) ...[
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
            ],
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
                  ElevatedButton(onPressed: _send, child: const Text('发送')),
                ],
              ),
            ),
          ),
        ],
        );
      },
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

  // DraggableScrollableSheet 控制器
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isInputFocused = false;
  double? _savedSheetSize;

  // 作者信息缓存
  String? _authorName;
  String? _authorAvatarUrl;
  bool _fetchingAuthor = false;
  String? _lastFetchedUid;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    // 监听输入框焦点变化
    _focusNode.addListener(_onFocusChanged);

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

  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_isInputFocused) {
      _isInputFocused = true;
      // 保存当前尺寸并展开到最大
      if (_sheetController.isAttached) {
        _savedSheetSize = _sheetController.size;
        _sheetController.animateTo(
          0.95,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } else if (!_focusNode.hasFocus && _isInputFocused) {
      _isInputFocused = false;
      // 恢复到之前的尺寸
      if (_sheetController.isAttached && _savedSheetSize != null) {
        _sheetController.animateTo(
          _savedSheetSize!,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
        _savedSheetSize = null;
      }
    }
  }

  /// 获取视频作者信息
  Future<void> _fetchAuthorInfo(String? uid) async {
    if (_fetchingAuthor || uid == null || uid == _lastFetchedUid) return;
    _fetchingAuthor = true;
    _lastFetchedUid = uid;

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: uid);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final avatarUrl = (userData['avatar'] ?? userData['avatar_url'])?.toString();
        final userName = (userData['username'] ?? userData['nickname'] ?? userData['name'])?.toString();

        if (mounted) {
          setState(() {
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              _authorAvatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
            }
            if (userName != null && userName.isNotEmpty) {
              _authorName = userName;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('_CommentSheetContent: fetch author error: $e');
    } finally {
      _fetchingAuthor = false;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _tab.dispose();
    _text.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    // 清理所有 hooks，防���内存泄漏
    _paneController._startReplyHook = null;
    _paneController._sendHook = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = keyboardHeight > 0;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      controller: _sheetController,
      snap: !_isInputFocused, // 输入时禁用吸附，防止干扰
      snapSizes: const [0.45, 0.7, 0.95],
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
            // 输入区域 - 键盘适配
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(
                left: Spacing.md,
                right: Spacing.md,
                top: Spacing.sm,
                bottom: hasKeyboard ? Spacing.sm : bottomPadding + Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 回复提示条
                  if (_replyingTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: Spacing.xs),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '回复 @${_replyingTo!.author}',
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyingTo = null;
                              });
                            },
                            child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  // 输入框行
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          focusNode: _focusNode,
                          decoration: InputDecoration(
                            hintText: _replyingTo == null ? '写下你的评论...' : '回复 @${_replyingTo!.author}',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                          style: theme.textTheme.bodyMedium,
                          maxLines: hasKeyboard ? 3 : 1,
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      IconButton(
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
                        icon: Icon(Icons.send, color: cs.primary),
                        tooltip: '发送',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ModalBottomSheet会自动处理键盘适配，不需要手动添加占位
          ],
        );
      },
    );
  }

  Widget _videoIntro(ScrollController controller) {
    final vp = context.watch<VideoProvider>();
    // 从各个列表中查找视频
    Video? video = vp.recommend.cast<Video?>().firstWhere(
      (v) => v?.id == widget.videoId,
      orElse: () => null,
    );
    video ??= vp.discover.cast<Video?>().firstWhere(
      (v) => v?.id == widget.videoId,
      orElse: () => null,
    );
    video ??= vp.featured.cast<Video?>().firstWhere(
      (v) => v?.id == widget.videoId,
      orElse: () => null,
    );
    video ??= vp.follow.cast<Video?>().firstWhere(
      (v) => v?.id == widget.videoId,
      orElse: () => null,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (video == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: Spacing.sm),
            Text('视频信息加载中...', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    // 触发作者信息获取
    if (video.uid != null && video.uid != _lastFetchedUid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAuthorInfo(video?.uid);
      });
    }

    // 获取有效的作者名称和头像
    final effectiveAuthorName = _authorName ?? video.authorName ?? video.uid ?? '未知作者';
    final effectiveAvatarUrl = _authorAvatarUrl ??
        (video.authorAvatarUrl != null && video.authorAvatarUrl!.isNotEmpty
            ? UrlUtils.resolveStorageUrl(video.authorAvatarUrl, defaultDir: 'avatars')
            : null);
    final authorInitial = effectiveAuthorName.isNotEmpty ? effectiveAuthorName.substring(0, 1).toUpperCase() : '?';

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者卡片
          GestureDetector(
            onTap: () {
              if (video?.uid != null) {
                context.push('/user/${video!.uid}');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty
                        ? NetworkImage(effectiveAvatarUrl)
                        : null,
                    child: effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty
                        ? Text(
                            authorInitial,
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveAuthorName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.thumb_up_outlined, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              formatCount(video.likes),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(width: Spacing.md),
                            Icon(Icons.chat_bubble_outline, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              formatCount(video.commentCount),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // 视频标题
          Text(
            video.title ?? '未命名视频',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Spacing.md),
          // 视频简介区块
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.primary),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      '视频简介',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  (video.intro?.isNotEmpty == true) ? video.intro! : '作者暂未添加视频简介',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: video.intro?.isNotEmpty == true ? cs.onSurface : cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          // 标签
          if (video.tags.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Icon(Icons.tag, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: Spacing.xs),
                Text(
                  '相关标签',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: video.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '#$tag',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
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

class _CommentTile extends StatefulWidget {
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

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  String? _avatarUrl;
  String? _authorName;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.authorId != widget.item.authorId) {
      _avatarUrl = null;
      _authorName = null;
      _fetchUserInfo();
    }
  }

  Future<void> _fetchUserInfo() async {
    if (_fetching || widget.item.authorId.isEmpty) return;
    _fetching = true;

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.item.authorId);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final avatarUrl = (userData['avatar'] ?? userData['avatar_url'])?.toString();
        final userName = (userData['username'] ?? userData['nickname'] ?? userData['name'])?.toString();

        if (mounted) {
          setState(() {
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              _avatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
            }
            if (userName != null && userName.isNotEmpty) {
              _authorName = userName;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('_CommentTile: fetch user info error: $e');
    } finally {
      _fetching = false;
    }
  }

  String get _effectiveAuthorName => _authorName ?? widget.item.author;
  String? get _effectiveAvatarUrl => _avatarUrl ?? (widget.item.avatar.isNotEmpty ? widget.item.avatar : null);

  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final children = widget.item.replies;
    final visibleChildren = widget.expanded ? children : (children.length > 2 ? children.sublist(0, 2) : children);
    final authorInitial = _effectiveAuthorName.isNotEmpty ? _effectiveAuthorName.substring(0, 1).toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.item.authorId.isNotEmpty) {
                    context.push('/user/${widget.item.authorId}');
                  }
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: _effectiveAvatarUrl != null && _effectiveAvatarUrl!.isNotEmpty
                      ? NetworkImage(_effectiveAvatarUrl!)
                      : null,
                  child: _effectiveAvatarUrl == null || _effectiveAvatarUrl!.isEmpty
                      ? Text(authorInitial, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12))
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_effectiveAuthorName.isNotEmpty ? _effectiveAuthorName : '匿名用户', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(widget.item.content),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_fmt(widget.item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(width: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              widget.onReply?.call(widget.item);
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
                  onPressed: widget.onDelete,
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 8),
              margin: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  ...visibleChildren.map((reply) => _ReplyTile(
                    item: reply,
                    onReply: widget.onReply, // 把 onReply 传下去
                    onDelete: () => widget.onDeleteReply?.call(reply),
                  )),
                  if (children.length > 2)
                    InkWell(
                      onTap: widget.onToggleExpand,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          widget.expanded ? '收起' : '展开 ${children.length - visibleChildren.length} 条回复',
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

// 【关键修改】_ReplyTile 现在有了自己的"回复"按钮和用户信息获取
class _ReplyTile extends StatefulWidget {
  final CommentItem item;
  final ValueSetter<CommentItem>? onReply;
  final VoidCallback? onDelete;

  const _ReplyTile({
    required this.item,
    this.onReply,
    this.onDelete
  });

  @override
  State<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<_ReplyTile> {
  String? _avatarUrl;
  String? _authorName;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  @override
  void didUpdateWidget(covariant _ReplyTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.authorId != widget.item.authorId) {
      _avatarUrl = null;
      _authorName = null;
      _fetchUserInfo();
    }
  }

  Future<void> _fetchUserInfo() async {
    if (_fetching || widget.item.authorId.isEmpty) return;
    _fetching = true;

    try {
      final userService = UserService(AppBootstrap.apiClient.dio);
      final resp = await userService.info(userId: widget.item.authorId);
      final data = resp.data as Map<String, dynamic>? ?? {};

      if (data['code']?.toString() == '10000' && data['data'] != null) {
        final userData = data['data'] as Map<String, dynamic>;
        final avatarUrl = (userData['avatar'] ?? userData['avatar_url'])?.toString();
        final userName = (userData['username'] ?? userData['nickname'] ?? userData['name'])?.toString();

        if (mounted) {
          setState(() {
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              _avatarUrl = UrlUtils.resolveStorageUrl(avatarUrl, defaultDir: 'avatars');
            }
            if (userName != null && userName.isNotEmpty) {
              _authorName = userName;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('_ReplyTile: fetch user info error: $e');
    } finally {
      _fetching = false;
    }
  }

  String get _effectiveAuthorName => _authorName ?? widget.item.author;
  String? get _effectiveAvatarUrl => _avatarUrl ?? (widget.item.avatar.isNotEmpty ? widget.item.avatar : null);

  String _fmt(DateTime t) {
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${t.hour}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parentAuthor = widget.item.parent?.author;
    final authorInitial = _effectiveAuthorName.isNotEmpty ? _effectiveAuthorName.substring(0, 1).toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 回复者头像
          GestureDetector(
            onTap: () {
              if (widget.item.authorId.isNotEmpty) {
                context.push('/user/${widget.item.authorId}');
              }
            },
            child: CircleAvatar(
              radius: 12,
              backgroundColor: cs.primaryContainer,
              backgroundImage: _effectiveAvatarUrl != null && _effectiveAvatarUrl!.isNotEmpty
                  ? NetworkImage(_effectiveAvatarUrl!)
                  : null,
              child: _effectiveAvatarUrl == null || _effectiveAvatarUrl!.isEmpty
                  ? Text(authorInitial, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 10))
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 评论内容部分
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: _effectiveAuthorName.isNotEmpty ? _effectiveAuthorName : '匿名用户',
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
                      TextSpan(text: ': ${widget.item.content}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 操作行
                Row(
                  children: [
                    Text(_fmt(widget.item.time), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(width: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          widget.onReply?.call(widget.item);
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
          // 删除按钮
          SizedBox(
            height: 20,
            width: 20,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: '删除回复',
              iconSize: 14,
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
