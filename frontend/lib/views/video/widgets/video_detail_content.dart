import 'package:flutter/material.dart';
import '../../../models/video.dart';
import '../../../providers/video_provider.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_tokens.dart';
import '../../../widgets/comment_sheet.dart' show CommentsPane; // 复用评论组件
import '../../../repositories/notes_repository.dart';
import '../../../services/notes_service.dart';
import '../../../app.dart';
import '../../../models/notes_models.dart';

/// 下半部分内容容器：评论 / 简介 / 笔记
class VideoDetailContent extends StatefulWidget {
  final Video video;
  const VideoDetailContent({super.key, required this.video});

  @override
  State<VideoDetailContent> createState() => _VideoDetailContentState();
}

class _VideoDetailContentState extends State<VideoDetailContent> with TickerProviderStateMixin {
  late final TabController _tab;
  bool _commentsMounted = false; // 评论区按需渲染
  Future<NoteListResp>? _notesFuture; // 笔记异步加载保持一次

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // 当切到“评论”标签时再挂载评论内容，提升初始渲染性能
    _tab.addListener(() {
      if (!_tab.indexIsChanging && _tab.index == 1 && !_commentsMounted) {
        setState(() => _commentsMounted = true);
      }
    });
    // 笔记异步加载（独立 Future，不影响其他区域）
    _notesFuture = _fetchNotes(widget.video.id);
  }

  Future<NoteListResp> _fetchNotes(String vid) async {
    try {
      final repo = NotesRepository(api: NotesService(AppBootstrap.apiClient.dio));
      return await repo.list(vid);
    } catch (_) {
      return const NoteListResp(count: 0, items: []);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 标签栏：Material 风格，当前选中有下划线指示器
        Material(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tab,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.textTheme.bodyMedium?.color,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: '简介'),
              Tab(text: '评论'),
              Tab(text: '笔记'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            // 支持左右滑动切换，默认就带平滑动画
            children: [
              // 简介
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: _IntroSection(video: widget.video),
              ),
              // 评论：复用组件，避免不必要的重新渲染与重复逻辑
              // 按需挂载以优化首屏性能
              _commentsMounted
                  ? CommentsPane(
                      videoId: widget.video.id,
                      showInput: true,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    )
                  : const _CommentsSkeleton(),
              // 笔记
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: FutureBuilder<NoteListResp>(
                  future: _notesFuture,
                  builder: (context, snap) {
                    final loaded = snap.connectionState == ConnectionState.done && snap.hasData;
                    final items = loaded ? snap.data!.items : const <NoteItem>[];
                    final attach = items.where((e) => e.seconds > 0).toList();
                    final user = items.where((e) => e.seconds <= 0).toList();
                    if (!loaded) return const _NotesSkeleton();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('关联笔记', style: theme.textTheme.titleSmall),
                        const SizedBox(height: Spacing.sm),
                        _NotesBlock(title: '视频附件笔记', items: attach, accent: Colors.blueAccent),
                        const SizedBox(height: Spacing.md),
                        _UserNotesBlock(videoId: widget.video.id, items: user),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntroSection extends StatelessWidget {
  final Video video;
  const _IntroSection({required this.video});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(video.title ?? '未知视频', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Row(children: [
          // 点赞数和评论数
          Icon(Icons.favorite_border, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text('${video.likes ?? 0}', style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text('${video.commentCount ?? 0}', style: theme.textTheme.bodySmall),
          const Spacer(),
          // 点赞按钮
          IconButton(
            onPressed: () => context.read<VideoProvider>().like(video.id),
            icon: const Icon(Icons.favorite_border),
            tooltip: '点赞',
          ),
          // 收藏按钮
          _FavoriteButton(videoId: video.id),
        ]),
        const SizedBox(height: Spacing.sm),
        if ((video.intro ?? '').isNotEmpty)
          Text(video.intro!, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.sm),
        if (video.tags.isNotEmpty)
          Wrap(spacing: 8, children: video.tags.map((t) => Chip(label: Text(t))).toList()),
      ],
    );
  }
}

/// 收藏按钮组件
class _FavoriteButton extends StatefulWidget {
  final String videoId;

  const _FavoriteButton({required this.videoId});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _loading = false;

  Future<void> _toggleFavorite() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final success = await context.read<VideoProvider>().toggleFavorite(widget.videoId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('操作失败，请重试'),
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VideoProvider>();
    final isFavorited = vp.isFavorited(widget.videoId);
    final theme = Theme.of(context);

    return IconButton(
      onPressed: _loading ? null : _toggleFavorite,
      icon: _loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              isFavorited ? Icons.star : Icons.star_border,
              color: isFavorited ? const Color(0xFFFFD700) : null,
            ),
      tooltip: isFavorited ? '取消收藏' : '收藏',
    );
  }
}


class _CommentsSkeleton extends StatelessWidget {
  const _CommentsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        children: List.generate(3, (i) => const _SkeletonLine()),
      ),
    );
  }
}

class _NotesSkeleton extends StatelessWidget {
  const _NotesSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(children: const [_SkeletonLine(), SizedBox(height: 8), _SkeletonLine(), SizedBox(height: 8), _SkeletonLine()]),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: Radii.sm),
    );
  }
}

