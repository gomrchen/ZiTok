import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/video.dart';
import '../../../providers/video_provider.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_tokens.dart';
import '../../../widgets/comment_sheet.dart' show CommentsPane; // 复用评论组件
import '../../../repositories/notes_repository.dart';
import '../../../services/notes_service.dart';
import '../../../app.dart';
import '../../../models/notes_models.dart';
import 'md_notes_sheet.dart' show NoteReaderPage;

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
      return await repo.getVideoNotes(videoId: int.tryParse(vid) ?? 0);
    } catch (_) {
      return const NoteListResp(total: 0, notes: []);
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
              _NotesTabContent(video: widget.video, notesFuture: _notesFuture),
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
          Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey.shade600),
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
            icon: const Icon(Icons.thumb_up_outlined),
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

/// 笔记Tab内容（统一样式+快速发布按钮）
class _NotesTabContent extends StatefulWidget {
  final Video video;
  final Future<NoteListResp>? notesFuture;

  const _NotesTabContent({required this.video, required this.notesFuture});

  @override
  State<_NotesTabContent> createState() => _NotesTabContentState();
}

class _NotesTabContentState extends State<_NotesTabContent> {
  List<NoteItem> _notes = [];
  bool _loaded = false;
  String _sortBy = 'like'; // 'like' or 'favorite'

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (widget.notesFuture == null) return;
    try {
      final result = await widget.notesFuture!;
      if (mounted) {
        setState(() {
          _notes = result.notes;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  List<NoteItem> get _sortedNotes {
    final sorted = List<NoteItem>.from(_notes);
    if (_sortBy == 'like') {
      sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      sorted.sort((a, b) => b.favoriteCount.compareTo(a.favoriteCount));
    }
    return sorted;
  }

  void _navigateToQuickPublish() {
    // 跳转到笔记发布页面，并预设关联视频
    context.push('/create', extra: {
      'mode': 'note_only',
      'linkedVideo': widget.video,
    });
  }

  void _openNoteReader(NoteItem note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteReaderPage(note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (!_loaded) {
      return const _NotesSkeleton();
    }

    return Column(
      children: [
        // 排序栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
          color: cs.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.article_outlined, size: 18, color: cs.primary),
              const SizedBox(width: Spacing.xs),
              Text('关联笔记 (${_notes.length})', style: theme.textTheme.labelLarge),
              const Spacer(),
              // 排序选择
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (value) => setState(() => _sortBy = value),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _sortBy == 'like' ? '按点赞数' : '按收藏数',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: cs.onSurfaceVariant),
                  ],
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'like', child: Text('按点赞数排序')),
                  const PopupMenuItem(value: 'favorite', child: Text('按收藏数排序')),
                ],
              ),
            ],
          ),
        ),
        // 笔记列表
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: Spacing.md),
                      Text('暂无关联笔记', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: Spacing.xs),
                      Text('成为第一个发布笔记的人吧！', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(Spacing.md),
                  itemCount: _sortedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _sortedNotes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: _UnifiedNoteListItem(
                        note: note,
                        onTap: () => _openNoteReader(note),
                      ),
                    );
                  },
                ),
        ),
        // 底部快速发布按钮
        Container(
          padding: EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.sm + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              onPressed: _navigateToQuickPublish,
              icon: const Icon(Icons.edit_note),
              label: const Text('快速发布笔记'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 统一样式的笔记列表项（与"我的笔记"一致）
class _UnifiedNoteListItem extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;

  const _UnifiedNoteListItem({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.article_outlined, color: cs.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : '无标题笔记',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.thumb_up_outlined, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${note.likeCount}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Icon(Icons.star_outline, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${note.favoriteCount}', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        // 如果有时间戳，显示
                        if (note.seconds > 0) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${note.seconds}s', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
