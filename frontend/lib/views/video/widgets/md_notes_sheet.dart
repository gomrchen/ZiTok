import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../repositories/notes_repository.dart';
import '../../../services/notes_service.dart';
import '../../../app.dart';
import '../../../theme/theme_tokens.dart';
import '../../../models/notes_models.dart';

/// 公共组件：Md 笔记弹窗（可拖拽查看更多，带关闭按钮）
/// 展示与视频关联的笔记列表，点击进入笔记阅览界面
class MdNotesBottomSheet extends StatefulWidget {
  final String videoId;
  const MdNotesBottomSheet({super.key, required this.videoId});

  @override
  State<MdNotesBottomSheet> createState() => _MdNotesBottomSheetState();
}

class _MdNotesBottomSheetState extends State<MdNotesBottomSheet> {
  List<NoteItem> _notes = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;
  String _sortBy = 'like'; // 'like' or 'favorite'

  /// 根据排序方式对笔记列表排序
  List<NoteItem> get _sortedNotes {
    final sorted = List<NoteItem>.from(_notes);
    if (_sortBy == 'like') {
      sorted.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    } else {
      sorted.sort((a, b) => b.favoriteCount.compareTo(a.favoriteCount));
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _loadNotes(refresh: true);
  }

  Future<void> _loadNotes({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _loading = true;
      if (refresh) _error = null;
    });

    try {
      final repo = NotesRepository(api: NotesService(AppBootstrap.apiClient.dio));
      final result = await repo.getVideoNotes(
        videoId: int.tryParse(widget.videoId) ?? 0,
        page: _page,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _notes = result.notes;
          } else {
            _notes.addAll(result.notes);
          }
          _hasMore = result.notes.length >= _pageSize;
          _page++;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, controller) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // 顶部拖动指示器
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 20, color: cs.primary),
                    const SizedBox(width: Spacing.sm),
                    Text('关联笔记', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_notes.length}',
                        style: theme.textTheme.labelSmall?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ),
                    const Spacer(),
                    // 排序按钮
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (value) => setState(() => _sortBy = value),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _sortBy == 'like' ? '按点赞' : '按收藏',
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
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 笔记列表
              Expanded(
                child: _buildContent(controller, cs, theme),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController controller, ColorScheme cs, ThemeData theme) {
    if (_loading && _notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: Spacing.md),
            Text('加载失败', style: theme.textTheme.bodyMedium),
            const SizedBox(height: Spacing.sm),
            ElevatedButton(
              onPressed: () => _loadNotes(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: Spacing.md),
            Text(
              '暂无关联笔记',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '该视频还没有关联的笔记内容',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final sortedNotes = _sortedNotes;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          if (_hasMore && !_loading &&
              notification.metrics.pixels >= notification.metrics.maxScrollExtent - 100) {
            _loadNotes();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(Spacing.md),
        itemCount: sortedNotes.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sortedNotes.length) {
            return const Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final note = sortedNotes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: _NoteListItem(
              note: note,
              onTap: () => _openNoteReader(note),
            ),
          );
        },
      ),
    );
  }
}

/// 笔记列表项（与我的笔记页面样式一致）
class _NoteListItem extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;

  const _NoteListItem({required this.note, required this.onTap});

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

/// 笔记阅读器页面（带字体大小调整和滚动控制）
class NoteReaderPage extends StatefulWidget {
  final NoteItem note;

  const NoteReaderPage({super.key, required this.note});

  @override
  State<NoteReaderPage> createState() => _NoteReaderPageState();
}

class _NoteReaderPageState extends State<NoteReaderPage> {
  late bool _isLiked;
  late bool _isFavorited;
  late int _likeCount;
  late int _favoriteCount;
  bool _likeLoading = false;
  bool _favoriteLoading = false;

  // 字体大小（默认14）
  double _fontSize = 14.0;
  static const double _minFontSize = 8.0;
  static const double _maxFontSize = 24.0;