// 已移除预览数据结构，改为复用 CommentsPane 内部逻辑

class _NotesBlock extends StatelessWidget {
  final String title;
  final List<NoteItem> items;
  final Color accent;
  const _NotesBlock({required this.title, required this.items, required this.accent});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: accent, borderRadius: Radii.sm)),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall),
        ]),
        const SizedBox(height: Spacing.sm),
        if (items.isEmpty)
          Text('暂无内容', style: theme.textTheme.bodySmall)
        else
          Column(
            children: [
              for (final n in items)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: Radii.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(n.content, style: theme.textTheme.bodySmall),
                      if (n.seconds > 0) ...[
                        const SizedBox(height: 6),
                        Row(children: [const Icon(Icons.schedule, size: 16), const SizedBox(width: 4), Text('${n.seconds}s')]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _UserNotesBlock extends StatefulWidget {
  final String videoId;
  final List<NoteItem> items;
  const _UserNotesBlock({required this.videoId, required this.items});
  @override
  State<_UserNotesBlock> createState() => _UserNotesBlockState();
}

class _UserNotesBlockState extends State<_UserNotesBlock> with AutomaticKeepAliveClientMixin {
  bool _editingNew = false;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) return;
    try {
      final repo = NotesRepository(api: NotesService(AppBootstrap.apiClient.dio));
      await repo.create(videoId: widget.videoId, title: title, content: content, seconds: 0);
      if (mounted) {
        setState(() {
          _editingNew = false;
          _title.clear();
          _content.clear();
          // 本地追加到列表（后端未就绪时的前端演示）
          widget.items.add(NoteItem(id: 'local_${DateTime.now().millisecondsSinceEpoch}', videoId: widget.videoId, title: title, content: content, seconds: 0, createAt: DateTime.now().millisecondsSinceEpoch ~/ 1000));
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败'), duration: Duration(milliseconds: 1200)));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 保持状态
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: Colors.orange, borderRadius: Radii.sm)),
          const SizedBox(width: 8),
          Text('用户关联笔记', style: theme.textTheme.titleSmall),
          const Spacer(),
          TextButton.icon(onPressed: () => setState(() => _editingNew = !_editingNew), icon: const Icon(Icons.add), label: const Text('新增')),
        ]),
        const SizedBox(height: Spacing.sm),
        if (_editingNew)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: Radii.md),
            child: Column(
              children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: '标题')),
                const SizedBox(height: 8),
                TextField(controller: _content, decoration: const InputDecoration(labelText: '内容'), maxLines: 3),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton(onPressed: _save, child: const Text('保存')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setState(() { _editingNew = false; _title.clear(); _content.clear(); }), child: const Text('取消')),
                ]),
              ],
            ),
          ),
        const SizedBox(height: Spacing.sm),
        if (widget.items.isEmpty)
          Text('暂无内容', style: theme.textTheme.bodySmall)
        else
          Column(
            children: [
              for (final n in widget.items)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: Radii.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(n.title, style: theme.textTheme.titleSmall)),
                        IconButton(onPressed: () {/* 预留编辑入口 */}, icon: const Icon(Icons.edit)),
                      ]),
                      const SizedBox(height: 6),
                      Text(n.content, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