  // 滚动控制器
  final ScrollController _scrollController = ScrollController();

  // 显示设置面板
  bool _showSettingsPanel = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.note.isLiked;
    _isFavorited = widget.note.isFavorited;
    _likeCount = widget.note.likeCount;
    _favoriteCount = widget.note.favoriteCount;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;

    setState(() => _likeLoading = true);

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final success = await notesRepo.toggleLike(int.tryParse(widget.note.id) ?? 0);

      if (success && mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _likeLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteLoading) return;

    setState(() => _favoriteLoading = true);

    try {
      final notesService = NotesService(AppBootstrap.apiClient.dio);
      final notesRepo = NotesRepository(api: notesService);
      final success = await notesRepo.toggleFavorite(int.tryParse(widget.note.id) ?? 0);

      if (success && mounted) {
        setState(() {
          _isFavorited = !_isFavorited;
          _favoriteCount += _isFavorited ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _favoriteLoading = false);
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _increaseFontSize() {
    if (_fontSize < _maxFontSize) {
      setState(() => _fontSize += 2);
    }
  }

  void _decreaseFontSize() {
    if (_fontSize > _minFontSize) {
      setState(() => _fontSize -= 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.note.title.isNotEmpty ? widget.note.title : '笔记详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 设置按钮
          IconButton(
            onPressed: () => setState(() => _showSettingsPanel = !_showSettingsPanel),
            icon: Icon(
              Icons.text_fields,
              color: _showSettingsPanel ? cs.primary : null,
            ),
            tooltip: '阅读设置',
          ),
          // 点赞按钮
          IconButton(
            onPressed: _likeLoading ? null : _toggleLike,
            icon: _likeLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _isLiked ? Colors.blue : null,
                  ),
            tooltip: '点赞 ($_likeCount)',
          ),
          // 收藏按钮
          IconButton(
            onPressed: _favoriteLoading ? null : _toggleFavorite,
            icon: _favoriteLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isFavorited ? Icons.star : Icons.star_outline,
                    color: _isFavorited ? Colors.amber : null,
                  ),
            tooltip: '收藏 ($_favoriteCount)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 主内容区域
          Container(
            color: cs.surface,
            child: Markdown(
              controller: _scrollController,
              data: widget.note.content.isNotEmpty
                  ? widget.note.content
                  : '# 暂无内容\n\n这篇笔记还没有内容。',
              padding: const EdgeInsets.all(Spacing.md),
              styleSheet: _buildMarkdownStyleSheet(theme, cs),
            ),
          ),

          // 设置面板
          if (_showSettingsPanel)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 字体大小调整
                    Text('字体大小', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: Spacing.sm),
                    IconButton(
                      onPressed: _fontSize > _minFontSize ? _decreaseFontSize : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      tooltip: '减小字体',
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_fontSize.toInt()}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      onPressed: _fontSize < _maxFontSize ? _increaseFontSize : null,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      tooltip: '增大字体',
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    // 滚动控制
                    IconButton(
                      onPressed: _scrollToTop,
                      icon: const Icon(Icons.vertical_align_top, size: 20),
                      tooltip: '回到顶部',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: _scrollToBottom,
                      icon: const Icon(Icons.vertical_align_bottom, size: 20),
                      tooltip: '跳到底部',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // 浮动操作按钮：快速回到顶部
      floatingActionButton: FloatingActionButton.small(
        onPressed: _scrollToTop,
        tooltip: '回到顶部',
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme, ColorScheme cs) {
    return MarkdownStyleSheet(
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
        fontSize: _fontSize + 8,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: _fontSize + 4,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
        fontSize: _fontSize + 2,
      ),
      p: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        height: 1.6,
        fontSize: _fontSize,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        backgroundColor: cs.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: _fontSize - 1,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurfaceVariant,
        fontStyle: FontStyle.italic,
        fontSize: _fontSize,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: cs.primary, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontSize: _fontSize,
      ),
    );
  }
}
